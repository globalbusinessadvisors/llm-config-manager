# Kubernetes Deployment Guide

Complete Kubernetes deployment manifests for LLM Config Manager platform.

## Prerequisites

- Kubernetes cluster (1.25+)
- kubectl configured
- Helm 3.x (for monitoring stack)
- cert-manager (for TLS certificates)
- NGINX Ingress Controller
- Prometheus Operator (optional, for ServiceMonitor)

## Quick Start

### 1. Create Namespace and Deploy All Resources

```bash
# Apply all manifests
kubectl apply -f namespace.yaml
kubectl apply -f secrets.yaml
kubectl apply -f configmap.yaml
kubectl apply -f pvc.yaml
kubectl apply -f rbac.yaml
kubectl apply -f postgres.yaml
kubectl apply -f redis.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
kubectl apply -f hpa.yaml
kubectl apply -f pdb.yaml
kubectl apply -f networkpolicy.yaml
kubectl apply -f servicemonitor.yaml

# Or use kustomize
kubectl apply -k .
```

### 2. Update Secrets

**IMPORTANT**: Before deploying, update the secrets in `secrets.yaml`:

```bash
# Generate encryption key
openssl rand -base64 32

# Generate strong passwords
openssl rand -base64 24

# Edit secrets.yaml and replace all CHANGE_ME values
vim secrets.yaml

# Apply secrets
kubectl apply -f secrets.yaml
```

### 3. Verify Deployment

```bash
# Check pod status
kubectl get pods -n llm-config

# Check services
kubectl get svc -n llm-config

# Check ingress
kubectl get ingress -n llm-config

# View logs
kubectl logs -n llm-config -l app=llm-config-manager --tail=100 -f
```

## Directory Structure

```
deployment/kubernetes/
├── namespace.yaml          # Namespace definition
├── configmap.yaml          # Configuration data
├── secrets.yaml            # Sensitive configuration (DO NOT COMMIT REAL VALUES)
├── pvc.yaml                # Persistent volume claims
├── rbac.yaml               # Service accounts and RBAC
├── deployment.yaml         # Main application deployment
├── service.yaml            # Kubernetes services
├── ingress.yaml            # Ingress for external access
├── hpa.yaml                # Horizontal pod autoscaler
├── pdb.yaml                # Pod disruption budget
├── networkpolicy.yaml      # Network policies
├── servicemonitor.yaml     # Prometheus ServiceMonitor
├── postgres.yaml           # PostgreSQL StatefulSet
├── redis.yaml              # Redis StatefulSet
├── kustomization.yaml      # Kustomize configuration
└── README.md               # This file
```

## Components

### Core Application

- **Deployment**: 3 replicas with rolling updates
- **Service**: ClusterIP, LoadBalancer, and Headless services
- **Ingress**: TLS-enabled with NGINX
- **HPA**: Auto-scaling based on CPU, memory, and custom metrics
- **PDB**: Ensures minimum availability during updates

### Dependencies

- **PostgreSQL**: StatefulSet with persistent storage
- **Redis**: StatefulSet for distributed caching
- **Prometheus**: Metrics collection (optional)
- **Grafana**: Visualization (optional)

### Security

- **RBAC**: Least-privilege service accounts
- **Network Policies**: Restrict pod-to-pod communication
- **Secrets**: Encrypted sensitive data
- **Security Context**: Non-root user, read-only filesystem
- **Pod Security Standards**: Baseline/Restricted

## Configuration

### Environment-Specific Configurations

Create overlays for different environments:

```bash
deployment/kubernetes/
├── base/              # Base configurations
├── overlays/
│   ├── development/   # Dev-specific configs
│   ├── staging/       # Staging-specific configs
│   └── production/    # Production-specific configs
```

### Using Kustomize

```bash
# Development
kubectl apply -k overlays/development/

# Staging
kubectl apply -k overlays/staging/

# Production
kubectl apply -k overlays/production/
```

## Scaling

### Manual Scaling

```bash
# Scale deployment
kubectl scale deployment llm-config-manager -n llm-config --replicas=5

# Scale PostgreSQL (not recommended - use operator)
kubectl scale statefulset postgres -n llm-config --replicas=3
```

### Auto-Scaling

HPA is configured in `hpa.yaml`:

- Min replicas: 3
- Max replicas: 10
- Target CPU: 70%
- Target Memory: 80%
- Custom metric: 1000 RPS per pod

## Monitoring

### Prometheus Integration

If using Prometheus Operator:

```bash
# Apply ServiceMonitor
kubectl apply -f servicemonitor.yaml

# Verify metrics are being scraped
kubectl port-forward -n llm-config svc/prometheus 9090:9090
# Open http://localhost:9090/targets
```

### Grafana Dashboards

Import the dashboard from `monitoring/grafana/dashboards/overview.json`

### Health Checks

```bash
# Check application health
kubectl exec -n llm-config deploy/llm-config-manager -- \
  curl -f http://localhost:8080/health

# Port-forward and check locally
kubectl port-forward -n llm-config svc/llm-config-manager 8080:8080
curl http://localhost:8080/health
```

## Storage

### Persistent Volumes

The deployment uses PersistentVolumeClaims:

- `llm-config-data`: 50Gi - Application data
- `llm-config-cache`: 20Gi - Cache storage
- `llm-config-backups`: 100Gi - Backup storage
- `llm-config-logs`: 10Gi - Log files
- `postgres-data`: 50Gi - Database storage
- `redis-data`: 10Gi - Redis persistence

### Storage Classes

Update `storageClassName` in `pvc.yaml` based on your cluster:

- AWS: `gp3`, `io2`
- GCP: `standard`, `ssd`
- Azure: `managed-premium`
- On-prem: `local-path`, `nfs`

## Networking

### Ingress

Update `ingress.yaml` with your domain:

```yaml
hosts:
  - api.llm-config.example.com  # Replace with your domain
```

### TLS Certificates

Using cert-manager:

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ClusterIssuer
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com  # Replace with your email
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
EOF
```

### Network Policies

Network policies are configured in `networkpolicy.yaml`:

- Default deny all ingress
- Allow ingress from NGINX Ingress
- Allow ingress from Prometheus
- Allow egress to PostgreSQL and Redis
- Allow egress for DNS resolution

## Backup and Restore

### Database Backup

```bash
# Create backup job
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: llm-config
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: backup
              image: postgres:16-alpine
              command:
                - /bin/sh
                - -c
                - pg_dump -U \$POSTGRES_USER -d \$POSTGRES_DB | gzip > /backups/backup-\$(date +%Y%m%d-%H%M%S).sql.gz
              env:
                - name: POSTGRES_USER
                  valueFrom:
                    secretKeyRef:
                      name: postgres-secrets
                      key: POSTGRES_USER
                - name: POSTGRES_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: postgres-secrets
                      key: POSTGRES_PASSWORD
                - name: POSTGRES_DB
                  valueFrom:
                    secretKeyRef:
                      name: postgres-secrets
                      key: POSTGRES_DB
              volumeMounts:
                - name: backups
                  mountPath: /backups
          volumes:
            - name: backups
              persistentVolumeClaim:
                claimName: llm-config-backups
          restartPolicy: OnFailure
EOF
```

### Restore from Backup

```bash
# Copy backup to pod
kubectl cp backup.sql.gz llm-config/postgres-0:/tmp/backup.sql.gz

# Restore
kubectl exec -n llm-config postgres-0 -- \
  gunzip -c /tmp/backup.sql.gz | psql -U llm_config_user -d llm_config
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod events
kubectl describe pod -n llm-config <pod-name>

# Check logs
kubectl logs -n llm-config <pod-name> --previous

# Check resource constraints
kubectl top pods -n llm-config
```

### Database Connection Issues

```bash
# Test PostgreSQL connection
kubectl exec -n llm-config deploy/llm-config-manager -- \
  nc -zv postgres-service 5432

# Check PostgreSQL logs
kubectl logs -n llm-config postgres-0
```

### Ingress Not Working

```bash
# Check ingress status
kubectl describe ingress -n llm-config llm-config-manager

# Check NGINX Ingress logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Test from within cluster
kubectl run -n llm-config curl-test --image=curlimages/curl -it --rm -- \
  curl http://llm-config-manager:8080/health
```

### Performance Issues

```bash
# Check resource usage
kubectl top pods -n llm-config
kubectl top nodes

# Check HPA status
kubectl get hpa -n llm-config

# View metrics
kubectl port-forward -n llm-config svc/llm-config-manager 9090:9090
# Open http://localhost:9090/metrics
```

## Security Best Practices

1. **Secrets Management**:
   - Use external secret managers (Vault, AWS Secrets Manager)
   - Rotate secrets regularly
   - Never commit secrets to Git

2. **RBAC**:
   - Follow least-privilege principle
   - Regular audit of permissions
   - Use separate service accounts

3. **Network Policies**:
   - Default deny all traffic
   - Explicitly allow only required connections
   - Regular review of policies

4. **Pod Security**:
   - Run as non-root user
   - Use read-only root filesystem where possible
   - Drop all capabilities
   - Enable seccomp profiles

5. **Image Security**:
   - Use specific image tags (not `latest`)
   - Scan images for vulnerabilities
   - Use private registries
   - Sign images with cosign

## Production Checklist

- [ ] Update all secrets with strong values
- [ ] Configure proper storage classes
- [ ] Set up TLS certificates
- [ ] Configure external secret management
- [ ] Set up monitoring and alerting
- [ ] Configure log aggregation
- [ ] Set up backup automation
- [ ] Test disaster recovery procedures
- [ ] Configure autoscaling thresholds
- [ ] Review and update resource limits
- [ ] Enable network policies
- [ ] Configure pod security policies
- [ ] Set up CI/CD pipelines
- [ ] Document runbooks
- [ ] Train operations team

## Support

For issues and questions:
- GitHub Issues: https://github.com/llm-devops/llm-config-manager/issues
- Documentation: https://docs.llm-config.example.com
- Slack: #llm-config-support
