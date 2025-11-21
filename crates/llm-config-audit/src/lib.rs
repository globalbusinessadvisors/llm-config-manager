//! Audit logging infrastructure for LLM Config Manager
//!
//! This module provides comprehensive audit logging capabilities for tracking
//! all configuration changes, access attempts, and system events.

pub mod events;
pub mod logger;
pub mod storage;

pub use events::{AuditEvent, AuditEventType, AuditSeverity};
pub use logger::AuditLogger;
pub use storage::{AuditStorage, FileAuditStorage};

use thiserror::Error;

#[derive(Debug, Error)]
pub enum AuditError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Serialization error: {0}")]
    Serialization(String),

    #[error("Storage error: {0}")]
    Storage(String),

    #[error("Invalid event: {0}")]
    InvalidEvent(String),
}

pub type Result<T> = std::result::Result<T, AuditError>;
