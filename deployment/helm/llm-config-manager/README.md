# LLM Config Manager Helm Chart

Enterprise-grade Helm chart for deploying LLM Config Manager on Kubernetes.

## TL;DR

```bash
helm install my-release ./llm-config-manager
```

## Prerequisites

- Kubernetes 1.25+
- Helm 3.x
- PV provisioner support in the underlying infrastructure
- (Optional) Prometheus Operator for ServiceMonitor support

## Installing the Chart

```bash
# Install with custom values
helm install my-release ./llm-config-manager -f custom-values.yaml

# Install to specific namespace
helm install my-release ./llm-config-manager --namespace llm-config --create-namespace

# Install with overrides
helm install my-release ./llm-config-manager \
  --set replicaCount=5 \
  --set resources.limits.memory=4Gi
```

## Uninstalling the Chart

```bash
helm uninstall my-release --namespace llm-config
```

## Configuration

The following table lists the configurable parameters and their default values.

### Global Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.imageRegistry` | Global Docker image registry | `""` |
| `global.imagePullSecrets` | Global Docker registry secret names | `[]` |
| `global.storageClass` | Global storage class | `"standard"` |

### Common Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `3` |
| `image.registry` | Image registry | `docker.io` |
| `image.repository` | Image repository | `llm-config-manager` |
| `image.tag` | Image tag | `"latest"` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `nameOverride` | Override chart name | `""` |
| `fullnameOverride` | Override full name | `""` |

### Service Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Service port | `8080` |
| `service.metricsPort` | Metrics port | `9090` |
| `service.sessionAffinity` | Session affinity | `ClientIP` |

### Ingress Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `true` |
| `ingress.className` | Ingress class name | `nginx` |
| `ingress.hosts[0].host` | Hostname | `api.llm-config.example.com` |
| `ingress.tls` | TLS configuration | See values.yaml |

### Resource Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources.limits.cpu` | CPU limit | `2000m` |
| `resources.limits.memory` | Memory limit | `2Gi` |
| `resources.requests.cpu` | CPU request | `500m` |
| `resources.requests.memory` | Memory request | `512Mi` |

### Autoscaling Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `autoscaling.enabled` | Enable HPA | `true` |
| `autoscaling.minReplicas` | Minimum replicas | `3` |
| `autoscaling.maxReplicas` | Maximum replicas | `10` |
| `autoscaling.targetCPUUtilizationPercentage` | Target CPU | `70` |

### Persistence Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.enabled` | Enable persistence | `true` |
| `persistence.storageClass` | Storage class | `"standard"` |
| `persistence.data.size` | Data volume size | `50Gi` |
| `persistence.cache.size` | Cache volume size | `20Gi` |
| `persistence.backups.size` | Backup volume size | `100Gi` |

### PostgreSQL Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql.enabled` | Enable PostgreSQL | `true` |
| `postgresql.auth.username` | Database user | `llm_config_user` |
| `postgresql.auth.database` | Database name | `llm_config` |
| `postgresql.primary.persistence.size` | Storage size | `50Gi` |

### Redis Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `redis.enabled` | Enable Redis | `true` |
| `redis.auth.enabled` | Enable auth | `true` |
| `redis.master.persistence.size` | Storage size | `10Gi` |

### Monitoring Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `monitoring.prometheus.enabled` | Enable Prometheus | `true` |
| `monitoring.prometheus.serviceMonitor.enabled` | Enable ServiceMonitor | `true` |
| `monitoring.grafana.enabled` | Enable Grafana | `true` |

## Examples

### Minimal Installation

```bash
helm install my-release ./llm-config-manager \
  --set postgresql.enabled=true \
  --set redis.enabled=true
```

### Production Installation

```bash
helm install my-release ./llm-config-manager \
  --set replicaCount=5 \
  --set resources.limits.memory=4Gi \
  --set persistence.data.size=100Gi \
  --set ingress.hosts[0].host=api.example.com \
  --set secrets.encryptionKey="$(openssl rand -base64 32)" \
  --set postgresql.auth.password="$(openssl rand -base64 24)" \
  --set redis.auth.password="$(openssl rand -base64 24)"
```

### With External Database

```bash
helm install my-release ./llm-config-manager \
  --set postgresql.enabled=false \
  --set externalDatabase.host=postgres.example.com \
  --set externalDatabase.port=5432 \
  --set externalDatabase.database=llm_config \
  --set externalDatabase.user=llm_config_user \
  --set externalDatabase.password=secure-password
```

### Development Mode

```bash
helm install my-release ./llm-config-manager \
  --set replicaCount=1 \
  --set autoscaling.enabled=false \
  --set persistence.enabled=false \
  --set ingress.enabled=false \
  --set resources.requests.memory=256Mi
```

## Upgrading

```bash
# Upgrade with new values
helm upgrade my-release ./llm-config-manager -f new-values.yaml

# Upgrade with specific parameter
helm upgrade my-release ./llm-config-manager --set replicaCount=7

# Rollback
helm rollback my-release 1
```

## Values Files for Different Environments

Create environment-specific values files:

**values-dev.yaml**:
```yaml
replicaCount: 1
autoscaling:
  enabled: false
persistence:
  enabled: false
resources:
  limits:
    memory: 1Gi
```

**values-staging.yaml**:
```yaml
replicaCount: 2
ingress:
  hosts:
    - host: staging.llm-config.example.com
```

**values-prod.yaml**:
```yaml
replicaCount: 5
resources:
  limits:
    memory: 4Gi
ingress:
  hosts:
    - host: api.llm-config.example.com
  tls:
    - secretName: prod-tls-cert
      hosts:
        - api.llm-config.example.com
```

Then install:
```bash
helm install my-release ./llm-config-manager -f values-prod.yaml
```

## Troubleshooting

### Pods not starting

```bash
# Check pod status
kubectl get pods -n llm-config

# View pod events
kubectl describe pod -n llm-config <pod-name>

# Check logs
kubectl logs -n llm-config <pod-name>
```

### Database connection issues

```bash
# Test PostgreSQL connection
kubectl exec -n llm-config <pod-name> -- nc -zv my-release-postgresql 5432

# Check PostgreSQL logs
kubectl logs -n llm-config my-release-postgresql-0
```

### Ingress not working

```bash
# Check ingress status
kubectl describe ingress -n llm-config my-release-llm-config-manager

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

## Dependencies

This chart has optional dependencies on:

- **bitnami/postgresql** (12.x.x)
- **bitnami/redis** (17.x.x)
- **prometheus-community/prometheus** (15.x.x)
- **grafana/grafana** (6.x.x)

Update dependencies:
```bash
helm dependency update ./llm-config-manager
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

Apache License 2.0

## Support

- GitHub Issues: https://github.com/llm-devops/llm-config-manager/issues
- Documentation: https://docs.llm-config.example.com
- Slack: #llm-config-support
