# Common Issues and Resolutions

**Version**: 1.0.0
**Last Updated**: 2025-11-21
**Purpose**: Quick reference guide for resolving common operational issues

## Table of Contents

1. [Service Issues](#service-issues)
2. [Configuration Issues](#configuration-issues)
3. [Database Issues](#database-issues)
4. [Cache Issues](#cache-issues)
5. [Authentication/Authorization Issues](#authenticationauthorization-issues)
6. [Performance Issues](#performance-issues)
7. [Security Issues](#security-issues)
8. [Deployment Issues](#deployment-issues)

## Service Issues

### Issue: Service Won't Start

**Symptoms**:
- Container/pod crashes immediately
- Service status shows "failed"
- Process exits with error code

**Common Causes & Solutions**:

#### 1. Missing Encryption Key

**Error Message**:
```
ERROR: Encryption key not configured
ERROR: LLM_CONFIG_ENCRYPTION_KEY environment variable not set
```

**Solution**:
```bash
# Generate key
export NEW_KEY=$(openssl rand -base64 32)

# Docker
echo "ENCRYPTION_KEY=$NEW_KEY" >> .env
docker-compose restart llm-config-manager

# Kubernetes
kubectl create secret generic llm-config-manager-secrets \
  --from-literal=ENCRYPTION_KEY="$NEW_KEY" \
  -n llm-config --dry-run=client -o yaml | kubectl apply -f -

# Systemd
sudo bash -c "echo 'LLM_CONFIG_ENCRYPTION_KEY=$NEW_KEY' >> /etc/default/llm-config-manager"
sudo systemctl restart llm-config-manager
```

#### 2. Port Already in Use

**Error Message**:
```
ERROR: Address already in use (os error 98)
ERROR: Cannot bind to 0.0.0.0:8080
```

**Solution**:
```bash
# Find process using port
sudo lsof -i :8080
sudo netstat -tulpn | grep :8080

# Kill conflicting process
sudo kill <PID>

# Or change port
# Docker: Edit docker-compose.yml
ports:
  - "8081:8080"  # Use different host port

# Systemd: Edit /etc/llm-config/config.yaml
server:
  port: 8081
```

#### 3. Permission Denied

**Error Message**:
```
ERROR: Permission denied (os error 13)
ERROR: Cannot write to /var/lib/llm-config/data
```

**Solution**:
```bash
# Docker
docker-compose exec llm-config-manager chown -R llmconfig:llmconfig /var/lib/llm-config
docker-compose restart llm-config-manager

# Systemd
sudo chown -R llmconfig:llmconfig /var/lib/llm-config
sudo chmod 755 /var/lib/llm-config/data
sudo systemctl restart llm-config-manager

# Kubernetes
kubectl exec -n llm-config <pod-name> -- chown -R llmconfig:llmconfig /var/lib/llm-config
kubectl delete pod -n llm-config <pod-name>  # Restart pod
```

#### 4. Configuration File Not Found

**Error Message**:
```
ERROR: Configuration file not found: /etc/llm-config/config.yaml
ERROR: No such file or directory
```

**Solution**:
```bash
# Docker
cp config/production.yaml docker-compose.yml
docker-compose up -d

# Kubernetes
kubectl create configmap llm-config-manager-config \
  --from-file=config.yaml=config/production.yaml \
  -n llm-config

# Systemd
sudo cp config/production.yaml /etc/llm-config/config.yaml
sudo chown root:root /etc/llm-config/config.yaml
sudo chmod 644 /etc/llm-config/config.yaml
```

### Issue: Service Crashes Repeatedly

**Symptoms**:
- Service restarts every few seconds
- CrashLoopBackOff (Kubernetes)
- High restart count

**Common Causes & Solutions**:

#### 1. Out of Memory

**Diagnosis**:
```bash
# Docker
docker inspect llm-config-manager | grep OOMKilled

# Kubernetes
kubectl describe pod -n llm-config <pod-name> | grep -A 5 "Last State"

# Systemd
sudo journalctl -u llm-config-manager | grep -i "out of memory"
```

**Solution**:
```bash
# Increase memory limits
# Docker
services:
  llm-config-manager:
    deploy:
      resources:
        limits:
          memory: 4G

# Kubernetes
resources:
  limits:
    memory: 4Gi

# Systemd
sudo systemctl edit llm-config-manager
[Service]
MemoryMax=4G
```

#### 2. Database Connection Failure

**Error Message**:
```
ERROR: Failed to connect to database
ERROR: Connection refused: postgres:5432
```

**Solution**:
```bash
# Check database is running
docker-compose ps postgres
kubectl get pod -n llm-config postgres-0
sudo systemctl status postgresql

# Start database if needed
docker-compose up -d postgres
kubectl scale statefulset postgres -n llm-config --replicas=1
sudo systemctl start postgresql

# Verify connection
docker-compose exec postgres pg_isready -U llm_config_user

# Check credentials
docker-compose exec postgres psql -U llm_config_user -d llm_config -c "SELECT 1;"
```

## Configuration Issues

### Issue: Configuration Not Found

**Symptoms**:
- API returns 404 for existing configs
- Configs disappear after restart
- Empty list responses

**Common Causes & Solutions**:

#### 1. Wrong Environment

**Solution**:
```bash
# Check which environment is being queried
curl http://localhost:8080/api/v1/configs/app/mykey?env=production

# List configs in all environments
for env in development staging production; do
  echo "Environment: $env"
  curl -s "http://localhost:8080/api/v1/configs/app?env=$env" | jq '.'
done
```

#### 2. Wrong Namespace

**Solution**:
```bash
# List all namespaces
curl http://localhost:8080/api/v1/namespaces

# Search across namespaces
for ns in $(curl -s http://localhost:8080/api/v1/namespaces | jq -r '.[]'); do
  echo "Namespace: $ns"
  curl -s "http://localhost:8080/api/v1/configs/$ns?env=production" | jq '.[] | .key'
done
```

### Issue: Configuration Not Updating

**Symptoms**:
- SET requests succeed but values don't change
- Old values returned after update
- Changes lost after restart

**Common Causes & Solutions**:

#### 1. Cache Not Invalidating

**Solution**:
```bash
# Check cache status
curl http://localhost:8080/health | jq '.checks.cache'

# Clear cache
docker-compose exec redis redis-cli FLUSHALL

# Restart service to rebuild cache
docker-compose restart llm-config-manager

# Verify update
curl -X POST http://localhost:8080/api/v1/configs/app/test \
  -H "Content-Type: application/json" \
  -d '{"value": "new_value", "env": "production", "user": "ops"}'

sleep 2
curl http://localhost:8080/api/v1/configs/app/test?env=production
```

#### 2. Permission Denied

**Error Message**:
```
ERROR: Insufficient permissions
ERROR: User 'viewer' cannot modify configuration
```

**Solution**:
```bash
# Check user permissions
curl http://localhost:8080/api/v1/users/viewer/permissions

# Use admin user
curl -X POST http://localhost:8080/api/v1/configs/app/test \
  -H "Content-Type: application/json" \
  -H "X-User: admin" \
  -d '{"value": "new_value", "env": "production", "user": "admin"}'
```

#### 3. Storage Full

**Error Message**:
```
ERROR: No space left on device
ERROR: Failed to write to storage
```

**Solution**:
```bash
# Check disk space
df -h /var/lib/llm-config

# Clean up space
# Remove old backups
find /var/lib/llm-config/backups -mtime +90 -delete

# Remove old logs
find /var/log/llm-config -name "*.log" -mtime +30 -delete

# Vacuum database
docker-compose exec postgres psql -U llm_config_user -d llm_config -c "VACUUM FULL;"

# Expand volume if needed
```

## Database Issues

### Issue: Database Connection Pool Exhausted

**Symptoms**:
- Errors: "connection pool exhausted"
- Timeouts on database operations
- Slow response times

**Solution**:
```bash
# 1. Check current connections
docker-compose exec postgres psql -U llm_config_user -d llm_config -c "
SELECT count(*) FROM pg_stat_activity WHERE datname='llm_config';
"

# 2. Kill idle connections
docker-compose exec postgres psql -U llm_config_user -d llm_config -c "
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'llm_config'
  AND state = 'idle'
  AND state_change < current_timestamp - INTERVAL '10 minutes';
"

# 3. Increase pool size
# Edit configuration
DATABASE_POOL_SIZE=100
DATABASE_MAX_CONNECTIONS=200

# Restart service
docker-compose restart llm-config-manager
```

### Issue: Database Locks

**Symptoms**:
- Operations hang/timeout
- High wait times
- Deadlock errors

**Solution**:
```bash
# 1. Check for locks
docker-compose exec postgres psql -U llm_config_user -d llm_config -c "
SELECT pid, usename, pg_blocking_pids(pid), query
FROM pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0;
"

# 2. Kill blocking queries
docker-compose exec postgres psql -U llm_config_user -d llm_config -c "
SELECT pg_terminate_backend(<pid>);
"

# 3. Optimize queries to reduce lock time
docker-compose exec postgres psql -U llm_config_user -d llm_config -c "
VACUUM ANALYZE;
"
```

## Cache Issues

### Issue: Low Cache Hit Rate

**Symptoms**:
- Cache hit rate <70%
- High storage load
- Slow response times

**Solution**:
```bash
# 1. Check cache configuration
curl http://localhost:8080/health | jq '.checks.cache'

# 2. Check cache hit rate
curl -s http://localhost:9090/metrics | awk '
/cache_hits_total/ {hits+=$2}
/cache_misses_total/ {misses+=$2}
END {
    if(hits+misses>0) print "Hit Rate:", (hits/(hits+misses))*100"%"
}'

# 3. Increase cache size
# Docker
services:
  llm-config-manager:
    environment:
      - CACHE_L1_SIZE=50000
      - CACHE_L1_TTL_SECONDS=7200

# 4. Increase Redis memory
redis:
  command: redis-server --maxmemory 2gb

# 5. Restart and monitor
docker-compose restart llm-config-manager redis
watch -n 5 'curl -s http://localhost:9090/metrics | grep cache_hits_total'
```

### Issue: Redis Connection Failed

**Symptoms**:
- Cache status: unhealthy/degraded
- "Connection refused" errors
- Fallback to storage

**Solution**:
```bash
# 1. Check Redis status
docker-compose ps redis
docker-compose exec redis redis-cli ping

# 2. Restart Redis
docker-compose restart redis

# 3. Check connectivity
docker-compose exec llm-config-manager nc -zv redis 6379

# 4. Check Redis logs
docker-compose logs redis | tail -50

# 5. Verify configuration
docker-compose exec redis redis-cli CONFIG GET maxmemory
docker-compose exec redis redis-cli INFO memory

# Note: System can operate without Redis (degraded mode)
```

## Authentication/Authorization Issues

### Issue: Access Denied

**Error Message**:
```
ERROR: 403 Forbidden
ERROR: Insufficient permissions
ERROR: User not authorized
```

**Solution**:
```bash
# 1. Check user permissions
curl http://localhost:8080/api/v1/users/<username>/permissions

# 2. Check RBAC configuration
curl http://localhost:8080/api/v1/roles

# 3. Grant permissions
curl -X POST http://localhost:8080/api/v1/users/<username>/roles \
  -H "Content-Type: application/json" \
  -d '{"role": "editor"}'

# 4. Use admin user temporarily
curl -H "X-User: admin" http://localhost:8080/api/v1/configs/app/key?env=production

# 5. Check audit log for permission denials
curl http://localhost:8080/api/v1/audit?event_type=permission_denied
```

### Issue: Rate Limited

**Error Message**:
```
ERROR: 429 Too Many Requests
ERROR: Rate limit exceeded
ERROR: IP banned
```

**Solution**:
```bash
# 1. Check if IP is banned
curl http://localhost:8080/api/v1/security/banned-ips

# 2. Unban IP
curl -X DELETE http://localhost:8080/api/v1/security/banned-ips/<ip_address> \
  -H "X-Admin-Token: <admin_token>"

# 3. Check rate limit configuration
curl http://localhost:8080/api/v1/security/rate-limits

# 4. Increase rate limits temporarily
# Edit security configuration
RATE_LIMIT_RPS=200  # Increase from 100

# 5. Use authenticated requests (higher limits)
curl -H "Authorization: Bearer <token>" \
  http://localhost:8080/api/v1/configs/app/key?env=production
```

## Performance Issues

### Issue: Slow Response Times

**Symptoms**:
- Response times >100ms (P95)
- Timeouts
- High latency

**Quick Fixes**:
```bash
# 1. Check system resources
docker stats llm-config-manager --no-stream

# 2. Check cache hit rate
curl -s http://localhost:9090/metrics | grep cache_hits_total

# 3. Clear cache and restart (forces rebuild)
docker-compose exec redis redis-cli FLUSHALL
docker-compose restart llm-config-manager

# 4. Scale horizontally (Kubernetes)
kubectl scale deployment llm-config-manager -n llm-config --replicas=5

# 5. Add database indexes
docker-compose exec postgres psql -U llm_config_user -d llm_config -c "
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_configs_namespace_key
ON configs(namespace, key);
"

# See performance-troubleshooting.md for detailed diagnosis
```

### Issue: High CPU Usage

**Symptoms**:
- CPU >80%
- Slow response times
- System unresponsive

**Quick Fixes**:
```bash
# 1. Check request rate
curl -s 'http://localhost:9091/api/v1/query?query=rate(http_requests_total[5m])'

# 2. Enable rate limiting
RATE_LIMIT_RPS=100
RATE_LIMIT_BURST=50

# 3. Scale horizontally
kubectl scale deployment llm-config-manager -n llm-config --replicas=5

# 4. Add more workers
SERVER_WORKERS=16

# 5. Restart service
docker-compose restart llm-config-manager
```

## Security Issues

### Issue: Failed Security Scan

**Symptoms**:
- Security scanner reports vulnerabilities
- Dependency alerts
- Known CVEs detected

**Solution**:
```bash
# 1. Run security scanners
./security/scanners/dependency-scanner.sh
./security/scanners/code-scanner.sh

# 2. Update dependencies
cargo update

# 3. Rebuild with latest patches
cargo build --release

# 4. Verify fixes
cargo audit

# 5. Review and accept risks (if needed)
# Document in security/accepted-risks.md
```

### Issue: Suspicious Activity Detected

**Symptoms**:
- Unusual access patterns
- Failed authentication attempts
- Mass data access

**Immediate Actions**:
```bash
# 1. Check audit logs
curl http://localhost:8080/api/v1/audit?since=1h | jq '.[] | select(.event_type=="permission_denied")'

# 2. Ban suspicious IPs
curl -X POST http://localhost:8080/api/v1/security/banned-ips \
  -H "Content-Type: application/json" \
  -d '{"ip": "10.0.0.1", "reason": "Suspicious activity"}'

# 3. Rotate secrets
./scripts/rotate-secrets.sh

# 4. Review access logs
docker-compose logs llm-config-manager | grep -i "403\|401"

# 5. Notify security team
# See incident-response.md for full procedure
```

## Deployment Issues

### Issue: Rolling Update Fails

**Symptoms** (Kubernetes):
- Pods stuck in Pending/ImagePullBackOff
- New version not starting
- Rollout stuck

**Solution**:
```bash
# 1. Check rollout status
kubectl rollout status deployment llm-config-manager -n llm-config

# 2. Check pod events
kubectl describe pod -n llm-config <pod-name>

# 3. Check image availability
docker pull llm-config-manager:latest

# 4. Rollback if needed
kubectl rollout undo deployment llm-config-manager -n llm-config

# 5. Check for configuration errors
kubectl logs -n llm-config <pod-name>

# 6. Retry deployment
kubectl rollout restart deployment llm-config-manager -n llm-config
```

### Issue: Health Check Failing After Deployment

**Symptoms**:
- New version deployed but health check fails
- Pods not becoming ready
- Old version not terminating

**Solution**:
```bash
# 1. Check health endpoint directly
kubectl port-forward -n llm-config <pod-name> 8080:8080
curl http://localhost:8080/health

# 2. Check logs for errors
kubectl logs -n llm-config <pod-name> --tail=100

# 3. Check configuration
kubectl get configmap -n llm-config llm-config-manager-config -o yaml

# 4. Verify secrets
kubectl get secret -n llm-config llm-config-manager-secrets -o yaml

# 5. Rollback if critical
kubectl rollout undo deployment llm-config-manager -n llm-config
```

## Quick Reference Commands

### Health Checks
```bash
# Overall health
curl http://localhost:8080/health

# Component health
curl http://localhost:8080/health | jq '.checks'

# Service status
docker-compose ps
kubectl get pods -n llm-config
sudo systemctl status llm-config-manager
```

### Logs
```bash
# View logs
docker-compose logs --tail=100 llm-config-manager
kubectl logs -n llm-config -l app=llm-config-manager --tail=100
sudo journalctl -u llm-config-manager -n 100

# Follow logs
docker-compose logs -f llm-config-manager
kubectl logs -n llm-config -l app=llm-config-manager -f
sudo journalctl -u llm-config-manager -f
```

### Restart Service
```bash
# Docker
docker-compose restart llm-config-manager

# Kubernetes
kubectl rollout restart deployment llm-config-manager -n llm-config

# Systemd
sudo systemctl restart llm-config-manager
```

### Clear Cache
```bash
docker-compose exec redis redis-cli FLUSHALL
kubectl exec -n llm-config redis-0 -- redis-cli FLUSHALL
redis-cli FLUSHALL
```

### Check Metrics
```bash
curl http://localhost:9090/metrics
curl http://localhost:9091/api/v1/query?query=up
```

## Escalation

If issue cannot be resolved:

1. **Document the issue**: Collect logs, metrics, and reproduction steps
2. **Check known issues**: Review GitHub issues and documentation
3. **Contact support**:
   - On-call: ops-oncall@example.com
   - SRE team: sre-team@example.com
   - Emergency: +1-555-0100
4. **Follow incident response procedure**: See incident-response.md

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-21
**Next Review**: 2026-02-21
**Owner**: Operations Team
