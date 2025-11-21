# Security Integration Guide

**Version**: 1.0.0
**Last Updated**: 2025-11-21
**Status**: Production-Ready

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [API Security Integration](#api-security-integration)
4. [CI/CD Pipeline](#cicd-pipeline)
5. [Configuration](#configuration)
6. [Testing](#testing)
7. [Monitoring](#monitoring)
8. [Troubleshooting](#troubleshooting)

## Overview

The LLM Config Manager has been fully integrated with enterprise-grade security features, providing comprehensive protection against common vulnerabilities and attack vectors. This document describes how security is integrated throughout the system.

### Security Components Integrated

1. **API Security Middleware**: Input validation, rate limiting, policy enforcement
2. **CI/CD Security Pipeline**: Automated security scanning and testing
3. **Security Integration Tests**: Comprehensive test coverage for security features
4. **Security Monitoring**: Real-time security event tracking

## Architecture

### Security Middleware Stack

```
┌─────────────────────────────────────────────┐
│            Client Request                    │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│     Security Context Middleware             │
│  - Extract user ID and IP address           │
│  - Create security context                  │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│     Rate Limiting Middleware                │
│  - Check per-IP and per-user limits         │
│  - Automatic IP banning                     │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│     Policy Enforcement Middleware           │
│  - IP allowlist/blocklist check             │
│  - TLS requirement verification             │
│  - CORS origin validation                   │
│  - Request size limits                      │
│  - Endpoint access control                  │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│     Input Validation Middleware             │
│  - SQL injection detection                  │
│  - XSS prevention                           │
│  - Path traversal detection                 │
│  - Command injection detection              │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│          API Route Handlers                 │
│  - Business logic execution                 │
│  - Data operations                          │
└─────────────────────────────────────────────┘
```

## API Security Integration

### Middleware Components

The API server includes comprehensive security middleware that protects all endpoints:

```rust
use llm_config_api::{create_router, SecurityState, ServerConfig};
use llm_config_core::ConfigManager;
use std::sync::Arc;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Create config manager
    let manager = Arc::new(ConfigManager::new(".llm-config")?);

    // Create server config with security enabled
    let config = ServerConfig {
        host: "0.0.0.0".to_string(),
        port: 8080,
        enable_cors: true,
        enable_security: true,
    };

    // Start server with integrated security
    llm_config_api::serve(manager, config).await
}
```

### Security Middleware Features

#### 1. Rate Limiting

Prevents abuse and DoS attacks:

- **Authenticated users**: 100 requests/second
- **Unauthenticated users**: 10 requests/second
- **Burst handling**: Allows bursts up to 50 requests
- **Automatic banning**: IPs exceeding limits are banned temporarily

Configuration:

```rust
use llm_config_security::{RateLimiter, RateLimitConfig};

let rate_limiter = RateLimiter::new(RateLimitConfig {
    authenticated_rps: 100,
    unauthenticated_rps: 10,
    burst_size: 50,
    window_seconds: 60,
    ban_duration_seconds: 3600,
    ban_threshold: 10,
});
```

#### 2. Input Validation

Detects and blocks malicious input:

- **SQL Injection**: Detects patterns like `UNION SELECT`, `DROP TABLE`
- **XSS**: Blocks `<script>` tags, `javascript:` URLs
- **Path Traversal**: Prevents `../` patterns
- **Command Injection**: Blocks shell metacharacters

All requests are automatically validated before reaching handlers.

#### 3. Policy Enforcement

Implements security policies:

- **IP Blocking**: Allowlist/blocklist specific IPs or ranges
- **TLS Enforcement**: Requires HTTPS connections
- **CORS Policy**: Validates origin headers
- **Request Size Limits**: Prevents large payload attacks (10MB default)
- **Endpoint Access Control**: Pattern-based endpoint filtering
- **MFA Requirements**: Enforces multi-factor authentication for sensitive operations

Configuration:

```rust
use llm_config_security::{PolicyEnforcer, SecurityPolicy};

let policy = SecurityPolicy {
    allowed_ip_ranges: vec!["192.168.0.0/16".to_string()],
    blocked_ips: vec!["10.0.0.1".to_string()],
    require_tls: true,
    min_tls_version: "1.2".to_string(),
    allowed_origins: vec!["https://example.com".to_string()],
    max_request_size: 10 * 1024 * 1024,
    session_timeout: 3600,
    require_mfa: true,
    allowed_endpoints: vec!["/api/*".to_string()],
    blocked_endpoints: vec!["/api/admin/*".to_string()],
    enable_audit: true,
    data_classifications: vec![
        DataClassification::Public,
        DataClassification::Internal,
    ],
};

let enforcer = PolicyEnforcer::new(policy);
```

### Custom Security Configuration

You can customize security settings for your deployment:

```rust
use llm_config_api::SecurityState;
use llm_config_security::{
    InputValidator, PolicyEnforcer, RateLimiter,
    RateLimitConfig, SecurityPolicy,
};

// Create custom rate limiter
let rate_limiter = RateLimiter::new(RateLimitConfig {
    authenticated_rps: 1000,  // Higher limit for enterprise
    unauthenticated_rps: 50,
    burst_size: 100,
    window_seconds: 60,
    ban_duration_seconds: 7200,
    ban_threshold: 15,
});

// Create custom policy
let mut policy = SecurityPolicy::default();
policy.allowed_ip_ranges = vec![
    "10.0.0.0/8".to_string(),
    "172.16.0.0/12".to_string(),
];
policy.max_request_size = 50 * 1024 * 1024; // 50MB

let policy_enforcer = PolicyEnforcer::new(policy);
let input_validator = InputValidator::default();

// Create security state with custom components
let security_state = SecurityState::with_components(
    rate_limiter,
    input_validator,
    policy_enforcer,
);
```

## CI/CD Pipeline

### Automated Security Scanning

The security pipeline runs automatically on:

- **Push to main/develop**: Full security scan
- **Pull requests**: Security validation before merge
- **Daily schedule**: 2 AM UTC for continuous monitoring
- **Manual trigger**: On-demand security scans

### Pipeline Jobs

#### 1. Dependency Scan

Checks for vulnerable dependencies using `cargo-audit`:

```bash
# Run manually
cargo dep-scan                          # Quick scan
cargo dep-scan --check-outdated         # Include outdated deps
cargo dep-scan --fail-on-vulnerabilities # Fail on findings
```

**Checks**:
- Known vulnerabilities in dependencies
- Outdated packages (optional)
- Unused dependencies (optional)
- Security advisories from RustSec

#### 2. Security Code Scan

Static code analysis for security issues:

```bash
# Run manually
cargo sec-scan              # Quick security scan
cargo sec-github            # Generate SARIF for GitHub
cargo sec-full              # Full markdown report
```

**Checks**:
- Clippy security lints
- Unsafe code blocks
- Hardcoded secrets (12 pattern types)
- SQL injection risks
- Multiple output formats: JSON, YAML, Markdown, SARIF

#### 3. Security Tests

Runs comprehensive security test suite:

```bash
# Run security module tests
cargo test --package llm-config-security --all-features

# Run API security integration tests
cargo test --package llm-config-api --test security_integration_tests
```

**Test Coverage**:
- 65+ unit tests in security crate
- 15+ integration tests for API security
- Attack simulation tests
- Edge case validation

#### 4. Secret Scan

Detects accidentally committed secrets using TruffleHog:

- Scans git history
- Identifies API keys, passwords, tokens
- Validates against known patterns

#### 5. Build Check

Verifies security features compile correctly:

```bash
# Build security crate
cargo build --package llm-config-security --all-features

# Build API with security
cargo build --package llm-config-api --all-features
```

### CI/CD Configuration

Located at `.github/workflows/security.yml`, the pipeline:

- Caches dependencies for faster builds
- Generates security reports
- Uploads artifacts for review
- Comments on PRs with security summary
- Retains reports for 30-90 days

## Configuration

### Environment Variables

Configure security features via environment variables:

```bash
# API Server
export API_HOST="0.0.0.0"
export API_PORT="8080"
export ENABLE_SECURITY="true"
export ENABLE_CORS="true"

# Rate Limiting
export RATE_LIMIT_AUTHENTICATED_RPS="100"
export RATE_LIMIT_UNAUTHENTICATED_RPS="10"
export RATE_LIMIT_BURST_SIZE="50"
export RATE_LIMIT_BAN_THRESHOLD="10"

# Policy
export REQUIRE_TLS="true"
export MIN_TLS_VERSION="1.2"
export MAX_REQUEST_SIZE="10485760"  # 10MB
export SESSION_TIMEOUT="3600"        # 1 hour

# Logging
export RUST_LOG="info,llm_config_security=debug"
```

### Configuration Files

Example production configuration:

```toml
# config/production.toml
[server]
host = "0.0.0.0"
port = 8080
enable_security = true
enable_cors = true

[security.rate_limit]
authenticated_rps = 100
unauthenticated_rps = 10
burst_size = 50
ban_threshold = 10

[security.policy]
require_tls = true
min_tls_version = "1.2"
max_request_size = 10485760
session_timeout = 3600

allowed_ip_ranges = [
    "10.0.0.0/8",
    "172.16.0.0/12",
]

blocked_ips = []

allowed_origins = [
    "https://example.com",
    "https://app.example.com",
]
```

## Testing

### Running Security Tests

#### Unit Tests

```bash
# All security module tests
cargo test --package llm-config-security

# Specific module tests
cargo test --package llm-config-security --lib input
cargo test --package llm-config-security --lib rate_limit
cargo test --package llm-config-security --lib crypto
```

#### Integration Tests

```bash
# API security integration tests
cargo test --package llm-config-api --test security_integration_tests

# Specific integration test
cargo test --package llm-config-api --test security_integration_tests test_sql_injection_blocked
```

#### Attack Simulation

```bash
# Run all attack simulation tests
cargo test --package llm-config-api --test security_integration_tests -- injection
cargo test --package llm-config-api --test security_integration_tests -- xss
cargo test --package llm-config-api --test security_integration_tests -- traversal
```

### Manual Testing

Use `curl` to test security features:

```bash
# Test SQL injection blocking
curl -v "http://localhost:8080/api/v1/configs/test/key' OR '1'='1"
# Expected: 400 Bad Request

# Test XSS blocking
curl -v "http://localhost:8080/api/v1/configs/test/<script>alert('xss')</script>"
# Expected: 400 Bad Request

# Test rate limiting (repeat rapidly)
for i in {1..20}; do
  curl "http://localhost:8080/api/v1/configs/test/key"
done
# Expected: Eventually 429 Too Many Requests

# Test large payload blocking
curl -X POST "http://localhost:8080/api/v1/configs/test/key" \
  -H "Content-Length: 20000000" \
  -H "Content-Type: application/json"
# Expected: 413 Payload Too Large

# Test blocked endpoint
curl "http://localhost:8080/api/v1/configs/admin/secret"
# Expected: 403 Forbidden (if configured)
```

## Monitoring

### Security Metrics

Monitor these key security metrics:

1. **Rate Limit Violations**
   - Number of rate limit hits per IP
   - Number of banned IPs
   - Rate limit statistics

2. **Attack Attempts**
   - SQL injection attempts
   - XSS attempts
   - Path traversal attempts
   - Command injection attempts

3. **Policy Violations**
   - Blocked IP access attempts
   - TLS requirement violations
   - CORS policy violations
   - Endpoint access denials

### Logging

Security events are logged with appropriate levels:

```rust
use tracing::{info, warn, error};

// Rate limit exceeded
warn!(
    ip = %ip_address,
    user = %user_id,
    "Rate limit exceeded"
);

// Attack detected
error!(
    ip = %ip_address,
    attack_type = "sql_injection",
    "Attack attempt detected and blocked"
);

// IP banned
warn!(
    ip = %ip_address,
    reason = "Rate limit violations",
    duration_seconds = 3600,
    "IP banned"
);
```

Configure logging:

```bash
# Development
export RUST_LOG="debug,llm_config_security=trace"

# Production
export RUST_LOG="info,llm_config_security=warn"
```

### Alerts

Set up alerts for critical security events:

1. **High Priority**
   - Multiple attack attempts from same IP
   - Successful attacks
   - Security scan failures in CI/CD
   - Dependency vulnerabilities

2. **Medium Priority**
   - Rate limit bans
   - Policy violations
   - Large number of blocked requests

3. **Low Priority**
   - Individual validation failures
   - Normal rate limiting

## Troubleshooting

### Common Issues

#### 1. False Positive Validation Errors

**Symptom**: Legitimate requests are blocked

**Solution**: Adjust input validation rules:

```rust
// Create lenient validator
let mut config = SanitizationConfig::default();
config.strict_mode = false;
let validator = InputValidator::with_config(config);
```

#### 2. Rate Limiting Too Aggressive

**Symptom**: Users hitting rate limits frequently

**Solution**: Increase rate limits:

```rust
let config = RateLimitConfig {
    authenticated_rps: 200,    // Increase from 100
    unauthenticated_rps: 20,   // Increase from 10
    burst_size: 100,           // Increase from 50
    // ...
};
```

#### 3. TLS Requirement Issues

**Symptom**: Requests fail with 426 Upgrade Required

**Solution**: Configure TLS properly or disable for development:

```rust
let mut policy = SecurityPolicy::default();
policy.require_tls = false;  // Development only!
```

#### 4. CORS Issues

**Symptom**: Browser requests blocked by CORS policy

**Solution**: Add allowed origins:

```rust
let mut policy = SecurityPolicy::default();
policy.allowed_origins = vec![
    "https://your-frontend.com".to_string(),
    "https://app.your-domain.com".to_string(),
];
```

### Debug Mode

Enable debug logging for troubleshooting:

```bash
RUST_LOG=debug,llm_config_security=trace cargo run --package llm-config-api
```

### Security Report Analysis

Review security scan reports:

```bash
# View latest dependency scan
cat security/reports/dependency-scan-*.txt

# View latest code scan
cat security/reports/code-security-report-*.md

# View all reports
ls -lht security/reports/
```

## Best Practices

### Development

1. **Always test security features** before deploying
2. **Run security scans locally** before committing
3. **Review security reports** in CI/CD
4. **Keep dependencies updated** to patch vulnerabilities
5. **Never commit secrets** - use environment variables

### Production

1. **Enable all security features** in production
2. **Use strict validation** for production environments
3. **Monitor security metrics** continuously
4. **Set up alerts** for critical security events
5. **Regular security audits** and penetration testing
6. **Keep security documentation updated**

### Security Updates

1. **Monitor RustSec advisories** for new vulnerabilities
2. **Run daily security scans** in CI/CD
3. **Update dependencies** promptly when vulnerabilities are found
4. **Test security updates** thoroughly before deploying
5. **Maintain security changelog** for audit purposes

## Additional Resources

- [Security Guide](./SECURITY.md) - Comprehensive security documentation
- [Security Implementation](./SECURITY-COMPLETE.md) - Implementation details
- [API Documentation](./API.md) - API usage and security
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [RustSec Advisory Database](https://rustsec.org/)

---

**Security Contact**: security@example.com
**Last Review**: 2025-11-21
**Next Review**: 2026-02-21
