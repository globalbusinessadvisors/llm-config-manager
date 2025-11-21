# LLM-Config-Manager: Integration Architecture Diagrams

**Date:** 2025-11-21
**Version:** 1.0.0
**Purpose:** Visual reference for system architecture and module integrations

---

## System Overview

```
┌────────────────────────────────────────────────────────────────────────────┐
│                          LLM DevOps Ecosystem                              │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────┐    │
│   │                    8 Functional Cores                            │    │
│   │                                                                   │    │
│   │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌──────────┐  │    │
│   │  │Intelligence│  │  Security  │  │ Automation │  │Governance│  │    │
│   │  │ (4 modules)│  │(3 modules) │  │(3 modules) │  │(3 modules│  │    │
│   │  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘  └────┬─────┘  │    │
│   │        │               │               │              │          │    │
│   │  ┌─────┴───────────────┴───────────────┴──────────────┴─────┐  │    │
│   │  │              LLM-Config-Manager (Central Hub)            │  │    │
│   │  │  - Unified Configuration Storage                         │  │    │
│   │  │  - Secrets Management (Vault + Cloud KMS)               │  │    │
│   │  │  - Policy Integration (Authorization & Validation)       │  │    │
│   │  │  - Audit Logging (SOC2/ISO27001/GDPR compliant)         │  │    │
│   │  └──────────────────────────────────────────────────────────┘  │    │
│   │        │               │               │              │          │    │
│   │  ┌─────┴──────┐  ┌────┴───────┐  ┌───┴──────┐  ┌───┴───────┐  │    │
│   │  │    Data    │  │ Ecosystem  │  │ Research │  │ Interface │  │    │
│   │  │(3 modules) │  │(2 modules) │  │(2 modules│  │(2 modules)│  │    │
│   │  └────────────┘  └────────────┘  └──────────┘  └───────────┘  │    │
│   └─────────────────────────────────────────────────────────────────┘    │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## Detailed Component Architecture

```
┌───────────────────────────────────────────────────────────────────────────┐
│                         LLM-Config-Manager                                │
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                     Presentation Layer                             │  │
│  │  ┌─────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │  │
│  │  │  REST API   │  │  gRPC API    │  │  CLI Interface           │  │  │
│  │  │  (axum)     │  │  (tonic)     │  │  (clap + ratatui)        │  │  │
│  │  │  :8080      │  │  :9090       │  │  Binary executable       │  │  │
│  │  │  /api/v1/*  │  │  ConfigSvc   │  │  llm-config get/set      │  │  │
│  │  └─────────────┘  └──────────────┘  └──────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                  │                                        │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                    Application Layer                               │  │
│  │                                                                     │  │
│  │  ┌──────────────────┐            ┌──────────────────┐             │  │
│  │  │  Config Engine   │            │ Secrets Manager  │             │  │
│  │  │  - Resolution    │            │ - Encryption     │             │  │
│  │  │  - Templating    │            │ - Key Rotation   │             │  │
│  │  │  - Validation    │            │ - Lifecycle Mgmt │             │  │
│  │  │  - Versioning    │            │ - DEK/KEK        │             │  │
│  │  └──────────────────┘            └──────────────────┘             │  │
│  │                                                                     │  │
│  │  ┌──────────────────┐            ┌──────────────────┐             │  │
│  │  │ Policy Engine    │            │  Audit Logger    │             │  │
│  │  │ Integration      │            │  - Event Capture │             │  │
│  │  │ - RBAC Enforcer  │            │  - Persistence   │             │  │
│  │  │ - Policy Validator│           │  - Hash Chains   │             │  │
│  │  │ - gRPC Client    │            │  - Compliance    │             │  │
│  │  └──────────────────┘            └──────────────────┘             │  │
│  │                                                                     │  │
│  │  ┌──────────────────────────────────────────────────┐             │  │
│  │  │              Cache Manager                        │             │  │
│  │  │  L1: In-Memory LRU (moka) - <1ms                 │             │  │
│  │  │  L2: Distributed (Redis) - <10ms                 │             │  │
│  │  │  L3: Persistent (sled) - <50ms                   │             │  │
│  │  └──────────────────────────────────────────────────┘             │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                  │                                        │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                    Integration Layer                               │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐    │  │
│  │  │   Vault      │  │  Cloud KMS   │  │  Policy Engine       │    │  │
│  │  │   Adapter    │  │  Adapters    │  │  Adapter (gRPC)      │    │  │
│  │  │  (vaultrs)   │  │  AWS/GCP/AZ  │  │  PolicyEvaluate()    │    │  │
│  │  └──────────────┘  └──────────────┘  └──────────────────────┘    │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐    │  │
│  │  │ Governance   │  │ Observatory  │  │  Edge Agent          │    │  │
│  │  │ Dashboard    │  │ (Metrics)    │  │  Integration         │    │  │
│  │  │ (REST)       │  │ (OTLP)       │  │  (gRPC + Delta)      │    │  │
│  │  └──────────────┘  └──────────────┘  └──────────────────────┘    │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                  │                                        │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                        Data Layer                                  │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐    │  │
│  │  │ Vault/KMS    │  │ PostgreSQL   │  │  Redis / sled        │    │  │
│  │  │ (Primary)    │  │ (Metadata,   │  │  (L2/L3 Cache)       │    │  │
│  │  │ Secrets      │  │  Audit Logs) │  │  Distributed/Local   │    │  │
│  │  └──────────────┘  └──────────────┘  └──────────────────────┘    │  │
│  └────────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow: Configuration Retrieval

### Scenario 1: Cache Hit (Fast Path)

```
┌─────────────┐
│   Client    │
│ (Inference  │
│   Engine)   │
└──────┬──────┘
       │ 1. GetConfig("llm.model_config")
       ▼
┌────────────────────────────────────────────┐
│     LLM-Config-Manager API                 │
│  ┌──────────────────────────────────────┐  │
│  │  2. Authorization Check              │  │
│  │     Policy Engine: Allow? (3ms)      │  │
│  └──────────────────────────────────────┘  │
│  ┌──────────────────────────────────────┐  │
│  │  3. L1 Cache Lookup (moka)           │  │
│  │     Cache HIT! (<1ms)                │  │
│  └──────────────────────────────────────┘  │
│  ┌──────────────────────────────────────┐  │
│  │  4. Return Cached Value              │  │
│  └──────────────────────────────────────┘  │
│  ┌──────────────────────────────────────┐  │
│  │  5. Audit Log (async, non-blocking)  │  │
│  └──────────────────────────────────────┘  │
└────────────────────────────────────────────┘
       │
       │ 6. Config value (Total: ~4ms)
       ▼
┌─────────────┐
│   Client    │
└─────────────┘
```

**Total Latency:** ~4ms (p99)
- Authorization: 3ms
- Cache lookup: <1ms
- Audit logging: Async (non-blocking)

---

### Scenario 2: Cache Miss (Vault Fetch)

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ 1. GetConfig("new.config.key")
       ▼
┌────────────────────────────────────────────┐
│     LLM-Config-Manager API                 │
│  ┌──────────────────────────────────────┐  │
│  │  2. Authorization Check (3ms)        │  │
│  └──────────────────────────────────────┘  │
│  ┌──────────────────────────────────────┐  │
│  │  3. L1 Cache Lookup (moka)           │  │
│  │     Cache MISS                       │  │
│  └──────────────────────────────────────┘  │
│  ┌──────────────────────────────────────┐  │
│  │  4. L2 Cache Lookup (Redis)          │  │
│  │     Cache MISS (5ms)                 │  │
│  └──────────────────────────────────────┘  │
│  ┌──────────────────────────────────────┐  │
│  │  5. Fetch from Vault (40ms)          │  │
│  │     ├─ HTTP request to Vault         │  │
│  │     ├─ Decrypt DEK with KMS (30ms)   │  │
│  │     └─ Decrypt data with DEK (5ms)   │  │
│  └──────────────────────────────────────┘  │
│  ┌──────────────────────────────────────┐  │
│  │  6. Populate Caches (L1 + L2)        │  │
│  └──────────────────────────────────────┘  │
│  ┌──────────────────────────────────────┐  │
│  │  7. Return Value + Audit Log         │  │
│  └──────────────────────────────────────┘  │
└────────────────────────────────────────────┘
       │
       │ 8. Config value (Total: ~48ms)
       ▼
┌─────────────┐
│   Client    │
└─────────────┘
```

**Total Latency:** ~48ms (p99)
- Authorization: 3ms
- L1 cache miss: <1ms
- L2 cache miss: 5ms
- Vault fetch: 40ms (30ms KMS decrypt + 10ms network)

---

## Data Flow: Secret Rotation

```
┌────────────────────────────────────────────────────────────────────┐
│              Automated Secret Rotation Workflow                    │
└────────────────────────────────────────────────────────────────────┘

Time: T-15 minutes (Pre-Rotation)
┌──────────────────────────────────────────────────────────────────┐
│  Rotation Scheduler                                               │
│  1. Generate new secret (validate strength)                       │
│  2. Test new secret (connectivity, permissions)                   │
│  3. Publish event: "secret.rotation.pending"                      │
│     └─▶ Dependent services receive notification (15 min warning) │
│  4. Wait for acknowledgments (timeout: 5 minutes)                 │
└──────────────────────────────────────────────────────────────────┘
       │
       ▼
Time: T-0 (Activation)
┌──────────────────────────────────────────────────────────────────┐
│  Rotation Manager                                                 │
│  1. Set new secret as "current" in Vault                          │
│  2. Keep old secret as "previous" (grace period starts)           │
│  3. Publish event: "secret.rotated"                               │
│     └─▶ Event bus broadcasts to all subscribers                  │
│  4. Cache invalidation (Redis pub/sub)                            │
│     └─▶ All instances invalidate cached old secret               │
└──────────────────────────────────────────────────────────────────┘
       │
       ▼
Time: T+0 to T+grace (Grace Period)
┌──────────────────────────────────────────────────────────────────┐
│  Dual-Secret Period (both old and new valid)                      │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Services gradually adopt new secret:                      │  │
│  │  - Refresh on next config pull (30s default)               │  │
│  │  - Pushed via WebSocket (instant for connected clients)    │  │
│  │  - Old secret still works (connection pools drain)         │  │
│  └────────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Monitoring:                                                │  │
│  │  - Track error rates (rollback if >5% increase)            │  │
│  │  - Monitor connection failures                             │  │
│  │  - Alert on anomalies                                      │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
       │
       ▼
Time: T+grace (Revocation)
┌──────────────────────────────────────────────────────────────────┐
│  Secret Revocation                                                │
│  1. Verify no services using old secret (telemetry check)         │
│  2. Revoke old secret (mark as "revoked" in Vault)                │
│  3. Alert if services still using old secret                      │
│  4. Log rotation completion to audit trail                        │
│  5. Schedule next rotation (90 days for API keys)                 │
└──────────────────────────────────────────────────────────────────┘
```

**Grace Periods:**
- API Keys: 7 days
- DB Credentials: 24 hours
- TLS Certificates: 2 hours
- Service Tokens: 5 minutes

---

## Multi-Tenant Isolation Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Multi-Tenant Isolation Layers                        │
└─────────────────────────────────────────────────────────────────────────┘

Layer 1: Network Isolation (mTLS)
┌────────────────────────────────────────────────────────────────────────┐
│  Each tenant's services use unique client certificates                 │
│  Certificate CN includes tenant ID for identity verification           │
│  mTLS enforced at API gateway and service mesh                         │
└────────────────────────────────────────────────────────────────────────┘
       │
       ▼
Layer 2: API-Level Tenant Validation
┌────────────────────────────────────────────────────────────────────────┐
│  Every API request:                                                     │
│  1. Extract tenant ID from JWT or mTLS certificate                     │
│  2. Validate tenant ID against request resource path                   │
│  3. Reject if mismatch (prevent cross-tenant access)                   │
│  4. Log all tenant boundary violations to security audit               │
└────────────────────────────────────────────────────────────────────────┘
       │
       ▼
Layer 3: Database Schema Isolation
┌────────────────────────────────────────────────────────────────────────┐
│  PostgreSQL:                                                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐       │
│  │ Schema: tenant_a│  │ Schema: tenant_b│  │ Schema: tenant_c│       │
│  │ - configs       │  │ - configs       │  │ - configs       │       │
│  │ - secrets       │  │ - secrets       │  │ - secrets       │       │
│  │ - audit_logs    │  │ - audit_logs    │  │ - audit_logs    │       │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘       │
│                                                                         │
│  Benefits:                                                              │
│  - Physical separation (no accidental cross-tenant queries)            │
│  - Per-tenant backup/restore                                           │
│  - Independent schema evolution                                        │
└────────────────────────────────────────────────────────────────────────┘
       │
       ▼
Layer 4: Cryptographic Isolation
┌────────────────────────────────────────────────────────────────────────┐
│  Tenant A                    Tenant B                    Tenant C      │
│  ┌──────────────┐            ┌──────────────┐          ┌────────────┐ │
│  │ Data         │            │ Data         │          │ Data       │ │
│  │   ↓          │            │   ↓          │          │   ↓        │ │
│  │ Encrypt with │            │ Encrypt with │          │ Encrypt    │ │
│  │ DEK_A        │            │ DEK_B        │          │ with DEK_C │ │
│  │   ↓          │            │   ↓          │          │   ↓        │ │
│  │ Encrypted    │            │ Encrypted    │          │ Encrypted  │ │
│  │ Data_A       │            │ Data_B       │          │ Data_C     │ │
│  └──────────────┘            └──────────────┘          └────────────┘ │
│         │                           │                         │        │
│         │ DEK_A encrypted by KEK_A  │ DEK_B by KEK_B         │        │
│         ▼                           ▼                         ▼        │
│  ┌──────────────────────────────────────────────────────────────────┐ │
│  │              Cloud KMS (Separate Keys per Tenant)                │ │
│  │  KEK_A          KEK_B          KEK_C                             │ │
│  │  (Tenant A)     (Tenant B)     (Tenant C)                        │ │
│  └──────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│  Guarantee: Even with DB access, attacker cannot decrypt tenant data   │
│  without corresponding KEK from KMS (cryptographic isolation proof)    │
└────────────────────────────────────────────────────────────────────────┘
       │
       ▼
Layer 5: Resource Quotas & Rate Limiting
┌────────────────────────────────────────────────────────────────────────┐
│  Per-Tenant Quotas:                                                     │
│  - Storage: 10GB max                                                    │
│  - API Calls: 1000 req/min (adjustable per tier)                       │
│  - Concurrent Connections: 100 max                                      │
│  - Secrets: 1000 max                                                    │
│  - Namespaces: 100 max                                                  │
│                                                                          │
│  Enforcement:                                                            │
│  - API gateway checks quotas before forwarding requests                 │
│  - Soft limits (warn at 80%) and hard limits (reject at 100%)          │
│  - Quota metrics exported to Observatory for dashboard visibility      │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Deployment Architecture: Hybrid Mode

```
┌───────────────────────────────────────────────────────────────────────────┐
│                   Kubernetes Cluster (Production)                         │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐│
│  │                Central Configuration Service                          ││
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐                     ││
│  │  │  Config    │  │  Config    │  │  Config    │  (3+ replicas)      ││
│  │  │  Manager   │  │  Manager   │  │  Manager   │  HPA enabled        ││
│  │  │  Pod 1     │  │  Pod 2     │  │  Pod 3     │  Resources:         ││
│  │  │  :8080 REST│  │  :8080 REST│  │  :8080 REST│  256Mi-1Gi RAM      ││
│  │  │  :9090 gRPC│  │  :9090 gRPC│  │  :9090 gRPC│  100m-1000m CPU     ││
│  │  └────────────┘  └────────────┘  └────────────┘                     ││
│  │         │                │                │                           ││
│  │         └────────────────┴────────────────┘                           ││
│  │                          │                                             ││
│  │                          ▼                                             ││
│  │  ┌──────────────────────────────────────────────────────────────┐    ││
│  │  │  Service: llm-config-manager-api (ClusterIP)                 │    ││
│  │  │  Ingress: config.llm-devops.example.com (external REST)      │    ││
│  │  │  Headless Service: llm-config-manager-grpc (internal gRPC)   │    ││
│  │  └──────────────────────────────────────────────────────────────┘    ││
│  └──────────────────────────────────────────────────────────────────────┘│
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐│
│  │            Standard Application Pods (95% of workloads)              ││
│  │  ┌───────────────────────────────────────────────────────────┐      ││
│  │  │  LLM-Data-Pipeline Pod                                     │      ││
│  │  │  ┌──────────────┐                                          │      ││
│  │  │  │ Application  │  ──gRPC──▶  Central Config API          │      ││
│  │  │  │ Container    │             (p99: ~30-50ms)              │      ││
│  │  │  └──────────────┘                                          │      ││
│  │  └───────────────────────────────────────────────────────────┘      ││
│  │  Latency acceptable for non-critical paths                          ││
│  └──────────────────────────────────────────────────────────────────────┘│
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐│
│  │     Critical Inference Pods with Sidecar (<5% of workloads)         ││
│  │  ┌───────────────────────────────────────────────────────────┐      ││
│  │  │  LLM-Inference-Engine Pod                                  │      ││
│  │  │  ┌────────────┐         ┌─────────────────────┐           │      ││
│  │  │  │ Inference  │ Unix    │ Config Sidecar      │           │      ││
│  │  │  │ Container  │ Socket  │ - Local cache (sled)│           │      ││
│  │  │  │            │ <1ms ◀──│ - Sync every 30s    │           │      ││
│  │  │  │            │         │ - gRPC to central   │           │      ││
│  │  │  │            │         │ - Hot reload support│           │      ││
│  │  │  └────────────┘         └─────────────────────┘           │      ││
│  │  │                            Resources: 50-100MB RAM         │      ││
│  │  └───────────────────────────────────────────────────────────┘      ││
│  │  Ultra-low latency for critical inference paths                     ││
│  └──────────────────────────────────────────────────────────────────────┘│
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐│
│  │                        Supporting Services                            ││
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐    ││
│  │  │  Vault     │  │ PostgreSQL │  │   Redis    │  │ Prometheus │    ││
│  │  │  (Secrets) │  │ (Metadata) │  │  (Cache)   │  │  (Metrics) │    ││
│  │  └────────────┘  └────────────┘  └────────────┘  └────────────┘    ││
│  └──────────────────────────────────────────────────────────────────────┘│
└───────────────────────────────────────────────────────────────────────────┘

Decision Matrix:
┌─────────────────┬──────────────┬─────────────────┬──────────────────────┐
│ Workload Type   │ Latency Need │ Read Volume     │ Deployment Pattern   │
├─────────────────┼──────────────┼─────────────────┼──────────────────────┤
│ Inference Engine│ p99 <5ms     │ >1000 req/s/pod │ Sidecar (critical)   │
│ Model Router    │ p99 <5ms     │ >500 req/s/pod  │ Sidecar (critical)   │
│ API Gateway     │ p99 <10ms    │ >500 req/s/pod  │ Sidecar (critical)   │
│ Data Pipeline   │ p99 <50ms OK │ <100 req/s/pod  │ Central API          │
│ Observatory     │ p99 <100ms OK│ <50 req/s/pod   │ Central API          │
│ Dashboard       │ p99 <200ms OK│ <10 req/s/pod   │ Central API          │
└─────────────────┴──────────────┴─────────────────┴──────────────────────┘

Cost Analysis:
- Central API only: 3 pods × 512MB = 1.5GB RAM
- With sidecars (5% of 100 pods): 1.5GB + (5 × 75MB) = 1.875GB RAM
- Total overhead: ~375MB (20% increase for 5x performance on critical paths)
```

---

## Policy Engine Integration Flow

```
┌───────────────────────────────────────────────────────────────────────────┐
│          Authorization & Validation via LLM-Policy-Engine                 │
└───────────────────────────────────────────────────────────────────────────┘

Scenario 1: Authorization Check (Every API Request)
┌─────────────┐
│   Client    │ 1. GetConfig(tenant-123, prod, llm.model_config)
└──────┬──────┘
       │
       ▼
┌────────────────────────────────────────────────┐
│        LLM-Config-Manager API                  │
│  ┌──────────────────────────────────────────┐  │
│  │ 2. Extract Identity & Build Policy Query │  │
│  │    User: alice@example.com               │  │
│  │    Tenant: tenant-123                    │  │
│  │    Resource: prod:llm.model_config       │  │
│  │    Action: read                          │  │
│  └──────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
       │
       ▼ 3. gRPC: EvaluatePolicy()
┌────────────────────────────────────────────────┐
│         LLM-Policy-Engine                      │
│  ┌──────────────────────────────────────────┐  │
│  │ 4. Load Policies (cached):               │  │
│  │    - RBAC: alice is "developer"          │  │
│  │    - ABAC: check time, location, env     │  │
│  │    - Resource ACL: prod configs          │  │
│  └──────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────┐  │
│  │ 5. Evaluate Policy:                      │  │
│  │    Result: ALLOW                         │  │
│  │    Reason: "developer role + prod read"  │  │
│  │    Duration: 3ms                         │  │
│  └──────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
       │
       ▼ 6. PolicyDecision{allow=true}
┌────────────────────────────────────────────────┐
│        LLM-Config-Manager API                  │
│  ┌──────────────────────────────────────────┐  │
│  │ 7. Decision: ALLOW - proceed to fetch   │  │
│  │ 8. Fetch from Vault (or cache)          │  │
│  │ 9. Return config value to client        │  │
│  │ 10. Audit log: {user, action, decision} │  │
│  └──────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
       │
       ▼ 11. Config value + success
┌─────────────┐
│   Client    │
└─────────────┘


Scenario 2: Pre-Commit Validation (Config Changes)
┌─────────────┐
│   Client    │ 1. SetConfig(tenant-123, prod, db-password, value, {expires: 180d})
└──────┬──────┘
       │
       ▼
┌────────────────────────────────────────────────┐
│        LLM-Config-Manager API                  │
│  ┌──────────────────────────────────────────┐  │
│  │ 2. Pre-Commit Validation Required       │  │
│  │    (production secret with expiration)   │  │
│  └──────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
       │
       ▼ 3. gRPC: ValidateConfig()
┌────────────────────────────────────────────────┐
│         LLM-Policy-Engine                      │
│  ┌──────────────────────────────────────────┐  │
│  │ 4. Load Security Policies:               │  │
│  │    Policy: "prod_secrets_max_expiration" │  │
│  │    Rule: expiration <= 90 days           │  │
│  └──────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────┐  │
│  │ 5. Evaluate:                             │  │
│  │    Given: expires = 180 days             │  │
│  │    Rule: 180 > 90 → VIOLATION            │  │
│  │    Result: INVALID                       │  │
│  └──────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
       │
       ▼ 6. ValidationResult{valid=false, violations=[...]}
┌────────────────────────────────────────────────┐
│        LLM-Config-Manager API                  │
│  ┌──────────────────────────────────────────┐  │
│  │ 7. Decision: REJECT - policy violation  │  │
│  │ 8. Return HTTP 400 Bad Request          │  │
│  │    Error: "Secret expiration exceeds    │  │
│  │            90 days for production"       │  │
│  │ 9. Audit log: {validation_failed}       │  │
│  └──────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
       │
       ▼ 10. Error response + violation details
┌─────────────┐
│   Client    │
└─────────────┘
```

**Performance SLA:**
- Authorization evaluation: <5ms (p99)
- Validation evaluation: <10ms (p99)
- Policy cache TTL: 1 minute (staleness acceptable for performance)
- Policy updates: Propagate in <1 minute (eventual consistency)

---

## Edge Agent Synchronization

```
┌───────────────────────────────────────────────────────────────────────────┐
│               Edge Agent Configuration Synchronization                     │
└───────────────────────────────────────────────────────────────────────────┘

┌─────────────────────┐                          ┌─────────────────────────┐
│   Edge Device       │                          │  Central Config Service │
│   (Cellular/WiFi)   │                          │  (Cloud/On-Prem)        │
│                     │                          │                         │
│ ┌─────────────────┐ │                          │  ┌────────────────────┐ │
│ │ Edge Agent      │ │                          │  │ Config Manager API │ │
│ │ - Local cache   │ │                          │  │ - Delta calculator │ │
│ │ - Sync manager  │ │                          │  │ - Version tracker  │ │
│ │ - Conflict res. │ │                          │  │ - Compression      │ │
│ └─────────────────┘ │                          │  └────────────────────┘ │
│         │           │                          │           │             │
└─────────┼───────────┘                          └───────────┼─────────────┘
          │                                                  │
          │ 1. GetConfigUpdates(current_version=41)         │
          │─────────────────────────────────────────────────▶│
          │                                                  │
          │                    2. Calculate delta           │
          │                       (version 41 → 42)         │
          │                       Changes:                  │
          │                       - llm.temperature: 0.7→0.8│
          │                       - llm.max_tokens: +field  │
          │                       Delta size: 200 bytes     │
          │                       (vs 5KB full config)      │
          │                                                  │
          │ 3. ConfigDelta(binary_patch, checksum, v=42)    │
          │◀─────────────────────────────────────────────────│
          │                                                  │
          │ 4. Apply patch to local config                  │
          │    - Decompress                                 │
          │    - Apply binary diff                          │
          │    - Verify checksum                            │
          │    - Update version → 42                        │
          │    - Persist to local cache                     │
          │                                                  │
          │ 5. ACK(version=42, success=true)                │
          │─────────────────────────────────────────────────▶│
          │                                                  │
          │                    6. Log sync event            │
          │                       Mark device up-to-date    │
          │                                                  │

Offline Mode (Device Disconnected):
┌─────────────────────┐
│   Edge Device       │
│   (Offline)         │
│                     │
│ ┌─────────────────┐ │
│ │ Edge Agent      │ │
│ │ Local Cache     │ │
│ │ - Last sync:    │ │
│ │   2h ago        │ │
│ │ - Staleness: OK │ │
│ │   (< 24h limit) │ │
│ │                 │ │
│ │ 1. Application  │ │
│ │    requests     │ │
│ │    config       │ │
│ │ 2. Serve from   │ │
│ │    local cache  │ │
│ │ 3. Log warning  │ │
│ │    if stale >1h │ │
│ └─────────────────┘ │
│                     │
│ Config age: 2 hours │
│ Acceptable for:     │
│ - Model params      │
│ - Feature flags     │
│ NOT acceptable for: │
│ - Security policies │
│ - Access control    │
└─────────────────────┘

Reconnection (Conflict Resolution):
┌─────────────────────┐                          ┌─────────────────────────┐
│   Edge Device       │                          │  Central Config Service │
│   (Reconnected)     │                          │                         │
│                     │                          │                         │
│ Local changes:      │                          │  Server changes:        │
│ - llm.temperature:  │                          │  - llm.temperature:     │
│   0.7 → 0.9 (local) │                          │    0.7 → 0.8 (server)   │
│                     │                          │                         │
│ 1. Sync request     │                          │                         │
│    (version=41,     │                          │                         │
│     local_changes)  │─────────────────────────▶│                         │
│                     │                          │ 2. Detect conflict      │
│                     │                          │    (both modified       │
│                     │                          │     same field)         │
│                     │                          │                         │
│                     │ 3. ConflictResolution    │                         │
│                     │    strategy=server_wins  │                         │
│                     │    (security configs)    │                         │
│                     │◀─────────────────────────│                         │
│ 4. Accept server    │                          │                         │
│    version (0.8)    │                          │                         │
│    Discard local    │                          │                         │
│    change (0.9)     │                          │                         │
│    Log conflict     │                          │                         │
│    resolution       │                          │                         │
│                     │ 5. ACK(resolved=true)    │                         │
│                     │─────────────────────────▶│                         │
└─────────────────────┘                          └─────────────────────────┘

Bandwidth Savings:
- Full config download: 5KB
- Delta update: 200 bytes
- Compression ratio: 96% reduction
- Monthly bandwidth (30 syncs/day): 5KB×30 = 150KB (full) vs 200B×30 = 6KB (delta)
```

---

## Observability Integration

```
┌───────────────────────────────────────────────────────────────────────────┐
│            LLM-Config-Manager Observability Export                        │
└───────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────┐
│                      LLM-Config-Manager                                  │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │                    Instrumentation Layer                            ││
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             ││
│  │  │  Metrics     │  │  Logs        │  │  Traces      │             ││
│  │  │  (metrics)   │  │  (tracing)   │  │  (tracing)   │             ││
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘             ││
│  └─────────┼──────────────────┼──────────────────┼───────────────────┘│
└────────────┼──────────────────┼──────────────────┼────────────────────┘
             │                  │                  │
             │                  │                  │
             ▼                  ▼                  ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        LLM-Observatory                                 │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐│
│  │  Metrics Collection (Prometheus)                                  ││
│  │  GET /metrics → Pull metrics every 15s                            ││
│  │  ┌─────────────────────────────────────────────────────────────┐ ││
│  │  │ llm_config_operations_total{op="get", status="success"} 1254││
│  │  │ llm_config_operation_duration_seconds{op="get", q="0.99"}   ││
│  │  │   0.045                                                      ││
│  │  │ llm_config_cache_hit_rate 0.981                             ││
│  │  │ llm_config_secret_rotations_total{status="success"} 45      ││
│  │  └─────────────────────────────────────────────────────────────┘ ││
│  └───────────────────────────────────────────────────────────────────┘│
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐│
│  │  Structured Logging (JSON to stdout → Loki)                      ││
│  │  ┌─────────────────────────────────────────────────────────────┐ ││
│  │  │ {                                                            │ ││
│  │  │   "timestamp": "2025-11-21T12:34:56.789Z",                  │ ││
│  │  │   "level": "INFO",                                          │ ││
│  │  │   "message": "Configuration retrieved",                     │ ││
│  │  │   "trace_id": "abc123",                                     │ ││
│  │  │   "tenant_id": "tenant-123",                                │ ││
│  │  │   "key": "llm.model_config",                                │ ││
│  │  │   "duration_ms": 4.5,                                       │ ││
│  │  │   "cache_hit": true                                         │ ││
│  │  │ }                                                            │ ││
│  │  └─────────────────────────────────────────────────────────────┘ ││
│  └───────────────────────────────────────────────────────────────────┘│
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐│
│  │  Distributed Tracing (OpenTelemetry → Tempo)                     ││
│  │  ┌─────────────────────────────────────────────────────────────┐ ││
│  │  │ Trace ID: abc123                                            │ ││
│  │  │ Span 1: http.request (50ms)                                 │ ││
│  │  │   ├─ Span 2: policy.evaluate (3ms)                          │ ││
│  │  │   ├─ Span 3: cache.lookup (1ms) [cache_hit=true]            │ ││
│  │  │   ├─ Span 4: audit.log (1ms) [async]                        │ ││
│  │  │   └─ Span 5: http.response (1ms)                            │ ││
│  │  │                                                              │ ││
│  │  │ Sampling:                                                    │ ││
│  │  │ - Errors: 100% (all errors traced)                          │ ││
│  │  │ - Slow (p99): 100% (>50ms traced)                           │ ││
│  │  │ - Normal: 1% (representative sample)                        │ ││
│  │  └─────────────────────────────────────────────────────────────┘ ││
│  └───────────────────────────────────────────────────────────────────┘│
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐│
│  │  Dashboards (Grafana)                                             ││
│  │  ┌─────────────────────────────────────────────────────────────┐ ││
│  │  │ Config Manager Overview:                                    │ ││
│  │  │ - Request rate (RPS)                                        │ ││
│  │  │ - Error rate (%)                                            │ ││
│  │  │ - P50/P95/P99 latency                                       │ ││
│  │  │ - Cache hit rate                                            │ ││
│  │  │ - Secret rotation status                                    │ ││
│  │  │ - Top tenants by request volume                             │ ││
│  │  └─────────────────────────────────────────────────────────────┘ ││
│  └───────────────────────────────────────────────────────────────────┘│
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐│
│  │  Alerting (Prometheus Alertmanager)                               ││
│  │  ┌─────────────────────────────────────────────────────────────┐ ││
│  │  │ Alert: HighErrorRate                                        │ ││
│  │  │ Condition: error_rate > 5% for 5 minutes                    │ ││
│  │  │ Action: Page on-call engineer                               │ ││
│  │  │                                                              │ ││
│  │  │ Alert: SecretRotationFailed                                 │ ││
│  │  │ Condition: rotation failure count > 0                       │ ││
│  │  │ Action: Immediate notification                              │ ││
│  │  └─────────────────────────────────────────────────────────────┘ ││
│  └───────────────────────────────────────────────────────────────────┘│
└────────────────────────────────────────────────────────────────────────┘
```

---

**Document Prepared By:** Requirements Analyst Agent
**Date:** 2025-11-21
**Version:** 1.0.0
**Purpose:** Visual reference for architecture discussions and implementation planning
