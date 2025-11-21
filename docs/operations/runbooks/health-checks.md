# Health Check Procedures

**Version**: 1.0.0
**Last Updated**: 2025-11-21
**Purpose**: Comprehensive procedures for monitoring and verifying system health

## Table of Contents

1. [Overview](#overview)
2. [Health Check Endpoints](#health-check-endpoints)
3. [Component Health Checks](#component-health-checks)
4. [Automated Health Monitoring](#automated-health-monitoring)
5. [Manual Health Verification](#manual-health-verification)
6. [Health Check Scripts](#health-check-scripts)
7. [Troubleshooting Unhealthy States](#troubleshooting-unhealthy-states)

## Overview

This runbook provides procedures for checking the health of LLM Config Manager and its components. Use these procedures for:

- Regular health verification
- Post-deployment validation
- Incident investigation
- Performance monitoring
- Capacity planning

### Health Status Levels

| Status | Description | Action Required |
|--------|-------------|-----------------|
| `healthy` | All systems operational | None |
| `degraded` | Some non-critical issues | Monitor, plan maintenance |
| `unhealthy` | Critical components down | Immediate action required |

## Health Check Endpoints

### Primary Health Endpoint

**Endpoint**: `GET /health`
**Port**: 8080 (default)
**Purpose**: Overall system health status

#### Request

```bash
curl -i http://localhost:8080/health
```

#### Healthy Response (HTTP 200)

```json
{
  "status": "healthy",
  "checks": {
    "storage": {
      "component": "storage",
      "status": "healthy",
      "message": null,
      "last_check": "2025-11-21T10:30:00Z",
      "duration_ms": 5
    },
    "cache": {
      "component": "cache",
      "status": "healthy",
      "message": null,
      "last_check": "2025-11-21T10:30:00Z",
      "duration_ms": 2
    },
    "database": {
      "component": "database",
      "status": "healthy",
      "message": null,
      "last_check": "2025-11-21T10:30:00Z",
      "duration_ms": 10
    }
  },
  "timestamp": "2025-11-21T10:30:00Z",
  "uptime_seconds": 86400
}
```

#### Degraded Response (HTTP 200)

```json
{
  "status": "degraded",
  "checks": {
    "storage": {
      "component": "storage",
      "status": "healthy",
      "message": null,
      "last_check": "2025-11-21T10:30:00Z",
      "duration_ms": 5
    },
    "cache": {
      "component": "cache",
      "status": "degraded",
      "message": "Redis connection slow (>100ms latency)",
      "last_check": "2025-11-21T10:30:00Z",
      "duration_ms": 150
    }
  },
  "timestamp": "2025-11-21T10:30:00Z",
  "uptime_seconds": 86400
}
```

#### Unhealthy Response (HTTP 503)

```json
{
  "status": "unhealthy",
  "checks": {
    "storage": {
      "component": "storage",
      "status": "unhealthy",
      "message": "Cannot connect to storage backend",
      "last_check": "2025-11-21T10:30:00Z",
      "duration_ms": 5000
    }
  },
  "timestamp": "2025-11-21T10:30:00Z",
  "uptime_seconds": 86400
}
```

### Readiness Endpoint

**Endpoint**: `GET /health/ready`
**Purpose**: Check if service can accept traffic

```bash
curl -i http://localhost:8080/health/ready
```

**Response**: HTTP 200 if ready, HTTP 503 if not ready

**Use Case**: Kubernetes readiness probe, load balancer health check

### Liveness Endpoint

**Endpoint**: `GET /health/live`
**Purpose**: Check if service is running (not deadlocked)

```bash
curl -i http://localhost:8080/health/live
```

**Response**: HTTP 200 if alive, HTTP 503 if deadlocked

**Use Case**: Kubernetes liveness probe, automatic restart trigger

## Component Health Checks

### Storage Health

#### Quick Check

```bash
# Via API health endpoint
curl http://localhost:8080/health | jq '.checks.storage'
```

#### Direct Check - Docker

```bash
# File-based storage
docker-compose exec llm-config-manager ls -lh /var/lib/llm-config/data/

# PostgreSQL
docker-compose exec postgres pg_isready -U llm_config_user
docker-compose exec postgres psql -U llm_config_user -d llm_config -c "SELECT version();"

# Test read/write
docker-compose exec postgres psql -U llm_config_user -d llm_config -c "
  CREATE TABLE health_check (id serial, test_time timestamp);
  INSERT INTO health_check (test_time) VALUES (NOW());
  SELECT * FROM health_check;
  DROP TABLE health_check;
"
```

#### Direct Check - Kubernetes

```bash
# Check storage PVC
kubectl get pvc -n llm-config

# Check PostgreSQL pod
kubectl exec -n llm-config postgres-0 -- pg_isready

# Test database connection
kubectl exec -n llm-config postgres-0 -- \
  psql -U llm_config_user -d llm_config -c "SELECT 1;"
```

#### Direct Check - Systemd

```bash
# File-based storage
sudo ls -lh /var/lib/llm-config/data/
sudo du -sh /var/lib/llm-config/data/

# PostgreSQL
sudo -u postgres pg_isready
sudo -u llmconfig psql -h localhost -U llm_config_user -d llm_config -c "SELECT version();"
```

#### Storage Health Indicators

**Healthy**:
- Response time: <50ms
- Connection successful
- Read/write operations work
- Disk space: >10GB free
- No error logs

**Degraded**:
- Response time: 50-200ms
- Occasional connection timeouts
- Disk space: 5-10GB free
- Warning logs present

**Unhealthy**:
- Response time: >200ms or timeout
- Cannot establish connection
- Disk space: <5GB free
- Error logs present

### Cache Health

#### Quick Check

```bash
# Via API
curl http://localhost:8080/health | jq '.checks.cache'
```

#### Direct Check - Docker

```bash
# Redis ping test
docker-compose exec redis redis-cli ping

# Check Redis info
docker-compose exec redis redis-cli INFO | grep -E "connected_clients|used_memory_human|instantaneous_ops_per_sec"

# Check cache keys
docker-compose exec redis redis-cli DBSIZE

# Test set/get
docker-compose exec redis redis-cli SET health_check_key "test_value"
docker-compose exec redis redis-cli GET health_check_key
docker-compose exec redis redis-cli DEL health_check_key
```

#### Direct Check - Kubernetes

```bash
# Check Redis pods
kubectl get pods -n llm-config -l app=redis

# Test Redis connection
kubectl exec -n llm-config redis-0 -- redis-cli ping

# Check Redis cluster status (if clustered)
kubectl exec -n llm-config redis-0 -- redis-cli CLUSTER INFO
```

#### Direct Check - Systemd

```bash
# Check Redis service
sudo systemctl status redis

# Test connection
redis-cli -h localhost -p 6379 ping

# Check memory usage
redis-cli INFO memory | grep used_memory_human
```

#### Cache Health Indicators

**Healthy**:
- Response time: <5ms
- PING returns PONG
- Memory usage: <80%
- No connection errors
- Cache hit rate: >70%

**Degraded**:
- Response time: 5-20ms
- Memory usage: 80-90%
- Cache hit rate: 50-70%
- Occasional connection timeouts

**Unhealthy**:
- Response time: >20ms or timeout
- Cannot connect
- Memory usage: >90%
- Cache hit rate: <50%
- Frequent evictions

### API Health

#### Endpoint Availability

```bash
# Test all critical endpoints
endpoints=(
  "/health"
  "/api/v1/configs/test/key?env=production"
  "/metrics"
)

for endpoint in "${endpoints[@]}"; do
  echo "Testing $endpoint"
  curl -i -s "http://localhost:8080$endpoint" | head -n 1
done
```

#### Response Time Test

```bash
# Measure response times
curl -w "\nTime: %{time_total}s\n" -o /dev/null -s http://localhost:8080/health
curl -w "\nTime: %{time_total}s\n" -o /dev/null -s http://localhost:8080/api/v1/configs/test/key?env=production
```

#### Load Test (Light)

```bash
# Install apache bench if needed: apt-get install apache2-utils

# Light load test: 100 requests, 10 concurrent
ab -n 100 -c 10 http://localhost:8080/health

# Expected: 0% failed, <100ms average response time
```

#### API Health Indicators

**Healthy**:
- All endpoints return expected status codes
- Response time: <100ms (P95)
- Error rate: <1%
- Success rate: >99%

**Degraded**:
- Response time: 100-500ms (P95)
- Error rate: 1-5%
- Some endpoints slow

**Unhealthy**:
- Response time: >500ms (P95)
- Error rate: >5%
- Endpoints returning 5xx errors
- Timeouts occurring

### Network Health

#### Port Connectivity

```bash
# Check if ports are listening
netstat -tuln | grep -E ':(8080|9090|5432|6379)'

# Test external access (from another machine)
nc -zv <hostname> 8080
nc -zv <hostname> 9090
```

#### DNS Resolution

```bash
# Test DNS (Kubernetes)
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup llm-config-manager.llm-config.svc.cluster.local

# Test DNS (Docker)
docker-compose exec llm-config-manager nslookup postgres

# Test external DNS
nslookup example.com
```

#### Network Latency

```bash
# Ping tests
ping -c 5 localhost
ping -c 5 <database-host>
ping -c 5 <redis-host>

# TCP connection time
time telnet localhost 8080 <<< "GET /health HTTP/1.0"
```

## Automated Health Monitoring

### Kubernetes Probes Configuration

```yaml
# Liveness probe - restart if fails
livenessProbe:
  httpGet:
    path: /health/live
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

# Readiness probe - remove from service if fails
readinessProbe:
  httpGet:
    path: /health/ready
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 2
```

### Docker Health Check

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/usr/local/bin/llm-config-server", "health-check"]
```

### Systemd Health Check Timer

The system includes an automated health check timer that runs every 5 minutes:

```bash
# Check timer status
systemctl status llm-config-healthcheck.timer

# View recent health check results
sudo journalctl -u llm-config-healthcheck.service -n 20

# Manually trigger health check
sudo systemctl start llm-config-healthcheck.service
```

### Prometheus Health Monitoring

```yaml
# Alert on service down
- alert: ServiceDown
  expr: up{job="llm-config-manager"} == 0
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "LLM Config Manager is down"

# Alert on health check failures
- alert: HealthCheckFailing
  expr: health_check_status{component="storage"} != 1
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Storage health check failing"
```

## Manual Health Verification

### Complete Health Check Procedure

Use this procedure for thorough system verification:

#### Step 1: Overall Health

```bash
# Check overall status
curl http://localhost:8080/health | jq '.'

# Expected: status = "healthy"
```

#### Step 2: Component Health

```bash
# Check each component
curl http://localhost:8080/health | jq '.checks | to_entries[] | {component: .key, status: .value.status, duration: .value.duration_ms}'

# Expected: All components "healthy", duration <100ms
```

#### Step 3: Service Availability

```bash
# Test API endpoints
curl -I http://localhost:8080/api/v1/configs/test/key?env=production
curl -I http://localhost:9090/metrics
curl -I http://localhost:8080/health

# Expected: All return HTTP 200
```

#### Step 4: Metrics Verification

```bash
# Check key metrics
curl -s http://localhost:9090/metrics | grep -E "config_operations_total|http_requests_total|cache_hits_total"

# Expected: Counters are incrementing
```

#### Step 5: Resource Usage

```bash
# Docker
docker stats llm-config-manager --no-stream

# Kubernetes
kubectl top pod -n llm-config -l app=llm-config-manager

# Systemd
ps aux | grep llm-config-server
free -h
df -h /var/lib/llm-config
```

**Expected**:
- CPU: <80%
- Memory: <80% of limit
- Disk: >10GB free

#### Step 6: Log Health

```bash
# Check for errors in last 5 minutes
# Docker
docker-compose logs --since 5m llm-config-manager | grep -i error

# Kubernetes
kubectl logs -l app=llm-config-manager -n llm-config --since=5m | grep -i error

# Systemd
sudo journalctl -u llm-config-manager --since "5 minutes ago" | grep -i error

# Expected: No ERROR level logs (WARN acceptable)
```

## Health Check Scripts

### Basic Health Check Script

Save as `/usr/local/bin/health-check.sh`:

```bash
#!/bin/bash
# Basic health check script for LLM Config Manager

set -e

HEALTH_URL="${HEALTH_URL:-http://localhost:8080/health}"
TIMEOUT="${TIMEOUT:-5}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "LLM Config Manager Health Check"
echo "================================"
echo ""

# Check if service is responding
if ! curl -f -s --max-time "$TIMEOUT" "$HEALTH_URL" > /tmp/health_check.json 2>&1; then
    echo -e "${RED}FAIL${NC}: Service not responding"
    exit 1
fi

# Parse health status
STATUS=$(jq -r '.status' /tmp/health_check.json)
UPTIME=$(jq -r '.uptime_seconds' /tmp/health_check.json)

echo "Status: $STATUS"
echo "Uptime: $UPTIME seconds"
echo ""

# Check component health
echo "Component Health:"
jq -r '.checks | to_entries[] | "\(.key): \(.value.status) (\(.value.duration_ms)ms)"' /tmp/health_check.json

# Determine exit code based on status
case "$STATUS" in
    "healthy")
        echo -e "\n${GREEN}PASS${NC}: All systems healthy"
        exit 0
        ;;
    "degraded")
        echo -e "\n${YELLOW}WARN${NC}: System degraded"
        exit 0
        ;;
    "unhealthy")
        echo -e "\n${RED}FAIL${NC}: System unhealthy"
        exit 1
        ;;
    *)
        echo -e "\n${RED}UNKNOWN${NC}: Unknown status"
        exit 2
        ;;
esac
```

Make executable:
```bash
chmod +x /usr/local/bin/health-check.sh
```

Usage:
```bash
# Run health check
/usr/local/bin/health-check.sh

# With custom URL
HEALTH_URL=http://api.example.com/health /usr/local/bin/health-check.sh
```

### Comprehensive Health Check Script

Save as `/usr/local/bin/comprehensive-health-check.sh`:

```bash
#!/bin/bash
# Comprehensive health check for LLM Config Manager

set -e

API_URL="${API_URL:-http://localhost:8080}"
METRICS_URL="${METRICS_URL:-http://localhost:9090}"

echo "Comprehensive Health Check"
echo "=========================="
echo ""

# 1. API Health
echo "1. Checking API health..."
if curl -f -s --max-time 5 "$API_URL/health" > /dev/null; then
    echo "   ✓ API responding"
else
    echo "   ✗ API not responding"
    exit 1
fi

# 2. Component Health
echo "2. Checking component health..."
COMPONENTS=$(curl -s "$API_URL/health" | jq -r '.checks | keys[]')
for component in $COMPONENTS; do
    STATUS=$(curl -s "$API_URL/health" | jq -r ".checks.$component.status")
    if [ "$STATUS" = "healthy" ]; then
        echo "   ✓ $component: healthy"
    else
        echo "   ⚠ $component: $STATUS"
    fi
done

# 3. Metrics Endpoint
echo "3. Checking metrics endpoint..."
if curl -f -s --max-time 5 "$METRICS_URL/metrics" > /dev/null; then
    echo "   ✓ Metrics available"
else
    echo "   ✗ Metrics not available"
fi

# 4. API Functionality
echo "4. Checking API functionality..."
if curl -f -s --max-time 5 "$API_URL/api/v1/configs/test/key?env=production" > /dev/null 2>&1; then
    echo "   ✓ API endpoints accessible"
else
    echo "   ⚠ API endpoints may be unavailable (404 is normal if key doesn't exist)"
fi

# 5. Response Time
echo "5. Checking response times..."
RESPONSE_TIME=$(curl -w "%{time_total}" -o /dev/null -s "$API_URL/health")
RESPONSE_MS=$(echo "$RESPONSE_TIME * 1000" | bc)
if (( $(echo "$RESPONSE_TIME < 0.1" | bc -l) )); then
    echo "   ✓ Response time: ${RESPONSE_MS}ms (excellent)"
elif (( $(echo "$RESPONSE_TIME < 0.5" | bc -l) )); then
    echo "   ✓ Response time: ${RESPONSE_MS}ms (good)"
else
    echo "   ⚠ Response time: ${RESPONSE_MS}ms (slow)"
fi

echo ""
echo "Health check complete"
```

Make executable:
```bash
chmod +x /usr/local/bin/comprehensive-health-check.sh
```

## Troubleshooting Unhealthy States

### Storage Unhealthy

**Symptoms**:
- Health endpoint shows storage unhealthy
- Long response times
- Database connection errors

**Diagnosis**:
```bash
# Check storage connectivity
docker-compose exec postgres pg_isready
# or
kubectl exec -n llm-config postgres-0 -- pg_isready

# Check disk space
df -h /var/lib/llm-config

# Check storage logs
docker-compose logs postgres | tail -50
```

**Resolution**:
1. If disk full: Clear space or expand volume
2. If database down: Restart database service
3. If connection issue: Check network connectivity
4. If corruption: Restore from backup

### Cache Unhealthy

**Symptoms**:
- Cache showing degraded/unhealthy
- Slow response times
- High cache miss rate

**Diagnosis**:
```bash
# Check Redis status
docker-compose exec redis redis-cli INFO

# Check memory usage
docker-compose exec redis redis-cli INFO memory

# Check connections
docker-compose exec redis redis-cli CLIENT LIST
```

**Resolution**:
1. If high memory: Increase Redis memory limit or clear cache
2. If connection issues: Check Redis service status
3. If slow: Check Redis performance metrics
4. If unavailable: System can operate without cache (degraded mode)

### API Unhealthy

**Symptoms**:
- Health endpoint not responding
- 5xx errors
- Timeouts

**Diagnosis**:
```bash
# Check service status
docker-compose ps llm-config-manager
# or
kubectl get pods -n llm-config

# Check logs
docker-compose logs --tail=100 llm-config-manager

# Check resource usage
docker stats llm-config-manager
```

**Resolution**:
1. If high CPU/memory: Increase resources or scale horizontally
2. If crashed: Check logs, restart service
3. If deadlocked: Restart service
4. If configuration error: Fix configuration and restart

### Network Unhealthy

**Symptoms**:
- Cannot reach endpoints
- Connection timeouts
- DNS resolution failures

**Diagnosis**:
```bash
# Check port availability
netstat -tuln | grep 8080

# Check DNS
nslookup localhost
nslookup <service-hostname>

# Check network connectivity
ping localhost
curl -I http://localhost:8080/health
```

**Resolution**:
1. If port blocked: Check firewall rules
2. If DNS issues: Check DNS configuration
3. If network partition: Check network infrastructure
4. If load balancer issue: Check load balancer health

## Health Check Best Practices

1. **Regular Monitoring**: Check health at least every 5 minutes
2. **Alert on Failures**: Set up alerts for degraded/unhealthy states
3. **Trend Analysis**: Track health metrics over time
4. **Document Baselines**: Know what "normal" looks like
5. **Test Failures**: Regularly test failure scenarios
6. **Automate Checks**: Use automated health check scripts
7. **Multiple Checks**: Don't rely on single health indicator
8. **Response Time SLA**: Define acceptable response times

## Success Criteria

System is considered healthy when:

- [ ] Overall health status: "healthy"
- [ ] All components healthy
- [ ] Response time: <100ms (P95)
- [ ] Error rate: <1%
- [ ] No ERROR logs in last 5 minutes
- [ ] Resource usage: <80%
- [ ] Uptime: >99.9%

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-21
**Next Review**: 2026-02-21
**Owner**: Operations Team
