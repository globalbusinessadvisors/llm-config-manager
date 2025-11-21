# Error Handling Guide

This document describes the error handling strategy for the LLM Config Manager platform.

## Table of Contents

- [Error Categories](#error-categories)
- [Error Types](#error-types)
- [Error Responses](#error-responses)
- [Error Codes](#error-codes)
- [Best Practices](#best-practices)
- [Recovery Strategies](#recovery-strategies)

## Error Categories

Errors are categorized into four main types:

### 1. Client Errors (4xx)

Errors caused by invalid client requests. These are **not retriable**.

- Invalid input data
- Missing required parameters
- Authorization failures
- Resource not found

**Handling**: Fix the request and retry.

### 2. Server Errors (5xx)

Errors caused by server-side issues. These **may be retriable**.

- Internal server errors
- Database connection failures
- Temporary unavailability

**Handling**: Implement exponential backoff and retry.

### 3. Validation Errors

Errors in data validation before processing.

- Schema validation failures
- Type mismatches
- Constraint violations

**Handling**: Fix the data and resubmit.

### 4. System Errors

Low-level system errors.

- Disk full
- Out of memory
- Permission denied

**Handling**: Requires administrative intervention.

## Error Types

### Core Module Errors (`ConfigError`)

```rust
pub enum ConfigError {
    // Validation Errors (Client)
    ValidationError(String),
    InvalidNamespace(String),
    InvalidKey(String),
    InvalidValue(String),

    // Not Found Errors (Client)
    NotFound { namespace: String, key: String, env: String },
    VersionNotFound(u64),

    // Permission Errors (Client)
    PermissionDenied { user: String, operation: String },

    // Storage Errors (Server - Retriable)
    StorageError(String),
    IoError(std::io::Error),

    // Serialization Errors (Server)
    SerializationError(String),

    // Crypto Errors (Server)
    EncryptionError(String),
    DecryptionError(String),

    // Internal Errors (Server)
    InternalError(String),
}
```

### RBAC Module Errors (`RbacError`)

```rust
pub enum RbacError {
    // Client Errors
    AccessDenied(String),
    UserNotFound(String),
    RoleNotFound(String),
    InvalidRole(String),
    InvalidScope(String),

    // Server Errors
    InternalError(String),
}
```

### Crypto Module Errors (`CryptoError`)

```rust
pub enum CryptoError {
    // Client Errors
    InvalidKey(String),
    InvalidAlgorithm(String),

    // Server Errors
    EncryptionFailed(String),
    DecryptionFailed(String),
    KeyGenerationFailed(String),

    // Internal Errors
    InternalError(String),
}
```

### Audit Module Errors (`AuditError`)

```rust
pub enum AuditError {
    // Storage Errors (Server)
    Storage(String),
    IoError(std::io::Error),

    // Query Errors (Client)
    InvalidQuery(String),
    InvalidTimeRange(String),

    // Internal Errors
    InternalError(String),
}
```

### Cache Module Errors (`CacheError`)

```rust
pub enum CacheError {
    // Client Errors
    CacheMiss(String),
    InvalidKey(String),

    // Storage Errors (Server)
    StorageError(String),
    IoError(std::io::Error),

    // Serialization Errors (Server)
    SerializationError(String),

    // Internal Errors
    InternalError(String),
}
```

## Error Responses

### API Error Response Format

All API errors follow a consistent JSON structure:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid configuration key format",
    "details": {
      "field": "key",
      "reason": "Key must match pattern: [a-zA-Z0-9_.-]+"
    },
    "timestamp": "2024-01-15T10:30:00Z",
    "request_id": "req_abc123",
    "retriable": false
  }
}
```

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `code` | string | Error code (see [Error Codes](#error-codes)) |
| `message` | string | Human-readable error message |
| `details` | object | Additional error context |
| `timestamp` | string | ISO 8601 timestamp |
| `request_id` | string | Request correlation ID |
| `retriable` | boolean | Whether the request can be retried |

### HTTP Status Codes

| Status | Category | Description |
|--------|----------|-------------|
| 400 | Bad Request | Invalid request format |
| 401 | Unauthorized | Authentication required |
| 403 | Forbidden | Permission denied |
| 404 | Not Found | Resource not found |
| 409 | Conflict | Resource conflict (e.g., version mismatch) |
| 422 | Unprocessable Entity | Validation error |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Unexpected server error |
| 503 | Service Unavailable | Temporary unavailability |

## Error Codes

### Client Errors (4xx)

| Code | HTTP | Description |
|------|------|-------------|
| `INVALID_REQUEST` | 400 | Malformed request |
| `VALIDATION_ERROR` | 422 | Validation failure |
| `INVALID_NAMESPACE` | 422 | Invalid namespace format |
| `INVALID_KEY` | 422 | Invalid key format |
| `INVALID_VALUE` | 422 | Invalid value format |
| `UNAUTHORIZED` | 401 | Authentication required |
| `PERMISSION_DENIED` | 403 | Insufficient permissions |
| `NOT_FOUND` | 404 | Resource not found |
| `VERSION_NOT_FOUND` | 404 | Version not found |
| `CONFLICT` | 409 | Version conflict |
| `RATE_LIMIT_EXCEEDED` | 429 | Too many requests |

### Server Errors (5xx)

| Code | HTTP | Description |
|------|------|-------------|
| `INTERNAL_ERROR` | 500 | Internal server error |
| `STORAGE_ERROR` | 500 | Storage operation failed |
| `ENCRYPTION_ERROR` | 500 | Encryption failed |
| `DECRYPTION_ERROR` | 500 | Decryption failed |
| `SERVICE_UNAVAILABLE` | 503 | Service temporarily unavailable |
| `DATABASE_ERROR` | 503 | Database connection error |

## Best Practices

### 1. Error Context

Always provide context in error messages:

**Bad:**
```rust
Err(ConfigError::ValidationError("Invalid value".into()))
```

**Good:**
```rust
Err(ConfigError::ValidationError(format!(
    "Invalid value for key '{}': expected integer, got string '{}'",
    key, value
)))
```

### 2. Error Wrapping

Use error context to preserve error chains:

```rust
use anyhow::Context;

fn load_config(path: &Path) -> Result<Config> {
    let content = fs::read_to_string(path)
        .context(format!("Failed to read config file: {}", path.display()))?;

    serde_yaml::from_str(&content)
        .context("Failed to parse config file as YAML")
}
```

### 3. Error Logging

Log errors with appropriate levels:

```rust
use tracing::{error, warn, debug};

match operation() {
    Ok(result) => Ok(result),
    Err(e) if e.is_retriable() => {
        warn!("Retriable error occurred: {}", e);
        Err(e)
    }
    Err(e) => {
        error!("Fatal error occurred: {:?}", e);
        Err(e)
    }
}
```

### 4. Error Recovery

Implement recovery strategies for retriable errors:

```rust
use tokio::time::{sleep, Duration};

async fn retry_with_backoff<F, T, E>(
    mut operation: F,
    max_attempts: u32,
) -> Result<T, E>
where
    F: FnMut() -> Result<T, E>,
    E: std::error::Error,
{
    let mut attempt = 0;
    loop {
        match operation() {
            Ok(result) => return Ok(result),
            Err(e) if attempt < max_attempts - 1 => {
                let backoff = Duration::from_millis(100 * 2_u64.pow(attempt));
                warn!("Attempt {} failed: {}. Retrying in {:?}", attempt + 1, e, backoff);
                sleep(backoff).await;
                attempt += 1;
            }
            Err(e) => return Err(e),
        }
    }
}
```

### 5. User-Friendly Messages

Provide actionable error messages:

**Bad:**
```
Error: Storage error
```

**Good:**
```
Failed to save configuration: disk quota exceeded.
Please free up space or increase quota for /var/lib/llm-config/data
```

## Recovery Strategies

### Retry Logic

For transient errors, implement exponential backoff:

```rust
pub struct RetryPolicy {
    max_attempts: u32,
    initial_backoff_ms: u64,
    max_backoff_ms: u64,
    backoff_multiplier: f64,
}

impl Default for RetryPolicy {
    fn default() -> Self {
        Self {
            max_attempts: 3,
            initial_backoff_ms: 100,
            max_backoff_ms: 10_000,
            backoff_multiplier: 2.0,
        }
    }
}
```

### Circuit Breaker

Prevent cascading failures:

```rust
pub struct CircuitBreaker {
    failure_threshold: u32,
    success_threshold: u32,
    timeout: Duration,
    state: Arc<Mutex<CircuitState>>,
}

enum CircuitState {
    Closed { failures: u32 },
    Open { opened_at: Instant },
    HalfOpen { successes: u32 },
}
```

### Graceful Degradation

Fall back to degraded functionality:

```rust
match cache.get(key).await {
    Ok(value) => Ok(value),
    Err(CacheError::CacheMiss(_)) => {
        // Cache miss - fetch from storage
        warn!("Cache miss for key: {}", key);
        storage.get(key).await
    }
    Err(e) => {
        // Cache error - bypass cache
        error!("Cache error, bypassing: {}", e);
        storage.get(key).await
    }
}
```

### Failover

Switch to backup systems:

```rust
let primary_result = primary_storage.get(key).await;
match primary_result {
    Ok(value) => Ok(value),
    Err(e) if is_transient(&e) => {
        warn!("Primary storage failed, trying backup: {}", e);
        backup_storage.get(key).await
    }
    Err(e) => Err(e),
}
```

## Error Monitoring

### Metrics

Track error rates and types:

```rust
use prometheus::{Counter, Histogram};

lazy_static! {
    static ref ERROR_COUNTER: Counter = Counter::new(
        "errors_total",
        "Total number of errors"
    ).unwrap();

    static ref ERROR_BY_TYPE: CounterVec = CounterVec::new(
        Opts::new("errors_by_type", "Errors by type"),
        &["error_type"]
    ).unwrap();
}

// Usage
ERROR_COUNTER.inc();
ERROR_BY_TYPE.with_label_values(&["validation"]).inc();
```

### Alerting

Set up alerts for critical errors:

- **High error rate**: > 5% of requests fail
- **Repeated failures**: Same operation fails 10+ times
- **Critical errors**: Encryption failures, data loss
- **Resource errors**: Disk full, OOM

### Error Aggregation

Group similar errors:

```rust
pub struct ErrorAggregator {
    errors: HashMap<String, ErrorStats>,
}

struct ErrorStats {
    count: u64,
    first_seen: DateTime<Utc>,
    last_seen: DateTime<Utc>,
    sample_message: String,
}
```

## Testing Error Handling

### Unit Tests

Test all error paths:

```rust
#[test]
fn test_invalid_key_error() {
    let result = validate_key("invalid key with spaces");
    assert!(result.is_err());
    assert!(matches!(result, Err(ConfigError::InvalidKey(_))));
}

#[test]
fn test_not_found_error() {
    let manager = ConfigManager::new(temp_dir()).unwrap();
    let result = manager.get("ns", "nonexistent", Environment::Development);
    assert!(result.unwrap().is_none());
}
```

### Integration Tests

Test error propagation:

```rust
#[tokio::test]
async fn test_storage_error_propagation() {
    // Simulate disk full
    let result = manager.set("ns", "key", value, env, "user").await;
    assert!(matches!(result, Err(ConfigError::StorageError(_))));
}
```

### Chaos Testing

Inject failures to test resilience:

```rust
#[cfg(feature = "chaos")]
pub fn inject_random_failure() -> Result<()> {
    if rand::random::<f64>() < 0.1 {
        Err(ConfigError::StorageError("Simulated failure".into()))
    } else {
        Ok(())
    }
}
```

## Examples

### Client Error Handling

```rust
match client.get_config("prod/api", "endpoint").await {
    Ok(config) => println!("Config: {:?}", config),
    Err(e) if e.is_not_found() => {
        println!("Config not found, using default");
    }
    Err(e) if e.is_permission_denied() => {
        eprintln!("Permission denied. Contact admin.");
    }
    Err(e) => {
        eprintln!("Failed to fetch config: {}", e);
    }
}
```

### Server Error Handling

```rust
async fn handle_request(req: Request) -> Result<Response> {
    let config = get_config(&req.namespace, &req.key, &req.env)
        .await
        .map_err(|e| {
            error!(
                request_id = %req.id,
                error = %e,
                "Failed to get configuration"
            );
            InternalError::from(e)
        })?;

    Ok(Response::success(config))
}
```

### Error Recovery

```rust
async fn resilient_operation() -> Result<Value> {
    retry_with_backoff(
        || async {
            storage.get(key).await
        },
        RetryPolicy::default(),
    )
    .await
    .or_else(|e| {
        warn!("All retries failed, using cache: {}", e);
        cache.get(key)
    })
    .or_else(|e| {
        warn!("Cache also failed, using default: {}", e);
        Ok(default_value())
    })
}
```

## Additional Resources

- [Rust Error Handling Book](https://doc.rust-lang.org/book/ch09-00-error-handling.html)
- [anyhow Crate Documentation](https://docs.rs/anyhow/)
- [thiserror Crate Documentation](https://docs.rs/thiserror/)
- [Error Handling Patterns](https://doc.rust-lang.org/book/ch09-02-recoverable-errors-with-result.html)
