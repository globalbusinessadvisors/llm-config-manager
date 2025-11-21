# LLM-Config-Manager Security Architecture

**Version:** 1.0.0
**Date:** 2025-11-21
**Author:** Security Architect Agent
**Status:** Draft for Review

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Security Principles](#security-principles)
3. [Recommended Rust Crates](#3-recommended-rust-crates)
4. [Encryption Strategies](#4-encryption-strategies)
5. [Access Control and RBAC](#5-access-control-and-rbac)
6. [Secret Rotation Mechanisms](#6-secret-rotation-mechanisms)
7. [Audit Logging and Compliance](#7-audit-logging-and-compliance)
8. [Validation Policies](#8-validation-policies)
9. [Threat Model and Mitigations](#9-threat-model-and-mitigations)
10. [Security Operations](#10-security-operations)

---

## Executive Summary

This document specifies the comprehensive security architecture for LLM-Config-Manager, focusing on production-ready Rust crates, encryption strategies, access control mechanisms, secret rotation policies, and audit logging implementations. The architecture follows zero-trust principles and defense-in-depth strategies to protect sensitive configuration data and secrets.

### Key Security Decisions

1. **Cryptography Stack:** Ring + RustCrypto for encryption, rustls for TLS, argon2 for key derivation
2. **Secrets Backend:** HashiCorp Vault as primary, with multi-cloud KMS support (AWS, GCP, Azure)
3. **Access Control:** RBAC with ABAC extensions using Casbin-rs and Open Policy Agent
4. **Audit Logging:** Structured logging with tracing + tracing-subscriber, immutable audit trail
5. **Validation:** JSON Schema validation with jsonschema crate, custom policy validation
6. **Secret Rotation:** Automated rotation with grace periods, health checks, and rollback capability

---

## 1. Security Principles

### 1.1 Zero-Trust Architecture

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

### 1.2 Defense in Depth

**Security Layers:**

```
┌─────────────────────────────────────────────────────────┐
│ Layer 7: Compliance & Governance                        │
│ - Regulatory compliance (SOC 2, GDPR, HIPAA)           │
│ - Policy enforcement and audit                          │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ Layer 6: Audit & Monitoring                             │
│ - Immutable audit logs with cryptographic integrity     │
│ - Real-time security monitoring and alerting            │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ Layer 5: Application Security                           │
│ - Input validation and sanitization                     │
│ - RBAC/ABAC authorization                               │
│ - Secure coding practices                               │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ Layer 4: Data Security                                  │
│ - Field-level encryption                                │
│ - Envelope encryption with KMS                          │
│ - Secure key management and rotation                    │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ Layer 3: Communication Security                         │
│ - TLS 1.3 with strong cipher suites                     │
│ - mTLS for service-to-service                           │
│ - Certificate management and rotation                   │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ Layer 2: Identity & Access Management                   │
│ - Strong authentication (mTLS, OAuth2/OIDC, JWT)        │
│ - Multi-factor authentication for humans               │
│ - Service account and workload identity                │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ Layer 1: Infrastructure Security                        │
│ - Network segmentation and firewalls                    │
│ - Container security and runtime protection             │
│ - Secrets management and isolation                      │
└─────────────────────────────────────────────────────────┘
```

### 1.3 Security by Design

**Principles:**
- Secure defaults (deny by default)
- Fail securely (no fail-open modes)
- Minimize attack surface
- Complete mediation (check every access)
- Separation of duties
- Privacy by design (data minimization, anonymization)

---

## 2. Recommended Rust Crates

### 2.1 Cryptography and Encryption

#### Core Cryptography

| Crate | Version | Purpose | Rationale |
|-------|---------|---------|-----------|
| **ring** | ^0.17 | AEAD encryption, key derivation, random generation | Battle-tested, misuse-resistant API, actively maintained. Preferred over deprecated sodiumoxide. Uses BoringSSL primitives. |
| **RustCrypto/aes-gcm** | ^0.10 | AES-256-GCM encryption | Pure Rust implementation, portable, constant-time operations |
| **chacha20poly1305** | ^0.10 | ChaCha20-Poly1305 AEAD | Alternative cipher for ARM/embedded systems without AES-NI hardware support |
| **rustls** | ^0.23 | TLS 1.2/1.3 implementation | Memory-safe, modern TLS stack. Outperforms OpenSSL in many scenarios. No C dependencies. |
| **rustls-native-certs** | ^0.7 | Native certificate loading | Loads platform's native certificate store for TLS |

**Ring Use Cases:**
```rust
use ring::aead::{Aad, BoundKey, Nonce, NonceSequence, OpeningKey, SealingKey, UnboundKey, AES_256_GCM};
use ring::rand::{SecureRandom, SystemRandom};
use ring::pbkdf2;

// AES-GCM encryption for configuration secrets
// HMAC for data integrity verification
// PBKDF2/HKDF for key derivation
// Secure random number generation
```

**Why Ring over Sodiumoxide:**
- Sodiumoxide is deprecated and no longer maintained
- Ring has broader primitive support and better performance
- Ring is misuse-resistant with strong type safety
- Used by major projects (rustls, webpki, etc.)

**Rationale for RustCrypto as Supplement:**
- Pure Rust implementations for better portability
- Constant-time operations for side-channel resistance
- Modular design allows selecting specific algorithms
- Active maintenance and security audits

#### Key Derivation and Password Hashing

| Crate | Version | Purpose | Rationale |
|-------|---------|---------|-----------|
| **argon2** | ^0.5 | Password hashing and key derivation | Winner of Password Hashing Competition, GPU-resistant, OWASP recommended. Supports Argon2id variant. |
| **pbkdf2** | ^0.12 | PBKDF2 key derivation | FIPS-140 compliant, required for some regulatory environments |
| **hkdf** | ^0.12 | HKDF key derivation | Extract-and-expand paradigm for deriving multiple keys from single master |

**Argon2 Configuration (OWASP Recommended):**
```rust
use argon2::{
    password_hash::{PasswordHasher, SaltString},
    Argon2, Params, Version,
};

// OWASP recommendation: 19 MiB memory, 2 iterations, 1 parallelism
let params = Params::new(
    19 * 1024,  // 19 MiB memory cost
    2,          // 2 iterations
    1,          // 1 degree of parallelism
    None        // output length (default 32 bytes)
).unwrap();

let argon2 = Argon2::new(
    argon2::Algorithm::Argon2id,  // Argon2id recommended for general use
    Version::V0x13,
    params,
);
```

**Use Cases:**
- **Argon2id**: Primary choice for password hashing and key derivation (side-channel resistant)
- **PBKDF2**: Legacy compatibility and FIPS-140 compliance requirements
- **HKDF**: Deriving multiple cryptographic keys from a single master secret

#### Digital Signatures and Certificates

| Crate | Version | Purpose | Rationale |
|-------|---------|---------|-----------|
| **ed25519-dalek** | ^2.1 | EdDSA signatures (Ed25519) | Fast, secure digital signatures for config signing and audit log integrity |
| **rsa** | ^0.9 | RSA signatures and encryption | Legacy compatibility, enterprise PKI integration |
| **x509-parser** | ^0.16 | X.509 certificate parsing | mTLS certificate validation, PKI integration |
| **webpki** | ^0.22 | Web PKI certificate validation | Certificate chain validation for TLS |

**Signature Use Cases:**
```rust
use ed25519_dalek::{Signature, Signer, SigningKey};

// Configuration signing for integrity
// Audit log tamper-evidence (Merkle tree signatures)
// Cryptographic proof of authenticity
```

### 2.2 Secrets Backend Integration

#### HashiCorp Vault

| Crate | Version | Purpose | Features |
|-------|---------|---------|----------|
| **vaultrs** | ^0.7 | Async Vault client | KV v1/v2, Transit, AppRole, Token, Kubernetes auth, Dynamic secrets, Seal/unseal |

**Capabilities:**
- **Authentication**: AppRole, AWS, JWT/OIDC, Kubernetes, Token, Certificate, Userpass
- **Secrets Engines**: KV v1/v2, AWS, Databases, PKI, SSH, Transit (encryption as a service)
- **System Operations**: Health checks, Policies, Sealing/unsealing, Wrapping tokens

**Example Integration:**
```rust
use vaultrs::client::{VaultClient, VaultClientSettingsBuilder};
use vaultrs::kv2;

// Initialize Vault client
let client = VaultClient::new(
    VaultClientSettingsBuilder::default()
        .address("https://vault.example.com")
        .token("s.token")
        .build()
        .unwrap()
).unwrap();

// Read secret from KV v2
let secret: Secret = kv2::read(&client, "secret", "database/credentials").await?;
```

**Production Considerations:**
- Use AppRole or Kubernetes auth (not root tokens)
- Enable TLS with certificate validation
- Implement token renewal and rotation
- Use lease management for dynamic secrets
- Configure appropriate TTLs for cached secrets

#### Cloud KMS Integrations

**AWS KMS**
| Crate | Version | Purpose | Authentication |
|-------|---------|---------|----------------|
| **aws-sdk-kms** | ^1.0 | Official AWS KMS client | IAM roles, STS, credential providers |
| **aws-config** | ^1.0 | AWS SDK configuration | Region, credentials, endpoint configuration |

**Features:**
- Envelope encryption with AWS-managed KEKs
- Multi-region key replication
- CloudHSM integration for FIPS 140-2 Level 3
- Key rotation automation
- CloudTrail audit logging integration

```rust
use aws_sdk_kms::Client;
use aws_config::load_from_env;

// Initialize AWS KMS client
let config = load_from_env().await;
let kms_client = Client::new(&config);

// Encrypt data with envelope encryption
let response = kms_client
    .generate_data_key()
    .key_id("alias/config-manager-key")
    .key_spec(DataKeySpec::Aes256)
    .send()
    .await?;
```

**Azure Key Vault**
| Crate | Version | Purpose | Authentication |
|-------|---------|---------|----------------|
| **azure_security_keyvault_keys** | ^0.20 | Azure Key Vault keys | Managed Identity, Service Principal |
| **azure_security_keyvault_secrets** | ^0.20 | Azure Key Vault secrets | Azure AD authentication |
| **azure_identity** | ^0.20 | Azure authentication | DefaultAzureCredential |

**Features (2025 SDK Updates):**
- Managed Identity support for zero-secret authentication
- Hardware Security Module (HSM) backed keys
- Key versioning and rotation
- Azure Monitor integration for audit logs
- RBAC integration with Azure AD

```rust
use azure_identity::DefaultAzureCredential;
use azure_security_keyvault_secrets::SecretClient;

// Initialize Azure Key Vault client
let credential = DefaultAzureCredential::new();
let client = SecretClient::new(
    "https://myvault.vault.azure.net",
    credential
)?;

// Get secret
let secret = client.get("database-password").await?;
```

**GCP Cloud KMS**
| Crate | Version | Purpose | Authentication |
|-------|---------|---------|----------------|
| **google-cloud-kms** | ^0.7 | GCP KMS client (community) | Workload Identity, Service Account |
| **gcloud-sdk** | ^0.25 | GCP SDK (alternative) | gRPC-based, generated from Google APIs |

**Note:** Google does not provide an official Rust SDK as of 2025, requiring use of community-maintained libraries.

**Features:**
- Cloud HSM integration
- Automatic and manual key rotation
- Cloud Audit Logs integration
- Workload Identity for GKE
- Global key replication

```rust
use google_cloud_kms::client::{Client, ClientConfig};

// Initialize GCP KMS client
let config = ClientConfig::default().with_auth().await?;
let client = Client::new(config).await?;

// Encrypt data
let response = client
    .encrypt("projects/my-project/locations/global/keyRings/my-ring/cryptoKeys/my-key")
    .plaintext(data)
    .send()
    .await?;
```

**Multi-Cloud Abstraction Layer:**
```rust
// Unified KMS interface for multi-cloud support
pub trait KmsProvider: Send + Sync {
    async fn encrypt(&self, key_id: &str, plaintext: &[u8]) -> Result<Vec<u8>>;
    async fn decrypt(&self, key_id: &str, ciphertext: &[u8]) -> Result<Vec<u8>>;
    async fn generate_data_key(&self, key_id: &str) -> Result<(Vec<u8>, Vec<u8>)>;
    async fn rotate_key(&self, key_id: &str) -> Result<String>;
}

// Implementations for AWS, Azure, GCP, Vault
impl KmsProvider for AwsKmsProvider { ... }
impl KmsProvider for AzureKmsProvider { ... }
impl KmsProvider for GcpKmsProvider { ... }
impl KmsProvider for VaultTransitProvider { ... }
```

### 2.3 Serialization and Validation

#### Serialization

| Crate | Version | Purpose | Use Case |
|-------|---------|---------|----------|
| **serde** | ^1.0 | Universal serialization framework | Core serialization trait |
| **serde_json** | ^1.0 | JSON serialization | REST API, audit logs, config storage |
| **toml** | ^0.8 | TOML serialization | Human-friendly configuration files |
| **serde-yaml-ng** | ^0.10 | YAML serialization | Configuration files (maintained fork) |

**Note:** Use `serde-yaml-ng` instead of deprecated `serde_yaml`.

#### Validation

| Crate | Version | Purpose | Rationale |
|-------|---------|---------|-----------|
| **jsonschema** | ^0.18 | JSON Schema validation | High-performance, supports drafts 4/6/7/2019-09/2020-12, custom validators |
| **validator** | ^0.18 | Derive-based validation | Declarative validation rules for structs, email/URL/IP validation |
| **serde_valid** | ^0.22 | Serde-integrated validation | Validation during deserialization |

**JSON Schema Validation Example:**
```rust
use jsonschema::{Draft, JSONSchema};
use serde_json::json;

// Define schema
let schema = json!({
    "type": "object",
    "properties": {
        "api_key": {
            "type": "string",
            "pattern": "^sk-[a-zA-Z0-9]{48}$"
        },
        "max_retries": {
            "type": "integer",
            "minimum": 0,
            "maximum": 10
        }
    },
    "required": ["api_key"]
});

// Compile schema
let compiled = JSONSchema::options()
    .with_draft(Draft::Draft7)
    .compile(&schema)
    .expect("Invalid schema");

// Validate configuration
let config = json!({"api_key": "sk-abc123...", "max_retries": 3});
if let Err(errors) = compiled.validate(&config) {
    for error in errors {
        eprintln!("Validation error: {}", error);
    }
}
```

**Validator Derive Example:**
```rust
use validator::{Validate, ValidationError};

#[derive(Debug, Validate, Deserialize)]
struct DatabaseConfig {
    #[validate(url)]
    host: String,

    #[validate(range(min = 1024, max = 65535))]
    port: u16,

    #[validate(length(min = 1, max = 63))]
    database: String,

    #[validate(custom(function = "validate_password_complexity"))]
    password: String,
}

fn validate_password_complexity(password: &str) -> Result<(), ValidationError> {
    if password.len() < 12 {
        return Err(ValidationError::new("password_too_short"));
    }
    // Additional complexity checks
    Ok(())
}
```

### 2.4 Access Control and RBAC

| Crate | Version | Purpose | Features |
|-------|---------|---------|----------|
| **casbin** | ^2.3 | Authorization library | RBAC, ABAC, ACL, RESTful, domain/tenant support |
| **casbin-rs** | ^2.3 | Rust implementation | Same as casbin, Rust-native |

**Casbin Features:**
- Multiple access control models (ACL, RBAC, ABAC, RESTful)
- Role hierarchy and inheritance
- Domain/tenant-based RBAC
- Resource roles (both users and resources can have roles)
- Hybrid models (RBAC + ABAC)
- Policy persistence (file, database, cloud storage)

**Casbin Model Example (RBAC with Domains):**
```ini
[request_definition]
r = sub, dom, obj, act

[policy_definition]
p = sub, dom, obj, act

[role_definition]
g = _, _, _

[policy_effect]
e = some(where (p.eft == allow))

[matchers]
m = g(r.sub, p.sub, r.dom) && r.dom == p.dom && r.obj == p.obj && r.act == p.act
```

**Policy Definitions:**
```csv
p, admin, tenant1, configs/*, read
p, admin, tenant1, configs/*, write
p, operator, tenant1, configs/prod/*, read
p, operator, tenant1, configs/dev/*, write
g, alice, admin, tenant1
g, bob, operator, tenant1
```

**Integration Example:**
```rust
use casbin::prelude::*;

// Initialize enforcer with model and policy
let mut enforcer = Enforcer::new("model.conf", "policy.csv").await?;

// Check authorization
if enforcer.enforce(("alice", "tenant1", "configs/prod/database", "write"))? {
    // Allow access
} else {
    // Deny access
}

// Add runtime policy
enforcer.add_policy(vec![
    "developer".to_owned(),
    "tenant1".to_owned(),
    "configs/dev/*".to_owned(),
    "read".to_owned(),
]).await?;
```

**Alternative: Custom RBAC Implementation**

For simpler use cases, implement custom RBAC:

```rust
use std::collections::HashMap;

pub struct RbacEngine {
    roles: HashMap<String, Role>,
    user_roles: HashMap<String, Vec<String>>,
    permissions: HashMap<String, Permission>,
}

pub struct Role {
    name: String,
    permissions: Vec<String>,
    inherits_from: Vec<String>,
}

pub struct Permission {
    resource: String,
    actions: Vec<Action>,
    effect: Effect,
}

pub enum Action {
    Read,
    Write,
    Delete,
    Rotate,
    Admin,
}

pub enum Effect {
    Allow,
    Deny,
}

impl RbacEngine {
    pub fn check_permission(
        &self,
        user: &str,
        resource: &str,
        action: Action,
    ) -> Result<bool> {
        // Resolve user roles
        let roles = self.user_roles.get(user).ok_or(Error::UserNotFound)?;

        // Check permissions for each role (including inherited)
        for role_name in roles {
            if let Some(role) = self.roles.get(role_name) {
                if self.role_has_permission(role, resource, &action)? {
                    return Ok(true);
                }
            }
        }

        Ok(false) // Default deny
    }
}
```

### 2.5 Audit Logging and Observability

#### Structured Logging and Tracing

| Crate | Version | Purpose | Rationale |
|-------|---------|---------|-----------|
| **tracing** | ^0.1 | Structured logging and distributed tracing | Modern async-first design, span-based context, industry standard |
| **tracing-subscriber** | ^0.3 | Tracing output and formatting | JSON formatting, filtering, layering |
| **tracing-appender** | ^0.2 | Non-blocking file appender | Background file writing, log rotation |
| **tracing-opentelemetry** | ^0.22 | OpenTelemetry integration | Distributed tracing with Jaeger/Zipkin |

**Why tracing over log:**
- Async-first design (essential for Tokio-based services)
- Structured fields with type safety
- Span-based context propagation
- Superior integration with async runtimes
- Better performance in high-throughput scenarios
- Industry standard for modern Rust services

**Audit Logging Configuration:**
```rust
use tracing::{info, warn, error, instrument};
use tracing_subscriber::{fmt, layer::SubscriberExt, EnvFilter};
use tracing_appender::rolling::{RollingFileAppender, Rotation};

// Configure audit logger with JSON output
let file_appender = RollingFileAppender::new(
    Rotation::DAILY,
    "/var/log/llm-config-manager",
    "audit.log"
);

let subscriber = tracing_subscriber::registry()
    .with(EnvFilter::new("info"))
    .with(
        fmt::layer()
            .json()
            .with_file(true)
            .with_line_number(true)
            .with_thread_ids(true)
            .with_writer(file_appender)
    );

tracing::subscriber::set_global_default(subscriber)?;

// Audit logging with context
#[instrument(
    name = "config_read",
    fields(
        user_id = %user_id,
        tenant_id = %tenant_id,
        namespace = %namespace,
        key = %key,
        result = tracing::field::Empty,
    )
)]
async fn read_config(
    user_id: &str,
    tenant_id: &str,
    namespace: &str,
    key: &str,
) -> Result<ConfigValue> {
    // Audit event automatically logged with span context
    info!("Configuration read requested");

    let value = fetch_config(namespace, key).await?;

    tracing::Span::current().record("result", "success");
    Ok(value)
}
```

**Audit Log Schema:**
```json
{
  "timestamp": "2025-11-21T10:30:45.123Z",
  "level": "INFO",
  "target": "llm_config_manager::config",
  "span": {
    "name": "config_read",
    "user_id": "alice@example.com",
    "tenant_id": "tenant-123",
    "namespace": "production/ml-service",
    "key": "database.credentials",
    "result": "success"
  },
  "fields": {
    "message": "Configuration read requested",
    "request_id": "req-abc-123",
    "source_ip": "10.0.1.42"
  }
}
```

#### Metrics and Monitoring

| Crate | Version | Purpose | Format |
|-------|---------|---------|--------|
| **metrics** | ^0.22 | Application metrics collection | Prometheus-compatible |
| **metrics-exporter-prometheus** | ^0.13 | Prometheus metrics export | HTTP /metrics endpoint |

**Key Metrics:**
```rust
use metrics::{counter, histogram, gauge};

// Security-relevant metrics
counter!("config_access_total", "action" => "read", "result" => "success").increment(1);
counter!("secret_rotation_total", "secret_type" => "api_key", "result" => "success").increment(1);
counter!("auth_attempts_total", "method" => "mtls", "result" => "failure").increment(1);
histogram!("vault_operation_duration_seconds", "operation" => "read").record(duration);
gauge!("active_sessions").set(session_count as f64);
```

### 2.6 Testing and Security Validation

| Crate | Version | Purpose | Use Case |
|-------|---------|---------|----------|
| **mockall** | ^0.12 | Mocking framework | Unit tests for security logic |
| **wiremock** | ^0.6 | HTTP mocking | Integration tests with Vault/KMS |
| **proptest** | ^1.4 | Property-based testing | Crypto operations, fuzzing |
| **cargo-audit** | ^0.20 | Dependency vulnerability scanning | CI/CD security checks |
| **cargo-deny** | ^0.14 | Dependency policy enforcement | License compliance, advisory checking |

---

## 3. Encryption Strategies

### 3.1 At-Rest Encryption

#### Configuration Data Encryption

**Encryption Algorithm:** AES-256-GCM (Galois/Counter Mode)

**Rationale:**
- Authenticated encryption (confidentiality + integrity)
- NIST recommended, FIPS 140-2 approved
- Hardware acceleration (AES-NI) on modern CPUs
- Parallelizable for high performance

**Implementation:**
```rust
use aes_gcm::{
    aead::{Aead, KeyInit, OsRng},
    Aes256Gcm, Nonce,
};
use rand::RngCore;

pub struct ConfigEncryption {
    cipher: Aes256Gcm,
}

impl ConfigEncryption {
    pub fn new(key: &[u8; 32]) -> Self {
        let cipher = Aes256Gcm::new(key.into());
        Self { cipher }
    }

    pub fn encrypt(&self, plaintext: &[u8]) -> Result<EncryptedData> {
        // Generate random nonce (96 bits for GCM)
        let mut nonce_bytes = [0u8; 12];
        OsRng.fill_bytes(&mut nonce_bytes);
        let nonce = Nonce::from_slice(&nonce_bytes);

        // Encrypt with AAD (additional authenticated data)
        let aad = b"config-v1"; // Version and type identifier
        let ciphertext = self.cipher
            .encrypt(nonce, Payload { msg: plaintext, aad })
            .map_err(|_| Error::EncryptionFailed)?;

        Ok(EncryptedData {
            ciphertext,
            nonce: nonce_bytes.to_vec(),
            algorithm: Algorithm::Aes256Gcm,
            key_id: self.key_id.clone(),
        })
    }

    pub fn decrypt(&self, encrypted: &EncryptedData) -> Result<Vec<u8>> {
        let nonce = Nonce::from_slice(&encrypted.nonce);
        let aad = b"config-v1";

        self.cipher
            .decrypt(nonce, Payload { msg: &encrypted.ciphertext, aad })
            .map_err(|_| Error::DecryptionFailed)
    }
}
```

**Alternative for ARM/Embedded:** ChaCha20-Poly1305

For systems without AES-NI hardware acceleration:

```rust
use chacha20poly1305::{
    aead::{Aead, KeyInit, OsRng},
    ChaCha20Poly1305, Nonce,
};

// Similar interface, optimized for software implementation
// Better performance on ARM, embedded, older CPUs
```

#### Envelope Encryption Pattern

**Architecture:**
```
┌─────────────────────────────────────────────────────────┐
│ Configuration Value (Plaintext)                         │
└─────────────────────────────────────────────────────────┘
                           ↓
                  ┌──────────────────┐
                  │ Generate DEK     │
                  │ (Data Encryption │
                  │      Key)        │
                  └──────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ Encrypt config with DEK → Encrypted Config              │
└─────────────────────────────────────────────────────────┘
                           ↓
                  ┌──────────────────┐
                  │ Encrypt DEK with │
                  │  KEK from KMS    │
                  └──────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ Store: {                                                │
│   encrypted_config: <ciphertext>,                       │
│   encrypted_dek: <wrapped_key>,                         │
│   kek_id: "arn:aws:kms:us-east-1:123456789:key/..."    │
│ }                                                       │
└─────────────────────────────────────────────────────────┘
```

**Implementation:**
```rust
use aws_sdk_kms::Client as KmsClient;

pub struct EnvelopeEncryption {
    kms_client: KmsClient,
    kek_id: String,
}

impl EnvelopeEncryption {
    pub async fn encrypt(&self, plaintext: &[u8]) -> Result<EnvelopeEncryptedData> {
        // 1. Generate data encryption key (DEK)
        let dek_response = self.kms_client
            .generate_data_key()
            .key_id(&self.kek_id)
            .key_spec(DataKeySpec::Aes256)
            .send()
            .await?;

        let plaintext_dek = dek_response.plaintext()
            .ok_or(Error::KeyGenerationFailed)?;
        let encrypted_dek = dek_response.ciphertext_blob()
            .ok_or(Error::KeyGenerationFailed)?;

        // 2. Encrypt data with DEK
        let cipher = Aes256Gcm::new(GenericArray::from_slice(plaintext_dek.as_ref()));
        let mut nonce_bytes = [0u8; 12];
        OsRng.fill_bytes(&mut nonce_bytes);
        let nonce = Nonce::from_slice(&nonce_bytes);

        let ciphertext = cipher
            .encrypt(nonce, plaintext)
            .map_err(|_| Error::EncryptionFailed)?;

        // 3. Zeroize DEK from memory
        let mut dek_copy = plaintext_dek.as_ref().to_vec();
        dek_copy.zeroize();

        // 4. Return envelope encrypted data
        Ok(EnvelopeEncryptedData {
            ciphertext,
            nonce: nonce_bytes.to_vec(),
            encrypted_dek: encrypted_dek.as_ref().to_vec(),
            kek_id: self.kek_id.clone(),
            algorithm: Algorithm::Aes256Gcm,
        })
    }

    pub async fn decrypt(&self, data: &EnvelopeEncryptedData) -> Result<Vec<u8>> {
        // 1. Decrypt DEK using KMS
        let dek_response = self.kms_client
            .decrypt()
            .ciphertext_blob(Blob::new(&data.encrypted_dek))
            .key_id(&self.kek_id)
            .send()
            .await?;

        let plaintext_dek = dek_response.plaintext()
            .ok_or(Error::DecryptionFailed)?;

        // 2. Decrypt data with DEK
        let cipher = Aes256Gcm::new(GenericArray::from_slice(plaintext_dek.as_ref()));
        let nonce = Nonce::from_slice(&data.nonce);

        let plaintext = cipher
            .decrypt(nonce, data.ciphertext.as_ref())
            .map_err(|_| Error::DecryptionFailed)?;

        // 3. Zeroize DEK from memory
        let mut dek_copy = plaintext_dek.as_ref().to_vec();
        dek_copy.zeroize();

        Ok(plaintext)
    }
}
```

**Benefits:**
- KEK never leaves KMS (highest security)
- DEK rotation without re-encrypting all data
- Unlimited data size (not limited by KMS)
- Multi-cloud portability
- Per-tenant isolation with separate KEKs

#### Database Encryption

**PostgreSQL (Metadata and Audit Logs):**
- Enable PostgreSQL Transparent Data Encryption (TDE) or disk encryption
- Use `pgcrypto` extension for column-level encryption if needed
- Connection encryption via TLS

```sql
-- Enable pgcrypto for field-level encryption
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Encrypt sensitive columns
CREATE TABLE secrets (
    id UUID PRIMARY KEY,
    namespace TEXT NOT NULL,
    key TEXT NOT NULL,
    encrypted_value BYTEA NOT NULL,  -- Pre-encrypted by application
    encryption_metadata JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Redis (Distributed Cache):**
- Enable TLS encryption for connections
- Use Redis 6+ with ACL for access control
- Consider encrypted persistence (RDB/AOF with disk encryption)

```rust
// Redis with TLS
use redis::AsyncCommands;

let client = redis::Client::open("rediss://cache.example.com:6380")?
    .set_tls_params(
        TlsConnParams::builder()
            .ca_certs("/path/to/ca.crt")
            .build()
    )?;
```

### 3.2 In-Transit Encryption

#### TLS 1.3 Configuration

**Cipher Suites (Ordered by Preference):**
1. `TLS_AES_256_GCM_SHA384` - Highest security, AEAD, hardware accelerated
2. `TLS_CHACHA20_POLY1305_SHA256` - Software-optimized, mobile-friendly
3. `TLS_AES_128_GCM_SHA256` - Performance-optimized, still secure

**Rustls Configuration:**
```rust
use rustls::{ServerConfig, ClientConfig};
use rustls::version::TLS13;
use rustls_pemfile::{certs, rsa_private_keys};

// Server configuration
pub fn build_tls_server_config(
    cert_path: &str,
    key_path: &str,
) -> Result<Arc<ServerConfig>> {
    let cert_file = File::open(cert_path)?;
    let key_file = File::open(key_path)?;

    let cert_chain = certs(&mut BufReader::new(cert_file))
        .collect::<Result<Vec<_>, _>>()?;
    let key = rsa_private_keys(&mut BufReader::new(key_file))
        .next()
        .ok_or(Error::NoPrivateKey)??;

    let config = ServerConfig::builder()
        .with_safe_default_cipher_suites()
        .with_safe_default_kx_groups()
        .with_protocol_versions(&[&TLS13])? // TLS 1.3 only
        .with_no_client_auth()
        .with_single_cert(cert_chain, key)?;

    Ok(Arc::new(config))
}
```

#### Mutual TLS (mTLS) for Service-to-Service

**Architecture:**
```
┌──────────────────┐                    ┌──────────────────┐
│  Service A       │                    │  Service B       │
│  - Client Cert   │──── TLS 1.3 ───────│  - Server Cert   │
│  - Verify Server │    (mutual auth)   │  - Verify Client │
└──────────────────┘                    └──────────────────┘
         ↓                                        ↓
    Certificate                              Certificate
    Validation                               Validation
         ↓                                        ↓
    ┌─────────────────────────────────────────────────┐
    │            Certificate Authority (CA)           │
    │  - Issues short-lived certificates              │
    │  - OCSP for revocation checking                 │
    └─────────────────────────────────────────────────┘
```

**mTLS Configuration:**
```rust
use rustls::{ServerConfig, ClientConfig, RootCertStore};
use rustls::server::AllowAnyAuthenticatedClient;

// Server with client certificate validation
pub fn build_mtls_server_config(
    cert_path: &str,
    key_path: &str,
    ca_cert_path: &str,
) -> Result<Arc<ServerConfig>> {
    let cert_file = File::open(cert_path)?;
    let key_file = File::open(key_path)?;
    let ca_file = File::open(ca_cert_path)?;

    let cert_chain = certs(&mut BufReader::new(cert_file))
        .collect::<Result<Vec<_>, _>>()?;
    let key = rsa_private_keys(&mut BufReader::new(key_file))
        .next()
        .ok_or(Error::NoPrivateKey)??;

    // Load CA certificates for client validation
    let mut root_store = RootCertStore::empty();
    let ca_certs = certs(&mut BufReader::new(ca_file))
        .collect::<Result<Vec<_>, _>>()?;
    for cert in ca_certs {
        root_store.add(cert)?;
    }

    let client_auth = AllowAnyAuthenticatedClient::new(root_store);

    let config = ServerConfig::builder()
        .with_safe_default_cipher_suites()
        .with_safe_default_kx_groups()
        .with_protocol_versions(&[&TLS13])?
        .with_client_cert_verifier(Arc::new(client_auth))
        .with_single_cert(cert_chain, key)?;

    Ok(Arc::new(config))
}

// Client configuration with client certificate
pub fn build_mtls_client_config(
    cert_path: &str,
    key_path: &str,
    ca_cert_path: &str,
) -> Result<Arc<ClientConfig>> {
    let cert_file = File::open(cert_path)?;
    let key_file = File::open(key_path)?;
    let ca_file = File::open(ca_cert_path)?;

    let cert_chain = certs(&mut BufReader::new(cert_file))
        .collect::<Result<Vec<_>, _>>()?;
    let key = rsa_private_keys(&mut BufReader::new(key_file))
        .next()
        .ok_or(Error::NoPrivateKey)??;

    let mut root_store = RootCertStore::empty();
    let ca_certs = certs(&mut BufReader::new(ca_file))
        .collect::<Result<Vec<_>, _>>()?;
    for cert in ca_certs {
        root_store.add(cert)?;
    }

    let config = ClientConfig::builder()
        .with_safe_default_cipher_suites()
        .with_safe_default_kx_groups()
        .with_protocol_versions(&[&TLS13])?
        .with_root_certificates(root_store)
        .with_client_auth_cert(cert_chain, key)?;

    Ok(Arc::new(config))
}
```

**Certificate Management:**
- **Issuance**: cert-manager (Kubernetes), ACME protocol, internal CA
- **Rotation**: 24-hour certificate lifetime (short-lived certs)
- **Revocation**: OCSP stapling for online revocation checking
- **Storage**: Kubernetes Secrets, Vault PKI engine, AWS ACM

### 3.3 Key Management and Rotation

#### Key Hierarchy

```
┌─────────────────────────────────────────────────────────┐
│ Root Key (Hardware Security Module)                     │
│ - Never exported                                        │
│ - Rotated annually                                      │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ Master Key Encryption Key (KEK)                         │
│ - Managed by KMS (AWS/GCP/Azure/Vault)                 │
│ - Rotated every 90 days                                 │
│ - One per tenant for isolation                          │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ Data Encryption Keys (DEK)                              │
│ - Generated per-configuration or per-secret             │
│ - Encrypted with KEK (envelope encryption)              │
│ - Rotated on KEK rotation (lazy re-encryption)          │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ Encrypted Configuration Data                            │
│ - Encrypted with DEK                                    │
│ - Re-encrypted on DEK rotation                          │
└─────────────────────────────────────────────────────────┘
```

#### Key Rotation Strategy

**Automatic Rotation Schedule:**
- **Root Keys (HSM)**: Annually (manual, high ceremony)
- **KEKs (KMS)**: Every 90 days (automated)
- **DEKs**: On KEK rotation (lazy re-encryption)
- **TLS Certificates**: Every 24 hours (short-lived, automated)
- **API Keys**: Every 90 days with 7-day grace period
- **Database Credentials**: Every 30 days with 24-hour grace period

**KEK Rotation Implementation:**
```rust
pub struct KeyRotationManager {
    kms_client: Box<dyn KmsProvider>,
    metadata_store: Arc<MetadataStore>,
}

impl KeyRotationManager {
    pub async fn rotate_kek(&self, tenant_id: &str) -> Result<RotationResult> {
        // 1. Create new KEK version in KMS
        let new_kek_id = self.kms_client
            .create_key_version(&format!("tenant-{}-kek", tenant_id))
            .await?;

        info!(
            tenant_id = %tenant_id,
            new_kek_id = %new_kek_id,
            "KEK rotation initiated"
        );

        // 2. Update tenant metadata with new KEK
        self.metadata_store
            .set_active_kek(tenant_id, &new_kek_id)
            .await?;

        // 3. Schedule lazy re-encryption of DEKs
        let configs_to_reencrypt = self.metadata_store
            .list_configs_with_old_kek(tenant_id)
            .await?;

        for config in configs_to_reencrypt {
            self.schedule_dek_reencryption(&config).await?;
        }

        // 4. Set old KEK for deprecation (but don't delete yet)
        let grace_period = Duration::from_days(7);
        self.metadata_store
            .schedule_kek_deletion(tenant_id, &old_kek_id, grace_period)
            .await?;

        Ok(RotationResult {
            new_kek_id,
            configs_scheduled: configs_to_reencrypt.len(),
            grace_period_end: Utc::now() + grace_period,
        })
    }

    /// Re-encrypt DEK with new KEK (lazy background process)
    async fn reencrypt_dek(&self, config_id: &str) -> Result<()> {
        // 1. Decrypt DEK with old KEK
        let encrypted_dek = self.metadata_store
            .get_encrypted_dek(config_id)
            .await?;

        let plaintext_dek = self.kms_client
            .decrypt(&encrypted_dek.old_kek_id, &encrypted_dek.ciphertext)
            .await?;

        // 2. Encrypt DEK with new KEK
        let new_kek_id = self.metadata_store
            .get_active_kek_for_config(config_id)
            .await?;

        let new_encrypted_dek = self.kms_client
            .encrypt(&new_kek_id, &plaintext_dek)
            .await?;

        // 3. Update metadata (atomic operation)
        self.metadata_store
            .update_encrypted_dek(config_id, &new_encrypted_dek, &new_kek_id)
            .await?;

        // 4. Zeroize plaintext DEK
        let mut dek_copy = plaintext_dek;
        dek_copy.zeroize();

        Ok(())
    }
}
```

**Key Versioning:**
```rust
pub struct KeyVersion {
    key_id: String,
    version: u32,
    created_at: DateTime<Utc>,
    expires_at: Option<DateTime<Utc>>,
    status: KeyStatus,
}

pub enum KeyStatus {
    Active,        // Currently in use for new encryptions
    Deprecated,    // Still valid for decryption, not for encryption
    Scheduled,     // Scheduled for deletion
    Deleted,       // Permanently deleted
}
```

---

## 4. Access Control and RBAC

### 4.1 RBAC Model

#### Role Hierarchy

```
┌─────────────────────────────────────────────────────────┐
│                     global-admin                         │
│  Permissions: *:*:*                                     │
│  Scope: All tenants, all namespaces                     │
└─────────────────────────────────────────────────────────┘
                           ↓
        ┌──────────────────┴──────────────────┐
        ↓                                     ↓
┌──────────────────┐              ┌──────────────────────┐
│  tenant-admin    │              │  security-auditor    │
│  Permissions:    │              │  Permissions:        │
│  - tenant:*:*    │              │  - audit:*:read      │
│  Scope: tenant   │              │  - config:*:read     │
└──────────────────┘              └──────────────────────┘
        ↓
        ├─────────────────┬──────────────────┐
        ↓                 ↓                  ↓
┌──────────────┐  ┌──────────────┐  ┌─────────────────┐
│  operator    │  │  developer   │  │  viewer         │
│  Permissions:│  │  Permissions:│  │  Permissions:   │
│  - config:*: │  │  - config:   │  │  - config:*:    │
│    read      │  │    dev:write │  │    read         │
│  - config:*: │  │  - config:   │  │  Scope: Limited │
│    write     │  │    staging:  │  └─────────────────┘
│  - secret:*: │  │    read      │
│    rotate    │  │  Scope: Non- │
│  Scope: All  │  │  production  │
│  envs        │  └──────────────┘
└──────────────┘
```

#### Permission Model

**Permission Structure:**
```
<resource>:<namespace_pattern>:<action>

Examples:
- config:production/*:read
- secret:*/database/*:rotate
- tenant:tenant-123:admin
- audit:*:read
```

**Resource Types:**
- `config` - Configuration values
- `secret` - Sensitive credentials
- `namespace` - Namespace management
- `tenant` - Tenant administration
- `audit` - Audit log access
- `policy` - Policy management

**Actions:**
- `read` - Read access
- `write` - Create/update access
- `delete` - Delete access
- `list` - List resources
- `rotate` - Rotate secrets
- `approve` - Approve changes
- `admin` - Administrative access

#### Role Definitions

```rust
pub struct Role {
    pub id: Uuid,
    pub name: String,
    pub description: String,
    pub permissions: Vec<Permission>,
    pub inherits_from: Vec<Uuid>,
    pub scope: RoleScope,
    pub created_at: DateTime<Utc>,
}

pub struct Permission {
    pub resource: ResourcePattern,
    pub actions: Vec<Action>,
    pub effect: Effect,
    pub conditions: Option<Vec<Condition>>,
}

pub struct ResourcePattern {
    pub resource_type: String,  // config, secret, namespace
    pub pattern: String,          // production/*, */database/*
}

pub enum Action {
    Read,
    Write,
    Delete,
    List,
    Rotate,
    Approve,
    Admin,
}

pub enum Effect {
    Allow,
    Deny,
}

pub enum RoleScope {
    Global,
    Tenant(String),
    Namespace(String),
}
```

**Predefined Roles:**

```rust
// Global Administrator
Role {
    name: "global-admin",
    permissions: vec![
        Permission {
            resource: ResourcePattern::parse("*:*")?,
            actions: vec![Action::Admin],
            effect: Effect::Allow,
            conditions: None,
        }
    ],
    scope: RoleScope::Global,
}

// Tenant Administrator
Role {
    name: "tenant-admin",
    permissions: vec![
        Permission {
            resource: ResourcePattern::parse("config:*")?,
            actions: vec![Action::Read, Action::Write, Action::Delete, Action::List],
            effect: Effect::Allow,
            conditions: None,
        },
        Permission {
            resource: ResourcePattern::parse("secret:*")?,
            actions: vec![Action::Read, Action::Rotate],
            effect: Effect::Allow,
            conditions: None,
        },
    ],
    scope: RoleScope::Tenant("<tenant-id>"),
}

// Operator
Role {
    name: "operator",
    permissions: vec![
        Permission {
            resource: ResourcePattern::parse("config:production/*")?,
            actions: vec![Action::Read, Action::Write],
            effect: Effect::Allow,
            conditions: None,
        },
        Permission {
            resource: ResourcePattern::parse("secret:*")?,
            actions: vec![Action::Rotate],
            effect: Effect::Allow,
            conditions: Some(vec![
                Condition::TimeWindow {
                    start: "09:00",
                    end: "17:00",
                    timezone: "UTC",
                }
            ]),
        },
    ],
    scope: RoleScope::Namespace("production"),
}

// Developer
Role {
    name: "developer",
    permissions: vec![
        Permission {
            resource: ResourcePattern::parse("config:development/*")?,
            actions: vec![Action::Read, Action::Write, Action::Delete],
            effect: Effect::Allow,
            conditions: None,
        },
        Permission {
            resource: ResourcePattern::parse("config:staging/*")?,
            actions: vec![Action::Read],
            effect: Effect::Allow,
            conditions: None,
        },
        Permission {
            resource: ResourcePattern::parse("config:production/*")?,
            actions: vec![Action::Read, Action::Write],
            effect: Effect::Deny, // Explicit deny
            conditions: None,
        },
    ],
    scope: RoleScope::Namespace("development"),
}

// Viewer (Read-only)
Role {
    name: "viewer",
    permissions: vec![
        Permission {
            resource: ResourcePattern::parse("config:*")?,
            actions: vec![Action::Read, Action::List],
            effect: Effect::Allow,
            conditions: None,
        },
        Permission {
            resource: ResourcePattern::parse("secret:*")?,
            actions: vec![Action::Read],
            effect: Effect::Deny, // Cannot read secrets
            conditions: None,
        },
    ],
    scope: RoleScope::Global,
}
```

### 4.2 Attribute-Based Access Control (ABAC)

**Conditional Permissions:**

```rust
pub enum Condition {
    TimeWindow {
        start: String,
        end: String,
        timezone: String,
    },
    IpRange {
        cidrs: Vec<String>,
    },
    Environment {
        allowed: Vec<String>,
    },
    MfaRequired,
    RequestOrigin {
        allowed_sources: Vec<Source>,
    },
}

pub enum Source {
    Internal,
    VPN,
    Public,
}
```

**ABAC Policy Example:**
```rust
Permission {
    resource: ResourcePattern::parse("secret:production/*")?,
    actions: vec![Action::Rotate],
    effect: Effect::Allow,
    conditions: Some(vec![
        // Only during business hours
        Condition::TimeWindow {
            start: "09:00",
            end: "17:00",
            timezone: "America/New_York",
        },
        // Only from internal network
        Condition::IpRange {
            cidrs: vec!["10.0.0.0/8".to_string(), "172.16.0.0/12".to_string()],
        },
        // Requires MFA
        Condition::MfaRequired,
    ]),
}
```

### 4.3 Authorization Enforcement

**Authorization Flow:**
```
┌──────────────────┐
│ Incoming Request │
└──────────────────┘
        ↓
┌──────────────────────────────────┐
│ 1. Authenticate                  │
│    - Extract identity from token │
│    - Validate JWT signature      │
│    - Verify mTLS certificate     │
└──────────────────────────────────┘
        ↓
┌──────────────────────────────────┐
│ 2. Extract Request Context       │
│    - User/Service ID             │
│    - Tenant ID                   │
│    - Resource                    │
│    - Action                      │
│    - Request metadata (IP, time) │
└──────────────────────────────────┘
        ↓
┌──────────────────────────────────┐
│ 3. Evaluate Authorization        │
│    - Query user roles            │
│    - Resolve permissions         │
│    - Check conditions (ABAC)     │
│    - Policy Engine (OPA/Casbin) │
└──────────────────────────────────┘
        ↓
    ┌───────┐
    │ Allow?│
    └───┬───┘
        ├─── Yes ──→ Proceed with request
        └─── No ───→ 403 Forbidden + Audit log
```

**Implementation:**
```rust
use casbin::prelude::*;

pub struct AuthorizationService {
    enforcer: Arc<Mutex<Enforcer>>,
    audit_logger: Arc<AuditLogger>,
}

impl AuthorizationService {
    pub async fn check_permission(
        &self,
        ctx: &RequestContext,
        resource: &str,
        action: Action,
    ) -> Result<bool> {
        let user_id = &ctx.user_id;
        let tenant_id = &ctx.tenant_id;

        // Construct authorization request
        let request = (
            user_id.as_str(),
            tenant_id.as_str(),
            resource,
            action.as_str(),
        );

        // Evaluate with Casbin
        let mut enforcer = self.enforcer.lock().await;
        let allowed = enforcer.enforce(request)
            .map_err(|e| Error::AuthorizationFailed(e.to_string()))?;

        // Additional ABAC conditions
        if allowed {
            let conditions_met = self.check_conditions(ctx, resource, action).await?;
            if !conditions_met {
                allowed = false;
            }
        }

        // Audit log authorization decision
        self.audit_logger.log(AuditEvent {
            event_type: AuditEventType::Authorization,
            timestamp: Utc::now(),
            user_id: ctx.user_id.clone(),
            tenant_id: ctx.tenant_id.clone(),
            resource: resource.to_string(),
            action: action.to_string(),
            result: if allowed { "allow" } else { "deny" },
            ip_address: ctx.source_ip.clone(),
            request_id: ctx.request_id.clone(),
        }).await?;

        Ok(allowed)
    }

    async fn check_conditions(
        &self,
        ctx: &RequestContext,
        resource: &str,
        action: Action,
    ) -> Result<bool> {
        // Fetch permission conditions
        let conditions = self.get_conditions(resource, action).await?;

        for condition in conditions {
            match condition {
                Condition::TimeWindow { start, end, timezone } => {
                    if !self.is_within_time_window(ctx, start, end, timezone)? {
                        return Ok(false);
                    }
                }
                Condition::IpRange { cidrs } => {
                    if !self.is_ip_in_range(&ctx.source_ip, &cidrs)? {
                        return Ok(false);
                    }
                }
                Condition::MfaRequired => {
                    if !ctx.mfa_verified {
                        return Ok(false);
                    }
                }
                // ... other conditions
            }
        }

        Ok(true)
    }
}
```

### 4.4 Service Account Authentication

**Service Account Token (JWT):**
```rust
use jsonwebtoken::{encode, decode, Header, Algorithm, Validation, EncodingKey, DecodingKey};
use serde::{Serialize, Deserialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct ServiceAccountClaims {
    pub sub: String,          // Service account ID
    pub tenant_id: String,
    pub scopes: Vec<String>,  // Granted permissions
    pub iat: i64,             // Issued at
    pub exp: i64,             // Expiration
    pub aud: String,          // Audience
    pub iss: String,          // Issuer
}

pub struct ServiceAccountManager {
    signing_key: EncodingKey,
    validation_key: DecodingKey,
}

impl ServiceAccountManager {
    pub fn create_token(
        &self,
        service_account_id: &str,
        tenant_id: &str,
        scopes: Vec<String>,
        ttl: Duration,
    ) -> Result<String> {
        let now = Utc::now().timestamp();
        let exp = now + ttl.num_seconds();

        let claims = ServiceAccountClaims {
            sub: service_account_id.to_string(),
            tenant_id: tenant_id.to_string(),
            scopes,
            iat: now,
            exp,
            aud: "llm-config-manager".to_string(),
            iss: "llm-config-manager-auth".to_string(),
        };

        let header = Header::new(Algorithm::ES256); // ECDSA with SHA-256
        let token = encode(&header, &claims, &self.signing_key)
            .map_err(|e| Error::TokenCreationFailed(e.to_string()))?;

        Ok(token)
    }

    pub fn validate_token(&self, token: &str) -> Result<ServiceAccountClaims> {
        let mut validation = Validation::new(Algorithm::ES256);
        validation.set_audience(&["llm-config-manager"]);
        validation.set_issuer(&["llm-config-manager-auth"]);

        let token_data = decode::<ServiceAccountClaims>(
            token,
            &self.validation_key,
            &validation,
        ).map_err(|e| Error::TokenValidationFailed(e.to_string()))?;

        Ok(token_data.claims)
    }
}
```

---

## 5. Secret Rotation Mechanisms

### 5.1 Rotation Policies

**Rotation Schedule by Secret Type:**

| Secret Type | Rotation Frequency | Grace Period | Automation | Rationale |
|-------------|-------------------|--------------|------------|-----------|
| **API Keys** | 90 days | 7 days | Fully automated | Balance security and operational burden |
| **Database Credentials** | 30 days | 24 hours | Automated with health checks | High-value target, frequent rotation |
| **TLS Certificates** | 24 hours | 2 hours | Fully automated (cert-manager) | Short-lived certs, automated renewal |
| **Encryption Keys (KEK)** | 90 days | N/A (versioned) | Automated background re-encryption | Key versioning, no grace period needed |
| **Service Account Tokens** | 1 hour (short) or 30 days (long) | 5 min (short), 7 days (long) | Automatic refresh | Context-dependent lifetime |
| **OAuth Refresh Tokens** | 7 days | 1 day | Automatic renewal | Standard OAuth practice |

### 5.2 Rotation Workflow

**Automated Rotation Process:**

```
┌──────────────────────────────────────────────────────────┐
│ Phase 1: Pre-Rotation                                    │
│ - Check rotation eligibility                             │
│ - Identify dependent services                            │
│ - Send pre-rotation notifications (15 min before)        │
└──────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────┐
│ Phase 2: Generate New Secret                             │
│ - Generate cryptographically secure new value            │
│ - Validate new secret (test connectivity, permissions)   │
│ - Store new version alongside old (both valid)           │
└──────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────┐
│ Phase 3: Grace Period (Dual-Secret Mode)                │
│ - Both old and new secrets valid                         │
│ - Services gradually migrate to new secret               │
│ - Monitor for errors or failed authentications           │
└──────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────┐
│ Phase 4: Verification                                    │
│ - Health check all dependent services                    │
│ - Verify no services using old secret                    │
│ - Check error rates and authentication failures          │
└──────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────┐
│ Phase 5: Revoke Old Secret                               │
│ - Mark old secret as revoked                             │
│ - Remove from active credential stores                   │
│ - Archive old secret (encrypted audit trail)             │
└──────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────┐
│ Phase 6: Post-Rotation                                   │
│ - Send completion notifications                          │
│ - Update audit logs                                      │
│ - Schedule next rotation                                 │
│ - Verify rotation success metrics                        │
└──────────────────────────────────────────────────────────┘
```

### 5.3 Implementation

**Secret Rotation Manager:**
```rust
pub struct SecretRotationManager {
    vault_client: Arc<dyn SecretsBackend>,
    notification_service: Arc<NotificationService>,
    health_checker: Arc<HealthChecker>,
    audit_logger: Arc<AuditLogger>,
}

impl SecretRotationManager {
    pub async fn rotate_secret(
        &self,
        secret_id: &str,
        secret_type: SecretType,
    ) -> Result<RotationResult> {
        info!(secret_id = %secret_id, secret_type = ?secret_type, "Starting secret rotation");

        // Phase 1: Pre-rotation
        self.pre_rotation_checks(secret_id).await?;
        self.notify_rotation_start(secret_id, Duration::from_secs(15 * 60)).await?;
        tokio::time::sleep(Duration::from_secs(15 * 60)).await; // Wait before rotation

        // Phase 2: Generate new secret
        let new_secret = self.generate_new_secret(secret_id, secret_type).await?;
        self.validate_new_secret(secret_id, &new_secret).await?;

        // Store new version (both old and new valid)
        self.vault_client
            .create_secret_version(secret_id, &new_secret)
            .await?;

        // Phase 3: Grace period
        let grace_period = self.get_grace_period(secret_type);
        info!(secret_id = %secret_id, grace_period_sec = grace_period.as_secs(),
              "Entering grace period - both secrets valid");

        tokio::time::sleep(grace_period).await;

        // Phase 4: Verification
        let health_status = self.health_checker
            .check_services_using_secret(secret_id)
            .await?;

        if !health_status.all_healthy() {
            warn!(secret_id = %secret_id, "Health check failed, initiating rollback");
            return self.rollback_rotation(secret_id).await;
        }

        // Phase 5: Revoke old secret
        self.vault_client
            .revoke_old_secret_version(secret_id)
            .await?;

        // Phase 6: Post-rotation
        self.notify_rotation_complete(secret_id).await?;
        self.schedule_next_rotation(secret_id, secret_type).await?;

        // Audit log
        self.audit_logger.log(AuditEvent {
            event_type: AuditEventType::SecretRotation,
            timestamp: Utc::now(),
            secret_id: secret_id.to_string(),
            secret_type: secret_type.to_string(),
            result: "success",
            metadata: HashMap::from([
                ("grace_period_sec", grace_period.as_secs().to_string()),
            ]),
        }).await?;

        Ok(RotationResult::Success)
    }

    async fn generate_new_secret(
        &self,
        secret_id: &str,
        secret_type: SecretType,
    ) -> Result<SecretValue> {
        match secret_type {
            SecretType::ApiKey => {
                // Generate cryptographically secure random API key
                let mut bytes = [0u8; 32];
                ring::rand::SystemRandom::new()
                    .fill(&mut bytes)
                    .map_err(|_| Error::RandomGenerationFailed)?;

                let api_key = format!("sk-{}", base64::encode(&bytes));
                Ok(SecretValue::ApiKey(api_key))
            }
            SecretType::DatabaseCredentials { host, port, database, username } => {
                // Generate strong random password
                let password = self.generate_secure_password(32)?;

                Ok(SecretValue::DatabaseCredentials {
                    host,
                    port,
                    database,
                    username,
                    password,
                })
            }
            SecretType::TlsCertificate => {
                // Request new certificate from CA
                let cert_request = self.create_cert_request(secret_id)?;
                let cert = self.issue_certificate(cert_request).await?;

                Ok(SecretValue::TlsCertificate {
                    cert_pem: cert.cert_pem,
                    private_key_pem: cert.private_key_pem,
                    ca_chain: cert.ca_chain,
                })
            }
            // ... other secret types
        }
    }

    async fn validate_new_secret(
        &self,
        secret_id: &str,
        new_secret: &SecretValue,
    ) -> Result<()> {
        match new_secret {
            SecretValue::DatabaseCredentials { host, port, database, username, password } => {
                // Test database connection with new credentials
                let conn_string = format!(
                    "postgresql://{}:{}@{}:{}/{}",
                    username, password, host, port, database
                );

                let pool = sqlx::PgPool::connect(&conn_string).await
                    .map_err(|e| Error::SecretValidationFailed(e.to_string()))?;

                // Execute test query
                sqlx::query("SELECT 1")
                    .execute(&pool)
                    .await
                    .map_err(|e| Error::SecretValidationFailed(e.to_string()))?;

                pool.close().await;
                Ok(())
            }
            SecretValue::ApiKey(key) => {
                // Test API key with provider
                // Implementation depends on provider
                Ok(())
            }
            // ... other validations
        }
    }

    fn get_grace_period(&self, secret_type: SecretType) -> Duration {
        match secret_type {
            SecretType::ApiKey => Duration::from_secs(7 * 24 * 60 * 60), // 7 days
            SecretType::DatabaseCredentials => Duration::from_secs(24 * 60 * 60), // 24 hours
            SecretType::TlsCertificate => Duration::from_secs(2 * 60 * 60), // 2 hours
            SecretType::ServiceAccountToken { long_lived: true } => Duration::from_secs(7 * 24 * 60 * 60),
            SecretType::ServiceAccountToken { long_lived: false } => Duration::from_secs(5 * 60), // 5 minutes
        }
    }

    async fn rollback_rotation(&self, secret_id: &str) -> Result<RotationResult> {
        warn!(secret_id = %secret_id, "Rolling back secret rotation");

        // Mark new secret version as invalid
        self.vault_client
            .invalidate_secret_version(secret_id, VersionSelector::Latest)
            .await?;

        // Keep old secret active
        self.vault_client
            .reactivate_secret_version(secret_id, VersionSelector::Previous)
            .await?;

        // Notify administrators
        self.notification_service
            .send_alert(Alert {
                severity: Severity::High,
                title: format!("Secret rotation rollback: {}", secret_id),
                message: "Automatic rollback due to health check failure".to_string(),
            })
            .await?;

        // Audit log
        self.audit_logger.log(AuditEvent {
            event_type: AuditEventType::SecretRotation,
            timestamp: Utc::now(),
            secret_id: secret_id.to_string(),
            result: "rollback",
            metadata: HashMap::from([
                ("reason", "health_check_failed"),
            ]),
        }).await?;

        Ok(RotationResult::Rollback)
    }
}
```

### 5.4 Notification Mechanisms

**Pre-rotation Notification (15 minutes before):**
```rust
pub struct NotificationService {
    email_client: Arc<EmailClient>,
    webhook_client: Arc<WebhookClient>,
}

impl NotificationService {
    pub async fn notify_rotation_start(
        &self,
        secret_id: &str,
        time_until_rotation: Duration,
    ) -> Result<()> {
        let notification = RotationNotification {
            event: "secret.rotation.starting",
            secret_id: secret_id.to_string(),
            time_until_rotation_sec: time_until_rotation.as_secs(),
            timestamp: Utc::now(),
            action_required: "Ensure services can handle secret rotation gracefully",
        };

        // Email notification
        self.email_client
            .send_to_subscribers(&notification)
            .await?;

        // Webhook notification
        self.webhook_client
            .post_event(&notification)
            .await?;

        Ok(())
    }

    pub async fn notify_rotation_complete(
        &self,
        secret_id: &str,
    ) -> Result<()> {
        let notification = RotationNotification {
            event: "secret.rotation.completed",
            secret_id: secret_id.to_string(),
            timestamp: Utc::now(),
            next_rotation: self.get_next_rotation_time(secret_id).await?,
        };

        self.email_client.send_to_subscribers(&notification).await?;
        self.webhook_client.post_event(&notification).await?;

        Ok(())
    }
}
```

---

## 6. Audit Logging and Compliance

### 6.1 Audit Event Types

**Events to Log:**

```rust
pub enum AuditEventType {
    // Configuration access
    ConfigRead,
    ConfigWrite,
    ConfigDelete,
    ConfigListNamespace,

    // Secret operations
    SecretRead,
    SecretWrite,
    SecretRotation,
    SecretExpired,
    SecretDeleted,

    // Authentication
    AuthenticationSuccess,
    AuthenticationFailure,
    SessionCreated,
    SessionExpired,
    TokenIssued,
    TokenRevoked,

    // Authorization
    AuthorizationAllow,
    AuthorizationDeny,
    PermissionChanged,
    RoleAssigned,
    RoleRevoked,

    // Policy enforcement
    PolicyViolation,
    PolicyValidationFailed,
    PolicyUpdated,

    // Tenant management
    TenantCreated,
    TenantDeleted,
    TenantSuspended,
    NamespaceCreated,
    NamespaceDeleted,

    // System events
    KeyRotation,
    BackupCreated,
    BackupRestored,
    HealthDegraded,
    EmergencyAccess,
}
```

### 6.2 Audit Log Schema

**Structured Audit Event:**
```rust
use serde::{Serialize, Deserialize};
use chrono::{DateTime, Utc};

#[derive(Debug, Serialize, Deserialize)]
pub struct AuditEvent {
    /// Unique event ID
    pub id: Uuid,

    /// Event timestamp (ISO 8601)
    pub timestamp: DateTime<Utc>,

    /// Event type
    pub event_type: AuditEventType,

    /// Actor (user or service) performing action
    pub actor: Actor,

    /// Resource being accessed
    pub resource: Resource,

    /// Action performed
    pub action: String,

    /// Result of action
    pub result: AuditResult,

    /// Request context
    pub request_context: RequestContext,

    /// Event-specific metadata
    pub metadata: HashMap<String, String>,

    /// Cryptographic signature for tamper-evidence
    pub signature: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Actor {
    pub id: String,
    pub actor_type: ActorType,
    pub name: Option<String>,
    pub email: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub enum ActorType {
    HumanUser,
    ServiceAccount,
    System,
    Anonymous,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Resource {
    pub resource_type: String, // config, secret, namespace, tenant
    pub resource_id: String,
    pub namespace: Option<String>,
    pub tenant_id: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub enum AuditResult {
    Success,
    Failure { reason: String },
    Denied { reason: String },
}

#[derive(Debug, Serialize, Deserialize)]
pub struct RequestContext {
    pub request_id: String,
    pub source_ip: String,
    pub user_agent: Option<String>,
    pub session_id: Option<String>,
    pub correlation_id: Option<String>,
}
```

**JSON Audit Log Example:**
```json
{
  "id": "evt_7f3a9b2c-4d5e-6789-abcd-ef0123456789",
  "timestamp": "2025-11-21T14:35:22.123Z",
  "event_type": "ConfigRead",
  "actor": {
    "id": "user_alice@example.com",
    "actor_type": "HumanUser",
    "name": "Alice Smith",
    "email": "alice@example.com"
  },
  "resource": {
    "resource_type": "config",
    "resource_id": "database.credentials",
    "namespace": "production/ml-service",
    "tenant_id": "tenant-123"
  },
  "action": "read",
  "result": {
    "Success": null
  },
  "request_context": {
    "request_id": "req-abc-123-def-456",
    "source_ip": "10.0.1.42",
    "user_agent": "curl/7.68.0",
    "session_id": "sess-xyz-789",
    "correlation_id": "trace-001-002-003"
  },
  "metadata": {
    "cache_hit": "false",
    "vault_latency_ms": "45",
    "config_version": "42"
  },
  "signature": "MEUCIQDl3h5+..."
}
```

### 6.3 Immutable Audit Trail

**Cryptographic Log Integrity (Merkle Tree):**

```rust
use sha2::{Sha256, Digest};
use ed25519_dalek::{SigningKey, Signature, Signer};

pub struct AuditLogger {
    storage: Arc<dyn AuditStorage>,
    signing_key: SigningKey,
    merkle_tree: Arc<Mutex<MerkleTree>>,
}

impl AuditLogger {
    pub async fn log(&self, event: AuditEvent) -> Result<()> {
        // 1. Serialize event to canonical JSON
        let event_json = serde_json::to_string(&event)?;

        // 2. Hash event
        let event_hash = Sha256::digest(event_json.as_bytes());

        // 3. Add to Merkle tree
        let mut tree = self.merkle_tree.lock().await;
        tree.append(&event_hash)?;
        let root_hash = tree.root();

        // 4. Sign root hash
        let signature = self.signing_key.sign(&root_hash);

        // 5. Store event with signature
        let mut signed_event = event;
        signed_event.signature = Some(base64::encode(signature.to_bytes()));

        self.storage.append(signed_event).await?;

        // 6. Periodically seal audit log
        if tree.len() % 1000 == 0 {
            self.seal_audit_log(&root_hash, &signature).await?;
        }

        Ok(())
    }

    pub async fn verify_integrity(&self, from_id: Uuid, to_id: Uuid) -> Result<bool> {
        // Fetch audit events
        let events = self.storage.get_range(from_id, to_id).await?;

        // Rebuild Merkle tree
        let mut tree = MerkleTree::new();
        for event in &events {
            let event_json = serde_json::to_string(event)?;
            let event_hash = Sha256::digest(event_json.as_bytes());
            tree.append(&event_hash)?;
        }

        // Verify root hash signature
        let root_hash = tree.root();
        let last_event = events.last().ok_or(Error::NoEvents)?;
        let signature = last_event.signature
            .as_ref()
            .ok_or(Error::NoSignature)?;

        let signature_bytes = base64::decode(signature)?;
        let signature = Signature::from_bytes(&signature_bytes)?;

        let verifying_key = self.signing_key.verifying_key();
        Ok(verifying_key.verify(&root_hash, &signature).is_ok())
    }

    async fn seal_audit_log(&self, root_hash: &[u8], signature: &Signature) -> Result<()> {
        // Store sealed log checkpoint
        let checkpoint = SealedCheckpoint {
            timestamp: Utc::now(),
            root_hash: base64::encode(root_hash),
            signature: base64::encode(signature.to_bytes()),
            event_count: self.merkle_tree.lock().await.len(),
        };

        self.storage.store_checkpoint(checkpoint).await?;

        info!(
            root_hash = %base64::encode(root_hash),
            "Audit log sealed"
        );

        Ok(())
    }
}
```

### 6.4 Audit Log Storage

**PostgreSQL Schema:**
```sql
CREATE TABLE audit_events (
    id UUID PRIMARY KEY,
    timestamp TIMESTAMPTZ NOT NULL,
    event_type TEXT NOT NULL,
    actor_id TEXT NOT NULL,
    actor_type TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    resource_id TEXT NOT NULL,
    namespace TEXT,
    tenant_id TEXT NOT NULL,
    action TEXT NOT NULL,
    result TEXT NOT NULL,
    request_context JSONB NOT NULL,
    metadata JSONB NOT NULL,
    signature TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for query performance
CREATE INDEX idx_audit_timestamp ON audit_events(timestamp DESC);
CREATE INDEX idx_audit_actor ON audit_events(actor_id, timestamp DESC);
CREATE INDEX idx_audit_resource ON audit_events(resource_type, resource_id, timestamp DESC);
CREATE INDEX idx_audit_tenant ON audit_events(tenant_id, timestamp DESC);
CREATE INDEX idx_audit_event_type ON audit_events(event_type, timestamp DESC);

-- Partitioning by month for retention management
CREATE TABLE audit_events_2025_11 PARTITION OF audit_events
    FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');

-- Sealed checkpoints table
CREATE TABLE audit_checkpoints (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ NOT NULL,
    root_hash TEXT NOT NULL,
    signature TEXT NOT NULL,
    event_count BIGINT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 6.5 Compliance Integration

**LLM-Policy-Engine Integration:**
```rust
pub struct ComplianceReporter {
    policy_engine_client: Arc<PolicyEngineClient>,
    audit_storage: Arc<dyn AuditStorage>,
}

impl ComplianceReporter {
    pub async fn generate_compliance_report(
        &self,
        tenant_id: &str,
        framework: ComplianceFramework,
        start_date: DateTime<Utc>,
        end_date: DateTime<Utc>,
    ) -> Result<ComplianceReport> {
        match framework {
            ComplianceFramework::Soc2 => self.generate_soc2_report(tenant_id, start_date, end_date).await,
            ComplianceFramework::Gdpr => self.generate_gdpr_report(tenant_id, start_date, end_date).await,
            ComplianceFramework::Hipaa => self.generate_hipaa_report(tenant_id, start_date, end_date).await,
            ComplianceFramework::PciDss => self.generate_pci_report(tenant_id, start_date, end_date).await,
        }
    }

    async fn generate_soc2_report(
        &self,
        tenant_id: &str,
        start_date: DateTime<Utc>,
        end_date: DateTime<Utc>,
    ) -> Result<ComplianceReport> {
        // SOC 2 Trust Service Criteria
        let controls = vec![
            self.verify_access_control(tenant_id, start_date, end_date).await?,
            self.verify_encryption_at_rest(tenant_id, start_date, end_date).await?,
            self.verify_encryption_in_transit(tenant_id, start_date, end_date).await?,
            self.verify_audit_logging(tenant_id, start_date, end_date).await?,
            self.verify_change_management(tenant_id, start_date, end_date).await?,
            self.verify_availability(tenant_id, start_date, end_date).await?,
        ];

        Ok(ComplianceReport {
            framework: ComplianceFramework::Soc2,
            tenant_id: tenant_id.to_string(),
            period: (start_date, end_date),
            controls,
            overall_compliance: controls.iter().all(|c| c.passed),
        })
    }

    async fn verify_access_control(
        &self,
        tenant_id: &str,
        start_date: DateTime<Utc>,
        end_date: DateTime<Utc>,
    ) -> Result<ControlResult> {
        // Query audit logs for unauthorized access attempts
        let denied_accesses = self.audit_storage
            .query()
            .tenant_id(tenant_id)
            .event_type(AuditEventType::AuthorizationDeny)
            .date_range(start_date, end_date)
            .count()
            .await?;

        // Verify RBAC enforcement
        let total_accesses = self.audit_storage
            .query()
            .tenant_id(tenant_id)
            .event_types(&[
                AuditEventType::ConfigRead,
                AuditEventType::ConfigWrite,
                AuditEventType::SecretRead,
            ])
            .date_range(start_date, end_date)
            .count()
            .await?;

        let rbac_enforcement_rate = if total_accesses > 0 {
            (total_accesses - denied_accesses) as f64 / total_accesses as f64
        } else {
            1.0
        };

        Ok(ControlResult {
            control_id: "CC6.1",
            control_name: "Access Control",
            passed: rbac_enforcement_rate >= 0.95, // 95% enforcement
            evidence: format!(
                "{} total accesses, {} denied ({}% enforcement rate)",
                total_accesses,
                denied_accesses,
                (rbac_enforcement_rate * 100.0) as u32
            ),
        })
    }
}
```

**LLM-Governance-Dashboard Integration:**
```rust
pub struct GovernanceDashboardSync {
    dashboard_client: Arc<GovernanceDashboardClient>,
    audit_storage: Arc<dyn AuditStorage>,
}

impl GovernanceDashboardSync {
    pub async fn sync_audit_events(&self) -> Result<()> {
        // Stream recent audit events to dashboard
        let events = self.audit_storage
            .query()
            .since(Utc::now() - Duration::from_secs(60)) // Last minute
            .limit(1000)
            .execute()
            .await?;

        for event in events {
            self.dashboard_client
                .publish_audit_event(event)
                .await?;
        }

        Ok(())
    }

    pub async fn push_metrics(&self) -> Result<()> {
        let metrics = AuditMetrics {
            total_events_last_hour: self.count_events_last_hour().await?,
            auth_failures_last_hour: self.count_auth_failures().await?,
            policy_violations_last_hour: self.count_policy_violations().await?,
            secret_rotations_pending: self.count_pending_rotations().await?,
        };

        self.dashboard_client
            .update_metrics(metrics)
            .await?;

        Ok(())
    }
}
```

---

## 7. Validation Policies

### 7.1 Schema Validation

**JSON Schema for Configuration Validation:**
```rust
use jsonschema::{Draft, JSONSchema};
use serde_json::json;

pub struct SchemaValidator {
    schemas: Arc<Mutex<HashMap<String, JSONSchema>>>,
}

impl SchemaValidator {
    pub fn new() -> Self {
        Self {
            schemas: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    pub async fn register_schema(
        &self,
        schema_name: &str,
        schema: serde_json::Value,
    ) -> Result<()> {
        let compiled = JSONSchema::options()
            .with_draft(Draft::Draft7)
            .compile(&schema)
            .map_err(|e| Error::InvalidSchema(e.to_string()))?;

        let mut schemas = self.schemas.lock().await;
        schemas.insert(schema_name.to_string(), compiled);

        Ok(())
    }

    pub async fn validate(
        &self,
        schema_name: &str,
        data: &serde_json::Value,
    ) -> Result<ValidationResult> {
        let schemas = self.schemas.lock().await;
        let schema = schemas
            .get(schema_name)
            .ok_or(Error::SchemaNotFound(schema_name.to_string()))?;

        match schema.validate(data) {
            Ok(_) => Ok(ValidationResult::Valid),
            Err(errors) => {
                let error_messages: Vec<String> = errors
                    .map(|e| format!("{} at {}", e, e.instance_path))
                    .collect();

                Ok(ValidationResult::Invalid { errors: error_messages })
            }
        }
    }
}
```

**Example Schemas:**
```rust
// Database configuration schema
let db_schema = json!({
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {
        "host": {
            "type": "string",
            "format": "hostname"
        },
        "port": {
            "type": "integer",
            "minimum": 1024,
            "maximum": 65535
        },
        "database": {
            "type": "string",
            "pattern": "^[a-z0-9_]+$",
            "minLength": 1,
            "maxLength": 63
        },
        "max_connections": {
            "type": "integer",
            "minimum": 1,
            "maximum": 1000,
            "default": 20
        },
        "ssl_mode": {
            "type": "string",
            "enum": ["disable", "require", "verify-ca", "verify-full"]
        }
    },
    "required": ["host", "port", "database"],
    "additionalProperties": false
});

// LLM API configuration schema
let llm_schema = json!({
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {
        "provider": {
            "type": "string",
            "enum": ["openai", "anthropic", "google", "azure", "aws"]
        },
        "model": {
            "type": "string"
        },
        "api_key": {
            "type": "string",
            "pattern": "^sk-[a-zA-Z0-9]{48}$"
        },
        "max_tokens": {
            "type": "integer",
            "minimum": 1,
            "maximum": 128000
        },
        "temperature": {
            "type": "number",
            "minimum": 0.0,
            "maximum": 2.0
        },
        "timeout_seconds": {
            "type": "integer",
            "minimum": 1,
            "maximum": 300,
            "default": 60
        }
    },
    "required": ["provider", "model", "api_key"],
    "additionalProperties": false
});
```

### 7.2 Custom Policy Validation

**Open Policy Agent (OPA) Integration:**
```rust
use serde_json::json;

pub struct PolicyValidator {
    opa_client: Arc<OpaClient>,
}

impl PolicyValidator {
    pub async fn validate_config_change(
        &self,
        actor: &Actor,
        config: &ConfigurationUpdate,
    ) -> Result<PolicyValidationResult> {
        // Prepare input for OPA
        let input = json!({
            "actor": {
                "id": actor.id,
                "roles": actor.roles,
                "tenant_id": actor.tenant_id,
            },
            "resource": {
                "namespace": config.namespace,
                "key": config.key,
                "value": config.value,
                "environment": config.environment,
            },
            "action": "config.write",
            "timestamp": Utc::now().to_rfc3339(),
        });

        // Query OPA
        let response = self.opa_client
            .query("llm/config/allow", input)
            .await?;

        if response.result.as_bool().unwrap_or(false) {
            Ok(PolicyValidationResult::Allowed)
        } else {
            let violations = response.violations
                .unwrap_or_default();

            Ok(PolicyValidationResult::Denied { violations })
        }
    }
}
```

**Example OPA Policy:**
```rego
package llm.config

import future.keywords.if
import future.keywords.in

# Deny production changes outside maintenance windows
deny[msg] {
    input.resource.environment == "production"
    not in_maintenance_window
    msg := "Production changes only allowed during maintenance windows"
}

# Deny secret changes without MFA
deny[msg] {
    contains(input.resource.key, "secret")
    not input.actor.mfa_verified
    msg := "Secret changes require MFA verification"
}

# Deny cross-tenant access
deny[msg] {
    input.resource.tenant_id != input.actor.tenant_id
    not "global-admin" in input.actor.roles
    msg := "Cross-tenant access denied"
}

# Deny changes to PII data without DPO role
deny[msg] {
    input.resource.contains_pii == true
    not "dpo" in input.actor.roles
    msg := "PII data modifications require DPO role"
}

# Allow if no denials
allow {
    count(deny) == 0
}

# Helper: Check if current time is in maintenance window
in_maintenance_window {
    now := time.now_ns()
    weekday := time.weekday(now)
    hour := time.clock([now])[0]

    # Maintenance window: Saturday 02:00-04:00 UTC
    weekday == "Saturday"
    hour >= 2
    hour < 4
}
```

### 7.3 Constraint Checking

**Validator Crate Integration:**
```rust
use validator::{Validate, ValidationError};

#[derive(Debug, Validate, Deserialize)]
pub struct DatabaseConfig {
    #[validate(url)]
    pub host: String,

    #[validate(range(min = 1024, max = 65535))]
    pub port: u16,

    #[validate(length(min = 1, max = 63), regex = "^[a-z0-9_]+$")]
    pub database: String,

    #[validate(range(min = 1, max = 1000))]
    pub max_connections: u32,

    #[validate(custom(function = "validate_ssl_mode"))]
    pub ssl_mode: String,
}

fn validate_ssl_mode(ssl_mode: &str) -> Result<(), ValidationError> {
    match ssl_mode {
        "disable" | "require" | "verify-ca" | "verify-full" => Ok(()),
        _ => {
            let mut error = ValidationError::new("invalid_ssl_mode");
            error.message = Some(Cow::from(
                "ssl_mode must be one of: disable, require, verify-ca, verify-full"
            ));
            Err(error)
        }
    }
}

#[derive(Debug, Validate, Deserialize)]
pub struct ApiKeyConfig {
    #[validate(length(min = 64, max = 64))]
    #[validate(custom(function = "validate_api_key_format"))]
    pub api_key: String,

    #[validate(range(min = 1, max = 10))]
    pub max_retries: u32,

    #[validate(range(min = 1, max = 300))]
    pub timeout_seconds: u64,
}

fn validate_api_key_format(api_key: &str) -> Result<(), ValidationError> {
    if api_key.starts_with("sk-") && api_key.len() == 51 {
        Ok(())
    } else {
        let mut error = ValidationError::new("invalid_api_key");
        error.message = Some(Cow::from("API key must start with 'sk-' and be 51 characters"));
        Err(error)
    }
}
```

---

## 8. Threat Model and Mitigations

### 8.1 Threat Categories

| Threat | Impact | Likelihood | Mitigation |
|--------|--------|------------|------------|
| **Unauthorized Access** | Critical | Medium | mTLS, RBAC, MFA, audit logging |
| **Credential Theft** | Critical | Medium | Encryption at rest, key rotation, short-lived tokens |
| **Man-in-the-Middle** | High | Low | TLS 1.3, certificate pinning, mTLS |
| **Data Exfiltration** | Critical | Low | Network segmentation, audit logs, DLP |
| **Insider Threat** | High | Medium | Least privilege, audit logs, separation of duties |
| **Supply Chain Attack** | High | Medium | Dependency scanning, SBOMs, signature verification |
| **Denial of Service** | Medium | High | Rate limiting, auto-scaling, circuit breakers |
| **Replay Attacks** | Medium | Low | Nonce-based encryption, timestamp validation |
| **Key Compromise** | Critical | Low | HSM-backed keys, key rotation, incident response |
| **SQL Injection** | High | Low | Parameterized queries, ORM, input validation |

### 8.2 Attack Scenarios and Mitigations

**Scenario 1: Compromised API Key**
- **Attack**: Attacker obtains API key through phishing or code leak
- **Detection**: Abnormal access patterns, geolocation anomalies, excessive requests
- **Mitigation**:
  - Immediate key revocation
  - Automatic rotation triggered
  - IP allowlisting enforcement
  - Rate limiting per key
  - Audit log analysis for unauthorized access

**Scenario 2: Insider Threat - Privilege Escalation**
- **Attack**: Malicious insider attempts to access secrets outside scope
- **Detection**: RBAC violation, cross-tenant access attempt, audit log alerts
- **Mitigation**:
  - Strict RBAC enforcement (no role bypasses)
  - Separation of duties (no user has both write and approve)
  - Anomaly detection for unusual access patterns
  - Real-time alerts to security team
  - Mandatory audit trail for all operations

**Scenario 3: Supply Chain Compromise - Malicious Dependency**
- **Attack**: Compromised Rust crate with backdoor
- **Detection**: cargo-audit, cargo-deny, manual code review
- **Mitigation**:
  - Dependency scanning in CI/CD pipeline
  - SBOM (Software Bill of Materials) generation
  - Signature verification for critical dependencies
  - Vendored dependencies for production builds
  - Minimal dependency footprint

---

## 9. Security Operations

### 9.1 Security Monitoring

**Real-Time Security Alerts:**
```rust
pub struct SecurityMonitor {
    alert_service: Arc<AlertService>,
    audit_logger: Arc<AuditLogger>,
}

impl SecurityMonitor {
    pub async fn monitor_security_events(&self) {
        // Monitor for suspicious patterns
        self.monitor_failed_authentications().await;
        self.monitor_privilege_escalations().await;
        self.monitor_unusual_access_patterns().await;
        self.monitor_key_compromise_indicators().await;
    }

    async fn monitor_failed_authentications(&self) {
        // Trigger alert if >5 failed auth attempts in 5 minutes
        let threshold = 5;
        let window = Duration::from_secs(5 * 60);

        let failed_attempts = self.audit_logger
            .count_events(AuditEventType::AuthenticationFailure, window)
            .await
            .unwrap_or(0);

        if failed_attempts > threshold {
            self.alert_service.send(SecurityAlert {
                severity: Severity::High,
                title: "Repeated authentication failures detected",
                description: format!("{} failed attempts in last 5 minutes", failed_attempts),
                recommended_action: "Investigate potential brute-force attack",
            }).await.ok();
        }
    }
}
```

### 9.2 Incident Response

**Incident Response Playbook:**

1. **Detection**: Automated alerting via security monitoring
2. **Containment**:
   - Revoke compromised credentials immediately
   - Disable affected service accounts
   - Block suspicious IP addresses
   - Isolate affected tenants/namespaces
3. **Investigation**:
   - Review audit logs for full scope
   - Identify compromised resources
   - Determine attack vector
4. **Remediation**:
   - Rotate all potentially compromised secrets
   - Patch vulnerabilities
   - Update security policies
5. **Recovery**:
   - Restore services with new credentials
   - Verify integrity of configurations
   - Monitor for residual threats
6. **Post-Incident**:
   - Root cause analysis
   - Update runbooks
   - Security training

### 9.3 Vulnerability Management

**Security Scanning Pipeline:**
```yaml
# CI/CD Security Checks
security_scan:
  - cargo audit     # Vulnerability scanning
  - cargo deny      # License and advisory checking
  - clippy          # Linting for security anti-patterns
  - semgrep         # Static analysis for vulnerabilities
  - trivy           # Container image scanning
```

**Dependency Audit:**
```toml
# .cargo/audit.toml
[advisories]
db-path = "~/.cargo/advisory-db"
db-urls = ["https://github.com/rustsec/advisory-db"]
vulnerability = "deny"
unmaintained = "warn"
unsound = "warn"
yanked = "deny"

[licenses]
unlicensed = "deny"
copyleft = "deny"
allow = ["MIT", "Apache-2.0", "BSD-3-Clause"]
```

---

## 10. Conclusion

This security architecture provides comprehensive protection for the LLM-Config-Manager through:

1. **Production-Ready Rust Crates**: Carefully selected, actively maintained, and security-audited libraries
2. **Defense in Depth**: Multiple layers of security controls from infrastructure to compliance
3. **Zero-Trust Architecture**: Continuous verification and least privilege enforcement
4. **Automated Security Operations**: Secret rotation, key management, and monitoring
5. **Compliance Framework**: Built-in support for SOC 2, GDPR, HIPAA, and other standards

The architecture balances security, performance, and operational complexity while providing enterprise-grade protection for sensitive configuration data and secrets.

---

**Document Version:** 1.0.0
**Last Updated:** 2025-11-21
**Author:** Security Architect Agent
**Status:** Ready for Review and Integration into ARCHITECTURE.md
