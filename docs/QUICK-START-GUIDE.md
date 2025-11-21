# LLM-Config-Manager: Quick Start Guide

**For:** Development Team
**Date:** 2025-11-21
**Version:** 1.0.0

---

## Getting Started in 5 Minutes

This guide gets you from zero to first commit in 5 minutes.

### Prerequisites

Ensure you have:
- Rust >= 1.75 (stable)
- Git >= 2.30
- Docker >= 20.10 (for integration tests)
- A code editor (VS Code with rust-analyzer recommended)

### 1. Clone and Setup (2 minutes)

```bash
# Clone the repository
git clone https://github.com/your-org/llm-config-manager.git
cd llm-config-manager

# Install Rust toolchain (if not already installed)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# Install development tools
cargo install cargo-watch cargo-audit cargo-flamegraph

# Verify installation
rustc --version  # Should be >= 1.75
cargo --version  # Should be >= 1.75
```

### 2. Project Structure (1 minute)

```
llm-config-manager/
├── Cargo.toml              # Workspace definition
├── crates/
│   ├── core/               # Core library (config management, secrets)
│   ├── api/                # REST/gRPC API server
│   ├── cli/                # CLI tool
│   └── common/             # Shared utilities
├── docs/                   # Documentation
│   ├── IMPLEMENTATION-ROADMAP.md  # Full roadmap
│   ├── EXECUTIVE-SUMMARY.md       # Executive summary
│   └── QUICK-START-GUIDE.md       # This file
├── plans/                  # SPARC planning documents
│   ├── SPECIFICATION.json
│   ├── pseudocode.json
│   ├── architecture-design.json
│   └── REFINEMENT.md
├── tests/                  # Integration tests
│   ├── fixtures/           # Test data
│   └── integration/        # Integration test suites
└── README.md               # Project README
```

### 3. First Build (1 minute)

```bash
# Build the project
cargo build

# Run tests
cargo test

# Run with auto-reload (development)
cargo watch -x run
```

### 4. Your First Contribution (1 minute)

```bash
# Create a feature branch
git checkout -b feature/your-feature-name

# Make your changes
# ... edit code ...

# Run checks
cargo fmt      # Format code
cargo clippy   # Lint code
cargo test     # Run tests

# Commit
git add .
git commit -m "feat: your feature description"

# Push and create PR
git push origin feature/your-feature-name
```

---

## Development Workflow

### Daily Workflow

```bash
# 1. Start your day - pull latest changes
git checkout main
git pull origin main
git checkout -b feature/your-task

# 2. Make changes with live reload
cargo watch -x test

# 3. Before committing - run checks
cargo fmt
cargo clippy
cargo test
cargo audit

# 4. Commit following conventional commits
git commit -m "type: description"
# Types: feat, fix, docs, test, refactor, perf, chore

# 5. Push and create PR
git push origin feature/your-task
```

### Running Specific Tests

```bash
# Run all tests
cargo test

# Run specific test
cargo test test_config_encryption

# Run tests with output
cargo test -- --nocapture

# Run tests in specific package
cargo test -p llm-config-core

# Run integration tests
cargo test --test integration

# Run benchmarks
cargo bench
```

### Development Server

```bash
# Run API server with auto-reload
cargo watch -x 'run --bin api-server'

# Run CLI with arguments
cargo run --bin config-cli -- get myconfig

# Run with debug logging
RUST_LOG=debug cargo run --bin api-server

# Run with release optimizations
cargo run --release --bin api-server
```

---

## Key Commands

### Building

```bash
cargo build                 # Debug build
cargo build --release       # Release build (optimized)
cargo build --all          # Build all workspace crates
cargo clean                # Clean build artifacts
```

### Testing

```bash
cargo test                          # Run all tests
cargo test --all                    # Test all crates
cargo test --lib                    # Test library only
cargo test --doc                    # Test documentation examples
cargo test -- --test-threads=1      # Run tests sequentially
cargo test -- --show-output         # Show println! output
```

### Code Quality

```bash
cargo fmt                   # Format all code
cargo fmt -- --check        # Check formatting (CI)
cargo clippy                # Run linter
cargo clippy -- -D warnings # Fail on warnings (CI)
cargo audit                 # Check for vulnerabilities
```

### Documentation

```bash
cargo doc                   # Build documentation
cargo doc --open            # Build and open in browser
cargo doc --no-deps         # Don't document dependencies
```

### Performance

```bash
cargo bench                 # Run benchmarks
cargo flamegraph            # Generate flamegraph (requires cargo-flamegraph)
```

---

## Coding Standards

### Code Organization

```rust
// 1. Module declaration
mod config;
mod secrets;

// 2. External imports
use std::collections::HashMap;
use tokio::sync::RwLock;

// 3. Internal imports
use crate::config::ConfigManager;
use crate::secrets::SecretsManager;

// 4. Type definitions
pub struct Config { /* ... */ }
pub enum ConfigValue { /* ... */ }

// 5. Implementation
impl Config {
    pub fn new() -> Self { /* ... */ }
}

// 6. Tests
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_config_creation() { /* ... */ }
}
```

### Error Handling

```rust
// Use Result for operations that can fail
pub async fn get_config(&self, key: &str) -> Result<ConfigValue, ConfigError> {
    // Use ? for error propagation
    let value = self.storage.load(key).await?;
    Ok(value)
}

// Define custom error types
#[derive(Debug, thiserror::Error)]
pub enum ConfigError {
    #[error("Configuration not found: {0}")]
    NotFound(String),

    #[error("Invalid configuration: {0}")]
    ValidationError(String),

    #[error("Storage error: {0}")]
    StorageError(#[from] StorageError),
}
```

### Async Code

```rust
// Prefer async/await over manual futures
pub async fn fetch_config(&self, namespace: &str) -> Result<Config> {
    // Use tokio for async runtime
    let data = tokio::fs::read_to_string(&self.path).await?;
    let config = serde_json::from_str(&data)?;
    Ok(config)
}

// Use spawn for concurrent operations
let handle1 = tokio::spawn(async move {
    fetch_config("namespace1").await
});
let handle2 = tokio::spawn(async move {
    fetch_config("namespace2").await
});
let (result1, result2) = tokio::join!(handle1, handle2);
```

### Testing

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_config_parsing() {
        let json = r#"{"key": "value"}"#;
        let config = Config::from_json(json).unwrap();
        assert_eq!(config.get("key"), Some("value"));
    }

    #[tokio::test]
    async fn test_async_fetch() {
        let manager = ConfigManager::new();
        let config = manager.fetch("test").await.unwrap();
        assert!(config.is_valid());
    }

    #[test]
    #[should_panic(expected = "Invalid configuration")]
    fn test_invalid_config() {
        let config = Config::from_json("invalid json").unwrap();
    }
}
```

### Documentation

```rust
/// Manages configuration storage and retrieval.
///
/// # Examples
///
/// ```
/// use llm_config_core::ConfigManager;
///
/// let manager = ConfigManager::new();
/// let config = manager.get("myconfig").await?;
/// ```
pub struct ConfigManager {
    /// The underlying storage backend
    storage: Box<dyn StorageBackend>,

    /// In-memory cache for frequently accessed configs
    cache: Arc<RwLock<HashMap<String, Config>>>,
}

impl ConfigManager {
    /// Creates a new configuration manager.
    ///
    /// # Arguments
    ///
    /// * `storage` - The storage backend to use
    ///
    /// # Returns
    ///
    /// A new `ConfigManager` instance
    pub fn new(storage: Box<dyn StorageBackend>) -> Self {
        Self {
            storage,
            cache: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Retrieves a configuration by namespace.
    ///
    /// # Errors
    ///
    /// Returns `ConfigError::NotFound` if the configuration doesn't exist.
    /// Returns `ConfigError::StorageError` if the storage backend fails.
    pub async fn get(&self, namespace: &str) -> Result<Config, ConfigError> {
        // Implementation
    }
}
```

---

## Common Tasks

### Adding a New Feature

1. **Create branch:**
   ```bash
   git checkout -b feature/my-feature
   ```

2. **Write tests first (TDD):**
   ```rust
   #[test]
   fn test_my_feature() {
       // Arrange
       let input = setup_test_data();

       // Act
       let result = my_feature(input);

       // Assert
       assert_eq!(result, expected);
   }
   ```

3. **Implement feature:**
   ```rust
   pub fn my_feature(input: Input) -> Output {
       // Implementation
   }
   ```

4. **Run tests:**
   ```bash
   cargo test test_my_feature
   ```

5. **Update documentation:**
   - Add doc comments (`///`)
   - Update README if user-facing
   - Add example if applicable

6. **Submit PR:**
   ```bash
   cargo fmt && cargo clippy && cargo test
   git add .
   git commit -m "feat: add my feature"
   git push origin feature/my-feature
   ```

### Fixing a Bug

1. **Reproduce bug with test:**
   ```rust
   #[test]
   #[ignore]  // Remove once fixed
   fn test_bug_reproduction() {
       // Reproduce the bug
       let result = buggy_function(input);
       assert_eq!(result, expected);  // This will fail
   }
   ```

2. **Fix the bug:**
   ```rust
   pub fn buggy_function(input: Input) -> Output {
       // Fixed implementation
   }
   ```

3. **Verify fix:**
   ```bash
   cargo test test_bug_reproduction
   ```

4. **Submit PR:**
   ```bash
   git commit -m "fix: resolve issue with X"
   ```

### Adding a Dependency

1. **Add to Cargo.toml:**
   ```toml
   [dependencies]
   serde = { version = "1.0", features = ["derive"] }
   ```

2. **Update lock file:**
   ```bash
   cargo update -p serde
   ```

3. **Check for vulnerabilities:**
   ```bash
   cargo audit
   ```

4. **Document why added:**
   ```toml
   # Required for JSON serialization of configuration
   serde = { version = "1.0", features = ["derive"] }
   ```

### Running Integration Tests

1. **Start dependencies:**
   ```bash
   docker-compose up -d
   ```

2. **Wait for services:**
   ```bash
   docker-compose ps  # Check all services are "Up"
   ```

3. **Run integration tests:**
   ```bash
   cargo test --test integration
   ```

4. **Clean up:**
   ```bash
   docker-compose down
   ```

---

## Debugging

### Using rust-analyzer in VS Code

1. **Install rust-analyzer extension**

2. **Hover over code** to see types and documentation

3. **Use breakpoints** in the debugger

4. **Launch configuration (`.vscode/launch.json`):**
   ```json
   {
     "version": "0.2.0",
     "configurations": [
       {
         "type": "lldb",
         "request": "launch",
         "name": "Debug unit tests",
         "cargo": {
           "args": ["test", "--no-run", "--lib"],
           "filter": {
             "name": "llm-config-core",
             "kind": "lib"
           }
         },
         "args": [],
         "cwd": "${workspaceFolder}"
       }
     ]
   }
   ```

### Logging

```rust
// Add tracing dependency
use tracing::{debug, info, warn, error};

// In your code
info!("Starting configuration manager");
debug!(namespace = %namespace, "Fetching config");
warn!("Cache miss for namespace: {}", namespace);
error!(error = ?err, "Failed to load config");

// Run with logging
RUST_LOG=debug cargo run
RUST_LOG=llm_config_core=trace cargo run  // Specific crate
```

### Common Issues

**Issue:** `error: linking with cc failed`
```bash
# Solution: Install build tools
# Ubuntu/Debian:
sudo apt-get install build-essential
# macOS:
xcode-select --install
```

**Issue:** `error: package X requires rustc >= 1.XX`
```bash
# Solution: Update Rust
rustup update stable
```

**Issue:** Tests fail with "Too many open files"
```bash
# Solution: Increase file descriptor limit
ulimit -n 4096
```

**Issue:** Slow compilation
```bash
# Solution: Use sccache for caching
cargo install sccache
export RUSTC_WRAPPER=sccache
```

---

## CI/CD Pipeline

### GitHub Actions Workflow

Our CI/CD pipeline runs on every commit:

1. **Lint** (cargo fmt --check, cargo clippy)
2. **Test** (cargo test --all)
3. **Security** (cargo audit)
4. **Build** (cargo build --release)
5. **Integration Tests** (docker-compose up → cargo test --test integration)

**Viewing Results:**
- Go to GitHub Actions tab
- Click on your commit/PR
- View logs for each step

**Common CI Failures:**

| Error | Cause | Fix |
|-------|-------|-----|
| `cargo fmt failed` | Code not formatted | Run `cargo fmt` locally |
| `cargo clippy failed` | Linting warnings | Fix warnings shown in logs |
| `cargo test failed` | Tests failing | Run `cargo test` locally to debug |
| `cargo audit failed` | Vulnerable dependency | Update dependencies or add exception |

---

## Performance Profiling

### CPU Profiling with Flamegraph

```bash
# Install cargo-flamegraph
cargo install flamegraph

# Generate flamegraph
cargo flamegraph --bin api-server

# Open flamegraph.svg in browser
```

### Benchmarking with Criterion

```rust
// benches/config_bench.rs
use criterion::{black_box, criterion_group, criterion_main, Criterion};
use llm_config_core::ConfigManager;

fn bench_config_fetch(c: &mut Criterion) {
    let manager = ConfigManager::new();
    c.bench_function("config_fetch", |b| {
        b.iter(|| manager.get(black_box("test_namespace")))
    });
}

criterion_group!(benches, bench_config_fetch);
criterion_main!(benches);
```

```bash
# Run benchmarks
cargo bench

# View results in target/criterion/report/index.html
```

---

## Resources

### Documentation

- **Full Roadmap:** `/docs/IMPLEMENTATION-ROADMAP.md` (32-week plan)
- **Executive Summary:** `/docs/EXECUTIVE-SUMMARY.md` (high-level overview)
- **Specification:** `/plans/SPECIFICATION.json` (functional requirements)
- **Architecture:** `/plans/architecture-design.json` (system design)
- **Refinement:** `/refinement-strategy.json` (testing strategy)

### External Resources

- **Rust Book:** https://doc.rust-lang.org/book/
- **Rust by Example:** https://doc.rust-lang.org/rust-by-example/
- **Tokio Tutorial:** https://tokio.rs/tokio/tutorial
- **Axum Documentation:** https://docs.rs/axum/latest/axum/
- **Tonic Guide:** https://github.com/hyperium/tonic

### Team Communication

- **Slack:** #llm-config-manager
- **Daily Standup:** 9:00 AM (15 minutes)
- **Sprint Review:** Every 2 weeks (Fridays)
- **Technical Questions:** @tech-lead
- **Security Questions:** @security-lead

---

## Cheat Sheet

### Most Common Commands

```bash
# Development
cargo watch -x test              # Auto-run tests on file change
cargo run --bin cli              # Run CLI
cargo run --bin api-server       # Run API server

# Quality
cargo fmt && cargo clippy && cargo test  # Pre-commit checks

# Testing
cargo test -- --nocapture        # Show println! output
cargo test --test integration    # Run integration tests
cargo bench                      # Run benchmarks

# Debugging
RUST_LOG=debug cargo run         # Run with debug logging
cargo flamegraph                 # Generate CPU flamegraph

# Dependencies
cargo tree                       # Show dependency tree
cargo update                     # Update dependencies
cargo audit                      # Check for vulnerabilities
```

### Keyboard Shortcuts (rust-analyzer in VS Code)

| Shortcut | Action |
|----------|--------|
| `F12` | Go to definition |
| `Shift+F12` | Find all references |
| `Ctrl+Space` | Trigger autocomplete |
| `Ctrl+.` | Quick fix / code actions |
| `F2` | Rename symbol |
| `Ctrl+Shift+O` | Go to symbol in file |
| `Ctrl+P` | Quick open file |

---

## Getting Help

1. **Documentation:** Check `/docs` directory first
2. **Code Examples:** Look in `tests/` and `examples/` directories
3. **Team Slack:** Ask in #llm-config-manager
4. **1-on-1:** Schedule with tech lead for complex issues
5. **Pair Programming:** Reach out for real-time help

**Office Hours:**
- Tech Lead: Tuesdays and Thursdays, 2-3 PM
- Security Lead: Wednesdays, 10-11 AM

---

## Welcome to the Team!

You're now ready to contribute to LLM-Config-Manager. Remember:

- Write tests first (TDD)
- Format and lint before committing
- Ask questions early and often
- Review the SPARC documentation for context
- Have fun building secure, high-performance Rust code!

**Happy coding! 🦀**

---

**Last Updated:** 2025-11-21
**Maintained By:** Development Team
**Questions?** Slack: #llm-config-manager
