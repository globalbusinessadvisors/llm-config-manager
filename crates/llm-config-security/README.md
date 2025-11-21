# llm-config-security

[![Crates.io](https://img.shields.io/crates/v/llm-config-security.svg)](https://crates.io/crates/llm-config-security)
[![Documentation](https://docs.rs/llm-config-security/badge.svg)](https://docs.rs/llm-config-security)
[![License](https://img.shields.io/crates/l/llm-config-security.svg)](https://github.com/globalbusinessadvisors/llm-config-manager/blob/main/LICENSE)

Security hardening and validation for LLM Config Manager with input validation, rate limiting, and threat protection.

## Features

- **Input Validation**: Comprehensive validation of user inputs
- **Rate Limiting**: Token bucket algorithm for API protection
- **SQL Injection Prevention**: Detection and blocking of SQL injection attempts
- **XSS Protection**: HTML/JavaScript sanitization
- **CSRF Protection**: Token-based CSRF prevention
- **Password Policies**: Configurable password strength requirements
- **Secret Detection**: Prevent accidental secret exposure

## Usage

```toml
[dependencies]
llm-config-security = "0.5.0"
```

```rust
use llm_config_security::{Validator, RateLimiter};

// Input validation
let validator = Validator::new();
validator.validate_key("app.database.url")?;
validator.validate_value("SELECT * FROM users")?;

// Rate limiting
let limiter = RateLimiter::new(100, Duration::from_secs(60));
if limiter.check_rate_limit(&client_id).await? {
    // Allow request
}
```

## Security Features

- OWASP Top 10 protections
- Constant-time comparisons
- Secure random generation
- Automatic secret redaction
- Security headers enforcement

## License

Licensed under the Apache License, Version 2.0.
