# Disaster Recovery Guide

**Version**: 1.0.0
**Last Updated**: 2025-11-21
**Purpose**: Procedures for recovering from catastrophic failures

## Table of Contents

1. [Overview](#overview)
2. [Disaster Scenarios](#disaster-scenarios)
3. [Recovery Time Objectives](#recovery-time-objectives)
4. [Disaster Recovery Procedures](#disaster-recovery-procedures)
5. [Testing and Validation](#testing-and-validation)
6. [Business Continuity](#business-continuity)

## Overview

This guide provides procedures for recovering from catastrophic failures that impact the LLM Config Manager service. Use this guide when standard troubleshooting and incident response procedures are insufficient.

### What is a Disaster?

A disaster is a catastrophic event that results in:
- Complete loss of primary infrastructure
- Irreversible data corruption
- Multiple simultaneous component failures
- Extended service outage (>4 hours)
- Security compromise requiring full rebuild

### Related Documents

- Backup & Restore: `/docs/operations/backup-restore.md`
- Incident Response: `/docs/operations/incident-response.md`
- Deployment Guide: `/docs/DEPLOYMENT.md`
- Security Guide: `/docs/SECURITY.md`

## Disaster Scenarios

### Scenario 1: Complete Data Center Failure

**Description**: Primary data center becomes unavailable (fire, flood, power outage, network failure)

**Impact**: Total service outage

**Recovery Strategy**: Failover to backup region/data center

**RTO**: 4 hours
**RPO**: 1 hour (last hourly backup)

### Scenario 2: Complete Data Loss/Corruption

**Description**: Storage system failure, ransomware, accidental deletion

**Impact**: All configuration data lost or corrupted

**Recovery Strategy**: Restore from backups

**RTO**: 2 hours
**RPO**: 24 hours (last daily backup)

### Scenario 3: Security Compromise

**Description**: Unauthorized access, malware, encryption keys compromised

**Impact**: System integrity compromised

**Recovery Strategy**: Clean rebuild with backup data

**RTO**: 8 hours
**RPO**: 24 hours

### Scenario 4: Critical Infrastructure Loss

**Description**: Kubernetes cluster failure, cloud provider outage, database cluster failure

**Impact**: Service unavailable, no failover possible

**Recovery Strategy**: Rebuild infrastructure, restore data

**RTO**: 6 hours
**RPO**: 1 hour

### Scenario 5: Multiple Component Failures

**Description**: Database, cache, and application all fail simultaneously

**Impact**: Complete system failure

**Recovery Strategy**: Systematic component restoration

**RTO**: 4 hours
**RPO**: 1 hour

## Recovery Time Objectives

### Definitions

- **RTO (Recovery Time Objective)**: Maximum acceptable downtime
- **RPO (Recovery Point Objective)**: Maximum acceptable data loss

### Service Level Objectives

| Priority | Component | RTO | RPO | Backup Frequency |
|----------|-----------|-----|-----|------------------|
| Critical | Configuration Data | 2 hours | 1 hour | Hourly |
| Critical | Application Service | 4 hours | N/A | N/A |
| High | Audit Logs | 8 hours | 24 hours | Daily |
| High | Metrics History | 24 hours | 7 days | Weekly |
| Medium | Cache Data | N/A | N/A | None (ephemeral) |

### Infrastructure Requirements

To meet RTO/RPO:

**Backups**:
- Hourly incremental backups
- Daily full backups
- Weekly off-site backups
- 90-day retention period

**Redundancy**:
- Multi-AZ deployment (production)
- Hot standby database replica
- Distributed storage (S3/equivalent)
- Geographic redundancy (optional)

**Monitoring**:
- Backup success verification
- DR system health checks
- Regular DR drill alerts

## Disaster Recovery Procedures

### Pre-Disaster Preparation Checklist

**Critical Items** (verify quarterly):

- [ ] Backups running and verified
- [ ] Backup restoration tested
- [ ] DR infrastructure provisioned
- [ ] Access credentials documented and secured
- [ ] Contact information current
- [ ] Runbooks updated
- [ ] Team trained on procedures
- [ ] Off-site backup storage configured
- [ ] DR testing completed successfully

### Disaster Declaration

**Authority**: Incident Commander or VP Engineering

**Criteria**:
- Service outage >2 hours with no path to recovery
- Complete data loss requiring restore
- Security compromise requiring rebuild
- Multiple simultaneous critical failures

**Actions Upon Declaration**:
1. Assemble disaster recovery team
2. Activate incident bridge/war room
3. Notify stakeholders (management, customers)
4. Execute appropriate recovery procedure
5. Document all actions taken

### Procedure 1: Complete Service Recovery

**Use Case**: Total service outage, all components down

**Prerequisites**:
- Recent backup available
- DR infrastructure accessible
- Team assembled

**Steps**:

#### Phase 1: Assessment (15 minutes)

```bash
# 1. Verify disaster scope
# Check all systems
curl -f http://primary.example.com/health || echo "PRIMARY DOWN"
curl -f http://secondary.example.com/health || echo "SECONDARY DOWN"

# 2. Identify last known good state
# Check backup availability
aws s3 ls s3://llm-config-backups/ --recursive | tail -20

# 3. Verify DR resources available
kubectl cluster-info --context dr-cluster
# or check DR cloud account access

# 4. Document current state
# Take screenshots, save logs, record observations
```

#### Phase 2: Infrastructure Setup (1-2 hours)

**Option A: Kubernetes Cluster**

```bash
# 1. Verify DR cluster ready
kubectl get nodes --context dr-cluster

# 2. Create namespace
kubectl create namespace llm-config --context dr-cluster

# 3. Apply configurations
kubectl apply -f deployment/kubernetes/ --context dr-cluster -n llm-config

# 4. Create secrets (from secure storage)
kubectl create secret generic llm-config-manager-secrets \
  --from-literal=ENCRYPTION_KEY="$(aws secretsmanager get-secret-value --secret-id llm-config-key --query SecretString --output text)" \
  --from-literal=DB_PASSWORD="$(aws secretsmanager get-secret-value --secret-id llm-config-db-password --query SecretString --output text)" \
  --context dr-cluster -n llm-config

# 5. Verify deployments
kubectl get pods -n llm-config --context dr-cluster --watch
```

**Option B: Docker Deployment**

```bash
# 1. Provision new servers
# Use infrastructure-as-code (Terraform)
cd terraform/dr
terraform apply -auto-approve

# 2. Install Docker and dependencies
ansible-playbook -i dr-hosts playbooks/install-docker.yml

# 3. Deploy application
scp docker-compose.yml dr-server:/opt/llm-config/
scp .env.production dr-server:/opt/llm-config/.env
ssh dr-server "cd /opt/llm-config && docker-compose up -d"

# 4. Verify service
curl http://dr-server:8080/health
```

#### Phase 3: Data Recovery (30-60 minutes)

**See detailed procedures in `/docs/operations/backup-restore.md`**

```bash
# 1. Identify backup to restore
BACKUP_DATE=$(date -d "yesterday" +%Y%m%d)
BACKUP_FILE="backup-${BACKUP_DATE}.tar.gz"

# 2. Download backup
aws s3 cp s3://llm-config-backups/${BACKUP_FILE} /tmp/

# 3. Stop application
kubectl scale deployment llm-config-manager --replicas=0 --context dr-cluster -n llm-config

# 4. Restore data
kubectl exec -n llm-config postgres-0 --context dr-cluster -- \
  pg_restore -U llm_config_user -d llm_config -v -Fc /backups/${BACKUP_FILE}

# 5. Verify data integrity
kubectl exec -n llm-config postgres-0 --context dr-cluster -- \
  psql -U llm_config_user -d llm_config -c "SELECT COUNT(*) FROM configs;"

# 6. Start application
kubectl scale deployment llm-config-manager --replicas=3 --context dr-cluster -n llm-config
```

#### Phase 4: Validation (30 minutes)

```bash
# 1. Health checks
curl http://dr-endpoint/health | jq '.'

# 2. Functional tests
# Test read
curl http://dr-endpoint/api/v1/configs/app/test?env=production

# Test write
curl -X POST http://dr-endpoint/api/v1/configs/app/dr-test \
  -H "Content-Type: application/json" \
  -d '{"value": "test", "env": "production", "user": "ops"}'

# Verify write
curl http://dr-endpoint/api/v1/configs/app/dr-test?env=production

# 3. Load test (light)
ab -n 100 -c 10 http://dr-endpoint/health

# 4. Monitor for stability
watch -n 10 'curl -s http://dr-endpoint/health | jq ".status"'
```

#### Phase 5: Traffic Cutover (15-30 minutes)

```bash
# 1. Update DNS (if using DNS failover)
# Change A record to point to DR endpoint
aws route53 change-resource-record-sets --hosted-zone-id ZXXXXX \
  --change-batch file://dns-update.json

# 2. Or update load balancer
# Point load balancer to DR servers

# 3. Verify traffic flowing
curl http://production-endpoint/health
# Should now hit DR system

# 4. Monitor metrics
# Watch for error spike, latency issues

# 5. Notify stakeholders
# Service restored, running on DR infrastructure
```

### Procedure 2: Database Recovery

**Use Case**: Database corrupted or lost, application still running

**Steps**:

```bash
# 1. Stop all writes
kubectl scale deployment llm-config-manager --replicas=0 -n llm-config

# 2. Backup current state (even if corrupt)
kubectl exec -n llm-config postgres-0 -- pg_dumpall -U postgres > current-state-$(date +%Y%m%d-%H%M%S).sql

# 3. Drop and recreate database
kubectl exec -n llm-config postgres-0 -- psql -U postgres -c "DROP DATABASE llm_config;"
kubectl exec -n llm-config postgres-0 -- psql -U postgres -c "CREATE DATABASE llm_config OWNER llm_config_user;"

# 4. Restore from backup
kubectl cp backup-latest.dump llm-config/postgres-0:/tmp/
kubectl exec -n llm-config postgres-0 -- pg_restore -U llm_config_user -d llm_config -v /tmp/backup-latest.dump

# 5. Verify restoration
kubectl exec -n llm-config postgres-0 -- psql -U llm_config_user -d llm_config -c "
SELECT
  (SELECT COUNT(*) FROM configs) as config_count,
  (SELECT COUNT(DISTINCT namespace) FROM configs) as namespace_count,
  (SELECT MAX(created_at) FROM configs) as latest_config;
"

# 6. Start application
kubectl scale deployment llm-config-manager --replicas=3 -n llm-config

# 7. Verify operations
curl http://localhost:8080/health
curl http://localhost:8080/api/v1/configs/app/test?env=production
```

### Procedure 3: Security Compromise Recovery

**Use Case**: System compromised, requires clean rebuild

**Critical**: Assume all secrets compromised

**Steps**:

#### Phase 1: Containment (Immediate)

```bash
# 1. Isolate system
kubectl delete namespace llm-config
# or
docker-compose down
iptables -A INPUT -j DROP  # On affected servers

# 2. Preserve evidence
tar -czf evidence-$(date +%Y%m%d-%H%M%S).tar.gz /var/log/llm-config /var/lib/llm-config

# 3. Notify security team
# Email: security@example.com
# Include: Timeline, affected systems, evidence collected

# 4. Rotate all credentials
# See security/scripts/rotate-all-secrets.sh
```

#### Phase 2: Investigation (1-2 hours)

```bash
# 1. Analyze logs for intrusion
grep -r "UNAUTHORIZED\|SUSPICIOUS\|FAILED_AUTH" /var/log/llm-config/

# 2. Check audit trail
curl http://backup-endpoint/api/v1/audit?since=7d > audit-review.json

# 3. Identify compromised data
# What configurations were accessed?
# Were secrets exposed?

# 4. Document findings
# Create security incident report
```

#### Phase 3: Clean Rebuild (2-4 hours)

```bash
# 1. Build new environment
# Use fresh infrastructure
terraform workspace new secure-rebuild
terraform apply

# 2. Generate new secrets
export NEW_ENCRYPTION_KEY=$(openssl rand -base64 32)
export NEW_DB_PASSWORD=$(openssl rand -base64 32)
export NEW_REDIS_PASSWORD=$(openssl rand -base64 32)

# 3. Deploy with new secrets
kubectl create secret generic llm-config-manager-secrets \
  --from-literal=ENCRYPTION_KEY="$NEW_ENCRYPTION_KEY" \
  --from-literal=DB_PASSWORD="$NEW_DB_PASSWORD" \
  --from-literal=REDIS_PASSWORD="$NEW_REDIS_PASSWORD" \
  -n llm-config

# 4. Restore data from pre-compromise backup
# Use backup from before compromise occurred
SAFE_BACKUP=$(date -d "7 days ago" +%Y%m%d)
aws s3 cp s3://llm-config-backups/backup-${SAFE_BACKUP}.tar.gz /tmp/

# 5. Re-encrypt all secrets with new key
# Application will handle re-encryption on startup

# 6. Deploy application
kubectl apply -f deployment/kubernetes/ -n llm-config

# 7. Verify security
./security/scanners/full-security-scan.sh

# 8. Cutover to new system
# Update DNS/load balancer
```

#### Phase 4: Preventive Measures

```bash
# 1. Apply security patches
cargo update
cargo build --release

# 2. Harden configuration
# Enable all security features
# Tighten access controls
# Update firewall rules

# 3. Enhanced monitoring
# Add security alerts
# Increase audit logging

# 4. Document lessons learned
# Update security incident response
```

### Procedure 4: Region/Data Center Failover

**Use Case**: Primary data center unavailable

**Prerequisites**:
- Multi-region deployment configured
- Data replication in place
- DNS failover ready

**Steps**:

```bash
# 1. Verify secondary region healthy
curl http://secondary-region.example.com/health

# 2. Check data replication lag
# Should be <5 minutes
kubectl exec -n llm-config postgres-replica-0 -- \
  psql -U llm_config_user -d llm_config -c "SELECT now() - pg_last_xact_replay_timestamp() AS replication_lag;"

# 3. Promote replica to primary
kubectl exec -n llm-config postgres-replica-0 -- \
  /usr/local/bin/pg-promote

# 4. Scale up application in secondary region
kubectl scale deployment llm-config-manager --replicas=3 --context secondary-region -n llm-config

# 5. Update DNS to point to secondary region
aws route53 change-resource-record-sets --hosted-zone-id ZXXXXX \
  --change-batch file://failover-dns.json

# 6. Verify traffic flowing to secondary
curl http://production-endpoint/health
# Check response headers for region

# 7. Monitor for issues
# Watch error rates, latency

# 8. Notify stakeholders
# Service running on secondary region
```

## Testing and Validation

### DR Drill Schedule

**Frequency**: Quarterly (every 3 months)

**Types of Drills**:

1. **Table-Top Exercise** (2 hours, quarterly)
   - Walk through procedures
   - Identify gaps
   - No actual recovery

2. **Partial Recovery** (4 hours, semi-annually)
   - Restore to test environment
   - Verify procedures work
   - No production impact

3. **Full Recovery** (8 hours, annually)
   - Complete DR exercise
   - Include traffic cutover
   - During maintenance window

### DR Drill Procedure

**Preparation** (1 week before):
```bash
# 1. Schedule maintenance window
# Notify stakeholders

# 2. Verify backups current
aws s3 ls s3://llm-config-backups/ --recursive | tail -10

# 3. Provision DR environment
terraform apply -target=dr-infrastructure

# 4. Brief team on drill
# Review procedures
# Assign roles
```

**Execution** (4-8 hours):
```bash
# 1. Start drill timer
echo "DR Drill started: $(date)"

# 2. Execute recovery procedure
# Follow disaster recovery procedures above

# 3. Document time for each phase
# Track against RTO/RPO

# 4. Validate recovered system
# Run test suite
# Check data integrity
# Verify functionality

# 5. Record lessons learned
# What worked?
# What didn't?
# What can be improved?
```

**Post-Drill** (1 week after):
```bash
# 1. Cleanup DR resources
terraform destroy -target=dr-infrastructure

# 2. Update procedures based on findings
# Fix gaps
# Clarify unclear steps

# 3. Update team training
# Address knowledge gaps

# 4. Schedule next drill
```

### Validation Checklist

After any disaster recovery:

**Technical Validation**:
- [ ] All services running and healthy
- [ ] Health checks passing
- [ ] All endpoints responding
- [ ] Data integrity verified
- [ ] Backups resuming
- [ ] Monitoring active
- [ ] Alerts configured
- [ ] Logs collecting

**Functional Validation**:
- [ ] Can create configurations
- [ ] Can read configurations
- [ ] Can update configurations
- [ ] Can delete configurations
- [ ] Can roll back versions
- [ ] Authentication working
- [ ] Authorization working
- [ ] Audit logging working

**Performance Validation**:
- [ ] Response times normal (<100ms P95)
- [ ] Error rate normal (<1%)
- [ ] Cache hit rate normal (>80%)
- [ ] Throughput normal
- [ ] Resource usage normal

**Security Validation**:
- [ ] All secrets rotated (if security incident)
- [ ] Access controls verified
- [ ] TLS/encryption active
- [ ] Security scans passing
- [ ] Audit logs intact

## Business Continuity

### Service Degradation Levels

**Level 0: Full Service**
- All features available
- Performance normal
- No user impact

**Level 1: Degraded Performance**
- All features available
- Slower response times
- Some user impact
- **Actions**: Monitor, investigate, plan fixes

**Level 2: Reduced Functionality**
- Core features available
- Non-critical features disabled
- Moderate user impact
- **Actions**: Communicate, implement fixes, escalate if prolonged

**Level 3: Read-Only Mode**
- Read operations only
- Write operations disabled
- Significant user impact
- **Actions**: Full team engagement, emergency procedures

**Level 4: Service Unavailable**
- All operations unavailable
- Complete outage
- Disaster recovery activated
- **Actions**: Execute DR procedures, stakeholder communication

### Communication During DR

**Stakeholders**:
- Executive leadership
- Customer success team
- Major customers
- All users (via status page)

**Communication Frequency**:
- Initial: Immediate (within 15 minutes)
- Updates: Every 30 minutes
- Resolution: Immediate
- Post-Mortem: Within 5 days

**Status Page Updates**:
```
Status: Major Outage
Impact: All operations unavailable
Started: [Time]
Last Update: [Time]

We are experiencing a major service disruption and have activated
our disaster recovery procedures. Our team is working to restore
service. Next update in 30 minutes.

Updates:
[Time] - Disaster recovery initiated
[Time] - Infrastructure provisioned
[Time] - Data restore in progress
[Time] - Service validation underway
```

### Critical Contacts

**Internal**:
- Incident Commander: ic@example.com, +1-555-0101
- On-Call Engineer: oncall@example.com, PagerDuty
- VP Engineering: vp-eng@example.com, +1-555-0102
- CTO: cto@example.com, +1-555-0103

**External**:
- Cloud Provider Support: [Provider] Platinum Support
- Database Vendor Support: [Vendor] Enterprise Support
- Security Consultant: security-consultant@example.com

**Emergency Services**:
- Data Center Provider: +1-555-1000
- Network Provider: +1-555-2000
- Physical Security: +1-555-3000

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-21
**Next Review**: 2026-02-21
**Next DR Drill**: 2026-03-01
**Owner**: Operations Team
