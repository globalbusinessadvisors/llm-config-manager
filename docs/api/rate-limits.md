# Rate Limiting Guide

> Comprehensive guide to rate limiting in the LLM Config Manager API

## Table of Contents

- [Overview](#overview)
- [Rate Limit Configuration](#rate-limit-configuration)
- [Rate Limit Headers](#rate-limit-headers)
- [IP-Based Limiting](#ip-based-limiting)
- [User-Based Limiting](#user-based-limiting)
- [Automatic IP Banning](#automatic-ip-banning)
- [Client Implementation](#client-implementation)
- [Best Practices](#best-practices)
- [Monitoring](#monitoring)

## Overview

Rate limiting protects the API from abuse and ensures fair resource allocation across all users. The LLM Config Manager implements a sophisticated multi-tier rate limiting system with automatic banning for abusive IPs.

### Key Features

- **Dual-Tier Limiting**: Global and per-IP rate limits
- **Authenticated/Unauthenticated Differentiation**: Higher limits for authenticated users
- **Adaptive Banning**: Automatic temporary bans for repeated violations
- **Burst Support**: Allow brief traffic spikes
- **Graceful Degradation**: Clear error messages and retry guidance

### Architecture

```
┌─────────────────────────────────────────────┐
│              API Request                     │
└───────────────┬─────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────┐
│      Check if IP is Banned                   │
│      (Ban List with TTL)                     │
└───────────────┬─────────────────────────────┘
                │ Not Banned
                ▼
┌─────────────────────────────────────────────┐
│      Check Global Rate Limit                 │
│      (Authenticated: 100 rps)                │
│      (Unauthenticated: 10 rps)               │
└───────────────┬─────────────────────────────┘
                │ Within Limit
                ▼
┌─────────────────────────────────────────────┐
│      Check Per-IP Rate Limit                 │
│      (Per IP: 10 rps)                        │
└───────────────┬─────────────────────────────┘
                │ Within Limit
                ▼
┌─────────────────────────────────────────────┐
│      Process Request                         │
└─────────────────────────────────────────────┘
```

## Rate Limit Configuration

### Default Limits

| Metric | Authenticated | Unauthenticated | Per-IP |
|--------|---------------|-----------------|--------|
| **Requests/Second** | 100 | 10 | 10 |
| **Burst Size** | 50 | 10 | 10 |
| **Time Window** | 60 seconds | 60 seconds | 60 seconds |
| **Ban Threshold** | 10 violations | 10 violations | 10 violations |
| **Ban Duration** | 1 hour | 1 hour | 1 hour |

### Configuration Options

Rate limits can be configured at server startup:

```rust
use llm_config_security::RateLimitConfig;

let config = RateLimitConfig {
    authenticated_rps: 100,
    unauthenticated_rps: 10,
    burst_size: 50,
    window_seconds: 60,
    ban_duration_seconds: 3600,
    ban_threshold: 10,
};

let rate_limiter = RateLimiter::new(config);
```

### Environment Variables

```bash
# Set rate limits via environment variables
export LLM_CONFIG_RATE_LIMIT_AUTH_RPS=100
export LLM_CONFIG_RATE_LIMIT_UNAUTH_RPS=10
export LLM_CONFIG_RATE_LIMIT_BURST=50
export LLM_CONFIG_BAN_THRESHOLD=10
export LLM_CONFIG_BAN_DURATION=3600
```

## Rate Limit Headers

Every API response includes rate limit information:

```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1705852800
```

### Header Descriptions

| Header | Description | Example |
|--------|-------------|---------|
| `X-RateLimit-Limit` | Maximum requests allowed in the time window | `100` |
| `X-RateLimit-Remaining` | Requests remaining in current window | `95` |
| `X-RateLimit-Reset` | Unix timestamp when the rate limit resets | `1705852800` |

### Reading Headers

**Python Example**:
```python
response = requests.get(url, headers=headers)

limit = int(response.headers.get('X-RateLimit-Limit', 0))
remaining = int(response.headers.get('X-RateLimit-Remaining', 0))
reset = int(response.headers.get('X-RateLimit-Reset', 0))

print(f"Rate limit: {remaining}/{limit} remaining")
print(f"Resets at: {datetime.fromtimestamp(reset)}")
```

**JavaScript Example**:
```javascript
const response = await fetch(url, { headers });

const limit = parseInt(response.headers.get('X-RateLimit-Limit') || '0');
const remaining = parseInt(response.headers.get('X-RateLimit-Remaining') || '0');
const reset = parseInt(response.headers.get('X-RateLimit-Reset') || '0');

console.log(`Rate limit: ${remaining}/${limit} remaining`);
console.log(`Resets at: ${new Date(reset * 1000)}`);
```

## IP-Based Limiting

The API implements per-IP rate limiting to prevent single IPs from monopolizing resources.

### How It Works

1. **Request Received**: API extracts client IP from connection info
2. **Limiter Check**: Check if IP has exceeded its per-IP limit
3. **Violation Tracking**: Record violations for repeated offenders
4. **Automatic Banning**: Ban IP after exceeding threshold

### Per-IP Limits

```
Authenticated Users:   10 requests/second per IP
Unauthenticated Users: 10 requests/second per IP
Burst Allowance:       10 requests
```

### Example Scenario

```
Time    | Requests | Status | Remaining
--------|----------|--------|----------
0.0s    | 1        | OK     | 9
0.1s    | 1        | OK     | 8
0.2s    | 1        | OK     | 7
...     | ...      | ...    | ...
0.9s    | 1        | OK     | 1
1.0s    | 1        | OK     | 0
1.1s    | 1        | 429    | 0  ← Rate limited
1.2s    | 1        | 429    | 0  ← Still limited
2.0s    | 1        | OK     | 9  ← Window reset
```

## User-Based Limiting

Authenticated users get higher rate limits based on their authentication status.

### Authentication Detection

The API detects authentication by checking for the `Authorization` header:

```rust
let is_authenticated = headers.get("authorization").is_some();
```

### Limit Selection

```rust
let limiter = if authenticated {
    &self.authenticated_limiter  // 100 rps
} else {
    &self.unauthenticated_limiter  // 10 rps
};
```

### Example

**Unauthenticated Request** (10 rps):
```bash
curl http://localhost:8080/api/v1/configs/app/llm/model?env=production
```

**Authenticated Request** (100 rps):
```bash
curl http://localhost:8080/api/v1/configs/app/llm/model?env=production \
  -H "Authorization: Bearer token"
```

## Automatic IP Banning

The API automatically bans IPs that repeatedly violate rate limits.

### Ban Triggers

1. **Violation Count**: IP exceeds rate limit 10 times
2. **Time Window**: Within the configured window (default: 60 seconds)
3. **Automatic Action**: IP is banned for 1 hour

### Ban Process

```rust
fn record_violation(&self, ip: IpAddr, reason: &str) {
    let mut limiters = self.per_ip_limiters.write().unwrap();
    if let Some(ip_limiter) = limiters.get_mut(&ip) {
        ip_limiter.violations += 1;
        ip_limiter.last_violation = std::time::Instant::now();

        // Ban if threshold exceeded
        if ip_limiter.violations >= self.config.ban_threshold {
            self.ban_ip(ip, reason.to_string(), ip_limiter.violations);
        }
    }
}
```

### Ban Response

When an IP is banned, requests receive:

```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/json

{
  "error": "Too Many Requests",
  "message": "IP address is temporarily banned"
}
```

### Ban Duration

- **Default**: 1 hour (3600 seconds)
- **Configurable**: Via `ban_duration_seconds` setting
- **Automatic Expiry**: Bans expire automatically

### Manual Ban Management

**Ban an IP**:
```rust
rate_limiter.ban(
    "192.168.1.100".parse().unwrap(),
    "Suspicious activity detected".to_string()
);
```

**Unban an IP**:
```rust
rate_limiter.unban("192.168.1.100".parse().unwrap());
```

**List Banned IPs**:
```rust
let banned_ips = rate_limiter.get_banned_ips();
for (ip, ban_info) in banned_ips {
    println!("IP: {}, Banned at: {:?}, Reason: {}",
        ip, ban_info.banned_at, ban_info.reason);
}
```

## Client Implementation

### Basic Rate Limit Handling

```python
import time
import requests

def get_config(url, headers):
    response = requests.get(url, headers=headers)

    if response.status_code == 429:
        # Rate limited - check Retry-After header
        retry_after = int(response.headers.get('Retry-After', 60))
        print(f"Rate limited. Waiting {retry_after}s...")
        time.sleep(retry_after)
        return get_config(url, headers)  # Retry

    return response.json()
```

### Advanced Rate Limit Handling

```python
import time
import requests
from datetime import datetime

class RateLimitedClient:
    def __init__(self, base_url, token):
        self.base_url = base_url
        self.token = token
        self.rate_limit = None
        self.rate_remaining = None
        self.rate_reset = None

    def update_rate_limits(self, response):
        """Update rate limit info from response headers"""
        self.rate_limit = int(response.headers.get('X-RateLimit-Limit', 0))
        self.rate_remaining = int(response.headers.get('X-RateLimit-Remaining', 0))
        self.rate_reset = int(response.headers.get('X-RateLimit-Reset', 0))

    def wait_if_needed(self):
        """Wait if rate limit is low"""
        if self.rate_remaining is not None and self.rate_remaining < 5:
            now = time.time()
            if self.rate_reset and now < self.rate_reset:
                wait_time = self.rate_reset - now + 1
                print(f"Rate limit low. Waiting {wait_time:.1f}s...")
                time.sleep(wait_time)

    def request(self, method, path, **kwargs):
        """Make request with rate limit handling"""
        self.wait_if_needed()

        url = f"{self.base_url}{path}"
        headers = kwargs.get('headers', {})
        headers['Authorization'] = f'Bearer {self.token}'
        kwargs['headers'] = headers

        response = requests.request(method, url, **kwargs)
        self.update_rate_limits(response)

        if response.status_code == 429:
            retry_after = int(response.headers.get('Retry-After', 60))
            print(f"Rate limited. Waiting {retry_after}s...")
            time.sleep(retry_after)
            return self.request(method, path, **kwargs)

        response.raise_for_status()
        return response.json()

    def get_config(self, namespace, key, env='production'):
        return self.request(
            'GET',
            f'/configs/{namespace}/{key}',
            params={'env': env}
        )

# Usage
client = RateLimitedClient('http://localhost:8080/api/v1', 'token')
config = client.get_config('app/llm', 'model', 'production')
```

### Request Throttling

```python
import time
from threading import Lock

class ThrottledClient:
    def __init__(self, base_url, token, max_rps=90):
        self.base_url = base_url
        self.token = token
        self.max_rps = max_rps
        self.min_interval = 1.0 / max_rps
        self.last_request_time = 0
        self.lock = Lock()

    def throttled_request(self, method, path, **kwargs):
        """Make request with client-side throttling"""
        with self.lock:
            # Calculate time to wait
            now = time.time()
            time_since_last = now - self.last_request_time
            if time_since_last < self.min_interval:
                time.sleep(self.min_interval - time_since_last)

            # Make request
            self.last_request_time = time.time()

        url = f"{self.base_url}{path}"
        headers = kwargs.get('headers', {})
        headers['Authorization'] = f'Bearer {self.token}'
        kwargs['headers'] = headers

        response = requests.request(method, url, **kwargs)

        if response.status_code == 429:
            retry_after = int(response.headers.get('Retry-After', 60))
            time.sleep(retry_after)
            return self.throttled_request(method, path, **kwargs)

        response.raise_for_status()
        return response.json()
```

### Batch Request Processing

```python
import time

class BatchProcessor:
    def __init__(self, client, batch_size=50, delay_between_batches=1.0):
        self.client = client
        self.batch_size = batch_size
        self.delay_between_batches = delay_between_batches

    def process_batch(self, items):
        """Process items in batches to avoid rate limits"""
        results = []

        for i in range(0, len(items), self.batch_size):
            batch = items[i:i + self.batch_size]

            print(f"Processing batch {i // self.batch_size + 1}...")

            for item in batch:
                try:
                    result = self.client.get_config(
                        item['namespace'],
                        item['key'],
                        item['env']
                    )
                    results.append({'item': item, 'result': result})
                except Exception as e:
                    results.append({'item': item, 'error': str(e)})

            # Wait between batches
            if i + self.batch_size < len(items):
                time.sleep(self.delay_between_batches)

        return results

# Usage
processor = BatchProcessor(client, batch_size=50, delay_between_batches=1.0)
items = [
    {'namespace': 'app/llm', 'key': 'model', 'env': 'production'},
    {'namespace': 'app/llm', 'key': 'temperature', 'env': 'production'},
    # ... more items
]
results = processor.process_batch(items)
```

## Best Practices

### 1. Monitor Rate Limit Headers

```python
def check_rate_limit_status(response):
    """Monitor and log rate limit status"""
    limit = int(response.headers.get('X-RateLimit-Limit', 0))
    remaining = int(response.headers.get('X-RateLimit-Remaining', 0))

    usage_percent = ((limit - remaining) / limit) * 100 if limit > 0 else 0

    if usage_percent > 90:
        logging.warning(f"Rate limit usage high: {usage_percent:.1f}%")
    elif usage_percent > 80:
        logging.info(f"Rate limit usage: {usage_percent:.1f}%")

    return remaining, limit
```

### 2. Implement Exponential Backoff

```python
import random

def exponential_backoff_with_jitter(attempt, base_delay=1, max_delay=60):
    """Calculate backoff with exponential growth and jitter"""
    delay = min(base_delay * (2 ** attempt), max_delay)
    jitter = random.uniform(0, delay * 0.1)  # 10% jitter
    return delay + jitter

# Usage
for attempt in range(max_retries):
    try:
        response = make_request()
        break
    except RateLimitError:
        if attempt < max_retries - 1:
            delay = exponential_backoff_with_jitter(attempt)
            time.sleep(delay)
```

### 3. Use Client-Side Rate Limiting

```python
from ratelimit import limits, sleep_and_retry

@sleep_and_retry
@limits(calls=90, period=1)  # 90 calls per second (90% of limit)
def get_config_rate_limited(namespace, key, env):
    """Get config with client-side rate limiting"""
    return client.get_config(namespace, key, env)
```

### 4. Implement Circuit Breaker

```python
class CircuitBreaker:
    def __init__(self, failure_threshold=5, timeout=60):
        self.failure_threshold = failure_threshold
        self.timeout = timeout
        self.failures = 0
        self.last_failure_time = None
        self.state = "closed"

    def call(self, func, *args, **kwargs):
        if self.state == "open":
            if time.time() - self.last_failure_time > self.timeout:
                self.state = "half-open"
            else:
                raise Exception("Circuit breaker is open")

        try:
            result = func(*args, **kwargs)
            self.on_success()
            return result
        except RateLimitError:
            self.on_failure()
            raise

    def on_success(self):
        self.failures = 0
        self.state = "closed"

    def on_failure(self):
        self.failures += 1
        self.last_failure_time = time.time()
        if self.failures >= self.failure_threshold:
            self.state = "open"
```

### 5. Cache Responses

```python
from functools import lru_cache
import time

def get_ttl_hash(seconds=300):
    """Return hash that changes every `seconds`"""
    return round(time.time() / seconds)

@lru_cache(maxsize=256)
def get_config_cached(namespace, key, env, ttl_hash):
    """Cached config retrieval with TTL"""
    return client.get_config(namespace, key, env)

# Usage (cached for 5 minutes)
config = get_config_cached('app/llm', 'model', 'production', get_ttl_hash(300))
```

### 6. Distribute Load

```python
import random

# Use multiple API keys to distribute load
api_keys = ['key1', 'key2', 'key3']

def get_client():
    """Get client with random API key for load distribution"""
    key = random.choice(api_keys)
    return ConfigClient(base_url, key)

# Usage
client = get_client()
config = client.get_config('app/llm', 'model', 'production')
```

### 7. Handle 429 Gracefully

```python
def handle_429(response):
    """Handle rate limit error with proper retry logic"""
    retry_after = int(response.headers.get('Retry-After', 60))

    # Log the rate limit
    logging.warning(f"Rate limited. Retry after {retry_after}s")

    # Wait with progress indication
    for i in range(retry_after):
        print(f"\rWaiting: {i+1}/{retry_after}s", end='', flush=True)
        time.sleep(1)
    print()  # New line

    return True  # Indicate retry
```

## Monitoring

### Metrics to Track

1. **Request Rate**: Requests per second over time
2. **Rate Limit Usage**: Percentage of limit used
3. **429 Errors**: Rate limit error frequency
4. **Banned IPs**: Number of banned IPs
5. **Response Time**: API latency under load

### Prometheus Metrics

```rust
use prometheus::{Counter, Histogram, IntGauge};

lazy_static! {
    static ref RATE_LIMIT_HITS: Counter = register_counter!(
        "api_rate_limit_hits_total",
        "Total rate limit hits (429 responses)"
    ).unwrap();

    static ref RATE_LIMIT_USAGE: Histogram = register_histogram!(
        "api_rate_limit_usage_percent",
        "Rate limit usage percentage"
    ).unwrap();

    static ref BANNED_IPS: IntGauge = register_int_gauge!(
        "api_banned_ips",
        "Number of currently banned IPs"
    ).unwrap();
}

// Record metrics
RATE_LIMIT_HITS.inc();
RATE_LIMIT_USAGE.observe(usage_percent);
BANNED_IPS.set(banned_ips.len() as i64);
```

### Grafana Dashboard

```yaml
# Example Grafana dashboard query
- title: Rate Limit Usage
  query: |
    rate(api_requests_total[5m]) / api_rate_limit * 100

- title: 429 Error Rate
  query: |
    rate(api_rate_limit_hits_total[5m])

- title: Banned IPs
  query: |
    api_banned_ips
```

### Alerting Rules

```yaml
# Prometheus alerting rules
groups:
  - name: rate_limiting
    rules:
      - alert: HighRateLimitUsage
        expr: api_rate_limit_usage_percent > 80
        for: 5m
        annotations:
          summary: "High rate limit usage"
          description: "Rate limit usage above 80%"

      - alert: FrequentRateLimitErrors
        expr: rate(api_rate_limit_hits_total[5m]) > 10
        for: 5m
        annotations:
          summary: "Frequent rate limit errors"
          description: "More than 10 rate limit errors per second"
```

## Additional Resources

- [API Reference](README.md) - Complete API documentation
- [Error Handling Guide](errors.md) - Error handling best practices
- [Authentication Guide](authentication.md) - Authentication setup
- [OpenAPI Specification](openapi.yaml) - API specification

---

**Version**: 0.5.0 | **Last Updated**: 2024-01-21
