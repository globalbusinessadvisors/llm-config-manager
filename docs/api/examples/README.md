# API Integration Examples

This directory contains complete, production-ready integration examples for the LLM Config Manager API in multiple programming languages.

## Available Examples

### [Python Client](python-client.py)

Full-featured Python client with:
- Automatic retry with exponential backoff
- Rate limit handling
- Connection pooling
- Request caching
- Comprehensive error handling
- Type hints

**Requirements**:
```bash
pip install requests
```

**Usage**:
```python
from python_client import LLMConfigClient

client = LLMConfigClient(
    base_url="http://localhost:8080/api/v1",
    token="your-auth-token"
)

config = client.get_config("app/llm", "model", "production")
print(config['value'])  # 'gpt-4'
```

---

### [Node.js Client](nodejs-client.js)

Enterprise-grade JavaScript/Node.js client with:
- Async/await support
- Promise-based API
- Automatic retry logic
- Rate limit detection
- Circuit breaker pattern support
- Built-in caching

**Requirements**:
```bash
npm install axios
```

**Usage**:
```javascript
const { LLMConfigClient } = require('./nodejs-client');

const client = new LLMConfigClient({
  baseUrl: 'http://localhost:8080/api/v1',
  token: 'your-auth-token'
});

const config = await client.getConfig('app/llm', 'model', 'production');
console.log(config.value);  // 'gpt-4'
```

---

### [Go Client](go-client.go)

Idiomatic Go client with:
- Strongly typed responses
- Context support (TODO)
- Retry with exponential backoff
- Rate limit tracking
- Concurrent request safety
- Comprehensive error handling

**Requirements**:
```bash
go get github.com/go-resty/resty/v2
```

**Usage**:
```go
package main

import (
    "fmt"
    "log"
)

func main() {
    client := NewLLMConfigClient(
        "http://localhost:8080/api/v1",
        "your-auth-token",
    )

    config, err := client.GetConfig("app/llm", "model", "production", false)
    if err != nil {
        log.Fatal(err)
    }

    fmt.Println(config.Value)  // "gpt-4"
}
```

---

### [cURL Examples](curl-examples.sh)

Interactive shell script with examples for:
- All API endpoints
- Error handling scenarios
- Rate limiting tests
- Bulk operations
- Configuration backup/restore
- Environment comparisons

**Usage**:
```bash
# Make executable
chmod +x curl-examples.sh

# Interactive menu
./curl-examples.sh

# Run specific example
./curl-examples.sh health
./curl-examples.sh get
./curl-examples.sh all

# Direct curl usage
curl http://localhost:8080/api/v1/configs/app/llm/model?env=production \
  -H "Authorization: Bearer your-token"
```

---

## Quick Start

### 1. Start the API Server

```bash
llm-config-server --host 0.0.0.0 --port 8080
```

### 2. Run Examples

**Python**:
```bash
python python-client.py
```

**Node.js**:
```bash
node nodejs-client.js
```

**Go**:
```bash
go run go-client.go
```

**cURL**:
```bash
./curl-examples.sh
```

## Common Patterns

### Get Configuration with Fallback

**Python**:
```python
def get_config_or_default(client, namespace, key, env, default):
    config = client.get_config(namespace, key, env)
    return config['value'] if config else default

model = get_config_or_default(client, 'app/llm', 'model', 'production', 'gpt-3.5-turbo')
```

**JavaScript**:
```javascript
async function getConfigOrDefault(client, namespace, key, env, defaultValue) {
  const config = await client.getConfig(namespace, key, env);
  return config ? config.value : defaultValue;
}

const model = await getConfigOrDefault(client, 'app/llm', 'model', 'production', 'gpt-3.5-turbo');
```

**Go**:
```go
func getConfigOrDefault(client *LLMConfigClient, namespace, key, env string, defaultValue interface{}) (interface{}, error) {
    config, err := client.GetConfig(namespace, key, env, false)
    if err != nil {
        return nil, err
    }
    if config == nil {
        return defaultValue, nil
    }
    return config.Value, nil
}
```

### Rate Limit Handling

**Python**:
```python
import time

try:
    config = client.get_config('app/llm', 'model', 'production')
except RateLimitError as e:
    print(f"Rate limited. Waiting...")
    time.sleep(60)
    config = client.get_config('app/llm', 'model', 'production')
```

**JavaScript**:
```javascript
try {
  const config = await client.getConfig('app/llm', 'model', 'production');
} catch (error) {
  if (error instanceof RateLimitError) {
    console.log(`Rate limited. Waiting ${error.retryAfter}s...`);
    await new Promise(resolve => setTimeout(resolve, error.retryAfter * 1000));
    const config = await client.getConfig('app/llm', 'model', 'production');
  }
}
```

**Go**:
```go
config, err := client.GetConfig("app/llm", "model", "production", false)
if err != nil {
    if clientErr, ok := err.(*ConfigClientError); ok && clientErr.StatusCode == 429 {
        log.Println("Rate limited. Waiting 60s...")
        time.Sleep(60 * time.Second)
        config, err = client.GetConfig("app/llm", "model", "production", false)
    }
}
```

### Batch Operations

**Python**:
```python
# Set multiple configs
configs = [
    ('app/llm', 'model', 'gpt-4'),
    ('app/llm', 'temperature', 0.7),
    ('app/llm', 'max_tokens', 2000),
]

for namespace, key, value in configs:
    client.set_config(namespace, key, value, 'production', 'admin')
```

**JavaScript**:
```javascript
// Set multiple configs
const configs = [
  ['app/llm', 'model', 'gpt-4'],
  ['app/llm', 'temperature', 0.7],
  ['app/llm', 'max_tokens', 2000],
];

for (const [namespace, key, value] of configs) {
  await client.setConfig(namespace, key, value, 'production', 'admin');
}
```

**Go**:
```go
// Set multiple configs
configs := []struct {
    namespace string
    key       string
    value     interface{}
}{
    {"app/llm", "model", "gpt-4"},
    {"app/llm", "temperature", 0.7},
    {"app/llm", "max_tokens", 2000},
}

for _, cfg := range configs {
    _, err := client.SetConfig(cfg.namespace, cfg.key, cfg.value, "production", "admin", false)
    if err != nil {
        log.Printf("Failed to set %s/%s: %v", cfg.namespace, cfg.key, err)
    }
}
```

### Caching

**Python with functools.lru_cache**:
```python
from functools import lru_cache
import time

@lru_cache(maxsize=256)
def get_config_cached(namespace, key, env, ttl_hash):
    return client.get_config(namespace, key, env)

def get_ttl_hash(seconds=300):
    return round(time.time() / seconds)

# Cached for 5 minutes
config = get_config_cached('app/llm', 'model', 'production', get_ttl_hash(300))
```

**JavaScript with Map**:
```javascript
class ConfigCache {
  constructor(ttlMs = 300000) {
    this.cache = new Map();
    this.ttl = ttlMs;
  }

  get(namespace, key, env) {
    const cacheKey = `${namespace}:${key}:${env}`;
    const entry = this.cache.get(cacheKey);
    if (!entry || Date.now() > entry.expiresAt) {
      return null;
    }
    return entry.value;
  }

  set(namespace, key, env, value) {
    const cacheKey = `${namespace}:${key}:${env}`;
    this.cache.set(cacheKey, {
      value,
      expiresAt: Date.now() + this.ttl
    });
  }
}
```

**Go with sync.Map**:
```go
type CacheEntry struct {
    Value     interface{}
    ExpiresAt time.Time
}

type ConfigCache struct {
    cache sync.Map
    ttl   time.Duration
}

func (c *ConfigCache) Get(namespace, key, env string) (interface{}, bool) {
    cacheKey := fmt.Sprintf("%s:%s:%s", namespace, key, env)
    if val, ok := c.cache.Load(cacheKey); ok {
        entry := val.(*CacheEntry)
        if time.Now().Before(entry.ExpiresAt) {
            return entry.Value, true
        }
        c.cache.Delete(cacheKey)
    }
    return nil, false
}
```

## Error Handling Best Practices

### Python

```python
import logging
from requests.exceptions import Timeout, ConnectionError

logger = logging.getLogger(__name__)

def get_config_safely(namespace, key, env, default=None):
    try:
        config = client.get_config(namespace, key, env)
        return config['value'] if config else default
    except NotFoundError:
        logger.info(f"Config not found: {namespace}/{key}, using default")
        return default
    except RateLimitError:
        logger.warning("Rate limited, retrying after delay")
        time.sleep(60)
        return get_config_safely(namespace, key, env, default)
    except AuthenticationError:
        logger.error("Authentication failed")
        raise
    except (Timeout, ConnectionError) as e:
        logger.error(f"Network error: {e}")
        return default
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return default
```

### JavaScript

```javascript
async function getConfigSafely(namespace, key, env, defaultValue = null) {
  try {
    const config = await client.getConfig(namespace, key, env);
    return config ? config.value : defaultValue;
  } catch (error) {
    if (error instanceof NotFoundError) {
      console.info(`Config not found: ${namespace}/${key}, using default`);
      return defaultValue;
    } else if (error instanceof RateLimitError) {
      console.warn('Rate limited, retrying after delay');
      await new Promise(resolve => setTimeout(resolve, 60000));
      return getConfigSafely(namespace, key, env, defaultValue);
    } else if (error instanceof AuthenticationError) {
      console.error('Authentication failed');
      throw error;
    } else {
      console.error(`Unexpected error: ${error.message}`);
      return defaultValue;
    }
  }
}
```

### Go

```go
func getConfigSafely(client *LLMConfigClient, namespace, key, env string, defaultValue interface{}) (interface{}, error) {
    config, err := client.GetConfig(namespace, key, env, false)
    if err != nil {
        if clientErr, ok := err.(*ConfigClientError); ok {
            switch clientErr.StatusCode {
            case 404:
                log.Printf("Config not found: %s/%s, using default", namespace, key)
                return defaultValue, nil
            case 429:
                log.Println("Rate limited, retrying after delay")
                time.Sleep(60 * time.Second)
                return getConfigSafely(client, namespace, key, env, defaultValue)
            case 401:
                log.Println("Authentication failed")
                return nil, err
            default:
                log.Printf("API error: %v", err)
                return defaultValue, nil
            }
        }
        log.Printf("Unexpected error: %v", err)
        return defaultValue, nil
    }

    if config == nil {
        return defaultValue, nil
    }

    return config.Value, nil
}
```

## Testing

### Unit Tests

**Python (pytest)**:
```python
import pytest
from unittest.mock import Mock, patch

def test_get_config():
    client = LLMConfigClient(base_url="http://test", token="test")

    with patch.object(client, '_request') as mock_request:
        mock_request.return_value = {
            'key': 'model',
            'value': 'gpt-4',
            'version': 1
        }

        config = client.get_config('app/llm', 'model', 'production')
        assert config['value'] == 'gpt-4'
```

**JavaScript (Jest)**:
```javascript
const { LLMConfigClient } = require('./nodejs-client');

test('get config', async () => {
  const client = new LLMConfigClient({
    baseUrl: 'http://test',
    token: 'test'
  });

  // Mock axios
  client.client.get = jest.fn().mockResolvedValue({
    data: { key: 'model', value: 'gpt-4', version: 1 }
  });

  const config = await client.getConfig('app/llm', 'model', 'production');
  expect(config.value).toBe('gpt-4');
});
```

**Go (testing)**:
```go
func TestGetConfig(t *testing.T) {
    // Create test server
    ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        json.NewEncoder(w).Encode(ConfigResponse{
            Key:   "model",
            Value: "gpt-4",
            Version: 1,
        })
    }))
    defer ts.Close()

    client := NewLLMConfigClient(ts.URL, "test-token")
    config, err := client.GetConfig("app/llm", "model", "production", false)

    assert.NoError(t, err)
    assert.Equal(t, "gpt-4", config.Value)
}
```

## Additional Resources

- [API Reference](../README.md) - Complete API documentation
- [Authentication Guide](../authentication.md) - Authentication setup
- [Error Handling Guide](../errors.md) - Error handling patterns
- [Rate Limiting Guide](../rate-limits.md) - Rate limiting details
- [OpenAPI Specification](../openapi.yaml) - API specification

## Contributing

To add a new example:

1. Create the example file in this directory
2. Follow the existing structure and patterns
3. Include comprehensive error handling
4. Add documentation in this README
5. Test thoroughly with the API server

## Support

For issues or questions:
- GitHub Issues: https://github.com/llm-devops/llm-config-manager/issues
- Discussions: https://github.com/llm-devops/llm-config-manager/discussions

---

**Version**: 0.5.0 | **Last Updated**: 2024-01-21
