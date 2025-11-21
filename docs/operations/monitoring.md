# Operations Monitoring Guide

**Version**: 1.0.0
**Last Updated**: 2025-11-21
**Purpose**: Complete guide for monitoring LLM Config Manager in production

## Table of Contents

1. [Overview](#overview)
2. [Key Metrics to Track](#key-metrics-to-track)
3. [Alert Thresholds](#alert-thresholds)
4. [Dashboard Setup](#dashboard-setup)
5. [Monitoring Best Practices](#monitoring-best-practices)
6. [Alert Response Procedures](#alert-response-procedures)

## Overview

This guide extends the technical monitoring documentation with operational procedures and best practices for production monitoring.

**Related Documentation**:
- Technical Monitoring: `/docs/MONITORING.md`
- Metrics Reference: `/docs/BENCHMARKS.md`
- Health Checks: `/docs/operations/runbooks/health-checks.md`

### Monitoring Philosophy

**Four Golden Signals** (Google SRE):
1. **Latency**: How long does it take to serve a request?
2. **Traffic**: How much demand is on the system?
3. **Errors**: What is the rate of failed requests?
4. **Saturation**: How full is the service?

## Key Metrics to Track

### Critical Metrics (Monitor Continuously)

#### 1. Service Availability

**Metric**: `up{job="llm-config-manager"}`
**Target**: 100% (99.9% acceptable)
**Alert If**: Service down for >1 minute

**Query**:
```promql
up{job="llm-config-manager"} == 0
```

**Dashboard Panel**: Single stat showing "UP" or "DOWN"

#### 2. Request Success Rate

**Metric**: `http_requests_total`
**Target**: >99% success rate
**Alert If**: <99% for >5 minutes

**Query**:
```promql
sum(rate(http_requests_total{status!~"5.."}[5m]))
/
sum(rate(http_requests_total[5m]))
* 100
```

**Dashboard Panel**: Time series graph with target line at 99%

#### 3. Response Time (P95)

**Metric**: `http_request_duration_seconds`
**Target**: <100ms (P95)
**Alert If**: >200ms for >5 minutes

**Query**:
```promql
histogram_quantile(0.95,
  rate(http_request_duration_seconds_bucket[5m])
)
```

**Dashboard Panel**: Graph showing P50, P95, P99 latencies

#### 4. Error Rate

**Metric**: `config_errors_total`
**Target**: <1% of operations
**Alert If**: >5% for >5 minutes

**Query**:
```promql
sum(rate(config_errors_total[5m]))
/
sum(rate(config_operations_total[5m]))
* 100
```

**Dashboard Panel**: Time series with alert threshold line

### Important Metrics (Monitor Regularly)

#### 5. Cache Hit Rate

**Metric**: `cache_hits_total` / `(cache_hits_total + cache_misses_total)`
**Target**: >80%
**Alert If**: <70% for >10 minutes

**Query**:
```promql
sum(rate(cache_hits_total[5m]))
/
(sum(rate(cache_hits_total[5m])) + sum(rate(cache_misses_total[5m])))
* 100
```

**Dashboard Panel**: Gauge showing current hit rate

#### 6. Storage Size

**Metric**: `storage_size_bytes`
**Target**: <80% capacity
**Alert If**: >90% capacity

**Query**:
```promql
storage_size_bytes / (100 * 1024 * 1024 * 1024) # Convert to GB
```

**Dashboard Panel**: Gauge showing used space in GB

#### 7. CPU Usage

**Metric**: `process_cpu_seconds_total`
**Target**: <70%
**Alert If**: >85% for >10 minutes

**Query**:
```promql
rate(process_cpu_seconds_total[5m]) * 100
```

**Dashboard Panel**: Time series graph

#### 8. Memory Usage

**Metric**: `process_resident_memory_bytes`
**Target**: <2GB
**Alert If**: >3.5GB

**Query**:
```promql
process_resident_memory_bytes / (1024 * 1024 * 1024) # Convert to GB
```

**Dashboard Panel**: Graph with memory limit line

### Operational Metrics (Track Trends)

#### 9. Configuration Operations

**Metrics**:
- `config_operations_total{operation="set"}`
- `config_operations_total{operation="get"}`
- `config_operations_total{operation="delete"}`

**Query**:
```promql
sum by (operation) (rate(config_operations_total[5m]))
```

**Dashboard Panel**: Stacked area chart by operation type

#### 10. Active Configurations

**Metric**: `config_active_total`
**Use**: Capacity planning

**Query**:
```promql
sum by (environment) (config_active_total)
```

**Dashboard Panel**: Bar chart by environment

## Alert Thresholds

### Critical Alerts (Immediate Response Required)

| Alert Name | Condition | Duration | Severity |
|------------|-----------|----------|----------|
| ServiceDown | `up{job="llm-config-manager"} == 0` | 1m | Critical |
| HighErrorRate | Error rate >10% | 5m | Critical |
| StorageFailure | Storage unavailable | 1m | Critical |
| OutOfMemory | Memory >95% limit | 2m | Critical |

**Response Time**: <5 minutes
**Escalation**: Immediate page on-call engineer

### Warning Alerts (Attention Required)

| Alert Name | Condition | Duration | Severity |
|------------|-----------|----------|----------|
| ElevatedErrorRate | Error rate >5% | 10m | Warning |
| HighLatency | P95 latency >200ms | 10m | Warning |
| LowCacheHitRate | Hit rate <70% | 15m | Warning |
| HighCPU | CPU usage >85% | 15m | Warning |
| HighMemory | Memory >80% limit | 10m | Warning |
| StorageNearCapacity | Storage >85% full | 30m | Warning |

**Response Time**: <30 minutes
**Escalation**: Notify team channel, investigate within hours

### Info Alerts (Informational)

| Alert Name | Condition | Duration | Severity |
|------------|-----------|----------|----------|
| DeploymentStarted | Deployment in progress | N/A | Info |
| ConfigurationChanged | Config change detected | N/A | Info |
| UnusualAccessPattern | Access spike detected | 5m | Info |
| CacheEvictionHigh | High eviction rate | 20m | Info |

**Response Time**: Best effort
**Escalation**: Log for review

## Dashboard Setup

### Main Operations Dashboard

**Purpose**: Single-pane view of system health

**Panels** (12 total):

1. **System Status** (Single Stat)
   - Metric: Overall health status
   - Target: "Healthy"

2. **Uptime** (Single Stat)
   - Metric: `time() - process_start_time_seconds`
   - Target: >99.9%

3. **Request Rate** (Graph)
   - Metric: `rate(http_requests_total[5m])`
   - Shows: Requests per second

4. **Success Rate** (Gauge)
   - Metric: Success rate %
   - Target: >99%

5. **P95 Latency** (Graph)
   - Metric: P95 response time
   - Target: <100ms

6. **Error Rate** (Graph)
   - Metric: Error percentage
   - Alert at: 5%, 10%

7. **Cache Hit Rate** (Gauge)
   - Metric: Cache hit percentage
   - Target: >80%

8. **Active Configurations** (Single Stat)
   - Metric: `config_active_total`
   - Shows: Current count

9. **Operations Breakdown** (Pie Chart)
   - Metric: Operations by type
   - Shows: SET, GET, DELETE, LIST

10. **CPU Usage** (Graph)
    - Metric: CPU percentage
    - Alert at: 85%

11. **Memory Usage** (Graph)
    - Metric: Memory in GB
    - Alert at: 3.5GB

12. **Storage Size** (Graph)
    - Metric: Storage used in GB
    - Alert at: 90GB

**Refresh Rate**: 5 seconds
**Time Range**: Last 1 hour (adjustable)

### Security Monitoring Dashboard

**Purpose**: Track security events and access patterns

**Panels**:

1. **Permission Denials** (Graph)
   - Metric: `rbac_permission_denials_total`
   - Alert if spike detected

2. **Rate Limit Hits** (Graph)
   - Metric: Rate limit violations
   - Shows: Requests blocked

3. **Banned IPs** (Table)
   - Metric: Currently banned IPs
   - Shows: IP, reason, duration

4. **Failed Authentication** (Counter)
   - Metric: Failed auth attempts
   - Alert at: >10 in 5m

5. **Secret Access** (Graph)
   - Metric: Secret read operations
   - Track unusual patterns

6. **Audit Events** (Graph)
   - Metric: `audit_events_total` by type
   - Shows: Event distribution

**Refresh Rate**: 10 seconds

### Performance Dashboard

**Purpose**: Deep dive into performance metrics

**Panels**:

1. **Latency Heatmap** (Heatmap)
   - Shows: Request latency distribution

2. **Operations Per Second** (Graph)
   - Metric: `rate(config_operations_total[5m])`
   - By operation type

3. **Cache Performance** (Graph)
   - L1 vs L2 hit rates
   - Cache efficiency

4. **Database Query Time** (Graph)
   - Metric: Database operation latency
   - Shows: Slow query patterns

5. **Resource Utilization** (Graph)
   - CPU, Memory, Disk I/O
   - Network bandwidth

6. **Connection Pools** (Graph)
   - Active vs available connections
   - Pool saturation

**Refresh Rate**: 10 seconds

## Monitoring Best Practices

### 1. Baseline Everything

**Action Items**:
- Record normal operating metrics for 1 week
- Document baseline values in runbook
- Set alert thresholds 20% above baseline
- Review baselines quarterly

**Example Baseline Documentation**:
```yaml
baselines:
  request_rate_rps: 1000
  p95_latency_ms: 45
  cache_hit_rate_pct: 85
  cpu_usage_pct: 40
  memory_usage_gb: 1.5
  error_rate_pct: 0.05
```

### 2. Monitor Trends, Not Just Thresholds

**Trend Monitoring**:
```promql
# Week-over-week latency comparison
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
/
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m] offset 7d))

# Daily traffic pattern
avg_over_time(rate(http_requests_total[1h])[1d:1h])
```

**Watch For**:
- Gradual memory increase (potential leak)
- Declining cache hit rate (capacity issue)
- Increasing latency (performance degradation)
- Growing storage size (cleanup needed)

### 3. Use Recording Rules

**Pre-compute expensive queries**:

```yaml
# prometheus.yml
groups:
  - name: llm_config_recording_rules
    interval: 30s
    rules:
      # Success rate
      - record: job:http_success_rate:5m
        expr: |
          sum(rate(http_requests_total{status!~"5.."}[5m]))
          /
          sum(rate(http_requests_total[5m]))

      # Cache hit rate
      - record: job:cache_hit_rate:5m
        expr: |
          sum(rate(cache_hits_total[5m]))
          /
          (sum(rate(cache_hits_total[5m])) + sum(rate(cache_misses_total[5m])))

      # Error rate
      - record: job:error_rate:5m
        expr: |
          sum(rate(config_errors_total[5m]))
          /
          sum(rate(config_operations_total[5m]))
```

### 4. Alert on Symptoms, Not Causes

**Good Alerts** (symptom-based):
- "API response time >200ms" (user impact)
- "Error rate >5%" (user impact)
- "Service unavailable" (user impact)

**Bad Alerts** (cause-based):
- "CPU >80%" (may not affect users)
- "Memory >3GB" (may not affect users)
- "Disk I/O high" (may not affect users)

**Exception**: Alert on causes that predict future symptoms:
- "Disk >90% full" (will cause issues soon)
- "Memory leak detected" (will cause issues soon)

### 5. Reduce Alert Fatigue

**Strategies**:

1. **Use appropriate durations**:
   ```yaml
   # Bad: Alert immediately on any spike
   - alert: HighLatency
     expr: p95_latency > 100ms
     for: 0s  # Too aggressive

   # Good: Alert only if sustained
   - alert: HighLatency
     expr: p95_latency > 100ms
     for: 10m  # Sustained issue
   ```

2. **Group related alerts**:
   ```yaml
   route:
     group_by: ['alertname', 'environment']
     group_wait: 10s
     group_interval: 5m
   ```

3. **Use inhibition rules**:
   ```yaml
   inhibit_rules:
     # If service is down, suppress all other alerts
     - source_match:
         alertname: ServiceDown
       target_match_re:
         alertname: .*
       equal: ['job']
   ```

4. **Implement quiet hours** (non-critical alerts only):
   ```yaml
   route:
     routes:
       - match:
           severity: info
         receiver: quiet-hours
         active_time_intervals:
           - weekdays-business-hours
   ```

### 6. Document Alert Response

For each alert, document:
- **What it means**: User impact
- **Why it fired**: Root cause indicators
- **How to investigate**: Step-by-step
- **How to resolve**: Common solutions
- **When to escalate**: Escalation criteria

**Example Alert Documentation**:
```yaml
- alert: HighLatency
  description: |
    API P95 latency is above 200ms.

    User Impact: Slow response times, poor user experience

    Common Causes:
    - High traffic (check request rate)
    - Low cache hit rate (check cache metrics)
    - Database slow (check DB query times)
    - Resource constraints (check CPU/memory)

    Investigation:
    1. Check current request rate
    2. Check cache hit rate
    3. Check database performance
    4. Check resource utilization

    Resolution:
    - If high traffic: Scale horizontally
    - If low cache hit: Increase cache size
    - If DB slow: Optimize queries
    - If resources: Increase limits

    Escalate if: Not resolved in 30 minutes
```

## Alert Response Procedures

### Critical Alert Response

**Timeline**: <5 minutes to acknowledge, <30 minutes to resolve or escalate

#### ServiceDown Alert

```bash
# 1. Acknowledge alert (immediately)
# Via PagerDuty/Slack/etc.

# 2. Check service status (1 minute)
kubectl get pods -n llm-config
docker-compose ps
systemctl status llm-config-manager

# 3. Check recent events (2 minutes)
kubectl describe pod -n llm-config <pod-name>
docker-compose logs --since 10m llm-config-manager
journalctl -u llm-config-manager --since "10 minutes ago"

# 4. Attempt restart (2 minutes)
kubectl rollout restart deployment llm-config-manager -n llm-config
docker-compose restart llm-config-manager
systemctl restart llm-config-manager

# 5. Verify recovery (2 minutes)
curl http://localhost:8080/health
kubectl get pods -n llm-config

# 6. If not recovered: Escalate (5 minutes)
# Notify senior engineer
# Follow incident response procedure
```

#### HighErrorRate Alert

```bash
# 1. Check error distribution (1 minute)
curl -s http://localhost:9090/metrics | grep config_errors_total

# 2. Check recent errors (2 minutes)
docker-compose logs --since 5m llm-config-manager | grep ERROR

# 3. Check health status (1 minute)
curl http://localhost:8080/health

# 4. Identify pattern (3 minutes)
# - Specific operation failing?
# - Specific environment?
# - Database/cache issue?

# 5. Apply mitigation (5 minutes)
# - Restart if needed
# - Clear cache if needed
# - Scale if needed

# 6. Monitor recovery (3 minutes)
watch -n 5 'curl -s http://localhost:9090/metrics | grep config_errors_total'
```

### Warning Alert Response

**Timeline**: <30 minutes to acknowledge, <2 hours to resolve

Follow investigation procedures in:
- `/docs/operations/runbooks/performance-troubleshooting.md`
- `/docs/operations/runbooks/common-issues.md`

### Daily Monitoring Tasks

**Morning Check** (10 minutes):
```bash
# 1. Check overnight alerts
# Review Grafana alert history

# 2. Check service health
curl http://localhost:8080/health | jq '.'

# 3. Review metrics dashboard
# Open main operations dashboard

# 4. Check error logs
docker-compose logs --since 12h llm-config-manager | grep -i error | wc -l

# 5. Verify backups completed
ls -lht /var/lib/llm-config/backups/ | head -5

# 6. Check capacity
df -h /var/lib/llm-config
```

**Weekly Review** (30 minutes):
- Review alert trends
- Analyze performance trends
- Check capacity projections
- Review and tune alert thresholds
- Update runbooks based on incidents

## Monitoring Checklist

**Initial Setup**:
- [ ] Prometheus scraping metrics endpoint
- [ ] Grafana dashboards imported
- [ ] Alert rules configured
- [ ] Alert routing configured (email, Slack, PagerDuty)
- [ ] Runbooks documented
- [ ] Team trained on alert response

**Ongoing Operations**:
- [ ] Daily health checks performed
- [ ] Alerts responded to within SLA
- [ ] Weekly metrics review completed
- [ ] Monthly baseline review
- [ ] Quarterly runbook updates

**Post-Incident**:
- [ ] Alert firing analyzed
- [ ] Response time documented
- [ ] Root cause identified
- [ ] Preventive measures implemented
- [ ] Runbook updated
- [ ] Team retrospective completed

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-21
**Next Review**: 2026-02-21
**Owner**: Operations Team
