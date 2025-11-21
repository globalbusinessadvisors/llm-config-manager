//! Multi-tier caching for LLM Config Manager
//!
//! This module provides a two-tier caching system:
//! - L1 Cache: In-memory cache for ultra-fast access (LRU eviction)
//! - L2 Cache: Persistent cache for warm restarts
//!
//! ## Performance Characteristics
//! - L1 Cache: <1μs latency
//! - L2 Cache: <1ms latency
//! - Cache miss: 5-10ms (disk read)

pub mod l1;
pub mod l2;
pub mod manager;

pub use l1::L1Cache;
pub use l2::L2Cache;
pub use manager::CacheManager;

use thiserror::Error;

#[derive(Debug, Error)]
pub enum CacheError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Serialization error: {0}")]
    Serialization(String),

    #[error("Cache miss for key: {0}")]
    CacheMiss(String),

    #[error("Eviction error: {0}")]
    Eviction(String),
}

pub type Result<T> = std::result::Result<T, CacheError>;
