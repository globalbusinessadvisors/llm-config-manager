# llm-config-api

[![Crates.io](https://img.shields.io/crates/v/llm-config-api.svg)](https://crates.io/crates/llm-config-api)
[![Documentation](https://docs.rs/llm-config-api/badge.svg)](https://docs.rs/llm-config-api)
[![License](https://img.shields.io/crates/l/llm-config-api.svg)](https://github.com/globalbusinessadvisors/llm-config-manager/blob/main/LICENSE)

REST API server for LLM Config Manager with JWT authentication, RBAC, rate limiting, and comprehensive security features.

## Features

- **REST API**: Full-featured REST API for configuration management
- **JWT Authentication**: Secure token-based authentication
- **RBAC Integration**: Role-based access control for all endpoints
- **Rate Limiting**: Per-client rate limiting with token bucket
- **CORS Support**: Configurable CORS policies
- **OpenAPI Documentation**: Auto-generated API documentation
- **Health Checks**: Liveness and readiness probes
- **Metrics Export**: Prometheus metrics endpoint

## Usage

```toml
[dependencies]
llm-config-api = "0.5.0"
tokio = { version = "1", features = ["full"] }
```

```rust
use llm_config_api::ApiServer;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let server = ApiServer::builder()
        .bind("0.0.0.0:8080")
        .with_jwt_secret("your-secret-key")
        .build()
        .await?;

    server.run().await?;
    Ok(())
}
```

## API Endpoints

- `POST /api/v1/auth/login` - Authenticate and get JWT token
- `GET /api/v1/config/:key` - Get configuration value
- `PUT /api/v1/config/:key` - Update configuration value
- `DELETE /api/v1/config/:key` - Delete configuration
- `GET /api/v1/config/:key/history` - Get configuration history
- `GET /health` - Health check endpoint
- `GET /metrics` - Prometheus metrics

## Security Features

- JWT-based authentication
- RBAC authorization
- Rate limiting (100 req/min per client)
- Input validation
- Audit logging
- TLS/HTTPS support

## License

Licensed under the Apache License, Version 2.0.
