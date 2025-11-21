//! Permission definitions

use serde::{Deserialize, Serialize};
use std::fmt;

/// Resource types in the system
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Resource {
    /// Configuration values
    Config,
    /// Secrets (encrypted values)
    Secret,
    /// Version history
    History,
    /// Audit logs
    AuditLog,
    /// System settings
    System,
    /// User management
    Users,
    /// Role management
    Roles,
}

impl fmt::Display for Resource {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Resource::Config => write!(f, "config"),
            Resource::Secret => write!(f, "secret"),
            Resource::History => write!(f, "history"),
            Resource::AuditLog => write!(f, "audit_log"),
            Resource::System => write!(f, "system"),
            Resource::Users => write!(f, "users"),
            Resource::Roles => write!(f, "roles"),
        }
    }
}

/// Actions that can be performed on resources
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Action {
    /// Read/view a resource
    Read,
    /// Create a new resource
    Create,
    /// Update an existing resource
    Update,
    /// Delete a resource
    Delete,
    /// List resources
    List,
    /// Rollback to a previous version
    Rollback,
    /// Export data
    Export,
    /// Import data
    Import,
}

impl fmt::Display for Action {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Action::Read => write!(f, "read"),
            Action::Create => write!(f, "create"),
            Action::Update => write!(f, "update"),
            Action::Delete => write!(f, "delete"),
            Action::List => write!(f, "list"),
            Action::Rollback => write!(f, "rollback"),
            Action::Export => write!(f, "export"),
            Action::Import => write!(f, "import"),
        }
    }
}

/// Permission combining a resource and an action
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct Permission {
    pub resource: Resource,
    pub action: Action,
}

impl Permission {
    /// Create a new permission
    pub fn new(resource: Resource, action: Action) -> Self {
        Self { resource, action }
    }

    /// Check if this permission allows the given resource and action
    pub fn allows(&self, resource: &Resource, action: &Action) -> bool {
        &self.resource == resource && &self.action == action
    }
}

impl fmt::Display for Permission {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}:{}", self.resource, self.action)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_permission_creation() {
        let perm = Permission::new(Resource::Config, Action::Read);
        assert_eq!(perm.resource, Resource::Config);
        assert_eq!(perm.action, Action::Read);
    }

    #[test]
    fn test_permission_allows() {
        let perm = Permission::new(Resource::Config, Action::Read);
        assert!(perm.allows(&Resource::Config, &Action::Read));
        assert!(!perm.allows(&Resource::Config, &Action::Update));
        assert!(!perm.allows(&Resource::Secret, &Action::Read));
    }

    #[test]
    fn test_permission_display() {
        let perm = Permission::new(Resource::Config, Action::Update);
        assert_eq!(perm.to_string(), "config:update");
    }

    #[test]
    fn test_permission_serialization() {
        let perm = Permission::new(Resource::Secret, Action::Create);
        let json = serde_json::to_string(&perm).unwrap();
        let deserialized: Permission = serde_json::from_str(&json).unwrap();
        assert_eq!(perm, deserialized);
    }
}
