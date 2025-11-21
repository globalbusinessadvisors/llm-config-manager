# Configuration Guide

Complete reference for configuring LLM Config Manager for all deployment scenarios.

## Table of Contents

1. [Configuration Overview](#configuration-overview)
2. [Configuration Files](#configuration-files)
3. [Environment Variables](#environment-variables)
4. [Server Configuration](#server-configuration)
5. [Storage Configuration](#storage-configuration)
6. [Security Configuration](#security-configuration)
7. [Caching Configuration](#caching-configuration)
8. [Logging Configuration](#logging-configuration)
9. [Best Practices](#best-practices)
10. [Production Configuration](#production-configuration)

## Configuration Overview

LLM Config Manager supports multiple configuration methods:

1. **Configuration Files** (YAML, TOML, JSON)
2. **Environment Variables** (recommended for secrets)
3. **Command-line Arguments**
4. **Programmatic Configuration** (library usage)

### Configuration Priority

Settings are applied in the following order (last wins):

1. Built-in defaults
2. Configuration file
3. Environment-specific file
4. Environment variables
5. Command-line arguments

**Example:**
```bash
# Default: port 8080
# config.yaml: port 9000
# Environment variable overrides to 3000
export LLM_CONFIG_SERVER_PORT=3000
llm-config-server --config config.yaml
# Final port: 3000
```

## Configuration Files

### Supported Formats

#### YAML (Recommended)

```yaml
# config.yaml
server:
  host: "0.0.0.0"
  port: 8080
  enable_cors: true
  enable_security: true

storage:
  type: "file"
  path: "/var/lib/llm-config/data"
  backup_enabled: true
  backup_interval: "24h"

security:
  encryption:
    algorithm: "aes-256-gcm"
    key_rotation_enabled: true
    key_rotation_interval: "30d"

  rate_limiting:
    enabled: true
    requests_per_second: 100
    burst_size: 200
    ban_duration: "1h"

  policies:
    require_tls: true
    allowed_ips: []
    blocked_ips: []
    cors_origins: ["*"]

cache:
  l1:
    enabled: true
    max_size: 1000
    ttl: "5m"

  l2:
    enabled: true
    type: "redis"
    url: "redis://localhost:6379"
    password: "${REDIS_PASSWORD}"
    max_size_mb: 500
    ttl: "1h"

logging:
  level: "info"
  format: "json"
  output: "stdout"
  file:
    enabled: true
    path: "/var/log/llm-config/app.log"
    max_size_mb: 100
    max_backups: 10

monitoring:
  enabled: true
  metrics_port: 9090
  health_check_interval: "30s"
  prometheus_enabled: true

audit:
  enabled: true
  log_path: "/var/log/llm-config/audit.log"
  retention_days: 90
  include_sensitive: false
```

#### TOML

```toml
# config.toml
[server]
host = "0.0.0.0"
port = 8080
enable_cors = true
enable_security = true

[storage]
type = "file"
path = "/var/lib/llm-config/data"
backup_enabled = true
backup_interval = "24h"

[security.encryption]
algorithm = "aes-256-gcm"
key_rotation_enabled = true
key_rotation_interval = "30d"

[cache.l1]
enabled = true
max_size = 1000
ttl = "5m"

[logging]
level = "info"
format = "json"
output = "stdout"
```

#### JSON

```json
{
  "server": {
    "host": "0.0.0.0",
    "port": 8080,
    "enable_cors": true,
    "enable_security": true
  },
  "storage": {
    "type": "file",
    "path": "/var/lib/llm-config/data"
  },
  "logging": {
    "level": "info",
    "format": "json"
  }
}
```

### Environment-Specific Configurations

Create separate configuration files for each environment:

```bash
config/
├── base.yaml          # Shared settings
├── development.yaml   # Development overrides
├── staging.yaml       # Staging overrides
└── production.yaml    # Production overrides
```

**base.yaml:**
```yaml
server:
  enable_cors: true
  enable_security: true

storage:
  type: "file"
  backup_enabled: true

logging:
  format: "json"
```

**development.yaml:**
```yaml
server:
  host: "127.0.0.1"
  port: 8080

logging:
  level: "debug"

security:
  rate_limiting:
    enabled: false
```

**production.yaml:**
```yaml
server:
  host: "0.0.0.0"
  port: 8080

logging:
  level: "info"
  file:
    enabled: true

security:
  rate_limiting:
    enabled: true
    requests_per_second: 100

  policies:
    require_tls: true
```

Load environment-specific config:

```bash
llm-config-server --config config/production.yaml
```

## Environment Variables

All configuration options can be set via environment variables.

### Naming Convention

```bash
# Format: LLM_CONFIG_<SECTION>_<KEY>
export LLM_CONFIG_SERVER_PORT=8080

# For nested values, use double underscores
export LLM_CONFIG_CACHE__L1__MAX_SIZE=1000
```

### Critical Environment Variables

Always set these via environment variables (never hardcode):

#### Encryption Key

```bash
# Generate key
export LLM_CONFIG_KEY=$(openssl rand -base64 32)

# Or use specific key
export LLM_CONFIG_KEY="EQa/CnulhQNT7jEWj5f8TyQN2YnCh2Lp9oIctKAMDdc="
```

#### Database Credentials

```bash
export LLM_CONFIG_DATABASE_URL="postgresql://user:password@localhost:5432/llm_config"
export LLM_CONFIG_DATABASE_PASSWORD="secure-password"
```

#### Redis Credentials

```bash
export LLM_CONFIG_REDIS_URL="redis://localhost:6379"
export LLM_CONFIG_REDIS_PASSWORD="redis-password"
```

#### API Authentication

```bash
export LLM_CONFIG_JWT_SECRET="your-jwt-secret"
export LLM_CONFIG_API_KEY="your-api-key"
```

### Complete Environment Variables Reference

#### Server Configuration

```bash
# Server settings
export LLM_CONFIG_SERVER_HOST="0.0.0.0"
export LLM_CONFIG_SERVER_PORT=8080
export LLM_CONFIG_SERVER_ENABLE_CORS=true
export LLM_CONFIG_SERVER_ENABLE_SECURITY=true
export LLM_CONFIG_SERVER_TIMEOUT_SECONDS=30
export LLM_CONFIG_SERVER_MAX_CONNECTIONS=1000
```

#### Storage Configuration

```bash
# Storage backend
export LLM_CONFIG_STORAGE_TYPE="file"  # file, postgres, mysql
export LLM_CONFIG_STORAGE_PATH="/var/lib/llm-config/data"
export LLM_CONFIG_STORAGE_BACKUP_ENABLED=true
export LLM_CONFIG_STORAGE_BACKUP_INTERVAL="24h"
export LLM_CONFIG_STORAGE_BACKUP_PATH="/var/lib/llm-config/backups"
```

#### Security Configuration

```bash
# Encryption
export LLM_CONFIG_ENCRYPTION_ALGORITHM="aes-256-gcm"
export LLM_CONFIG_ENCRYPTION_KEY="your-encryption-key"
export LLM_CONFIG_ENCRYPTION_KEY_ROTATION_ENABLED=true
export LLM_CONFIG_ENCRYPTION_KEY_ROTATION_INTERVAL="30d"

# Rate limiting
export LLM_CONFIG_RATE_LIMIT_ENABLED=true
export LLM_CONFIG_RATE_LIMIT_RPS=100
export LLM_CONFIG_RATE_LIMIT_BURST=200
export LLM_CONFIG_RATE_LIMIT_BAN_DURATION="1h"

# Policies
export LLM_CONFIG_SECURITY_REQUIRE_TLS=true
export LLM_CONFIG_SECURITY_ALLOWED_IPS=""  # Comma-separated
export LLM_CONFIG_SECURITY_BLOCKED_IPS=""  # Comma-separated
```

#### Cache Configuration

```bash
# L1 Cache (Memory)
export LLM_CONFIG_CACHE_L1_ENABLED=true
export LLM_CONFIG_CACHE_L1_MAX_SIZE=1000
export LLM_CONFIG_CACHE_L1_TTL="5m"

# L2 Cache (Redis)
export LLM_CONFIG_CACHE_L2_ENABLED=true
export LLM_CONFIG_CACHE_L2_TYPE="redis"
export LLM_CONFIG_CACHE_L2_URL="redis://localhost:6379"
export LLM_CONFIG_CACHE_L2_PASSWORD="redis-password"
export LLM_CONFIG_CACHE_L2_MAX_SIZE_MB=500
export LLM_CONFIG_CACHE_L2_TTL="1h"
```

#### Logging Configuration

```bash
# Logging
export LLM_CONFIG_LOG_LEVEL="info"  # trace, debug, info, warn, error
export LLM_CONFIG_LOG_FORMAT="json"  # json, text
export LLM_CONFIG_LOG_OUTPUT="stdout"  # stdout, file
export LLM_CONFIG_LOG_FILE_PATH="/var/log/llm-config/app.log"
export LLM_CONFIG_LOG_FILE_MAX_SIZE_MB=100
export LLM_CONFIG_LOG_FILE_MAX_BACKUPS=10
export RUST_LOG="info"  # Rust-specific logging
```

#### Monitoring Configuration

```bash
# Monitoring
export LLM_CONFIG_MONITORING_ENABLED=true
export LLM_CONFIG_METRICS_PORT=9090
export LLM_CONFIG_HEALTH_CHECK_INTERVAL="30s"
export LLM_CONFIG_PROMETHEUS_ENABLED=true
```

#### Audit Configuration

```bash
# Audit logging
export LLM_CONFIG_AUDIT_ENABLED=true
export LLM_CONFIG_AUDIT_LOG_PATH="/var/log/llm-config/audit.log"
export LLM_CONFIG_AUDIT_RETENTION_DAYS=90
export LLM_CONFIG_AUDIT_INCLUDE_SENSITIVE=false
```

## Server Configuration

### Basic Server Settings

```yaml
server:
  # Bind address
  host: "0.0.0.0"  # 0.0.0.0 for all interfaces, 127.0.0.1 for localhost only

  # Port number
  port: 8080

  # CORS settings
  enable_cors: true
  cors_origins: ["*"]  # ["https://app.example.com"] for specific origins
  cors_methods: ["GET", "POST", "PUT", "DELETE"]
  cors_headers: ["Content-Type", "Authorization"]

  # Security
  enable_security: true

  # Timeouts
  read_timeout: "30s"
  write_timeout: "30s"
  idle_timeout: "120s"

  # Connection limits
  max_connections: 1000
  max_requests_per_connection: 100

  # TLS/HTTPS (optional)
  tls_enabled: false
  tls_cert_path: "/etc/llm-config/tls/cert.pem"
  tls_key_path: "/etc/llm-config/tls/key.pem"
```

### Command-line Server Options

```bash
llm-config-server \
  --host 0.0.0.0 \
  --port 8080 \
  --config /etc/llm-config/config.yaml \
  --enable-security true \
  --log-level info
```

## Storage Configuration

### File Storage (Default)

```yaml
storage:
  type: "file"
  path: "/var/lib/llm-config/data"

  # File storage options
  file:
    max_file_size_mb: 100
    compression_enabled: true
    fsync_enabled: true  # Ensure durability

  # Backup settings
  backup_enabled: true
  backup_interval: "24h"
  backup_path: "/var/lib/llm-config/backups"
  backup_retention_days: 30
```

### PostgreSQL Storage

```yaml
storage:
  type: "postgres"

  # Connection settings
  postgres:
    host: "localhost"
    port: 5432
    database: "llm_config"
    username: "llm_config_user"
    password: "${POSTGRES_PASSWORD}"  # From environment variable
    ssl_mode: "require"

    # Connection pool
    max_connections: 20
    min_connections: 5
    connection_timeout: "30s"
    idle_timeout: "10m"

    # Performance
    statement_cache_size: 100
```

### MySQL Storage

```yaml
storage:
  type: "mysql"

  # Connection settings
  mysql:
    host: "localhost"
    port: 3306
    database: "llm_config"
    username: "llm_config_user"
    password: "${MYSQL_PASSWORD}"

    # Connection pool
    max_connections: 20
    min_connections: 5
```

## Security Configuration

### Encryption Settings

```yaml
security:
  encryption:
    # Algorithm (currently only aes-256-gcm)
    algorithm: "aes-256-gcm"

    # Key management
    key_source: "env"  # env, file, vault
    key_rotation_enabled: true
    key_rotation_interval: "30d"

    # For file-based keys
    key_file_path: "/etc/llm-config/keys/encryption.key"

    # For Vault
    vault_url: "https://vault.example.com"
    vault_path: "secret/llm-config/encryption-key"
```

### Rate Limiting

```yaml
security:
  rate_limiting:
    enabled: true

    # Per-IP rate limits
    requests_per_second: 100
    burst_size: 200

    # Authenticated users (higher limits)
    authenticated_rps: 1000
    authenticated_burst: 2000

    # Ban settings
    ban_enabled: true
    ban_threshold: 1000  # Requests per minute
    ban_duration: "1h"

    # Whitelist
    whitelist_ips:
      - "10.0.0.0/8"      # Internal network
      - "192.168.0.0/16"  # Private network
```

### Policy Enforcement

```yaml
security:
  policies:
    # TLS requirement
    require_tls: true
    tls_min_version: "1.2"

    # IP filtering
    allowed_ips: []  # Empty = allow all
    blocked_ips:
      - "1.2.3.4"
      - "5.6.7.0/24"

    # Input validation
    max_key_length: 256
    max_value_size_mb: 10
    max_namespace_depth: 10

    # CORS
    cors_enabled: true
    cors_origins:
      - "https://app.example.com"
      - "https://admin.example.com"

    # Content Security Policy
    csp_enabled: true
    csp_directives:
      default-src: "'self'"
      script-src: "'self' 'unsafe-inline'"
```

### RBAC Configuration

```yaml
security:
  rbac:
    enabled: true

    # Default roles
    roles:
      admin:
        permissions:
          - "config:read"
          - "config:write"
          - "config:delete"
          - "config:rollback"
          - "rbac:manage"

      developer:
        permissions:
          - "config:read"
          - "config:write"
          - "config:rollback"

      readonly:
        permissions:
          - "config:read"

    # User assignments
    users:
      alice:
        role: "admin"
      bob:
        role: "developer"
      charlie:
        role: "readonly"
```

## Caching Configuration

### L1 Cache (Memory)

```yaml
cache:
  l1:
    enabled: true
    max_size: 1000  # Maximum number of entries
    ttl: "5m"       # Time to live
    eviction_policy: "lru"  # lru, lfu, fifo
```

### L2 Cache (Redis)

```yaml
cache:
  l2:
    enabled: true
    type: "redis"

    # Connection
    url: "redis://localhost:6379"
    password: "${REDIS_PASSWORD}"
    db: 0

    # Pool settings
    max_connections: 10
    min_idle_connections: 2
    connection_timeout: "5s"

    # Cache settings
    max_size_mb: 500
    ttl: "1h"

    # Key prefix (for multi-tenancy)
    key_prefix: "llm-config:"

    # Cluster mode
    cluster_enabled: false
    cluster_nodes:
      - "redis1:6379"
      - "redis2:6379"
      - "redis3:6379"
```

### Cache Strategies

```yaml
cache:
  # Cache strategy
  strategy: "write-through"  # write-through, write-behind, cache-aside

  # Invalidation
  invalidation:
    enabled: true
    strategy: "immediate"  # immediate, lazy, ttl

  # Warming
  warming:
    enabled: true
    on_startup: true
    namespaces:
      - "app/llm"
      - "app/features"
```

## Logging Configuration

### Basic Logging

```yaml
logging:
  # Log level
  level: "info"  # trace, debug, info, warn, error

  # Format
  format: "json"  # json, text, pretty

  # Output
  output: "stdout"  # stdout, file, both

  # Structured fields
  include_timestamp: true
  include_level: true
  include_target: true
  include_line_numbers: true
```

### File Logging

```yaml
logging:
  file:
    enabled: true
    path: "/var/log/llm-config/app.log"

    # Rotation
    max_size_mb: 100
    max_backups: 10
    max_age_days: 30
    compress: true

    # Permissions
    permissions: 0600
```

### Advanced Logging

```yaml
logging:
  # Per-module log levels
  module_levels:
    llm_config_core: "debug"
    llm_config_api: "info"
    llm_config_security: "warn"

  # Filtering
  filters:
    # Exclude health checks
    - type: "path"
      pattern: "/health"
      level: "trace"

  # Sampling (reduce log volume)
  sampling:
    enabled: true
    rate: 0.1  # Log 10% of requests
```

### Audit Logging

```yaml
audit:
  enabled: true

  # Output
  log_path: "/var/log/llm-config/audit.log"

  # Retention
  retention_days: 90

  # What to log
  events:
    - "config:create"
    - "config:update"
    - "config:delete"
    - "config:rollback"
    - "rbac:change"

  # Include sensitive data?
  include_sensitive: false

  # Format
  format: "json"

  # Remote logging (optional)
  remote:
    enabled: false
    endpoint: "https://audit.example.com/logs"
    api_key: "${AUDIT_API_KEY}"
```

## Best Practices

### 1. Separate Secrets from Configuration

**Bad:**
```yaml
storage:
  postgres:
    password: "hardcoded-password"  # DON'T DO THIS
```

**Good:**
```yaml
storage:
  postgres:
    password: "${POSTGRES_PASSWORD}"  # From environment
```

```bash
export POSTGRES_PASSWORD="secure-password"
```

### 2. Use Configuration Templates

**config/template.yaml:**
```yaml
server:
  host: "${SERVER_HOST:-0.0.0.0}"
  port: ${SERVER_PORT:-8080}

storage:
  type: "${STORAGE_TYPE:-file}"
  path: "${STORAGE_PATH:-/var/lib/llm-config/data}"
```

### 3. Validate Configuration on Startup

```bash
# Validate configuration before starting
llm-config-server --config config.yaml --validate

# Start only if validation passes
llm-config-server --config config.yaml --validate && \
  llm-config-server --config config.yaml
```

### 4. Use Environment-Specific Configurations

```bash
# Development
llm-config-server --config config/development.yaml

# Staging
llm-config-server --config config/staging.yaml

# Production
llm-config-server --config config/production.yaml
```

### 5. Enable Security Features in Production

```yaml
# Production configuration
server:
  enable_security: true

security:
  rate_limiting:
    enabled: true
  policies:
    require_tls: true
  rbac:
    enabled: true

audit:
  enabled: true
```

### 6. Configure Appropriate Logging

```yaml
# Development: verbose logging
logging:
  level: "debug"
  format: "pretty"

# Production: structured logging
logging:
  level: "info"
  format: "json"
  file:
    enabled: true
```

### 7. Set Resource Limits

```yaml
server:
  max_connections: 1000
  max_requests_per_connection: 100

cache:
  l1:
    max_size: 1000
  l2:
    max_size_mb: 500

security:
  policies:
    max_value_size_mb: 10
```

### 8. Configure Monitoring

```yaml
monitoring:
  enabled: true
  metrics_port: 9090
  health_check_interval: "30s"
  prometheus_enabled: true

  # Custom metrics
  custom_metrics:
    - name: "config_access_count"
      type: "counter"
    - name: "config_access_duration"
      type: "histogram"
```

## Production Configuration

Complete production-ready configuration example:

```yaml
# config/production.yaml
server:
  host: "0.0.0.0"
  port: 8080
  enable_cors: true
  enable_security: true
  read_timeout: "30s"
  write_timeout: "30s"
  max_connections: 1000

  tls_enabled: true
  tls_cert_path: "/etc/llm-config/tls/cert.pem"
  tls_key_path: "/etc/llm-config/tls/key.pem"

storage:
  type: "postgres"
  postgres:
    host: "${POSTGRES_HOST}"
    port: 5432
    database: "llm_config"
    username: "llm_config_user"
    password: "${POSTGRES_PASSWORD}"
    ssl_mode: "require"
    max_connections: 20

  backup_enabled: true
  backup_interval: "6h"
  backup_path: "/var/lib/llm-config/backups"
  backup_retention_days: 30

security:
  encryption:
    algorithm: "aes-256-gcm"
    key_rotation_enabled: true
    key_rotation_interval: "30d"

  rate_limiting:
    enabled: true
    requests_per_second: 100
    burst_size: 200
    ban_enabled: true
    ban_duration: "1h"

  policies:
    require_tls: true
    tls_min_version: "1.2"
    max_value_size_mb: 10

  rbac:
    enabled: true

cache:
  l1:
    enabled: true
    max_size: 1000
    ttl: "5m"

  l2:
    enabled: true
    type: "redis"
    url: "${REDIS_URL}"
    password: "${REDIS_PASSWORD}"
    max_size_mb: 500
    ttl: "1h"
    cluster_enabled: true

logging:
  level: "info"
  format: "json"
  output: "both"

  file:
    enabled: true
    path: "/var/log/llm-config/app.log"
    max_size_mb: 100
    max_backups: 10
    compress: true

monitoring:
  enabled: true
  metrics_port: 9090
  health_check_interval: "30s"
  prometheus_enabled: true

audit:
  enabled: true
  log_path: "/var/log/llm-config/audit.log"
  retention_days: 90
  include_sensitive: false
```

### Production Environment Variables

```bash
# Production .env file (use secrets manager in real production)
LLM_CONFIG_KEY="$(openssl rand -base64 32)"
POSTGRES_HOST="postgres.example.com"
POSTGRES_PASSWORD="secure-postgres-password"
REDIS_URL="redis://redis.example.com:6379"
REDIS_PASSWORD="secure-redis-password"
```

## Configuration Validation

### Validate Configuration

```bash
# Validate configuration file
llm-config-server --config config.yaml --validate

# Validate with environment variables
export LLM_CONFIG_KEY="test-key"
llm-config-server --config config.yaml --validate
```

### Common Validation Errors

```
Error: Encryption key not set
Solution: Set LLM_CONFIG_KEY environment variable

Error: Invalid port number: 99999
Solution: Use port between 1 and 65535

Error: TLS enabled but certificate not found
Solution: Provide valid tls_cert_path and tls_key_path

Error: Redis URL invalid
Solution: Use format redis://host:port or redis://user:pass@host:port
```

## Next Steps

- Review [Getting Started Guide](getting-started.md) for basic setup
- See [Use Cases & Examples](examples/) for configuration examples
- Check [Troubleshooting Guide](troubleshooting.md) for configuration issues
- Read [Deployment Guide](../DEPLOYMENT.md) for production deployment

## Support

For configuration help:
- Documentation: https://docs.llm-config-manager.io
- GitHub Discussions: https://github.com/llm-devops/llm-config-manager/discussions
- Discord: https://discord.gg/llm-config-manager
- Enterprise Support: enterprise@llm-config-manager.io
