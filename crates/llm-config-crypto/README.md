# llm-config-crypto

[![Crates.io](https://img.shields.io/crates/v/llm-config-crypto.svg)](https://crates.io/crates/llm-config-crypto)
[![Documentation](https://docs.rs/llm-config-crypto/badge.svg)](https://docs.rs/llm-config-crypto)
[![License](https://img.shields.io/crates/l/llm-config-crypto.svg)](https://github.com/globalbusinessadvisors/llm-config-manager/blob/main/LICENSE)

Cryptography primitives for LLM Config Manager providing AES-256-GCM encryption, key derivation, and secure key management.

## Features

- **AES-256-GCM Encryption**: Industry-standard encryption for configuration secrets
- **Secure Key Derivation**: Argon2id-based key derivation from passwords
- **Key Management**: Secure generation, storage, and rotation of encryption keys
- **Zero-Copy Security**: Zeroization of sensitive data in memory
- **ChaCha20-Poly1305**: Alternative cipher for high-performance scenarios

## Usage

Add this to your `Cargo.toml`:

```toml
[dependencies]
llm-config-crypto = "0.5.0"
```

### Basic Example

```rust
use llm_config_crypto::{CryptoManager, KeyDerivation};

// Create a crypto manager
let crypto = CryptoManager::new()?;

// Encrypt sensitive data
let plaintext = b"my-secret-value";
let encrypted = crypto.encrypt(plaintext)?;

// Decrypt data
let decrypted = crypto.decrypt(&encrypted)?;
assert_eq!(plaintext, decrypted.as_slice());
```

### Key Derivation

```rust
use llm_config_crypto::KeyDerivation;

// Derive a key from a password
let password = "my-secure-password";
let salt = KeyDerivation::generate_salt()?;
let key = KeyDerivation::derive_key(password, &salt)?;
```

## Security Features

- **AEAD**: Authenticated encryption with associated data
- **Constant-time operations**: Prevents timing attacks
- **Automatic zeroization**: Sensitive data cleared from memory
- **Secure random**: Cryptographically secure random number generation

## Performance

Benchmarks on modern hardware:
- Encryption (1KB): ~20 µs
- Decryption (1KB): ~20 µs
- Key derivation: ~100 ms (tuned for security)

## Minimum Supported Rust Version

This crate requires Rust 1.75 or later.

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](../../LICENSE) for details.

## Contributing

See [CONTRIBUTING.md](../../docs/CONTRIBUTING.md) for contribution guidelines.
