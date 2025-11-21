//! Storage backend for LLM Config Manager

pub mod file;
pub mod models;

pub use models::*;

use thiserror::Error;

#[derive(Error, Debug)]
pub enum StorageError {
    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),

    #[error("Serialization error: {0}")]
    SerializationError(String),

    #[error("Not found: {0}")]
    NotFound(String),

    #[error("Already exists: {0}")]
    AlreadyExists(String),

    #[error("Invalid path: {0}")]
    InvalidPath(String),

    #[error("Crypto error: {0}")]
    CryptoError(#[from] llm_config_crypto::CryptoError),
}

pub type Result<T> = std::result::Result<T, StorageError>;
