# LLM-Config-Manager: Complete SPARC Specification

**Project:** LLM-Config-Manager
**Version:** 1.0.0
**Date:** 2025-11-21
**Status:** Complete - Ready for Implementation
**Methodology:** SPARC (Specification, Pseudocode, Architecture, Refinement, Completion)

---

## Document Overview

This comprehensive SPARC specification document consolidates all planning, design, and implementation details for the LLM-Config-Manager system. It serves as the authoritative reference for the unified configuration and secrets-management backbone of the LLM DevOps ecosystem.

### Document Purpose

- Provide a single source of truth for all SPARC phases
- Enable systematic implementation following SPARC methodology
- Define clear requirements, design, and delivery roadmap
- Support stakeholder alignment and team coordination

### Key Highlights

- **Scope:** 15 functional requirements across 8 functional cores
- **Integration:** 6+ LLM DevOps modules with defined contracts
- **Timeline:** 32 weeks (8 months) from MVP to v1.0
- **Technology:** Rust-based with enterprise-grade security
- **Deployment:** CLI, API, Sidecar, and Hybrid modes

---

## Table of Contents

1. [SPARC Phase 1: Specification](#1-sparc-phase-1-specification)
2. [SPARC Phase 2: Pseudocode](#2-sparc-phase-2-pseudocode)
3. [SPARC Phase 3: Architecture](#3-sparc-phase-3-architecture)
4. [SPARC Phase 4: Refinement](#4-sparc-phase-4-refinement)
5. [SPARC Phase 5: Completion](#5-sparc-phase-5-completion)
6. [Appendix: Quick Reference](#6-appendix-quick-reference)

---

# 1. SPARC Phase 1: Specification

**Status:** Complete
**Completion Date:** 2025-11-21
**Artifacts:** SPECIFICATION.json, REQUIREMENTS_ANALYSIS.md

## 1.1 Project Vision and Scope

### Purpose

The LLM-Config-Manager serves as the **unified configuration and secrets-management backbone** for the LLM DevOps ecosystem, providing centralized, versioned, and secure storage and distribution of:

- **Configuration parameters:** API endpoints, model settings, operational configs
- **Secrets:** API keys, tokens, certificates, credentials
- **Policies:** Access control, security rules, cost limits
- **Templates:** Reusable configuration patterns

### Key Differentiators

1. **LLM-Native:** Purpose-built for LLM operations with specialized configuration patterns for model endpoints, API parameters, prompt templates, and inference settings
2. **Zero-Trust Security:** Multi-tenant isolation, end-to-end encryption, comprehensive audit logging, RBAC/ABAC policy enforcement
3. **Production-Grade:** 99.9% uptime SLA, dynamic hot-reload, disaster recovery, full observability
4. **Ecosystem Integration:** Seamless integration with 6+ LLM DevOps modules

### In Scope

- Centralized configuration storage and retrieval for all LLM DevOps modules
- Secure secrets management for API keys, tokens, certificates, and credentials
- Version control and audit trail for all configuration changes
- Multi-tenant isolation with namespace and tenant-level access controls
- Environment-specific configuration overrides (dev, staging, production, edge)
- Dynamic configuration reload without service restarts
- Integration APIs for module-to-module configuration sharing
- LLM-specific configuration patterns
- Configuration validation and schema enforcement
- Secret rotation automation and lifecycle management
- Encryption at rest and in transit for all sensitive data
- Role-based access control (RBAC) and policy enforcement
- Configuration templates and inheritance hierarchies
- Backup, restore, and disaster recovery capabilities
- Observability hooks for configuration access and changes
- Integration with external secret stores (Vault, AWS, Azure, GCP)

### Out of Scope

- Runtime code deployment or application binary distribution
- Direct LLM model training or inference operations
- General-purpose key-value storage unrelated to configuration
- Real-time event streaming or message queue functionality
- User interface or frontend dashboard (handled by LLM-Governance-Dashboard)
- Log aggregation and storage (handled by LLM-Observatory)
- Network policy enforcement or service mesh control plane
- Container orchestration or Kubernetes operator functionality

## 1.2 Functional Requirements

### FR-001: Configuration Storage (Critical)

**Requirement:** Store hierarchical configuration data in key-value pairs with support for namespaces, environments, and tenant isolation

**Acceptance Criteria:**
- Support for nested configuration structures up to 10 levels deep
- Namespace isolation enforced at the storage layer
- Environment tags (dev, staging, prod, edge) with inheritance
- Tenant-specific configuration overrides without duplication
- Maximum configuration value size of 1MB per key
- Support for JSON, YAML, TOML, and plain text value formats

### FR-002: Secrets Management (Critical)

**Requirement:** Securely store, encrypt, and manage sensitive credentials including API keys, certificates, tokens, and database passwords

**Acceptance Criteria:**
- AES-256-GCM encryption at rest for all secrets
- Separate encryption keys per tenant for cryptographic isolation
- Support for asymmetric encryption using RSA-4096 or Ed25519
- Secure key derivation using Argon2id or PBKDF2
- Secret expiration and rotation scheduling
- Audit logging for all secret access attempts
- Secret versioning with rollback capability
- Support for dynamic secret generation (temporary tokens)

### FR-003: Version Control (High)

**Requirement:** Maintain complete version history of all configuration changes with diff tracking, rollback capability, and audit trail

**Acceptance Criteria:**
- Git-style versioning with commit messages and timestamps
- Store minimum 90 days of version history (configurable)
- Atomic updates with ACID transaction guarantees
- Point-in-time restoration to any previous version
- Configuration diff generation between any two versions
- Tag-based version labeling for stable releases
- Change attribution with user/service identity
- Automatic cleanup of old versions based on retention policy

### FR-004: Multi-Tenant Isolation (Critical)

**Requirement:** Enforce strict tenant isolation with namespace segregation, preventing cross-tenant data access and ensuring resource quotas

**Acceptance Criteria:**
- Cryptographic tenant ID validation on all operations
- Physical data separation in storage layer per tenant
- Tenant-specific quota enforcement (storage, API calls, concurrent connections)
- Zero data leakage between tenants verified by security testing
- Support for hierarchical tenants (parent/child relationships)
- Tenant-scoped API authentication tokens
- Configurable tenant isolation modes (hard/soft)
- Tenant lifecycle management (create, suspend, delete, archive)

### FR-005: Environment Overrides (High)

**Requirement:** Support environment-specific configuration overlays with precedence rules and inheritance from base configurations

**Acceptance Criteria:**
- Layered configuration resolution: global → tenant → environment → service
- Explicit override syntax to prevent accidental inheritance
- Environment promotion workflows (dev → staging → prod)
- Validation that overrides match schema of base configuration
- Dry-run capability to preview effective configuration
- Support for conditional overrides based on feature flags
- Clear precedence documentation and visualization
- Warning system for divergent configurations across environments

### FR-006: Dynamic Reload (High)

**Requirement:** Enable runtime configuration updates without service restarts through push notifications or polling mechanisms

**Acceptance Criteria:**
- WebSocket or SSE-based push notifications for configuration changes
- Polling fallback with configurable intervals (default 30s)
- Configuration cache with TTL-based invalidation
- Versioned configuration endpoints to prevent stale reads
- Graceful degradation if config service is unreachable
- Local cache persistence for offline operation
- Atomic configuration swap to prevent partial updates
- Rollback trigger if configuration causes service errors

### FR-007: LLM-Specific Configuration (High)

**Requirement:** Provide specialized configuration patterns for LLM operations including model endpoints, API parameters, prompt templates, and inference settings

**Acceptance Criteria:**
- Predefined schemas for OpenAI, Anthropic, Google, AWS, Azure LLM APIs
- Model versioning and endpoint management with fallback chains
- Token budget and rate limit configuration per model
- Prompt template versioning with variable substitution
- Model parameter presets (temperature, top_p, max_tokens, etc.)
- Multi-provider configuration with automatic failover
- Cost tracking integration hooks for billing
- Model capability metadata (context window, modalities supported)

### FR-008: Configuration Validation (High)

**Requirement:** Validate all configuration changes against predefined schemas before acceptance, preventing invalid or dangerous configurations

**Acceptance Criteria:**
- JSON Schema or similar validation for all configuration values
- Custom validation rules using Rego (Open Policy Agent) or CEL
- Type checking for primitive values (string, int, bool, float)
- Range validation for numeric parameters
- Regex pattern matching for string formats
- Cross-field validation (e.g., max > min)
- Validation error reporting with actionable messages
- Dry-run validation API endpoint

### FR-009: Integration APIs (Critical)

**Requirement:** Expose REST and gRPC APIs for configuration retrieval, updates, and real-time subscriptions, with client SDKs for Rust, Python, and TypeScript

**Acceptance Criteria:**
- RESTful HTTP API with OpenAPI 3.0 specification
- gRPC API with Protocol Buffers definitions
- Client SDK for Rust with async/await support
- Client SDK for Python with type hints
- Client SDK for TypeScript with full type definitions
- Batch operations to reduce API round trips
- GraphQL API for flexible configuration queries (optional)
- Streaming subscriptions for configuration updates
- API versioning with deprecation notices
- Rate limiting and request throttling per client

### FR-010: Secret Rotation (High)

**Requirement:** Automate secret rotation with configurable schedules, notifying dependent services and maintaining overlap periods during rotation

**Acceptance Criteria:**
- Configurable rotation schedules (hourly, daily, weekly, monthly)
- Pre-rotation notifications to dependent services (15 minutes before)
- Dual-secret overlap period (old and new valid simultaneously)
- Automatic rollback if rotation causes service failures
- Integration with external secret providers for federated rotation
- Rotation audit logs with before/after values (hashed)
- Manual rotation trigger via API or CLI
- Health checks before and after rotation
- Support for coordinated rotation across multiple secrets

### FR-011: Access Control (Critical)

**Requirement:** Implement fine-grained role-based access control (RBAC) with attribute-based policies for configuration and secret access

**Acceptance Criteria:**
- Predefined roles: admin, operator, developer, viewer, service-account
- Custom role creation with granular permissions
- Permission model: read, write, delete, rotate, admin
- Scope-based permissions (global, tenant, namespace, key-prefix)
- Attribute-based policies (time-of-day, IP range, environment)
- Service account authentication with mTLS certificates
- Human user authentication via OAuth2/OIDC integration
- API key authentication with scoped permissions
- Permission inheritance in hierarchical structures
- Audit logging of all access control decisions

### FR-012: Observability Integration (High)

**Requirement:** Emit structured logs, metrics, and traces for all configuration operations, integrating with LLM-Observatory for centralized monitoring

**Acceptance Criteria:**
- Structured JSON logs with trace correlation IDs
- OpenTelemetry trace export for distributed tracing
- Prometheus-compatible metrics endpoint (/metrics)
- Key metrics: request latency, error rate, cache hit ratio, secret rotation status
- Health check endpoints (/health/live, /health/ready)
- Configuration change events published to event bus
- Performance monitoring for configuration retrieval (p50, p95, p99)
- Alerting hooks for failed rotations or access violations

### FR-013: Disaster Recovery (High)

**Requirement:** Provide automated backup, point-in-time recovery, and disaster recovery capabilities with cross-region replication

**Acceptance Criteria:**
- Automated hourly backups with 30-day retention
- Incremental backups to minimize storage overhead
- Point-in-time recovery with 5-minute RPO (Recovery Point Objective)
- Cross-region replication for high availability
- Backup encryption with separate encryption keys
- Backup integrity verification and testing
- Manual backup trigger via API
- Documented disaster recovery runbooks
- Recovery Time Objective (RTO) < 15 minutes

### FR-014: Configuration Templates (Medium)

**Requirement:** Support configuration templates with variable substitution, inheritance, and reusable patterns for common configurations

**Acceptance Criteria:**
- Template syntax with variable placeholders (e.g., {{variable_name}})
- Template inheritance with override capability
- Template library for common LLM configurations
- Variable resolution from environment, tenant context, or external sources
- Template validation before instantiation
- Version control for templates separate from configurations
- Template sharing across tenants (with permission)
- Documentation generation from templates

### FR-015: External Integrations (Medium)

**Requirement:** Integrate with external secret management systems as upstream providers, supporting hybrid and federated deployments

**Acceptance Criteria:**
- HashiCorp Vault integration for secret storage and dynamic secrets
- AWS Secrets Manager integration with IAM-based authentication
- Azure Key Vault integration with Managed Identity
- GCP Secret Manager integration with Workload Identity
- Bidirectional sync with external providers (optional)
- Fallback to local storage if external provider unreachable
- Secret caching with configurable TTL
- Provider-specific configuration validation

## 1.3 Non-Functional Requirements

### Performance

- **Read Latency:** p99 < 10ms (cached), p99 < 100ms (vault miss)
- **Write Latency:** p99 < 50ms
- **Throughput:** 50,000+ req/s with caching enabled
- **Cache Hit Rate:** >= 85% under normal load
- **Startup Time:** < 5 seconds for API service

### Availability

- **Uptime SLA:** 99.9% (8.76 hours downtime/year)
- **Recovery Time Objective (RTO):** < 15 minutes
- **Recovery Point Objective (RPO):** < 5 minutes
- **Redundancy:** Multi-region deployment support

### Scalability

- **Tenants:** Support 10,000+ active tenants
- **Configurations:** 100,000+ configs per tenant
- **Concurrent Connections:** 10,000+ simultaneous clients
- **Storage Growth:** Linear scaling with tenant/config count
- **Horizontal Scaling:** Support for 10+ API server replicas

### Security

- **Compliance:** SOC2 Type II, ISO27001, GDPR, NIST-800-53
- **Encryption:** AES-256-GCM at rest, TLS 1.3 in transit
- **Authentication:** JWT, mTLS, OAuth2/OIDC, API keys
- **Authorization:** RBAC/ABAC with deny-by-default
- **Audit Retention:** 7 years for compliance logs

## 1.4 Integration Model

### LLM DevOps Module Integrations

#### LLM-Observatory (Intelligence Core)
- **Integration Type:** Telemetry Export
- **Protocol:** OpenTelemetry (OTLP)
- **Data Flow:** Config-Manager → Observatory
- **Purpose:** Export logs, metrics, and traces for centralized monitoring

#### LLM-Gateway (Interface Core)
- **Integration Type:** Dynamic Configuration
- **Protocol:** gRPC with streaming
- **Data Flow:** Bidirectional
- **Purpose:** Real-time routing configuration and policy updates

#### LLM-Prompt-Manager (Research Core)
- **Integration Type:** Template Storage
- **Protocol:** REST API
- **Data Flow:** Bidirectional
- **Purpose:** Version-controlled prompt template storage

#### LLM-Cost-Optimizer (Automation Core)
- **Integration Type:** Policy Management
- **Protocol:** gRPC
- **Data Flow:** Bidirectional
- **Purpose:** Budget limits and cost optimization policies

#### LLM-Security-Scanner (Security Core)
- **Integration Type:** Security Policies
- **Protocol:** gRPC
- **Data Flow:** Config-Manager → Security-Scanner
- **Purpose:** Security policy definitions and threat rules

#### LLM-Model-Router (Intelligence Core)
- **Integration Type:** Routing Configuration
- **Protocol:** gRPC with streaming
- **Data Flow:** Config-Manager → Model-Router
- **Purpose:** Model endpoint configuration and failover rules

### Communication Protocols

- **gRPC:** High-performance module-to-module communication
- **REST/HTTP:** External integrations and administration
- **WebSocket/SSE:** Real-time configuration push notifications
- **mTLS:** All inter-service communication in zero-trust architecture

---

# 2. SPARC Phase 2: Pseudocode

**Status:** Complete
**Completion Date:** 2025-11-21
**Artifacts:** PSEUDOCODE.md, pseudocode.json

## 2.1 Core Operations

### Configuration Retrieval Algorithm

```pseudocode
FUNCTION retrieve_configuration(namespace, key, environment, tenant_id, user_context)
  INPUT:
    - namespace: String (e.g., "acme-corp/ml-platform/inference")
    - key: String (e.g., "openai.api_endpoint")
    - environment: Option<String> (e.g., "production")
    - tenant_id: UUID
    - user_context: AuthContext

  OUTPUT:
    - Result<ConfigValue, ConfigError>

  STEPS:
    1. Validate inputs
       - Ensure namespace and key are non-empty
       - Validate tenant_id format (UUID v4)

    2. Check authorization
       - Extract user identity from user_context
       - Query RBAC policy engine
       - IF NOT authorized THEN RETURN Error::Unauthorized

    3. Construct cache key
       - cache_key = format!("{}/{}/{}@{}", tenant_id, namespace, key, environment)

    4. Check L1 cache (in-memory, per-instance)
       - IF L1.contains(cache_key) THEN
           - Log cache hit (L1)
           - RETURN L1.get(cache_key)

    5. Check L2 cache (Redis, distributed)
       - IF L2.contains(cache_key) THEN
           - value = L2.get(cache_key)
           - L1.set(cache_key, value, TTL=5min)
           - Log cache hit (L2)
           - RETURN value

    6. Fetch from Vault (source of truth)
       - vault_path = construct_vault_path(tenant_id, namespace, key, environment)
       - TRY:
           - config = vault_client.read(vault_path)
       - CATCH VaultError:
           - IF offline_mode_enabled THEN
               - RETURN cached_value_if_available OR Error::ServiceUnavailable
           - ELSE RETURN Error::VaultUnreachable

    7. Apply environment override resolution
       - IF environment specified THEN
           - resolution_chain = [environment, "staging", "development", "base"]
           - FOR each env IN resolution_chain:
               - env_path = construct_vault_path(tenant_id, namespace, key, env)
               - IF vault_client.exists(env_path) THEN
                   - config = vault_client.read(env_path)
                   - BREAK

    8. Decrypt if encrypted
       - IF config.encrypted THEN
           - dek = retrieve_data_encryption_key(tenant_id, config.encryption_key_id)
           - config.value = decrypt_aes_gcm(config.value, dek, config.nonce)

    9. Validate schema
       - schema = fetch_schema(config.schema_version)
       - IF NOT validate_json_schema(config.value, schema) THEN
           - RETURN Error::SchemaValidationFailed

    10. Populate caches
        - L2.set(cache_key, config.value, TTL=15min)
        - L1.set(cache_key, config.value, TTL=5min)

    11. Audit log (async)
        - audit_logger.log_async({
            event_type: "config.read",
            actor: user_context.user_id,
            resource: format!("{}/{}", namespace, key),
            result: "success",
            timestamp: utc_now()
          })

    12. RETURN config.value

COMPLEXITY: O(1) amortized with caching, O(n) worst case for environment resolution
CACHING_STRATEGY: Two-level LRU with TTL
ERROR_HANDLING: Graceful degradation with cached values
```

### Configuration Update Algorithm

```pseudocode
FUNCTION store_configuration(namespace, key, value, metadata, tenant_id, user_context)
  INPUT:
    - namespace: String
    - key: String
    - value: ConfigValue
    - metadata: ConfigMetadata (includes schema_version, tags, commit_message)
    - tenant_id: UUID
    - user_context: AuthContext

  OUTPUT:
    - Result<ConfigId, ConfigError>

  STEPS:
    1. Validate inputs
       - Validate namespace format (alphanumeric + separators)
       - Validate key format (no special characters)
       - Validate value size (<= 1MB)
       - Validate schema against metadata.schema_version

    2. Check authorization
       - IF NOT policy_engine.authorize(user_context, namespace, Action::Write) THEN
           - RETURN Error::Unauthorized("Write permission denied")

    3. Check tenant quotas
       - current_usage = query_tenant_usage(tenant_id)
       - IF current_usage.config_count >= tenant.quota.max_configs THEN
           - RETURN Error::QuotaExceeded("Maximum configurations reached")

    4. Prepare configuration object
       - config_id = generate_uuid_v4()
       - config = Configuration {
           id: config_id,
           tenant_id: tenant_id,
           namespace: namespace,
           key: key,
           value: value,
           schema_version: metadata.schema_version,
           encrypted: false,
           encryption_key_id: None,
           created_at: utc_now(),
           created_by: user_context.user_id,
           updated_at: utc_now(),
           updated_by: user_context.user_id,
           version: 1,
         }

    5. Detect and encrypt secrets
       - IF contains_secret_markers(value) THEN
           - encryption_key_id = get_or_create_tenant_key(tenant_id)
           - dek = retrieve_data_encryption_key(tenant_id, encryption_key_id)
           - nonce = generate_random_nonce(12)  # 96 bits for GCM
           - encrypted_value = encrypt_aes_gcm(value, dek, nonce)
           - config.value = encrypted_value
           - config.encrypted = true
           - config.encryption_key_id = Some(encryption_key_id)
           - config.nonce = Some(base64_encode(nonce))

    6. Begin distributed transaction
       - transaction = storage.begin_transaction()
       - TRY:

    7. Check for existing configuration
       - existing_config = vault_client.read(construct_vault_path(tenant_id, namespace, key))
       - IF existing_config.exists THEN
           - config.version = existing_config.version + 1
           - operation_type = ChangeType::Update
       - ELSE:
           - operation_type = ChangeType::Create

    8. Store configuration in Vault
       - vault_path = construct_vault_path(tenant_id, namespace, key, environment)
       - vault_client.write(vault_path, serialize_config(config))

    9. Store metadata in PostgreSQL
       - db.execute("
           INSERT INTO configurations
           (id, tenant_id, namespace, key, value_type, encrypted, encryption_key_id,
            schema_version, created_at, created_by, updated_at, updated_by, version)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
           ON CONFLICT (tenant_id, namespace, key) DO UPDATE SET
             value_type = $5, encrypted = $6, encryption_key_id = $7,
             schema_version = $8, updated_at = $11, updated_by = $12, version = $13
         ", [config.id, config.tenant_id, ...])

    10. Create version history entry
        - version_entry = ConfigVersion {
            id: generate_uuid_v4(),
            config_id: config.id,
            version_number: config.version,
            value: config.value,
            change_type: operation_type,
            changed_by: user_context.user_id,
            changed_at: utc_now(),
            change_reason: metadata.commit_message,
            diff: compute_json_diff(existing_config.value, config.value) IF exists,
            git_commit: metadata.git_commit,
          }
        - db.execute("INSERT INTO config_versions ...", version_entry)

    11. Invalidate all caches
        - cache_invalidation_key = format!("{}/{}", namespace, key)
        - L1.invalidate(cache_invalidation_key)
        - redis_pubsub.publish("cache_invalidation", {
            tenant_id: tenant_id,
            namespace: namespace,
            key: key,
            timestamp: utc_now()
          })

    12. Commit transaction
        - transaction.commit()

    13. Audit log (async)
        - audit_logger.log_async({
            event_type: "config.write",
            operation: operation_type,
            actor: user_context.user_id,
            resource: format!("{}/{}", namespace, key),
            result: "success",
            config_id: config.id,
            version: config.version,
            timestamp: utc_now()
          })

    14. Notify subscribers (async)
        - notification_service.notify_async({
            event: "config.changed",
            tenant_id: tenant_id,
            namespace: namespace,
            key: key,
            version: config.version,
            change_type: operation_type
          })

    15. RETURN Ok(config.id)

  CATCH error:
    - transaction.rollback()
    - audit_logger.log_async({error: error.to_string(), result: "failure"})
    - RETURN Err(error)

COMPLEXITY: O(1) for write, O(n) for version history storage
TRANSACTION: ACID guarantees with two-phase commit
CONSISTENCY: Strong consistency with distributed locking
```

## 2.2 Encryption and Decryption

### Envelope Encryption Algorithm

```pseudocode
FUNCTION encrypt_secret(plaintext, tenant_id, secret_metadata)
  INPUT:
    - plaintext: Vec<u8> (raw secret bytes)
    - tenant_id: UUID
    - secret_metadata: SecretMetadata (key_id, algorithm)

  OUTPUT:
    - Result<EncryptedValue, CryptoError>

  STEPS:
    1. Retrieve or generate Data Encryption Key (DEK)
       - dek_id = format!("dek-{}-{}", tenant_id, secret_metadata.key_id)
       - dek = key_cache.get(dek_id)
       - IF dek.is_none() THEN
           - dek = generate_random_key(32)  # 256 bits for AES-256
           - key_cache.set(dek_id, dek, TTL=1hour)

    2. Generate unique nonce
       - nonce = generate_random_bytes(12)  # 96 bits for AES-GCM

    3. Prepare Additional Authenticated Data (AAD)
       - aad = serialize({
           tenant_id: tenant_id,
           key_id: secret_metadata.key_id,
           timestamp: utc_now(),
           version: 1
         })

    4. Encrypt with AES-256-GCM
       - cipher = create_aes_gcm_cipher(dek)
       - ciphertext_with_tag = cipher.encrypt(nonce, plaintext, aad)
       - ciphertext = ciphertext_with_tag[0..len-16]
       - auth_tag = ciphertext_with_tag[len-16..len]

    5. Encrypt DEK with Key Encryption Key (envelope encryption)
       - kek_id = get_tenant_kek_id(tenant_id)
       - kms_provider = get_kms_provider(kek_id)
       - encrypted_dek = kms_provider.encrypt(kek_id, dek)

    6. Create encrypted envelope
       - encrypted_value = EncryptedValue {
           ciphertext: base64_encode(ciphertext),
           encrypted_dek: base64_encode(encrypted_dek),
           kek_id: kek_id,
           algorithm: Algorithm::AES256GCM,
           nonce: base64_encode(nonce),
           auth_tag: base64_encode(auth_tag),
           aad: base64_encode(aad),
           created_at: utc_now(),
           version: 1
         }

    7. RETURN Ok(encrypted_value)

ALGORITHM: AES-256-GCM with envelope encryption
KEY_HIERARCHY: KEK (KMS) → DEK (runtime) → Data
AUTHENTICATION: AEAD with Additional Authenticated Data
```

### Decryption Algorithm

```pseudocode
FUNCTION decrypt_secret(encrypted_value, tenant_id)
  INPUT:
    - encrypted_value: EncryptedValue
    - tenant_id: UUID

  OUTPUT:
    - Result<Vec<u8>, CryptoError>

  STEPS:
    1. Validate tenant isolation
       - IF NOT validate_tenant_access(tenant_id, encrypted_value.kek_id) THEN
           - audit_logger.log_security_violation("cross_tenant_decryption_attempt")
           - RETURN Error::TenantIsolationViolation

    2. Retrieve KEK and decrypt DEK
       - kms_provider = get_kms_provider(encrypted_value.kek_id)
       - encrypted_dek = base64_decode(encrypted_value.encrypted_dek)
       - TRY:
           - dek = kms_provider.decrypt(encrypted_value.kek_id, encrypted_dek)
       - CATCH KMSError:
           - RETURN Error::DecryptionFailed("KEK decryption failed")

    3. Decode encrypted components
       - ciphertext = base64_decode(encrypted_value.ciphertext)
       - nonce = base64_decode(encrypted_value.nonce)
       - auth_tag = base64_decode(encrypted_value.auth_tag)
       - aad = base64_decode(encrypted_value.aad)

    4. Verify algorithm compatibility
       - IF encrypted_value.algorithm != Algorithm::AES256GCM THEN
           - RETURN Error::UnsupportedAlgorithm

    5. Decrypt with AES-256-GCM
       - cipher = create_aes_gcm_cipher(dek)
       - ciphertext_with_tag = concat(ciphertext, auth_tag)
       - TRY:
           - plaintext = cipher.decrypt(nonce, ciphertext_with_tag, aad)
       - CATCH DecryptionError:
           - audit_logger.log_security_violation("authentication_tag_mismatch")
           - RETURN Error::AuthenticationFailed

    6. Check rotation schedule
       - IF should_rotate(encrypted_value.created_at) THEN
           - trigger_rotation_async(tenant_id, encrypted_value.key_id)

    7. Audit log (async)
       - audit_logger.log_async({
           event_type: "secret.decrypt",
           tenant_id: tenant_id,
           key_id: encrypted_value.key_id,
           result: "success",
           timestamp: utc_now()
         })

    8. RETURN Ok(plaintext)

SECURITY: Constant-time comparison for auth tags
AUDIT: All decryption attempts logged
ROTATION: Automatic trigger based on key age
```

## 2.3 Version Control and Rollback

### Rollback Algorithm

```pseudocode
FUNCTION rollback_configuration(namespace, key, target_version, tenant_id, user_context)
  INPUT:
    - namespace: String
    - key: String
    - target_version: u64
    - tenant_id: UUID
    - user_context: AuthContext

  OUTPUT:
    - Result<Version, RollbackError>

  STEPS:
    1. Check elevated privileges
       - IF NOT policy_engine.authorize(user_context, namespace, Action::Admin) THEN
           - RETURN Error::InsufficientPrivileges("Rollback requires admin role")

    2. Acquire distributed lock
       - lock_key = format!("rollback-lock-{}-{}-{}", tenant_id, namespace, key)
       - lock = distributed_lock.acquire(lock_key, timeout=30s)
       - IF lock.failed THEN
           - RETURN Error::LockAcquisitionFailed("Concurrent rollback in progress")

    3. Fetch current configuration
       - current_config = vault_client.read(construct_vault_path(tenant_id, namespace, key))
       - current_version = current_config.version

    4. Fetch target version from history
       - target_config = db.query_one("
           SELECT * FROM config_versions
           WHERE config_id = $1 AND version_number = $2
         ", [current_config.id, target_version])
       - IF target_config.is_none() THEN
           - RETURN Error::VersionNotFound("Target version does not exist")

    5. Validate rollback safety
       - IF NOT is_rollback_safe(current_config, target_config) THEN
           - # Check for breaking schema changes
           - RETURN Error::UnsafeRollback("Schema incompatibility detected")

    6. Begin transaction
       - transaction = storage.begin_transaction()
       - TRY:

    7. Create new rollback version entry
       - new_version_number = current_version + 1
       - rollback_entry = ConfigVersion {
           id: generate_uuid_v4(),
           config_id: current_config.id,
           version_number: new_version_number,
           value: target_config.value,
           change_type: ChangeType::Rollback,
           changed_by: user_context.user_id,
           changed_at: utc_now(),
           change_reason: format!("Rollback to version {}", target_version),
           diff: compute_json_diff(current_config.value, target_config.value),
           rollback_to: Some(target_version),
           is_rollback: true
         }

    8. Update configuration in Vault
       - vault_path = construct_vault_path(tenant_id, namespace, key)
       - rolled_back_config = current_config.clone()
       - rolled_back_config.value = target_config.value
       - rolled_back_config.version = new_version_number
       - rolled_back_config.updated_at = utc_now()
       - rolled_back_config.updated_by = user_context.user_id
       - vault_client.write(vault_path, serialize_config(rolled_back_config))

    9. Update database
       - db.execute("
           UPDATE configurations
           SET version = $1, updated_at = $2, updated_by = $3
           WHERE id = $4
         ", [new_version_number, utc_now(), user_context.user_id, current_config.id])
       - db.execute("INSERT INTO config_versions ...", rollback_entry)

    10. Invalidate caches
        - L1.invalidate(format!("{}/{}", namespace, key))
        - redis_pubsub.publish("cache_invalidation", {...})

    11. Commit transaction
        - transaction.commit()

    12. Critical audit log (async, high priority)
        - audit_logger.log_critical_async({
            event_type: "config.rollback",
            actor: user_context.user_id,
            resource: format!("{}/{}", namespace, key),
            from_version: current_version,
            to_version: target_version,
            result: "success",
            timestamp: utc_now()
          })

    13. Notify all subscribers (critical notification)
        - notification_service.notify_critical({
            event: "config.rolledback",
            tenant_id: tenant_id,
            namespace: namespace,
            key: key,
            from_version: current_version,
            to_version: target_version
          })

    14. Release distributed lock
        - distributed_lock.release(lock)

    15. RETURN Ok(rollback_entry)

  CATCH error:
    - transaction.rollback()
    - distributed_lock.release(lock)
    - RETURN Err(error)

SAFETY: Schema compatibility check before rollback
CONCURRENCY: Distributed locking prevents concurrent rollbacks
AUDIT: Critical security event logging
```

## 2.4 Dynamic Reload Mechanism

### Hot-Reload Algorithm

```pseudocode
FUNCTION process_reload_event(event: ConfigChangeEvent)
  INPUT:
    - event: ConfigChangeEvent {
        tenant_id: UUID,
        namespace: String,
        key: String,
        new_version: u64,
        change_type: ChangeType
      }

  OUTPUT:
    - Result<(), ReloadError>

  STEPS:
    1. Fetch new configuration
       - new_config = vault_client.read(construct_vault_path(
           event.tenant_id, event.namespace, event.key
         ))
       - IF new_config.is_none() THEN
           - RETURN Error::ConfigNotFound

    2. Pre-validate configuration
       - schema = fetch_schema(new_config.schema_version)
       - IF NOT validate_json_schema(new_config.value, schema) THEN
           - RETURN Error::ValidationFailed("New config invalid")

    3. Pre-load and cache new configuration
       - # Pre-warm cache before swap
       - temp_cache_key = format!("reload-temp-{}-{}", event.namespace, event.key)
       - L1.set(temp_cache_key, new_config.value, TTL=1min)

    4. Acquire brief write lock
       - # Minimize lock duration for low latency
       - write_lock = config_registry.acquire_write_lock(event.namespace, event.key)
       - lock_start_time = utc_now()

    5. Atomic configuration swap
       - old_config = config_registry.get(event.namespace, event.key)
       - config_registry.set(event.namespace, event.key, new_config)
       - lock_duration = utc_now() - lock_start_time
       - metrics.record_lock_duration("config.reload.lock_ms", lock_duration)

    6. Release write lock immediately
       - write_lock.release()

    7. Notify reload hooks
       - hooks = reload_hook_registry.get_hooks(event.namespace, event.key)
       - FOR each hook IN hooks:
           - TRY:
               - hook.on_reload(old_config, new_config)
           - CATCH HookError:
               - log_error("Reload hook failed", hook.name, error)
               - # Continue with other hooks (non-blocking)

    8. Health check with automatic rollback
       - health_check_passed = true
       - TRY:
           - health_result = health_checker.check_config_health(
               event.namespace, event.key, timeout=5s
             )
           - IF NOT health_result.healthy THEN
               - health_check_passed = false
       - CATCH HealthCheckTimeout:
           - health_check_passed = false

       - IF NOT health_check_passed THEN
           - # Automatic rollback on failure
           - config_registry.set(event.namespace, event.key, old_config)
           - audit_logger.log_critical("config.reload.rollback", {
               reason: "health_check_failed",
               namespace: event.namespace,
               key: event.key
             })
           - RETURN Error::HealthCheckFailed("Rolled back to previous version")

    9. Update cache with final config
       - cache_key = format!("{}/{}", event.namespace, event.key)
       - L1.set(cache_key, new_config.value, TTL=5min)
       - L2.set(cache_key, new_config.value, TTL=15min)

    10. Emit metrics
        - metrics.increment("config.reload.success", tags={
            namespace: event.namespace,
            change_type: event.change_type
          })
        - metrics.record_histogram("config.reload.duration_ms", reload_duration)

    11. Audit log (async)
        - audit_logger.log_async({
            event_type: "config.reloaded",
            namespace: event.namespace,
            key: event.key,
            from_version: old_config.version,
            to_version: new_config.version,
            result: "success",
            timestamp: utc_now()
          })

    12. RETURN Ok(())

CONCURRENCY: Read-write lock with brief write duration (<1ms)
SAFETY: Pre-validation and health checks with automatic rollback
PERFORMANCE: Minimize lock contention through pre-loading
```

## 2.5 Multi-Tenant Isolation

### Tenant Boundary Enforcement

```pseudocode
FUNCTION enforce_tenant_isolation(operation, user_context, requested_tenant_id)
  INPUT:
    - operation: Operation (Read, Write, Delete, Admin)
    - user_context: AuthContext (contains authenticated tenant_id, user_id, roles)
    - requested_tenant_id: UUID (tenant being accessed)

  OUTPUT:
    - Result<TenantScope, IsolationError>

  STEPS:
    1. Extract authenticated tenant from context
       - authenticated_tenant_id = user_context.tenant_id

    2. Validate tenant is active
       - tenant = db.query_one("SELECT * FROM tenants WHERE id = $1", [requested_tenant_id])
       - IF tenant.is_none() THEN
           - RETURN Error::TenantNotFound
       - IF tenant.status != TenantStatus::Active THEN
           - RETURN Error::TenantSuspended("Tenant is not active")

    3. Check tenant quotas
       - IF operation IN [Operation::Write, Operation::Admin] THEN
           - usage = query_tenant_usage(requested_tenant_id)
           - IF usage.exceeds_quota(tenant.quotas) THEN
               - RETURN Error::QuotaExceeded(usage.limiting_resource)

    4. Validate same-tenant access (default: deny cross-tenant)
       - IF authenticated_tenant_id != requested_tenant_id THEN
           - # Check for explicit cross-tenant sharing policy
           - sharing_policy = db.query_one("
               SELECT * FROM cross_tenant_policies
               WHERE source_tenant = $1 AND target_tenant = $2 AND enabled = true
             ", [authenticated_tenant_id, requested_tenant_id])

           - IF sharing_policy.is_none() THEN
               - audit_logger.log_security_violation({
                   event_type: "cross_tenant_access_denied",
                   actor: user_context.user_id,
                   source_tenant: authenticated_tenant_id,
                   target_tenant: requested_tenant_id,
                   operation: operation
                 })
               - RETURN Error::CrossTenantAccessDenied

    5. Create isolated tenant scope
       - allowed_namespaces = db.query_all("
           SELECT namespace FROM namespace_permissions
           WHERE tenant_id = $1 AND user_id = $2
         ", [requested_tenant_id, user_context.user_id])

       - tenant_scope = TenantScope {
           tenant_id: requested_tenant_id,
           user_id: user_context.user_id,
           allowed_namespaces: allowed_namespaces,
           allowed_operations: derive_operations_from_roles(user_context.roles),
           encryption_key_id: tenant.encryption_key_id,
           quotas: tenant.quotas,
           isolation_mode: tenant.isolation_mode
         }

    6. Audit all isolation checks
       - audit_logger.log_async({
           event_type: "tenant.isolation_check",
           authenticated_tenant: authenticated_tenant_id,
           requested_tenant: requested_tenant_id,
           operation: operation,
           result: "allowed",
           timestamp: utc_now()
         })

    7. RETURN Ok(tenant_scope)

SECURITY: Default deny for cross-tenant access
AUDIT: All isolation checks logged
QUOTAS: Resource limits enforced at tenant boundary
```

## 2.6 RBAC Policy Evaluation

### Authorization Decision Algorithm

```pseudocode
FUNCTION evaluate_rbac_policy(user_context, action, resource)
  INPUT:
    - user_context: AuthContext (tenant_id, user_id, roles, attributes)
    - action: Action (Read, Write, Delete, Rotate, Admin)
    - resource: Resource (namespace, key)

  OUTPUT:
    - Result<AuthDecision, PolicyError>

  STEPS:
    1. Resolve effective user roles
       - direct_roles = user_context.roles
       - group_roles = db.query_all("
           SELECT role FROM group_roles
           WHERE user_id = $1 AND tenant_id = $2
         ", [user_context.user_id, user_context.tenant_id])
       - effective_roles = union(direct_roles, group_roles)

    2. Fetch applicable policies for resource
       - policies = policy_cache.get(resource.namespace)
       - IF policies.is_none() THEN
           - policies = db.query_all("
               SELECT * FROM rbac_policies
               WHERE tenant_id = $1 AND (
                 namespace = $2 OR
                 namespace LIKE $3 OR
                 namespace = '*'
               )
               ORDER BY specificity DESC
             ", [user_context.tenant_id, resource.namespace, format!("{}%", resource.namespace)])
           - policy_cache.set(resource.namespace, policies, TTL=5min)

    3. Evaluate policies with Deny > Allow precedence
       - deny_policies = filter_policies(policies, effect: Effect::Deny)
       - allow_policies = filter_policies(policies, effect: Effect::Allow)

       - # Check deny policies first
       - FOR each policy IN deny_policies:
           - IF matches_policy(policy, effective_roles, action, resource, user_context) THEN
               - audit_decision(policy, "deny", "explicit_deny_policy")
               - RETURN AuthDecision::Deny(policy.id)

       - # Check allow policies
       - FOR each policy IN allow_policies:
           - IF matches_policy(policy, effective_roles, action, resource, user_context) THEN
               - # Check conditional policies
               - IF policy.conditions.is_some() THEN
                   - IF NOT evaluate_conditions(policy.conditions, user_context) THEN
                       - CONTINUE  # Skip this policy
               - audit_decision(policy, "allow", "explicit_allow_policy")
               - RETURN AuthDecision::Allow(policy.id)

       - # Default deny if no matching allow policy
       - audit_decision(None, "deny", "default_deny")
       - RETURN AuthDecision::Deny(None)

    4. FUNCTION matches_policy(policy, roles, action, resource, context) -> bool:
         - # Role matching with wildcards
         - IF NOT match_roles(policy.roles, roles) THEN
             - RETURN false

         - # Action matching
         - IF NOT match_action(policy.actions, action) THEN
             - RETURN false

         - # Resource matching with hierarchical patterns
         - IF NOT match_resource_pattern(policy.resource_pattern, resource) THEN
             - RETURN false

         - RETURN true

    5. FUNCTION evaluate_conditions(conditions, context) -> bool:
         - # Time-based conditions
         - IF conditions.time_window.is_some() THEN
             - IF NOT is_within_time_window(utc_now(), conditions.time_window) THEN
                 - RETURN false

         - # IP-based conditions
         - IF conditions.ip_whitelist.is_some() THEN
             - IF NOT ip_in_whitelist(context.ip_address, conditions.ip_whitelist) THEN
                 - RETURN false

         - # Environment-based conditions
         - IF conditions.environment.is_some() THEN
             - IF context.environment != conditions.environment THEN
                 - RETURN false

         - # Custom attribute conditions
         - IF conditions.attributes.is_some() THEN
             - FOR each (key, expected_value) IN conditions.attributes:
                 - IF context.attributes.get(key) != expected_value THEN
                     - RETURN false

         - RETURN true

COMPLEXITY: O(p) where p = number of policies
CACHING: Policy evaluation results cached for 30s
PRECEDENCE: Deny policies always take priority over Allow
AUDIT: All authorization decisions logged
```

---

# 3. SPARC Phase 3: Architecture

**Status:** Complete
**Completion Date:** 2025-11-21
**Artifacts:** ARCHITECTURE.md, architecture-design.json, SYSTEM_ARCHITECTURE_SPECIFICATION.md

## 3.1 System Architecture Overview

### Layered Architecture Model

The LLM-Config-Manager follows a four-layer architecture pattern:

```
┌─────────────────────────────────────────────────────────────────┐
│                     PRESENTATION LAYER                          │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌──────────┐  │
│  │  REST API  │  │  gRPC API  │  │  GraphQL   │  │   CLI    │  │
│  │   (Axum)   │  │  (Tonic)   │  │  (Async)   │  │  (Clap)  │  │
│  └────────────┘  └────────────┘  └────────────┘  └──────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    APPLICATION LAYER                            │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌──────────┐  │
│  │  Config    │  │  Secrets   │  │  Version   │  │  Policy  │  │
│  │  Engine    │  │  Manager   │  │  Control   │  │  Engine  │  │
│  └────────────┘  └────────────┘  └────────────┘  └──────────┘  │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌──────────┐  │
│  │  Tenant    │  │  Namespace │  │ Validation │  │  Audit   │  │
│  │   Mgmt     │  │   Manager  │  │   Engine   │  │  Logger  │  │
│  └────────────┘  └────────────┘  └────────────┘  └──────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   INTEGRATION LAYER                             │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌──────────┐  │
│  │   Vault    │  │  Cloud KMS │  │   Policy   │  │   Obs.   │  │
│  │  Adapter   │  │  (AWS/GCP) │  │   Adapter  │  │  Export  │  │
│  └────────────┘  └────────────┘  └────────────┘  └──────────┘  │
│  ┌────────────┐  ┌────────────┐                                │
│  │   Cache    │  │ Pub/Sub    │                                │
│  │  (Redis)   │  │  (Redis)   │                                │
│  └────────────┘  └────────────┘                                │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      DATA LAYER                                 │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌──────────┐  │
│  │  Vault KV  │  │ PostgreSQL │  │    Sled    │  │   File   │  │
│  │  (Secrets) │  │  (Audit)   │  │  (Cache)   │  │ Storage  │  │
│  └────────────┘  └────────────┘  └────────────┘  └──────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## 3.2 Technology Stack

### Core Technologies

| Layer | Component | Technology | Version | Rationale |
|-------|-----------|------------|---------|-----------|
| **Language** | Core Runtime | Rust | 1.70+ | Memory safety, performance, async support |
| **HTTP Framework** | REST API | Axum | 0.7 | Modern, type-safe, Tower ecosystem |
| **gRPC Framework** | RPC API | Tonic | 0.11 | Best-in-class Rust gRPC, streaming support |
| **CLI Framework** | Command Line | Clap | 4.5 | Derive macros, excellent ergonomics |
| **Cryptography** | Encryption | Ring | 0.17 | Misuse-resistant, battle-tested |
| **Password Hashing** | Auth | Argon2 | 0.5 | Winner of password hashing competition |
| **TLS** | Transport Security | Rustls | 0.23 | Memory-safe TLS 1.3 implementation |

### Data Storage

| Component | Technology | Version | Purpose |
|-----------|------------|---------|---------|
| **Secrets Backend** | HashiCorp Vault | 1.14+ | Secrets storage, dynamic secrets |
| **Database** | PostgreSQL | 14+ | Audit logs, metadata, RBAC |
| **SQL Driver** | sqlx | 0.7 | Async SQL with compile-time checking |
| **Distributed Cache** | Redis | 7+ | L2 cache, pub/sub for invalidation |
| **Embedded DB** | Sled | 0.34 | Local cache, embedded key-value store |

### Observability

| Component | Technology | Version | Purpose |
|-----------|------------|---------|---------|
| **Tracing** | tracing | 0.1 | Structured logging, distributed tracing |
| **Metrics** | metrics | 0.22 | Application metrics collection |
| **Metrics Export** | metrics-exporter-prometheus | 0.13 | Prometheus format export |
| **Distributed Tracing** | OpenTelemetry | 0.21 | OTLP export to Observatory |

### Cloud Integrations

| Cloud Provider | SDK | Version | Purpose |
|----------------|-----|---------|---------|
| **AWS** | rusoto_kms, rusoto_secretsmanager | 0.48 | AWS KMS, Secrets Manager |
| **GCP** | gcp_auth, google-cloudkms1 | 0.12, 5.0 | GCP Cloud KMS, Secret Manager |
| **Azure** | azure_security_keyvault | 0.20 | Azure Key Vault |

## 3.3 Component Architecture

### Configuration Engine

**Responsibilities:**
- Configuration CRUD operations
- Environment-based resolution and overrides
- Template variable substitution
- Configuration diffing and comparison

**Key Interfaces:**
```rust
pub trait ConfigurationEngine {
    async fn get(&self, namespace: &str, key: &str, env: Option<&str>) -> Result<ConfigValue>;
    async fn set(&self, namespace: &str, key: &str, value: ConfigValue, metadata: ConfigMetadata) -> Result<ConfigId>;
    async fn delete(&self, namespace: &str, key: &str) -> Result<()>;
    async fn list(&self, namespace: &str, filter: Option<Filter>) -> Result<Vec<Configuration>>;
    async fn diff(&self, namespace: &str, key: &str, v1: u64, v2: u64) -> Result<JsonPatch>;
}
```

### Secrets Manager

**Responsibilities:**
- Secret encryption and decryption (envelope encryption)
- Secret rotation scheduling and execution
- Integration with Vault and cloud KMS providers
- Secret expiration and lifecycle management

**Key Interfaces:**
```rust
pub trait SecretsManager {
    async fn encrypt(&self, plaintext: &[u8], tenant_id: Uuid, metadata: SecretMetadata) -> Result<EncryptedValue>;
    async fn decrypt(&self, encrypted: &EncryptedValue, tenant_id: Uuid) -> Result<Vec<u8>>;
    async fn rotate(&self, secret_id: Uuid, rotation_policy: RotationPolicy) -> Result<()>;
    async fn schedule_rotation(&self, secret_id: Uuid, schedule: CronSchedule) -> Result<()>;
}
```

### Policy Engine (RBAC/ABAC)

**Responsibilities:**
- Authorization decision evaluation
- Policy caching and invalidation
- Role and permission management
- Attribute-based condition evaluation

**Key Interfaces:**
```rust
pub trait PolicyEngine {
    async fn authorize(&self, context: &AuthContext, action: Action, resource: &Resource) -> Result<AuthDecision>;
    async fn create_policy(&self, policy: Policy) -> Result<PolicyId>;
    async fn update_policy(&self, policy_id: PolicyId, policy: Policy) -> Result<()>;
    async fn delete_policy(&self, policy_id: PolicyId) -> Result<()>;
    async fn list_policies(&self, filter: Option<PolicyFilter>) -> Result<Vec<Policy>>;
}
```

### Version Control

**Responsibilities:**
- Version history management
- Rollback operations with validation
- Diff generation (JSON Patch format)
- Change audit trail

**Key Interfaces:**
```rust
pub trait VersionControl {
    async fn create_version(&self, config_id: Uuid, value: ConfigValue, metadata: VersionMetadata) -> Result<Version>;
    async fn get_version(&self, config_id: Uuid, version: u64) -> Result<Version>;
    async fn list_versions(&self, config_id: Uuid, limit: Option<usize>) -> Result<Vec<Version>>;
    async fn rollback(&self, config_id: Uuid, target_version: u64, context: &AuthContext) -> Result<Version>;
    async fn diff(&self, config_id: Uuid, v1: u64, v2: u64) -> Result<JsonPatch>;
}
```

### Audit Logger

**Responsibilities:**
- Comprehensive audit logging
- Immutable audit trail
- Structured log formatting (JSON)
- Integration with LLM-Observatory

**Key Interfaces:**
```rust
pub trait AuditLogger {
    async fn log(&self, event: AuditEvent) -> Result<()>;
    fn log_async(&self, event: AuditEvent);
    async fn query(&self, filter: AuditFilter, pagination: Pagination) -> Result<Vec<AuditEvent>>;
    async fn export(&self, filter: AuditFilter, format: ExportFormat) -> Result<Vec<u8>>;
}
```

## 3.4 Data Models

### Core Data Structures

#### Configuration

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Configuration {
    pub id: Uuid,
    pub tenant_id: Uuid,
    pub namespace: String,
    pub key: String,
    pub value: ConfigValue,
    pub schema_version: String,
    pub encrypted: bool,
    pub encryption_key_id: Option<String>,
    pub version: u64,
    pub created_at: DateTime<Utc>,
    pub created_by: String,
    pub updated_at: DateTime<Utc>,
    pub updated_by: String,
    pub expires_at: Option<DateTime<Utc>>,
    pub tags: HashMap<String, String>,
}
```

#### ConfigValue (Polymorphic)

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "value")]
pub enum ConfigValue {
    String(String),
    Number(f64),
    Integer(i64),
    Boolean(bool),
    Object(HashMap<String, ConfigValue>),
    Array(Vec<ConfigValue>),
    Secret(EncryptedValue),
    Reference(ConfigReference),
    Template(TemplateValue),
}
```

#### Namespace

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Namespace {
    pub id: Uuid,
    pub tenant_id: Uuid,
    pub path: String,  // "org/project/service/environment"
    pub name: String,
    pub parent_id: Option<Uuid>,
    pub metadata: NamespaceMetadata,
    pub quotas: ResourceQuotas,
    pub created_at: DateTime<Utc>,
    pub created_by: String,
}
```

#### EncryptedValue

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EncryptedValue {
    pub ciphertext: String,        // base64 encoded
    pub encrypted_dek: String,     // base64 encoded
    pub kek_id: String,            // KEK identifier
    pub algorithm: EncryptionAlgorithm,
    pub nonce: String,             // base64 encoded
    pub auth_tag: Option<String>,  // base64 encoded
}
```

### Database Schema (PostgreSQL)

```sql
-- Tenants table
CREATE TABLE tenants (
    id UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL,  -- Active, Suspended, Deleted
    encryption_key_id VARCHAR(255),
    quotas JSONB,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Configurations metadata table
CREATE TABLE configurations (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    namespace VARCHAR(512) NOT NULL,
    key VARCHAR(255) NOT NULL,
    value_type VARCHAR(50),
    encrypted BOOLEAN NOT NULL DEFAULT false,
    encryption_key_id VARCHAR(255),
    schema_version VARCHAR(50),
    version BIGINT NOT NULL DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_by VARCHAR(255),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_by VARCHAR(255),
    expires_at TIMESTAMP WITH TIME ZONE,
    UNIQUE (tenant_id, namespace, key)
);

CREATE INDEX idx_configs_tenant_namespace ON configurations(tenant_id, namespace);
CREATE INDEX idx_configs_expires_at ON configurations(expires_at) WHERE expires_at IS NOT NULL;

-- Configuration versions table
CREATE TABLE config_versions (
    id UUID PRIMARY KEY,
    config_id UUID NOT NULL REFERENCES configurations(id),
    version_number BIGINT NOT NULL,
    value JSONB NOT NULL,
    change_type VARCHAR(50) NOT NULL,  -- Create, Update, Delete, Rollback
    changed_by VARCHAR(255),
    changed_at TIMESTAMP WITH TIME ZONE NOT NULL,
    change_reason TEXT,
    diff JSONB,
    git_commit VARCHAR(64),
    is_rollback BOOLEAN DEFAULT false,
    rollback_to BIGINT,
    UNIQUE (config_id, version_number)
);

CREATE INDEX idx_versions_config ON config_versions(config_id, version_number DESC);

-- Audit log table (immutable, append-only)
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    actor VARCHAR(255) NOT NULL,
    resource_type VARCHAR(50),
    resource_id VARCHAR(255),
    action VARCHAR(50),
    result VARCHAR(50),  -- Success, Failure, Denied
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    ip_address INET,
    user_agent TEXT,
    metadata JSONB
);

CREATE INDEX idx_audit_tenant_timestamp ON audit_logs(tenant_id, timestamp DESC);
CREATE INDEX idx_audit_actor ON audit_logs(actor, timestamp DESC);
CREATE INDEX idx_audit_resource ON audit_logs(resource_type, resource_id, timestamp DESC);

-- RBAC policies table
CREATE TABLE rbac_policies (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    effect VARCHAR(10) NOT NULL,  -- Allow, Deny
    roles TEXT[] NOT NULL,
    actions TEXT[] NOT NULL,
    resource_pattern VARCHAR(512) NOT NULL,
    conditions JSONB,
    enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    UNIQUE (tenant_id, name)
);

CREATE INDEX idx_policies_tenant_enabled ON rbac_policies(tenant_id, enabled);
```

## 3.5 Deployment Architectures

### 3.5.1 CLI Deployment

**Target Use Case:** Developer workstations, CI/CD pipelines, administrative operations

**Architecture:**
- Standalone binary (Linux, macOS, Windows)
- Local embedded database (Sled) for caching
- Direct integration with Vault/KMS APIs
- Offline-first with cache persistence

**Deployment:**
- Distribution: GitHub Releases, Homebrew, cargo install
- Configuration: `~/.llm-config-manager/config.toml`
- Authentication: OS keychain for token storage

**Resource Requirements:**
- CPU: Minimal (<10% single core)
- Memory: 50-100MB
- Storage: 100MB (binary + cache)

### 3.5.2 Microservice API Deployment

**Target Use Case:** Enterprise-wide centralized configuration service

**Architecture:**
- Kubernetes deployment with horizontal autoscaling
- Stateless API servers (3+ replicas)
- Shared PostgreSQL for metadata
- Shared Redis for distributed cache
- Integration with external Vault cluster

**Kubernetes Manifest:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llm-config-manager
  namespace: llm-devops
spec:
  replicas: 3
  selector:
    matchLabels:
      app: llm-config-manager
  template:
    metadata:
      labels:
        app: llm-config-manager
    spec:
      containers:
      - name: config-manager
        image: llm-config-manager:1.0.0
        ports:
        - containerPort: 8080  # REST API
          name: http
        - containerPort: 9090  # gRPC
          name: grpc
        - containerPort: 9091  # Metrics
          name: metrics
        env:
        - name: VAULT_ADDR
          valueFrom:
            configMapKeyRef:
              name: config-manager-config
              key: vault_addr
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: config-manager-secrets
              key: database_url
        - name: REDIS_URL
          valueFrom:
            configMapKeyRef:
              name: config-manager-config
              key: redis_url
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 1000m
            memory: 1Gi
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: llm-config-manager
  namespace: llm-devops
spec:
  selector:
    app: llm-config-manager
  ports:
  - name: http
    port: 80
    targetPort: 8080
  - name: grpc
    port: 9090
    targetPort: 9090
  type: ClusterIP
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: llm-config-manager-hpa
  namespace: llm-devops
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: llm-config-manager
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

**Resource Requirements (per replica):**
- CPU: 100m request, 1000m limit
- Memory: 256Mi request, 1Gi limit
- Storage: Shared PostgreSQL + Redis

### 3.5.3 Sidecar Deployment

**Target Use Case:** Ultra-low latency requirements (<5ms p99)

**Architecture:**
- Sidecar container injected into application pods
- Local in-memory cache (Sled)
- Async sync with central API
- Fallback to central API if cache miss

**Kubernetes Sidecar Injection:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llm-inference-service
spec:
  template:
    spec:
      containers:
      - name: inference-service
        image: llm-inference:latest
        env:
        - name: CONFIG_MANAGER_URL
          value: "http://localhost:8081"

      - name: config-manager-sidecar
        image: llm-config-manager-sidecar:1.0.0
        ports:
        - containerPort: 8081
          name: http
        env:
        - name: CENTRAL_API_URL
          value: "http://llm-config-manager.llm-devops.svc.cluster.local"
        - name: CACHE_MODE
          value: "aggressive"
        - name: SYNC_INTERVAL
          value: "30s"
        resources:
          requests:
            cpu: 50m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        volumeMounts:
        - name: cache
          mountPath: /var/cache/config-manager

      volumes:
      - name: cache
        emptyDir: {}
```

**Resource Requirements (per sidecar):**
- CPU: 50m request, 500m limit
- Memory: 128Mi request, 512Mi limit
- Storage: EmptyDir for local cache

### 3.5.4 Hybrid Deployment

**Target Use Case:** Mixed workload (critical + non-critical services)

**Architecture:**
- Central API for most services (95% of pods)
- Selective sidecar injection for latency-critical services (5% of pods)
- Shared cache and database layers
- Unified monitoring and audit logging

**Decision Criteria for Sidecar:**
- Service requires p99 latency < 5ms
- High read throughput (>1000 req/s per pod)
- Critical path for user-facing features
- Acceptable resource overhead

## 3.6 API Contracts

### REST API Specification

**Base URL:** `/api/v1`

#### Configuration Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/configs/{namespace}/{key}` | Retrieve configuration |
| POST | `/configs/{namespace}/{key}` | Create configuration |
| PUT | `/configs/{namespace}/{key}` | Update configuration |
| DELETE | `/configs/{namespace}/{key}` | Delete configuration |
| GET | `/configs/{namespace}` | List configurations in namespace |
| GET | `/configs/{namespace}/history` | Get version history |
| POST | `/configs/{namespace}/rollback` | Rollback configuration |
| POST | `/configs/bulk` | Bulk operations |
| POST | `/configs/validate` | Validate configuration |

**Example: Get Configuration**

```http
GET /api/v1/configs/acme-corp/ml-platform/inference/openai.api_key?environment=production HTTP/1.1
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
X-Tenant-ID: 550e8400-e29b-41d4-a716-446655440000

HTTP/1.1 200 OK
Content-Type: application/json

{
  "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "namespace": "acme-corp/ml-platform/inference",
  "key": "openai.api_key",
  "value": {
    "type": "Secret",
    "value": {
      "ciphertext": "Q2lwaGVydGV4dCBleGFtcGxl...",
      "algorithm": "AES256GCM"
    }
  },
  "version": 5,
  "created_at": "2025-01-15T10:30:00Z",
  "updated_at": "2025-11-20T14:22:00Z"
}
```

### gRPC API Specification

**Service Definition (Protocol Buffers):**

```protobuf
syntax = "proto3";

package llm.config.v1;

service ConfigService {
  rpc GetConfiguration(GetConfigRequest) returns (Configuration);
  rpc SetConfiguration(SetConfigRequest) returns (ConfigResponse);
  rpc DeleteConfiguration(DeleteConfigRequest) returns (DeleteConfigResponse);
  rpc ListConfigurations(ListConfigRequest) returns (stream Configuration);
  rpc WatchConfiguration(WatchConfigRequest) returns (stream ConfigChangeEvent);
}

message GetConfigRequest {
  string namespace = 1;
  string key = 2;
  optional string environment = 3;
  string tenant_id = 4;
}

message Configuration {
  string id = 1;
  string namespace = 2;
  string key = 3;
  oneof value {
    string string_value = 4;
    int64 int_value = 5;
    double double_value = 6;
    bool bool_value = 7;
    bytes encrypted_value = 8;
  }
  uint64 version = 9;
  int64 created_at = 10;
  int64 updated_at = 11;
}

message ConfigChangeEvent {
  string config_id = 1;
  string namespace = 2;
  string key = 3;
  uint64 new_version = 4;
  ChangeType change_type = 5;
  int64 timestamp = 6;
}

enum ChangeType {
  CREATE = 0;
  UPDATE = 1;
  DELETE = 2;
  ROLLBACK = 3;
}
```

## 3.7 Performance and Scalability Specifications

### Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Read Latency (Cached)** | p50 < 1ms, p99 < 5ms | In-memory cache hit |
| **Read Latency (DB)** | p50 < 10ms, p99 < 50ms | Cache miss, Vault fetch |
| **Write Latency** | p50 < 20ms, p99 < 50ms | Includes encryption, audit log |
| **Rollback Latency** | p50 < 50ms, p99 < 200ms | Includes validation, cache invalidation |
| **API Throughput** | 50,000+ req/s | With 85% cache hit rate |
| **Cache Hit Rate** | ≥ 85% | Under normal load |
| **Startup Time** | < 5 seconds | API server initialization |

### Scalability Targets

| Dimension | Target | Notes |
|-----------|--------|-------|
| **Active Tenants** | 10,000+ | Tested with synthetic load |
| **Configurations per Tenant** | 100,000+ | Tested with pagination |
| **Concurrent Connections** | 10,000+ | WebSocket and gRPC |
| **API Server Replicas** | 10+ | Horizontal scaling |
| **Database Size** | 1TB+ | PostgreSQL with partitioning |
| **Cache Size** | 100GB+ | Redis cluster |

### Caching Strategy

**Three-Level Cache Hierarchy:**

1. **L1 Cache (In-Memory, per-instance)**
   - Technology: moka (Rust LRU cache)
   - Size: 100MB per instance
   - TTL: 5 minutes
   - Eviction: LRU
   - Invalidation: Redis pub/sub notifications

2. **L2 Cache (Distributed, Redis)**
   - Technology: Redis Cluster
   - Size: 10-100GB (configurable)
   - TTL: 15 minutes
   - Eviction: LRU with volatile-lru policy
   - Persistence: RDB snapshots every 5 minutes

3. **L3 Cache (Source of Truth, Vault)**
   - Technology: HashiCorp Vault
   - Storage Backend: Raft or Consul
   - Replication: Multi-datacenter
   - Backup: Hourly snapshots

### Cache Invalidation Strategy

**Pub/Sub Pattern:**
```rust
// On configuration update
redis_pubsub.publish("config:invalidate", json!({
    "tenant_id": tenant_id,
    "namespace": namespace,
    "key": key,
    "version": new_version,
    "timestamp": utc_now()
}));

// All instances subscribe and invalidate
redis_subscriber.on_message("config:invalidate", |msg| {
    let invalidation: CacheInvalidation = serde_json::from_str(&msg)?;
    L1_cache.invalidate(&invalidation.cache_key());
    L2_cache.invalidate(&invalidation.cache_key());
});
```

---

# 4. SPARC Phase 4: Refinement

**Status:** Complete
**Completion Date:** 2025-11-21
**Artifacts:** REFINEMENT.md, refinement-strategy.json

## 4.1 Iterative Development Strategy

### Sprint-Based Delivery Model

**Total Duration:** 32 weeks (16 sprints, 2 weeks each)

**Phase Breakdown:**
- **MVP Phase:** Sprints 1-4 (8 weeks)
- **Beta Phase:** Sprints 5-10 (12 weeks)
- **V1.0 Phase:** Sprints 11-16 (12 weeks)

### Sprint Structure

Each sprint follows a consistent pattern:

```
Week 1:
- Day 1-2: Sprint planning, story refinement
- Day 3-5: Development (feature implementation)

Week 2:
- Day 1-3: Development (completion, testing)
- Day 4: Code review, integration testing
- Day 5: Sprint review, retrospective, demo
```

### Quality Gates

Each sprint must pass quality gates before proceeding:

1. **Code Quality Gate:**
   - All tests passing (unit, integration)
   - Code coverage meets target (80%+)
   - No compiler warnings
   - Clippy lints passing
   - cargo fmt applied

2. **Security Gate:**
   - No critical/high vulnerabilities (cargo audit)
   - Security review for crypto/auth code
   - OWASP compliance checks
   - Secrets not exposed in logs

3. **Performance Gate:**
   - Benchmark targets met
   - No performance regression >10%
   - Load testing passed
   - Resource usage within limits

4. **Documentation Gate:**
   - API documentation updated
   - Code comments for complex logic
   - Integration guide updated
   - Changelog maintained

## 4.2 Testing Strategy

### Test Pyramid

```
                 ▲
                / \
               /   \
              /  E2E \           10% - End-to-End Tests
             /-------\
            /         \
           / Integration \       30% - Integration Tests
          /-------------\
         /               \
        /   Unit Tests    \     60% - Unit Tests
       /-------------------\
```

### Unit Testing

**Target Coverage:** 90% (MVP: 80%, Beta: 85%, V1.0: 90%)

**Framework:** cargo test with tokio-test for async

**Example Test:**
```rust
#[cfg(test)]
mod tests {
    use super::*;
    use mockall::predicate::*;

    #[tokio::test]
    async fn test_get_config_with_cache_hit() {
        let mut mock_cache = MockCache::new();
        mock_cache.expect_get()
            .with(eq("test/config"))
            .returning(|_| Some(ConfigValue::String("cached".to_string())));

        let engine = ConfigurationEngine::new(mock_cache, mock_vault);
        let result = engine.get("test", "config", None).await.unwrap();

        assert_eq!(result, ConfigValue::String("cached".to_string()));
    }
}
```

### Integration Testing

**Target Coverage:** 85% (MVP: 60%, Beta: 75%, V1.0: 85%)

**Framework:** cargo test with testcontainers for external services

**Example Test:**
```rust
#[tokio::test]
async fn test_config_crud_with_vault() {
    let vault = testcontainers::clients::Cli::default()
        .run(testcontainers::images::generic::GenericImage::new("vault:1.14"));

    let vault_addr = format!("http://localhost:{}", vault.get_host_port_ipv4(8200));

    let engine = ConfigurationEngine::new_with_vault(&vault_addr).await;

    // Test create
    let config_id = engine.set("test", "key", ConfigValue::String("value".to_string())).await.unwrap();

    // Test read
    let value = engine.get("test", "key", None).await.unwrap();
    assert_eq!(value, ConfigValue::String("value".to_string()));

    // Test update
    engine.set("test", "key", ConfigValue::String("new_value".to_string())).await.unwrap();

    // Test delete
    engine.delete("test", "key").await.unwrap();
    assert!(engine.get("test", "key", None).await.is_err());
}
```

### End-to-End Testing

**Target Coverage:** 70% (MVP: Manual, Beta: 50%, V1.0: 70%)

**Framework:** cargo test with full system deployment

**Example Test:**
```rust
#[tokio::test]
async fn test_full_config_lifecycle() {
    let test_env = deploy_test_environment().await;

    // Create configuration via REST API
    let client = reqwest::Client::new();
    let response = client.post(&format!("{}/api/v1/configs/test/key", test_env.api_url))
        .json(&json!({
            "value": {"type": "String", "value": "test"},
            "schema_version": "1.0"
        }))
        .send()
        .await
        .unwrap();
    assert_eq!(response.status(), 201);

    // Retrieve via gRPC API
    let mut grpc_client = ConfigServiceClient::connect(test_env.grpc_url).await.unwrap();
    let request = GetConfigRequest {
        namespace: "test".to_string(),
        key: "key".to_string(),
        ..Default::default()
    };
    let response = grpc_client.get_configuration(request).await.unwrap();
    assert_eq!(response.into_inner().value, "test");

    // Verify audit log
    let audit_logs = test_env.query_audit_logs("config.write").await;
    assert!(!audit_logs.is_empty());
}
```

### Performance Testing

**Framework:** criterion.rs for benchmarks

**Example Benchmark:**
```rust
use criterion::{black_box, criterion_group, criterion_main, Criterion};

fn bench_config_read_cached(c: &mut Criterion) {
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let engine = runtime.block_on(async {
        ConfigurationEngine::new_with_test_cache().await
    });

    c.bench_function("config_read_cached", |b| {
        b.to_async(&runtime).iter(|| async {
            engine.get(
                black_box("test"),
                black_box("key"),
                None
            ).await.unwrap()
        })
    });
}

criterion_group!(benches, bench_config_read_cached);
criterion_main!(benches);
```

**Performance Targets:**
- Config read (cached): < 1ms (p99)
- Config read (vault): < 50ms (p99)
- Config write: < 50ms (p99)
- Encryption/decryption: < 10ms (p99)

### Security Testing

**Penetration Testing:**
- Scheduled: End of Sprint 6 (Beta), End of Sprint 16 (V1.0)
- Third-party: External security firm for V1.0
- Focus: Authentication, authorization, injection attacks, encryption

**Vulnerability Scanning:**
- Automated: cargo audit in CI/CD (every commit)
- Dependency scanning: Dependabot (weekly)
- Container scanning: Trivy (every build)

**Fuzzing:**
```rust
use cargo_fuzz::fuzz_target;

fuzz_target!(|data: &[u8]| {
    if let Ok(s) = std::str::from_utf8(data) {
        let _ = serde_json::from_str::<ConfigValue>(s);
    }
});
```

## 4.3 Security Hardening

### Defense in Depth

**Layer 1: Network Security**
- TLS 1.3 for all communications
- mTLS for service-to-service communication
- Network policies in Kubernetes (deny-by-default)
- API rate limiting (1000 req/min per client)

**Layer 2: Authentication**
- JWT tokens with RS256 signatures
- OAuth2/OIDC integration for human users
- mTLS certificates for service accounts
- API key rotation every 90 days

**Layer 3: Authorization**
- RBAC/ABAC with deny-by-default
- Policy-based access control via LLM-Policy-Engine
- Least privilege principle
- Attribute-based conditions (time, IP, environment)

**Layer 4: Data Encryption**
- AES-256-GCM for data at rest
- Envelope encryption (KEK → DEK → Data)
- Separate encryption keys per tenant
- Automatic key rotation (365 days)

**Layer 5: Audit and Monitoring**
- Comprehensive audit logging
- Immutable audit trail (append-only)
- Real-time anomaly detection
- Security event alerting

### Secure Development Practices

1. **Code Review:**
   - All code reviewed by 2+ engineers
   - Security-focused review for crypto/auth code
   - Automated static analysis (clippy, cargo-audit)

2. **Secret Management:**
   - No secrets in code or git history
   - Environment variables for configuration
   - Vault for secret storage
   - Secret rotation automation

3. **Input Validation:**
   - Schema validation for all inputs
   - SQL injection prevention (parameterized queries)
   - XSS prevention (output encoding)
   - Path traversal prevention

4. **Error Handling:**
   - No sensitive data in error messages
   - Generic error messages for security failures
   - Detailed errors in audit logs only
   - Rate limiting on error responses

## 4.4 Performance Optimization

### Optimization Strategies

**1. Caching:**
- Three-level cache hierarchy (L1/L2/L3)
- Intelligent cache warming
- Predictive prefetching based on access patterns
- Cache compression for large values

**2. Database Optimization:**
- Connection pooling (10-100 connections)
- Query optimization with EXPLAIN ANALYZE
- Index optimization for hot queries
- Partitioning for large tables (audit logs)

**3. Concurrency:**
- Async/await for all I/O operations
- Tokio runtime with work-stealing scheduler
- Read-write locks for minimal write contention
- Lock-free data structures where possible

**4. Memory Optimization:**
- Zero-copy deserialization where possible
- Memory pooling for frequent allocations
- Streaming for large responses
- Compression for network transfers

**5. Network Optimization:**
- HTTP/2 with multiplexing
- gRPC streaming for bulk operations
- Request batching to reduce round trips
- Connection keep-alive

### Profiling and Monitoring

**Tools:**
- flamegraph for CPU profiling
- valgrind/massif for memory profiling
- tokio-console for async task monitoring
- perf for system-level profiling

**Metrics:**
- Request latency histograms (p50, p95, p99)
- Throughput (req/s)
- Error rate
- Cache hit rate
- Database query time
- Memory usage
- CPU usage

## 4.5 Feedback Loops

### Continuous Integration

**CI Pipeline (GitHub Actions):**
```yaml
name: CI Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
      - name: Run tests
        run: cargo test --all-features

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Format check
        run: cargo fmt --all -- --check
      - name: Clippy
        run: cargo clippy --all-targets -- -D warnings

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Security audit
        run: cargo audit

  benchmark:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run benchmarks
        run: cargo bench --no-fail-fast
```

### User Feedback

**Beta Testing Program:**
- 5+ beta organizations
- Weekly feedback sessions
- Bug reports via GitHub Issues
- Feature requests via GitHub Discussions

**Feedback Channels:**
- Sprint reviews (every 2 weeks)
- User surveys (monthly)
- Support tickets (continuous)
- Community forum (continuous)

### Retrospectives

**Sprint Retrospective (every 2 weeks):**
- What went well?
- What didn't go well?
- Action items for improvement

**Phase Retrospective (after MVP, Beta, V1.0):**
- Major achievements
- Challenges and learnings
- Process improvements
- Technical debt assessment

---

# 5. SPARC Phase 5: Completion

**Status:** In Progress
**Start Date:** 2025-11-21
**Artifacts:** 5-COMPLETION.md, IMPLEMENTATION-ROADMAP.md, completion-roadmap.json

## 5.1 Phased Delivery Roadmap

### Phase Overview

| Phase | Version | Duration | Sprints | Status |
|-------|---------|----------|---------|--------|
| **MVP** | 0.1.0 | 8 weeks | 1-4 | Planned |
| **Beta** | 0.5.0 | 12 weeks | 5-10 | Planned |
| **V1.0** | 1.0.0 | 12 weeks | 11-16 | Planned |

## 5.2 MVP Phase (v0.1.0)

**Duration:** Sprints 1-4 (8 weeks)
**Goal:** Core functionality with basic security

### Sprint 1: Configuration CRUD & File-Based Storage

**Week 1-2**

**Features:**
- Configuration CRUD operations (Create, Read, Update, Delete)
- File-based storage with atomic operations
- Basic data validation
- Project structure and CI/CD setup

**Deliverables:**
- Core data models (Configuration, ConfigValue, Namespace)
- File storage adapter with atomic writes
- Unit tests (70% coverage target)
- CI/CD pipeline (GitHub Actions)

**Acceptance Criteria:**
- Configuration can be stored and retrieved
- File operations are atomic (no partial writes)
- Unit tests passing
- CI/CD pipeline operational

### Sprint 2: Encryption & Versioning

**Week 3-4**

**Features:**
- AES-256-GCM encryption for secrets
- Basic key management (environment variables)
- Configuration versioning with history
- Rollback capability

**Deliverables:**
- Encryption/decryption module
- Key management with rotation support
- Version control implementation
- Integration tests for encryption

**Acceptance Criteria:**
- Secrets encrypted at rest
- Versioning tracks all changes
- Rollback to any previous version working
- Key rotation mechanism functional

### Sprint 3: CLI Interface & Environment Management

**Week 5-6**

**Features:**
- CLI tool with all CRUD commands
- Environment-based configuration (dev, staging, prod)
- Configuration override resolution
- Interactive mode for complex operations

**Deliverables:**
- CLI binary (clap-based)
- Environment override logic
- Shell completion scripts
- CLI integration tests

**Acceptance Criteria:**
- All CLI commands functional
- Environment inheritance working
- Help documentation complete
- CLI builds for Linux, macOS, Windows

### Sprint 4: Validation & First Integration

**Week 7-8**

**Features:**
- Schema-based configuration validation
- LLM-Prompt-Manager integration
- Error handling and reporting
- MVP release preparation

**Deliverables:**
- JSON Schema validation engine
- Prompt Manager integration adapter
- Comprehensive error messages
- MVP release (v0.1.0)

**Acceptance Criteria:**
- All P0 features complete
- Unit test coverage ≥ 80%
- Zero critical vulnerabilities
- Prompt Manager integration validated

**MVP Success Metrics:**
- Read latency: < 10ms (p95)
- Write latency: < 50ms (p95)
- Support 1,000 configs per tenant
- Zero critical security vulnerabilities

## 5.3 Beta Phase (v0.5.0)

**Duration:** Sprints 5-10 (12 weeks)
**Goal:** Enterprise features and production hardening

### Sprint 5-6: Vault Integration & RBAC

**Week 9-12**

**Features:**
- HashiCorp Vault integration (KV v2)
- Token and AppRole authentication
- Role-Based Access Control (RBAC)
- Permission management

**Deliverables:**
- Vault adapter implementation
- RBAC policy engine
- Migration tool (file → Vault)
- Security review report

**Acceptance Criteria:**
- Vault integration operational
- RBAC denies unauthorized access
- Migration tool tested with 1000+ configs
- Security review passed

### Sprint 7: Audit Logging & REST API

**Week 13-14**

**Features:**
- Comprehensive audit logging
- REST API service (Axum)
- API authentication (JWT)
- OpenAPI specification

**Deliverables:**
- Audit logger implementation
- REST API endpoints
- API documentation (OpenAPI)
- Postman collection

**Acceptance Criteria:**
- All mutations logged to audit trail
- REST API functional
- API documentation complete
- JWT authentication working

### Sprint 8: REST API Enhancement & Import/Export

**Week 15-16**

**Features:**
- Bulk operations
- Import/export tools (JSON, YAML)
- LLM-Gateway integration
- Performance optimization

**Deliverables:**
- Bulk API endpoints
- Import/export CLI commands
- Gateway integration adapter
- Performance benchmark report

**Acceptance Criteria:**
- Bulk operations handle 1000+ configs
- Import/export tested with large datasets
- Gateway integration validated
- Performance targets met (< 5ms p95 cached)

### Sprint 9: Templates & Caching

**Week 17-18**

**Features:**
- Configuration templates with variable substitution
- Redis distributed cache (L2)
- Cache invalidation via pub/sub
- LLM-Observatory integration

**Deliverables:**
- Template engine
- Redis cache adapter
- Pub/sub invalidation
- Observatory metrics export

**Acceptance Criteria:**
- Templates support variable substitution
- Cache hit rate ≥ 80%
- Observatory receives metrics and traces
- Cache invalidation working across replicas

### Sprint 10: Advanced Validation & Beta Release

**Week 19-20**

**Features:**
- Custom validation rules (Rego/CEL)
- LLM-Cost-Optimizer integration
- Beta testing preparation
- Migration guides

**Deliverables:**
- Advanced validation engine
- Cost Optimizer integration
- Beta release (v0.5.0)
- Migration documentation

**Acceptance Criteria:**
- Custom validation rules functional
- 3+ LLM modules integrated
- Beta user feedback positive (≥ 90%)
- Migration success rate ≥ 95%

**Beta Success Metrics:**
- API throughput: ≥ 1000 req/s
- Read latency (cached): < 5ms (p95)
- Unit test coverage: ≥ 85%
- Integration test coverage: ≥ 75%
- 3+ module integrations validated

## 5.4 V1.0 Phase

**Duration:** Sprints 11-16 (12 weeks)
**Goal:** Production-ready with full feature set

### Sprint 11-12: Multi-Tenancy

**Week 21-24**

**Features:**
- Complete multi-tenant isolation
- Tenant lifecycle management
- Tenant-specific encryption keys
- Resource quotas

**Deliverables:**
- Multi-tenant architecture
- Tenant management API
- Isolation test suite
- Penetration testing report

**Acceptance Criteria:**
- Zero data leakage in penetration tests
- Support 100+ tenants
- Cryptographic isolation verified
- Tenant quotas enforced

### Sprint 13-14: Advanced RBAC & Drift Detection

**Week 25-28**

**Features:**
- Attribute-Based Access Control (ABAC)
- Configuration drift detection
- LLM-Gateway full integration
- LLM-Prompt-Manager full integration

**Deliverables:**
- ABAC policy engine
- Drift detection algorithm
- Full Gateway integration
- Full Prompt Manager integration

**Acceptance Criteria:**
- ABAC conditions evaluated correctly
- Drift detected and reported
- Gateway and Prompt Manager fully integrated
- All integration tests passing

### Sprint 15: Secrets Rotation & GraphQL API

**Week 29-30**

**Features:**
- Automated secret rotation
- Grace period management
- GraphQL API (optional)
- LLM-Observatory full integration

**Deliverables:**
- Rotation scheduler
- GraphQL API service
- Observatory full integration
- Rotation test suite

**Acceptance Criteria:**
- Rotation automated with zero downtime
- Grace period working correctly
- GraphQL queries functional
- Observatory integration complete

### Sprint 16: GitOps, Sidecar, & Production Launch

**Week 31-32**

**Features:**
- Configuration as Code (GitOps)
- Sidecar deployment mode
- Plugin system (extensibility)
- All SDKs (Rust, Python, Go, TypeScript)

**Deliverables:**
- GitOps sync engine
- Sidecar container
- Plugin SDK
- Production runbooks

**Acceptance Criteria:**
- GitOps sync working with Git repos
- Sidecar deployment tested
- 6+ module integrations complete
- Production readiness review passed

**V1.0 Success Metrics:**
- API throughput: ≥ 5000 req/s
- Uptime SLA: 99.9%
- Unit test coverage: ≥ 90%
- Integration test coverage: ≥ 85%
- E2E test coverage: ≥ 70%
- 6+ module integrations validated
- 10+ enterprise customers
- 100+ active users

## 5.5 Post-Launch (Continuous)

**Week 33+**

**Activities:**
- Production monitoring and support
- Incident response
- Bug fixes and patches
- Feature enhancements (v1.1, v1.2)
- Community engagement
- Security audits
- Performance reviews

**Success Metrics:**
- Uptime SLA: 99.9%
- Support resolution: < 24 hours
- Customer satisfaction: ≥ 95%
- NPS score: ≥ 50
- Monthly active users growth

## 5.6 Risk Management

### Critical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Vault integration complexity | Medium | High | Allocate 2 sprints; maintain file fallback; engage HashiCorp support |
| RBAC security vulnerabilities | Medium | Critical | Security reviews; penetration testing; OWASP guidelines; bug bounty |
| Performance targets not met | Low | Medium | Continuous benchmarking; early optimization; infrastructure scaling |
| Multi-tenancy isolation breach | Low | Critical | Architecture review; isolation tests; third-party audit |
| Integration delays (LLM modules) | Medium | Medium | Early coordination; staggered rollout; mock services; adapter pattern |
| Production incidents | Low | Critical | Comprehensive testing; gradual rollout; incident response plan; 24/7 on-call |

### Mitigation Strategies

**Vault Integration:**
- Week 1-2: Proof of concept with test Vault
- Week 3-4: Production integration with fallback
- Continuous: Monitor Vault performance and availability

**Security:**
- Sprint 6: Internal security review
- Sprint 10: External penetration testing
- Sprint 16: Third-party security audit

**Performance:**
- Every sprint: Benchmark regression tests
- Sprint 4: Load testing with 1000 configs
- Sprint 10: Load testing with 10,000 configs
- Sprint 16: Load testing with 100,000 configs

**Integration:**
- Sprint 1: Define integration contracts
- Sprint 4: First integration (Prompt Manager)
- Sprint 8-10: Additional integrations (Gateway, Observatory, Cost Optimizer)
- Sprint 13-16: Full integrations (all modules)

## 5.7 Resource Requirements

### Team Composition

**MVP Phase (Weeks 1-8):**
- 1 Senior Backend Developer (Rust) - Full-time
- 1 Security Engineer - Part-time (20%)
- 1 QA Engineer - Part-time (30%)

**Beta Phase (Weeks 9-20):**
- 2 Senior Backend Developers (Rust) - Full-time
- 1 Security Engineer - Full-time
- 1 DevOps/SRE Engineer - Full-time
- 1 QA Engineer - Full-time
- 1 Technical Writer - Part-time (50%)
- 1 Beta Program Manager - Part-time (50%)

**V1.0 Phase (Weeks 21-32):**
- 2-3 Senior Backend Developers - Full-time
- 1 Security Engineer - Full-time
- 1 DevOps/SRE Engineer - Full-time
- 2 QA Engineers - Full-time
- 1 Technical Writer - Full-time
- 1 Product Manager - Full-time
- 1 Customer Success Manager - Full-time
- 1 Support Engineer - Full-time

### Infrastructure Requirements

**Development:**
- Local development environments (Rust toolchain)
- Git repository (GitHub)
- CI/CD pipeline (GitHub Actions)

**Staging (Beta):**
- Kubernetes cluster (3+ nodes)
- Vault dev server
- PostgreSQL instance
- Redis instance
- Monitoring stack (Prometheus, Grafana)

**Production (V1.0):**
- Multi-zone Kubernetes cluster (5+ nodes)
- HA Vault cluster (3+ nodes)
- HA PostgreSQL cluster (primary + 2 replicas)
- Redis cluster (3+ nodes)
- Load balancer with health checks
- Monitoring and logging infrastructure
- Backup storage (S3/GCS, 7-year retention)

### Budget Estimate

**Personnel Costs (8 months):**
- MVP: $200K - $300K (2-3 FTE)
- Beta: $500K - $700K (5-6 FTE)
- V1.0: $600K - $800K (7-8 FTE)
- **Total Personnel:** $1.3M - $1.8M

**Infrastructure Costs (8 months):**
- MVP: $5K (dev/test environments)
- Beta: $20K (staging environment)
- V1.0: $50K (production environment)
- **Total Infrastructure:** $75K

**Third-Party Services:**
- Security audit (2x): $40K
- Penetration testing (2x): $30K
- Compliance certification (SOC2): $50K
- **Total Third-Party:** $120K

**Grand Total:** $1.5M - $2.0M

---

# 6. Appendix: Quick Reference

## 6.1 Key Documents

| Document | Location | Purpose |
|----------|----------|---------|
| **Specification** | `/plans/SPECIFICATION.json` | Functional requirements (FR-001 to FR-015) |
| **Pseudocode** | `/plans/PSEUDOCODE.md` | Algorithm designs and logic flows |
| **Architecture** | `/plans/ARCHITECTURE.md` | System architecture and component design |
| **Refinement** | `/plans/REFINEMENT.md` | Testing strategy and optimization |
| **Completion** | `/docs/5-COMPLETION.md` | Phased delivery roadmap |
| **Implementation Roadmap** | `/docs/IMPLEMENTATION-ROADMAP.md` | Detailed sprint breakdown |
| **Requirements Analysis** | `/docs/REQUIREMENTS_ANALYSIS.md` | Comprehensive requirements research |
| **System Architecture** | `/docs/SYSTEM_ARCHITECTURE_SPECIFICATION.md` | Complete architecture specification |
| **Executive Summary** | `/docs/EXECUTIVE-SUMMARY.md` | High-level project overview |
| **SPARC Progression** | `/docs/SPARC-STAGE-PROGRESSION.md` | SPARC methodology tracking |

## 6.2 Technology Stack Summary

### Core Technologies
- **Language:** Rust 1.70+
- **HTTP Framework:** Axum 0.7
- **gRPC Framework:** Tonic 0.11
- **Cryptography:** Ring 0.17, Argon2 0.5, Rustls 0.23
- **Database:** PostgreSQL 14+ (sqlx 0.7)
- **Cache:** Redis 7+ (distributed), Moka (in-memory), Sled 0.34 (embedded)
- **Secrets:** HashiCorp Vault (vaultrs 0.7), AWS/GCP/Azure KMS
- **Observability:** OpenTelemetry, Prometheus, tracing, metrics

## 6.3 Performance Targets

| Metric | Target |
|--------|--------|
| Read Latency (Cached) | p50 < 1ms, p99 < 5ms |
| Read Latency (Vault) | p50 < 10ms, p99 < 50ms |
| Write Latency | p50 < 20ms, p99 < 50ms |
| API Throughput | 50,000+ req/s |
| Cache Hit Rate | ≥ 85% |
| Uptime SLA | 99.9% |

## 6.4 Timeline Summary

| Phase | Duration | Sprints | Version |
|-------|----------|---------|---------|
| **MVP** | 8 weeks | 1-4 | 0.1.0 |
| **Beta** | 12 weeks | 5-10 | 0.5.0 |
| **V1.0** | 12 weeks | 11-16 | 1.0.0 |
| **Total** | 32 weeks | 16 | - |

## 6.5 Integration Summary

| Module | Core | Integration Type | Status |
|--------|------|------------------|--------|
| LLM-Observatory | Intelligence | Telemetry Export | Sprints 9, 14 |
| LLM-Gateway | Interface | Dynamic Configuration | Sprints 8, 13 |
| LLM-Prompt-Manager | Research | Template Storage | Sprints 4, 13 |
| LLM-Cost-Optimizer | Automation | Policy Management | Sprints 10, 14 |
| LLM-Security-Scanner | Security | Security Policies | Sprint 15 |
| LLM-Model-Router | Intelligence | Routing Configuration | Sprint 16 |

## 6.6 Success Metrics Rollup

| Metric | MVP | Beta | V1.0 |
|--------|-----|------|------|
| Unit Test Coverage | ≥80% | ≥85% | ≥90% |
| Integration Test Coverage | ≥60% | ≥75% | ≥85% |
| E2E Test Coverage | Manual | ≥50% | ≥70% |
| Security Vulnerabilities | 0 critical/high | 0 critical/high | 0 critical/high/medium |
| API Throughput | - | ≥1000 req/s | ≥5000 req/s |
| Module Integrations | 1 | 3+ | 6+ |
| Active Users | 5-10 (internal) | 20+ (beta) | 100+ (production) |
| Organizations | 1 | 5+ | 10+ |

## 6.7 Contact and Support

**Project Lead:** [TBD]
**Technical Lead:** [TBD]
**Security Lead:** [TBD]
**Product Owner:** [TBD]

**Communication Channels:**
- **Daily Standups:** Team-internal (15 minutes)
- **Weekly Status:** Email update to stakeholders (Fridays)
- **Sprint Reviews:** Demo to stakeholders (every 2 weeks)
- **Monthly Executive Summary:** High-level progress report

**Escalation Path:**
1. Team member → Team lead (same day)
2. Team lead → Technical lead (within 1 day)
3. Technical lead → Project lead (within 2 days)
4. Project lead → Executive sponsor (within 3 days)

---

## Document Metadata

| Attribute | Value |
|-----------|-------|
| **Created** | 2025-11-21 |
| **Version** | 1.0.0 |
| **Project** | LLM-Config-Manager |
| **Methodology** | SPARC |
| **Status** | Complete - Ready for Implementation |
| **Total Pages** | [Auto-generated] |
| **Last Updated** | 2025-11-21 |

---

## Approval Signatures

- [ ] **Technical Lead:** _________________ Date: _______
- [ ] **Security Lead:** _________________ Date: _______
- [ ] **Product Owner:** _________________ Date: _______
- [ ] **Executive Sponsor:** _____________ Date: _______

**Next Review:** End of MVP Phase (Week 8)

---

**End of SPARC Specification Document**
