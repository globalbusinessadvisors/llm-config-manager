# Monitoring and Observability Guide

This guide describes the monitoring and observability features of the LLM Config Manager platform.

## Table of Contents

- [Overview](#overview)
- [Metrics](#metrics)
- [Health Checks](#health-checks)
- [Prometheus Integration](#prometheus-integration)
- [Grafana Dashboards](#grafana-dashboards)
- [Alerting](#alerting)
- [Best Practices](#best-practices)

## Overview

The LLM Config Manager platform provides comprehensive monitoring through:

- **Prometheus Metrics**: Detailed performance and operational metrics
- **Health Checks**: Component health status monitoring
- **Grafana Dashboards**: Visual monitoring and analysis
- **Alert Rules**: Proactive issue detection

### Architecture

```
┌─────────────┐
│ Application │
│   Metrics   │
└──────┬──────┘
       │
       ▼
┌─────────────┐     ┌──────────┐     ┌─────────┐
│ Prometheus  │────▶│ Grafana  │────▶│ Alerts  │
│   Server    │     │Dashboard │     │         │
└─────────────┘     └──────────┘     └─────────┘
```

## Metrics

### Metric Categories

#### 1. Configuration Metrics

**Operations**:
```
config_operations_total{operation, environment}
- Total configuration operations (set, get, delete, list)

config_operation_duration_seconds{operation}
- Operation latency histogram

config_active_total{namespace, environment}
- Number of active configurations

config_errors_total{error_type, operation}
- Error counts by type
```

**Example Queries**:
```promql
# Operations per second
rate(config_operations_total[5m])

# P95 latency
histogram_quantile(0.95, rate(config_operation_duration_seconds_bucket[5m]))

# Error rate
rate(config_errors_total[5m]) / rate(config_operations_total[5m])
```

#### 2. Cache Metrics

**Performance**:
```
cache_hits_total{tier}
- Cache hit count (L1, L2)

cache_misses_total{tier}
- Cache miss count

cache_evictions_total{tier}
- Cache eviction count

cache_size_entries{tier}
- Current cache size

cache_operation_duration_seconds{operation, tier}
- Cache operation latency
```

**Example Queries**:
```promql
# Cache hit rate
sum(rate(cache_hits_total[5m])) /
  (sum(rate(cache_hits_total[5m])) + sum(rate(cache_misses_total[5m])))

# L1 vs L2 hit rates
sum by (tier) (rate(cache_hits_total[5m])) /
  sum by (tier) (rate(cache_hits_total[5m]) + rate(cache_misses_total[5m]))

# Cache efficiency
cache_size_entries / cache_hits_total
```

#### 3. RBAC Metrics

**Authorization**:
```
rbac_permission_checks_total{resource, action, result}
- Permission check count

rbac_permission_denials_total{resource, action}
- Permission denial count

rbac_check_duration_seconds{resource}
- Permission check latency

rbac_active_roles_total{role}
- Active role assignments
```

**Example Queries**:
```promql
# Permission denial rate
rate(rbac_permission_denials_total[5m]) /
  rate(rbac_permission_checks_total[5m])

# Checks per second by resource
sum by (resource) (rate(rbac_permission_checks_total[5m]))

# P99 check latency
histogram_quantile(0.99, rate(rbac_check_duration_seconds_bucket[5m]))
```

#### 4. Audit Metrics

**Events**:
```
audit_events_total{event_type}
- Audit event count

audit_events_by_user_total{user}
- Events by user

audit_event_processing_duration_seconds
- Event processing time

audit_queue_size
- Event queue depth
```

**Example Queries**:
```promql
# Events per second
rate(audit_events_total[5m])

# Top users by activity
topk(10, sum by (user) (rate(audit_events_by_user_total[1h])))

# Queue depth alert
audit_queue_size > 1000
```

#### 5. Storage Metrics

**Operations**:
```
storage_operations_total{operation}
- Storage operation count

storage_operation_duration_seconds{operation}
- Storage operation latency

storage_size_bytes
- Total storage size

storage_errors_total{error_type}
- Storage errors
```

**Example Queries**:
```promql
# Storage throughput
rate(storage_operations_total[5m])

# Average operation latency
rate(storage_operation_duration_seconds_sum[5m]) /
  rate(storage_operation_duration_seconds_count[5m])

# Storage growth rate
deriv(storage_size_bytes[1h])
```

#### 6. Cryptography Metrics

**Operations**:
```
crypto_operations_total{operation, algorithm}
- Crypto operations count

crypto_operation_duration_seconds{operation}
- Crypto operation latency

crypto_key_rotations_total
- Key rotation count

crypto_encryption_errors_total
- Encryption errors
```

**Example Queries**:
```promql
# Crypto operations per second
rate(crypto_operations_total[5m])

# P95 encryption latency
histogram_quantile(0.95, rate(crypto_operation_duration_seconds_bucket[5m]))

# Key rotations per day
increase(crypto_key_rotations_total[24h])
```

#### 7. System Metrics

**Health**:
```
system_uptime_seconds
- System uptime

system_memory_usage_bytes
- Memory usage

http_requests_total{method, path, status}
- HTTP request count

http_request_duration_seconds{method, path}
- HTTP request latency
```

**Example Queries**:
```promql
# Requests per second
rate(http_requests_total[5m])

# Error rate (5xx responses)
sum(rate(http_requests_total{status=~"5.."}[5m])) /
  sum(rate(http_requests_total[5m]))

# P95 request latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

## Health Checks

### Endpoints

#### `/health`
Returns overall system health status.

**Response (Healthy)**:
```json
{
  "status": "healthy",
  "checks": {
    "storage": {
      "component": "storage",
      "status": "healthy",
      "message": null,
      "last_check": "2024-01-15T10:30:00Z",
      "duration_ms": 5
    },
    "cache": {
      "component": "cache",
      "status": "healthy",
      "message": null,
      "last_check": "2024-01-15T10:30:00Z",
      "duration_ms": 2
    }
  },
  "timestamp": "2024-01-15T10:30:00Z",
  "uptime_seconds": 86400
}
```

**Response (Degraded)**:
```json
{
  "status": "degraded",
  "checks": {
    "disk": {
      "component": "disk",
      "status": "degraded",
      "message": "Disk usage at 85% (warning threshold: 80%)",
      "last_check": "2024-01-15T10:30:00Z",
      "duration_ms": 10
    }
  },
  "timestamp": "2024-01-15T10:30:00Z",
  "uptime_seconds": 86400
}
```

#### `/health/ready`
Returns readiness status (can accept traffic).

#### `/health/live`
Returns liveness status (application is running).

### Health Check Components

1. **Storage**: File system or database connectivity
2. **Cache**: Cache layer health (L1 + L2)
3. **Database**: Database connection pool status
4. **Disk Space**: Available disk space
5. **Memory**: Memory usage

### Status Codes

| Status | HTTP Code | Description |
|--------|-----------|-------------|
| `healthy` | 200 | All components healthy |
| `degraded` | 200 | Some components degraded |
| `unhealthy` | 503 | Critical components unhealthy |

## Prometheus Integration

### Configuration

**prometheus.yml**:
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'llm-config-manager'
    static_configs:
      - targets: ['localhost:9090']
    metrics_path: '/metrics'
```

### Metric Endpoint

The application exposes metrics at:
```
GET /metrics
```

**Example Response**:
```
# HELP config_operations_total Total number of configuration operations
# TYPE config_operations_total counter
config_operations_total{operation="set",environment="production"} 1234
config_operations_total{operation="get",environment="production"} 5678

# HELP cache_hits_total Total cache hits
# TYPE cache_hits_total counter
cache_hits_total{tier="l1"} 10000
cache_hits_total{tier="l2"} 2000

# HELP http_request_duration_seconds HTTP request duration
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{method="GET",path="/api/config",le="0.005"} 100
http_request_duration_seconds_bucket{method="GET",path="/api/config",le="0.01"} 150
http_request_duration_seconds_sum{method="GET",path="/api/config"} 1.5
http_request_duration_seconds_count{method="GET",path="/api/config"} 200
```

### Service Discovery

For dynamic environments, use Prometheus service discovery:

**kubernetes_sd_config**:
```yaml
scrape_configs:
  - job_name: 'llm-config-manager'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_app]
        action: keep
        regex: llm-config-manager
```

## Grafana Dashboards

### Pre-built Dashboards

The platform includes pre-configured Grafana dashboards:

1. **Overview Dashboard**: High-level system health
2. **Performance Dashboard**: Latency and throughput metrics
3. **Cache Dashboard**: Cache performance and hit rates
4. **Security Dashboard**: RBAC and audit metrics
5. **Error Dashboard**: Error rates and types

### Dashboard Import

Import dashboards from `monitoring/grafana/dashboards/`:

1. Open Grafana UI
2. Navigate to Dashboards → Import
3. Upload dashboard JSON file
4. Select Prometheus data source
5. Click Import

### Key Panels

#### Overview Dashboard
- System uptime
- Request rate
- Error rate
- Cache hit rate
- Active configurations
- Recent alerts

#### Performance Dashboard
- P50/P95/P99 latencies
- Operations per second
- Resource utilization
- Request breakdown by operation
- Slowest operations

#### Cache Dashboard
- L1 vs L2 hit rates
- Cache size over time
- Eviction rate
- Cache efficiency
- Miss patterns

## Alerting

### Alert Rules

**Prometheus alert rules** (`monitoring/prometheus/alerts.yml`):

```yaml
groups:
  - name: llm-config-manager
    interval: 30s
    rules:
      # High error rate
      - alert: HighErrorRate
        expr: |
          sum(rate(config_errors_total[5m])) /
          sum(rate(config_operations_total[5m])) > 0.05
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value | humanizePercentage }}"

      # Low cache hit rate
      - alert: LowCacheHitRate
        expr: |
          sum(rate(cache_hits_total[5m])) /
          (sum(rate(cache_hits_total[5m])) + sum(rate(cache_misses_total[5m]))) < 0.7
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Cache hit rate below 70%"
          description: "Hit rate: {{ $value | humanizePercentage }}"

      # High latency
      - alert: HighLatency
        expr: |
          histogram_quantile(0.95,
            rate(config_operation_duration_seconds_bucket[5m])
          ) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "P95 latency above 100ms"
          description: "Current P95: {{ $value }}s"

      # Storage near capacity
      - alert: StorageNearCapacity
        expr: storage_size_bytes > 80e9  # 80GB
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "Storage usage above 80GB"
          description: "Current size: {{ $value | humanize }}B"

      # Service down
      - alert: ServiceDown
        expr: up{job="llm-config-manager"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "LLM Config Manager is down"
          description: "Service has been down for 1 minute"

      # High permission denial rate
      - alert: HighPermissionDenialRate
        expr: |
          rate(rbac_permission_denials_total[5m]) /
          rate(rbac_permission_checks_total[5m]) > 0.2
        for: 10m
        labels:
          severity: info
        annotations:
          summary: "High permission denial rate"
          description: "Denial rate: {{ $value | humanizePercentage }}"

      # Audit queue backing up
      - alert: AuditQueueBackup
        expr: audit_queue_size > 10000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Audit queue is backing up"
          description: "Queue size: {{ $value }}"
```

### Alert Severity Levels

| Severity | Description | Response Time |
|----------|-------------|---------------|
| `critical` | Service down or data loss | Immediate |
| `warning` | Degraded performance | 1 hour |
| `info` | Informational | Best effort |

### Alert Channels

Configure alert destinations in Prometheus Alertmanager:

```yaml
route:
  group_by: ['alertname', 'severity']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'team-notifications'

receivers:
  - name: 'team-notifications'
    email_configs:
      - to: 'ops@example.com'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/...'
        channel: '#alerts'
    pagerduty_configs:
      - service_key: 'your-key'
```

## Best Practices

### 1. Metric Naming

Follow Prometheus naming conventions:
- Use base units (seconds, bytes, not milliseconds or kilobytes)
- Suffix with unit (`_seconds`, `_bytes`, `_total`)
- Use labels for dimensions

### 2. Cardinality

Avoid high-cardinality labels:
- ❌ Don't use user IDs as labels
- ❌ Don't use timestamps as labels
- ✅ Use aggregated categories
- ✅ Limit label values to <100

### 3. Recording Rules

Pre-compute expensive queries:

```yaml
groups:
  - name: recording_rules
    interval: 30s
    rules:
      - record: job:cache_hit_rate:5m
        expr: |
          sum(rate(cache_hits_total[5m])) /
          (sum(rate(cache_hits_total[5m])) + sum(rate(cache_misses_total[5m])))

      - record: job:error_rate:5m
        expr: |
          sum(rate(config_errors_total[5m])) /
          sum(rate(config_operations_total[5m]))
```

### 4. Dashboard Organization

- **Start with overview**, drill down to details
- **Use consistent time ranges** across panels
- **Add descriptions** to panels
- **Use templating** for dynamic dashboards

### 5. Alert Fatigue

Prevent alert fatigue:
- Set appropriate thresholds
- Use `for` duration to avoid flapping
- Group related alerts
- Include actionable information

### 6. Retention

Configure appropriate retention:

```yaml
# Prometheus
storage:
  tsdb:
    retention.time: 15d
    retention.size: 50GB

# For long-term storage, use Thanos or Cortex
```

## Troubleshooting

### Metrics Not Appearing

1. **Check endpoint**:
   ```bash
   curl http://localhost:9090/metrics
   ```

2. **Verify Prometheus config**:
   ```bash
   promtool check config prometheus.yml
   ```

3. **Check Prometheus targets**:
   Navigate to Prometheus UI → Status → Targets

### High Cardinality

Check metric cardinality:
```promql
count by (__name__) ({__name__=~".+"})
```

Identify problematic metrics:
```promql
topk(10, count by (__name__, job)({__name__=~".+"}))
```

### Dashboard Not Loading

1. Check Prometheus data source connectivity
2. Verify metric names in queries
3. Check time range selector
4. Review browser console for errors

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [PromQL Guide](https://prometheus.io/docs/prometheus/latest/querying/basics/)
