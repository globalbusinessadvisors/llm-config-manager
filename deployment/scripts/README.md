# Deployment Scripts

Automated deployment scripts for LLM Config Manager supporting multiple deployment methods.

## Available Scripts

- **deploy-docker.sh** - Docker Compose deployment
- **deploy-kubernetes.sh** - Kubernetes deployment using kubectl
- **deploy-helm.sh** - Helm chart deployment
- **deploy-systemd.sh** - Systemd service deployment

## Prerequisites

### General
- Bash 4.0+
- curl
- openssl (for secret generation)

### Docker Deployment
- Docker 20.10+
- Docker Compose 2.0+ (or docker-compose 1.29+)

### Kubernetes Deployment
- kubectl 1.25+
- Access to a Kubernetes cluster
- (Optional) Prometheus Operator for monitoring

### Helm Deployment
- Helm 3.x
- kubectl 1.25+
- Access to a Kubernetes cluster

### Systemd Deployment
- Systemd-based Linux distribution
- PostgreSQL and Redis (if not embedded)
- Root access

## Docker Deployment

### Quick Start

```bash
# Start all services
./deploy-docker.sh start

# View logs
./deploy-docker.sh logs

# Check status
./deploy-docker.sh status

# Stop services
./deploy-docker.sh stop
```

### Commands

- `start` - Build and start all services
- `stop` - Stop all services
- `restart` - Restart all services
- `logs` - View service logs
- `status` - Show service status
- `health` - Check service health
- `build` - Build Docker image only

### Access

- **Application**: http://localhost:8080
- **Metrics**: http://localhost:9090/metrics
- **Prometheus**: http://localhost:9091
- **Grafana**: http://localhost:3000 (admin/admin)

## Kubernetes Deployment

### Quick Start

```bash
# Install using kubectl
./deploy-kubernetes.sh install

# View status
./deploy-kubernetes.sh status

# Port forward to local machine
./deploy-kubernetes.sh port-forward
```

### Commands

- `install` - Install using kubectl
- `install-kustomize` - Install using kustomize
- `upgrade` - Upgrade deployment
- `uninstall` - Uninstall (with confirmation)
- `status` - Show deployment status
- `logs` - View pod logs
- `health` - Check application health
- `port-forward` - Port forward to localhost:8080

### Environment Variables

- `NAMESPACE` - Kubernetes namespace (default: llm-config)

### Notes

- Generates secure random secrets automatically
- Creates `secrets-generated.yaml` (not committed to git)
- Requires appropriate cluster permissions

## Helm Deployment

### Quick Start

```bash
# Create environment-specific values
./deploy-helm.sh create-values production

# Install with default values
./deploy-helm.sh install

# Install with custom values
VALUES_FILE=./deployment/helm/values-production.yaml ./deploy-helm.sh install

# Upgrade
./deploy-helm.sh upgrade

# Uninstall
./deploy-helm.sh uninstall
```

### Commands

- `install` - Install Helm chart
- `upgrade` - Upgrade existing release
- `uninstall` - Uninstall release (with confirmation)
- `status` - Show release status
- `values` - Get current values
- `logs` - View pod logs
- `rollback [revision]` - Rollback to specific revision
- `lint` - Lint Helm chart
- `dry-run` - Test installation without applying
- `create-values [env]` - Create environment-specific values file

### Environment Variables

- `RELEASE_NAME` - Helm release name (default: llm-config)
- `NAMESPACE` - Kubernetes namespace (default: llm-config)
- `VALUES_FILE` - Path to custom values file

### Examples

```bash
# Development deployment
RELEASE_NAME=llm-dev NAMESPACE=dev VALUES_FILE=values-dev.yaml ./deploy-helm.sh install

# Production deployment with custom values
VALUES_FILE=values-prod.yaml ./deploy-helm.sh install

# Check what will be installed
./deploy-helm.sh dry-run

# Upgrade with new image tag
helm upgrade llm-config ./deployment/helm/llm-config-manager \
  --set image.tag=v1.1.0 \
  --namespace llm-config
```

## Systemd Deployment

### Quick Start

```bash
# Build the project first
cargo build --release

# Install service (requires root)
sudo ./deploy-systemd.sh install

# Check status
./deploy-systemd.sh status

# View logs
./deploy-systemd.sh logs
```

### Commands

- `install` - Full installation (user, dirs, config, service)
- `uninstall` - Uninstall (with confirmation)
- `start` - Start services
- `stop` - Stop services
- `restart` - Restart services
- `status` - Show service status
- `logs` - View logs (journalctl)

### Installation Steps

The install command performs:

1. Creates `llmconfig` system user
2. Creates required directories
3. Installs binary to `/usr/local/bin/`
4. Installs configuration to `/etc/llm-config/`
5. Generates secure secrets
6. Installs systemd units
7. Enables and starts services

### Files Created

- `/usr/local/bin/llm-config-server` - Binary
- `/etc/llm-config/config.yaml` - Configuration
- `/etc/llm-config/environment` - Environment variables
- `/etc/default/llm-config-manager` - Secrets (600 permissions)
- `/etc/systemd/system/llm-config-*.service` - Service units
- `/etc/systemd/system/llm-config-*.timer` - Timer units
- `/var/lib/llm-config/{data,cache,backups}/` - Data directories
- `/var/log/llm-config/` - Log directory

### Systemd Services

- **llm-config-manager.service** - Main application
- **llm-config-backup.timer** - Daily backups (2 AM)
- **llm-config-cleanup.timer** - Weekly cleanup (Sunday 3 AM)
- **llm-config-healthcheck.timer** - Health checks (every 5 min)

### Managing the Service

```bash
# Start/stop/restart
sudo systemctl start llm-config-manager
sudo systemctl stop llm-config-manager
sudo systemctl restart llm-config-manager

# View logs
sudo journalctl -u llm-config-manager -f

# Check status
systemctl status llm-config-manager

# List timers
systemctl list-timers llm-config-*
```

## Security Considerations

### Secrets Management

All scripts generate secure random secrets automatically:

- Encryption keys: 32 bytes (base64 encoded)
- Passwords: 24 bytes (base64 encoded)
- Tokens: 32 bytes (base64 encoded)

Generated secrets are stored in:
- Docker: `.env` file (git-ignored)
- Kubernetes: `secrets-generated.yaml` (git-ignored)
- Helm: Custom values file (should be git-ignored)
- Systemd: `/etc/default/llm-config-manager` (600 permissions)

### Best Practices

1. **Never commit secrets to version control**
2. **Rotate secrets regularly** (every 90 days recommended)
3. **Use external secret management** in production:
   - HashiCorp Vault
   - AWS Secrets Manager
   - Azure Key Vault
   - Google Secret Manager
   - Kubernetes External Secrets Operator

4. **Backup secrets securely**
5. **Use TLS/HTTPS** in production
6. **Enable audit logging**
7. **Restrict network access** with firewalls/network policies

## Monitoring

All deployment methods include monitoring integration:

### Metrics

- **Endpoint**: `/metrics` (port 9090)
- **Format**: Prometheus
- **Metrics**: 50+ application and system metrics

### Health Checks

- **Endpoint**: `/health`
- **Checks**: Storage, cache, database, disk space

### Dashboards

- Pre-configured Grafana dashboards
- 14 panels covering all subsystems
- Real-time metrics visualization

## Troubleshooting

### Docker Issues

```bash
# Check service logs
./deploy-docker.sh logs

# Restart specific service
docker-compose restart llm-config-manager

# Rebuild image
docker-compose build --no-cache llm-config-manager

# Check health
curl http://localhost:8080/health
```

### Kubernetes Issues

```bash
# Check pod status
kubectl get pods -n llm-config

# View pod logs
kubectl logs -n llm-config <pod-name>

# Describe pod
kubectl describe pod -n llm-config <pod-name>

# Execute into pod
kubectl exec -it -n llm-config <pod-name> -- /bin/sh
```

### Helm Issues

```bash
# Check release status
helm status llm-config -n llm-config

# View values
helm get values llm-config -n llm-config

# View manifest
helm get manifest llm-config -n llm-config

# Rollback
helm rollback llm-config -n llm-config
```

### Systemd Issues

```bash
# Check service status
systemctl status llm-config-manager

# View logs
journalctl -u llm-config-manager -xe

# Test configuration
/usr/local/bin/llm-config-server check-config --config /etc/llm-config/config.yaml

# Check permissions
ls -la /var/lib/llm-config/
ls -la /etc/llm-config/
```

## Upgrading

### Docker

```bash
# Pull latest image or rebuild
./deploy-docker.sh build

# Restart services
./deploy-docker.sh restart
```

### Kubernetes

```bash
# Update image tag in deployment.yaml
# Then apply
./deploy-kubernetes.sh upgrade
```

### Helm

```bash
# Upgrade with new chart version
./deploy-helm.sh upgrade

# Or with custom values
VALUES_FILE=values-prod.yaml ./deploy-helm.sh upgrade
```

### Systemd

```bash
# Build new binary
cargo build --release

# Stop service
sudo systemctl stop llm-config-manager

# Replace binary
sudo cp target/release/llm-config-server /usr/local/bin/

# Start service
sudo systemctl start llm-config-manager
```

## Backup and Restore

### Docker

```bash
# Backup data volume
docker run --rm -v llm-config-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/backup.tar.gz /data

# Restore
docker run --rm -v llm-config-data:/data -v $(pwd):/backup \
  alpine tar xzf /backup/backup.tar.gz -C /
```

### Kubernetes

```bash
# Create manual backup
kubectl exec -n llm-config deployment/llm-config-manager -- \
  /usr/local/bin/llm-config-server backup --output /backups/manual-backup.tar.gz

# Copy backup locally
kubectl cp llm-config/<pod-name>:/backups/manual-backup.tar.gz ./backup.tar.gz
```

### Systemd

```bash
# Manual backup
sudo systemctl start llm-config-backup.service

# Backups are stored in /var/lib/llm-config/backups/

# Restore
sudo systemctl stop llm-config-manager
sudo tar xzf /var/lib/llm-config/backups/backup-YYYYMMDD-HHMMSS.tar.gz \
  -C /var/lib/llm-config/data
sudo systemctl start llm-config-manager
```

## Support

For issues and questions:
- GitHub Issues: https://github.com/llm-devops/llm-config-manager/issues
- Documentation: https://docs.llm-config.example.com
- Slack: #llm-config-support

## License

Apache License 2.0
