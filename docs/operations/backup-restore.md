# Backup and Restore Procedures

**Version**: 1.0.0
**Last Updated**: 2025-11-21
**Purpose**: Complete procedures for backing up and restoring LLM Config Manager data

## Table of Contents

1. [Overview](#overview)
2. [Backup Strategy](#backup-strategy)
3. [Backup Procedures](#backup-procedures)
4. [Restore Procedures](#restore-procedures)
5. [Backup Verification](#backup-verification)
6. [Backup Management](#backup-management)
7. [Automated Backup](#automated-backup)

## Overview

This guide provides comprehensive procedures for backing up and restoring all LLM Config Manager data, including configurations, secrets, audit logs, and metadata.

### What Gets Backed Up

**Critical Data** (must backup):
- Configuration entries (all environments)
- Encrypted secrets
- Version history
- User and role assignments
- Policy configurations

**Important Data** (should backup):
- Audit logs
- Metrics history
- Access logs

**Ephemeral Data** (no backup needed):
- Cache data (Redis)
- Temporary files
- Session data

### Backup Strategy

**Frequency**:
- **Hourly**: Incremental backups (last hour's changes)
- **Daily**: Full backups (complete database dump)
- **Weekly**: Off-site backups (to remote storage)

**Retention**:
- Hourly: Keep 24 hours (24 backups)
- Daily: Keep 30 days (30 backups)
- Weekly: Keep 90 days (12 backups)
- Monthly: Keep 1 year (12 backups)

**Storage Locations**:
- Primary: `/var/lib/llm-config/backups/` (local)
- Secondary: S3/Cloud Storage (off-site)
- Archive: Glacier/Cold Storage (long-term)

## Backup Procedures

### Manual Backup

#### Complete System Backup

```bash
#!/bin/bash
# Complete manual backup script

set -e

BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/var/lib/llm-config/backups"
BACKUP_FILE="backup-${BACKUP_DATE}.tar.gz"

echo "Starting complete system backup: ${BACKUP_FILE}"

# 1. Create backup directory
mkdir -p "${BACKUP_DIR}"

# 2. Backup configuration data
echo "Backing up configuration data..."
docker-compose exec -T postgres pg_dump -U llm_config_user -Fc llm_config > "${BACKUP_DIR}/database-${BACKUP_DATE}.dump"

# 3. Backup file-based storage (if using)
echo "Backing up file storage..."
tar -czf "${BACKUP_DIR}/storage-${BACKUP_DATE}.tar.gz" /var/lib/llm-config/data/

# 4. Backup audit logs
echo "Backing up audit logs..."
tar -czf "${BACKUP_DIR}/audit-${BACKUP_DATE}.tar.gz" /var/log/llm-config/audit/

# 5. Backup configuration files
echo "Backing up configuration files..."
tar -czf "${BACKUP_DIR}/config-${BACKUP_DATE}.tar.gz" /etc/llm-config/

# 6. Create manifest
echo "Creating backup manifest..."
cat > "${BACKUP_DIR}/manifest-${BACKUP_DATE}.txt" <<EOF
Backup Date: ${BACKUP_DATE}
Database: database-${BACKUP_DATE}.dump
Storage: storage-${BACKUP_DATE}.tar.gz
Audit Logs: audit-${BACKUP_DATE}.tar.gz
Configuration: config-${BACKUP_DATE}.tar.gz
EOF

# 7. Create combined archive
echo "Creating combined archive..."
cd "${BACKUP_DIR}"
tar -czf "${BACKUP_FILE}" \
  "database-${BACKUP_DATE}.dump" \
  "storage-${BACKUP_DATE}.tar.gz" \
  "audit-${BACKUP_DATE}.tar.gz" \
  "config-${BACKUP_DATE}.tar.gz" \
  "manifest-${BACKUP_DATE}.txt"

# 8. Cleanup individual files
rm -f "database-${BACKUP_DATE}.dump" \
      "storage-${BACKUP_DATE}.tar.gz" \
      "audit-${BACKUP_DATE}.tar.gz" \
      "config-${BACKUP_DATE}.tar.gz" \
      "manifest-${BACKUP_DATE}.txt"

echo "Backup completed: ${BACKUP_DIR}/${BACKUP_FILE}"
echo "Size: $(du -h ${BACKUP_DIR}/${BACKUP_FILE} | cut -f1)"

# 9. Upload to remote storage (optional)
if [ -n "${AWS_BACKUP_BUCKET}" ]; then
  echo "Uploading to S3..."
  aws s3 cp "${BACKUP_DIR}/${BACKUP_FILE}" "s3://${AWS_BACKUP_BUCKET}/backups/${BACKUP_FILE}"
  echo "Upload complete"
fi

# 10. Verify backup
echo "Verifying backup integrity..."
tar -tzf "${BACKUP_DIR}/${BACKUP_FILE}" > /dev/null
echo "Backup verification successful"
```

Save as `/usr/local/bin/llm-config-backup.sh` and make executable:
```bash
chmod +x /usr/local/bin/llm-config-backup.sh
```

Usage:
```bash
# Run backup
/usr/local/bin/llm-config-backup.sh

# With remote upload
AWS_BACKUP_BUCKET=my-backups /usr/local/bin/llm-config-backup.sh
```

#### Database-Only Backup

**PostgreSQL**:
```bash
# Full database dump
docker-compose exec postgres pg_dump -U llm_config_user -Fc llm_config > backup-db-$(date +%Y%m%d).dump

# Schema only
docker-compose exec postgres pg_dump -U llm_config_user --schema-only llm_config > schema-$(date +%Y%m%d).sql

# Data only
docker-compose exec postgres pg_dump -U llm_config_user --data-only llm_config > data-$(date +%Y%m%d).sql

# Specific table
docker-compose exec postgres pg_dump -U llm_config_user -t configs llm_config > configs-$(date +%Y%m%d).sql
```

**File-Based Storage**:
```bash
# Backup sled database
tar -czf storage-backup-$(date +%Y%m%d).tar.gz /var/lib/llm-config/data/

# Verify backup
tar -tzf storage-backup-$(date +%Y%m%d).tar.gz
```

#### Configuration-Only Backup

```bash
# Backup all configuration files
tar -czf config-backup-$(date +%Y%m%d).tar.gz \
  /etc/llm-config/ \
  /etc/default/llm-config-manager \
  docker-compose.yml \
  .env

# Backup Kubernetes configurations
kubectl get all -n llm-config -o yaml > k8s-backup-$(date +%Y%m%d).yaml
kubectl get configmap -n llm-config -o yaml > configmap-backup-$(date +%Y%m%d).yaml
kubectl get secret -n llm-config -o yaml > secret-backup-$(date +%Y%m%d).yaml
```

### Backup Types

#### Full Backup

**When**: Daily at 2 AM
**Content**: Complete database dump + all files
**Size**: ~1-10 GB (varies with data)
**Duration**: 10-30 minutes

```bash
# Docker
docker-compose exec postgres pg_dump -U llm_config_user -Fc llm_config > full-backup-$(date +%Y%m%d).dump

# Kubernetes
kubectl exec -n llm-config postgres-0 -- pg_dump -U llm_config_user -Fc llm_config > full-backup-$(date +%Y%m%d).dump
```

#### Incremental Backup

**When**: Hourly
**Content**: Changes since last backup
**Size**: ~100 MB - 1 GB
**Duration**: 1-5 minutes

```bash
# PostgreSQL WAL archiving (continuous backup)
# Configure in postgresql.conf:
# wal_level = replica
# archive_mode = on
# archive_command = 'cp %p /var/lib/llm-config/backups/wal/%f'

# Restore uses WAL replay for point-in-time recovery
```

#### Differential Backup

**When**: Every 6 hours
**Content**: Changes since last full backup
**Size**: ~500 MB - 5 GB
**Duration**: 5-15 minutes

```bash
# Use pg_basebackup for base + WAL files
docker-compose exec postgres pg_basebackup -U postgres -D /backups/differential-$(date +%Y%m%d-%H%M) -Ft -z -P
```

### Backup Verification

**Always verify backups after creation**:

```bash
#!/bin/bash
# Backup verification script

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
  echo "ERROR: Backup file not found: $BACKUP_FILE"
  exit 1
fi

echo "Verifying backup: $BACKUP_FILE"

# 1. Check file integrity
echo "Checking file integrity..."
if tar -tzf "$BACKUP_FILE" > /dev/null 2>&1; then
  echo "✓ Archive integrity OK"
else
  echo "✗ Archive integrity FAILED"
  exit 1
fi

# 2. Check file size
echo "Checking file size..."
SIZE=$(stat -f%z "$BACKUP_FILE" 2>/dev/null || stat -c%s "$BACKUP_FILE")
MIN_SIZE=1048576  # 1 MB minimum
if [ "$SIZE" -gt "$MIN_SIZE" ]; then
  echo "✓ File size OK: $(numfmt --to=iec-i --suffix=B $SIZE)"
else
  echo "✗ File size too small: $SIZE bytes"
  exit 1
fi

# 3. List contents
echo "Checking contents..."
CONTENTS=$(tar -tzf "$BACKUP_FILE" | wc -l)
if [ "$CONTENTS" -gt 0 ]; then
  echo "✓ Contains $CONTENTS files"
else
  echo "✗ Archive is empty"
  exit 1
fi

# 4. Check for required files
echo "Checking required files..."
REQUIRED_FILES=(
  "database-"
  "manifest-"
)

for required in "${REQUIRED_FILES[@]}"; do
  if tar -tzf "$BACKUP_FILE" | grep -q "$required"; then
    echo "✓ Found $required"
  else
    echo "⚠ Missing $required"
  fi
done

echo ""
echo "Backup verification complete"
```

Save as `/usr/local/bin/verify-backup.sh` and use:
```bash
/usr/local/bin/verify-backup.sh /var/lib/llm-config/backups/backup-20251121-120000.tar.gz
```

## Restore Procedures

### Pre-Restore Checklist

Before restoring:

- [ ] Identify correct backup to restore
- [ ] Verify backup integrity
- [ ] Notify stakeholders of downtime
- [ ] Stop application services
- [ ] Backup current state (even if corrupt)
- [ ] Document current system state
- [ ] Have rollback plan ready

### Complete System Restore

```bash
#!/bin/bash
# Complete system restore script

set -e

BACKUP_FILE="$1"

if [ -z "$BACKUP_FILE" ]; then
  echo "Usage: $0 <backup-file>"
  exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
  echo "ERROR: Backup file not found: $BACKUP_FILE"
  exit 1
fi

echo "RESTORE PROCEDURE"
echo "================="
echo "Backup file: $BACKUP_FILE"
echo ""
read -p "This will OVERWRITE existing data. Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "Restore cancelled"
  exit 0
fi

# 1. Stop application
echo "1. Stopping application..."
docker-compose stop llm-config-manager
# or
kubectl scale deployment llm-config-manager -n llm-config --replicas=0

# 2. Backup current state
echo "2. Backing up current state..."
SAFETY_BACKUP="safety-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -czf "/tmp/${SAFETY_BACKUP}" /var/lib/llm-config/data/ 2>/dev/null || true
echo "Safety backup: /tmp/${SAFETY_BACKUP}"

# 3. Extract backup
echo "3. Extracting backup..."
TEMP_DIR=$(mktemp -d)
tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"
echo "Extracted to: $TEMP_DIR"

# 4. Display manifest
echo "4. Backup manifest:"
cat "$TEMP_DIR"/manifest-*.txt
echo ""
read -p "Proceed with restore? (yes/no): " confirm2

if [ "$confirm2" != "yes" ]; then
  echo "Restore cancelled"
  rm -rf "$TEMP_DIR"
  exit 0
fi

# 5. Restore database
echo "5. Restoring database..."
DB_DUMP=$(ls "$TEMP_DIR"/database-*.dump)
docker-compose exec -T postgres dropdb -U postgres llm_config || true
docker-compose exec -T postgres createdb -U postgres -O llm_config_user llm_config
docker-compose exec -T postgres pg_restore -U llm_config_user -d llm_config -v < "$DB_DUMP"

# 6. Restore file storage
echo "6. Restoring file storage..."
STORAGE_BACKUP=$(ls "$TEMP_DIR"/storage-*.tar.gz)
rm -rf /var/lib/llm-config/data/*
tar -xzf "$STORAGE_BACKUP" -C /

# 7. Restore configuration
echo "7. Restoring configuration..."
CONFIG_BACKUP=$(ls "$TEMP_DIR"/config-*.tar.gz)
tar -xzf "$CONFIG_BACKUP" -C /

# 8. Restore audit logs
echo "8. Restoring audit logs..."
AUDIT_BACKUP=$(ls "$TEMP_DIR"/audit-*.tar.gz)
tar -xzf "$AUDIT_BACKUP" -C /

# 9. Cleanup
echo "9. Cleaning up..."
rm -rf "$TEMP_DIR"

# 10. Start application
echo "10. Starting application..."
docker-compose start llm-config-manager
# or
kubectl scale deployment llm-config-manager -n llm-config --replicas=3

# 11. Wait for startup
echo "11. Waiting for application startup..."
sleep 15

# 12. Verify restore
echo "12. Verifying restore..."
if curl -f http://localhost:8080/health; then
  echo "✓ Health check passed"
else
  echo "✗ Health check failed"
  echo "Check logs: docker-compose logs llm-config-manager"
  exit 1
fi

# 13. Test functionality
echo "13. Testing functionality..."
curl http://localhost:8080/api/v1/configs/test/restore-test?env=production

echo ""
echo "Restore completed successfully"
echo "Safety backup saved at: /tmp/${SAFETY_BACKUP}"
echo "Keep safety backup until restore is verified"
```

Save as `/usr/local/bin/llm-config-restore.sh` and make executable:
```bash
chmod +x /usr/local/bin/llm-config-restore.sh
```

Usage:
```bash
# Restore from backup
/usr/local/bin/llm-config-restore.sh /var/lib/llm-config/backups/backup-20251121-120000.tar.gz
```

### Database-Only Restore

**PostgreSQL**:
```bash
# 1. Stop application
docker-compose stop llm-config-manager

# 2. Drop and recreate database
docker-compose exec postgres psql -U postgres -c "DROP DATABASE llm_config;"
docker-compose exec postgres psql -U postgres -c "CREATE DATABASE llm_config OWNER llm_config_user;"

# 3. Restore from dump
docker-compose exec -T postgres pg_restore -U llm_config_user -d llm_config -v < backup-db-20251121.dump

# 4. Verify data
docker-compose exec postgres psql -U llm_config_user -d llm_config -c "
SELECT COUNT(*) FROM configs;
SELECT COUNT(DISTINCT namespace) FROM configs;
SELECT MAX(created_at) FROM configs;
"

# 5. Start application
docker-compose start llm-config-manager
```

### Point-in-Time Recovery (PITR)

**Prerequisites**: WAL archiving enabled

```bash
# 1. Identify target time
TARGET_TIME="2025-11-21 12:00:00"

# 2. Stop PostgreSQL
docker-compose stop postgres

# 3. Remove current data
rm -rf /var/lib/postgresql/data/*

# 4. Restore base backup
tar -xzf base-backup-20251121.tar.gz -C /var/lib/postgresql/data/

# 5. Create recovery configuration
cat > /var/lib/postgresql/data/recovery.conf <<EOF
restore_command = 'cp /var/lib/llm-config/backups/wal/%f %p'
recovery_target_time = '${TARGET_TIME}'
recovery_target_action = 'promote'
EOF

# 6. Start PostgreSQL (will replay WAL to target time)
docker-compose start postgres

# 7. Monitor recovery
docker-compose logs -f postgres

# 8. Verify recovery point
docker-compose exec postgres psql -U llm_config_user -d llm_config -c "
SELECT MAX(created_at) FROM configs;
"
```

### Partial Restore

**Restore specific namespace**:
```bash
# 1. Export from backup
docker-compose exec postgres pg_restore -U llm_config_user -d temp_db backup.dump

# 2. Export specific data
docker-compose exec postgres psql -U llm_config_user -d temp_db -c "
COPY (SELECT * FROM configs WHERE namespace = 'app') TO '/tmp/app-configs.csv' CSV HEADER;
"

# 3. Import into production
docker-compose exec postgres psql -U llm_config_user -d llm_config -c "
COPY configs FROM '/tmp/app-configs.csv' CSV HEADER;
"
```

### Restore Verification

After any restore:

```bash
#!/bin/bash
# Post-restore verification script

echo "Post-Restore Verification"
echo "========================"

# 1. Health check
echo "1. Health check..."
if curl -f http://localhost:8080/health; then
  echo "✓ Service is healthy"
else
  echo "✗ Service health check failed"
  exit 1
fi

# 2. Database connectivity
echo "2. Database connectivity..."
docker-compose exec postgres psql -U llm_config_user -d llm_config -c "SELECT 1;" > /dev/null
if [ $? -eq 0 ]; then
  echo "✓ Database connection OK"
else
  echo "✗ Database connection failed"
  exit 1
fi

# 3. Data integrity
echo "3. Data integrity..."
CONFIG_COUNT=$(docker-compose exec -T postgres psql -U llm_config_user -d llm_config -t -c "SELECT COUNT(*) FROM configs;")
echo "Configuration count: $CONFIG_COUNT"

if [ "$CONFIG_COUNT" -gt 0 ]; then
  echo "✓ Data present"
else
  echo "✗ No data found"
  exit 1
fi

# 4. API functionality
echo "4. API functionality..."
curl -s http://localhost:8080/api/v1/configs/test/verify?env=production > /dev/null
if [ $? -eq 0 ]; then
  echo "✓ API is functional"
else
  echo "⚠ API test returned error (may be expected if key doesn't exist)"
fi

# 5. Cache functionality
echo "5. Cache functionality..."
CACHE_STATUS=$(curl -s http://localhost:8080/health | jq -r '.checks.cache.status')
if [ "$CACHE_STATUS" = "healthy" ]; then
  echo "✓ Cache is operational"
else
  echo "⚠ Cache status: $CACHE_STATUS"
fi

# 6. Recent activity
echo "6. Recent activity..."
LATEST_CONFIG=$(docker-compose exec -T postgres psql -U llm_config_user -d llm_config -t -c "SELECT MAX(created_at) FROM configs;")
echo "Latest configuration: $LATEST_CONFIG"

echo ""
echo "Verification complete"
```

## Backup Management

### Retention Policy

**Automated Cleanup**:
```bash
#!/bin/bash
# Backup cleanup script

BACKUP_DIR="/var/lib/llm-config/backups"

# Keep hourly backups for 24 hours
find "$BACKUP_DIR" -name "backup-hourly-*.tar.gz" -mtime +1 -delete

# Keep daily backups for 30 days
find "$BACKUP_DIR" -name "backup-daily-*.tar.gz" -mtime +30 -delete

# Keep weekly backups for 90 days
find "$BACKUP_DIR" -name "backup-weekly-*.tar.gz" -mtime +90 -delete

# Keep monthly backups for 365 days
find "$BACKUP_DIR" -name "backup-monthly-*.tar.gz" -mtime +365 -delete

echo "Backup cleanup complete"
```

### Storage Management

**Check backup storage usage**:
```bash
# Local storage
du -sh /var/lib/llm-config/backups/
ls -lht /var/lib/llm-config/backups/ | head -20

# Remote storage (S3)
aws s3 ls s3://my-backups/llm-config/ --recursive --human-readable | tail -20
aws s3 ls s3://my-backups/llm-config/ --recursive | awk '{sum+=$3} END {print sum/1024/1024/1024 " GB"}'
```

**Cleanup old backups**:
```bash
# Remove backups older than 90 days from S3
aws s3 ls s3://my-backups/llm-config/ --recursive | \
  awk '{print $4}' | \
  while read file; do
    aws s3api head-object --bucket my-backups --key "$file" --query LastModified --output text | \
    xargs -I {} date -d {} +%s | \
    while read timestamp; do
      if [ $(($(date +%s) - timestamp)) -gt 7776000 ]; then
        echo "Deleting old backup: $file"
        aws s3 rm "s3://my-backups/$file"
      fi
    done
  done
```

## Automated Backup

### Systemd Timer (Linux)

Already configured in deployment. Verify:

```bash
# Check backup timer status
systemctl status llm-config-backup.timer

# View recent backup runs
journalctl -u llm-config-backup.service -n 20

# Manually trigger backup
sudo systemctl start llm-config-backup.service

# View backup logs
sudo journalctl -u llm-config-backup.service -f
```

### Kubernetes CronJob

```yaml
# backup-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: llm-config-backup
  namespace: llm-config
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: llm-config-manager:latest
            command:
            - /bin/bash
            - -c
            - |
              pg_dump -U llm_config_user -h postgres -Fc llm_config > /backups/backup-$(date +%Y%m%d).dump
              # Upload to S3
              aws s3 cp /backups/backup-$(date +%Y%m%d).dump s3://my-backups/llm-config/
          volumeMounts:
          - name: backups
            mountPath: /backups
          env:
          - name: PGPASSWORD
            valueFrom:
              secretKeyRef:
                name: llm-config-manager-secrets
                key: DB_PASSWORD
          volumes:
          - name: backups
            persistentVolumeClaim:
              claimName: llm-config-backups
          restartPolicy: OnFailure
```

Apply:
```bash
kubectl apply -f backup-cronjob.yaml
```

### Docker Compose with Cron

Add to docker-compose.yml:
```yaml
services:
  backup:
    image: llm-config-manager:latest
    volumes:
      - llm-config-backups:/backups
    environment:
      - BACKUP_SCHEDULE=0 2 * * *
    command: crond -f -l 2
```

## Best Practices

1. **Test Restores Regularly**: Monthly restore drills
2. **Verify Every Backup**: Automate verification
3. **Store Off-Site**: Use cloud storage for redundancy
4. **Encrypt Backups**: Protect sensitive data
5. **Document Procedures**: Keep runbooks updated
6. **Monitor Backup Jobs**: Alert on failures
7. **Maintain Multiple Copies**: 3-2-1 rule (3 copies, 2 media types, 1 off-site)
8. **Secure Backup Storage**: Restrict access, audit logs
9. **Version Backups**: Never overwrite backups
10. **Clean Up Old Backups**: Manage storage costs

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-21
**Next Review**: 2026-02-21
**Owner**: Operations Team
