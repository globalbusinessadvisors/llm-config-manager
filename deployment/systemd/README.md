# Systemd Service Files

Production-ready systemd service files for deploying LLM Config Manager as a native Linux service.

## Files Overview

- **llm-config-manager.service** - Main application service
- **llm-config-backup.service** - Backup service (oneshot)
- **llm-config-backup.timer** - Daily backup timer
- **llm-config-cleanup.service** - Cleanup service for old backups/logs
- **llm-config-cleanup.timer** - Weekly cleanup timer
- **llm-config-healthcheck.service** - Health monitoring service
- **llm-config-healthcheck.timer** - Health check timer (every 5 min)
- **environment** - Environment variable configuration

## Prerequisites

- Systemd-based Linux distribution (Ubuntu 20.04+, Debian 11+, RHEL 8+, etc.)
- LLM Config Manager binary installed at `/usr/local/bin/llm-config-server`
- PostgreSQL and Redis (if not using embedded/file-based storage)

## Installation

### 1. Create User and Directories

```bash
# Create service user
sudo useradd -r -s /bin/false -m -d /var/lib/llm-config llmconfig

# Create directories
sudo mkdir -p /var/lib/llm-config/{data,cache,backups}
sudo mkdir -p /var/log/llm-config
sudo mkdir -p /etc/llm-config

# Set ownership
sudo chown -R llmconfig:llmconfig /var/lib/llm-config
sudo chown -R llmconfig:llmconfig /var/log/llm-config
sudo chown -R llmconfig:llmconfig /etc/llm-config
```

### 2. Install Binary

```bash
# Copy binary
sudo cp /path/to/llm-config-server /usr/local/bin/
sudo chmod 755 /usr/local/bin/llm-config-server
sudo chown root:root /usr/local/bin/llm-config-server
```

### 3. Install Configuration

```bash
# Copy production config
sudo cp config/production.yaml /etc/llm-config/config.yaml
sudo chown llmconfig:llmconfig /etc/llm-config/config.yaml
sudo chmod 600 /etc/llm-config/config.yaml

# Copy environment file
sudo cp deployment/systemd/environment /etc/llm-config/environment
sudo chown llmconfig:llmconfig /etc/llm-config/environment
sudo chmod 600 /etc/llm-config/environment
```

### 4. Configure Secrets

Create `/etc/default/llm-config-manager` with sensitive values:

```bash
sudo tee /etc/default/llm-config-manager > /dev/null <<'EOF'
# Encryption key (generate with: openssl rand -base64 32)
LLM_CONFIG_ENCRYPTION_KEY=YOUR_ENCRYPTION_KEY_HERE

# Database password
DATABASE_PASSWORD=YOUR_DB_PASSWORD_HERE

# Redis password
REDIS_PASSWORD=YOUR_REDIS_PASSWORD_HERE

# API token
API_TOKEN_SECRET=YOUR_API_TOKEN_HERE
EOF

# Secure the file
sudo chmod 600 /etc/default/llm-config-manager
sudo chown root:root /etc/default/llm-config-manager
```

### 5. Install Systemd Units

```bash
# Copy service files
sudo cp deployment/systemd/*.service /etc/systemd/system/
sudo cp deployment/systemd/*.timer /etc/systemd/system/

# Set permissions
sudo chmod 644 /etc/systemd/system/llm-config-*.service
sudo chmod 644 /etc/systemd/system/llm-config-*.timer

# Reload systemd
sudo systemctl daemon-reload
```

### 6. Enable and Start Services

```bash
# Enable main service
sudo systemctl enable llm-config-manager.service

# Enable backup timer
sudo systemctl enable llm-config-backup.timer

# Enable cleanup timer
sudo systemctl enable llm-config-cleanup.timer

# Enable health check timer
sudo systemctl enable llm-config-healthcheck.timer

# Start main service
sudo systemctl start llm-config-manager.service

# Start timers
sudo systemctl start llm-config-backup.timer
sudo systemctl start llm-config-cleanup.timer
sudo systemctl start llm-config-healthcheck.timer
```

## Managing the Service

### Service Control

```bash
# Start service
sudo systemctl start llm-config-manager

# Stop service
sudo systemctl stop llm-config-manager

# Restart service
sudo systemctl restart llm-config-manager

# Reload configuration (without restart)
sudo systemctl reload llm-config-manager

# Check status
sudo systemctl status llm-config-manager

# View logs
sudo journalctl -u llm-config-manager -f

# View logs since boot
sudo journalctl -u llm-config-manager -b
```

### Timer Management

```bash
# List all timers
systemctl list-timers llm-config-*

# Check timer status
sudo systemctl status llm-config-backup.timer

# Manually trigger backup
sudo systemctl start llm-config-backup.service

# View backup logs
sudo journalctl -u llm-config-backup
```

### Health Monitoring

```bash
# Check health status
curl http://localhost:8080/health

# View health check logs
sudo journalctl -u llm-config-healthcheck
```

## Security Features

The service units include comprehensive security hardening:

### Filesystem Protection
- `ProtectSystem=strict` - Read-only filesystem except specific paths
- `ProtectHome=true` - No access to user home directories
- `ReadWritePaths=` - Explicitly allowed write paths
- `PrivateTmp=true` - Isolated /tmp directory

### Namespace Isolation
- `RestrictNamespaces=true` - No namespace creation
- `PrivateMounts=true` - Private mount namespace

### System Call Filtering
- `SystemCallFilter=@system-service` - Only allow service-related syscalls
- `SystemCallFilter=~@privileged` - Block privileged syscalls
- `SystemCallArchitectures=native` - Only native architecture

### Capabilities
- `CapabilityBoundingSet=` - No capabilities
- `AmbientCapabilities=` - No ambient capabilities
- `NoNewPrivileges=true` - Prevent privilege escalation

### Resource Limits
- `MemoryMax=2G` - Maximum memory usage
- `CPUQuota=200%` - Maximum CPU usage (2 cores)
- `TasksMax=4096` - Maximum number of tasks
- `LimitNOFILE=65536` - File descriptor limit

### Network Restrictions
- `RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6` - Only allow necessary address families

## Logging

### View Logs

```bash
# Real-time logs
sudo journalctl -u llm-config-manager -f

# Last 100 lines
sudo journalctl -u llm-config-manager -n 100

# Since specific time
sudo journalctl -u llm-config-manager --since "2024-01-01 00:00:00"

# Errors only
sudo journalctl -u llm-config-manager -p err

# JSON format
sudo journalctl -u llm-config-manager -o json-pretty
```

### Log Rotation

Configure journald log rotation in `/etc/systemd/journald.conf`:

```ini
[Journal]
SystemMaxUse=1G
SystemMaxFileSize=100M
RuntimeMaxUse=100M
MaxRetentionSec=7day
```

Then restart journald:

```bash
sudo systemctl restart systemd-journald
```

## Backup and Restore

### Manual Backup

```bash
# Trigger backup manually
sudo systemctl start llm-config-backup.service

# Check backup status
sudo systemctl status llm-config-backup.service

# List backups
ls -lh /var/lib/llm-config/backups/
```

### Restore from Backup

```bash
# Stop service
sudo systemctl stop llm-config-manager

# Restore backup
sudo -u llmconfig tar xzf /var/lib/llm-config/backups/backup-YYYYMMDD-HHMMSS.tar.gz -C /var/lib/llm-config/data

# Start service
sudo systemctl start llm-config-manager
```

## Monitoring

### Systemd Status

```bash
# Service status
systemctl is-active llm-config-manager
systemctl is-enabled llm-config-manager
systemctl is-failed llm-config-manager

# Resource usage
systemd-cgtop -1 | grep llm-config
```

### Metrics

Metrics are exposed at `http://localhost:9090/metrics` in Prometheus format.

```bash
# Check metrics endpoint
curl http://localhost:9090/metrics
```

### Integration with Monitoring

Configure Prometheus to scrape metrics:

```yaml
scrape_configs:
  - job_name: 'llm-config-manager'
    static_configs:
      - targets: ['localhost:9090']
```

## Troubleshooting

### Service Won't Start

```bash
# Check for configuration errors
sudo /usr/local/bin/llm-config-server check-config --config /etc/llm-config/config.yaml

# Check service status
sudo systemctl status llm-config-manager -l

# View detailed logs
sudo journalctl -u llm-config-manager -xe

# Check file permissions
ls -la /var/lib/llm-config/
ls -la /etc/llm-config/
```

### Permission Issues

```bash
# Fix ownership
sudo chown -R llmconfig:llmconfig /var/lib/llm-config
sudo chown -R llmconfig:llmconfig /var/log/llm-config

# Fix permissions
sudo chmod 755 /var/lib/llm-config
sudo chmod 755 /var/lib/llm-config/data
sudo chmod 755 /var/lib/llm-config/cache
sudo chmod 755 /var/lib/llm-config/backups
sudo chmod 600 /etc/llm-config/config.yaml
```

### Database Connection Issues

```bash
# Test database connection
sudo -u llmconfig psql -h localhost -U llm_config_user -d llm_config -c "SELECT version();"

# Check PostgreSQL status
sudo systemctl status postgresql

# View PostgreSQL logs
sudo journalctl -u postgresql
```

### High Memory Usage

```bash
# Check current usage
systemd-cgtop -1 | grep llm-config

# Adjust memory limit
sudo systemctl edit llm-config-manager

# Add override:
[Service]
MemoryMax=4G

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart llm-config-manager
```

## Upgrading

### Zero-Downtime Upgrade

```bash
# 1. Stop timers
sudo systemctl stop llm-config-backup.timer
sudo systemctl stop llm-config-cleanup.timer
sudo systemctl stop llm-config-healthcheck.timer

# 2. Backup current binary
sudo cp /usr/local/bin/llm-config-server /usr/local/bin/llm-config-server.backup

# 3. Install new binary
sudo cp /path/to/new/llm-config-server /usr/local/bin/

# 4. Test configuration
sudo /usr/local/bin/llm-config-server check-config --config /etc/llm-config/config.yaml

# 5. Restart service
sudo systemctl restart llm-config-manager

# 6. Verify service is running
sudo systemctl status llm-config-manager
curl http://localhost:8080/health

# 7. Restart timers
sudo systemctl start llm-config-backup.timer
sudo systemctl start llm-config-cleanup.timer
sudo systemctl start llm-config-healthcheck.timer
```

### Rollback

```bash
# Restore previous binary
sudo cp /usr/local/bin/llm-config-server.backup /usr/local/bin/llm-config-server

# Restart service
sudo systemctl restart llm-config-manager
```

## Uninstallation

```bash
# Stop and disable services
sudo systemctl stop llm-config-manager
sudo systemctl stop llm-config-backup.timer
sudo systemctl stop llm-config-cleanup.timer
sudo systemctl stop llm-config-healthcheck.timer
sudo systemctl disable llm-config-manager
sudo systemctl disable llm-config-backup.timer
sudo systemctl disable llm-config-cleanup.timer
sudo systemctl disable llm-config-healthcheck.timer

# Remove service files
sudo rm /etc/systemd/system/llm-config-*.service
sudo rm /etc/systemd/system/llm-config-*.timer

# Reload systemd
sudo systemctl daemon-reload

# Remove binary
sudo rm /usr/local/bin/llm-config-server

# Remove data (CAREFUL: This deletes all data!)
# sudo rm -rf /var/lib/llm-config
# sudo rm -rf /var/log/llm-config
# sudo rm -rf /etc/llm-config

# Remove user
# sudo userdel llmconfig
```

## Best Practices

1. **Always backup before upgrades**
2. **Test configuration changes in staging first**
3. **Monitor logs after changes**
4. **Keep secrets in `/etc/default/llm-config-manager`, not in git**
5. **Rotate encryption keys regularly**
6. **Review and adjust resource limits based on workload**
7. **Enable automatic security updates**
8. **Use TLS for production deployments**
9. **Configure log aggregation for centralized logging**
10. **Set up external monitoring and alerting**

## Support

For issues and questions:
- GitHub Issues: https://github.com/llm-devops/llm-config-manager/issues
- Documentation: https://docs.llm-config.example.com
- Slack: #llm-config-support
