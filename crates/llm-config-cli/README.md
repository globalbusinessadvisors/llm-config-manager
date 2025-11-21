# llm-config-cli

[![Crates.io](https://img.shields.io/crates/v/llm-config-cli.svg)](https://crates.io/crates/llm-config-cli)
[![Documentation](https://docs.rs/llm-config-cli/badge.svg)](https://docs.rs/llm-config-cli)
[![License](https://img.shields.io/crates/l/llm-config-cli.svg)](https://github.com/globalbusinessadvisors/llm-config-manager/blob/main/LICENSE)

Command-line interface for LLM Config Manager with interactive prompts, colored output, and comprehensive configuration management.

## Features

- **Interactive Mode**: User-friendly prompts for configuration
- **Colored Output**: Syntax highlighting and status colors
- **Batch Operations**: Import/export configurations in bulk
- **Environment Management**: Switch between environments easily
- **Secret Management**: Secure handling of sensitive values
- **Version Control**: View history and rollback changes
- **Format Support**: JSON, YAML, TOML input/output

## Installation

```bash
cargo install llm-config-cli
```

## Usage

### Set Configuration

```bash
# Set a simple value
llm-config set app.database.url postgres://localhost/mydb --env production

# Set a secret (encrypted)
llm-config set-secret app.api.key my-secret-key --env production
```

### Get Configuration

```bash
# Get a value
llm-config get app.database.url --env production

# Get with JSON output
llm-config get app.database.url --env production --format json
```

### List Configurations

```bash
# List all configurations
llm-config list --env production

# List with pattern
llm-config list app.* --env production
```

### Version Control

```bash
# View history
llm-config history app.database.url

# Rollback to previous version
llm-config rollback app.database.url --version 5
```

### Import/Export

```bash
# Export configurations
llm-config export --env production > config.json

# Import configurations
llm-config import config.json --env staging
```

## Configuration

The CLI stores its configuration in `~/.config/llm-config/config.toml`:

```toml
[default]
environment = "development"
format = "json"
storage_path = "~/.local/share/llm-config"
```

## License

Licensed under the Apache License, Version 2.0.
