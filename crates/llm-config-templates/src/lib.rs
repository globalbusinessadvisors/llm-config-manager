//! Configuration templates for LLM Config Manager
//!
//! This module provides template functionality for creating reusable
//! configuration patterns with variable substitution.
//!
//! ## Example
//! ```
//! use llm_config_templates::{Template, TemplateEngine};
//! use std::collections::HashMap;
//!
//! let template_str = "Hello, {{name}}! Your score is {{score}}.";
//! let mut vars = HashMap::new();
//! vars.insert("name".to_string(), "Alice".to_string());
//! vars.insert("score".to_string(), "100".to_string());
//!
//! let engine = TemplateEngine::new();
//! let result = engine.render(template_str, &vars).unwrap();
//! assert_eq!(result, "Hello, Alice! Your score is 100.");
//! ```

pub mod engine;
pub mod parser;
pub mod template;

pub use engine::TemplateEngine;
pub use template::Template;

use thiserror::Error;

#[derive(Debug, Error)]
pub enum TemplateError {
    #[error("Parse error: {0}")]
    ParseError(String),

    #[error("Variable not found: {0}")]
    VariableNotFound(String),

    #[error("Invalid template: {0}")]
    InvalidTemplate(String),

    #[error("Serialization error: {0}")]
    Serialization(String),
}

pub type Result<T> = std::result::Result<T, TemplateError>;
