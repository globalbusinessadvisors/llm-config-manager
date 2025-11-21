# Contributing to LLM Config Manager

Thank you for your interest in contributing to LLM Config Manager! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Setup](#development-setup)
4. [How to Contribute](#how-to-contribute)
5. [Development Workflow](#development-workflow)
6. [Coding Standards](#coding-standards)
7. [Testing Guidelines](#testing-guidelines)
8. [Documentation](#documentation)
9. [Pull Request Process](#pull-request-process)
10. [Release Process](#release-process)

## Code of Conduct

This project adheres to a Code of Conduct that all contributors are expected to follow. Please read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before contributing.

### Our Pledge

We are committed to providing a welcoming and inspiring community for all. Please be respectful and constructive in your interactions.

## Getting Started

### Prerequisites

- **Rust**: 1.75 or higher
- **Git**: For version control
- **Optional**: Redis (for caching tests)
- **Optional**: PostgreSQL/MySQL (for database backend tests)

### Quick Start

```bash
# Clone the repository
git clone https://github.com/llm-devops/llm-config-manager.git
cd llm-config-manager

# Build the project
cargo build

# Run tests
cargo test --all-features

# Run security scans
./security/scanners/dependency-scanner.sh
./security/scanners/code-scanner.sh
```

## Development Setup

### 1. Fork and Clone

```bash
# Fork the repository on GitHub
# Then clone your fork
git clone https://github.com/YOUR_USERNAME/llm-config-manager.git
cd llm-config-manager

# Add upstream remote
git remote add upstream https://github.com/llm-devops/llm-config-manager.git
```

### 2. Install Development Tools

```bash
# Install Rust toolchain
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install additional tools
cargo install cargo-watch      # Auto-rebuild on changes
cargo install cargo-tarpaulin  # Code coverage
cargo install cargo-audit      # Security auditing
cargo install cargo-outdated   # Check outdated dependencies
```

### 3. Set Up Pre-Commit Hooks

```bash
# Install pre-commit (Python tool)
pip install pre-commit

# Install hooks
pre-commit install
```

### 4. IDE Setup

#### VS Code
Install recommended extensions:
- `rust-analyzer`: Rust language server
- `crates`: Cargo.toml dependency management
- `better-toml`: TOML syntax highlighting
- `error-lens`: Inline error messages

#### IntelliJ IDEA / CLion
Install the Rust plugin from JetBrains.

## How to Contribute

### Types of Contributions

We welcome various types of contributions:

1. **Bug Reports**: Report issues you encounter
2. **Feature Requests**: Suggest new features
3. **Bug Fixes**: Fix reported issues
4. **New Features**: Implement planned or approved features
5. **Documentation**: Improve or add documentation
6. **Tests**: Add or improve test coverage
7. **Performance**: Optimize performance
8. **Security**: Report or fix security issues

### Reporting Bugs

When reporting bugs, please include:

- **Description**: Clear description of the issue
- **Steps to Reproduce**: Detailed steps to reproduce
- **Expected Behavior**: What you expected to happen
- **Actual Behavior**: What actually happened
- **Environment**: OS, Rust version, relevant configuration
- **Logs**: Relevant error messages or logs

Use the bug report template when creating an issue.

### Suggesting Features

When suggesting features:

- **Use Case**: Describe the use case
- **Proposed Solution**: Suggest an implementation approach
- **Alternatives**: Consider alternative approaches
- **Impact**: Estimate impact on existing functionality

Use the feature request template when creating an issue.

### Security Issues

**DO NOT** report security vulnerabilities through public GitHub issues.

Instead, email security@llm-config-manager.io with:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

See [SECURITY.md](SECURITY.md) for details.

## Development Workflow

### 1. Create a Branch

```bash
# Update your fork
git checkout main
git pull upstream main

# Create a feature branch
git checkout -b feature/your-feature-name
# or
git checkout -b fix/issue-number-description
```

Branch naming conventions:
- `feature/feature-name`: New features
- `fix/issue-123-description`: Bug fixes
- `docs/topic`: Documentation updates
- `refactor/component-name`: Code refactoring
- `test/component-name`: Test additions
- `perf/optimization-name`: Performance improvements

### 2. Make Changes

Follow the coding standards (see below) and make your changes.

### 3. Write Tests

All code changes should include tests:

```bash
# Run tests
cargo test

# Run specific test
cargo test test_name

# Run tests with output
cargo test -- --nocapture

# Run tests for specific package
cargo test --package llm-config-core
```

### 4. Run Checks

Before committing, run all checks:

```bash
# Format code
cargo fmt --all

# Lint code
cargo clippy --all-targets --all-features -- -D warnings

# Run tests
cargo test --all-features

# Check security
./security/scanners/dependency-scanner.sh
./security/scanners/code-scanner.sh

# Build documentation
cargo doc --no-deps --all-features
```

### 5. Commit Changes

Follow conventional commits format:

```bash
git commit -m "type(scope): description"
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Test additions or updates
- `chore`: Build process or auxiliary tool changes
- `security`: Security improvements

Examples:
```bash
git commit -m "feat(api): add GraphQL endpoint for configurations"
git commit -m "fix(crypto): resolve key rotation issue"
git commit -m "docs(readme): update installation instructions"
git commit -m "test(cache): add tests for L2 cache invalidation"
```

### 6. Push and Create PR

```bash
# Push to your fork
git push origin feature/your-feature-name

# Create a Pull Request on GitHub
```

## Coding Standards

### Rust Style Guide

Follow the official [Rust Style Guide](https://doc.rust-lang.org/1.0.0/style/):

1. **Formatting**: Use `cargo fmt`
2. **Linting**: Pass `cargo clippy` without warnings
3. **Naming**:
   - `snake_case` for functions, variables, modules
   - `PascalCase` for types, traits
   - `SCREAMING_SNAKE_CASE` for constants
4. **Documentation**: Document all public APIs with `///` comments
5. **Error Handling**: Use `Result` and `?` operator, avoid `unwrap()`

### Code Quality

- **DRY**: Don't Repeat Yourself
- **KISS**: Keep It Simple, Stupid
- **YAGNI**: You Aren't Gonna Need It
- **SOLID**: Follow SOLID principles
- **Clean Code**: Write self-documenting code

### Example Code

```rust
/// Retrieves a configuration value from storage.
///
/// # Arguments
///
/// * `namespace` - The configuration namespace
/// * `key` - The configuration key
/// * `environment` - The target environment
///
/// # Returns
///
/// * `Ok(Some(ConfigEntry))` - Configuration found
/// * `Ok(None)` - Configuration not found
/// * `Err(ConfigError)` - Error occurred
///
/// # Examples
///
/// ```
/// use llm_config_core::{ConfigManager, Environment};
///
/// let manager = ConfigManager::new(".llm-config")?;
/// let entry = manager.get("app", "key", Environment::Production)?;
/// ```
pub fn get(
    &self,
    namespace: &str,
    key: &str,
    environment: Environment,
) -> Result<Option<ConfigEntry>, ConfigError> {
    // Implementation
}
```

## Testing Guidelines

### Test Coverage

Aim for high test coverage:
- **Unit Tests**: Test individual functions and methods
- **Integration Tests**: Test component interactions
- **End-to-End Tests**: Test complete workflows

### Writing Tests

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_existing_config() {
        // Arrange
        let manager = ConfigManager::new_in_memory().unwrap();
        manager.set("ns", "key", "value".into(), Environment::Base, "user").unwrap();

        // Act
        let result = manager.get("ns", "key", Environment::Base).unwrap();

        // Assert
        assert!(result.is_some());
        assert_eq!(result.unwrap().value, ConfigValue::String("value".to_string()));
    }

    #[test]
    fn test_get_nonexistent_config() {
        // Arrange
        let manager = ConfigManager::new_in_memory().unwrap();

        // Act
        let result = manager.get("ns", "key", Environment::Base).unwrap();

        // Assert
        assert!(result.is_none());
    }

    #[test]
    #[should_panic(expected = "Invalid namespace")]
    fn test_invalid_namespace_panics() {
        let manager = ConfigManager::new_in_memory().unwrap();
        manager.set("", "key", "value".into(), Environment::Base, "user").unwrap();
    }
}
```

### Property-Based Testing

Use `proptest` for property-based tests:

```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn test_encrypt_decrypt_roundtrip(plaintext in prop::collection::vec(any::<u8>(), 0..1000)) {
        let engine = CryptoEngine::new(&generate_key());
        let ciphertext = engine.encrypt(&plaintext).unwrap();
        let decrypted = engine.decrypt(&ciphertext).unwrap();
        prop_assert_eq!(plaintext, decrypted);
    }
}
```

### Benchmarking

Use `criterion` for benchmarks:

```rust
use criterion::{black_box, criterion_group, criterion_main, Criterion};

fn bench_encryption(c: &mut Criterion) {
    let engine = CryptoEngine::new(&generate_key());
    let data = vec![0u8; 1024];

    c.bench_function("encrypt_1kb", |b| {
        b.iter(|| engine.encrypt(black_box(&data)))
    });
}

criterion_group!(benches, bench_encryption);
criterion_main!(benches);
```

## Documentation

### Code Documentation

- Document all public APIs
- Include examples in documentation
- Use proper Markdown formatting
- Keep documentation up-to-date

### User Documentation

When adding features, update:
- README.md
- docs/API.md (for API changes)
- docs/ARCHITECTURE.md (for architectural changes)
- CHANGELOG.md

### Documentation Style

```rust
/// Short one-line description.
///
/// Longer description with more details. Can span multiple
/// lines and include examples.
///
/// # Arguments
///
/// * `arg1` - Description of arg1
/// * `arg2` - Description of arg2
///
/// # Returns
///
/// Description of return value
///
/// # Errors
///
/// Description of possible errors
///
/// # Examples
///
/// ```
/// // Example code
/// ```
///
/// # Panics
///
/// Description of panic conditions
///
/// # Safety
///
/// Safety considerations for unsafe code
```

## Pull Request Process

### Before Submitting

- [ ] Code follows project style guidelines
- [ ] All tests pass
- [ ] New tests added for new functionality
- [ ] Documentation updated
- [ ] CHANGELOG.md updated (for notable changes)
- [ ] No new compiler warnings
- [ ] Security scans pass
- [ ] Commits follow conventional commit format

### PR Template

Use the pull request template provided. Include:

1. **Description**: What does this PR do?
2. **Motivation**: Why is this change needed?
3. **Related Issues**: Link to related issues
4. **Testing**: How was this tested?
5. **Screenshots**: If applicable
6. **Checklist**: Completed checklist items

### Review Process

1. **Automated Checks**: CI/CD runs automatically
2. **Code Review**: At least one maintainer reviews
3. **Changes Requested**: Address feedback
4. **Approval**: Maintainer approves
5. **Merge**: Maintainer merges to main

### After Merge

- Delete your branch
- Update your fork
- Close related issues (if applicable)

## Release Process

Releases are managed by maintainers:

1. **Version Bump**: Update version in Cargo.toml files
2. **Changelog**: Update CHANGELOG.md
3. **Tag**: Create git tag (v0.5.0)
4. **Build**: Build release binaries
5. **Publish**: Publish to crates.io
6. **Announce**: Announce release

## Getting Help

- **Documentation**: https://docs.llm-config-manager.io
- **Discussions**: https://github.com/llm-devops/llm-config-manager/discussions
- **Discord**: https://discord.gg/llm-config-manager
- **Email**: dev@llm-config-manager.io

## Recognition

Contributors are recognized in:
- CHANGELOG.md (for significant contributions)
- GitHub contributors list
- Release notes

Thank you for contributing to LLM Config Manager!

---

**Questions?** Feel free to ask in Discussions or Discord.
