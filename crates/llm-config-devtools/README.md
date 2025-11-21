# LLM Config Devtools

Enterprise-grade security scanning and development tools for the LLM Config Manager project.

## Features

### Security Scanning

- **Clippy Integration**: Runs cargo clippy with security-focused lints
- **Unsafe Code Detection**: Identifies all unsafe code blocks for review
- **Secret Scanning**: Detects hardcoded secrets (passwords, API keys, tokens)
- **SQL Injection Detection**: Identifies potential SQL injection vulnerabilities

### Report Generation

Multiple output formats supported:

- **JSON**: Machine-readable format for tooling integration
- **YAML**: Human-readable structured format
- **Markdown**: Documentation-friendly format
- **SARIF**: GitHub Security tab integration

## Installation

### As a Cargo Subcommand

```bash
cargo install --path crates/llm-config-devtools
```

### As a Library

Add to your `Cargo.toml`:

```toml
[dependencies]
llm-config-devtools = { path = "../llm-config-devtools" }
```

## Usage

### CLI Usage

#### Security Scan

```bash
# Run full security scan with markdown output
llm-security-scan --output report.md --format markdown

# Generate SARIF for GitHub Security tab
llm-security-scan --output results.sarif --format sarif

# Fail CI if high severity findings are found
llm-security-scan --fail-on-high

# Disable specific scans
llm-security-scan --no-secrets --no-sql
```

#### Dependency Scan

```bash
# Check for vulnerable dependencies
llm-dependency-scan

# Check for outdated dependencies
llm-dependency-scan --check-outdated

# Check for unused dependencies
llm-dependency-scan --check-unused

# Save JSON report
llm-dependency-scan --output report.json
```

### Library Usage

```rust
use llm_config_devtools::security::{SecurityScanner, ScanConfig};
use llm_config_devtools::report::{generate_report, OutputFormat};
use std::path::PathBuf;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Configure scanner
    let config = ScanConfig {
        project_root: PathBuf::from("."),
        scan_clippy: true,
        scan_unsafe: true,
        scan_secrets: true,
        scan_sql: true,
        max_workers: None,
    };

    // Run scan
    let scanner = SecurityScanner::new(config);
    let report = scanner.scan()?;

    // Generate report
    let markdown = generate_report(&report, OutputFormat::Markdown)?;
    println!("{}", markdown);

    // Check for high severity findings
    if report.has_high_severity() {
        eprintln!("High severity findings detected!");
        std::process::exit(1);
    }

    Ok(())
}
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Security Scan

on: [push, pull_request]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
      - name: Run security scan
        run: |
          cargo run --bin llm-security-scan -- \
            --output results.sarif \
            --format sarif \
            --fail-on-high
      - name: Upload SARIF
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: results.sarif
```

## Output Formats

### JSON

```json
{
  "timestamp": "2025-11-21T10:00:00Z",
  "project_root": ".",
  "findings": [
    {
      "severity": "high",
      "category": "unsafe_code",
      "title": "Unsafe code block detected",
      "message": "Found unsafe code block...",
      "file": "src/lib.rs",
      "line": 42
    }
  ],
  "summary": {
    "total": 1,
    "critical": 0,
    "high": 1,
    "medium": 0,
    "low": 0
  }
}
```

### SARIF (GitHub Security)

SARIF format is automatically recognized by GitHub and displayed in the Security tab.

### Markdown

Human-readable report with severity indicators, code snippets, and recommendations.

## Development

### Running Tests

```bash
cargo test --package llm-config-devtools
```

### Running Locally

```bash
# Security scan
cargo run --bin llm-security-scan

# Dependency scan
cargo run --bin llm-dependency-scan
```

## Performance

- **Parallel Scanning**: Uses rayon for parallel processing
- **Incremental**: Only scans source files (skips target/, node_modules/)
- **Fast**: 10-50x faster than shell-based scanners

## License

Apache-2.0

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for details.
