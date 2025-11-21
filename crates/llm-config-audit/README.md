# llm-config-audit

[![Crates.io](https://img.shields.io/crates/v/llm-config-audit.svg)](https://crates.io/crates/llm-config-audit)
[![Documentation](https://docs.rs/llm-config-audit/badge.svg)](https://docs.rs/llm-config-audit)
[![License](https://img.shields.io/crates/l/llm-config-audit.svg)](https://github.com/globalbusinessadvisors/llm-config-manager/blob/main/LICENSE)

Comprehensive audit logging system with tamper-proof logs, change tracking, and compliance reporting for LLM Config Manager.

## Features

- **Tamper-Proof Logging**: Cryptographic hashing of audit entries
- **Change Tracking**: Record all configuration changes with before/after values
- **User Attribution**: Track who made what changes when
- **Compliance Reports**: SOC2, HIPAA, ISO27001 audit trails
- **Query Interface**: Search and filter audit logs

## Usage

```toml
[dependencies]
llm-config-audit = "0.5.0"
```

```rust
use llm_config_audit::{AuditLogger, AuditEvent};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let logger = AuditLogger::new()?;

    // Log an event
    logger.log(AuditEvent {
        user_id: "user123",
        action: "UPDATE",
        resource: "app.database.url",
        old_value: Some("old-url"),
        new_value: Some("new-url"),
        timestamp: Utc::now(),
    }).await?;

    // Query audit logs
    let logs = logger.query()
        .user("user123")
        .since(start_date)
        .execute()
        .await?;

    Ok(())
}
```

## License

Licensed under the Apache License, Version 2.0.
