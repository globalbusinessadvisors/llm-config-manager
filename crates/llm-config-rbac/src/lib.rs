//! Role-Based Access Control (RBAC) for LLM Config Manager
//!
//! This module provides comprehensive RBAC capabilities including:
//! - Predefined roles (Admin, Editor, Viewer, Auditor)
//! - Fine-grained permissions
//! - Policy enforcement
//! - Role hierarchies

pub mod permissions;
pub mod policy;
pub mod roles;

pub use permissions::{Action, Permission, Resource};
pub use policy::PolicyEnforcer;
pub use roles::{Role, RoleAssignment};

use thiserror::Error;

#[derive(Debug, Error)]
pub enum RbacError {
    #[error("Access denied: {0}")]
    AccessDenied(String),

    #[error("Invalid role: {0}")]
    InvalidRole(String),

    #[error("Invalid permission: {0}")]
    InvalidPermission(String),

    #[error("User not found: {0}")]
    UserNotFound(String),
}

pub type Result<T> = std::result::Result<T, RbacError>;
