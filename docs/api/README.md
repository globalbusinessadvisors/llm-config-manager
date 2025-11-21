# LLM Config Manager API Reference

> Enterprise-grade REST API for configuration management

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Base URL](#base-url)
- [Authentication](#authentication)
- [Rate Limiting](#rate-limiting)
- [API Endpoints](#api-endpoints)
  - [Health Check](#health-check)
  - [Configuration Management](#configuration-management)
  - [Version History](#version-history)
- [Data Models](#data-models)
- [Error Handling](#error-handling)
- [Code Examples](#code-examples)
- [Best Practices](#best-practices)

## Overview

The LLM Config Manager API provides a RESTful interface for managing configurations across multiple environments. Built with Rust and Axum, it offers high performance, strong security guarantees, and enterprise-grade features.

### Key Features

- **Multi-Environment Support**: Manage configurations for base, development, staging, production, and edge environments
- **Type-Safe Values**: Support for strings, integers, floats, booleans, arrays, and objects
- **Secret Management**: Encrypted storage for sensitive data (API keys, passwords, tokens)
- **Version Control**: Complete history tracking with rollback capabilities
- **High Performance**: <10ms response times with multi-tier caching
- **Enterprise Security**: Rate limiting, input validation, attack prevention
- **RBAC Ready**: Role-based access control with audit logging

### Architecture

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ HTTPS/TLS
       ▼
┌─────────────┐
│  API Layer  │  ← Rate Limiting, Auth, Validation
└──────┬──────┘
       │
┌──────┴──────┐
│ Core Manager│  ← Business Logic, Versioning
└──────┬──────┘
       │
┌──────┴──────┐
│ Cache Layer │  ← L1 (Memory) + L2 (Redis)
└──────┬──────┘
       │
┌──────┴──────┐
│   Storage   │  ← File/PostgreSQL/MySQL
└─────────────┘
```

## Quick Start

### 1. Start the API Server

```bash
# Start with default settings
llm-config-server --host 0.0.0.0 --port 8080

# Start with custom security settings
llm-config-server \
  --host 0.0.0.0 \
  --port 8080 \
  --enable-security true \
  --rate-limit-rps 100
```

### 2. Health Check

```bash
curl http://localhost:8080/health
```

### 3. Set a Configuration

```bash
curl -X POST http://localhost:8080/api/v1/configs/app/llm/model \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-token" \
  -d '{
    "value": "gpt-4",
    "env": "production",
    "user": "admin"
  }'
```

### 4. Get a Configuration

```bash
curl http://localhost:8080/api/v1/configs/app/llm/model?env=production \
  -H "Authorization: Bearer your-token"
```

## Base URL

The API is served under the `/api/v1` prefix:

- **Production**: `https://api.llm-config-manager.io/api/v1`
- **Staging**: `https://staging-api.llm-config-manager.io/api/v1`
- **Local**: `http://localhost:8080/api/v1`

## Authentication

### Current Implementation

The API currently uses simple header-based authentication for development:

```http
Authorization: Bearer <your-token>
X-User-ID: <user-identifier>
```

### Production Recommendations

For production deployments, implement one of:

1. **OAuth 2.0**: Industry standard, supports multiple grant types
2. **JWT Tokens**: Stateless, self-contained, scalable
3. **API Keys**: Simple, suitable for service-to-service communication
4. **mTLS**: Mutual TLS for high-security environments

Example with JWT:

```bash
# Get JWT token
TOKEN=$(curl -X POST https://auth.example.com/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "secret"}' \
  | jq -r '.token')

# Use token in API requests
curl http://localhost:8080/api/v1/configs/app/llm/model?env=production \
  -H "Authorization: Bearer $TOKEN"
```

See [Authentication Guide](authentication.md) for detailed implementation guidance.

## Rate Limiting

The API implements adaptive rate limiting to protect against abuse:

### Limits

| User Type | Requests/Second | Burst Size | Per-IP Limit |
|-----------|-----------------|------------|--------------|
| Authenticated | 100 | 50 | 10 req/s |
| Unauthenticated | 10 | 10 | 10 req/s |

### Rate Limit Headers

All responses include rate limit information:

```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1634567890
```

### Handling Rate Limits

When rate limited, the API returns `429 Too Many Requests`:

```json
{
  "error": "Too Many Requests",
  "message": "Rate limit exceeded. Please try again later"
}
```

Response includes a `Retry-After` header indicating when to retry.

### IP Banning

- **Threshold**: 10 violations within the time window
- **Ban Duration**: 1 hour (configurable)
- **Ban Response**: HTTP 429 with message "IP address is temporarily banned"

See [Rate Limiting Guide](rate-limits.md) for detailed documentation.

## API Endpoints

### Health Check

#### GET /health

Check the health status of the API service.

**No authentication required. Not subject to rate limiting.**

```bash
curl http://localhost:8080/health
```

**Response** (200 OK):

```json
{
  "status": "healthy",
  "service": "llm-config-manager",
  "version": "0.5.0"
}
```

**Use Cases**:
- Kubernetes liveness probes
- Load balancer health checks
- Monitoring systems
- Deployment verification

---

### Configuration Management

#### GET /api/v1/configs/{namespace}/{key}

Retrieve a specific configuration value.

**Parameters**:
- `namespace` (path, required): Configuration namespace (e.g., `app/llm`)
- `key` (path, required): Configuration key (e.g., `model`)
- `env` (query, optional): Environment (default: `development`)
- `with_overrides` (query, optional): Include environment overrides (default: `false`)

**Example**:

```bash
curl http://localhost:8080/api/v1/configs/app/llm/model?env=production \
  -H "Authorization: Bearer token"
```

**Response** (200 OK):

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "namespace": "app/llm",
  "key": "model",
  "value": "gpt-4",
  "environment": "production",
  "version": 3,
  "metadata": {
    "created_at": "2024-01-15T10:30:00Z",
    "created_by": "admin",
    "updated_at": "2024-01-20T14:45:00Z",
    "updated_by": "devops-team",
    "tags": ["llm", "model"],
    "description": "Primary LLM model for production"
  }
}
```

**Error Responses**:
- `400 Bad Request`: Invalid parameters
- `404 Not Found`: Configuration doesn't exist
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server error

---

#### POST /api/v1/configs/{namespace}/{key}

Create or update a configuration value.

**Parameters**:
- `namespace` (path, required): Configuration namespace
- `key` (path, required): Configuration key

**Request Body**:

```json
{
  "value": "gpt-4",
  "env": "production",
  "user": "admin",
  "secret": false
}
```

**Field Descriptions**:
- `value` (required): Configuration value (any JSON type)
- `env` (required): Target environment
- `user` (optional): User making the change (default: `"api-user"`)
- `secret` (optional): Encrypt as secret (default: `false`)

**Examples**:

**String Value**:
```bash
curl -X POST http://localhost:8080/api/v1/configs/app/llm/model \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer token" \
  -d '{
    "value": "gpt-4",
    "env": "production",
    "user": "admin"
  }'
```

**Number Value**:
```bash
curl -X POST http://localhost:8080/api/v1/configs/app/llm/temperature \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer token" \
  -d '{
    "value": 0.7,
    "env": "production",
    "user": "admin"
  }'
```

**Object Value**:
```bash
curl -X POST http://localhost:8080/api/v1/configs/app/llm/settings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer token" \
  -d '{
    "value": {
      "temperature": 0.7,
      "max_tokens": 2000,
      "top_p": 0.9
    },
    "env": "production",
    "user": "admin"
  }'
```

**Secret Value** (encrypted):
```bash
curl -X POST http://localhost:8080/api/v1/configs/app/llm/api_key \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer token" \
  -d '{
    "value": "sk-proj-abc123...",
    "env": "production",
    "user": "admin",
    "secret": true
  }'
```

**Response** (200 OK):

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "namespace": "app/llm",
  "key": "model",
  "value": "gpt-4",
  "environment": "production",
  "version": 4,
  "metadata": {
    "created_at": "2024-01-15T10:30:00Z",
    "created_by": "admin",
    "updated_at": "2024-01-21T10:00:00Z",
    "updated_by": "admin",
    "tags": [],
    "description": null
  }
}
```

**Error Responses**:
- `400 Bad Request`: Invalid request body or parameters
- `413 Payload Too Large`: Request exceeds 10MB limit
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server error

---

#### DELETE /api/v1/configs/{namespace}/{key}

Delete a configuration entry.

**Warning**: This operation is permanent and cannot be undone.

**Parameters**:
- `namespace` (path, required): Configuration namespace
- `key` (path, required): Configuration key
- `env` (query, optional): Environment (default: `development`)

**Example**:

```bash
curl -X DELETE http://localhost:8080/api/v1/configs/app/llm/old_config?env=development \
  -H "Authorization: Bearer token"
```

**Response** (204 No Content):

Empty response body on success.

**Error Responses**:
- `400 Bad Request`: Invalid parameters
- `404 Not Found`: Configuration doesn't exist
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server error

---

#### GET /api/v1/configs/{namespace}

List all configuration keys in a namespace.

**Parameters**:
- `namespace` (path, required): Configuration namespace
- `env` (query, optional): Environment (default: `development`)

**Example**:

```bash
curl http://localhost:8080/api/v1/configs/app/llm?env=production \
  -H "Authorization: Bearer token"
```

**Response** (200 OK):

```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "namespace": "app/llm",
    "key": "model",
    "value": "gpt-4",
    "environment": "production",
    "version": 3,
    "metadata": {
      "created_at": "2024-01-15T10:30:00Z",
      "created_by": "admin",
      "updated_at": "2024-01-20T14:45:00Z",
      "updated_by": "devops-team",
      "tags": ["llm", "model"],
      "description": "Primary LLM model"
    }
  },
  {
    "id": "660e8400-e29b-41d4-a716-446655440001",
    "namespace": "app/llm",
    "key": "api_key",
    "value": "<encrypted>",
    "environment": "production",
    "version": 1,
    "metadata": {
      "created_at": "2024-01-15T10:30:00Z",
      "created_by": "admin",
      "updated_at": "2024-01-15T10:30:00Z",
      "updated_by": "admin",
      "tags": ["secret"],
      "description": "OpenAI API key"
    }
  }
]
```

**Note**: Secret values are displayed as `"<encrypted>"` and never exposed through the API.

**Error Responses**:
- `400 Bad Request`: Invalid namespace
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server error

---

### Version History

#### GET /api/v1/configs/{namespace}/{key}/history

Retrieve the complete version history for a configuration.

**Parameters**:
- `namespace` (path, required): Configuration namespace
- `key` (path, required): Configuration key
- `env` (query, optional): Environment (default: `development`)

**Example**:

```bash
curl http://localhost:8080/api/v1/configs/app/llm/model/history?env=production \
  -H "Authorization: Bearer token"
```

**Response** (200 OK):

```json
[
  {
    "version": 3,
    "value": "gpt-4",
    "created_at": "2024-01-20T14:45:00Z",
    "created_by": "devops-team",
    "change_description": "Upgraded to GPT-4"
  },
  {
    "version": 2,
    "value": "gpt-3.5-turbo",
    "created_at": "2024-01-18T09:20:00Z",
    "created_by": "admin",
    "change_description": "Updated model"
  },
  {
    "version": 1,
    "value": "gpt-3.5",
    "created_at": "2024-01-15T10:30:00Z",
    "created_by": "admin",
    "change_description": null
  }
]
```

Versions are returned in reverse chronological order (newest first).

**Error Responses**:
- `400 Bad Request`: Invalid parameters
- `404 Not Found`: Configuration doesn't exist
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server error

---

#### POST /api/v1/configs/{namespace}/{key}/rollback/{version}

Rollback a configuration to a specific version.

This creates a new version with the value from the specified historical version.

**Parameters**:
- `namespace` (path, required): Configuration namespace
- `key` (path, required): Configuration key
- `version` (path, required): Version number to rollback to
- `env` (query, optional): Environment (default: `development`)

**Example**:

```bash
curl -X POST http://localhost:8080/api/v1/configs/app/llm/model/rollback/2?env=production \
  -H "Authorization: Bearer token"
```

**Response** (200 OK):

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "namespace": "app/llm",
  "key": "model",
  "value": "gpt-3.5-turbo",
  "environment": "production",
  "version": 4,
  "metadata": {
    "created_at": "2024-01-15T10:30:00Z",
    "created_by": "admin",
    "updated_at": "2024-01-21T11:00:00Z",
    "updated_by": "system",
    "tags": [],
    "description": null
  }
}
```

**Note**: The rolled-back configuration gets a new version number (incremented), not the old version number.

**Error Responses**:
- `400 Bad Request`: Invalid parameters
- `404 Not Found`: Configuration or version doesn't exist
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server error

---

## Data Models

### Environment

Supported environments for configuration isolation:

```typescript
type Environment =
  | "base"        // Base configurations shared across all environments
  | "development" // Development environment (default)
  | "staging"     // Staging/pre-production environment
  | "production"  // Production environment
  | "edge"        // Edge/CDN deployments
```

### ConfigValue

Configuration values support multiple types:

```typescript
type ConfigValue =
  | string          // "gpt-4"
  | number          // 42, 0.7
  | boolean         // true, false
  | Array<any>      // [1, 2, 3]
  | Object          // {"key": "value"}
  | Secret          // Encrypted data (displayed as "<encrypted>")
```

### ConfigMetadata

Metadata tracking for audit and governance:

```typescript
interface ConfigMetadata {
  created_at: string;      // ISO 8601 timestamp
  created_by: string;      // User who created
  updated_at: string;      // ISO 8601 timestamp
  updated_by: string;      // User who last updated
  tags: string[];          // Tags for categorization
  description?: string;    // Optional description
}
```

### ConfigResponse

Complete configuration entry:

```typescript
interface ConfigResponse {
  id: string;              // UUID
  namespace: string;       // "app/llm"
  key: string;             // "model"
  value: ConfigValue;      // Any supported type
  environment: Environment;
  version: number;         // Current version (starts at 1)
  metadata: ConfigMetadata;
}
```

### VersionEntry

Historical version information:

```typescript
interface VersionEntry {
  version: number;
  value: ConfigValue;
  created_at: string;
  created_by: string;
  change_description?: string;
}
```

## Error Handling

All errors follow a consistent structure:

```json
{
  "error": "Error Type",
  "message": "Detailed error message"
}
```

### HTTP Status Codes

| Code | Description | Example |
|------|-------------|---------|
| 200 | Success | Configuration retrieved |
| 204 | Success (No Content) | Configuration deleted |
| 400 | Bad Request | Invalid parameters or request body |
| 401 | Unauthorized | Missing or invalid authentication |
| 403 | Forbidden | Insufficient permissions |
| 404 | Not Found | Configuration doesn't exist |
| 413 | Payload Too Large | Request exceeds 10MB |
| 426 | Upgrade Required | HTTPS required |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Unexpected server error |

See [Error Handling Guide](errors.md) for detailed error documentation.

## Code Examples

### cURL

**Set Configuration**:
```bash
curl -X POST http://localhost:8080/api/v1/configs/app/llm/model \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer token" \
  -d '{"value": "gpt-4", "env": "production", "user": "admin"}'
```

**Get Configuration**:
```bash
curl http://localhost:8080/api/v1/configs/app/llm/model?env=production \
  -H "Authorization: Bearer token"
```

### Python

```python
import requests

BASE_URL = "http://localhost:8080/api/v1"
TOKEN = "your-token"

headers = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json"
}

# Set configuration
response = requests.post(
    f"{BASE_URL}/configs/app/llm/model",
    headers=headers,
    json={
        "value": "gpt-4",
        "env": "production",
        "user": "admin"
    }
)
config = response.json()
print(f"Set config version: {config['version']}")

# Get configuration
response = requests.get(
    f"{BASE_URL}/configs/app/llm/model",
    headers=headers,
    params={"env": "production"}
)
config = response.json()
print(f"Model: {config['value']}")

# Get history
response = requests.get(
    f"{BASE_URL}/configs/app/llm/model/history",
    headers=headers,
    params={"env": "production"}
)
history = response.json()
for version in history:
    print(f"Version {version['version']}: {version['value']}")
```

### JavaScript/Node.js

```javascript
const axios = require('axios');

const BASE_URL = 'http://localhost:8080/api/v1';
const TOKEN = 'your-token';

const client = axios.create({
  baseURL: BASE_URL,
  headers: {
    'Authorization': `Bearer ${TOKEN}`,
    'Content-Type': 'application/json'
  }
});

// Set configuration
async function setConfig() {
  const response = await client.post('/configs/app/llm/model', {
    value: 'gpt-4',
    env: 'production',
    user: 'admin'
  });
  console.log(`Set config version: ${response.data.version}`);
}

// Get configuration
async function getConfig() {
  const response = await client.get('/configs/app/llm/model', {
    params: { env: 'production' }
  });
  console.log(`Model: ${response.data.value}`);
}

// Get history
async function getHistory() {
  const response = await client.get('/configs/app/llm/model/history', {
    params: { env: 'production' }
  });
  response.data.forEach(version => {
    console.log(`Version ${version.version}: ${version.value}`);
  });
}

// Error handling
async function example() {
  try {
    await setConfig();
    await getConfig();
    await getHistory();
  } catch (error) {
    if (error.response) {
      console.error(`Error ${error.response.status}: ${error.response.data.message}`);
    } else {
      console.error('Network error:', error.message);
    }
  }
}

example();
```

See [examples directory](examples/) for complete code samples in multiple languages.

## Best Practices

### 1. Use Appropriate Environments

```bash
# Development configs
curl -X POST .../configs/app/llm/model -d '{"value": "gpt-3.5-turbo", "env": "development"}'

# Production configs (with review process)
curl -X POST .../configs/app/llm/model -d '{"value": "gpt-4", "env": "production"}'
```

### 2. Always Use Secrets for Sensitive Data

```bash
# ✅ GOOD: Encrypted secret
curl -X POST .../configs/app/llm/api_key \
  -d '{"value": "sk-proj-...", "env": "production", "secret": true}'

# ❌ BAD: Plain text
curl -X POST .../configs/app/llm/api_key \
  -d '{"value": "sk-proj-...", "env": "production", "secret": false}'
```

### 3. Use Descriptive Namespaces

```bash
# ✅ GOOD: Clear hierarchy
/configs/app/llm/model
/configs/database/postgres/connection_string
/configs/features/experimental/new_ui

# ❌ BAD: Unclear structure
/configs/model
/configs/db
/configs/flag1
```

### 4. Implement Proper Error Handling

```python
import requests
from requests.exceptions import HTTPError, Timeout

def get_config(namespace, key, env="production"):
    try:
        response = requests.get(
            f"{BASE_URL}/configs/{namespace}/{key}",
            params={"env": env},
            headers=headers,
            timeout=5
        )
        response.raise_for_status()
        return response.json()

    except HTTPError as e:
        if e.response.status_code == 404:
            # Config doesn't exist - use default
            return {"value": "default-value"}
        elif e.response.status_code == 429:
            # Rate limited - implement backoff
            time.sleep(int(e.response.headers.get('Retry-After', 60)))
            return get_config(namespace, key, env)
        else:
            raise

    except Timeout:
        # Timeout - use cached value or default
        return get_cached_config(namespace, key, env)
```

### 5. Monitor Rate Limits

```python
def check_rate_limit(response):
    limit = int(response.headers.get('X-RateLimit-Limit', 0))
    remaining = int(response.headers.get('X-RateLimit-Remaining', 0))

    if remaining < limit * 0.1:  # Less than 10% remaining
        print(f"Warning: Rate limit low ({remaining}/{limit})")
        # Consider implementing request throttling
```

### 6. Use Version History for Auditing

```bash
# Check who changed what and when
curl http://localhost:8080/api/v1/configs/app/llm/model/history?env=production

# Rollback if needed
curl -X POST http://localhost:8080/api/v1/configs/app/llm/model/rollback/2?env=production
```

### 7. Cache Configurations Client-Side

```python
import time
from functools import lru_cache

@lru_cache(maxsize=128)
def get_config_cached(namespace, key, env, ttl_hash):
    """Cached config retrieval with TTL"""
    return get_config(namespace, key, env)

def get_ttl_hash(seconds=300):
    """Return hash that changes every `seconds`"""
    return round(time.time() / seconds)

# Usage
config = get_config_cached("app/llm", "model", "production", get_ttl_hash())
```

### 8. Implement Graceful Degradation

```python
def get_config_with_fallback(namespace, key, env, default):
    """Get config with fallback to default"""
    try:
        response = get_config(namespace, key, env)
        return response['value']
    except Exception as e:
        logging.warning(f"Failed to get config {namespace}:{key}, using default: {e}")
        return default

# Usage
model = get_config_with_fallback("app/llm", "model", "production", "gpt-3.5-turbo")
```

## Additional Resources

- **[OpenAPI Specification](openapi.yaml)**: Complete API specification in OpenAPI 3.0 format
- **[Authentication Guide](authentication.md)**: Detailed authentication implementation
- **[Error Handling Guide](errors.md)**: Comprehensive error documentation
- **[Rate Limiting Guide](rate-limits.md)**: Rate limiting details and best practices
- **[Code Examples](examples/)**: Complete integration examples
- **[Security Guide](../SECURITY.md)**: Security best practices and compliance
- **[Architecture Overview](../ARCHITECTURE.md)**: System architecture and design

## Support

### Community
- **GitHub Issues**: https://github.com/llm-devops/llm-config-manager/issues
- **Discussions**: https://github.com/llm-devops/llm-config-manager/discussions
- **Discord**: https://discord.gg/llm-config-manager

### Enterprise
- **Email**: enterprise@llm-config-manager.io
- **Security**: security@llm-config-manager.io
- **Support**: support@llm-config-manager.io

---

**Version**: 0.5.0 | **Last Updated**: 2024-01-21 | [Report Issues](https://github.com/llm-devops/llm-config-manager/issues)
