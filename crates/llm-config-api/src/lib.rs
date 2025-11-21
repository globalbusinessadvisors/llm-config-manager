//! REST API for LLM Config Manager
//!
//! This crate provides a REST API server for the LLM Config Manager using Axum.
//!
//! ## Features
//! - RESTful API for configuration management
//! - JSON request/response format
//! - CORS support
//! - Graceful shutdown
//! - Health check endpoint
//! - Comprehensive error handling
//!
//! ## Example
//! ```no_run
//! use llm_config_api::{serve, ServerConfig};
//! use llm_config_core::ConfigManager;
//! use std::sync::Arc;
//!
//! #[tokio::main]
//! async fn main() {
//!     let manager = Arc::new(ConfigManager::new(".llm-config").unwrap());
//!     let config = ServerConfig::default();
//!     serve(manager, config).await.unwrap();
//! }
//! ```

pub mod middleware;
pub mod routes;
pub mod server;

pub use middleware::{SecurityResponse, SecurityState};
pub use routes::{ApiError, ApiState, ConfigResponse, ErrorResponse};
pub use server::{create_router, serve, ServerConfig};
