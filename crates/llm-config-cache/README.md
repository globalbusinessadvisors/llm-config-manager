# llm-config-cache

[![Crates.io](https://img.shields.io/crates/v/llm-config-cache.svg)](https://crates.io/crates/llm-config-cache)
[![Documentation](https://docs.rs/llm-config-cache/badge.svg)](https://docs.rs/llm-config-cache)
[![License](https://img.shields.io/crates/l/llm-config-cache.svg)](https://github.com/globalbusinessadvisors/llm-config-manager/blob/main/LICENSE)

Multi-tier caching system with L1/L2 cache support, TTL management, and cache invalidation strategies for LLM Config Manager.

## Features

- **Two-Tier Caching**: In-memory L1 cache + persistent L2 cache
- **TTL Management**: Automatic expiration of cached entries
- **Cache Promotion**: Hot entries promoted from L2 to L1
- **Invalidation Strategies**: Pattern-based and namespace-wide invalidation
- **High Performance**: Sub-microsecond L1 access, microsecond L2 access

## Usage

```toml
[dependencies]
llm-config-cache = "0.5.0"
```

```rust
use llm_config_cache::CacheManager;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cache = CacheManager::new();

    // Cache a value
    cache.put("key", b"value", Some(Duration::from_secs(300))).await?;

    // Retrieve from cache
    if let Some(value) = cache.get("key").await? {
        println!("Cached: {:?}", value);
    }

    Ok(())
}
```

## Performance

- L1 cache hit: ~8 µs
- L2 cache hit: ~50 µs
- Cache miss: Falls through to storage

## License

Licensed under the Apache License, Version 2.0.
