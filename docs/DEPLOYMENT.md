# LLM Config Manager - Deployment Guide

Complete deployment guide for LLM Config Manager covering all supported deployment methods.

## Table of Contents

1. [Overview](#overview)
2. [Deployment Options](#deployment-options)
3. [Prerequisites](#prerequisites)
4. [Quick Start](#quick-start)
5. [Docker Deployment](#docker-deployment)
6. [Kubernetes Deployment](#kubernetes-deployment)
7. [Helm Deployment](#helm-deployment)
8. [Systemd Deployment](#systemd-deployment)
9. [Configuration](#configuration)
10. [Security](#security)
11. [Monitoring](#monitoring)
12. [Backup and Restore](#backup-and-restore)
13. [Troubleshooting](#troubleshooting)
14. [Production Checklist](#production-checklist)

## Overview

LLM Config Manager supports multiple deployment methods to fit different infrastructure requirements:

- **Docker Compose** - Quick start, development, small deployments
- **Kubernetes** - Production-grade orchestration, high availability
- **Helm** - Simplified Kubernetes deployment with package management
- **Systemd** - Native Linux service for bare-metal/VM deployments

All deployment methods include:
- Automated secret generation
- Health checks
- Metrics and monitoring
- Backup automation
- Security hardening

## Deployment Options

| Method | Use Case | Complexity | HA Support | Auto-scaling |
|--------|----------|------------|------------|--------------|
| Docker Compose | Development, small deployments | Low | No | No |
| Kubernetes | Production, enterprise | Medium | Yes | Manual |
| Helm | Production with easy management | Low | Yes | Yes |
| Systemd | Bare metal, VMs | Medium | No | No |

## Prerequisites

### All Deployments

- **Operating System**: Linux (Ubuntu 20.04+, Debian 11+, RHEL 8+)
- **Tools**: bash, curl, openssl
- **Network**: Internet access for downloading dependencies
- **Storage**: Minimum 100GB available disk space

### Docker Deployment

- Docker 20.10+
- Docker Compose 2.0+ (or 1.29+)
- 4GB RAM minimum (8GB recommended)
- 2 CPU cores minimum (4 recommended)

### Kubernetes Deployment

- Kubernetes cluster 1.25+
- kubectl configured with cluster access
- Storage provisioner (for PersistentVolumes)
- Ingress controller (NGINX recommended)
- 8GB RAM per node minimum
- 4 CPU cores per node minimum

### Helm Deployment

- Helm 3.x
- Kubernetes 1.25+
- kubectl configured
- Same requirements as Kubernetes

### Systemd Deployment

- Systemd-based Linux distribution
- PostgreSQL 12+ (if not using embedded storage)
- Redis 6+ (if using distributed cache)
- 8GB RAM minimum
- 4 CPU cores minimum
- Root access

## Quick Start

### Option 1: Docker Compose (Fastest)

```bash
cd llm-config-manager
./deployment/scripts/deploy-docker.sh start
```

Access at http://localhost:8080

### Option 2: Helm (Production-Ready)

```bash
# Create values file with secrets
./deployment/scripts/deploy-helm.sh create-values production

# Edit and customize
vim deployment/helm/values-production.yaml

# Install
VALUES_FILE=deployment/helm/values-production.yaml ./deployment/scripts/deploy-helm.sh install
```

### Option 3: Systemd (Bare Metal)

```bash
# Build binary
cargo build --release

# Install service
sudo ./deployment/scripts/deploy-systemd.sh install
```

## Docker Deployment

### Installation

```bash
cd llm-config-manager

# Start all services
./deployment/scripts/deploy-docker.sh start
```

The script will:
1. Check prerequisites (Docker, Docker Compose)
2. Generate secure random secrets in `.env`
3. Build the Docker image
4. Start all services:
   - LLM Config Manager (port 8080, 9090)
   - PostgreSQL (port 5432)
   - Redis (port 6379)
   - Prometheus (port 9091)
   - Grafana (port 3000)
   - Alertmanager (port 9093)
   - Node Exporter (port 9100)

### Managing Services

```bash
# View logs
./deployment/scripts/deploy-docker.sh logs

# Check status
./deployment/scripts/deploy-docker.sh status

# Restart services
./deployment/scripts/deploy-docker.sh restart

# Stop services
./deployment/scripts/deploy-docker.sh stop

# Check health
./deployment/scripts/deploy-docker.sh health
```

### Access Points

- **Application API**: http://localhost:8080
- **Health Endpoint**: http://localhost:8080/health
- **Metrics**: http://localhost:9090/metrics
- **Prometheus**: http://localhost:9091
- **Grafana**: http://localhost:3000 (default: admin/admin)
- **Alertmanager**: http://localhost:9093

### Customization

Edit `docker-compose.yml` to customize:

```yaml
services:
  llm-config-manager:
    environment:
      - SERVER_WORKERS=8  # Increase workers
    resources:
      limits:
        memory: 4G  # Increase memory
```

Restart to apply changes:

```bash
./deployment/scripts/deploy-docker.sh restart
```

## Kubernetes Deployment

### Installation

```bash
# Install using kubectl
./deployment/scripts/deploy-kubernetes.sh install
```

The script will:
1. Generate secure secrets
2. Create namespace `llm-config`
3. Deploy all Kubernetes resources:
   - Deployment (3 replicas)
   - Services (ClusterIP, LoadBalancer, Headless)
   - Ingress
   - HorizontalPodAutoscaler
   - PodDisruptionBudget
   - NetworkPolicies
   - ServiceMonitor (if Prometheus Operator is installed)
   - PostgreSQL StatefulSet
   - Redis StatefulSet

### Accessing the Application

**Via Port Forward** (local development):

```bash
./deployment/scripts/deploy-kubernetes.sh port-forward
```

Access at http://localhost:8080

**Via Ingress** (production):

1. Update `deployment/kubernetes/ingress.yaml` with your domain
2. Configure DNS to point to ingress controller
3. Access at https://your-domain.com

### Managing Deployment

```bash
# View status
./deployment/scripts/deploy-kubernetes.sh status

# View logs
./deployment/scripts/deploy-kubernetes.sh logs

# Check health
./deployment/scripts/deploy-kubernetes.sh health

# Upgrade deployment
./deployment/scripts/deploy-kubernetes.sh upgrade

# Uninstall
./deployment/scripts/deploy-kubernetes.sh uninstall
```

### Scaling

**Manual Scaling**:

```bash
kubectl scale deployment llm-config-manager -n llm-config --replicas=5
```

**Auto-Scaling** (already configured via HPA):

- Min replicas: 3
- Max replicas: 10
- Target CPU: 70%
- Target Memory: 80%

### Storage

Persistent volumes are automatically provisioned for:

- Application data (50GB)
- Cache storage (20GB)
- Backups (100GB)
- Logs (10GB)
- PostgreSQL (50GB)
- Redis (10GB)
- Prometheus (30GB)
- Grafana (5GB)

Update storage class in `deployment/kubernetes/pvc.yaml`:

```yaml
storageClassName: fast-ssd  # Your storage class
```

## Helm Deployment

### Create Values File

```bash
# Generate production values
./deployment/scripts/deploy-helm.sh create-values production

# Edit values
vim deployment/helm/values-production.yaml
```

Update critical values:

```yaml
ingress:
  hosts:
    - host: api.llm-config.example.com  # Your domain

secrets:
  encryptionKey: "..."  # From generated values

postgresql:
  auth:
    password: "..."  # From generated values

redis:
  auth:
    password: "..."  # From generated values
```

### Installation

```bash
# Install with custom values
VALUES_FILE=deployment/helm/values-production.yaml ./deployment/scripts/deploy-helm.sh install

# Or install with inline overrides
helm install llm-config ./deployment/helm/llm-config-manager \
  --namespace llm-config \
  --create-namespace \
  --set replicaCount=5 \
  --set resources.limits.memory=4Gi
```

### Managing Release

```bash
# Check status
./deployment/scripts/deploy-helm.sh status

# View current values
./deployment/scripts/deploy-helm.sh values

# View logs
./deployment/scripts/deploy-helm.sh logs

# Upgrade
VALUES_FILE=deployment/helm/values-production.yaml ./deployment/scripts/deploy-helm.sh upgrade

# Rollback
./deployment/scripts/deploy-helm.sh rollback 1
```

### Helm Values Reference

Key configuration options:

```yaml
# Replicas
replicaCount: 3

# Image
image:
  repository: llm-config-manager
  tag: "v1.0.0"
  pullPolicy: IfNotPresent

# Resources
resources:
  limits:
    cpu: 2000m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 512Mi

# Auto-scaling
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

# Storage
persistence:
  enabled: true
  storageClass: "fast-ssd"
  data:
    size: 100Gi

# Monitoring
monitoring:
  prometheus:
    enabled: true
  grafana:
    enabled: true
```

## Systemd Deployment

### Build Application

```bash
# Build release binary
cargo build --release

# Verify binary
./target/release/llm-config-server --version
```

### Installation

```bash
# Install service (requires root)
sudo ./deployment/scripts/deploy-systemd.sh install
```

The script will:
1. Create `llmconfig` system user
2. Create directories in `/var/lib/llm-config` and `/var/log/llm-config`
3. Install binary to `/usr/local/bin/llm-config-server`
4. Install configuration to `/etc/llm-config/`
5. Generate secure secrets in `/etc/default/llm-config-manager`
6. Install systemd units
7. Enable and start services

### Managing Service

```bash
# Check status
systemctl status llm-config-manager

# Start/stop/restart
sudo systemctl start llm-config-manager
sudo systemctl stop llm-config-manager
sudo systemctl restart llm-config-manager

# View logs
sudo journalctl -u llm-config-manager -f

# View logs since boot
sudo journalctl -u llm-config-manager -b

# Reload configuration
sudo systemctl reload llm-config-manager
```

### Timers

Three timers are automatically configured:

**Backup Timer** (daily at 2 AM):
```bash
# Check status
systemctl status llm-config-backup.timer

# Manual backup
sudo systemctl start llm-config-backup.service

# View backup logs
sudo journalctl -u llm-config-backup
```

**Cleanup Timer** (weekly on Sunday at 3 AM):
```bash
# Check status
systemctl status llm-config-cleanup.timer

# Manual cleanup
sudo systemctl start llm-config-cleanup.service
```

**Health Check Timer** (every 5 minutes):
```bash
# Check status
systemctl status llm-config-healthcheck.timer

# Manual health check
sudo systemctl start llm-config-healthcheck.service
```

### Configuration

Main configuration files:

- `/etc/llm-config/config.yaml` - Application configuration
- `/etc/llm-config/environment` - Environment variables
- `/etc/default/llm-config-manager` - Secrets (600 permissions)

Edit configuration:

```bash
sudo vim /etc/llm-config/config.yaml

# Reload to apply changes
sudo systemctl reload llm-config-manager
```

### Upgrading

```bash
# Build new version
cargo build --release

# Stop service
sudo systemctl stop llm-config-manager

# Backup current binary
sudo cp /usr/local/bin/llm-config-server /usr/local/bin/llm-config-server.backup

# Install new binary
sudo cp target/release/llm-config-server /usr/local/bin/

# Start service
sudo systemctl start llm-config-manager

# Check status
systemctl status llm-config-manager
```

If issues occur, rollback:

```bash
sudo systemctl stop llm-config-manager
sudo cp /usr/local/bin/llm-config-server.backup /usr/local/bin/llm-config-server
sudo systemctl start llm-config-manager
```

## Configuration

### Environment Variables

Common configuration options across all deployment methods:

```bash
# Server configuration
SERVER_HOST=0.0.0.0
SERVER_PORT=8080
SERVER_WORKERS=4

# Logging
RUST_LOG=info
RUST_BACKTRACE=1

# Features
ENABLE_RBAC=true
ENABLE_ENCRYPTION=true
ENABLE_AUDIT=true
ENABLE_CACHE=true

# Cache configuration
CACHE_L1_SIZE=10000
CACHE_L1_TTL_SECONDS=3600
CACHE_L2_ENABLED=true

# Database
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=llm_config
DATABASE_USER=llm_config_user
DATABASE_PASSWORD=<secret>  # Never commit this

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=<secret>  # Never commit this

# Encryption
LLM_CONFIG_ENCRYPTION_KEY=<secret>  # Generated with: openssl rand -base64 32
```

### Configuration Files

**Production** (`config/production.yaml`):

```yaml
server:
  host: "0.0.0.0"
  port: 8080
  workers: 4
  enable_tls: true
  tls_cert: "/etc/llm-config/certs/cert.pem"
  tls_key: "/etc/llm-config/certs/key.pem"

storage:
  type: "postgres"
  path: "/var/lib/llm-config/data"
  backup_enabled: true
  backup_retention_days: 30

encryption:
  algorithm: "aes-256-gcm"
  key_rotation_enabled: true
  key_rotation_days: 90

audit:
  enabled: true
  retention_days: 365
  format: "json"

rbac:
  enabled: true
  cache_ttl_seconds: 3600

cache:
  l1_enabled: true
  l1_size: 10000
  l1_ttl_seconds: 3600
  l2_enabled: true
  l2_path: "/var/lib/llm-config/cache"

monitoring:
  metrics_enabled: true
  metrics_port: 9090
  health_check_interval_seconds: 30
```

## Security

### Secrets Management

**Docker**:
- Stored in `.env` file (git-ignored)
- File permissions: 600
- Generated automatically by deploy script

**Kubernetes**:
- Stored in Kubernetes Secrets
- Encrypted at rest (if enabled on cluster)
- Generated automatically by deploy script

**Helm**:
- Stored in values file (should be git-ignored)
- Use external secret management in production:
  - HashiCorp Vault
  - AWS Secrets Manager
  - Azure Key Vault

**Systemd**:
- Stored in `/etc/default/llm-config-manager`
- File permissions: 600, owned by root
- Generated automatically by deploy script

### TLS/HTTPS

**Kubernetes/Helm**:

1. Install cert-manager:
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

2. Create ClusterIssuer:
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
```

3. Update ingress annotation:
```yaml
annotations:
  cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

**Systemd**:

1. Obtain TLS certificate (Let's Encrypt, commercial CA)
2. Update `/etc/llm-config/config.yaml`:
```yaml
server:
  enable_tls: true
  tls_cert: "/etc/llm-config/certs/cert.pem"
  tls_key: "/etc/llm-config/certs/key.pem"
```

3. Restart service:
```bash
sudo systemctl restart llm-config-manager
```

### Security Hardening

**Docker**:
- Run as non-root user (llmconfig:1000)
- Read-only root filesystem where possible
- No capabilities added
- Security-conscious network policies

**Kubernetes**:
- Pod Security Standards: Baseline/Restricted
- Network Policies enabled
- Service accounts with minimal permissions
- Read-only root filesystem
- No privileged containers

**Systemd**:
- Run as dedicated user (llmconfig)
- Systemd security features:
  - `ProtectSystem=strict`
  - `PrivateTmp=true`
  - `NoNewPrivileges=true`
  - `RestrictNamespaces=true`
  - SystemCall filtering

### Key Rotation

Rotate encryption keys every 90 days:

```bash
# Generate new key
NEW_KEY=$(openssl rand -base64 32)

# Update configuration with new key
# Old encrypted data will be re-encrypted automatically

# For Docker
echo "ENCRYPTION_KEY=${NEW_KEY}" >> .env

# For Kubernetes
kubectl create secret generic llm-config-manager-secrets \
  --from-literal=ENCRYPTION_KEY="${NEW_KEY}" \
  --namespace llm-config \
  --dry-run=client -o yaml | kubectl apply -f -

# For Systemd
sudo bash -c "echo 'LLM_CONFIG_ENCRYPTION_KEY=${NEW_KEY}' >> /etc/default/llm-config-manager"

# Restart application
```

## Monitoring

All deployment methods include comprehensive monitoring.

### Metrics

**Prometheus Endpoint**: `/metrics` (port 9090)

**Available Metrics** (50+):
- Configuration operations (total, duration, errors)
- Cache performance (hits, misses, evictions)
- RBAC checks (total, denials, duration)
- Audit events (by type, by user)
- Storage operations (size, errors)
- Crypto operations (encryptions, key rotations)
- HTTP requests (total, duration, status)
- System metrics (uptime, memory, CPU)

### Dashboards

**Grafana**:
- Pre-configured dashboard with 14 panels
- Import from `monitoring/grafana/dashboards/overview.json`

**Panels**:
1. System Status
2. Uptime
3. Request Rate
4. Error Rate
5. P95 Latency
6. Cache Hit Rate
7. Active Configurations
8. Operations Breakdown
9. Permission Checks
10. Audit Events
11. Storage Size
12. Memory Usage

### Alerts

**Prometheus Alertmanager**:
- 40+ alert rules in `monitoring/prometheus/alerts.yml`

**Critical Alerts**:
- ServiceDown
- CriticalErrorRate (>10%)
- StorageFailure

**Warning Alerts**:
- HighErrorRate (>5%)
- HighLatency (P95 >100ms)
- LowCacheHitRate (<70%)
- HighMemoryUsage (>8GB)

**Security Alerts**:
- EncryptionFailures
- UnusualAccessPattern
- ExcessiveSecretAccess

### Health Checks

**HTTP Endpoint**: `/health`

**Response Example**:
```json
{
  "status": "healthy",
  "checks": {
    "storage": {
      "component": "storage",
      "status": "healthy",
      "last_check": "2024-01-15T10:30:00Z",
      "duration_ms": 5
    },
    "cache": {
      "component": "cache",
      "status": "healthy",
      "last_check": "2024-01-15T10:30:00Z",
      "duration_ms": 2
    },
    "database": {
      "component": "database",
      "status": "healthy",
      "last_check": "2024-01-15T10:30:00Z",
      "duration_ms": 10
    }
  },
  "timestamp": "2024-01-15T10:30:00Z",
  "uptime_seconds": 86400
}
```

**Status Values**:
- `healthy` - All systems operational
- `degraded` - Some components experiencing issues
- `unhealthy` - Critical components down

## Backup and Restore

### Docker

**Automated Backups**:
Backups are stored in the `llm-config-backups` volume.

**Manual Backup**:
```bash
# Backup data volume
docker run --rm \
  -v llm-config-data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/backup-$(date +%Y%m%d).tar.gz /data
```

**Restore**:
```bash
# Stop services
./deployment/scripts/deploy-docker.sh stop

# Restore data
docker run --rm \
  -v llm-config-data:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/backup-YYYYMMDD.tar.gz -C /

# Start services
./deployment/scripts/deploy-docker.sh start
```

### Kubernetes

**Automated Backups**:
Create a CronJob:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: llm-config-backup
  namespace: llm-config
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: backup
              image: llm-config-manager:latest
              command:
                - /usr/local/bin/llm-config-server
                - backup
                - --output
                - /backups/backup-$(date +%Y%m%d).tar.gz
              volumeMounts:
                - name: backups
                  mountPath: /backups
          volumes:
            - name: backups
              persistentVolumeClaim:
                claimName: llm-config-backups
          restartPolicy: OnFailure
```

**Manual Backup**:
```bash
kubectl exec -n llm-config deployment/llm-config-manager -- \
  /usr/local/bin/llm-config-server backup \
  --output /var/lib/llm-config/backups/manual-backup.tar.gz
```

**Restore**:
```bash
# Scale down to 0
kubectl scale deployment llm-config-manager -n llm-config --replicas=0

# Copy backup to pod
kubectl cp backup.tar.gz llm-config/<pod-name>:/tmp/

# Restore
kubectl exec -n llm-config <pod-name> -- \
  tar xzf /tmp/backup.tar.gz -C /var/lib/llm-config/data

# Scale back up
kubectl scale deployment llm-config-manager -n llm-config --replicas=3
```

### Systemd

**Automated Backups**:
The `llm-config-backup.timer` runs daily at 2 AM.

**Manual Backup**:
```bash
sudo systemctl start llm-config-backup.service
```

**Restore**:
```bash
# Stop service
sudo systemctl stop llm-config-manager

# Restore backup
sudo tar xzf /var/lib/llm-config/backups/backup-YYYYMMDD-HHMMSS.tar.gz \
  -C /var/lib/llm-config/data

# Start service
sudo systemctl start llm-config-manager
```

## Troubleshooting

### Common Issues

#### Service Won't Start

**Docker**:
```bash
# Check logs
./deployment/scripts/deploy-docker.sh logs

# Check individual service
docker-compose logs llm-config-manager

# Restart
./deployment/scripts/deploy-docker.sh restart
```

**Kubernetes**:
```bash
# Check pod status
kubectl get pods -n llm-config

# Describe pod
kubectl describe pod -n llm-config <pod-name>

# View logs
kubectl logs -n llm-config <pod-name>
```

**Systemd**:
```bash
# Check status
systemctl status llm-config-manager

# View detailed logs
journalctl -u llm-config-manager -xe

# Check configuration
/usr/local/bin/llm-config-server check-config --config /etc/llm-config/config.yaml
```

#### Database Connection Issues

**Check Database**:
```bash
# Docker
docker-compose exec postgres psql -U llm_config_user -d llm_config -c "SELECT version();"

# Kubernetes
kubectl exec -n llm-config postgres-0 -- psql -U llm_config_user -d llm_config -c "SELECT version();"

# Systemd
sudo -u llmconfig psql -h localhost -U llm_config_user -d llm_config -c "SELECT version();"
```

**Check Connectivity**:
```bash
# From application pod/container
nc -zv <database-host> 5432
```

#### High Memory Usage

**Check Usage**:
```bash
# Docker
docker stats llm-config-manager

# Kubernetes
kubectl top pods -n llm-config

# Systemd
systemd-cgtop -1 | grep llm-config
```

**Adjust Limits**:
```bash
# Docker - edit docker-compose.yml
services:
  llm-config-manager:
    deploy:
      resources:
        limits:
          memory: 4G

# Kubernetes - edit deployment.yaml
resources:
  limits:
    memory: 4Gi

# Systemd - create override
sudo systemctl edit llm-config-manager
# Add:
[Service]
MemoryMax=4G
```

#### Performance Issues

**Check Metrics**:
```bash
# View metrics
curl http://localhost:9090/metrics

# Check latency
curl -w "@-" -o /dev/null -s http://localhost:8080/health <<'EOF'
    time_namelookup:  %{time_namelookup}\n
       time_connect:  %{time_connect}\n
    time_appconnect:  %{time_appconnect}\n
   time_pretransfer:  %{time_pretransfer}\n
      time_redirect:  %{time_redirect}\n
 time_starttransfer:  %{time_starttransfer}\n
                    ----------\n
         time_total:  %{time_total}\n
EOF
```

**Tune Performance**:
```yaml
# Increase workers
SERVER_WORKERS=8

# Increase cache size
CACHE_L1_SIZE=50000

# Enable connection pooling
DATABASE_POOL_SIZE=50
REDIS_POOL_SIZE=20
```

### Debug Mode

Enable debug logging:

**Docker**:
```yaml
# docker-compose.yml
environment:
  - RUST_LOG=debug
```

**Kubernetes**:
```yaml
# deployment.yaml
env:
  - name: RUST_LOG
    value: debug
```

**Systemd**:
```bash
# /etc/llm-config/environment
RUST_LOG=debug

# Restart
sudo systemctl restart llm-config-manager
```

## Production Checklist

### Pre-Deployment

- [ ] Build and test application locally
- [ ] Run all integration tests
- [ ] Run benchmarks and validate performance
- [ ] Security audit completed
- [ ] Load testing performed
- [ ] Documentation reviewed and updated

### Deployment

- [ ] Generate secure random secrets
- [ ] Configure TLS/HTTPS certificates
- [ ] Set up external secret management
- [ ] Configure proper resource limits
- [ ] Enable monitoring and alerting
- [ ] Set up log aggregation
- [ ] Configure automated backups
- [ ] Test backup and restore procedures
- [ ] Set up disaster recovery plan
- [ ] Configure firewall rules
- [ ] Enable network policies (Kubernetes)
- [ ] Set up audit logging
- [ ] Configure RBAC permissions
- [ ] Test health checks

### Post-Deployment

- [ ] Verify all services are running
- [ ] Check health endpoints
- [ ] Validate metrics collection
- [ ] Test application functionality
- [ ] Verify backup automation
- [ ] Check log collection
- [ ] Test alerting rules
- [ ] Perform security scan
- [ ] Document deployment specifics
- [ ] Train operations team
- [ ] Create runbook
- [ ] Set up on-call rotation

### Ongoing Maintenance

- [ ] Monitor metrics and alerts
- [ ] Review logs regularly
- [ ] Rotate secrets every 90 days
- [ ] Apply security updates
- [ ] Test disaster recovery quarterly
- [ ] Review and update documentation
- [ ] Perform capacity planning
- [ ] Optimize based on metrics
- [ ] Conduct security audits
- [ ] Backup verification

## Support

### Documentation

- **Main Documentation**: [README.md](../README.md)
- **Configuration Guide**: [CONFIGURATION.md](CONFIGURATION.md)
- **Monitoring Guide**: [MONITORING.md](MONITORING.md)
- **API Documentation**: [API.md](API.md)
- **Security Guide**: [SECURITY.md](SECURITY.md)

### Community

- **GitHub Issues**: https://github.com/llm-devops/llm-config-manager/issues
- **Discussions**: https://github.com/llm-devops/llm-config-manager/discussions
- **Slack**: #llm-config-support

### Commercial Support

For enterprise support, SLA guarantees, and professional services:
- Email: enterprise@example.com
- Web: https://llm-config.example.com/enterprise

## License

Apache License 2.0 - See [LICENSE](../LICENSE) for details

---

**Last Updated**: 2025-11-21
**Version**: 1.0.0
