# LLM-Config-Manager Architecture Design

**Version:** 1.0.0
**Methodology:** SPARC - Architecture Phase
**Date:** 2025-11-21
**Ecosystem:** LLM DevOps

---

## Executive Summary

This document defines the comprehensive architecture for **LLM-Config-Manager**, an enterprise-grade configuration and secrets management system built in Rust. The system provides centralized, secure, and scalable configuration management for the LLM DevOps ecosystem, with deep integration into LLM-Policy-Engine, LLM-Governance-Dashboard, and other ecosystem modules.

### Key Architecture Decisions

1. **Primary Framework:** Axum for REST APIs (modern, ergonomic, excellent Tokio integration)
2. **Alternative:** Actix-web for extreme throughput scenarios
3. **gRPC Framework:** Tonic for service-to-service communication
4. **Cryptography:** Ring for encryption operations (actively maintained, misuse-resistant)
5. **Secrets Backend:** HashiCorp Vault with multi-cloud KMS support (AWS, GCP, Azure)
6. **Deployment Modes:** CLI tool, Microservice API, Sidecar, and Hybrid approaches

---

## Table of Contents

1. [Recommended Rust Crates](#1-recommended-rust-crates)
2. [Deployment Architectures](#2-deployment-architectures)
3. [Component Architecture](#3-component-architecture)
4. [Data Models](#4-data-models)
5. [Integration Patterns](#5-integration-patterns)
6. [Scalability Considerations](#6-scalability-considerations)
7. [Security Architecture](#7-security-architecture)
8. [Performance Targets](#8-performance-targets)

---

## 1. Recommended Rust Crates

### 1.1 Cryptography and Security

#### Primary Crates

| Crate | Version | Purpose | Rationale |
|-------|---------|---------|-----------|
| **ring** | ^0.17 | Core crypto operations | Actively maintained, misuse-resistant API, battle-tested. Preferred over deprecated sodiumoxide |
| **rustls** | ^0.23 | TLS implementation | Modern, memory-safe TLS, excellent performance |
| **argon2** | ^0.5 | Password hashing | Winner of Password Hashing Competition, GPU-resistant |

**ring use cases:**
- AES-GCM encryption for configuration secrets
- HMAC for data integrity verification
- Key derivation (PBKDF2, HKDF)
- Secure random number generation

#### Supplementary Crates

- **chacha20poly1305** (^0.10): Alternative AEAD cipher for ARM/embedded systems without AES-NI
- **ed25519-dalek** (^2.1): Digital signatures for config signing and audit log integrity
- **x509-parser** (^0.16): Certificate parsing for mTLS authentication

### 1.2 Serialization and Configuration

| Crate | Version | Purpose |
|-------|---------|---------|
| **serde** | ^1.0 | Universal serialization framework |
| **serde_json** | ^1.0 | JSON format (REST API, audit logs) |
| **toml** | ^0.8 | TOML format (human-friendly configs) |
| **serde-yaml-ng** | ^0.10 | YAML format (maintained fork, original deprecated) |
| **config** | ^0.14 | Layered configuration management |
| **figment** | ^0.10 | Advanced config aggregation, type-safe |

**Note:** Use `serde-yaml-ng` instead of deprecated `serde_yaml`.

### 1.3 Secrets Backend Integration

#### HashiCorp Vault
- **vaultrs** (^0.7): Most feature-complete async Vault client
  - Supports KV v1/v2, Transit, AppRole, Token, Kubernetes auth
  - Dynamic secrets (AWS, Database)
  - Seal/unseal operations

#### Cloud KMS
- **rusoto_kms** (^0.48): AWS KMS integration for envelope encryption
- **gcp_auth** (^0.12) + **google-cloudkms1** (^5.0): GCP Cloud KMS
- **azure_security_keyvault** (^0.20): Azure Key Vault integration

### 1.4 HTTP/gRPC Servers

#### HTTP Frameworks

| Framework | Version | Best For | Strengths |
|-----------|---------|----------|-----------|
| **axum** | ^0.7 | Modern APIs | Type-safe extractors, Tower ecosystem, intuitive API, lower resource usage |
| **actix-web** | ^4.5 | Extreme throughput | Best benchmark performance, mature ecosystem, actor model |

**Recommendation:** Use **axum** as primary framework for:
- Excellent ergonomics and developer experience
- Modern async patterns with Tokio
- Type-safe middleware and extractors
- Lower memory footprint

**Use actix-web** only when:
- Extreme throughput is critical (>100K req/s per instance)
- Legacy codebase already uses actix ecosystem
- WebSocket support for real-time config sync

#### gRPC
- **tonic** (^0.11): Best-in-class gRPC for Rust
  - Native async/await support
  - Built on hyper and tower
  - Excellent streaming support
  - Code generation from protobuf
- **prost** (^0.12): Protocol Buffers implementation (used by tonic)

#### Supporting Middleware
- **tower** (^0.4): Service abstraction (rate limiting, timeouts, load balancing)
- **tower-http** (^0.5): HTTP middleware (CORS, compression, auth)

### 1.5 Database and Storage

#### SQL
- **sqlx** (^0.7): Async SQL driver with compile-time query verification
  - PostgreSQL for metadata, audit logs, RBAC
  - Features: `runtime-tokio-rustls`, `postgres`, `migrate`

#### Key-Value
- **sled** (^0.34): Embedded database for local caching (pure Rust, ACID)
- **redis** (^0.24): Distributed cache, pub/sub for config updates

### 1.6 Observability and Logging

| Crate | Version | Purpose |
|-------|---------|---------|
| **tracing** | ^0.1 | Structured logging and distributed tracing |
| **tracing-subscriber** | ^0.3 | Tracing output and formatting |
| **metrics** | ^0.22 | Application metrics collection |
| **metrics-exporter-prometheus** | ^0.13 | Prometheus metrics export |

### 1.7 CLI and TUI

| Crate | Version | Purpose |
|-------|---------|---------|
| **clap** | ^4.5 | Command-line parsing (derive macros) |
| **ratatui** | ^0.26 | Terminal UI framework (modern tui-rs fork) |
| **crossterm** | ^0.27 | Cross-platform terminal manipulation |
| **indicatif** | ^0.17 | Progress bars and spinners |

### 1.8 Testing and Validation

- **validator** (^0.18): Data validation with derive macros
- **jsonschema** (^0.17): JSON Schema validation
- **mockall** (^0.12): Mocking framework for unit tests
- **wiremock** (^0.6): HTTP mocking for integration tests
- **proptest** (^1.4): Property-based testing for crypto/config logic

---

## 2. Deployment Architectures

### 2.1 CLI Management Tool

**Architecture Type:** Standalone Binary

#### Description
Single-binary CLI tool for local configuration management and administrative operations.

#### Components
- Command-line interface (clap)
- Local configuration cache (sled)
- Vault/KMS client integration
- Configuration editor and validator
- Audit log viewer
- Export/import utilities

#### Deployment Model
- **Packaging:** Native binaries (Linux, macOS, Windows), Docker container
- **Distribution:** GitHub Releases, Homebrew, apt/yum, cargo install
- **Updates:** Auto-update capability via GitHub releases

#### Use Cases
- Developer workstation configuration management
- CI/CD pipeline configuration injection
- Emergency configuration rollback
- Local development with offline-first support
- Administrative operations (key rotation, policy updates)

#### Advantages
- Zero infrastructure required
- Fast local operations with caching
- Works offline with cached configs
- Easy to install and update
- Low latency for development workflows

#### Security Model
- **Authentication:** User-provided vault tokens or API keys
- **Authorization:** Inherits user's vault/KMS permissions
- **Secrets Storage:** OS keychain integration (keyring-rs)
- **Encryption at Rest:** Local cache encrypted with user key

#### Scalability
- **Target Scale:** Individual developers and small teams
- **Performance:** Local ops <10ms, Vault ops <100ms

---

### 2.2 Microservice API Server

**Architecture Type:** Centralized Service

#### Description
Always-on API server providing centralized configuration management with caching, authentication, and audit logging.

#### Components
- HTTP/REST API (axum)
- gRPC API (tonic) for service-to-service
- Authentication/Authorization layer (JWT, mTLS)
- Distributed cache (Redis)
- Audit logging (PostgreSQL)
- Metrics and monitoring (Prometheus)
- Health checks and readiness probes

#### Deployment Model: Kubernetes

```yaml
Deployment: 3+ replicas with HPA
Resources:
  Requests: 256Mi memory, 100m CPU
  Limits: 1Gi memory, 1000m CPU
Services:
  - ClusterIP for internal access
  - Ingress for external REST API
  - Headless service for gRPC
Config:
  - ConfigMap for app configuration
  - Secret for vault credentials
  - PVC for local cache (optional)
```

#### API Design

**REST API** (`/api/v1`)
- `GET /configs/{namespace}/{key}` - Get configuration
- `POST /configs/{namespace}/{key}` - Create configuration
- `PUT /configs/{namespace}/{key}` - Update configuration
- `DELETE /configs/{namespace}/{key}` - Delete configuration
- `GET /configs/{namespace}?environment={env}` - List configs
- `GET /configs/{namespace}/history` - Version history
- `POST /configs/{namespace}/validate` - Validate config
- `POST /configs/bulk` - Bulk operations
- `GET /health` - Health check
- `GET /metrics` - Prometheus metrics

**gRPC API**
- `ConfigService` - CRUD operations
- `WatchService` - Streaming config updates
- `ValidateService` - Schema validation
- `AuditService` - Query audit logs

#### Use Cases
- Centralized configuration service for microservices
- Multi-tenant configuration management
- Audit and compliance requirements
- Configuration as a service (CaaS)
- GitOps-driven configuration updates
- Real-time configuration distribution

#### Advantages
- Centralized access control and auditing
- High availability and redundancy
- Horizontal scalability
- Consistent configuration across environments
- Rate limiting and quota management
- Built-in observability

#### Security Model
- **Authentication:** Bearer token (JWT), mTLS, API key, OAuth2/OIDC
- **Authorization:** Policy-based access control via LLM-Policy-Engine, namespace-level permissions, RBAC
- **Encryption:** TLS 1.3 for all communications, end-to-end encryption for sensitive configs, encrypted cache at rest

#### Scalability
- **Target Scale:** Enterprise-wide deployment
- **Concurrent Users:** 10,000+ clients
- **Throughput:** 50,000+ req/s with caching
- **Latency:** p50 <5ms (cached), p99 <50ms (vault miss)
- **Availability:** 99.99% uptime SLA

#### Caching Strategy
- **L1:** In-memory LRU cache (per-instance)
- **L2:** Distributed Redis cache (cluster-wide)
- **L3:** Vault/KMS (source of truth)
- **TTL:** Configurable per namespace (default: 5m)
- **Invalidation:** Pub/sub based on Redis

---

### 2.3 Sidecar Integration Mode

**Architecture Type:** Container Sidecar Pattern

#### Description
Lightweight sidecar container running alongside application pods, providing local configuration caching and automatic refresh.

#### Components
- Minimal HTTP server for local queries
- Configuration synchronization agent
- Local file system cache
- Health monitoring and auto-recovery
- Unix domain socket for IPC

#### Deployment Model: Kubernetes

```yaml
Deployment: Sidecar container in application pods
Injection: Manual or admission webhook
Resources:
  Requests: 64Mi memory, 50m CPU
  Limits: 256Mi memory, 200m CPU
Volumes:
  - emptyDir for config cache
  - ConfigMap for sidecar config
  - Secret for vault credentials
InitContainer: Pre-populate cache before app starts
```

#### Communication Methods
- Unix domain sockets (lowest latency)
- localhost HTTP (127.0.0.1:8080)
- Shared volume (file-based)

#### Use Cases
- Low-latency config access for applications
- Offline resilience with local caching
- Zero code changes in application
- Automatic configuration refresh
- Kubernetes-native deployments
- Multi-language application support

#### Advantages
- Sub-millisecond config access (local)
- No network latency for cached configs
- Automatic sync in background
- Application remains unaware of config complexity
- Works during network partitions
- Language-agnostic (any app can use)

#### Sync Strategy
- **Modes:** Polling, Push (WebSocket/gRPC streaming), Hybrid
- **Default Interval:** 30 seconds with random jitter
- **Backoff:** Exponential backoff on failures

#### Cache Management
- **Storage:** In-memory + file system for persistence
- **Eviction:** LRU with size limits
- **Warming:** Pre-fetch configs on startup

#### Security Model
- **Authentication:** Pod service account token
- **Authorization:** Namespace and pod-level restrictions
- **Encryption:** Configs encrypted at rest in cache
- **Isolation:** Process isolation, no shared state between apps

#### Scalability
- **Target Scale:** Thousands of sidecars per cluster
- **Pod Overhead:** ~50-100Mi memory per sidecar
- **Latency:** p99 <1ms for cached reads

---

### 2.4 Hybrid Deployment

**Architecture Type:** Multi-Mode

#### Description
Combination of microservice API server with optional sidecar injection for high-performance applications.

#### Architecture
- **Central:** Microservice API server (3+ replicas)
- **Edge:** Sidecar containers in critical pods
- **Admin:** CLI tool for operations
- **CDN:** Optional edge cache (Cloudflare Workers, AWS Lambda@Edge)

#### Routing Strategy
- **Low-latency apps:** Use sidecar for p99 <5ms
- **Standard apps:** Direct API calls to central server
- **Admin ops:** CLI tool for management
- **Public configs:** Edge cache for geo-distribution

#### Decision Tree

**Use Sidecar If:**
- Application requires p99 latency <5ms
- High read volume (>1000 req/s per pod)
- Critical path operations depend on config
- Offline resilience required

**Use Central API If:**
- Moderate latency acceptable (<50ms)
- Low to medium read volume
- Strong consistency required
- Simplified operations preferred

**Use CLI For:**
- Administrative operations
- CI/CD integration
- Manual interventions
- Development workflows

#### Advantages
- Best of both worlds (centralization + performance)
- Flexible deployment per application needs
- Cost-effective resource utilization
- Gradual adoption and migration
- Supports diverse application requirements

#### Scalability
- **Target Scale:** Global deployments, 100K+ clients
- **Cost Optimization:** Sidecars only for <5% of pods needing ultra-low latency

---

## 3. Component Architecture

### 3.1 System Layers

```
┌─────────────────────────────────────────────────────────────┐
│                   Presentation Layer                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────────┐      │
│  │ REST API │  │ gRPC API │  │   CLI Interface      │      │
│  │  (axum)  │  │ (tonic)  │  │ (clap + ratatui)     │      │
│  └──────────┘  └──────────┘  └──────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                   Application Layer                          │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │ Config Engine   │  │ Secrets Manager │                  │
│  │ - Resolution    │  │ - Encryption    │                  │
│  │ - Templating    │  │ - Key Rotation  │                  │
│  │ - Validation    │  │ - Lifecycle     │                  │
│  └─────────────────┘  └─────────────────┘                  │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │ Policy Engine   │  │  Audit Logger   │                  │
│  │ Integration     │  │  - Event Capture│                  │
│  │ - RBAC          │  │  - Persistence  │                  │
│  │ - Validation    │  │  - Integrity    │                  │
│  └─────────────────┘  └─────────────────┘                  │
│  ┌─────────────────┐                                        │
│  │ Cache Manager   │                                        │
│  │ - L1: Memory    │                                        │
│  │ - L2: Redis     │                                        │
│  │ - L3: Disk      │                                        │
│  └─────────────────┘                                        │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                   Integration Layer                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Vault        │  │ Cloud KMS    │  │ Policy Engine│     │
│  │ Adapter      │  │ Adapters     │  │ Adapter      │     │
│  │ (vaultrs)    │  │ AWS/GCP/Azure│  │ (gRPC)       │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Governance   │  │ Observatory  │  │ Edge Agent   │     │
│  │ Dashboard    │  │ (Metrics)    │  │ Integration  │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                   Data Layer                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Vault/KMS    │  │ PostgreSQL   │  │ Redis/Sled   │     │
│  │ (Primary)    │  │ (Metadata)   │  │ (Cache)      │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Core Components

#### Configuration Engine
- **ConfigResolver:** Hierarchical config resolution with environment overrides
- **TemplateEngine:** Variable substitution and templating (Handlebars-style)
- **Validator:** Schema and business rule validation
- **VersionManager:** Version control and history tracking

#### Secrets Manager
- **EncryptionService:** AES-GCM/ChaCha20-Poly1305 encryption
- **KeyManager:** KEK management and rotation
- **SecretStore:** In-memory secure storage with zeroization

#### Policy Engine Integration
- **RBACEnforcer:** Role-based access control evaluation
- **PolicyValidator:** Policy syntax and semantic validation
- **PolicyClient:** gRPC communication with LLM-Policy-Engine

#### Audit Logger
- **Event Capture:** Intercept all significant operations
- **Persistence:** PostgreSQL with partitioning by time
- **Integrity:** Cryptographic log integrity (Merkle trees)
- **Query API:** Flexible audit log querying

#### Cache Manager
- **L1 Cache:** In-memory LRU (per-instance)
- **L2 Cache:** Redis distributed cache
- **L3 Cache:** Local disk cache (sled)
- **Invalidation:** Pub/sub based cache invalidation

### 3.3 Data Flow Examples

#### Config Read Path
1. Client sends `GET /configs/{namespace}/{key}`
2. REST API authenticates and authorizes request
3. Cache Manager checks L1 (in-memory) cache → **HIT:** Return immediately
4. If miss, check L2 (Redis) cache → **HIT:** Store in L1, return
5. If miss, fetch from Vault via adapter
6. Decrypt if encrypted, validate schema
7. Store in L2 and L1 caches
8. Return to client
9. Log audit event asynchronously

#### Config Write Path
1. Client sends `POST /configs/{namespace}/{key}` with new value
2. REST API authenticates and authorizes request
3. Policy Engine validates write permission
4. Configuration Engine validates schema
5. Secrets Manager encrypts sensitive fields
6. Vault Adapter writes to Vault
7. Metadata Store saves version and metadata to PostgreSQL
8. Cache invalidation broadcast via Redis pub/sub
9. All cache layers invalidate the key
10. Audit Logger records write event
11. Governance Dashboard notified via WebSocket

#### Secret Rotation Path
1. Scheduler triggers rotation for expired secret
2. Secrets Manager generates new secret value
3. Cloud KMS generates new DEK (data encryption key)
4. Re-encrypt secret with new DEK
5. Store new secret version in Vault
6. Update metadata with rotation timestamp
7. Invalidate all caches for this secret
8. Notify dependent services (optional)
9. Log rotation event to audit log

---

## 4. Data Models

### 4.1 Configuration Schema

```rust
struct Configuration {
    id: Uuid,
    namespace: String,           // e.g., "production/ml-service"
    key: String,                 // e.g., "database.url"
    value: ConfigValue,          // Nested value (can be object/array)
    value_type: ValueType,       // String, Number, Boolean, Object, Array, Secret
    encrypted: bool,
    encryption_key_id: Option<String>,
    schema_version: String,
    metadata: ConfigMetadata,
    tags: HashMap<String, String>,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
    created_by: String,
    updated_by: String,
}

enum ConfigValue {
    String(String),
    Number(f64),
    Boolean(bool),
    Object(HashMap<String, ConfigValue>),
    Array(Vec<ConfigValue>),
    Secret(EncryptedValue),
}

struct EncryptedValue {
    ciphertext: Vec<u8>,
    nonce: Vec<u8>,
    algorithm: Algorithm,         // AES256-GCM, ChaCha20-Poly1305
    key_id: String,
    envelope: Option<EnvelopeData>,
}

struct EnvelopeData {
    encrypted_dek: Vec<u8>,       // Encrypted data encryption key
    kek_id: String,               // Key encryption key identifier
    kms_provider: KMSProvider,    // AWS_KMS, GCP_KMS, Azure_KeyVault, Vault
}
```

### 4.2 Namespace Organization

```
Hierarchical namespace structure:

/ (root)
├── production/
│   ├── ml-service/
│   │   ├── inference/
│   │   ├── training/
│   │   └── monitoring/
│   └── api-gateway/
├── staging/
└── development/
```

```rust
struct Namespace {
    id: Uuid,
    path: String,                 // "prod/ml-service/inference"
    parent_id: Option<Uuid>,
    name: String,                 // "inference"
    metadata: NamespaceMetadata,
    permissions: Vec<Permission>,
    created_at: DateTime<Utc>,
}

struct NamespaceMetadata {
    description: String,
    owner_team: String,
    contacts: Vec<String>,        // Email addresses
    cost_center: Option<String>,
    tags: HashMap<String, String>,
}
```

### 4.3 Environment Hierarchy

```
Inheritance chain:
base → development → staging → production

Config resolution: production (specific) → staging → development → base (defaults)
```

```rust
struct Environment {
    name: String,                 // "development", "staging", "production"
    tier: Tier,                   // Development, Test, Staging, Production
    parent: Option<String>,       // Parent environment for inheritance
    promotion_order: u32,         // Order in promotion pipeline
    auto_promote: bool,           // Auto-promote configs from parent
    require_approval: bool,       // Require approval for changes
    approvers: Vec<String>,       // Users who can approve
}

enum Tier {
    Development,
    Test,
    Staging,
    Production,
}
```

### 4.4 Version History

```rust
struct ConfigVersion {
    id: Uuid,
    config_id: Uuid,
    version_number: u64,          // Monotonically increasing
    value: ConfigValue,
    change_type: ChangeType,      // Create, Update, Delete, Restore
    changed_by: String,
    changed_at: DateTime<Utc>,
    change_reason: Option<String>, // Commit message
    diff: Option<String>,         // JSON patch
    git_commit: Option<String>,   // Git commit hash (GitOps)
    rollback_to: Option<Uuid>,    // Version ID if rollback
}

enum ChangeType {
    Create,
    Update,
    Delete,
    Restore,
}
```

### 4.5 Secret Types

```rust
struct Secret {
    id: Uuid,
    namespace: String,
    key: String,
    secret_type: SecretType,
    encrypted_value: EncryptedValue,
    rotation_policy: RotationPolicy,
    expires_at: Option<DateTime<Utc>>,
    metadata: SecretMetadata,
}

enum SecretType {
    GenericSecret,
    ApiKey { provider: String, scopes: Vec<String> },
    DatabaseCredentials {
        host: String,
        port: u16,
        database: String,
        username: String,
        password: String,
    },
    Certificate {
        cert_pem: String,
        private_key_pem: String,
        ca_chain: Option<String>,
    },
    SSHKey {
        public_key: String,
        private_key: String,
    },
    OAuthToken {
        access_token: String,
        refresh_token: Option<String>,
        expires_in: i64,
    },
    JWTSigningKey {
        algorithm: String,
        public_key: String,
        private_key: String,
    },
}

struct RotationPolicy {
    enabled: bool,
    interval: Duration,           // e.g., 90 days
    auto_rotate: bool,
    grace_period: Duration,       // Old secret valid for grace period
    last_rotated: DateTime<Utc>,
    next_rotation: DateTime<Utc>,
    rotation_notification: Vec<String>, // Email addresses
}
```

### 4.6 Audit and RBAC

```rust
struct AuditLog {
    id: Uuid,
    timestamp: DateTime<Utc>,
    event_type: AuditEventType,
    actor: Actor,
    resource: Resource,
    action: String,               // read, write, delete
    result: Result,               // Success, Failure, Denied
    ip_address: Option<String>,
    user_agent: Option<String>,
    request_id: String,
    metadata: HashMap<String, String>,
}

enum AuditEventType {
    ConfigRead,
    ConfigWrite,
    ConfigDelete,
    SecretAccess,
    SecretRotation,
    PolicyViolation,
    Authentication,
    AuthorizationFailure,
    PermissionChange,
    NamespaceCreated,
    NamespaceDeleted,
}

struct Role {
    id: Uuid,
    name: String,                 // "admin", "developer", "viewer", "operator"
    description: String,
    permissions: Vec<Permission>,
    inherits_from: Vec<Uuid>,     // Parent roles for inheritance
    created_at: DateTime<Utc>,
}

struct Permission {
    resource: String,             // Resource pattern, e.g., "configs:prod/*"
    actions: Vec<Action>,         // Read, Write, Delete, List, Approve, etc.
    effect: Effect,               // Allow, Deny
    conditions: Option<Vec<Condition>>,
}

enum Action {
    Read,
    Write,
    Delete,
    List,
    Approve,
    Rotate,
    Grant,
    Admin,
}

struct RoleBinding {
    id: Uuid,
    role_id: Uuid,
    subject: Subject,             // User, service account, or group
    namespace: String,            // Namespace scope
    created_at: DateTime<Utc>,
    expires_at: Option<DateTime<Utc>>, // Temporary role binding
}
```

---

## 5. Integration Patterns

### 5.1 LLM-Policy-Engine Integration

**Purpose:** Validation policies and RBAC enforcement

**Integration Type:** Synchronous gRPC
**Protocol:** gRPC over HTTP/2, mTLS authentication, Protocol Buffers

#### Data Flow

**Config-Manager → Policy-Engine:**
- `EvaluatePermission(actor, resource, action)` → Allow/Deny
- `ValidateConfiguration(config, schema, policies)` → ValidationResult
- `GetEffectivePermissions(actor, namespace)` → PermissionSet
- `CheckCompliance(config, compliance_tags)` → ComplianceReport

**Policy-Engine → Config-Manager:**
- `OnPolicyChange(policy_id)` → notification
- `OnRoleUpdate(role_id)` → notification

#### Caching
- Permission cache TTL: 5 minutes
- Policy cache TTL: 10 minutes
- Invalidation: Push-based via pub/sub

#### Fallback Strategy
- **On Policy Engine Unavailable:** Use cached permissions with limited TTL
- **Fail Open:** No (default deny)
- **Default Policy:** Deny all, allow read for authenticated users

#### Integration Patterns

**1. Pre-request Authorization**
```
1. Receive config operation request
2. Extract actor and resource from request
3. Call Policy-Engine.EvaluatePermission()
4. If denied, return 403 Forbidden
5. If allowed, proceed with operation
```

**2. Post-write Validation**
```
1. Configuration written to vault
2. Call Policy-Engine.ValidateConfiguration()
3. If validation fails, rollback or quarantine
4. Log validation results to audit log
```

**3. Policy Synchronization**
```
1. Policy-Engine publishes policy update event
2. Config-Manager receives notification
3. Invalidate local policy cache
4. Fetch updated policies lazily on next request
```

---

### 5.2 LLM-Governance-Dashboard Integration

**Purpose:** Visibility and audit surfacing

**Integration Type:** Asynchronous HTTP/REST + WebSocket
**Protocol:** HTTP/REST for queries, WebSocket for live updates, JWT authentication, JSON format

#### Data Flow

**Config-Manager → Governance-Dashboard:**
- `StreamAuditLogs()` → WebSocket stream
- `PushMetrics(metrics)` → async
- `NotifyConfigChange(change_event)` → async
- `NotifyPolicyViolation(violation)` → async
- `ReportHealth(health_status)` → async

**Governance-Dashboard → Config-Manager:**
- `QueryAuditLogs(filter)` → paginated results
- `GetMetricsSummary()` → aggregated metrics
- `GetConfigSnapshot(namespace)` → current state
- `GetComplianceReport()` → compliance status

#### Event Streaming
- **Mechanism:** WebSocket with JSON messages
- **Events:** `config.created`, `config.updated`, `config.deleted`, `secret.accessed`, `secret.rotated`, `policy.violated`, `permission.denied`, `health.degraded`
- **Batching:** Batch events every 1 second or 100 events
- **Backpressure:** Drop oldest events if buffer exceeds 10,000

#### Metrics Export
- **Endpoint:** `POST /api/v1/metrics`
- **Frequency:** Every 30 seconds
- **Format:** Prometheus-compatible JSON
- **Metrics:**
  - `config_operations_total{operation, namespace, status}`
  - `secret_access_total{namespace, secret_type}`
  - `cache_hit_ratio{layer}`
  - `vault_latency_seconds{operation}`
  - `policy_evaluation_duration_seconds`
  - `active_configurations{namespace, environment}`

---

### 5.3 LLM-Observatory Integration

**Purpose:** Metrics, tracing, and observability

**Integration Type:** Pull-based metrics + Push-based tracing
**Protocol:** Prometheus scraping (HTTP), OpenTelemetry over gRPC, JSON logs to stdout

#### Data Flow

**Observatory → Config-Manager:**
- `GET /metrics` → Prometheus format metrics (scrape every 15 seconds)

**Config-Manager → Observatory:**
- `PushTraces(spans)` → OpenTelemetry Collector
- `PushLogs(log_entries)` → Fluentd/Vector

#### Metrics Categories

**Request Metrics:**
- `http_requests_total{method, path, status}`
- `http_request_duration_seconds{method, path}`
- `grpc_requests_total{service, method, status}`
- `grpc_request_duration_seconds{service, method}`

**Application Metrics:**
- `configs_total{namespace, environment}`
- `secrets_total{namespace, type}`
- `cache_hits_total{layer}`
- `cache_misses_total{layer}`
- `vault_operations_total{operation, status}`
- `policy_evaluations_total{result}`
- `audit_events_total{event_type}`

**System Metrics:**
- `process_cpu_seconds_total`
- `process_resident_memory_bytes`
- `process_open_fds`
- `tokio_workers_active`

#### Tracing
- **Library:** tracing + tracing-opentelemetry
- **Sampling:** Always trace errors, 10% sampling for success
- **Spans:** `http_request`, `vault_read`, `vault_write`, `cache_get`, `policy_evaluate`, `db_query`
- **Attributes:** `request_id`, `actor`, `namespace`, `environment`, `tenant_id`

#### Logging
- **Format:** JSON structured logs
- **Levels:** ERROR, WARN, INFO, DEBUG, TRACE
- **Fields:** `timestamp`, `level`, `message`, `target`, `span`, `fields`, `request_id`

---

### 5.4 LLM-Edge-Agent Integration

**Purpose:** Edge configuration distribution and offline support

**Integration Type:** Bidirectional gRPC streaming
**Protocol:** gRPC over HTTP/2 with TLS, mTLS + API key authentication, Protocol Buffers

#### Data Flow

**Config-Manager → Edge-Agent:**
- `SyncConfigurations(namespace, version)` → ConfigBatch
- `StreamUpdates()` → bidirectional stream
- `GetConfigDiff(from_version, to_version)` → Diff

**Edge-Agent → Config-Manager:**
- `ReportHealth(health)` → ack
- `RequestSync(namespace)` → sync initiated
- `ReportConflict(conflict)` → resolution

#### Sync Protocol
- **Mode:** Delta synchronization with version vectors
- **Compression:** gzip for large config batches
- **Deduplication:** Content-addressed storage with SHA-256
- **Conflict Resolution:** Last-write-wins with version vectors
- **Offline Support:** Yes

#### Edge Caching
- **Storage:** Local sled database on edge device
- **Max Cache Size:** 100MB per agent
- **Eviction:** LRU with priority based on access frequency
- **Staleness Tolerance:** Up to 1 hour for non-critical configs

#### Integration Patterns

**1. Incremental Sync**
```
1. Edge agent sends last known version
2. Config-Manager computes delta
3. Send compressed diff
4. Edge agent applies diff and updates version
```

**2. Offline-First Operation**
```
1. Network partition occurs
2. Edge agent uses local cache
3. Queue local changes (if any)
4. On reconnection, sync bidirectionally
5. Resolve conflicts using version vectors
```

**3. Selective Sync**
```
1. Edge agent registers with subscriptions
2. Only receive updates for subscribed namespaces
3. Reduces bandwidth and storage
```

---

### 5.5 LLM-Auto-Optimizer Integration

**Purpose:** Configuration optimization feedback loop

**Integration Type:** Asynchronous REST API
**Protocol:** HTTP/REST, API key authentication, JSON format

#### Data Flow

**Auto-Optimizer → Config-Manager:**
- `ProposeConfigChange(namespace, key, new_value, justification)` → change_request_id
- `GetCurrentConfig(namespace)` → config_snapshot
- `GetConfigPerformanceMetrics(namespace)` → metrics

**Config-Manager → Auto-Optimizer:**
- `NotifyConfigApplied(change_request_id, applied_at)` → ack
- `NotifyConfigRejected(change_request_id, reason)` → ack

#### Optimization Workflow
```
1. Auto-Optimizer analyzes system performance
2. Identifies suboptimal configurations
3. Proposes configuration changes to Config-Manager
4. Config-Manager validates against policies
5. If approved, applies change and notifies Auto-Optimizer
6. Auto-Optimizer monitors impact
7. If negative impact, rollback is triggered
```

#### Approval Modes
- **Automatic:** For non-production, low-risk changes
- **Manual:** For production, require human approval
- **Dry-run:** Simulate but don't apply

#### Integration Patterns

**1. Propose-Approve-Apply**
```
1. Auto-Optimizer proposes change
2. Config-Manager validates and creates change request
3. Approval workflow triggered (if required)
4. On approval, apply change
5. Monitor for rollback conditions
```

**2. A/B Testing Configurations**
```
1. Create A/B test configuration variants
2. Apply variant A to 90% of instances, variant B to 10%
3. Monitor performance metrics
4. If B outperforms A, promote to 100%
```

---

## 6. Scalability Considerations

### 6.1 Read Throughput

**Target:** 100,000+ reads/second

**Strategies:**
- Multi-tier caching (in-memory, Redis, local disk)
- Read replicas for PostgreSQL metadata store
- Content-delivery network for static/public configs
- Horizontal scaling with stateless API servers
- gRPC multiplexing for service-to-service calls

**Bottlenecks:**
- Vault read throughput → Mitigated by aggressive caching (95%+ hit ratio)
- Redis single-instance limits → Use Redis Cluster
- Database connection pool exhaustion → Use connection pooling (sqlx)

---

### 6.2 Write Throughput

**Target:** 10,000+ writes/second

**Strategies:**
- Asynchronous vault writes with write-behind caching
- Batch writes for bulk operations
- Sharded PostgreSQL for audit logs (partition by time)
- Async audit logging with buffering
- Optimistic locking for concurrent updates

**Bottlenecks:**
- Vault write throughput → Vault Enterprise clustering
- PostgreSQL write throughput → Partitioning, sharding
- Audit log write volume → Async with batching

---

### 6.3 Storage Capacity

**Target:** Millions of configurations

**Strategies:**
- Vault as primary storage (unlimited in cloud KMS)
- PostgreSQL partitioning by namespace and time
- Compression for large configuration values
- Archival of old versions to object storage (S3, GCS)
- Deduplication using content addressing

**Considerations:**
- Vault storage limits depend on backend (Consul, S3, etc.)
- PostgreSQL table partitioning for audit logs (by month)
- Retention policies for old versions (e.g., keep last 100 versions)

---

### 6.4 Geographic Distribution

**Target:** Multi-region, low-latency access

**Strategies:**
- Regional Config-Manager deployments
- Vault replication (Vault Enterprise)
- Redis replication across regions
- Edge caching with CDN
- Active-active multi-region with eventual consistency

**Patterns:**

| Pattern | Consistency | Latency |
|---------|-------------|---------|
| **Active-Passive** | Strong consistency | Cross-region on failover |
| **Active-Active** | Eventual consistency | Local region latency |
| **Read Replicas** | Read-after-write consistency | Local reads, cross-region writes |

---

### 6.5 Tenant Isolation

**Target:** 10,000+ tenants on shared infrastructure

**Strategies:**
- Namespace-based isolation
- Per-tenant rate limiting
- Separate vault paths per tenant
- Tenant-aware caching (avoid cross-tenant leaks)
- Resource quotas per tenant
- Dedicated instances for high-value tenants

**Security:**
- No shared cache keys between tenants
- Tenant ID validation on every request
- Separate encryption keys per tenant
- Audit logging per tenant

---

### 6.6 Failover and High Availability

**Target:** 99.99% uptime (52 minutes downtime/year)

**Strategies:**
- Multi-zone Kubernetes deployments
- Stateless API servers (easy to scale and replace)
- Redis Sentinel for cache HA
- PostgreSQL streaming replication
- Health checks and auto-recovery
- Circuit breakers to prevent cascade failures
- Graceful degradation (serve from cache if Vault unavailable)

**Failure Modes:**

| Failure | Mitigation | Impact |
|---------|------------|--------|
| **Vault unavailable** | Serve from Redis/local cache with TTL | Stale configs for TTL duration |
| **PostgreSQL down** | Failover to read replica, queue writes | Audit logging delayed |
| **Redis down** | Fall back to Vault (slower) | Higher latency, increased Vault load |
| **Single API server down** | Kubernetes auto-restarts, load balancer reroutes | Minimal (other replicas handle traffic) |

---

### 6.7 Cost Optimization

**Target:** Minimize cloud costs at scale

**Strategies:**
- Aggressive caching to reduce Vault API calls
- Compression for network transfer and storage
- Spot instances for non-critical workloads
- Auto-scaling based on load (scale down during off-hours)
- Archival to cheaper storage tiers (S3 Glacier)
- Right-sizing resources based on actual usage
- Sidecar mode to reduce API server load

**Monitoring:**
- Track cost per tenant
- Monitor cache hit ratios (target >95%)
- Alert on cost anomalies
- Periodic cost optimization reviews

---

### 6.8 Operational Complexity

**Target:** Simple to deploy and operate

**Strategies:**
- Single-binary deployment (minimize dependencies)
- Helm charts for Kubernetes
- Terraform modules for infrastructure
- Automated backups and DR testing
- Runbooks for common operations
- Self-service CLI for developers
- Comprehensive observability (metrics, logs, traces)
- Automated testing (unit, integration, load tests)

**Day-2 Operations:**
- Vault key rotation procedures
- Database schema migrations (sqlx migrations)
- Config-Manager version upgrades (blue/green deployments)
- Disaster recovery drills
- Security patching

---

## 7. Security Architecture

### 7.1 Encryption

#### At Rest
- All secrets encrypted with AES-256-GCM
- Envelope encryption with KMS
- Database encryption (PostgreSQL TDE)
- Redis encryption (requirepass + TLS)
- Local cache encryption (sled with encrypted values)

#### In Transit
- TLS 1.3 for all HTTP/gRPC communications
- mTLS for service-to-service
- Certificate pinning for critical connections
- Perfect forward secrecy (PFS)

#### Key Management
- KEK (Key Encryption Key) managed by cloud KMS
- DEK (Data Encryption Key) generated per-config
- Automatic key rotation every 90 days
- Old keys retained for decryption (key versioning)
- Hardware Security Module (HSM) support via KMS

---

### 7.2 Authentication

**Methods:**
- JWT tokens (RS256/ES256 signatures)
- API keys (for legacy clients)
- mTLS client certificates
- OAuth2/OIDC (integration with enterprise IdP)
- Kubernetes service account tokens

**Token Lifecycle:**
- Short-lived access tokens (15 minutes)
- Refresh tokens (7 days)
- Token revocation support
- Token rotation on suspicious activity

---

### 7.3 Authorization

**Model:** Attribute-Based Access Control (ABAC) with RBAC foundation

**Enforcement Points:**
- API gateway (coarse-grained)
- Application layer (fine-grained)
- Policy Engine integration (complex rules)

**Principles:**
- Principle of least privilege
- Defense in depth (multiple layers)
- Fail-safe defaults (deny by default)
- Separation of duties

---

### 7.4 Audit and Compliance

**Audit Trail:**
- Immutable audit logs
- Cryptographic log integrity (Merkle trees)
- Tamper-evident log storage
- Retention: 7 years for compliance

**Compliance Frameworks:**
- SOC 2 Type II
- PCI DSS
- HIPAA
- GDPR
- ISO 27001

**Controls:**
- Access logging for all config/secret operations
- Data residency controls (geo-fencing)
- Right to be forgotten (GDPR)
- Encryption at rest and in transit
- Regular security audits and penetration testing

---

### 7.5 Secrets Hygiene

**Practices:**
- Never log secrets (redact from logs/traces)
- Secrets never in git (enforce with pre-commit hooks)
- Automatic secret scanning (TruffleHog, GitGuardian)
- Secret rotation enforcement
- Expiration warnings
- Revocation on employee offboarding

---

## 8. Performance Targets

### 8.1 Latency

| Operation | p50 | p99 | p99.9 |
|-----------|-----|-----|-------|
| **Config Read (Cached)** | < 1ms | < 5ms | < 10ms |
| **Config Read (Vault)** | < 20ms | < 50ms | < 100ms |
| **Config Write** | < 50ms | < 200ms | < 500ms |
| **Policy Evaluation** | < 5ms | < 20ms | < 50ms |

### 8.2 Throughput

- **Reads:** 100,000+ req/s with caching
- **Writes:** 10,000+ req/s
- **Cache Hit Ratio:** > 95%

### 8.3 Resource Usage

**API Server:**
- Memory: 512Mi - 2Gi (depending on cache size)
- CPU: 0.5 - 2 cores

**Sidecar:**
- Memory: 64Mi - 256Mi
- CPU: 0.05 - 0.2 cores

---

## 9. Security Architecture (Detailed)

### 9.1 Security Principles

#### Zero-Trust Architecture

**Core Tenets:**
- Never trust, always verify - authenticate and authorize every request
- Assume breach - design for containment and rapid response
- Least privilege - grant minimum necessary permissions
- Verify explicitly - cryptographic identity verification for all entities

**Implementation:**
- Mutual TLS (mTLS) for all inter-service communication
- No implicit trust between services or users
- Continuous authentication and authorization
- Network micro-segmentation with strict policies
- Identity-based access (not network location-based)

#### Defense in Depth

The security architecture implements multiple overlapping layers of security controls:

```
Layer 7: Compliance & Governance (SOC 2, GDPR, HIPAA)
Layer 6: Audit & Monitoring (Immutable logs, real-time alerting)
Layer 5: Application Security (Input validation, RBAC/ABAC)
Layer 4: Data Security (Field-level encryption, envelope encryption)
Layer 3: Communication Security (TLS 1.3, mTLS)
Layer 2: Identity & Access Management (Strong auth, MFA)
Layer 1: Infrastructure Security (Network segmentation, container security)
```

### 9.2 Encryption Stack

#### At-Rest Encryption

**Primary Algorithm:** AES-256-GCM (Galois/Counter Mode)

**Rationale:**
- Authenticated encryption (confidentiality + integrity)
- NIST recommended, FIPS 140-2 approved
- Hardware acceleration (AES-NI) on modern CPUs
- Parallelizable for high performance

**Rust Crate:** `aes-gcm` (^0.10) from RustCrypto

**Alternative for ARM/Embedded:** ChaCha20-Poly1305

**Rust Crate:** `chacha20poly1305` (^0.10)

**Rationale:** Better performance on systems without AES-NI hardware support

#### Envelope Encryption Pattern

```
Configuration Value (Plaintext)
         ↓
Generate DEK (Data Encryption Key)
         ↓
Encrypt config with DEK → Encrypted Config
         ↓
Encrypt DEK with KEK from KMS
         ↓
Store: {encrypted_config, encrypted_dek, kek_id}
```

**Benefits:**
- KEK never leaves KMS (highest security)
- DEK rotation without re-encrypting all data
- Unlimited data size (not limited by KMS)
- Multi-cloud portability
- Per-tenant isolation with separate KEKs

#### Key Management

**Key Hierarchy:**
```
Root Key (HSM) - Never exported, rotated annually
    ↓
Master KEK (KMS) - Per-tenant, rotated every 90 days
    ↓
Data Encryption Keys (DEK) - Per-config, rotated on KEK rotation
    ↓
Encrypted Configuration Data
```

**Rotation Schedule:**
- **Root Keys (HSM)**: Annually (manual, high ceremony)
- **KEKs (KMS)**: Every 90 days (automated)
- **DEKs**: On KEK rotation (lazy re-encryption)
- **TLS Certificates**: Every 24 hours (short-lived, automated)
- **API Keys**: Every 90 days with 7-day grace period
- **Database Credentials**: Every 30 days with 24-hour grace period

#### In-Transit Encryption

**TLS 1.3 Configuration**

**Cipher Suites (Ordered by Preference):**
1. `TLS_AES_256_GCM_SHA384` - Highest security, AEAD, hardware accelerated
2. `TLS_CHACHA20_POLY1305_SHA256` - Software-optimized, mobile-friendly
3. `TLS_AES_128_GCM_SHA256` - Performance-optimized, still secure

**Rust Crate:** `rustls` (^0.23)

**Rationale:**
- Memory-safe, modern TLS stack
- Outperforms OpenSSL in many scenarios
- No C dependencies
- Excellent integration with async Rust (Tokio)

**Mutual TLS (mTLS) for Service-to-Service:**
- Bidirectional authentication
- Certificate-based identity verification
- Short-lived certificates (24-hour lifetime)
- OCSP stapling for revocation checking
- Integration with cert-manager (Kubernetes)

### 9.3 Recommended Rust Crates (Extended)

#### Password Hashing and Key Derivation

| Crate | Version | Purpose | Rationale |
|-------|---------|---------|-----------|
| **argon2** | ^0.5 | Password hashing, key derivation | Winner of Password Hashing Competition, GPU-resistant, OWASP recommended |
| **pbkdf2** | ^0.12 | PBKDF2 key derivation | FIPS-140 compliant, legacy compatibility |
| **hkdf** | ^0.12 | HKDF key derivation | Extract-and-expand for deriving multiple keys |

**Argon2 Configuration (OWASP Recommended):**
- Memory cost: 19 MiB
- Iterations: 2
- Parallelism: 1
- Algorithm: Argon2id (hybrid, side-channel resistant)

#### Digital Signatures and Certificates

| Crate | Version | Purpose | Use Case |
|-------|---------|---------|----------|
| **ed25519-dalek** | ^2.1 | EdDSA signatures | Config signing, audit log integrity |
| **rsa** | ^0.9 | RSA signatures/encryption | Legacy compatibility, enterprise PKI |
| **x509-parser** | ^0.16 | X.509 certificate parsing | mTLS certificate validation |
| **webpki** | ^0.22 | Web PKI validation | Certificate chain validation |

#### Cloud KMS Integration

**AWS KMS**
- **Crate:** `aws-sdk-kms` (^1.0)
- **Features:** Envelope encryption, multi-region replication, CloudHSM integration

**Azure Key Vault**
- **Crate:** `azure_security_keyvault_keys` (^0.20), `azure_security_keyvault_secrets` (^0.20)
- **Features:** Managed Identity, HSM-backed keys, Azure AD integration
- **Note:** Official Microsoft Rust SDK released in 2025

**GCP Cloud KMS**
- **Crate:** `google-cloud-kms` (^0.7) - Community-maintained
- **Alternative:** `gcloud-sdk` (^0.25) - gRPC-based
- **Note:** No official Google Rust SDK; requires community libraries

**HashiCorp Vault**
- **Crate:** `vaultrs` (^0.7)
- **Features:** KV v1/v2, Transit, AppRole, Kubernetes auth, Dynamic secrets

#### Validation and Schema

| Crate | Version | Purpose | Rationale |
|-------|---------|---------|-----------|
| **jsonschema** | ^0.18 | JSON Schema validation | High-performance, supports drafts 4/6/7/2019-09/2020-12 |
| **validator** | ^0.18 | Derive-based validation | Declarative validation rules for structs |
| **serde_valid** | ^0.22 | Serde-integrated validation | Validation during deserialization |

#### Audit Logging and Observability

| Crate | Version | Purpose | Rationale |
|-------|---------|---------|-----------|
| **tracing** | ^0.1 | Structured logging, distributed tracing | Modern async-first design, span-based context |
| **tracing-subscriber** | ^0.3 | Tracing output and formatting | JSON formatting, filtering, layering |
| **tracing-appender** | ^0.2 | Non-blocking file appender | Background file writing, log rotation |
| **tracing-opentelemetry** | ^0.22 | OpenTelemetry integration | Distributed tracing (Jaeger/Zipkin) |
| **metrics** | ^0.22 | Application metrics | Prometheus-compatible |
| **metrics-exporter-prometheus** | ^0.13 | Prometheus export | HTTP /metrics endpoint |

**Why `tracing` over `log`:**
- Async-first design (essential for Tokio-based services)
- Structured fields with type safety
- Span-based context propagation
- Superior integration with async runtimes
- Industry standard for modern Rust services in 2025

### 9.4 Access Control and RBAC

#### Role Hierarchy

```
global-admin (Permissions: *:*:*)
    ↓
    ├── tenant-admin (Scope: Single tenant)
    │   ↓
    │   ├── operator (Config read/write, secret rotation)
    │   ├── developer (Dev/staging access)
    │   └── viewer (Read-only)
    │
    └── security-auditor (Audit logs, config read-only)
```

**RBAC Implementation:**
- **Crate:** `casbin` (^2.3) or `casbin-rs` (^2.3)
- **Features:** Multiple access control models (ACL, RBAC, ABAC), domain/tenant support, role hierarchy

**Permission Model:**
```
<resource>:<namespace_pattern>:<action>

Examples:
- config:production/*:read
- secret:*/database/*:rotate
- tenant:tenant-123:admin
```

**Actions:**
- `read` - Read access
- `write` - Create/update access
- `delete` - Delete access
- `list` - List resources
- `rotate` - Rotate secrets
- `approve` - Approve changes
- `admin` - Administrative access

#### Attribute-Based Access Control (ABAC)

**Conditional Permissions:**
- Time-based (e.g., maintenance windows only)
- IP-based (e.g., internal network only)
- Environment-based (e.g., production requires MFA)
- Request origin (e.g., VPN vs public)

**Integration with Open Policy Agent (OPA):**
- Complex authorization logic
- Policy-as-code (Rego language)
- Centralized policy management
- Integration with LLM-Policy-Engine

### 9.5 Secret Rotation Mechanisms

#### Rotation Workflow

```
Phase 1: Pre-Rotation
- Check eligibility
- Identify dependent services
- Send notifications (15 min before)

Phase 2: Generate New Secret
- Generate cryptographically secure value
- Validate new secret
- Store new version (dual-secret mode)

Phase 3: Grace Period
- Both old and new secrets valid
- Services migrate gradually
- Monitor for errors

Phase 4: Verification
- Health check dependent services
- Verify no services using old secret
- Check error rates

Phase 5: Revoke Old Secret
- Mark old secret as revoked
- Remove from active stores
- Archive (encrypted audit trail)

Phase 6: Post-Rotation
- Send completion notifications
- Update audit logs
- Schedule next rotation
```

#### Failure Handling

**Rollback Triggers:**
- Validation failure of new secret
- Health check failure of dependent services
- Partial propagation timeout
- Manual operator override

**Rollback Process:**
- Mark new secret version as invalid
- Reactivate old secret
- Alert administrators
- Audit log rollback event

### 9.6 Audit Logging and Compliance

#### Audit Event Types

**Events Logged:**
- Configuration access (read, write, delete)
- Secret operations (access, rotation, expiration)
- Authentication (success, failure, session events)
- Authorization (allow, deny, permission changes)
- Policy enforcement (violations, validation failures)
- Tenant lifecycle (created, deleted, suspended)
- System events (key rotation, backups, health degradation)

#### Audit Log Schema

**Structured Event Format:**
```json
{
  "id": "evt_uuid",
  "timestamp": "2025-11-21T14:35:22.123Z",
  "event_type": "ConfigRead",
  "actor": {
    "id": "user_alice@example.com",
    "actor_type": "HumanUser"
  },
  "resource": {
    "resource_type": "config",
    "resource_id": "database.credentials",
    "namespace": "production/ml-service",
    "tenant_id": "tenant-123"
  },
  "action": "read",
  "result": "Success",
  "request_context": {
    "request_id": "req-abc-123",
    "source_ip": "10.0.1.42",
    "user_agent": "curl/7.68.0"
  },
  "metadata": {},
  "signature": "MEUCIQDl3h5+..."
}
```

#### Immutable Audit Trail

**Cryptographic Integrity (Merkle Tree):**
- Each audit event hashed (SHA-256)
- Events appended to Merkle tree
- Root hash signed with Ed25519
- Periodic sealing (every 1000 events)
- Tamper-evident storage

**Rust Crates:**
- `sha2` for hashing
- `ed25519-dalek` for signatures

#### Storage and Retention

**PostgreSQL Schema:**
- Partitioned by month for retention management
- Indexes on timestamp, actor, resource, tenant
- Separate table for sealed checkpoints

**Retention Policies:**
- Hot storage: 90 days
- Warm storage: 1 year
- Cold storage: 7 years (compliance)
- Archived to S3 Glacier or equivalent

#### Compliance Integration

**Supported Frameworks:**
- SOC 2 Type II
- GDPR (data protection, right to erasure)
- HIPAA (healthcare data)
- PCI-DSS (payment data)
- ISO 27001 (information security)

**LLM-Policy-Engine Integration:**
- Automated compliance reporting
- Policy violation detection
- Control verification
- Evidence collection

**LLM-Governance-Dashboard Integration:**
- Real-time audit event streaming (WebSocket)
- Metrics push (every 30 seconds)
- Configuration change notifications
- Policy violation alerts

### 9.7 Validation Policies

#### Schema Validation

**JSON Schema Support:**
- Draft 7 recommended
- Custom validators for LLM-specific patterns
- Type checking, range validation, regex patterns
- Cross-field validation

**Example Schemas:**
- Database configuration (host, port, credentials)
- LLM API configuration (provider, model, parameters)
- Service account configuration (scopes, TTL)

#### Custom Policy Validation

**Open Policy Agent (OPA) Integration:**
- Policy-as-code (Rego language)
- Complex authorization logic
- Environment-based rules (e.g., production restrictions)
- Compliance enforcement (e.g., PII handling)

**Example Policies:**
- Deny production changes outside maintenance windows
- Require MFA for secret modifications
- Deny cross-tenant access (except global admins)
- Require DPO role for PII data changes

#### Constraint Checking

**Validator Crate Integration:**
- Declarative validation with derive macros
- Built-in validators (URL, email, IP, range)
- Custom validation functions
- Detailed error messages

### 9.8 Threat Model

**Key Threats and Mitigations:**

| Threat | Impact | Mitigation |
|--------|--------|------------|
| **Unauthorized Access** | Critical | mTLS, RBAC, MFA, audit logging |
| **Credential Theft** | Critical | Encryption at rest, key rotation, short-lived tokens |
| **Man-in-the-Middle** | High | TLS 1.3, certificate pinning, mTLS |
| **Data Exfiltration** | Critical | Network segmentation, audit logs, DLP |
| **Insider Threat** | High | Least privilege, audit logs, separation of duties |
| **Supply Chain Attack** | High | Dependency scanning (cargo-audit), SBOMs |
| **Denial of Service** | Medium | Rate limiting, auto-scaling, circuit breakers |
| **Key Compromise** | Critical | HSM-backed keys, key rotation, incident response |

### 9.9 Security Operations

**Security Monitoring:**
- Real-time alerting for suspicious patterns
- Failed authentication tracking (>5 in 5 min → alert)
- Privilege escalation attempts
- Unusual access patterns (geolocation, time-of-day)
- Key compromise indicators

**Incident Response:**
1. Detection: Automated alerting
2. Containment: Revoke credentials, block IPs, isolate tenants
3. Investigation: Audit log analysis, scope determination
4. Remediation: Rotate secrets, patch vulnerabilities
5. Recovery: Restore services, verify integrity
6. Post-Incident: Root cause analysis, runbook updates

**Vulnerability Management:**
- Automated dependency scanning (`cargo audit`)
- License and advisory checking (`cargo deny`)
- Static analysis (`clippy`, `semgrep`)
- Container image scanning (`trivy`)
- Critical patches within 48 hours

---

## Conclusion

This architecture provides a production-ready, enterprise-grade foundation for the LLM-Config-Manager. The design emphasizes:

1. **Security:** End-to-end encryption, RBAC, audit logging, compliance
2. **Scalability:** Multi-tier caching, horizontal scaling, multi-region support
3. **Flexibility:** Multiple deployment modes (CLI, API, Sidecar, Hybrid)
4. **Integration:** Deep integration with LLM DevOps ecosystem
5. **Operations:** Simple deployment, comprehensive observability, automated operations

The recommended Rust crates are production-proven, actively maintained, and provide the necessary performance and security characteristics for enterprise deployments.

### Next Steps (SPARC Methodology)

1. **Specification (S):** ✅ Requirements gathered
2. **Pseudocode (P):** ✅ High-level architecture designed
3. **Architecture (A):** ✅ **CURRENT PHASE COMPLETE**
4. **Refinement (R):** Detailed implementation design, API contracts, database schemas
5. **Completion (C):** Implementation, testing, deployment

---

**Document Version:** 1.0.0
**Last Updated:** 2025-11-21
**Author:** Architecture Design Agent
**Status:** Ready for Review and Refinement Phase
