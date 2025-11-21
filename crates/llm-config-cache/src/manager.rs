//! Cache manager coordinating L1 and L2 caches

use crate::{l1::L1Cache, l2::L2Cache, Result};
use llm_config_core::ConfigEntry;
use std::path::Path;
use std::sync::Arc;

/// Multi-tier cache manager
pub struct CacheManager {
    l1: Arc<L1Cache>,
    l2: Arc<L2Cache>,
}

impl CacheManager {
    /// Create a new cache manager
    pub fn new(l1_size: usize, l2_dir: impl AsRef<Path>) -> Result<Self> {
        Ok(Self {
            l1: Arc::new(L1Cache::new(l1_size)),
            l2: Arc::new(L2Cache::new(l2_dir)?),
        })
    }

    /// Get an entry from the cache
    ///
    /// Search order:
    /// 1. L1 cache (fastest)
    /// 2. L2 cache (fast)
    /// 3. Return cache miss
    pub fn get(&self, namespace: &str, key: &str, env: &str) -> Result<ConfigEntry> {
        // Try L1 first
        if let Ok(entry) = self.l1.get(namespace, key, env) {
            return Ok(entry);
        }

        // Try L2 if L1 miss
        if let Ok(entry) = self.l2.get(namespace, key, env) {
            // Promote to L1
            self.l1.put(entry.clone())?;
            return Ok(entry);
        }

        // Complete cache miss
        Err(crate::CacheError::CacheMiss(format!(
            "{}:{}:{}",
            namespace, key, env
        )))
    }

    /// Put an entry into the cache (both L1 and L2)
    pub fn put(&self, entry: ConfigEntry) -> Result<()> {
        // Write to both caches
        self.l1.put(entry.clone())?;
        self.l2.put(&entry)?;
        Ok(())
    }

    /// Invalidate an entry from both caches
    pub fn invalidate(&self, namespace: &str, key: &str, env: &str) -> Result<()> {
        self.l1.invalidate(namespace, key, env);
        self.l2.invalidate(namespace, key, env)?;
        Ok(())
    }

    /// Clear both caches
    pub fn clear(&self) -> Result<()> {
        self.l1.clear();
        self.l2.clear()?;
        Ok(())
    }

    /// Get L1 cache statistics
    pub fn l1_stats(&self) -> crate::l1::CacheStats {
        self.l1.stats()
    }

    /// Get L2 cache size
    pub fn l2_size(&self) -> usize {
        self.l2.size()
    }

    /// Clear only L1 cache (for testing)
    pub fn clear_l1(&self) {
        self.l1.clear();
    }

    /// Clear only L2 cache (for testing)
    pub fn clear_l2(&self) -> Result<()> {
        self.l2.clear()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use llm_config_core::{ConfigMetadata, ConfigValue, Environment};
    use tempfile::TempDir;
    use uuid::Uuid;

    fn create_test_entry(namespace: &str, key: &str, env: Environment) -> ConfigEntry {
        ConfigEntry {
            id: Uuid::new_v4(),
            namespace: namespace.to_string(),
            key: key.to_string(),
            value: ConfigValue::String("test-value".to_string()),
            environment: env,
            version: 1,
            metadata: ConfigMetadata {
                created_at: chrono::Utc::now(),
                created_by: "test".to_string(),
                updated_at: chrono::Utc::now(),
                updated_by: "test".to_string(),
                tags: vec![],
                description: None,
            },
        }
    }

    #[test]
    fn test_manager_creation() {
        let temp_dir = TempDir::new().unwrap();
        let manager = CacheManager::new(100, temp_dir.path()).unwrap();
        assert_eq!(manager.l1_stats().size, 0);
        assert_eq!(manager.l2_size(), 0);
    }

    #[test]
    fn test_put_and_get() {
        let temp_dir = TempDir::new().unwrap();
        let manager = CacheManager::new(100, temp_dir.path()).unwrap();

        let entry = create_test_entry("ns", "key1", Environment::Development);
        manager.put(entry.clone()).unwrap();

        let retrieved = manager.get("ns", "key1", "development").unwrap();
        assert_eq!(retrieved.id, entry.id);
    }

    #[test]
    fn test_l1_to_l2_fallback() {
        let temp_dir = TempDir::new().unwrap();
        let manager = CacheManager::new(100, temp_dir.path()).unwrap();

        let entry = create_test_entry("ns", "key1", Environment::Development);
        manager.put(entry.clone()).unwrap();

        // Clear L1 but L2 should still have it
        manager.l1.clear();

        // Should still retrieve from L2
        let retrieved = manager.get("ns", "key1", "development").unwrap();
        assert_eq!(retrieved.id, entry.id);

        // L1 should now have it (promoted)
        let stats = manager.l1_stats();
        assert_eq!(stats.size, 1);
    }

    #[test]
    fn test_invalidate() {
        let temp_dir = TempDir::new().unwrap();
        let manager = CacheManager::new(100, temp_dir.path()).unwrap();

        let entry = create_test_entry("ns", "key1", Environment::Development);
        manager.put(entry).unwrap();

        manager.invalidate("ns", "key1", "development").unwrap();

        assert!(manager.get("ns", "key1", "development").is_err());
    }

    #[test]
    fn test_clear() {
        let temp_dir = TempDir::new().unwrap();
        let manager = CacheManager::new(100, temp_dir.path()).unwrap();

        for i in 0..10 {
            let entry = create_test_entry("ns", &format!("key{}", i), Environment::Development);
            manager.put(entry).unwrap();
        }

        assert_eq!(manager.l1_stats().size, 10);
        assert_eq!(manager.l2_size(), 10);

        manager.clear().unwrap();

        assert_eq!(manager.l1_stats().size, 0);
        assert_eq!(manager.l2_size(), 0);
    }

    #[test]
    fn test_cache_promotion() {
        let temp_dir = TempDir::new().unwrap();
        let manager = CacheManager::new(2, temp_dir.path()).unwrap(); // Small L1 cache

        // Add 3 entries
        for i in 0..3 {
            let entry = create_test_entry("ns", &format!("key{}", i), Environment::Development);
            manager.put(entry).unwrap();
        }

        // L1 can only hold 2 entries, L2 should have all 3
        assert_eq!(manager.l1_stats().size, 2);
        assert_eq!(manager.l2_size(), 3);

        // Access an entry that was evicted from L1
        manager.get("ns", "key0", "development").unwrap();

        // It should be promoted back to L1
        let stats = manager.l1_stats();
        assert_eq!(stats.size, 2); // Still at capacity
    }
}
