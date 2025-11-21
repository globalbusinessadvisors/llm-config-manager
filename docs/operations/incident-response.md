# Incident Response Procedures

**Version**: 1.0.0
**Last Updated**: 2025-11-21
**Purpose**: Structured procedures for responding to and managing production incidents

## Table of Contents

1. [Overview](#overview)
2. [Incident Classification](#incident-classification)
3. [Incident Response Workflow](#incident-response-workflow)
4. [Incident Response Procedures](#incident-response-procedures)
5. [Communication Protocols](#communication-protocols)
6. [Post-Incident Review](#post-incident-review)
7. [Incident Response Team](#incident-response-team)

## Overview

This document defines the incident response process for LLM Config Manager production issues. The goal is to minimize impact, restore service quickly, and prevent recurrence.

### Incident Response Principles

1. **Safety First**: Protect data integrity and user privacy
2. **Communicate Early**: Notify stakeholders immediately
3. **Restore Quickly**: Fix now, investigate later
4. **Learn Always**: Conduct thorough post-incident reviews
5. **Blameless Culture**: Focus on systems, not people

### Related Documents

- Monitoring Guide: `/docs/operations/monitoring.md`
- Runbooks: `/docs/operations/runbooks/`
- Security Guide: `/docs/SECURITY.md`
- Deployment Guide: `/docs/DEPLOYMENT.md`

## Incident Classification

### Severity Levels

#### Severity 1 (Critical) - P1

**Definition**: Complete service outage or data loss

**Characteristics**:
- Service completely unavailable
- Data corruption or loss
- Security breach
- Affects all or majority of users

**Examples**:
- All API endpoints returning 5xx errors
- Database corruption
- Encryption keys compromised
- Unauthorized access detected

**Response Time**: Immediate (within 5 minutes)
**Escalation**: Page on-call immediately
**Communication**: Hourly updates to stakeholders

#### Severity 2 (High) - P2

**Definition**: Major functionality degraded

**Characteristics**:
- Critical features unavailable
- Severe performance degradation
- Affects significant user subset
- No workaround available

**Examples**:
- Write operations failing (reads work)
- P95 latency >1 second
- Cache completely unavailable
- Partial data inconsistency

**Response Time**: Within 15 minutes
**Escalation**: Notify on-call and team
**Communication**: Update every 2 hours

#### Severity 3 (Medium) - P3

**Definition**: Moderate impact with workaround

**Characteristics**:
- Non-critical features affected
- Performance issues
- Affects small user subset
- Workaround available

**Examples**:
- Backup job failing
- Monitoring gaps
- Low cache hit rate
- Slow queries on specific operations

**Response Time**: Within 1 hour
**Escalation**: Team notification
**Communication**: Daily updates

#### Severity 4 (Low) - P4

**Definition**: Minor issues, cosmetic problems

**Characteristics**:
- No significant user impact
- Documentation issues
- Nice-to-have features
- Planned improvements

**Examples**:
- Log formatting issues
- Dashboard display problems
- Documentation gaps
- Enhancement requests

**Response Time**: Best effort
**Escalation**: Normal workflow
**Communication**: As needed

## Incident Response Workflow

### Phase 1: Detection (0-5 minutes)

**Trigger Sources**:
- Monitoring alerts (Prometheus/Grafana)
- Health check failures
- User reports
- Security scans
- Automated tests

**Actions**:
```bash
# 1. Acknowledge alert
# Via PagerDuty/Slack/monitoring tool

# 2. Quick assessment (2 minutes)
# Check service status
curl http://localhost:8080/health
kubectl get pods -n llm-config  # or docker-compose ps

# 3. Verify incident (1 minute)
# Check metrics
curl http://localhost:9090/metrics | grep -E "up|error"

# 4. Classify severity (1 minute)
# Use severity definitions above

# 5. Initiate response (1 minute)
# Notify team based on severity
```

### Phase 2: Response (5-60 minutes)

**Objectives**:
1. Contain the incident
2. Restore service
3. Preserve evidence
4. Communicate status

**Actions**:

#### A. Assemble Team

```bash
# P1/P2: Page on-call engineer
# P1: Alert incident commander
# P1: Notify stakeholders

# Create incident channel
# Slack: #incident-YYYYMMDD-HHMM
# Document: incident-log.md
```

#### B. Initial Assessment

```bash
# 1. Gather symptoms (5 minutes)
# - What's broken?
# - When did it start?
# - What changed recently?

# 2. Check recent deployments
kubectl rollout history deployment llm-config-manager -n llm-config
docker-compose logs --since 30m llm-config-manager | head -50

# 3. Review monitoring
# - Error rate spike?
# - Latency increase?
# - Resource exhaustion?

# 4. Check dependencies
# - Database healthy?
# - Cache available?
# - Network issues?
```

#### C. Immediate Mitigation

**Priority**: Stop the bleeding

**Common Mitigations**:

**Service Restart**:
```bash
# If service is hung/crashed
kubectl rollout restart deployment llm-config-manager -n llm-config
# or
docker-compose restart llm-config-manager
# or
sudo systemctl restart llm-config-manager
```

**Rollback Deployment**:
```bash
# If related to recent deployment
kubectl rollout undo deployment llm-config-manager -n llm-config
# or
docker-compose down && git checkout <previous-version> && docker-compose up -d
```

**Scale Horizontally**:
```bash
# If overwhelmed by traffic
kubectl scale deployment llm-config-manager -n llm-config --replicas=10
```

**Enable Maintenance Mode** (if available):
```bash
# Redirect traffic to maintenance page
# Reject new requests
# Allow inflight requests to complete
```

**Isolate Issue**:
```bash
# Ban suspicious IPs
curl -X POST http://localhost:8080/api/v1/security/banned-ips \
  -d '{"ip": "X.X.X.X", "reason": "Incident response"}'

# Disable affected feature
# Update configuration to disable problematic component
```

#### D. Restore Service

**Verification Steps**:
```bash
# 1. Check health endpoint
curl http://localhost:8080/health

# 2. Verify metrics
curl http://localhost:9090/metrics | grep -E "error|latency"

# 3. Test functionality
# Run smoke tests
curl -X POST http://localhost:8080/api/v1/configs/test/incident_test \
  -d '{"value": "test", "env": "production", "user": "ops"}'

curl http://localhost:8080/api/v1/configs/test/incident_test?env=production

# 4. Check logs for errors
docker-compose logs --since 5m llm-config-manager | grep ERROR

# 5. Monitor for stability (10 minutes)
watch -n 10 'curl -s http://localhost:8080/health | jq ".status"'
```

### Phase 3: Recovery (1-4 hours)

**Objectives**:
1. Verify complete restoration
2. Root cause analysis
3. Implement permanent fixes
4. Prevent recurrence

**Actions**:

#### A. Verify Full Recovery

```bash
# 1. Run comprehensive health check
/usr/local/bin/comprehensive-health-check.sh

# 2. Check all metrics normal
# Review Grafana dashboards

# 3. User acceptance
# Verify user reports of normal operation

# 4. Sustained stability
# Monitor for 1 hour without issues
```

#### B. Root Cause Analysis

**Investigative Questions**:
1. What exactly happened?
2. When did it start?
3. What was the user impact?
4. What triggered it?
5. Why didn't we catch it earlier?

**Collect Evidence**:
```bash
# 1. Save logs
docker-compose logs llm-config-manager > incident-logs-$(date +%Y%m%d-%H%M%S).txt

# 2. Export metrics
curl http://localhost:9091/api/v1/query_range?query=up[6h] > metrics-during-incident.json

# 3. Document timeline
# When: First symptom detected
# When: Alert fired
# When: Team notified
# When: Mitigation started
# When: Service restored
# When: Full recovery

# 4. Identify changes
git log --since="6 hours ago" --oneline
kubectl rollout history deployment llm-config-manager -n llm-config
```

#### C. Implement Permanent Fix

```bash
# 1. Develop fix
# - Code changes
# - Configuration updates
# - Infrastructure changes

# 2. Test fix
# - Unit tests
# - Integration tests
# - Load tests

# 3. Deploy fix
# - Follow normal deployment process
# - Extra monitoring during deployment

# 4. Verify fix
# - Monitor for recurrence
# - Load test if applicable
```

### Phase 4: Post-Incident (1-7 days)

**Objectives**:
1. Document incident
2. Identify improvements
3. Prevent recurrence
4. Share learnings

**Actions**: See [Post-Incident Review](#post-incident-review)

## Incident Response Procedures

### Security Incident

**Triggers**:
- Unauthorized access detected
- Data breach suspected
- Malware detected
- DDoS attack
- Unusual access patterns

**Immediate Actions**:

1. **Contain** (5 minutes):
   ```bash
   # Isolate affected systems
   kubectl scale deployment llm-config-manager -n llm-config --replicas=0

   # Ban suspicious IPs
   # Save evidence before cleanup
   ```

2. **Assess** (15 minutes):
   ```bash
   # Check audit logs
   curl http://localhost:8080/api/v1/audit?since=24h > audit-incident.json

   # Check access patterns
   docker-compose logs llm-config-manager | grep -E "403|401|429"

   # Identify compromised accounts
   ```

3. **Eradicate** (30 minutes):
   ```bash
   # Rotate all secrets
   ./scripts/rotate-all-secrets.sh

   # Patch vulnerability
   # Update dependencies
   # Deploy fixed version
   ```

4. **Recover** (1 hour):
   ```bash
   # Restore from clean backup if needed
   # See disaster-recovery.md

   # Scale back up
   kubectl scale deployment llm-config-manager -n llm-config --replicas=3

   # Verify security
   cargo dep-scan --fail-on-vulnerabilities
   cargo sec-scan --fail-on-high
   ```

5. **Report**:
   - Notify security team: security@example.com
   - Document in security incident log
   - Follow compliance requirements (GDPR, etc.)

### Data Loss/Corruption Incident

**Triggers**:
- Data integrity check failures
- User reports of missing data
- Backup verification failures
- Storage corruption errors

**Immediate Actions**:

1. **Stop Operations** (immediate):
   ```bash
   # Prevent further corruption
   kubectl scale deployment llm-config-manager -n llm-config --replicas=0

   # Enable read-only mode if available
   ```

2. **Assess Damage** (10 minutes):
   ```bash
   # Check data integrity
   # Compare with backups
   # Identify affected data

   # Check logs for corruption
   docker-compose logs llm-config-manager | grep -i "corrupt\|integrity"
   ```

3. **Restore** (30-60 minutes):
   ```bash
   # Follow backup-restore.md procedures
   # Restore from most recent clean backup
   # Verify restored data

   # If PostgreSQL:
   docker-compose exec postgres pg_restore --verbose -d llm_config backup.dump
   ```

4. **Verify** (15 minutes):
   ```bash
   # Run data integrity checks
   # Compare record counts
   # Verify random samples
   ```

5. **Resume Operations**:
   ```bash
   # Scale back up
   kubectl scale deployment llm-config-manager -n llm-config --replicas=3

   # Monitor closely
   ```

### Performance Degradation Incident

**Triggers**:
- Latency >500ms P95
- High CPU/memory usage
- Low cache hit rate
- Timeouts occurring

**Actions**:

1. **Quick Assessment** (5 minutes):
   ```bash
   # Check current load
   curl -s http://localhost:9090/metrics | grep http_requests_total

   # Check resources
   docker stats llm-config-manager --no-stream

   # Check cache
   curl http://localhost:8080/health | jq '.checks.cache'
   ```

2. **Immediate Mitigation** (10 minutes):
   ```bash
   # Scale horizontally
   kubectl scale deployment llm-config-manager -n llm-config --replicas=10

   # Enable rate limiting
   # Clear and rebuild cache
   docker-compose exec redis redis-cli FLUSHALL

   # Optimize database
   docker-compose exec postgres psql -U llm_config_user -d llm_config -c "VACUUM ANALYZE;"
   ```

3. **Detailed Investigation**:
   - Follow `/docs/operations/runbooks/performance-troubleshooting.md`

### Third-Party Dependency Failure

**Triggers**:
- Database unavailable
- Redis connection failed
- External service timeout
- Network partition

**Actions**:

1. **Verify Impact** (2 minutes):
   ```bash
   # Check health status
   curl http://localhost:8080/health

   # Identify failed dependency
   ```

2. **Failover/Fallback** (5 minutes):
   ```bash
   # If cache unavailable: Operate without cache (degraded mode)
   # If database unavailable: Failover to replica

   # Point to backup systems
   # Update connection strings
   ```

3. **Restore Primary** (varies):
   ```bash
   # Restart failed service
   docker-compose restart postgres
   kubectl delete pod -n llm-config postgres-0

   # Verify recovery
   docker-compose exec postgres pg_isready
   ```

## Communication Protocols

### Internal Communication

**Incident Channel** (Slack/Teams):
- Create dedicated channel: `#incident-YYYYMMDD-HHMM`
- Pin incident status message
- Update every 30 minutes (P1), 1 hour (P2)
- Document all actions taken

**Status Updates Template**:
```
INCIDENT UPDATE - [timestamp]
Status: [Investigating | Identified | Monitoring | Resolved]
Impact: [Description of user impact]
Actions Taken: [What we've done]
Next Steps: [What we're doing next]
ETA: [Expected resolution time]
```

### External Communication

**Severity 1/2 Incidents**:

1. **Initial Notification** (within 30 minutes):
   ```
   Subject: [INCIDENT] LLM Config Manager Service Disruption

   We are currently experiencing a service disruption affecting
   LLM Config Manager. Our team is actively working to resolve
   the issue.

   Impact: [Description]
   Started: [Time]
   Status: Investigating

   We will provide updates every hour until resolved.
   ```

2. **Progress Updates** (hourly for P1, 2-hourly for P2):
   ```
   Subject: [UPDATE] LLM Config Manager Incident

   Current Status: [Description]
   Actions Taken: [Summary]
   Next Steps: [What's next]
   Expected Resolution: [ETA if known]
   ```

3. **Resolution Notice**:
   ```
   Subject: [RESOLVED] LLM Config Manager Incident

   The service disruption has been resolved as of [time].

   Summary: [Brief description]
   Duration: [Total downtime]
   Root Cause: [Summary]
   Prevention: [What we're doing to prevent recurrence]

   Full post-mortem will be published within 5 business days.
   ```

### Escalation Matrix

| Severity | First Response | Escalation 1 | Escalation 2 |
|----------|---------------|--------------|--------------|
| P1 | On-call (immediate) | Incident Commander (5 min) | VP Engineering (15 min) |
| P2 | On-call (15 min) | Team Lead (30 min) | Engineering Manager (2 hours) |
| P3 | Team (1 hour) | Team Lead (4 hours) | - |
| P4 | Best effort | - | - |

**Contact Information**:
- On-call: ops-oncall@example.com, PagerDuty
- Incident Commander: ic@example.com
- Team Lead: team-lead@example.com
- Engineering Manager: eng-manager@example.com
- VP Engineering: vp-eng@example.com
- Emergency Hotline: +1-555-0100

## Post-Incident Review

### Blameless Post-Mortem

**Purpose**: Learn and improve, not blame

**Timeline**: Within 5 business days of incident resolution

**Attendees**:
- Incident responders
- Affected team members
- Engineering leadership
- Product stakeholders (if user-facing)

**Agenda** (1 hour meeting):

1. **Incident Summary** (5 min)
   - What happened?
   - When did it happen?
   - Who was affected?
   - Duration and impact?

2. **Timeline Review** (15 min)
   - Detection to resolution timeline
   - What went well?
   - What could be improved?

3. **Root Cause Analysis** (20 min)
   - Use "5 Whys" technique
   - Identify contributing factors
   - Distinguish symptoms from causes

4. **Action Items** (15 min)
   - Preventive measures
   - Monitoring improvements
   - Process improvements
   - Owners and deadlines

5. **Documentation** (5 min)
   - Runbook updates
   - Alert tuning
   - Knowledge sharing

### Post-Mortem Template

```markdown
# Incident Post-Mortem: [Title]

**Date**: YYYY-MM-DD
**Duration**: [Start] to [End] ([Duration])
**Severity**: P[1-4]
**Impact**: [Number] users affected, [Duration] downtime
**Incident Commander**: [Name]
**Responders**: [Names]

## Summary

[2-3 sentence summary of what happened and impact]

## Timeline

All times in UTC.

| Time | Event |
|------|-------|
| 10:00 | First symptom detected |
| 10:05 | Alert fired |
| 10:10 | On-call acknowledged |
| 10:15 | Root cause identified |
| 10:30 | Mitigation deployed |
| 10:45 | Service restored |
| 11:00 | Verified stable |

## Root Cause

[Detailed explanation of what caused the incident]

## Impact

- **Users Affected**: [Number or percentage]
- **Duration**: [Total downtime]
- **Operations Affected**: [Which features/operations]
- **Data Impact**: [Any data loss/corruption]

## Detection

[How we discovered the incident - monitoring, user report, etc.]

## Response

[What we did to resolve the incident]

## What Went Well

- [Thing 1]
- [Thing 2]

## What Could Be Improved

- [Thing 1]
- [Thing 2]

## Action Items

| Action | Owner | Deadline | Priority |
|--------|-------|----------|----------|
| [Action 1] | [Name] | [Date] | High |
| [Action 2] | [Name] | [Date] | Medium |

## Lessons Learned

- [Lesson 1]
- [Lesson 2]
```

### Action Item Tracking

**Requirements**:
- Every post-mortem must have at least 3 action items
- Each action item must have owner and deadline
- Track in project management system
- Review in weekly team meetings
- Close loop on completion

**Categories**:
1. **Immediate fixes**: Deploy within 1 week
2. **Short-term improvements**: Complete within 1 month
3. **Long-term initiatives**: Complete within 1 quarter

## Incident Response Team

### Roles and Responsibilities

#### Incident Commander (IC)

**Responsibilities**:
- Overall incident coordination
- Make key decisions
- Delegate tasks
- Manage communication
- Declare incident resolved

**Authority**:
- Override normal processes
- Allocate any necessary resources
- Involve additional personnel
- Postpone non-critical work

#### On-Call Engineer

**Responsibilities**:
- First responder
- Initial assessment
- Technical execution
- Status updates
- Escalation when needed

**On-Call Rotation**: Weekly rotation, published in advance

#### Communications Lead (P1 only)

**Responsibilities**:
- Stakeholder communication
- Status page updates
- Customer notifications
- Post-incident communication

#### Subject Matter Experts (as needed)

**Roles**:
- Security expert
- Database expert
- Network expert
- Application expert

**Responsibilities**:
- Provide specialized knowledge
- Technical deep-dives
- Long-term fixes

### Training and Preparedness

**Quarterly Exercises**:
- Incident response drills
- Fire drills for different scenarios
- Runbook walkthroughs
- Communication practice

**Continuous Learning**:
- Review past incidents
- Study public post-mortems
- Share knowledge in team meetings
- Update runbooks based on incidents

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-21
**Next Review**: 2026-02-21
**Owner**: Operations Team
