# Encryption Policy

**Policy Number**: SEC-POL-002
**Version**: 1.0
**Effective Date**: 2025-11-21
**Review Date**: 2026-11-21
**Owner**: Security Team
**Classification**: Internal Use

## 1. Purpose

This policy establishes requirements for the use of cryptographic controls to protect sensitive data in the LLM Config Manager system in accordance with industry best practices and regulatory requirements.

## 2. Scope

This policy applies to:
- All data stored by LLM Config Manager
- All data transmitted by LLM Config Manager
- All cryptographic operations
- All encryption keys and key management
- All personnel handling encrypted data

## 3. Policy Statements

### 3.1 Data Encryption Requirements

**3.1.1 Encryption at Rest**

**Mandatory Encryption**:
- All Secret-classified data (API keys, credentials, PHI, PII)
- All Confidential-classified data
- All encryption keys
- All authentication credentials
- All backup data

**Algorithm Requirements**:
- **Symmetric Encryption**: AES-256-GCM (Advanced Encryption Standard, 256-bit key, Galois/Counter Mode)
- **Minimum Key Length**: 256 bits (32 bytes)
- **No Weak Algorithms**: No DES, 3DES, RC4, MD5, SHA-1

**Implementation**:
```
Location: /workspaces/llm-config-manager/crates/llm-config-crypto/
Algorithm: AES-256-GCM
Key Management: Secure key storage with separation
Validation: Crypto validator enforces standards
```

**3.1.2 Encryption in Transit**

**Mandatory TLS**:
- All API communications: TLS 1.2 or higher
- All administrative access: TLS 1.2 or higher
- All database connections: TLS 1.2 or higher
- All inter-service communication: TLS 1.2 or higher

**TLS Requirements**:
- **Minimum Version**: TLS 1.2 (TLS 1.3 preferred)
- **Cipher Suites**: Strong ciphers only (ECDHE, AES-GCM)
- **Certificate Validation**: Required for all connections
- **No Weak Ciphers**: No SSLv2, SSLv3, TLS 1.0, TLS 1.1

**Approved Cipher Suites**:
```
TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
TLS_AES_256_GCM_SHA384 (TLS 1.3)
TLS_AES_128_GCM_SHA256 (TLS 1.3)
```

**3.1.3 Classification-Based Encryption**

| Classification | At Rest | In Transit | Key Length |
|----------------|---------|------------|------------|
| **Secret** | AES-256-GCM (Required) | TLS 1.2+ (Required) | 256-bit |
| **Confidential** | AES-256-GCM (Required) | TLS 1.2+ (Required) | 256-bit |
| **Internal** | Recommended | TLS 1.2+ (Recommended) | 256-bit |
| **Public** | Not required | TLS 1.2+ (Optional) | N/A |

### 3.2 Key Management

**3.2.1 Key Generation**

- **Cryptographically Secure Random Number Generator (CSRNG)** required
- **Minimum Key Length**: 256 bits for symmetric, 2048 bits for asymmetric
- **Entropy**: Adequate entropy verified before generation
- **No Weak Keys**: All-zeros, all-ones, repeating patterns rejected

**Key Generation Implementation**:
```rust
// Secure key generation
use ring::rand::{SystemRandom, SecureRandom};

let rng = SystemRandom::new();
let mut key = [0u8; 32];  // 256-bit key
rng.fill(&mut key)?;

// Validate key strength
crypto_validator.validate_key(&key)?;
```

**3.2.2 Key Storage**

- **Separation**: Keys stored separately from encrypted data
- **Encryption**: Keys encrypted with Key Encryption Key (KEK)
- **Access Control**: Strict access control on key storage
- **Hardware Security Module (HSM)**: Recommended for production
- **No Hardcoded Keys**: Keys never embedded in code
- **Environment Variables**: Keys passed via secure environment variables or secrets management

**3.2.3 Key Distribution**

- **Secure Channels**: Keys distributed only over encrypted channels
- **Authorization**: Distribution to authorized personnel/systems only
- **Audit Trail**: All key distribution logged
- **No Email**: Keys never sent via email or unencrypted communication

**3.2.4 Key Rotation**

**Rotation Schedule**:
- **Encryption Keys**: Every 90 days (recommended)
- **API Keys**: Every 90 days (mandatory)
- **TLS Certificates**: Every 365 days (mandatory)
- **Master Keys**: Every 365 days (mandatory)

**Rotation Triggers**:
- Scheduled rotation period reached
- Key compromise suspected
- Personnel with key access terminated
- System migration or upgrade
- Compliance requirement

**Rotation Process**:
1. Generate new key
2. Re-encrypt data with new key
3. Secure disposal of old key
4. Update key references
5. Verify re-encryption successful
6. Audit log rotation event

**Implementation**:
```rust
pub struct KeyValidator {
    max_key_age_days: u32,
}

impl KeyValidator {
    /// Check if key should be rotated
    pub fn should_rotate(&self, key_created_at: DateTime<Utc>) -> bool {
        let age = Utc::now() - key_created_at;
        age.num_days() > self.max_key_age_days as i64
    }

    /// Days until rotation needed
    pub fn days_until_rotation(&self, key_created_at: DateTime<Utc>) -> i64 {
        let age = (Utc::now() - key_created_at).num_days();
        self.max_key_age_days as i64 - age
    }
}
```

**3.2.5 Key Destruction**

**When to Destroy Keys**:
- Key rotated (old key destroyed after re-encryption)
- Data permanently deleted
- Key compromised
- Retention period expired

**Destruction Methods**:
- **Cryptographic Erasure**: Overwrite with random data
- **Zeroization**: Overwrite with zeros
- **Physical Destruction**: For hardware keys/HSM
- **Verification**: Confirm destruction completed

**Secure Memory Handling**:
```rust
use zeroize::Zeroize;

struct SecureSecret {
    data: Vec<u8>,
}

impl Drop for SecureSecret {
    fn drop(&mut self) {
        // Zeroize memory on drop
        self.data.zeroize();
    }
}
```

### 3.3 Password Security

**3.3.1 Password Hashing**

- **Algorithm**: Argon2id (recommended) or bcrypt
- **Salt**: Unique salt per password
- **Work Factor**: Appropriate cost parameter
- **No Weak Hashing**: No MD5, SHA-1, plain SHA-256

**Implementation**:
```rust
use argon2::{Argon2, PasswordHasher, PasswordVerifier};

// Hash password
let salt = SaltString::generate(&mut OsRng);
let argon2 = Argon2::default();
let password_hash = argon2.hash_password(password, &salt)?;

// Verify password
let parsed_hash = PasswordHash::new(&password_hash)?;
argon2.verify_password(password, &parsed_hash)?;
```

**3.3.2 Password Storage**

- Never store passwords in plaintext
- Store only password hashes
- Salt every password
- Use appropriate work factor

### 3.4 Algorithm and Protocol Standards

**3.4.1 Approved Algorithms**

**Symmetric Encryption**:
- ✅ AES-256-GCM (Recommended)
- ✅ AES-192-GCM
- ✅ AES-128-GCM
- ❌ DES, 3DES, RC4, Blowfish (Prohibited)

**Asymmetric Encryption**:
- ✅ RSA 3072-bit or higher
- ✅ ECDSA with P-256 or higher
- ✅ EdDSA (Ed25519)
- ❌ RSA < 2048-bit (Prohibited)

**Hashing**:
- ✅ SHA-256, SHA-384, SHA-512 (General purpose)
- ✅ Argon2id, bcrypt (Password hashing)
- ❌ MD5, SHA-1 (Prohibited except for non-security uses)

**3.4.2 Protocol Standards**

**TLS/SSL**:
- ✅ TLS 1.3 (Preferred)
- ✅ TLS 1.2 (Minimum)
- ❌ TLS 1.1, TLS 1.0, SSLv3, SSLv2 (Prohibited)

### 3.5 Cryptographic Operations

**3.5.1 Secure Comparison**

- Use constant-time comparison for secrets
- Prevent timing attacks
- Never use simple equality for security-sensitive comparisons

**Implementation**:
```rust
use subtle::ConstantTimeEq;

// Constant-time comparison
let equal = secret1.ct_eq(&secret2);
```

**3.5.2 Random Number Generation**

- Use cryptographically secure RNG (CSRNG)
- Never use standard random() for security purposes
- System-provided CSRNG preferred

**3.5.3 Secure Coding Practices**

- Avoid storing sensitive data longer than necessary
- Clear sensitive data from memory after use
- Use secure memory handling (zeroization)
- Validate all cryptographic inputs
- Handle errors securely (no information leakage)

### 3.6 Compliance and Standards

**3.6.1 Regulatory Compliance**

This policy ensures compliance with:
- **GDPR**: Article 32 - Security of processing
- **HIPAA**: 45 CFR § 164.312(a)(2)(iv) - Encryption and decryption
- **PCI DSS**: Requirement 3 - Protect stored cardholder data
- **SOC 2**: CC6.6 - Restriction of access to data
- **ISO 27001**: A.10.1.1, A.10.1.2 - Cryptographic controls

**3.6.2 Industry Standards**

Adherence to:
- **NIST SP 800-57**: Key Management Recommendations
- **NIST SP 800-175B**: Guideline for Using Cryptographic Standards
- **FIPS 140-2**: Cryptographic Module Validation (Level 1 minimum)

## 4. Roles and Responsibilities

### 4.1 Security Team
- Define and maintain encryption policy
- Approve cryptographic standards
- Monitor encryption implementation
- Conduct encryption audits

### 4.2 Development Team
- Implement encryption according to policy
- Use approved algorithms and libraries
- Secure key handling in code
- Test encryption functionality

### 4.3 Operations Team
- Manage encryption keys
- Configure TLS properly
- Monitor key expiration
- Execute key rotation

### 4.4 All Personnel
- Protect encryption keys
- Report suspected key compromise
- Follow secure key handling procedures
- Comply with policy requirements

## 5. Exceptions

### 5.1 Exception Process
- Written exception request required
- Business and technical justification
- Risk assessment and compensating controls
- Security team approval
- Time-limited (annual renewal)
- Exception log maintained

### 5.2 Legacy Systems
- Documented migration plan required
- Compensating controls implemented
- Regular risk review
- Target date for compliance

## 6. Monitoring and Enforcement

### 6.1 Monitoring
- Encryption coverage monitored
- Weak algorithm detection
- Key age tracking
- TLS version monitoring
- Certificate expiration tracking

### 6.2 Enforcement
- Automated enforcement via crypto validator
- Code review for compliance
- Security testing
- Policy violations reported

### 6.3 Audit
- Annual policy compliance audit
- Encryption implementation review
- Key management audit
- Algorithm compliance verification

## 7. Incident Response

### 7.1 Key Compromise
- Immediate key rotation
- Impact assessment
- Re-encryption if necessary
- Incident investigation
- Notification per breach policy

### 7.2 Encryption Failure
- Immediate investigation
- System isolation if needed
- Data integrity verification
- Remediation and recovery
- Post-incident review

## 8. Related Documents

- Security Policy (SEC-POL-000)
- Access Control Policy (SEC-POL-001)
- Incident Response Policy (SEC-POL-003)
- Key Management Procedures
- Cryptographic Standards Guide

## 9. References

- NIST Special Publication 800-57: Key Management Recommendations
- NIST Special Publication 800-175B: Cryptographic Standards
- OWASP Cryptographic Storage Cheat Sheet
- OWASP Key Management Cheat Sheet

## 10. Policy Review

This policy is reviewed annually and updated to address:
- New cryptographic vulnerabilities
- Algorithm deprecations
- Regulatory changes
- Technology advances
- Lessons learned from incidents

---

**Approved by**:
- Chief Information Security Officer: _________________ Date: _______
- Chief Technology Officer: _________________ Date: _______

**Document Control**:
- Version: 1.0
- Effective: 2025-11-21
- Next Review: 2026-11-21
- Owner: Security Team
