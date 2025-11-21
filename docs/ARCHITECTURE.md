# Architecture Overview

**Version**: 1.0.0
**Last Updated**: 2025-11-21
**Status**: Production

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Principles](#architecture-principles)
3. [System Architecture](#system-architecture)
4. [Component Architecture](#component-architecture)
5. [Data Flow](#data-flow)
6. [Security Architecture](#security-architecture)
7. [Scalability Architecture](#scalability-architecture)
8. [Deployment Architecture](#deployment-architecture)
9. [Technology Stack](#technology-stack)
10. [Design Decisions](#design-decisions)

## System Overview

LLM Config Manager is built on a layered, modular architecture that prioritizes security, scalability, and maintainability. The system is designed as a collection of loosely-coupled crates that work together to provide enterprise-grade configuration management.

### Design Goals

1. **Security First**: Multi-layer security with defense in depth
2. **High Performance**: Sub-millisecond latency for cached operations
3. **Scalability**: Horizontal scaling for high-throughput workloads
4. **Reliability**: Atomic operations with crash-safe guarantees
5. **Maintainability**: Clean code, modular design, comprehensive tests
6. **Extensibility**: Plugin-ready architecture for future enhancements

## Architecture Principles

###  1. Layered Architecture

The system follows a strict layered architecture where each layer has well-defined responsibilities and dependencies flow downward:

```
┌─────────────────────────────────────────┐
│         Presentation Layer              │  ← CLI, REST API
├─────────────────────────────────────────┤
│         Security Layer                  │  ← Input validation, rate limiting
├─────────────────────────────────────────┤
│         Application Layer               │  ← Business logic, orchestration
├─────────────────────────────────────────┤
│         Domain Layer                    │  ← Core domain models
├─────────────────────────────────────────┤
│         Infrastructure Layer            │  ← Storage, cache, crypto
└─────────────────────────────────────────┘
```

### 2. Microservices-Ready

While currently monolithic, the architecture is designed to support microservices deployment:

- **Clear boundaries** between components
- **Async/await** patterns for non-blocking I/O
- **Message passing** through well-defined interfaces
- **Stateless operations** where possible

### 3. Defense in Depth

Security is implemented at multiple layers:

1. **Network Layer**: TLS encryption
2. **Application Layer**: Input validation, rate limiting
3. **Business Layer**: RBAC, policy enforcement
4. **Data Layer**: Encryption at rest

### 4. Fail-Safe Design

The system is designed to fail safely:

- **Atomic operations**: All or nothing
- **Crash recovery**: Automatic recovery from crashes
- **Graceful degradation**: Continue operating with reduced functionality
- **Circuit breakers**: Prevent cascade failures

## System Architecture

### High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                       Client Applications                         │
│                                                                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │   CLI    │  │ REST API │  │  Library │  │   SDKs   │       │
│  └─────┬────┘  └─────┬────┘  └─────┬────┘  └─────┬────┘       │
└────────┼─────────────┼─────────────┼─────────────┼──────────────┘
         │             │             │             │
         └─────────────┴─────────────┴─────────────┘
                              │
┌─────────────────────────────┼──────────────────────────────────┐
│                       Security Middleware                        │
│                                                                  │
│  ┌──────────────┐  ┌───────────────┐  ┌──────────────────┐   │
│  │    Input     │  │  Rate Limit   │  │     Policy       │   │
│  │  Validation  │  │  & Banning    │  │   Enforcement    │   │
│  └──────────────┘  └───────────────┘  └──────────────────┘   │
└─────────────────────────────┼──────────────────────────────────┘
                              │
┌─────────────────────────────┼──────────────────────────────────┐
│                     Configuration Manager                        │
│                                                                  │
│  ┌──────────────┐  ┌───────────────┐  ┌──────────────────┐   │
│  │   Version    │  │  Environment  │  │      RBAC        │   │
│  │   Control    │  │   Management  │  │   & Audit        │   │
│  └──────────────┘  └───────────────┘  └──────────────────┘   │
└─────────────────────────────┼──────────────────────────────────┘
                              │
┌─────────────────────────────┼──────────────────────────────────┐
│                         Cache Layer                              │
│                                                                  │
│  ┌──────────────┐                    ┌──────────────────┐     │
│  │  L1 Cache    │───Promotion───────▶│    L2 Cache      │     │
│  │  (Memory)    │◀──Eviction─────────│    (Redis)       │     │
│  │  <1ms        │                    │    <5ms          │     │
│  └──────────────┘                    └──────────────────┘     │
└─────────────────────────────┼──────────────────────────────────┘
                              │
┌─────────────────────────────┼──────────────────────────────────┐
│                        Storage Layer                             │
│                                                                  │
│  ┌──────────────┐  ┌───────────────┐  ┌──────────────────┐   │
│  │  File Store  │  │  PostgreSQL   │  │     MySQL        │   │
│  │   (Sled)     │  │   (Future)    │  │    (Future)      │   │
│  └──────┬───────┘  └───────┬───────┘  └──────┬───────────┘   │
│         │                  │                  │                │
│         └──────────────────┴──────────────────┘                │
│                            │                                    │
│                  ┌─────────┴──────────┐                       │
│                  │   Encryption       │                       │
│                  │   (AES-256-GCM)    │                       │
│                  └────────────────────┘                       │
└──────────────────────────────────────────────────────────────────┘
```

### Component Interaction

```
┌─────────┐
│  Client │
└────┬────┘
     │ 1. Request
     ▼
┌─────────────────┐
│  Security       │
│  Middleware     │
└────┬────────────┘
     │ 2. Validated Request
     ▼
┌─────────────────┐
│  Config         │◀────────┐
│  Manager        │         │ 6. Cache Miss
└────┬────────────┘         │
     │ 3. Check Cache       │
     ▼                      │
┌─────────────────┐         │
│  Cache          │         │
│  (L1/L2)        │─────────┘
└────┬────────────┘
     │ 4. Cache Hit
     │    OR
     │ 5. Fetch from Storage
     ▼
┌─────────────────┐
│  Storage        │
│  (Encrypted)    │
└────┬────────────┘
     │ 7. Return Data
     ▼
┌─────────┐
│  Client │
└─────────┘
```

## Component Architecture

### Core Crates

#### 1. llm-config-core

**Purpose**: Core business logic and configuration management

**Responsibilities**:
- Configuration CRUD operations
- Version management
- Environment handling
- Validation orchestration
- Business rules enforcement

**Key Components**:
```rust
pub struct ConfigManager {
    storage: Arc<dyn Storage>,
    crypto: Arc<CryptoEngine>,
    cache: Option<Arc<CacheManager>>,
    audit: Option<Arc<AuditLogger>>,
    rbac: Option<Arc<PolicyEnforcer>>,
}

pub struct ConfigEntry {
    pub id: Uuid,
    pub namespace: String,
    pub key: String,
    pub value: ConfigValue,
    pub environment: Environment,
    pub version: u64,
    pub metadata: Metadata,
}
```

**Dependencies**: storage, crypto, cache, audit, rbac

#### 2. llm-config-api

**Purpose**: REST API server

**Responsibilities**:
- HTTP request handling
- Route management
- Request/response serialization
- API documentation
- Security middleware integration

**Key Components**:
```rust
pub struct ApiState {
    pub manager: Arc<ConfigManager>,
}

pub async fn serve(
    manager: Arc<ConfigManager>,
    config: ServerConfig,
) -> anyhow::Result<()>
```

**Stack**: Axum + Tower + Hyper

#### 3. llm-config-security

**Purpose**: Security middleware and validation

**Responsibilities**:
- Input validation and sanitization
- Rate limiting and IP banning
- Policy enforcement
- Attack prevention
- Security context management

**Key Components**:
```rust
pub struct SecurityState {
    pub rate_limiter: Arc<RateLimiter>,
    pub input_validator: Arc<InputValidator>,
    pub policy_enforcer: Arc<PolicyEnforcer>,
}
```

**Protection Against**: SQL injection, XSS, path traversal, command injection, LDAP injection

#### 4. llm-config-storage

**Purpose**: Data persistence layer

**Responsibilities**:
- Storage abstraction
- Atomic operations
- Backup/restore
- Migration support

**Key Components**:
```rust
pub trait Storage: Send + Sync {
    fn get(&self, namespace: &str, key: &str, env: Environment)
        -> Result<Option<ConfigEntry>>;
    fn set(&self, entry: &ConfigEntry) -> Result<()>;
    fn delete(&self, namespace: &str, key: &str, env: Environment)
        -> Result<bool>;
    fn list(&self, namespace: &str, env: Environment)
        -> Result<Vec<ConfigEntry>>;
}
```

**Implementations**: File-based (Sled), PostgreSQL (future), MySQL (future)

#### 5. llm-config-crypto

**Purpose**: Cryptographic operations

**Responsibilities**:
- AES-256-GCM encryption/decryption
- Key management
- Nonce generation
- Secure memory handling

**Key Components**:
```rust
pub struct CryptoEngine {
    key: Secret<Key>,
}

impl CryptoEngine {
    pub fn encrypt(&self, plaintext: &[u8]) -> CryptoResult<Vec<u8>>;
    pub fn decrypt(&self, ciphertext: &[u8]) -> CryptoResult<Vec<u8>>;
}
```

**Algorithm**: AES-256-GCM with unique nonces

#### 6. llm-config-cache

**Purpose**: Multi-tier caching

**Responsibilities**:
- L1 in-memory caching (LRU)
- L2 persistent caching (Redis)
- Cache promotion/demotion
- TTL management
- Cache invalidation

**Key Components**:
```rust
pub struct CacheManager {
    l1: Arc<L1Cache>,
    l2: Arc<L2Cache>,
}
```

**Performance**: <1ms (L1), <5ms (L2)

#### 7. llm-config-rbac

**Purpose**: Role-based access control

**Responsibilities**:
- Role management
- Permission checking
- Policy evaluation
- Access logging

**Key Components**:
```rust
pub struct PolicyEnforcer {
    roles: HashMap<String, Role>,
    assignments: HashMap<String, Vec<RoleAssignment>>,
}

pub enum Role {
    Admin,
    Editor,
    Viewer,
    Auditor,
    Custom(CustomRole),
}
```

#### 8. llm-config-audit

**Purpose**: Audit logging

**Responsibilities**:
- Event logging
- Query interface
- Log validation
- Event retention

**Key Components**:
```rust
pub struct AuditLogger {
    storage: Arc<dyn AuditStorage>,
}

pub enum AuditEventType {
    ConfigCreated { ... },
    ConfigUpdated { ... },
    ConfigDeleted { ... },
    ConfigRead { ... },
    SecretAccessed { ... },
}
```

#### 9. llm-config-templates

**Purpose**: Configuration templating

**Responsibilities**:
- Template parsing
- Variable substitution
- Template validation
- Rendering

**Key Components**:
```rust
pub struct Template {
    pub name: String,
    pub content: String,
    variables: HashSet<String>,
}

pub struct TemplateEngine {
    templates: HashMap<String, Template>,
}
```

#### 10. llm-config-metrics

**Purpose**: Observability

**Responsibilities**:
- Metrics collection
- Health checks
- Performance monitoring
- Statistics

**Key Components**:
```rust
pub struct MetricsCollector {
    registry: Arc<Registry>,
}

pub struct HealthCheck {
    pub status: HealthStatus,
    pub checks: Vec<ComponentHealth>,
}
```

**Format**: Prometheus-compatible

## Data Flow

### Read Operation

```
1. Client Request
   ↓
2. Security Middleware
   - Input validation
   - Rate limit check
   - Policy enforcement
   ↓
3. Config Manager
   ↓
4. Check L1 Cache
   ├─ HIT → Return (< 1ms)
   └─ MISS ↓
5. Check L2 Cache
   ├─ HIT → Promote to L1 → Return (< 5ms)
   └─ MISS ↓
6. Storage Layer
   - Read from disk/DB
   - Decrypt if secret
   ↓
7. Update Caches
   - Write to L1
   - Write to L2
   ↓
8. Return to Client
```

### Write Operation

```
1. Client Request
   ↓
2. Security Middleware
   - Input validation
   - Rate limit check
   - Policy enforcement
   ↓
3. RBAC Check
   - Verify permissions
   ↓
4. Config Manager
   - Validate data
   - Check constraints
   ↓
5. Encrypt (if secret)
   - AES-256-GCM
   - Generate nonce
   ↓
6. Storage Layer
   - Atomic write
   - Create version
   ↓
7. Invalidate Caches
   - Remove from L1
   - Remove from L2
   ↓
8. Audit Log
   - Record event
   ↓
9. Return Success
```

### Version Rollback

```
1. Client Rollback Request
   ↓
2. Security & RBAC Checks
   ↓
3. Config Manager
   - Fetch version history
   - Validate version exists
   ↓
4. Retrieve Version
   - Read historical entry
   - Decrypt if needed
   ↓
5. Create New Version
   - Current version + 1
   - Copy old value
   ↓
6. Write Operation
   - Same as standard write
   ↓
7. Audit Log
   - Record rollback event
   ↓
8. Return Success
```

## Security Architecture

### Multi-Layer Security

```
Layer 1: Network Security
├─ TLS 1.2+ encryption
├─ Certificate validation
└─ Secure protocols

Layer 2: Application Security
├─ Input validation
├─ Output encoding
├─ Rate limiting
└─ IP allowlist/blocklist

Layer 3: Authentication & Authorization
├─ API key authentication
├─ RBAC policies
├─ Permission checks
└─ Session management

Layer 4: Data Security
├─ AES-256-GCM encryption
├─ Secure key storage
├─ Memory zeroization
└─ Secure delete

Layer 5: Audit & Monitoring
├─ Comprehensive logging
├─ Security event tracking
├─ Anomaly detection
└─ Alert generation
```

### Attack Surface Mitigation

| Attack Vector | Mitigation | Implementation |
|---------------|------------|----------------|
| SQL Injection | Input validation, parameterized queries | `input.rs` |
| XSS | Input sanitization, output encoding | `input.rs` |
| Path Traversal | Path validation, canonicalization | `input.rs` |
| Command Injection | Input validation, no shell execution | `input.rs` |
| Rate Limit Bypass | IP-based limiting, token buckets | `rate_limit.rs` |
| Privilege Escalation | RBAC, permission checks | `rbac.rs` |
| Data Exfiltration | Encryption, access controls | `crypto.rs` |
| DoS | Rate limiting, resource limits | `rate_limit.rs` |

## Scalability Architecture

### Horizontal Scaling

```
┌─────────────┐
│ Load        │
│ Balancer    │
└──────┬──────┘
       │
       ├─────────┬─────────┬─────────┐
       ▼         ▼         ▼         ▼
   ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐
   │API-1│   │API-2│   │API-3│   │API-N│
   └──┬──┘   └──┬──┘   └──┬──┘   └──┬──┘
      │         │         │         │
      └─────────┴─────────┴─────────┘
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
   ┌─────────┐           ┌─────────┐
   │ Redis   │           │ Primary │
   │ Cluster │           │ Storage │
   └─────────┘           └────┬────┘
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
               ┌─────────┐         ┌─────────┐
               │Replica-1│         │Replica-N│
               └─────────┘         └─────────┘
```

### Performance Optimization

1. **Caching Strategy**:
   - L1: Hot data (frequently accessed)
   - L2: Warm data (occasionally accessed)
   - Storage: Cold data (rarely accessed)

2. **Connection Pooling**:
   - Database connection pools
   - Redis connection pools
   - HTTP client connection reuse

3. **Async Processing**:
   - Non-blocking I/O
   - Concurrent request handling
   - Background job processing

## Deployment Architecture

### Kubernetes Deployment

```yaml
┌─────────────────────────────────────────┐
│            Kubernetes Cluster            │
│                                          │
│  ┌────────────────────────────────────┐ │
│  │         Ingress Controller          │ │
│  └─────────────┬──────────────────────┘ │
│                │                         │
│  ┌─────────────┴──────────────────────┐ │
│  │       API Service (ClusterIP)       │ │
│  └─────────────┬──────────────────────┘ │
│                │                         │
│  ┌─────────────┴──────────────────────┐ │
│  │     API Deployment (3 replicas)     │ │
│  │  ┌──────┐  ┌──────┐  ┌──────┐     │ │
│  │  │ Pod1 │  │ Pod2 │  │ Pod3 │     │ │
│  │  └──────┘  └──────┘  └──────┘     │ │
│  └──────────────────────────────────┬─┘ │
│                                     │   │
│  ┌──────────────────────────────────┴─┐ │
│  │     Redis StatefulSet (3 nodes)    │ │
│  └──────────────────────────────────┬─┘ │
│                                     │   │
│  ┌──────────────────────────────────┴─┐ │
│  │     Storage PersistentVolume       │ │
│  └────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

### Docker Compose Deployment

```yaml
services:
  api:
    image: llm-config-manager:latest
    ports:
      - "8080:8080"
    environment:
      - LLM_CONFIG_KEY=${ENCRYPTION_KEY}
      - REDIS_URL=redis://redis:6379
    depends_on:
      - redis
      - storage

  redis:
    image: redis:7-alpine
    volumes:
      - redis-data:/data

  storage:
    image: postgres:15-alpine
    volumes:
      - postgres-data:/var/lib/postgresql/data
```

## Technology Stack

### Language & Runtime
- **Rust 1.75+**: Systems programming language
- **Tokio**: Async runtime

### Web Framework
- **Axum**: Web application framework
- **Tower**: Service middleware
- **Hyper**: HTTP library

### Storage
- **Sled**: Embedded database
- **PostgreSQL**: (Future) Relational database
- **MySQL**: (Future) Relational database
- **Redis**: Cache layer

### Security
- **Ring**: Cryptography library
- **AES-256-GCM**: Encryption algorithm
- **Argon2**: Password hashing
- **Zeroize**: Secure memory clearing

### Observability
- **Prometheus**: Metrics
- **OpenTelemetry**: Tracing
- **Tracing**: Structured logging

### Testing
- **Cargo Test**: Unit testing
- **Proptest**: Property-based testing
- **Criterion**: Benchmarking

## Design Decisions

### Why Rust?

**Decision**: Use Rust as the primary language

**Rationale**:
- Memory safety without garbage collection
- Zero-cost abstractions
- Excellent concurrency support
- Strong type system
- Great tooling (Cargo, Clippy)

### Why Axum?

**Decision**: Use Axum for the REST API

**Rationale**:
- Built on Tokio (excellent async performance)
- Type-safe extractors
- Minimal boilerplate
- Tower middleware ecosystem
- Active development

### Why AES-256-GCM?

**Decision**: Use AES-256-GCM for encryption

**Rationale**:
- Authenticated encryption (confidentiality + integrity)
- NIST recommended
- Hardware acceleration available
- Well-studied and trusted

### Why Multi-Tier Caching?

**Decision**: Implement L1 (memory) + L2 (Redis) caching

**Rationale**:
- L1 provides ultra-low latency (<1ms)
- L2 provides high-capacity shared cache
- Promotion strategy optimizes hot data
- Graceful degradation if cache unavailable

### Why Modular Crates?

**Decision**: Split functionality into separate crates

**Rationale**:
- Clear separation of concerns
- Independent testing
- Reusability
- Parallel compilation
- Future microservices migration

### Why File-Based Storage First?

**Decision**: Implement file-based storage before databases

**Rationale**:
- Zero external dependencies
- Simpler deployment
- Embedded use cases
- Atomic operations with Sled
- Database backends can be added later

## Future Architecture Considerations

### Multi-Region Support

```
Region A                  Region B                  Region C
┌────────┐              ┌────────┐              ┌────────┐
│  API   │─────────────▶│  API   │─────────────▶│  API   │
└───┬────┘  Replication └───┬────┘  Replication └───┬────┘
    │                       │                       │
┌───┴────┐              ┌───┴────┐              ┌───┴────┐
│Storage │              │Storage │              │Storage │
└────────┘              └────────┘              └────────┘
```

### Event Sourcing

```
Command → Event Store → Projection → Read Model
                ↓
            Event Log
                ↓
         Event Replay
```

### Plugin System

```
┌──────────────────────────────────┐
│        Core System               │
├──────────────────────────────────┤
│      Plugin Interface            │
├──────────────────────────────────┤
│  ┌────────┐  ┌────────┐  ┌────┐│
│  │Plugin 1│  │Plugin 2│  │... ││
│  └────────┘  └────────┘  └────┘│
└──────────────────────────────────┘
```

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-21
**Next Review**: 2026-02-21
