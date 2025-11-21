# Startup and Shutdown Procedures

**Version**: 1.0.0
**Last Updated**: 2025-11-21
**Purpose**: Standard operating procedures for starting and stopping LLM Config Manager services

## Table of Contents

1. [Overview](#overview)
2. [Pre-Startup Checklist](#pre-startup-checklist)
3. [Startup Procedures](#startup-procedures)
4. [Post-Startup Verification](#post-startup-verification)
5. [Shutdown Procedures](#shutdown-procedures)
6. [Emergency Shutdown](#emergency-shutdown)
7. [Restart Procedures](#restart-procedures)
8. [Troubleshooting](#troubleshooting)

## Overview

This runbook provides step-by-step procedures for safely starting and stopping LLM Config Manager services across all deployment methods.

### Service Dependencies

```
PostgreSQL/Redis (if used)
    ↓
LLM Config Manager API
    ↓
Load Balancer/Ingress
    ↓
Monitoring (Prometheus/Grafana)
```

**Startup Order**: Bottom-up (dependencies first)
**Shutdown Order**: Top-down (reverse order)

## Pre-Startup Checklist

Before starting services, verify:

### System Resources

```bash
# Check available disk space (need >10GB free)
df -h /var/lib/llm-config

# Check available memory (need >2GB free)
free -h

# Check CPU load
uptime
```

**Requirements**:
- Disk space: >10GB free
- Memory: >2GB available
- CPU load: <80%

### Configuration Files

```bash
# Docker Compose
test -f docker-compose.yml && echo "OK" || echo "MISSING"
test -f .env && echo "OK" || echo "MISSING"

# Kubernetes
kubectl get configmap llm-config-manager-config -n llm-config

# Systemd
test -f /etc/llm-config/config.yaml && echo "OK" || echo "MISSING"
test -f /etc/default/llm-config-manager && echo "OK" || echo "MISSING"
```

### Network Connectivity

```bash
# Check required ports are available
netstat -tuln | grep -E ':(8080|9090|5432|6379)'

# Test DNS resolution
nslookup example.com

# Test external connectivity (if needed)
curl -I https://google.com
```

### Encryption Keys

```bash
# Docker
grep -q "ENCRYPTION_KEY=" .env && echo "KEY CONFIGURED" || echo "KEY MISSING"

# Kubernetes
kubectl get secret llm-config-manager-secrets -n llm-config

# Systemd
sudo grep -q "LLM_CONFIG_ENCRYPTION_KEY=" /etc/default/llm-config-manager && \
  echo "KEY CONFIGURED" || echo "KEY MISSING"
```

## Startup Procedures

### Docker Compose Startup

#### Step 1: Start Dependencies

```bash
# Start PostgreSQL and Redis first
docker-compose up -d postgres redis

# Wait for databases to be ready (30 seconds)
sleep 30

# Verify PostgreSQL is ready
docker-compose exec postgres pg_isready -U llm_config_user

# Verify Redis is ready
docker-compose exec redis redis-cli ping
```

**Expected Output**:
```
postgres: accepting connections
PONG
```

#### Step 2: Start Application

```bash
# Start LLM Config Manager
docker-compose up -d llm-config-manager

# Wait for application startup (10 seconds)
sleep 10

# View startup logs
docker-compose logs --tail=50 llm-config-manager
```

**Expected Log Messages**:
```
INFO Starting LLM Config API server on 0.0.0.0:8080
INFO Storage initialized successfully
INFO Cache layer connected
INFO Security middleware enabled
INFO Server is ready to accept connections
```

#### Step 3: Start Monitoring

```bash
# Start Prometheus and Grafana
docker-compose up -d prometheus grafana alertmanager

# Verify monitoring stack
docker-compose ps
```

**Expected Status**: All services should be "Up"

### Kubernetes Startup

#### Step 1: Verify Cluster Status

```bash
# Check cluster health
kubectl cluster-info

# Verify namespace exists
kubectl get namespace llm-config

# Check node readiness
kubectl get nodes
```

#### Step 2: Start Database StatefulSets

```bash
# Start PostgreSQL
kubectl scale statefulset postgres -n llm-config --replicas=1

# Wait for pod to be ready
kubectl wait --for=condition=ready pod/postgres-0 -n llm-config --timeout=120s

# Start Redis
kubectl scale statefulset redis -n llm-config --replicas=3

# Wait for Redis cluster
kubectl wait --for=condition=ready pod -l app=redis -n llm-config --timeout=120s
```

#### Step 3: Start Application Deployment

```bash
# Scale up application
kubectl scale deployment llm-config-manager -n llm-config --replicas=3

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod -l app=llm-config-manager \
  -n llm-config --timeout=180s

# Check pod status
kubectl get pods -n llm-config
```

**Expected Output**:
```
NAME                                  READY   STATUS    RESTARTS   AGE
llm-config-manager-6d4b8f9c7d-abc12   1/1     Running   0          2m
llm-config-manager-6d4b8f9c7d-def34   1/1     Running   0          2m
llm-config-manager-6d4b8f9c7d-ghi56   1/1     Running   0          2m
```

### Systemd Startup

#### Step 1: Start Dependencies (if local)

```bash
# Start PostgreSQL (if installed locally)
sudo systemctl start postgresql

# Wait for PostgreSQL
sleep 5
sudo systemctl status postgresql

# Start Redis (if installed locally)
sudo systemctl start redis

# Wait for Redis
sleep 3
sudo systemctl status redis
```

#### Step 2: Start Application

```bash
# Start LLM Config Manager
sudo systemctl start llm-config-manager

# Wait for startup (10 seconds)
sleep 10

# Check status
sudo systemctl status llm-config-manager
```

**Expected Output**:
```
● llm-config-manager.service - LLM Config Manager
   Loaded: loaded (/etc/systemd/system/llm-config-manager.service; enabled)
   Active: active (running) since ...
   Main PID: 12345 (llm-config-serv)
   Status: "Server ready"
```

#### Step 3: Enable Automatic Startup

```bash
# Enable service to start on boot
sudo systemctl enable llm-config-manager

# Verify enabled
sudo systemctl is-enabled llm-config-manager
```

**Expected Output**: `enabled`

## Post-Startup Verification

After starting services, perform these verification steps:

### Health Check

```bash
# Basic health check
curl -f http://localhost:8080/health

# Detailed health status
curl http://localhost:8080/health | jq '.'
```

**Expected Response**:
```json
{
  "status": "healthy",
  "checks": {
    "storage": {
      "component": "storage",
      "status": "healthy",
      "last_check": "2025-11-21T10:30:00Z",
      "duration_ms": 5
    },
    "cache": {
      "component": "cache",
      "status": "healthy",
      "last_check": "2025-11-21T10:30:00Z",
      "duration_ms": 2
    }
  },
  "timestamp": "2025-11-21T10:30:00Z",
  "uptime_seconds": 120
}
```

### API Functionality Test

```bash
# Test GET request
curl http://localhost:8080/api/v1/configs/test/example?env=production

# Test POST request
curl -X POST http://localhost:8080/api/v1/configs/test/startup_test \
  -H "Content-Type: application/json" \
  -d '{
    "value": "test_value",
    "env": "production",
    "user": "ops"
  }'

# Verify it was created
curl http://localhost:8080/api/v1/configs/test/startup_test?env=production

# Clean up test
curl -X DELETE http://localhost:8080/api/v1/configs/test/startup_test?env=production
```

### Metrics Verification

```bash
# Check metrics endpoint
curl http://localhost:9090/metrics | grep -E "config_operations_total|http_requests_total"

# Verify Prometheus is scraping (if using monitoring stack)
curl http://localhost:9091/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="llm-config-manager")'
```

### Log Verification

```bash
# Docker
docker-compose logs --tail=100 llm-config-manager | grep -i error

# Kubernetes
kubectl logs -l app=llm-config-manager -n llm-config --tail=100 | grep -i error

# Systemd
sudo journalctl -u llm-config-manager -n 100 --no-pager | grep -i error
```

**Expected**: No ERROR level logs during normal startup

### Connection Pool Status

```bash
# Check database connections (if PostgreSQL)
docker-compose exec postgres psql -U llm_config_user -d llm_config \
  -c "SELECT count(*) FROM pg_stat_activity WHERE datname='llm_config';"

# Check Redis connections
docker-compose exec redis redis-cli CLIENT LIST | wc -l
```

## Shutdown Procedures

### Pre-Shutdown Checklist

Before shutting down:

1. Notify users of planned maintenance
2. Drain load balancer traffic
3. Complete in-flight requests
4. Backup current state (optional but recommended)

### Graceful Shutdown - Docker Compose

#### Step 1: Stop Accepting New Requests

```bash
# For load-balanced deployments, remove from load balancer first
# (This step is environment-specific)

# Wait for in-flight requests to complete (30 seconds)
sleep 30
```

#### Step 2: Stop Application

```bash
# Stop application gracefully (allows 10s for cleanup)
docker-compose stop -t 10 llm-config-manager

# Verify stopped
docker-compose ps llm-config-manager
```

**Expected Output**: Status should be "Exited (0)"

#### Step 3: Stop Monitoring (Optional)

```bash
# Stop monitoring stack
docker-compose stop prometheus grafana alertmanager
```

#### Step 4: Stop Databases (Optional)

```bash
# Only stop if doing full shutdown
# WARNING: This will cause downtime

# Stop Redis
docker-compose stop redis

# Stop PostgreSQL (ensure all connections closed)
docker-compose stop postgres
```

### Graceful Shutdown - Kubernetes

#### Step 1: Cordon Nodes (Optional)

```bash
# Prevent new pods from being scheduled
kubectl cordon <node-name>
```

#### Step 2: Scale Down Application

```bash
# Gradually scale down
kubectl scale deployment llm-config-manager -n llm-config --replicas=2
sleep 30
kubectl scale deployment llm-config-manager -n llm-config --replicas=1
sleep 30
kubectl scale deployment llm-config-manager -n llm-config --replicas=0

# Verify all pods terminated
kubectl get pods -n llm-config -l app=llm-config-manager
```

#### Step 3: Scale Down Databases (Optional)

```bash
# Only for complete shutdown
kubectl scale statefulset redis -n llm-config --replicas=0
kubectl scale statefulset postgres -n llm-config --replicas=0
```

### Graceful Shutdown - Systemd

#### Step 1: Stop Application

```bash
# Stop service gracefully
sudo systemctl stop llm-config-manager

# Verify stopped
sudo systemctl status llm-config-manager
```

**Expected Output**: Status should be "inactive (dead)"

#### Step 2: Stop Dependencies (Optional)

```bash
# Only if running locally
sudo systemctl stop redis
sudo systemctl stop postgresql
```

#### Step 3: Verify Clean Shutdown

```bash
# Check for clean shutdown in logs
sudo journalctl -u llm-config-manager -n 50 --no-pager | tail -20
```

**Expected Log Messages**:
```
INFO Received shutdown signal
INFO Draining active connections
INFO Closing database connections
INFO Flushing cache
INFO Shutdown complete
```

## Emergency Shutdown

Use emergency shutdown only when:
- System is unresponsive
- Critical security incident
- Data corruption detected
- Hardware failure imminent

### Docker Compose Emergency Shutdown

```bash
# Force stop all services immediately
docker-compose kill

# Verify all stopped
docker-compose ps

# Remove containers if needed
docker-compose down
```

### Kubernetes Emergency Shutdown

```bash
# Force delete all pods
kubectl delete pods -n llm-config -l app=llm-config-manager --grace-period=0 --force

# Scale to zero
kubectl scale deployment llm-config-manager -n llm-config --replicas=0
```

### Systemd Emergency Shutdown

```bash
# Send SIGKILL to force termination
sudo systemctl kill -s SIGKILL llm-config-manager

# Stop service
sudo systemctl stop llm-config-manager

# Verify process terminated
ps aux | grep llm-config-server
```

## Restart Procedures

### Rolling Restart (Zero Downtime)

#### Kubernetes

```bash
# Restart with rolling update
kubectl rollout restart deployment llm-config-manager -n llm-config

# Watch rollout status
kubectl rollout status deployment llm-config-manager -n llm-config

# Verify all pods running
kubectl get pods -n llm-config -l app=llm-config-manager
```

#### Docker Compose

```bash
# Restart single container (for single instance)
docker-compose restart llm-config-manager

# For multi-instance (manual rolling restart)
docker-compose up -d --scale llm-config-manager=3 --no-recreate
```

#### Systemd

```bash
# Simple restart
sudo systemctl restart llm-config-manager

# Reload configuration without restart (if supported)
sudo systemctl reload llm-config-manager
```

### Configuration Reload

```bash
# Docker - restart container
docker-compose restart llm-config-manager

# Kubernetes - trigger rolling restart
kubectl rollout restart deployment llm-config-manager -n llm-config

# Systemd - reload configuration
sudo systemctl reload llm-config-manager
```

## Troubleshooting

### Service Won't Start

#### Check 1: Port Conflicts

```bash
# Check if ports are already in use
sudo netstat -tuln | grep -E ':(8080|9090)'

# Find process using port
sudo lsof -i :8080
```

**Resolution**: Stop conflicting service or change port

#### Check 2: Missing Configuration

```bash
# Docker
cat .env | grep -E "ENCRYPTION_KEY|DB_PASSWORD"

# Kubernetes
kubectl get secret llm-config-manager-secrets -n llm-config -o yaml

# Systemd
sudo cat /etc/default/llm-config-manager | grep -E "LLM_CONFIG_ENCRYPTION_KEY"
```

**Resolution**: Generate missing secrets, update configuration

#### Check 3: Database Not Ready

```bash
# Check PostgreSQL
docker-compose exec postgres pg_isready
# or
sudo systemctl status postgresql

# Check Redis
docker-compose exec redis redis-cli ping
# or
sudo systemctl status redis
```

**Resolution**: Wait for databases to start, check logs

#### Check 4: Permission Issues

```bash
# Docker - check volume permissions
docker-compose exec llm-config-manager ls -la /var/lib/llm-config/data

# Systemd - check file permissions
sudo ls -la /var/lib/llm-config/data
sudo ls -la /etc/llm-config/
```

**Resolution**: Fix permissions
```bash
# Docker
docker-compose exec llm-config-manager chown -R llmconfig:llmconfig /var/lib/llm-config

# Systemd
sudo chown -R llmconfig:llmconfig /var/lib/llm-config
sudo chown root:root /etc/llm-config/config.yaml
sudo chmod 600 /etc/default/llm-config-manager
```

### Service Shuts Down Immediately

#### Check Logs

```bash
# Docker
docker-compose logs --tail=100 llm-config-manager

# Kubernetes
kubectl logs -l app=llm-config-manager -n llm-config --tail=100

# Systemd
sudo journalctl -u llm-config-manager -n 100 --no-pager
```

**Look for**:
- Configuration errors
- Missing encryption key
- Database connection failures
- Port binding failures

#### Check Configuration Syntax

```bash
# Validate YAML syntax (if applicable)
python3 -c "import yaml; yaml.safe_load(open('/etc/llm-config/config.yaml'))"

# Check environment variables
env | grep LLM_CONFIG
```

### Slow Startup

#### Check 1: Database Connection

```bash
# Test database connectivity
time docker-compose exec postgres pg_isready

# Check connection pool
curl http://localhost:8080/health | jq '.checks.database'
```

#### Check 2: Cache Connection

```bash
# Test Redis connectivity
time docker-compose exec redis redis-cli ping

# Check cache health
curl http://localhost:8080/health | jq '.checks.cache'
```

#### Check 3: Resource Constraints

```bash
# Check CPU/Memory
docker stats llm-config-manager --no-stream
# or
top -p $(pgrep llm-config-server)
```

**Resolution**: Increase resource limits in deployment configuration

## Success Criteria

Service startup is successful when:

- [ ] Health endpoint returns HTTP 200 with status "healthy"
- [ ] All dependency services are running
- [ ] No ERROR logs in last 5 minutes
- [ ] API responds to test requests
- [ ] Metrics endpoint is accessible
- [ ] Cache connections established
- [ ] Database connections established
- [ ] Uptime counter is incrementing

## Rollback Procedure

If startup fails:

1. **Stop new service**: Follow shutdown procedures
2. **Restore previous version**:
   ```bash
   # Docker
   docker-compose down
   docker-compose up -d

   # Kubernetes
   kubectl rollout undo deployment llm-config-manager -n llm-config

   # Systemd
   sudo systemctl stop llm-config-manager
   sudo cp /usr/local/bin/llm-config-server.backup /usr/local/bin/llm-config-server
   sudo systemctl start llm-config-manager
   ```
3. **Verify rollback**: Follow post-startup verification
4. **Investigate failure**: Review logs and metrics

## Contact Information

**On-Call Team**: ops-oncall@example.com
**Escalation**: sre-team@example.com
**Emergency**: +1-555-0100

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-21
**Next Review**: 2026-02-21
**Owner**: Operations Team
