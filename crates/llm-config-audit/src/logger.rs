//! Audit logger implementation

use crate::{
    events::{AuditEvent, AuditEventType},
    storage::AuditStorage,
    Result,
};
use std::sync::Arc;
use tokio::sync::mpsc;
use tracing::{error, info};

/// Audit logger with async event processing
pub struct AuditLogger {
    storage: Arc<dyn AuditStorage>,
    event_tx: mpsc::UnboundedSender<AuditEvent>,
}

impl AuditLogger {
    /// Create a new audit logger
    pub fn new(storage: Arc<dyn AuditStorage>) -> Self {
        let (event_tx, mut event_rx) = mpsc::unbounded_channel::<AuditEvent>();

        let storage_clone = Arc::clone(&storage);

        // Spawn background task to process events
        tokio::spawn(async move {
            while let Some(event) = event_rx.recv().await {
                if let Err(e) = storage_clone.store(&event) {
                    error!("Failed to store audit event: {}", e);
                } else {
                    info!(
                        event_id = %event.id,
                        event_type = ?event.event_type,
                        user = %event.user,
                        "Audit event logged"
                    );
                }
            }
        });

        Self { storage, event_tx }
    }

    /// Log an audit event
    pub fn log(&self, event: AuditEvent) -> Result<()> {
        self.event_tx
            .send(event)
            .map_err(|e| crate::AuditError::Storage(format!("Failed to send event: {}", e)))?;
        Ok(())
    }

    /// Log an audit event (convenience method that creates the event)
    pub fn log_event(&self, event_type: AuditEventType, user: impl Into<String>) -> Result<()> {
        let event = AuditEvent::new(event_type, user);
        self.log(event)
    }

    /// Query events from storage
    pub fn query(
        &self,
        start: chrono::DateTime<chrono::Utc>,
        end: chrono::DateTime<chrono::Utc>,
        limit: Option<usize>,
    ) -> Result<Vec<AuditEvent>> {
        self.storage.query(start, end, limit)
    }

    /// Query events by user
    pub fn query_by_user(&self, user: &str, limit: Option<usize>) -> Result<Vec<AuditEvent>> {
        self.storage.query_by_user(user, limit)
    }

    /// Get total event count
    pub fn count(&self) -> Result<usize> {
        self.storage.count()
    }
}

impl Clone for AuditLogger {
    fn clone(&self) -> Self {
        Self {
            storage: Arc::clone(&self.storage),
            event_tx: self.event_tx.clone(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{events::AuditEventType, storage::FileAuditStorage};
    use tempfile::TempDir;

    #[tokio::test]
    async fn test_logger_creation() {
        let temp_dir = TempDir::new().unwrap();
        let storage = Arc::new(FileAuditStorage::new(temp_dir.path()).unwrap());
        let logger = AuditLogger::new(storage);

        assert!(logger.count().is_ok());
    }

    #[tokio::test]
    async fn test_log_event() {
        let temp_dir = TempDir::new().unwrap();
        let storage = Arc::new(FileAuditStorage::new(temp_dir.path()).unwrap());
        let logger = AuditLogger::new(storage);

        logger
            .log_event(
                AuditEventType::ConfigCreated {
                    namespace: "test".to_string(),
                    key: "key1".to_string(),
                    environment: "dev".to_string(),
                },
                "test-user",
            )
            .unwrap();

        // Wait for async processing
        tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;

        let count = logger.count().unwrap();
        assert_eq!(count, 1);
    }

    #[tokio::test]
    async fn test_multiple_events() {
        let temp_dir = TempDir::new().unwrap();
        let storage = Arc::new(FileAuditStorage::new(temp_dir.path()).unwrap());
        let logger = AuditLogger::new(storage);

        for i in 0..10 {
            logger
                .log_event(
                    AuditEventType::ConfigAccessed {
                        namespace: "test".to_string(),
                        key: format!("key{}", i),
                        environment: "dev".to_string(),
                    },
                    "user",
                )
                .unwrap();
        }

        // Wait for async processing
        tokio::time::sleep(tokio::time::Duration::from_millis(200)).await;

        let count = logger.count().unwrap();
        assert_eq!(count, 10);
    }

    #[tokio::test]
    async fn test_query_events() {
        let temp_dir = TempDir::new().unwrap();
        let storage = Arc::new(FileAuditStorage::new(temp_dir.path()).unwrap());
        let logger = AuditLogger::new(storage);

        logger
            .log_event(
                AuditEventType::ConfigCreated {
                    namespace: "test".to_string(),
                    key: "key1".to_string(),
                    environment: "dev".to_string(),
                },
                "test-user",
            )
            .unwrap();

        // Wait for async processing
        tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;

        let start = chrono::Utc::now() - chrono::Duration::hours(1);
        let end = chrono::Utc::now() + chrono::Duration::hours(1);

        let events = logger.query(start, end, None).unwrap();
        assert_eq!(events.len(), 1);
    }
}
