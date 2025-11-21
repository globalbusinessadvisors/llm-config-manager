# llm-config-templates

[![Crates.io](https://img.shields.io/crates/v/llm-config-templates.svg)](https://crates.io/crates/llm-config-templates)
[![Documentation](https://docs.rs/llm-config-templates/badge.svg)](https://docs.rs/llm-config-templates)
[![License](https://img.shields.io/crates/l/llm-config-templates.svg)](https://github.com/globalbusinessadvisors/llm-config-manager/blob/main/LICENSE)

Configuration template system with variable substitution, inheritance, and environment-specific overrides for LLM Config Manager.

## Features

- **Variable Substitution**: Use `${VAR}` syntax for dynamic values
- **Template Inheritance**: Extend base templates with overrides
- **Environment-Specific**: Different templates per environment
- **Validation**: Type checking and constraint validation

## Usage

```toml
[dependencies]
llm-config-templates = "0.5.0"
```

```rust
use llm_config_templates::TemplateEngine;

let engine = TemplateEngine::new();

// Define a template
let template = r#"
database_url = "${DB_HOST}:${DB_PORT}/${DB_NAME}"
max_connections = ${MAX_CONNS}
"#;

// Render with variables
let rendered = engine.render(template, &vars)?;
```

## License

Licensed under the Apache License, Version 2.0.
