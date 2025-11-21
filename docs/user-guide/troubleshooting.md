# Troubleshooting Guide

Solutions to common issues and problems when using LLM Config Manager.

## Table of Contents

1. [Installation Issues](#installation-issues)
2. [Server Issues](#server-issues)
3. [Configuration Issues](#configuration-issues)
4. [API Issues](#api-issues)
5. [Security Issues](#security-issues)
6. [Performance Issues](#performance-issues)
7. [Integration Issues](#integration-issues)
8. [FAQ](#faq)

## Installation Issues

### Issue: "Rust compiler not found"

**Symptoms:**
```bash
$ cargo build
error: rustc not found
```

**Solution:**
```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Reload shell
source $HOME/.cargo/env

# Verify installation
rustc --version
cargo --version
```

### Issue: "Compilation fails with OpenSSL errors"

**Symptoms:**
```bash
error: failed to run custom build command for `openssl-sys`
could not find system library 'openssl' required by the 'openssl-sys' crate
```

**Solution:**

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install pkg-config libssl-dev
```

**macOS:**
```bash
brew install openssl
export OPENSSL_DIR=/usr/local/opt/openssl
```

**RHEL/CentOS:**
```bash
sudo yum install openssl-devel
```

### Issue: "Docker build fails"

**Symptoms:**
```bash
$ docker build -t llm-config .
ERROR: failed to solve: process "/bin/sh -c cargo build --release" did not complete successfully
```

**Solution:**
```bash
# Ensure Docker has enough resources
# Docker Desktop: Settings -> Resources
# Minimum: 4GB RAM, 2 CPUs

# Try building with BuildKit
DOCKER_BUILDKIT=1 docker build -t llm-config .

# Or use docker-compose
docker-compose build --no-cache
```

### Issue: "Permission denied when running binary"

**Symptoms:**
```bash
$ ./target/release/llm-config-server
bash: ./target/release/llm-config-server: Permission denied
```

**Solution:**
```bash
# Make binary executable
chmod +x target/release/llm-config-server

# Run
./target/release/llm-config-server
```

## Server Issues

### Issue: "Cannot bind to port 8080"

**Symptoms:**
```bash
ERROR: Address already in use (os error 98)
```

**Solution:**
```bash
# Check what's using the port
sudo lsof -i :8080
# or
sudo netstat -tlnp | grep :8080

# Kill the process
sudo kill -9 <PID>

# Or use a different port
llm-config-server --port 8081
```

### Issue: "Server starts but immediately exits"

**Symptoms:**
```bash
$ llm-config-server
Starting LLM Config API server on 0.0.0.0:8080
# Server exits with no error message
```

**Solution:**
```bash
# Check if encryption key is set
echo $LLM_CONFIG_KEY

# If not set, generate and export it
export LLM_CONFIG_KEY=$(llm-config keygen)

# Check server logs
llm-config-server --log-level debug

# Validate configuration
llm-config-server --config config.yaml --validate
```

### Issue: "Server crashes with 'panic' error"

**Symptoms:**
```bash
thread 'main' panicked at 'called `Result::unwrap()` on an `Err` value'
```

**Solution:**
```bash
# Enable backtrace for detailed error info
export RUST_BACKTRACE=1
llm-config-server

# Check for config issues
llm-config-server --config config.yaml --validate

# Check file permissions
ls -la /var/lib/llm-config/
chmod 700 /var/lib/llm-config/
chown $USER:$USER /var/lib/llm-config/
```

### Issue: "Health check fails"

**Symptoms:**
```bash
$ curl http://localhost:8080/health
curl: (7) Failed to connect to localhost port 8080: Connection refused
```

**Solution:**
```bash
# Check if server is running
ps aux | grep llm-config-server

# Check if listening on correct interface
netstat -an | grep 8080

# If server binds to 127.0.0.1, use localhost
curl http://127.0.0.1:8080/health

# If behind firewall, check firewall rules
sudo ufw status
sudo ufw allow 8080/tcp
```

## Configuration Issues

### Issue: "Configuration not found"

**Symptoms:**
```bash
$ llm-config get app/llm model --env production
Error: Configuration not found: app/llm/model
```

**Solution:**
```bash
# List all configurations to verify namespace
llm-config list app/llm --env production

# Check if configuration exists in different environment
llm-config list app/llm --env development

# Set the configuration if it doesn't exist
llm-config set app/llm model "gpt-4" --env production
```

### Issue: "Encryption key error"

**Symptoms:**
```bash
Error: Encryption key not set or invalid
```

**Solution:**
```bash
# Generate a new encryption key
export LLM_CONFIG_KEY=$(llm-config keygen)

# Or use an existing key
export LLM_CONFIG_KEY="EQa/CnulhQNT7jEWj5f8TyQN2YnCh2Lp9oIctKAMDdc="

# Verify key is set
echo $LLM_CONFIG_KEY

# For Docker, pass as environment variable
docker run -e LLM_CONFIG_KEY="$LLM_CONFIG_KEY" llm-config
```

### Issue: "Cannot decrypt secret"

**Symptoms:**
```bash
Error: Failed to decrypt value: authentication failed
```

**Solution:**
```bash
# This error means the encryption key has changed
# You need to use the original key that encrypted the data

# If you lost the key, you'll need to:
# 1. Delete the encrypted configuration
llm-config delete app/llm api_key --env production

# 2. Re-set with new key
export LLM_CONFIG_KEY=$(llm-config keygen)
llm-config set app/llm api_key "sk-..." --env production --secret

# To prevent this, always backup your encryption key!
```

### Issue: "Configuration file not loaded"

**Symptoms:**
```bash
$ llm-config-server --config /path/to/config.yaml
Error: No such file or directory
```

**Solution:**
```bash
# Verify file exists
ls -la /path/to/config.yaml

# Check file permissions
chmod 644 /path/to/config.yaml

# Use absolute path
llm-config-server --config $(pwd)/config.yaml

# Validate YAML syntax
cat config.yaml | python -c "import yaml, sys; yaml.safe_load(sys.stdin)"
```

## API Issues

### Issue: "API returns 404 Not Found"

**Symptoms:**
```bash
$ curl http://localhost:8080/api/v1/configs/app/llm/model
{"error": "Not Found"}
```

**Solution:**
```bash
# Check API endpoint format
# Correct format: /api/v1/configs/:namespace/:key?env=:environment

# Example with environment parameter
curl "http://localhost:8080/api/v1/configs/app/llm/model?env=production"

# List available configurations
curl "http://localhost:8080/api/v1/configs/app/llm?env=production"

# Create configuration if it doesn't exist
curl -X POST http://localhost:8080/api/v1/configs/app/llm/model \
  -H "Content-Type: application/json" \
  -d '{"value": "gpt-4", "env": "production", "user": "admin"}'
```

### Issue: "API returns 429 Too Many Requests"

**Symptoms:**
```bash
$ curl http://localhost:8080/api/v1/configs/app/llm/model
{"error": "Too Many Requests", "retry_after": 60}
```

**Solution:**
```bash
# Wait for rate limit to reset (check retry_after header)
sleep 60

# Reduce request rate in your application
# Add delays between requests

# Or increase rate limits in configuration
cat > config.yaml <<EOF
security:
  rate_limiting:
    enabled: true
    requests_per_second: 200  # Increased from 100
    burst_size: 400           # Increased from 200
EOF

llm-config-server --config config.yaml
```

### Issue: "CORS error in browser"

**Symptoms:**
```
Access to fetch at 'http://localhost:8080' from origin 'http://localhost:3000'
has been blocked by CORS policy
```

**Solution:**
```yaml
# config.yaml
server:
  enable_cors: true
  cors_origins:
    - "http://localhost:3000"
    - "https://app.example.com"
```

```bash
# Or allow all origins (development only!)
cat > config.yaml <<EOF
server:
  enable_cors: true
  cors_origins: ["*"]
EOF
```

### Issue: "API returns 500 Internal Server Error"

**Symptoms:**
```bash
$ curl http://localhost:8080/api/v1/configs/app/llm/model
{"error": "Internal Server Error"}
```

**Solution:**
```bash
# Check server logs
tail -f /var/log/llm-config/app.log

# Enable debug logging
export RUST_LOG=debug
llm-config-server

# For Docker
docker logs llm-config

# Check for database connectivity issues
# Check for permission issues
# Check for disk space issues
df -h
```

## Security Issues

### Issue: "Rate limit bypass"

**Symptoms:**
- Users able to make more requests than configured limit

**Solution:**
```yaml
# config.yaml - Ensure security is enabled
server:
  enable_security: true

security:
  rate_limiting:
    enabled: true
    requests_per_second: 100
    burst_size: 200
    ban_enabled: true
    ban_duration: "1h"
```

```bash
# Restart server to apply changes
systemctl restart llm-config
# or
docker restart llm-config
```

### Issue: "Suspicious activity detected"

**Symptoms:**
```bash
WARN: Multiple failed authentication attempts from IP 1.2.3.4
```

**Solution:**
```yaml
# config.yaml - Block suspicious IPs
security:
  policies:
    blocked_ips:
      - "1.2.3.4"
      - "5.6.7.0/24"
```

```bash
# Check audit logs
tail -f /var/log/llm-config/audit.log

# Enable audit logging if not already enabled
cat > config.yaml <<EOF
audit:
  enabled: true
  log_path: "/var/log/llm-config/audit.log"
  retention_days: 90
EOF
```

### Issue: "SSL/TLS certificate error"

**Symptoms:**
```bash
$ curl https://localhost:8080/health
curl: (60) SSL certificate problem: self signed certificate
```

**Solution:**
```bash
# For testing, skip certificate verification (not recommended for production!)
curl -k https://localhost:8080/health

# Or add certificate to trusted store
# For production, use proper CA-signed certificate

# Generate self-signed certificate for testing
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes
```

## Performance Issues

### Issue: "Slow API responses"

**Symptoms:**
- API responses take >1 second
- High latency

**Solution:**
```yaml
# config.yaml - Enable caching
cache:
  l1:
    enabled: true
    max_size: 1000
    ttl: "5m"

  l2:
    enabled: true
    type: "redis"
    url: "redis://localhost:6379"
    ttl: "1h"
```

```bash
# Check if Redis is running (if using L2 cache)
redis-cli ping

# Monitor cache hit rate
curl http://localhost:9090/metrics | grep cache_hit

# Check database performance
# For PostgreSQL:
psql -U llm_config_user -d llm_config -c "EXPLAIN ANALYZE SELECT * FROM configs;"
```

### Issue: "High memory usage"

**Symptoms:**
```bash
$ docker stats llm-config
CONTAINER   MEM USAGE / LIMIT     MEM %
llm-config  1.8GiB / 2GiB        90%
```

**Solution:**
```yaml
# config.yaml - Reduce cache sizes
cache:
  l1:
    max_size: 500  # Reduced from 1000

  l2:
    max_size_mb: 250  # Reduced from 500
```

```bash
# Set Docker memory limits
docker run -m 1g llm-config

# Monitor memory usage
docker stats llm-config

# Check for memory leaks
valgrind target/release/llm-config-server
```

### Issue: "Database connection pool exhausted"

**Symptoms:**
```bash
ERROR: connection pool exhausted
```

**Solution:**
```yaml
# config.yaml - Increase connection pool
storage:
  postgres:
    max_connections: 50  # Increased from 20
    min_connections: 10  # Increased from 5
    connection_timeout: "30s"
```

## Integration Issues

### Issue: "Python client import error"

**Symptoms:**
```python
ModuleNotFoundError: No module named 'llm_config_client'
```

**Solution:**
```bash
# Install requests library
pip install requests

# Copy the client code from the integration guide
# Save as llm_config_client.py in your project

# Or create a simple wrapper
cat > llm_config_client.py <<'EOF'
import requests

class LLMConfigClient:
    def __init__(self, base_url="http://localhost:8080"):
        self.base_url = base_url
        self.api_base = f"{base_url}/api/v1"

    def get_config(self, namespace, key, env="production"):
        url = f"{self.api_base}/configs/{namespace}/{key}"
        response = requests.get(url, params={"env": env})
        response.raise_for_status()
        return response.json()
EOF
```

### Issue: "Connection refused when calling API"

**Symptoms:**
```python
ConnectionRefusedError: [Errno 61] Connection refused
```

**Solution:**
```python
# Check server is running
import requests
try:
    response = requests.get("http://localhost:8080/health")
    print(f"Server status: {response.json()}")
except requests.ConnectionError:
    print("Server is not running!")

# Verify correct URL
# If using Docker, use host.docker.internal on Mac/Windows
# or container name if in same Docker network
config_url = "http://host.docker.internal:8080"  # Docker Desktop
# or
config_url = "http://llm-config:8080"  # Docker Compose
```

### Issue: "Timeout errors"

**Symptoms:**
```python
requests.exceptions.ReadTimeout: HTTPConnectionPool(host='localhost', port=8080): Read timed out.
```

**Solution:**
```python
import requests

# Increase timeout
response = requests.get(
    "http://localhost:8080/api/v1/configs/app/llm/model",
    params={"env": "production"},
    timeout=30  # 30 seconds
)

# Or implement retry logic
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry

session = requests.Session()
retry = Retry(total=3, backoff_factor=1)
adapter = HTTPAdapter(max_retries=retry)
session.mount('http://', adapter)

response = session.get("http://localhost:8080/api/v1/configs/app/llm/model")
```

## FAQ

### How do I backup my configurations?

```bash
# Export all configurations
llm-config export --output backup.yaml

# Export specific namespace
llm-config export --namespace app/llm --output llm-backup.yaml

# Backup database (if using PostgreSQL)
pg_dump -U llm_config_user llm_config > backup.sql

# For file storage, backup the data directory
tar -czf llm-config-backup.tar.gz /var/lib/llm-config/
```

### How do I restore configurations?

```bash
# Import from backup
llm-config import --input backup.yaml

# Restore database
psql -U llm_config_user llm_config < backup.sql

# Restore file storage
tar -xzf llm-config-backup.tar.gz -C /
```

### How do I migrate between environments?

```bash
# Export from source environment
llm-config export --env production --output prod-config.yaml

# Import to target environment
llm-config import --input prod-config.yaml --env staging

# Or copy specific configs
llm-config get app/llm model --env production | \
  llm-config set app/llm model --env staging
```

### How do I rotate encryption keys?

```bash
# 1. Generate new key
NEW_KEY=$(llm-config keygen)

# 2. Export with old key
export LLM_CONFIG_KEY="old-key"
llm-config export --output backup.yaml

# 3. Switch to new key
export LLM_CONFIG_KEY="$NEW_KEY"

# 4. Re-import (will re-encrypt with new key)
llm-config import --input backup.yaml

# 5. Update key in production
kubectl set env deployment/llm-config LLM_CONFIG_KEY="$NEW_KEY"
```

### How do I debug configuration issues?

```bash
# Enable debug logging
export RUST_LOG=debug
llm-config-server

# Check configuration with verbose output
llm-config get app/llm model --env production --verbose

# Validate configuration file
llm-config-server --config config.yaml --validate

# Test API with curl verbose mode
curl -v http://localhost:8080/api/v1/configs/app/llm/model?env=production

# Check server metrics
curl http://localhost:9090/metrics
```

### How do I improve performance?

```bash
# 1. Enable caching
cat > config.yaml <<EOF
cache:
  l1:
    enabled: true
    max_size: 1000

  l2:
    enabled: true
    type: "redis"
    url: "redis://localhost:6379"
EOF

# 2. Use connection pooling
# 3. Implement client-side caching
# 4. Use CDN for static content
# 5. Scale horizontally with multiple instances
```

### How do I monitor the system?

```bash
# Check health
curl http://localhost:8080/health

# View metrics
curl http://localhost:9090/metrics

# Access Grafana (if using Docker Compose)
open http://localhost:3000

# Check logs
tail -f /var/log/llm-config/app.log
tail -f /var/log/llm-config/audit.log

# Monitor with Prometheus
open http://localhost:9091
```

### How do I secure my deployment?

```yaml
# config.yaml - Production security settings
server:
  enable_security: true
  tls_enabled: true

security:
  rate_limiting:
    enabled: true

  policies:
    require_tls: true
    allowed_ips:
      - "10.0.0.0/8"  # Internal network only

  rbac:
    enabled: true

audit:
  enabled: true
  retention_days: 90
```

### How do I test my configuration?

```bash
# 1. Set test configuration
llm-config set test/config value "test" --env development

# 2. Retrieve and verify
llm-config get test/config value --env development

# 3. Test API endpoint
curl http://localhost:8080/api/v1/configs/test/config/value?env=development

# 4. Clean up
llm-config delete test/config value --env development

# 5. Run integration tests
cargo test --package llm-config-integration-tests
```

## Getting Help

### Community Support

- **Documentation**: https://docs.llm-config-manager.io
- **GitHub Issues**: https://github.com/llm-devops/llm-config-manager/issues
- **GitHub Discussions**: https://github.com/llm-devops/llm-config-manager/discussions
- **Discord**: https://discord.gg/llm-config-manager

### Enterprise Support

- **Email**: enterprise@llm-config-manager.io
- **Security Issues**: security@llm-config-manager.io
- **Phone**: Contact via enterprise email

### Before Asking for Help

Please provide:

1. **Version**: `llm-config-server --version`
2. **Environment**: OS, Rust version, deployment method
3. **Configuration**: Sanitized config.yaml (remove secrets!)
4. **Logs**: Relevant log entries with timestamps
5. **Steps to reproduce**: What you did, what you expected, what happened
6. **Error messages**: Full error output with stack traces

**Example:**

```markdown
## Issue Description
API returns 500 error when trying to get configuration

## Environment
- OS: Ubuntu 22.04
- Rust: 1.75.0
- Deployment: Docker
- Version: 0.5.0

## Configuration
```yaml
server:
  port: 8080
  enable_security: true
```

## Steps to Reproduce
1. Start server: `docker-compose up -d`
2. Set config: `llm-config set app/llm model "gpt-4" --env production`
3. Get config: `curl http://localhost:8080/api/v1/configs/app/llm/model?env=production`

## Error Output
```
{"error": "Internal Server Error"}
```

## Logs
```
2025-11-21 12:00:00 ERROR Failed to connect to database: connection refused
```
```

## Next Steps

- Review [Getting Started Guide](getting-started.md) for setup help
- See [Configuration Guide](configuration.md) for configuration options
- Check [Integration Guide](integration.md) for integration issues
- Read [Use Cases & Examples](examples/) for usage patterns
