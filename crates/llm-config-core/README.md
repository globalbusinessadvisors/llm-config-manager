# llm-config-core

[![Crates.io](https://img.shields.io/crates/v/llm-config-core.svg)](https://crates.io/crates/llm-config-core)
[![Documentation](https://docs.rs/llm-config-core/badge.svg)](https://docs.rs/llm-config-core)
[![License](https://img.shields.io/crates/l/llm-config-core.svg)](https://github.com/globalbusinessadvisors/llm-config-manager/blob/main/LICENSE)

Core configuration management library for LLM Config Manager with multi-environment support, versioning, and secret management.

## Features

- **Multi-Environment Support**: Manage configurations across dev, staging, production, and custom environments
- **Secret Management**: Encrypted storage of sensitive configuration values
- **Version Control**: Track changes and rollback to previous configurations
- **Namespace Isolation**: Organize configurations by application or service
- **Environment Overrides**: Cascade configuration values with environment-specific overrides
- **Type Safety**: Strong typing for configuration values with validation
- **Async/Await**: Full async support with Tokio runtime

## Usage

Add this to your `Cargo.toml`:

```toml
[dependencies]
llm-config-core = "0.5.0"
tokio = { version = "1", features = ["full"] }
```

### Quick Start

```rust
use llm_config_core::{ConfigManager, Environment};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize configuration manager
    let config = ConfigManager::new("./config-data").await?;

    // Set a configuration value
    config.set(
        "app.database.url",
        "postgres://localhost/mydb",
        Environment::Development
    ).await?;

    // Get a configuration value
    let db_url = config.get("app.database.url", Environment::Development).await?;
    println!("Database URL: {}", db_url);

    Ok(())
}
```

### Secret Management

```rust
// Store an encrypted secret
config.set_secret(
    "app.api.key",
    "my-secret-api-key",
    Environment::Production
).await?;

// Retrieve and decrypt the secret
let api_key = config.get_secret("app.api.key", Environment::Production).await?;
```

### Version Control

```rust
// Get configuration history
let history = config.get_history("app.database.url").await?;
for version in history {
    println!("Version {}: {}", version.version, version.value);
}

// Rollback to previous version
config.rollback("app.database.url", 5).await?;
```

### Environment Overrides

```rust
// Set base configuration
config.set("app.max_connections", "100", Environment::Base).await?;

// Override for production
config.set("app.max_connections", "500", Environment::Production).await?;

// Get with cascade (returns 500 for production, 100 for others)
let max_conns = config.get_with_overrides("app.max_connections", Environment::Production).await?;
```

## Architecture

The core library is built on:
- **llm-config-storage**: Persistent storage backend
- **llm-config-crypto**: Encryption for secrets
- **Sled**: Embedded database for fast access
- **Tokio**: Async runtime for concurrent operations

## Performance

Benchmarks on modern hardware:
- Configuration retrieval: ~50 µs
- Configuration updates: ~100 µs
- With encryption: ~120 µs
- Batch operations: ~10,000 ops/sec

## Minimum Supported Rust Version

This crate requires Rust 1.75 or later.

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](../../LICENSE) for details.

## Contributing

See [CONTRIBUTING.md](../../docs/CONTRIBUTING.md) for contribution guidelines.
