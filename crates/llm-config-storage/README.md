# llm-config-storage

[![Crates.io](https://img.shields.io/crates/v/llm-config-storage.svg)](https://crates.io/crates/llm-config-storage)
[![Documentation](https://docs.rs/llm-config-storage/badge.svg)](https://docs.rs/llm-config-storage)
[![License](https://img.shields.io/crates/l/llm-config-storage.svg)](https://github.com/globalbusinessadvisors/llm-config-manager/blob/main/LICENSE)

Persistent storage backend for LLM Config Manager using embedded Sled database with encryption support.

## Features

- **Embedded Database**: Zero-config Sled database for persistent storage
- **Encryption at Rest**: Automatic encryption of sensitive configuration data
- **ACID Transactions**: Atomic, consistent, isolated, durable operations
- **Namespace Isolation**: Separate storage for different configuration namespaces
- **Version History**: Store and retrieve historical configuration versions
- **Backup & Restore**: Built-in backup and restore capabilities

## Usage

Add this to your `Cargo.toml`:

```toml
[dependencies]
llm-config-storage = "0.5.0"
llm-config-crypto = "0.5.0"
```

### Basic Example

```rust
use llm_config_storage::StorageBackend;
use llm_config_crypto::CryptoManager;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize storage with encryption
    let crypto = CryptoManager::new()?;
    let storage = StorageBackend::open("./data", Some(crypto))?;

    // Store configuration
    storage.put("app.database.url", b"postgres://localhost/mydb").await?;

    // Retrieve configuration
    let value = storage.get("app.database.url").await?;

    Ok(())
}
```

### Namespace Management

```rust
// Create namespace-specific storage
let namespace = storage.namespace("production");
namespace.put("api.key", b"secret-key").await?;
```

## Storage Format

- **Key-Value Store**: Simple and efficient key-value access
- **JSON/Binary**: Supports both JSON and binary value storage
- **Compression**: Optional compression for large values
- **Encryption**: Transparent encryption layer for sensitive data

## Performance

Benchmarks on modern hardware:
- Read operations: ~10 µs per key
- Write operations: ~50 µs per key
- Batch writes: ~5000 ops/sec

## Minimum Supported Rust Version

This crate requires Rust 1.75 or later.

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](../../LICENSE) for details.

## Contributing

See [CONTRIBUTING.md](../../docs/CONTRIBUTING.md) for contribution guidelines.
