# Performance Troubleshooting Runbook

**Version**: 1.0.0
**Last Updated**: 2025-11-21
**Purpose**: Diagnose and resolve performance issues in LLM Config Manager

## Table of Contents

1. [Overview](#overview)
2. [Performance Baselines](#performance-baselines)
3. [Quick Diagnostics](#quick-diagnostics)
4. [High Latency Issues](#high-latency-issues)
5. [High CPU Usage](#high-cpu-usage)
6. [High Memory Usage](#high-memory-usage)
7. [Cache Performance Issues](#cache-performance-issues)
8. [Database Performance Issues](#database-performance-issues)
9. [Network Performance Issues](#network-performance-issues)
10. [Resource Exhaustion](#resource-exhaustion)
11. [Performance Optimization](#performance-optimization)

## Overview

This runbook provides systematic procedures for diagnosing and resolving performance issues. Use it when experiencing:

- High response times (>100ms P95)
- Increased error rates
- Resource constraints
- Throughput degradation
- Cache inefficiency

### Performance Troubleshooting Workflow

```
1. Identify Symptoms → 2. Collect Metrics → 3. Analyze Data
                                                     ↓
6. Verify Fix ← 5. Implement Solution ← 4. Diagnose Root Cause
```

## Performance Baselines

### Expected Performance Metrics

| Operation | Latency (P50) | Latency (P95) | Latency (P99) | Throughput |
|-----------|---------------|---------------|---------------|------------|
| Cache Hit (L1) | <0.5ms | <1ms | <2ms | 1M+ ops/sec |
| Cache Hit (L2) | <2ms | <5ms | <10ms | 100K+ ops/sec |
| Storage Read | <20ms | <50ms | <100ms | 1K+ ops/sec |
| Storage Write | <30ms | <100ms | <200ms | 500+ ops/sec |
| API Request (cached) | <5ms | <10ms | <20ms | 10K+ req/sec |
| API Request (uncached) | <50ms | <150ms | <300ms | 1K+ req/sec |

### Normal Resource Usage

| Resource | Normal | Warning | Critical |
|----------|--------|---------|----------|
| CPU Usage | <50% | 50-80% | >80% |
| Memory Usage | <60% | 60-80% | >80% |
| Disk I/O | <70% | 70-85% | >85% |
| Network I/O | <60% | 60-80% | >80% |
| Cache Hit Rate | >80% | 70-80% | <70% |
| Error Rate | <0.1% | 0.1-1% | >1% |

## Quick Diagnostics

### 1-Minute Health Check

Run this quick diagnostic to identify immediate issues:

```bash
#!/bin/bash
# Quick performance diagnostic

echo "=== Quick Performance Check ==="
echo ""

# 1. Response Time
echo "1. API Response Time:"
curl -w "Time: %{time_total}s\n" -o /dev/null -s http://localhost:8080/health

# 2. Service Status
echo "2. Service Status:"
curl -s http://localhost:8080/health | jq -r '.status'

# 3. Resource Usage (Docker)
echo "3. Resource Usage:"
docker stats llm-config-manager --no-stream --format "CPU: {{.CPUPerc}}, Memory: {{.MemPerc}}"

# 4. Error Rate (last 5 min)
echo "4. Recent Errors:"
docker-compose logs --since 5m llm-config-manager | grep -c ERROR

# 5. Cache Hit Rate
echo "5. Cache Performance:"
curl -s http://localhost:9090/metrics | grep cache_hits_total | tail -2

echo ""
echo "Check complete"
```

### Key Metrics to Check

```bash
# Get current metrics
curl -s http://localhost:9090/metrics | grep -E "config_operation_duration|cache_hits_total|http_request_duration"

# Calculate error rate
curl -s http://localhost:9090/metrics | awk '
/config_errors_total/ {errors+=$2}
/config_operations_total/ {ops+=$2}
END {if(ops>0) print "Error Rate:", (errors/ops)*100"%"}'

# Check P95 latency from Prometheus
curl -s 'http://localhost:9091/api/v1/query?query=histogram_quantile(0.95,rate(http_request_duration_seconds_bucket[5m]))' | jq '.data.result[0].value[1]'
```

## High Latency Issues

### Symptoms
- API response times >100ms (P95)
- Slow user experience
- Timeouts occurring
- Queue buildup

### Diagnosis Steps

#### Step 1: Identify Slow Operations

```bash
# Check latency distribution
curl -s http://localhost:9090/metrics | grep "config_operation_duration_seconds"

# Identify slowest operations
curl -s 'http://localhost:9091/api/v1/query?query=topk(5,rate(config_operation_duration_seconds_sum[5m])/rate(config_operation_duration_seconds_count[5m]))' | jq '.data.result'
```

#### Step 2: Check Cache Hit Rate

```bash
# Calculate cache hit rate
curl -s http://localhost:9090/metrics | awk '
/cache_hits_total/ {hits+=$2}
/cache_misses_total/ {misses+=$2}
END {
    total = hits + misses
    if(total > 0) {
        hit_rate = (hits / total) * 100
        print "Cache Hit Rate:", hit_rate"%"
        print "Total Hits:", hits
        print "Total Misses:", misses
    }
}'
```

Expected: >80% hit rate

#### Step 3: Check Storage Latency

```bash
# Test storage read latency
time curl -s http://localhost:8080/api/v1/configs/test/key?env=production > /dev/null

# Check storage metrics
curl -s http://localhost:9090/metrics | grep "storage_operation_duration_seconds"

# Test database directly (if PostgreSQL)
docker-compose exec postgres psql -U llm_config_user -d llm_config -c "
\timing on
SELECT * FROM configs LIMIT 100;
"
```

#### Step 4: Check Network Latency

```bash
# Test network latency to dependencies
ping -c 10 localhost
ping -c 10 postgres
ping -c 10 redis

# Check for packet loss
mtr --report --report-cycles 10 localhost
```

### Resolution Strategies

#### High Cache Miss Rate (<70%)

```bash
# 1. Check cache configuration
curl http://localhost:8080/health | jq '.checks.cache'

# 2. Increase cache size
# Docker: Edit docker-compose.yml
services:
  llm-config-manager:
    environment:
      - CACHE_L1_SIZE=50000  # Increase from 10000
      - CACHE_L1_TTL_SECONDS=7200  # Increase TTL

# 3. Restart service
docker-compose restart llm-config-manager

# 4. Pre-warm cache (if needed)
# Fetch frequently accessed configs to populate cache
```

#### Slow Storage Operations

```bash
# 1. Check disk I/O
iostat -x 1 5

# 2. Check for disk space issues
df -h /var/lib/llm-config

# 3. Check for database locks (PostgreSQL)
docker-compose exec postgres psql -U llm_config_user -d llm_config -c "
SELECT pid, usename, state, query, age(clock_timestamp(), query_start)
FROM pg_stat_activity
WHERE state != 'idle' AND query NOT ILIKE '%pg_stat_activity%'
ORDER BY query_start ASC;
"

# 4. Optimize database (if needed)
docker-compose exec postgres psql -U llm_config_user -d llm_config -c "VACUUM ANALYZE;"
```

#### Network Latency

```bash
# 1. Check for network issues
netstat -s | grep -i error

# 2. Check connection pool status
curl -s http://localhost:9090/metrics | grep "connection_pool"

# 3. Increase connection pool size
# Edit configuration to increase pool size
DATABASE_POOL_SIZE=50  # Increase from default

# 4. Check for DNS issues
nslookup postgres
nslookup redis
```

## High CPU Usage

### Symptoms
- CPU usage >80%
- Slow response times
- Increased latency
- System unresponsive

### Diagnosis Steps

#### Step 1: Identify CPU Consumers

```bash
# Docker
docker stats llm-config-manager --no-stream

# Systemd
top -p $(pgrep llm-config-server) -n 1

# Kubernetes
kubectl top pod -n llm-config -l app=llm-config-manager
```

#### Step 2: Check Request Rate

```bash
# Current request rate
curl -s http://localhost:9090/metrics | grep "http_requests_total"

# Calculate requests per second (from Prometheus)
curl -s 'http://localhost:9091/api/v1/query?query=rate(http_requests_total[5m])' | jq '.data.result[0].value[1]'
```

#### Step 3: Check for Hot Loops

```bash
# Get CPU profile (if enabled)
curl -s http://localhost:8080/debug/pprof/profile?seconds=30 > cpu.prof

# Check for long-running operations
docker-compose logs --since 5m llm-config-manager | grep "duration_ms" | sort -t: -k2 -n | tail -20
```

### Resolution Strategies

#### High Request Load

```bash
# 1. Check request rate
current_rps=$(curl -s 'http://localhost:9091/api/v1/query?query=rate(http_requests_total[5m])' | jq -r '.data.result[0].value[1]')
echo "Current RPS: $current_rps"

# 2. Scale horizontally (Kubernetes)
kubectl scale deployment llm-config-manager -n llm-config --replicas=5

# 3. Enable rate limiting (if not already)
# Edit security configuration
RATE_LIMIT_RPS=100
RATE_LIMIT_BURST=50

# 4. Add more worker threads
# Docker: Edit docker-compose.yml
services:
  llm-config-manager:
    environment:
      - SERVER_WORKERS=8  # Increase from 4
```

#### Inefficient Operations

```bash
# 1. Identify expensive operations
curl -s http://localhost:9090/metrics | grep "operation_duration_seconds" | sort -t= -k2 -n | tail -10

# 2. Enable query caching
# Ensure cache is enabled and properly sized

# 3. Optimize database queries
# Add indexes if needed (PostgreSQL)
docker-compose exec postgres psql -U llm_config_user -d llm_config -c "
CREATE INDEX IF NOT EXISTS idx_configs_namespace ON configs(namespace);
CREATE INDEX IF NOT EXISTS idx_configs_key ON configs(key);
CREATE INDEX IF NOT EXISTS idx_configs_env ON configs(environment);
"

# 4. Review and optimize hot code paths
# Check application logs for performance warnings
```

## High Memory Usage

### Symptoms
- Memory usage >80%
- OOM kills
- Swapping occurring
- Slow performance

### Diagnosis Steps

#### Step 1: Check Memory Usage

```bash
# Docker
docker stats llm-config-manager --no-stream --format "Memory: {{.MemUsage}}"

# Systemd
ps aux | grep llm-config-server | awk '{print $6}'
free -h

# Kubernetes
kubectl top pod -n llm-config -l app=llm-config-manager
```

#### Step 2: Check Cache Size

```bash
# Check L1 cache size
curl -s http://localhost:9090/metrics | grep "cache_size_entries"

# Check Redis memory
docker-compose exec redis redis-cli INFO memory | grep used_memory_human

# Check memory breakdown
curl -s http://localhost:9090/metrics | grep "memory_usage_bytes"
```

#### Step 3: Check for Memory Leaks

```bash
# Monitor memory over time (5 minutes)
for i in {1..60}; do
  docker stats llm-config-manager --no-stream --format "{{.MemPerc}}" | tee -a /tmp/memory_trend.log
  sleep 5
done

# Analyze trend
cat /tmp/memory_trend.log
```

### Resolution Strategies

#### Excessive Cache Size

```bash
# 1. Check current cache usage
docker-compose exec redis redis-cli INFO memory

# 2. Reduce cache size
# Edit docker-compose.yml
services:
  llm-config-manager:
    environment:
      - CACHE_L1_SIZE=5000  # Reduce from 10000

redis:
  command: redis-server --maxmemory 512mb --maxmemory-policy allkeys-lru

# 3. Clear cache if needed
docker-compose exec redis redis-cli FLUSHALL

# 4. Restart service
docker-compose restart llm-config-manager redis
```

#### Memory Leak

```bash
# 1. Restart service (immediate mitigation)
docker-compose restart llm-config-manager

# 2. Check for known issues
# Review application logs for memory warnings

# 3. Enable memory profiling
# Add to configuration
RUST_LOG=debug
MEMORY_PROFILING_ENABLED=true

# 4. Collect memory profile
curl -s http://localhost:8080/debug/pprof/heap > heap.prof

# 5. Monitor after restart
watch -n 5 'docker stats llm-config-manager --no-stream'
```

#### Increase Memory Limits

```bash
# Docker Compose
services:
  llm-config-manager:
    deploy:
      resources:
        limits:
          memory: 4G  # Increase from 2G
        reservations:
          memory: 2G

# Kubernetes
kubectl patch deployment llm-config-manager -n llm-config --patch '
spec:
  template:
    spec:
      containers:
      - name: llm-config-manager
        resources:
          limits:
            memory: 4Gi
          requests:
            memory: 2Gi
'

# Systemd
sudo systemctl edit llm-config-manager
# Add:
[Service]
MemoryMax=4G
MemoryHigh=3.5G
```

## Cache Performance Issues

### Symptoms
- Low cache hit rate (<70%)
- High storage load
- Increased latency
- Cache evictions

### Diagnosis

```bash
# 1. Check cache hit rate
curl -s http://localhost:9090/metrics | awk '
/cache_hits_total{tier="l1"}/ {l1_hits=$2}
/cache_misses_total{tier="l1"}/ {l1_misses=$2}
/cache_hits_total{tier="l2"}/ {l2_hits=$2}
/cache_misses_total{tier="l2"}/ {l2_misses=$2}
END {
    l1_total = l1_hits + l1_misses
    l2_total = l2_hits + l2_misses
    if(l1_total > 0) print "L1 Hit Rate:", (l1_hits/l1_total)*100"%"
    if(l2_total > 0) print "L2 Hit Rate:", (l2_hits/l2_total)*100"%"
}'

# 2. Check eviction rate
curl -s http://localhost:9090/metrics | grep "cache_evictions_total"

# 3. Check cache size
curl -s http://localhost:9090/metrics | grep "cache_size_entries"

# 4. Check TTL configuration
curl http://localhost:8080/health | jq '.checks.cache'
```

### Resolution

```bash
# 1. Increase cache size
# Edit configuration
CACHE_L1_SIZE=50000  # Increase
CACHE_L2_MAXMEMORY=2gb  # Increase Redis memory

# 2. Increase TTL
CACHE_L1_TTL_SECONDS=7200  # Increase from 3600

# 3. Pre-warm cache with hot data
# Script to populate cache with frequently accessed configs
#!/bin/bash
for config in production_configs.txt; do
  curl "http://localhost:8080/api/v1/configs/$config?env=production"
done

# 4. Monitor cache performance
watch -n 5 'curl -s http://localhost:9090/metrics | grep cache_hits_total'
```

## Database Performance Issues

### Symptoms
- Slow queries (>100ms)
- High database CPU
- Connection pool exhaustion
- Lock contention

### Diagnosis

```bash
# 1. Check database health
docker-compose exec postgres pg_isready

# 2. Check connection count
docker-compose exec postgres psql -U llm_config_user -d llm_config -c "
SELECT count(*) as connections FROM pg_stat_activity WHERE datname='llm_config';
"

# 3. Check slow queries
docker-compose exec postgres psql -U llm_config_user -d llm_config -c "
SELECT query, calls, total_time, mean_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;
"

# 4. Check for locks
docker-compose exec postgres psql -U llm_config_user -d llm_config -c "
SELECT pid, usename, state, wait_event_type, wait_event, query
FROM pg_stat_activity
WHERE wait_event is NOT NULL;
"
```

### Resolution

```bash
# 1. Add indexes
docker-compose exec postgres psql -U llm_config_user -d llm_config -c "
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_configs_namespace_key
ON configs(namespace, key);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_configs_env_created
ON configs(environment, created_at);
"

# 2. Analyze and vacuum
docker-compose exec postgres psql -U llm_config_user -d llm_config -c "
VACUUM ANALYZE configs;
"

# 3. Increase connection pool
# Edit configuration
DATABASE_POOL_SIZE=50
DATABASE_MAX_CONNECTIONS=100

# 4. Tune PostgreSQL
docker-compose exec postgres psql -U llm_config_user -d llm_config -c "
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
SELECT pg_reload_conf();
"
```

## Network Performance Issues

### Symptoms
- High network latency
- Packet loss
- Connection timeouts
- Slow data transfer

### Diagnosis

```bash
# 1. Check network latency
ping -c 100 localhost | tail -3
ping -c 100 postgres | tail -3
ping -c 100 redis | tail -3

# 2. Check bandwidth
iperf3 -c postgres -t 10

# 3. Check connection count
netstat -an | grep ESTABLISHED | wc -l

# 4. Check for errors
netstat -s | grep -i error
```

### Resolution

```bash
# 1. Optimize connection pooling
# Use connection pooling for databases
DATABASE_POOL_SIZE=50
REDIS_POOL_SIZE=20

# 2. Enable keepalive
# Add to configuration
TCP_KEEPALIVE=true
TCP_KEEPALIVE_INTERVAL=60

# 3. Use local caching
# Ensure L1 cache is enabled and sized appropriately

# 4. Check network configuration
# Ensure MTU is optimal
ip link show | grep mtu
```

## Resource Exhaustion

### File Descriptor Exhaustion

```bash
# Check current usage
lsof -p $(pgrep llm-config-server) | wc -l

# Check limits
ulimit -n

# Increase limits (Systemd)
sudo systemctl edit llm-config-manager
# Add:
[Service]
LimitNOFILE=65536

# Restart
sudo systemctl restart llm-config-manager
```

### Thread Pool Exhaustion

```bash
# Check thread count
ps -eLf | grep llm-config-server | wc -l

# Increase worker threads
SERVER_WORKERS=16  # Increase

# Monitor thread usage
watch -n 2 'ps -eLf | grep llm-config-server | wc -l'
```

### Disk Space Exhaustion

```bash
# Check disk usage
df -h /var/lib/llm-config

# Clean up old logs
find /var/log/llm-config -name "*.log" -mtime +30 -delete

# Clean up old backups
find /var/lib/llm-config/backups -mtime +90 -delete

# Rotate logs
sudo logrotate -f /etc/logrotate.d/llm-config-manager
```

## Performance Optimization

### General Optimizations

1. **Enable All Caching Layers**
   ```bash
   CACHE_L1_ENABLED=true
   CACHE_L2_ENABLED=true
   CACHE_L1_SIZE=50000
   ```

2. **Tune Worker Threads**
   ```bash
   # Set to number of CPU cores
   SERVER_WORKERS=$(nproc)
   ```

3. **Optimize Database**
   ```bash
   # Add indexes
   # Vacuum regularly
   # Tune configuration
   ```

4. **Use Connection Pooling**
   ```bash
   DATABASE_POOL_SIZE=50
   REDIS_POOL_SIZE=20
   ```

5. **Enable Compression**
   ```bash
   ENABLE_COMPRESSION=true
   COMPRESSION_LEVEL=6
   ```

### Monitoring Performance Improvements

```bash
# Before optimization
curl -w "@-" -o /dev/null -s http://localhost:8080/api/v1/configs/test/key?env=production <<'EOF'
time_total: %{time_total}s
EOF

# After optimization
# Compare times

# Check metrics trends
curl -s 'http://localhost:9091/api/v1/query?query=rate(http_request_duration_seconds_sum[5m])/rate(http_request_duration_seconds_count[5m])'
```

## Performance Optimization Checklist

- [ ] Cache hit rate >80%
- [ ] API response time <100ms (P95)
- [ ] CPU usage <70%
- [ ] Memory usage <70%
- [ ] Database queries <50ms (P95)
- [ ] Connection pools sized appropriately
- [ ] Indexes created on frequently queried fields
- [ ] Logs rotated regularly
- [ ] Monitoring enabled and tracked

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-21
**Next Review**: 2026-02-21
**Owner**: Operations Team
