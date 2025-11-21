# Error Handling Reference

> Comprehensive guide to error handling in the LLM Config Manager API

## Table of Contents

- [Overview](#overview)
- [Error Response Format](#error-response-format)
- [HTTP Status Codes](#http-status-codes)
- [Error Categories](#error-categories)
- [Detailed Error Reference](#detailed-error-reference)
- [Client Error Handling](#client-error-handling)
- [Best Practices](#best-practices)

## Overview

The LLM Config Manager API uses standard HTTP status codes and provides detailed error messages in a consistent JSON format. All errors include a machine-readable error type and a human-readable message.

### Design Principles

1. **Consistency**: All errors follow the same structure
2. **Clarity**: Error messages are descriptive and actionable
3. **Security**: Sensitive information is never exposed in error messages
4. **Standards**: HTTP status codes follow RFC 7231
5. **Debugging**: Includes context when safe to do so

## Error Response Format

All error responses follow this structure:

```json
{
  "error": "Error Type",
  "message": "Detailed error message"
}
```

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `error` | string | Machine-readable error type (e.g., "Not Found", "Bad Request") |
| `message` | string | Human-readable error description with context |

### Example

```json
{
  "error": "Not Found",
  "message": "Configuration not found: app/llm:model"
}
```

## HTTP Status Codes

### Success Codes (2xx)

| Code | Status | Description | Example |
|------|--------|-------------|---------|
| 200 | OK | Request successful, response includes data | GET config successful |
| 204 | No Content | Request successful, no response body | DELETE config successful |

### Client Error Codes (4xx)

| Code | Status | Description | When Used |
|------|--------|-------------|-----------|
| 400 | Bad Request | Invalid request parameters or body | Invalid environment, malformed JSON |
| 401 | Unauthorized | Authentication required or failed | Missing/invalid token |
| 403 | Forbidden | Insufficient permissions | IP blocked, policy violation |
| 404 | Not Found | Resource doesn't exist | Config or version not found |
| 413 | Payload Too Large | Request body exceeds size limit | Request > 10MB |
| 426 | Upgrade Required | HTTPS required | HTTP request in production |
| 429 | Too Many Requests | Rate limit exceeded | Too many requests from IP/user |

### Server Error Codes (5xx)

| Code | Status | Description | When Used |
|------|--------|-------------|-----------|
| 500 | Internal Server Error | Unexpected server error | Database failure, panic |
| 503 | Service Unavailable | Service temporarily unavailable | Maintenance mode, overload |

## Error Categories

### 1. Validation Errors (400)

Errors caused by invalid input data.

**Common Causes**:
- Invalid namespace format
- Invalid key format
- Unknown environment
- Malformed JSON
- Invalid data types
- Missing required fields

**Examples**:

```json
{
  "error": "Bad Request",
  "message": "Unknown environment: invalid"
}
```

```json
{
  "error": "Bad Request",
  "message": "Secret value must be a string"
}
```

```json
{
  "error": "Bad Request",
  "message": "Input validation failed: invalid characters in namespace"
}
```

---

### 2. Authentication Errors (401)

Errors related to authentication failures.

**Common Causes**:
- Missing authentication header
- Invalid token/API key
- Expired token
- Malformed authentication header

**Examples**:

```json
{
  "error": "Unauthorized",
  "message": "Authentication failed"
}
```

```json
{
  "error": "Unauthorized",
  "message": "Invalid or expired token"
}
```

**Security Note**: Error messages intentionally avoid disclosing whether a token exists but is invalid vs. doesn't exist at all.

---

### 3. Authorization Errors (403)

Errors caused by insufficient permissions.

**Common Causes**:
- IP address blocked
- Insufficient role permissions
- Security policy violation
- Endpoint access denied
- TLS requirement not met

**Examples**:

```json
{
  "error": "Forbidden",
  "message": "Access denied"
}
```

```json
{
  "error": "Forbidden",
  "message": "Request rejected due to security policy"
}
```

**Security Note**: Generic messages prevent information disclosure about security policies.

---

### 4. Not Found Errors (404)

Errors when requested resources don't exist.

**Common Causes**:
- Configuration doesn't exist
- Namespace is empty
- Version doesn't exist
- Invalid endpoint path

**Examples**:

```json
{
  "error": "Not Found",
  "message": "Configuration not found: app/llm:model"
}
```

```json
{
  "error": "Not Found",
  "message": "Version 5 not found"
}
```

---

### 5. Rate Limiting Errors (429)

Errors when rate limits are exceeded.

**Common Causes**:
- Too many requests from IP
- User rate limit exceeded
- IP temporarily banned
- Burst limit exceeded

**Examples**:

```json
{
  "error": "Too Many Requests",
  "message": "Rate limit exceeded. Please try again later"
}
```

```json
{
  "error": "Too Many Requests",
  "message": "IP address is temporarily banned"
}
```

**Response Headers**:
```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1705852800
Retry-After: 60
```

---

### 6. Server Errors (500)

Unexpected server-side errors.

**Common Causes**:
- Database connection failure
- Storage backend unavailable
- Encryption/decryption failure
- Unexpected panic or crash

**Examples**:

```json
{
  "error": "Internal Server Error",
  "message": "An unexpected error occurred. Please try again later."
}
```

**Security Note**: Internal errors provide minimal detail to prevent information disclosure.

## Detailed Error Reference

### Validation Errors

#### Invalid Environment

```http
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "error": "Bad Request",
  "message": "Unknown environment: invalid"
}
```

**Cause**: Environment parameter is not one of: base, development, staging, production, edge

**Solution**: Use a valid environment value

**Example Fix**:
```bash
# ❌ Wrong
curl .../configs/app/llm/model?env=invalid

# ✅ Correct
curl .../configs/app/llm/model?env=production
```

---

#### Invalid Namespace Format

```http
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "error": "Bad Request",
  "message": "Input validation failed: invalid characters in namespace"
}
```

**Cause**: Namespace contains invalid characters (only alphanumeric, `/`, `_`, `-` allowed)

**Solution**: Use only allowed characters in namespace

**Valid Examples**:
- `app/llm`
- `database/postgres`
- `features/experimental`
- `api_v2/configs`

---

#### Invalid JSON

```http
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "error": "Bad Request",
  "message": "Failed to parse JSON: expected value at line 1 column 1"
}
```

**Cause**: Request body is not valid JSON

**Solution**: Ensure request body is properly formatted JSON

**Example Fix**:
```bash
# ❌ Wrong (missing quotes)
curl -X POST .../configs/app/llm/model -d '{value: gpt-4, env: production}'

# ✅ Correct
curl -X POST .../configs/app/llm/model -d '{"value": "gpt-4", "env": "production"}'
```

---

#### Secret Value Type Error

```http
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "error": "Bad Request",
  "message": "Secret value must be a string"
}
```

**Cause**: Attempting to store non-string value as a secret

**Solution**: Convert value to string before marking as secret

**Example Fix**:
```bash
# ❌ Wrong (number as secret)
curl -X POST .../configs/app/llm/api_key \
  -d '{"value": 12345, "env": "production", "secret": true}'

# ✅ Correct
curl -X POST .../configs/app/llm/api_key \
  -d '{"value": "sk-proj-abc123", "env": "production", "secret": true}'
```

---

### Security Errors

#### SQL Injection Attempt

```http
HTTP/1.1 403 Forbidden
Content-Type: application/json

{
  "error": "Forbidden",
  "message": "Request rejected due to security policy"
}
```

**Cause**: Input contains patterns matching SQL injection attempts

**Detected Patterns**:
- `' OR '1'='1`
- `'; DROP TABLE`
- `UNION SELECT`
- etc.

**Note**: The API automatically blocks and logs potential SQL injection attempts.

---

#### XSS Attempt

```http
HTTP/1.1 403 Forbidden
Content-Type: application/json

{
  "error": "Forbidden",
  "message": "Request rejected due to security policy"
}
```

**Cause**: Input contains patterns matching XSS attempts

**Detected Patterns**:
- `<script>`
- `javascript:`
- `onerror=`
- etc.

---

#### Path Traversal Attempt

```http
HTTP/1.1 403 Forbidden
Content-Type: application/json

{
  "error": "Forbidden",
  "message": "Request rejected due to security policy"
}
```

**Cause**: Input contains path traversal patterns

**Detected Patterns**:
- `../`
- `..\`
- `/etc/passwd`
- etc.

---

#### Request Too Large

```http
HTTP/1.1 413 Payload Too Large
Content-Type: application/json

{
  "error": "Payload Too Large",
  "message": "Request size exceeds maximum allowed: 10485760 bytes"
}
```

**Cause**: Request body exceeds 10MB limit

**Solution**: Reduce request size or split into multiple requests

---

#### TLS Required

```http
HTTP/1.1 426 Upgrade Required
Content-Type: application/json

{
  "error": "Upgrade Required",
  "message": "HTTPS/TLS connection required"
}
```

**Cause**: HTTP request to production environment (HTTPS required)

**Solution**: Use HTTPS

**Example Fix**:
```bash
# ❌ Wrong
curl http://api.example.com/api/v1/configs/app/llm/model

# ✅ Correct
curl https://api.example.com/api/v1/configs/app/llm/model
```

---

## Client Error Handling

### Python Example

```python
import requests
import time
from requests.exceptions import HTTPError, Timeout, ConnectionError

class ConfigClient:
    def __init__(self, base_url, token):
        self.base_url = base_url
        self.headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        }

    def get_config(self, namespace, key, env="production", max_retries=3):
        """Get config with comprehensive error handling"""
        url = f"{self.base_url}/configs/{namespace}/{key}"
        params = {"env": env}

        for attempt in range(max_retries):
            try:
                response = requests.get(
                    url,
                    params=params,
                    headers=self.headers,
                    timeout=5
                )
                response.raise_for_status()
                return response.json()

            except HTTPError as e:
                status_code = e.response.status_code
                error_data = e.response.json()

                if status_code == 400:
                    # Bad request - don't retry
                    raise ValueError(f"Invalid request: {error_data['message']}")

                elif status_code == 401:
                    # Unauthorized - refresh token and retry
                    self.refresh_token()
                    if attempt < max_retries - 1:
                        continue
                    raise

                elif status_code == 403:
                    # Forbidden - don't retry
                    raise PermissionError(f"Access denied: {error_data['message']}")

                elif status_code == 404:
                    # Not found - return None
                    return None

                elif status_code == 429:
                    # Rate limited - backoff and retry
                    retry_after = int(e.response.headers.get('Retry-After', 60))
                    print(f"Rate limited. Waiting {retry_after}s...")
                    time.sleep(retry_after)
                    if attempt < max_retries - 1:
                        continue
                    raise

                elif status_code >= 500:
                    # Server error - retry with exponential backoff
                    if attempt < max_retries - 1:
                        wait_time = (2 ** attempt) * 1
                        print(f"Server error. Retrying in {wait_time}s...")
                        time.sleep(wait_time)
                        continue
                    raise

                else:
                    raise

            except Timeout:
                # Timeout - retry with exponential backoff
                if attempt < max_retries - 1:
                    wait_time = (2 ** attempt) * 1
                    print(f"Timeout. Retrying in {wait_time}s...")
                    time.sleep(wait_time)
                    continue
                raise

            except ConnectionError:
                # Connection error - retry with exponential backoff
                if attempt < max_retries - 1:
                    wait_time = (2 ** attempt) * 1
                    print(f"Connection error. Retrying in {wait_time}s...")
                    time.sleep(wait_time)
                    continue
                raise

        raise Exception(f"Failed after {max_retries} attempts")

    def refresh_token(self):
        """Refresh authentication token"""
        # Implementation depends on auth method
        pass

# Usage
client = ConfigClient('http://localhost:8080/api/v1', 'token')

try:
    config = client.get_config('app/llm', 'model', 'production')
    if config:
        print(f"Model: {config['value']}")
    else:
        print("Config not found, using default")
        model = "gpt-3.5-turbo"  # Fallback

except ValueError as e:
    print(f"Invalid request: {e}")
except PermissionError as e:
    print(f"Permission denied: {e}")
except Exception as e:
    print(f"Unexpected error: {e}")
```

### JavaScript Example

```javascript
class ConfigClient {
  constructor(baseUrl, token) {
    this.baseUrl = baseUrl;
    this.token = token;
  }

  async getConfig(namespace, key, env = 'production', maxRetries = 3) {
    const url = `${this.baseUrl}/configs/${namespace}/${key}?env=${env}`;

    for (let attempt = 0; attempt < maxRetries; attempt++) {
      try {
        const response = await fetch(url, {
          headers: {
            'Authorization': `Bearer ${this.token}`,
            'Content-Type': 'application/json'
          },
          timeout: 5000
        });

        if (response.ok) {
          return await response.json();
        }

        const errorData = await response.json();

        switch (response.status) {
          case 400:
            throw new Error(`Invalid request: ${errorData.message}`);

          case 401:
            await this.refreshToken();
            if (attempt < maxRetries - 1) continue;
            throw new Error('Authentication failed');

          case 403:
            throw new Error(`Access denied: ${errorData.message}`);

          case 404:
            return null;

          case 429:
            const retryAfter = parseInt(response.headers.get('Retry-After') || '60');
            console.log(`Rate limited. Waiting ${retryAfter}s...`);
            await this.sleep(retryAfter * 1000);
            if (attempt < maxRetries - 1) continue;
            throw new Error('Rate limit exceeded');

          case 500:
          case 503:
            if (attempt < maxRetries - 1) {
              const waitTime = Math.pow(2, attempt) * 1000;
              console.log(`Server error. Retrying in ${waitTime/1000}s...`);
              await this.sleep(waitTime);
              continue;
            }
            throw new Error('Server error');

          default:
            throw new Error(`Unexpected error: ${errorData.message}`);
        }

      } catch (error) {
        if (attempt === maxRetries - 1) throw error;

        const waitTime = Math.pow(2, attempt) * 1000;
        console.log(`Error: ${error.message}. Retrying in ${waitTime/1000}s...`);
        await this.sleep(waitTime);
      }
    }

    throw new Error(`Failed after ${maxRetries} attempts`);
  }

  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  async refreshToken() {
    // Implementation depends on auth method
  }
}

// Usage
const client = new ConfigClient('http://localhost:8080/api/v1', 'token');

try {
  const config = await client.getConfig('app/llm', 'model', 'production');
  if (config) {
    console.log(`Model: ${config.value}`);
  } else {
    console.log('Config not found, using default');
    const model = 'gpt-3.5-turbo'; // Fallback
  }
} catch (error) {
  console.error('Error:', error.message);
}
```

## Best Practices

### 1. Always Check HTTP Status Codes

```python
response = requests.get(url)
if response.status_code == 200:
    data = response.json()
elif response.status_code == 404:
    # Use default value
    data = {"value": "default"}
else:
    # Handle error
    response.raise_for_status()
```

### 2. Implement Exponential Backoff

```python
import time

def exponential_backoff(attempt, max_delay=60):
    """Calculate exponential backoff delay"""
    delay = min(2 ** attempt, max_delay)
    return delay + random.uniform(0, 1)  # Add jitter
```

### 3. Respect Retry-After Headers

```python
if response.status_code == 429:
    retry_after = int(response.headers.get('Retry-After', 60))
    time.sleep(retry_after)
```

### 4. Log Errors for Debugging

```python
import logging

try:
    response = requests.get(url)
    response.raise_for_status()
except HTTPError as e:
    logging.error(
        "API request failed",
        extra={
            "status_code": e.response.status_code,
            "error": e.response.json(),
            "url": url,
            "timestamp": time.time()
        }
    )
```

### 5. Implement Circuit Breaker Pattern

```python
class CircuitBreaker:
    def __init__(self, failure_threshold=5, timeout=60):
        self.failure_threshold = failure_threshold
        self.timeout = timeout
        self.failures = 0
        self.last_failure_time = None
        self.state = "closed"  # closed, open, half-open

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
        except Exception as e:
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

### 6. Use Timeouts

```python
# Always set a timeout
response = requests.get(url, timeout=5)

# Or use separate connect and read timeouts
response = requests.get(url, timeout=(3, 10))  # 3s connect, 10s read
```

### 7. Implement Graceful Degradation

```python
def get_config_with_fallback(namespace, key, env, default):
    """Get config with fallback to default"""
    try:
        config = client.get_config(namespace, key, env)
        return config['value'] if config else default
    except Exception as e:
        logging.warning(f"Failed to get config, using default: {e}")
        return default

# Usage
model = get_config_with_fallback('app/llm', 'model', 'production', 'gpt-3.5-turbo')
```

### 8. Monitor Error Rates

```python
from prometheus_client import Counter, Histogram

api_errors = Counter(
    'api_errors_total',
    'Total API errors',
    ['status_code', 'endpoint']
)

api_latency = Histogram(
    'api_request_duration_seconds',
    'API request latency',
    ['endpoint']
)

# Track errors
api_errors.labels(status_code=404, endpoint='/configs').inc()
```

## Additional Resources

- [OpenAPI Specification](openapi.yaml) - Complete error schema definitions
- [Rate Limiting Guide](rate-limits.md) - Rate limit error handling
- [Authentication Guide](authentication.md) - Authentication error handling
- [API Reference](README.md) - Complete API documentation

---

**Version**: 0.5.0 | **Last Updated**: 2024-01-21
