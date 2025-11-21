# llm-config-rbac

[![Crates.io](https://img.shields.io/crates/v/llm-config-rbac.svg)](https://crates.io/crates/llm-config-rbac)
[![Documentation](https://docs.rs/llm-config-rbac/badge.svg)](https://docs.rs/llm-config-rbac)
[![License](https://img.shields.io/crates/l/llm-config-rbac.svg)](https://github.com/globalbusinessadvisors/llm-config-manager/blob/main/LICENSE)

Role-Based Access Control (RBAC) system with fine-grained permissions, namespace isolation, and policy enforcement for LLM Config Manager.

## Features

- **Fine-Grained Permissions**: Read, write, delete, admin permissions per resource
- **Namespace Isolation**: Scope permissions to specific configuration namespaces
- **Role Management**: Define custom roles with specific permission sets
- **Policy Enforcement**: Automatic policy checks before operations
- **User-Role Assignment**: Flexible user-to-role mappings
- **Audit Trail**: Track all authorization decisions

## Usage

```toml
[dependencies]
llm-config-rbac = "0.5.0"
```

```rust
use llm_config_rbac::{RBACManager, Permission, Role};

// Create RBAC manager
let rbac = RBACManager::new();

// Define roles
rbac.create_role("admin", vec![
    Permission::Read,
    Permission::Write,
    Permission::Delete,
    Permission::Admin,
]);

// Assign role to user
rbac.assign_role("user123", "admin", Some("production"))?;

// Check permissions
if rbac.can_write("user123", "app.database.url", "production") {
    // User has write permission
}
```

## License

Licensed under the Apache License, Version 2.0.
