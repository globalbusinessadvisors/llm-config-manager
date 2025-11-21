# Monitoring Setup Guide

This directory contains all the monitoring and observability configurations for the LLM Config Manager platform.

## Directory Structure

```
monitoring/
├── prometheus/
│   ├── prometheus.yml      # Prometheus server configuration
│   └── alerts.yml          # Alert rules
├── grafana/
│   └── dashboards/
│       └── overview.json   # Main overview dashboard
└── README.md               # This file
```

## Quick Start

### 1. Start Prometheus

```bash
# Using Docker
docker run -d \
  --name prometheus \
  -p 9090:9090 \
  -v $(pwd)/monitoring/prometheus:/etc/prometheus \
  prom/prometheus:latest \
  --config.file=/etc/prometheus/prometheus.yml

# Or using binary
prometheus --config.file=monitoring/prometheus/prometheus.yml
```

### 2. Start Grafana

```bash
# Using Docker
docker run -d \
  --name grafana \
  -p 3000:3000 \
  grafana/grafana:latest

# Access Grafana at http://localhost:3000
# Default credentials: admin/admin
```

### 3. Configure Grafana

1. **Add Prometheus Data Source**:
   - Navigate to Configuration → Data Sources
   - Click "Add data source"
   - Select "Prometheus"
   - URL: `http://prometheus:9090` (or `http://localhost:9090`)
   - Click "Save & Test"

2. **Import Dashboard**:
   - Navigate to Dashboards → Import
   - Upload `monitoring/grafana/dashboards/overview.json`
   - Select Prometheus data source
   - Click "Import"

### 4. Start Alertmanager (Optional)

```bash
# Create alertmanager config
cat > alertmanager.yml <<EOF
global:
  resolve_timeout: 5m

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
        from: 'alertmanager@example.com'
        smarthost: 'smtp.example.com:587'
        auth_username: 'alertmanager'
        auth_password: 'password'
EOF

# Start Alertmanager
docker run -d \
  --name alertmanager \
  -p 9093:9093 \
  -v $(pwd)/alertmanager.yml:/etc/alertmanager/alertmanager.yml \
  prom/alertmanager:latest
```

## Docker Compose Setup

For a complete monitoring stack:

```yaml
version: '3.8'

services:
  llm-config-manager:
    build: .
    ports:
      - "8080:8080"
      - "9090:9090"  # Metrics port
    environment:
      - METRICS_ENABLED=true
      - METRICS_PORT=9090

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus:/etc/prometheus
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=15d'

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana
      - ./monitoring/grafana/dashboards:/etc/grafana/provisioning/dashboards
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false

  alertmanager:
    image: prom/alertmanager:latest
    ports:
      - "9093:9093"
    volumes:
      - ./monitoring/prometheus/alertmanager.yml:/etc/alertmanager/alertmanager.yml
      - alertmanager-data:/alertmanager

  node-exporter:
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'

volumes:
  prometheus-data:
  grafana-data:
  alertmanager-data:
```

Start the stack:
```bash
docker-compose up -d
```

## Kubernetes Deployment

### Using Helm

```bash
# Add Prometheus community charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus stack
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values monitoring/kubernetes/values.yaml

# Install LLM Config Manager
kubectl apply -f deployment/kubernetes/llm-config-manager.yaml
```

### Manual Deployment

```yaml
# Service Monitor for Prometheus Operator
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: llm-config-manager
  namespace: default
spec:
  selector:
    matchLabels:
      app: llm-config-manager
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
```

## Metrics Verification

### Check Metrics Endpoint

```bash
# Verify metrics are being exposed
curl http://localhost:9090/metrics

# Should see output like:
# config_operations_total{operation="set",environment="production"} 123
# cache_hits_total{tier="l1"} 456
# ...
```

### Check Prometheus Targets

1. Open Prometheus UI: `http://localhost:9090`
2. Navigate to Status → Targets
3. Verify `llm-config-manager` target is UP

### Query Metrics

In Prometheus UI, try these queries:

```promql
# Request rate
rate(http_requests_total[5m])

# Error rate
sum(rate(config_errors_total[5m])) / sum(rate(config_operations_total[5m]))

# Cache hit rate
sum(rate(cache_hits_total[5m])) /
  (sum(rate(cache_hits_total[5m])) + sum(rate(cache_misses_total[5m])))

# P95 latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

## Alert Verification

### Test Alerts

```bash
# Trigger a test alert
amtool alert add test \
  severity=warning \
  alertname=TestAlert \
  instance=localhost:9090

# View active alerts
amtool alert query

# Silence an alert
amtool silence add alertname=TestAlert
```

### View Alerts in Grafana

1. Open Grafana UI: `http://localhost:3000`
2. Navigate to Alerting → Alert Rules
3. View active and fired alerts

## Dashboard Customization

### Create Custom Dashboard

1. Open Grafana
2. Click "+" → Dashboard
3. Add Panel
4. Select metric from Prometheus
5. Customize visualization
6. Save dashboard

### Export Dashboard

```bash
# Export dashboard JSON
curl -X GET \
  http://admin:admin@localhost:3000/api/dashboards/uid/<dashboard-uid> \
  > custom-dashboard.json
```

## Troubleshooting

### Metrics Not Appearing

1. **Check application is running**:
   ```bash
   curl http://localhost:8080/health
   ```

2. **Check metrics endpoint**:
   ```bash
   curl http://localhost:9090/metrics
   ```

3. **Check Prometheus logs**:
   ```bash
   docker logs prometheus
   ```

4. **Verify Prometheus config**:
   ```bash
   promtool check config monitoring/prometheus/prometheus.yml
   ```

### Grafana Dashboard Issues

1. **Check data source connection**:
   - Grafana → Configuration → Data Sources
   - Click "Test" on Prometheus data source

2. **Check query syntax**:
   - Use Prometheus UI to test queries first

3. **Check time range**:
   - Ensure dashboard time range includes data

### Alerts Not Firing

1. **Check alert rules**:
   ```bash
   promtool check rules monitoring/prometheus/alerts.yml
   ```

2. **View pending alerts**:
   - Prometheus → Alerts
   - Check if alerts are in pending state

3. **Check Alertmanager**:
   ```bash
   curl http://localhost:9093/api/v2/alerts
   ```

## Production Recommendations

### Prometheus

- **Storage**: Use persistent volumes for data retention
- **Retention**: Configure based on needs (default 15 days)
- **High Availability**: Run multiple Prometheus instances
- **Federation**: Use Thanos or Cortex for long-term storage

### Grafana

- **Authentication**: Enable OAuth or LDAP
- **Dashboards**: Version control dashboard JSON
- **Plugins**: Install useful plugins (worldmap, piechart)
- **Backups**: Regular dashboard exports

### Alertmanager

- **Grouping**: Group related alerts to reduce noise
- **Routing**: Route to appropriate teams
- **Inhibition**: Suppress alerts during maintenance
- **Testing**: Regular alert testing and verification

## Monitoring Best Practices

1. **Start Simple**: Begin with overview dashboard
2. **Iterate**: Add panels as needs evolve
3. **Alert Wisely**: Avoid alert fatigue
4. **Document**: Add panel descriptions
5. **Review**: Regular dashboard and alert reviews
6. **Capacity Planning**: Monitor trends for planning

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Alertmanager Guide](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [PromQL Tutorial](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [LLM Config Manager Monitoring Docs](../docs/MONITORING.md)

## Support

For issues or questions:
- Check the [troubleshooting guide](../docs/MONITORING.md#troubleshooting)
- Review [GitHub issues](https://github.com/llm-devops/llm-config-manager/issues)
- Contact the operations team
