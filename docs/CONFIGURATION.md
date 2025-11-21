# Configuration Management Guide

This guide explains how to configure the LLM Config Manager for different environments and use cases.

## Table of Contents

- [Configuration Files](#configuration-files)
- [Environment Variables](#environment-variables)
- [Configuration Priority](#configuration-priority)
- [Security Best Practices](#security-best-practices)
- [Production Deployment](#production-deployment)
- [Configuration Reference](#configuration-reference)

## Configuration Files

The platform supports multiple configuration formats:

- **YAML** (recommended): `config.yaml`
- **TOML**: `config.toml`
- **JSON**: `config.json`
- **Environment variables**: Prefix with `LLM_CONFIG_`

### Environment-Specific Configurations

Pre-configured examples are available in the `config/` directory:

```
config/
├── development.yaml    # Local development settings
├── staging.yaml        # Staging environment settings
└── production.yaml     # Production-ready settings
```

### Loading Configuration

#### From File

```bash
# Using default config.yaml in current directory
llm-config-server

# Specify custom config file
llm-config-server --config /etc/llm-config/production.yaml

# Use environment-specific config
llm-config-server --env production
```

#### From Environment Variables

All configuration values can be set via environment variables:

```bash
# Format: LLM_CONFIG_<SECTION>_<KEY>
export LLM_CONFIG_SERVER_PORT=8080
export LLM_CONFIG_SERVER_HOST=0.0.0.0
export LLM_CONFIG_ENCRYPTION_ALGORITHM=aes-256-gcm
export LLM_CONFIG_DATABASE_PASSWORD=secret123
```

Nested values use double underscores:

```bash
export LLM_CONFIG_CACHE__L1__MAX_SIZE=1000
export LLM_CONFIG_CACHE__L2__MAX_SIZE_MB=500
```

## Configuration Priority

Configuration is loaded in the following order (last wins):

1. Built-in defaults
2. Configuration file (`config.yaml`)
3. Environment-specific file (`config/production.yaml`)
4. Environment variables (`LLM_CONFIG_*`)
5. Command-line arguments

Example:
```bash
# File sets port to 8080
# Environment variable overrides to 9000
export LLM_CONFIG_SERVER_PORT=9000
llm-config-server --config config.yaml

# Final port: 9000
```

## Environment Variables

### Critical Settings

Always set these via environment variables (never hardcode):

```bash
# Database credentials
export LLM_CONFIG_DATABASE_PASSWORD="your-db-password"

# Encryption key (generate with: openssl rand -hex 32)
export LLM_CONFIG_ENCRYPTION_KEY="your-encryption-key-here"

# JWT secret (generate with: openssl rand -base64 32)
export LLM_CONFIG_JWT_SECRET="your-jwt-secret-here"

# API keys for external services
export LLM_CONFIG_API_KEY="your-api-key"
```

### Secrets Management Integration

Use a secrets manager in production:

#### AWS Secrets Manager

```bash
# Fetch from AWS Secrets Manager
export LLM_CONFIG_ENCRYPTION_KEY=$(aws secretsmanager get-secret-value \
  --secret-id llm-config/encryption-key \
  --query SecretString \
  --output text)
```

#### HashiCorp Vault

```bash
# Fetch from Vault
export LLM_CONFIG_ENCRYPTION_KEY=$(vault kv get \
  -field=key \
  secret/llm-config/encryption)
```

#### Kubernetes Secrets

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: llm-config
    env:
    - name: LLM_CONFIG_ENCRYPTION_KEY
      valueFrom:
        secretKeyRef:
          name: llm-config-secrets
          key: encryption-key
```

## Security Best Practices

### Encryption Keys

1. **Generate Strong Keys**
   ```bash
   # AES-256 key (32 bytes)
   openssl rand -hex 32

   # Or base64 encoded
   openssl rand -base64 32
   ```

2. **Key Rotation**
   - Enable automatic rotation in production
   - Keep old keys for decrypting existing secrets
   - Implement key versioning

3. **Key Storage**
   - Never commit keys to version control
   - Use secrets management systems
   - Encrypt keys at rest

### TLS/SSL Certificates

Generate self-signed certificates for development:

```bash
openssl req -x509 -newkey rsa:4096 \
  -keyout server.key \
  -out server.crt \
  -days 365 \
  -nodes \
  -subj "/CN=localhost"
```

Use Let's Encrypt or your organization's CA for production.

### File Permissions

Secure configuration and data files:

```bash
# Configuration files
chmod 600 /etc/llm-config/production.yaml
chown llm-config:llm-config /etc/llm-config/production.yaml

# Data directory
chmod 700 /var/lib/llm-config/data
chown -R llm-config:llm-config /var/lib/llm-config

# Logs
chmod 750 /var/log/llm-config
chown llm-config:adm /var/log/llm-config
```

### Network Security

1. **Firewall Rules**
   ```bash
   # Allow only necessary ports
   ufw allow 8080/tcp  # API
   ufw allow 9090/tcp  # Metrics (restrict to monitoring subnet)
   ```

2. **TLS Configuration**
   - Require TLS 1.2 or higher
   - Disable weak ciphers
   - Enable HSTS

3. **Rate Limiting**
   - Enable in production
   - Adjust based on expected load
   - Monitor for abuse

## Production Deployment

### Checklist

Before deploying to production:

- [ ] Generate new encryption keys (don't use dev keys!)
- [ ] Configure database with strong password
- [ ] Enable TLS/SSL
- [ ] Set up log rotation
- [ ] Configure backups
- [ ] Enable audit logging
- [ ] Set up monitoring and alerts
- [ ] Configure rate limiting
- [ ] Review and restrict CORS settings
- [ ] Enable security headers (HSTS, CSP)
- [ ] Set appropriate file permissions
- [ ] Configure firewall rules
- [ ] Test disaster recovery procedures

### Recommended Production Settings

```yaml
# Minimal production configuration
server:
  host: "0.0.0.0"
  port: 8080
  workers: 4
  enable_tls: true
  tls_cert_path: "/etc/llm-config/certs/server.crt"
  tls_key_path: "/etc/llm-config/certs/server.key"

storage:
  path: "/var/lib/llm-config/data"
  backup_enabled: true
  backup_path: "/var/lib/llm-config/backups"

audit:
  enabled: true
  log_path: "/var/log/llm-config/audit"
  retention_days: 365

logging:
  level: "info"
  format: "json"
  output: "file"

security:
  require_https: true
  hsts_enabled: true
```

### High Availability Setup

For production HA deployment:

1. **Load Balancer**
   ```
   Load Balancer (TLS termination)
        |
        v
   +----+----+----+
   |    |    |    |
   v    v    v    v
   App  App  App  App (multiple instances)
   ```

2. **Shared Storage**
   - Use network filesystem (NFS, EFS) or
   - Use object storage (S3) or
   - Use database backend

3. **Caching**
   - Redis for distributed L2 cache
   - Consistent hashing for cache keys

4. **Database**
   - Primary-replica setup
   - Automated failover
   - Connection pooling

## Configuration Reference

### Server Section

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `host` | string | `127.0.0.1` | Server bind address |
| `port` | integer | `8080` | Server port |
| `workers` | integer | CPU cores | Number of worker threads |
| `max_connections` | integer | `1000` | Maximum concurrent connections |
| `timeout_seconds` | integer | `30` | Request timeout |
| `enable_tls` | boolean | `false` | Enable TLS/SSL |
| `tls_cert_path` | string | - | Path to TLS certificate |
| `tls_key_path` | string | - | Path to TLS private key |

### Storage Section

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `type` | string | `file` | Storage backend type |
| `path` | string | `./data` | Storage directory path |
| `backup_enabled` | boolean | `false` | Enable automatic backups |
| `backup_path` | string | - | Backup directory path |
| `backup_retention_days` | integer | `30` | Backup retention period |
| `max_file_size_mb` | integer | `100` | Maximum file size limit |

### Encryption Section

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `algorithm` | string | `aes-256-gcm` | Encryption algorithm |
| `key_rotation_enabled` | boolean | `false` | Enable automatic key rotation |
| `key_rotation_days` | integer | `90` | Key rotation interval |

### Cache Section

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `l1.enabled` | boolean | `true` | Enable L1 (in-memory) cache |
| `l1.max_size` | integer | `1000` | L1 cache size (entries) |
| `l1.ttl_seconds` | integer | `300` | L1 TTL (seconds) |
| `l2.enabled` | boolean | `true` | Enable L2 (disk) cache |
| `l2.path` | string | `./cache` | L2 cache directory |
| `l2.max_size_mb` | integer | `500` | L2 cache size (MB) |
| `l2.ttl_seconds` | integer | `3600` | L2 TTL (seconds) |

### Audit Section

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `enabled` | boolean | `true` | Enable audit logging |
| `log_path` | string | `./logs/audit` | Audit log directory |
| `retention_days` | integer | `365` | Log retention period |
| `format` | string | `json` | Log format (json/text) |
| `log_level` | string | `info` | Log level |
| `include_read_operations` | boolean | `false` | Log read operations |
| `sensitive_fields_redacted` | boolean | `true` | Redact sensitive data |

### RBAC Section

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `enabled` | boolean | `true` | Enable RBAC |
| `default_role` | string | `viewer` | Default role for new users |
| `allow_self_service` | boolean | `false` | Users can modify own roles |
| `require_mfa_for_admin` | boolean | `true` | Require MFA for admin ops |
| `session_timeout_minutes` | integer | `60` | Session timeout |

### Rate Limiting Section

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `enabled` | boolean | `true` | Enable rate limiting |
| `requests_per_minute` | integer | `1000` | Global rate limit |
| `burst_size` | integer | `100` | Burst capacity |
| `per_user_limit` | boolean | `true` | Per-user rate limiting |

### Monitoring Section

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `enabled` | boolean | `true` | Enable monitoring |
| `metrics_port` | integer | `9090` | Prometheus metrics port |
| `metrics_path` | string | `/metrics` | Metrics endpoint path |
| `health_check_path` | string | `/health` | Health check endpoint |
| `profiling_enabled` | boolean | `false` | Enable profiling |

## Examples

### Development Setup

```bash
# Use development config
cp config/development.yaml config.yaml

# Start server
llm-config-server
```

### Production Setup with Docker

```dockerfile
FROM rust:1.75 as builder
WORKDIR /app
COPY . .
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates
COPY --from=builder /app/target/release/llm-config-server /usr/local/bin/
COPY config/production.yaml /etc/llm-config/config.yaml
CMD ["llm-config-server", "--config", "/etc/llm-config/config.yaml"]
```

### Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llm-config-manager
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: llm-config
        image: llm-config-manager:latest
        env:
        - name: LLM_CONFIG_ENCRYPTION_KEY
          valueFrom:
            secretKeyRef:
              name: llm-config-secrets
              key: encryption-key
        volumeMounts:
        - name: config
          mountPath: /etc/llm-config
        - name: data
          mountPath: /var/lib/llm-config
      volumes:
      - name: config
        configMap:
          name: llm-config-config
      - name: data
        persistentVolumeClaim:
          claimName: llm-config-data
```

## Troubleshooting

### Configuration Not Loading

1. Check file permissions:
   ```bash
   ls -l config.yaml
   ```

2. Validate YAML syntax:
   ```bash
   yamllint config.yaml
   ```

3. Check environment variables:
   ```bash
   env | grep LLM_CONFIG
   ```

### Connection Issues

1. Verify server is listening:
   ```bash
   netstat -tlnp | grep 8080
   ```

2. Check firewall:
   ```bash
   ufw status
   ```

3. Test connectivity:
   ```bash
   curl -k https://localhost:8080/health
   ```

### Permission Errors

1. Check file ownership:
   ```bash
   ls -la /var/lib/llm-config
   ```

2. Verify process user:
   ```bash
   ps aux | grep llm-config
   ```

3. Check SELinux (if applicable):
   ```bash
   ausearch -m avc -ts recent
   ```

## Additional Resources

- [Deployment Guide](DEPLOYMENT.md)
- [Security Best Practices](SECURITY.md)
- [Operations Runbook](OPERATIONS.md)
- [API Documentation](API.md)
