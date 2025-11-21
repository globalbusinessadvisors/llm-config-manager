# Authentication Guide

> Comprehensive authentication implementation for LLM Config Manager API

## Table of Contents

- [Overview](#overview)
- [Current Implementation](#current-implementation)
- [Production Authentication Methods](#production-authentication-methods)
  - [JWT Tokens](#jwt-tokens)
  - [API Keys](#api-keys)
  - [OAuth 2.0](#oauth-20)
  - [Mutual TLS (mTLS)](#mutual-tls-mtls)
- [Implementation Examples](#implementation-examples)
- [Security Best Practices](#security-best-practices)
- [Migration Guide](#migration-guide)

## Overview

Authentication ensures that only authorized users and services can access the LLM Config Manager API. This guide covers the current development authentication approach and provides comprehensive guidance for implementing production-grade authentication.

### Authentication Flow

```
┌────────────┐          ┌──────────────┐          ┌─────────────┐
│   Client   │          │     API      │          │   Storage   │
└─────┬──────┘          └──────┬───────┘          └──────┬──────┘
      │                        │                         │
      │  1. Request + Auth     │                         │
      ├───────────────────────>│                         │
      │                        │                         │
      │                        │  2. Validate Auth       │
      │                        │  (Check token/key)      │
      │                        │                         │
      │                        │  3. Check Permissions   │
      │                        │                         │
      │                        │  4. Query Config        │
      │                        ├────────────────────────>│
      │                        │                         │
      │                        │  5. Return Data         │
      │                        │<────────────────────────┤
      │                        │                         │
      │  6. Response           │                         │
      │<───────────────────────┤                         │
      │                        │                         │
```

## Current Implementation

The current implementation uses simple header-based authentication suitable for development and testing:

### Headers

```http
Authorization: Bearer <token>
X-User-ID: <user-identifier>
```

### Example Request

```bash
curl http://localhost:8080/api/v1/configs/app/llm/model?env=production \
  -H "Authorization: Bearer dev-token-12345" \
  -H "X-User-ID: admin"
```

### Middleware Implementation

The API extracts the user ID from headers for audit logging:

```rust
// Extract user ID from headers (simplified)
let user_id = headers
    .get("x-user-id")
    .and_then(|v| v.to_str().ok())
    .unwrap_or("anonymous")
    .to_string();

// Create security context
let context = SecurityContext::new(user_id, ip.to_string());
```

### Limitations

**Development Only**: This approach is suitable only for development:
- No token validation
- No expiration checking
- No cryptographic verification
- Not suitable for production use

## Production Authentication Methods

### JWT Tokens

JSON Web Tokens (JWT) are the recommended authentication method for most production deployments.

#### Benefits

- **Stateless**: No server-side session storage required
- **Self-contained**: Tokens include all necessary information
- **Standards-based**: RFC 7519 compliant
- **Scalable**: Works well in distributed systems
- **Flexible**: Supports custom claims and expiration

#### Implementation

**1. Generate JWT Token**

```rust
use jsonwebtoken::{encode, decode, Header, Algorithm, Validation, EncodingKey, DecodingKey};
use serde::{Deserialize, Serialize};
use chrono::{Utc, Duration};

#[derive(Debug, Serialize, Deserialize)]
struct Claims {
    sub: String,        // User ID
    exp: usize,         // Expiration time
    iat: usize,         // Issued at
    roles: Vec<String>, // User roles
}

fn generate_token(user_id: &str, roles: Vec<String>, secret: &[u8]) -> Result<String, Error> {
    let expiration = Utc::now()
        .checked_add_signed(Duration::hours(24))
        .expect("valid timestamp")
        .timestamp() as usize;

    let claims = Claims {
        sub: user_id.to_string(),
        exp: expiration,
        iat: Utc::now().timestamp() as usize,
        roles,
    };

    encode(
        &Header::new(Algorithm::HS256),
        &claims,
        &EncodingKey::from_secret(secret)
    )
}
```

**2. Validate JWT Token**

```rust
fn validate_token(token: &str, secret: &[u8]) -> Result<Claims, Error> {
    let validation = Validation::new(Algorithm::HS256);

    let token_data = decode::<Claims>(
        token,
        &DecodingKey::from_secret(secret),
        &validation
    )?;

    Ok(token_data.claims)
}
```

**3. Middleware Integration**

```rust
use axum::{
    extract::{Request, State},
    http::{HeaderMap, StatusCode},
    middleware::Next,
    response::Response,
};

async fn jwt_auth_middleware(
    State(secret): State<Vec<u8>>,
    headers: HeaderMap,
    mut request: Request,
    next: Next,
) -> Result<Response, StatusCode> {
    // Extract token from Authorization header
    let token = headers
        .get("authorization")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "))
        .ok_or(StatusCode::UNAUTHORIZED)?;

    // Validate token
    let claims = validate_token(token, &secret)
        .map_err(|_| StatusCode::UNAUTHORIZED)?;

    // Store claims in request extensions
    request.extensions_mut().insert(claims);

    Ok(next.run(request).await)
}
```

**4. Client Usage**

```python
import requests
import jwt
import time

# Generate token (typically done by auth service)
payload = {
    'sub': 'admin',
    'exp': int(time.time()) + 86400,  # 24 hours
    'iat': int(time.time()),
    'roles': ['admin', 'config-write']
}
token = jwt.encode(payload, 'your-secret-key', algorithm='HS256')

# Use token in requests
headers = {
    'Authorization': f'Bearer {token}',
    'Content-Type': 'application/json'
}

response = requests.get(
    'http://localhost:8080/api/v1/configs/app/llm/model',
    headers=headers,
    params={'env': 'production'}
)
```

#### Token Structure

```json
{
  "header": {
    "alg": "HS256",
    "typ": "JWT"
  },
  "payload": {
    "sub": "admin",
    "exp": 1705852800,
    "iat": 1705766400,
    "roles": ["admin", "config-write"]
  }
}
```

#### Best Practices

1. **Use Strong Secrets**: Minimum 256 bits (32 bytes)
2. **Set Reasonable Expiration**: 1-24 hours for access tokens
3. **Implement Refresh Tokens**: For long-lived sessions
4. **Use RS256 for Production**: Asymmetric signing for better security
5. **Validate All Claims**: Check exp, iat, iss, aud
6. **Implement Token Revocation**: Maintain a blacklist or use short expiration

---

### API Keys

API keys are simple, suitable for service-to-service authentication.

#### Benefits

- **Simple**: Easy to implement and use
- **No Expiration**: Long-lived credentials
- **Service-Friendly**: Perfect for automated systems
- **Revocable**: Can be invalidated immediately

#### Implementation

**1. Generate API Key**

```rust
use rand::Rng;
use sha2::{Sha256, Digest};

fn generate_api_key() -> (String, String) {
    // Generate random key
    let key: String = rand::thread_rng()
        .sample_iter(&rand::distributions::Alphanumeric)
        .take(32)
        .map(char::from)
        .collect();

    let prefixed_key = format!("llm_config_{}", key);

    // Hash for storage
    let mut hasher = Sha256::new();
    hasher.update(&prefixed_key);
    let hash = format!("{:x}", hasher.finalize());

    (prefixed_key, hash)
}
```

**2. Validate API Key**

```rust
use sha2::{Sha256, Digest};

fn validate_api_key(key: &str, stored_hash: &str) -> bool {
    let mut hasher = Sha256::new();
    hasher.update(key);
    let computed_hash = format!("{:x}", hasher.finalize());

    computed_hash == stored_hash
}
```

**3. Middleware Integration**

```rust
async fn api_key_middleware(
    State(keys_db): State<Arc<HashMap<String, User>>>,
    headers: HeaderMap,
    mut request: Request,
    next: Next,
) -> Result<Response, StatusCode> {
    // Extract API key from header
    let api_key = headers
        .get("x-api-key")
        .and_then(|v| v.to_str().ok())
        .ok_or(StatusCode::UNAUTHORIZED)?;

    // Look up user by API key
    let user = keys_db
        .get(api_key)
        .ok_or(StatusCode::UNAUTHORIZED)?;

    // Store user in request extensions
    request.extensions_mut().insert(user.clone());

    Ok(next.run(request).await)
}
```

**4. Client Usage**

```bash
# Using curl
curl http://localhost:8080/api/v1/configs/app/llm/model?env=production \
  -H "X-API-Key: llm_config_abc123xyz789"

# Using Python
import requests

headers = {
    'X-API-Key': 'llm_config_abc123xyz789'
}

response = requests.get(
    'http://localhost:8080/api/v1/configs/app/llm/model',
    headers=headers,
    params={'env': 'production'}
)
```

#### Best Practices

1. **Use Prefixes**: e.g., `llm_config_` for easy identification
2. **Store Hashes Only**: Never store plain API keys
3. **Implement Key Rotation**: Regular rotation schedule
4. **Monitor Usage**: Track API key usage patterns
5. **Rate Limit Per Key**: Prevent abuse
6. **Audit Key Access**: Log all key usage

---

### OAuth 2.0

OAuth 2.0 provides delegated authentication, ideal for third-party integrations.

#### Grant Types

1. **Authorization Code**: Web applications
2. **Client Credentials**: Service-to-service
3. **Resource Owner Password**: Legacy applications
4. **Refresh Token**: Long-lived sessions

#### Implementation (Client Credentials Flow)

**1. Token Endpoint**

```rust
use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
struct TokenRequest {
    grant_type: String,
    client_id: String,
    client_secret: String,
    scope: Option<String>,
}

#[derive(Serialize)]
struct TokenResponse {
    access_token: String,
    token_type: String,
    expires_in: u64,
    scope: String,
}

async fn token_endpoint(
    Json(req): Json<TokenRequest>,
) -> Result<Json<TokenResponse>, StatusCode> {
    // Validate client credentials
    if !validate_client(&req.client_id, &req.client_secret) {
        return Err(StatusCode::UNAUTHORIZED);
    }

    // Generate access token
    let token = generate_access_token(&req.client_id, req.scope.as_deref())?;

    Ok(Json(TokenResponse {
        access_token: token,
        token_type: "Bearer".to_string(),
        expires_in: 3600,
        scope: req.scope.unwrap_or_default(),
    }))
}
```

**2. Client Usage**

```python
import requests

# Get access token
token_response = requests.post(
    'http://localhost:8080/oauth/token',
    data={
        'grant_type': 'client_credentials',
        'client_id': 'my-app',
        'client_secret': 'secret123',
        'scope': 'config:read config:write'
    }
)
token = token_response.json()['access_token']

# Use token for API requests
headers = {'Authorization': f'Bearer {token}'}
response = requests.get(
    'http://localhost:8080/api/v1/configs/app/llm/model',
    headers=headers,
    params={'env': 'production'}
)
```

#### Best Practices

1. **Use Authorization Code with PKCE**: For public clients
2. **Validate Redirect URIs**: Prevent open redirects
3. **Implement Token Introspection**: For distributed validation
4. **Use Short-Lived Access Tokens**: 5-15 minutes
5. **Implement Refresh Tokens**: For seamless renewal

---

### Mutual TLS (mTLS)

mTLS provides certificate-based authentication for high-security environments.

#### Benefits

- **Strong Authentication**: Based on X.509 certificates
- **Mutual Verification**: Both client and server authenticate
- **No Shared Secrets**: Uses asymmetric cryptography
- **Defense in Depth**: Additional security layer

#### Implementation

**1. Generate Certificates**

```bash
# Generate CA certificate
openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout ca-key.pem -out ca-cert.pem -days 3650 \
  -subj "/CN=LLM Config CA"

# Generate server certificate
openssl req -newkey rsa:4096 -nodes \
  -keyout server-key.pem -out server-req.pem \
  -subj "/CN=localhost"

openssl x509 -req -in server-req.pem -CA ca-cert.pem \
  -CAkey ca-key.pem -CAcreateserial -out server-cert.pem -days 365

# Generate client certificate
openssl req -newkey rsa:4096 -nodes \
  -keyout client-key.pem -out client-req.pem \
  -subj "/CN=client-1"

openssl x509 -req -in client-req.pem -CA ca-cert.pem \
  -CAkey ca-key.pem -CAcreateserial -out client-cert.pem -days 365
```

**2. Server Configuration**

```rust
use axum_server::tls_rustls::RustlsConfig;

async fn start_mtls_server() -> Result<(), Box<dyn std::error::Error>> {
    let config = RustlsConfig::from_pem_file(
        "server-cert.pem",
        "server-key.pem",
    )
    .await?
    .with_client_auth_required("ca-cert.pem")
    .await?;

    let app = create_router();

    let addr = "0.0.0.0:8443".parse()?;

    axum_server::bind_rustls(addr, config)
        .serve(app.into_make_service())
        .await?;

    Ok(())
}
```

**3. Client Usage**

```bash
# Using curl with mTLS
curl https://localhost:8443/api/v1/configs/app/llm/model \
  --cert client-cert.pem \
  --key client-key.pem \
  --cacert ca-cert.pem
```

```python
import requests

# Using Python with mTLS
response = requests.get(
    'https://localhost:8443/api/v1/configs/app/llm/model',
    cert=('client-cert.pem', 'client-key.pem'),
    verify='ca-cert.pem',
    params={'env': 'production'}
)
```

#### Best Practices

1. **Use Strong Key Sizes**: Minimum 2048 bits (4096 recommended)
2. **Implement Certificate Revocation**: CRL or OCSP
3. **Short Certificate Lifetimes**: 90 days or less
4. **Automated Rotation**: Use tools like cert-manager
5. **Monitor Expiration**: Alert before certificates expire

---

## Implementation Examples

### Complete JWT Example

```rust
use axum::{
    extract::State,
    http::{HeaderMap, StatusCode},
    middleware::Next,
    response::{IntoResponse, Response},
    routing::get,
    Extension, Json, Router,
};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};
use std::sync::Arc;

#[derive(Debug, Clone, Serialize, Deserialize)]
struct Claims {
    sub: String,
    exp: usize,
    roles: Vec<String>,
}

#[derive(Clone)]
struct AuthState {
    secret: Vec<u8>,
}

async fn jwt_middleware(
    State(state): State<Arc<AuthState>>,
    headers: HeaderMap,
    mut request: axum::extract::Request,
    next: Next,
) -> Result<Response, StatusCode> {
    let token = headers
        .get("authorization")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "))
        .ok_or(StatusCode::UNAUTHORIZED)?;

    let claims = decode::<Claims>(
        token,
        &DecodingKey::from_secret(&state.secret),
        &Validation::default(),
    )
    .map_err(|_| StatusCode::UNAUTHORIZED)?
    .claims;

    request.extensions_mut().insert(claims);
    Ok(next.run(request).await)
}

async fn protected_handler(
    Extension(claims): Extension<Claims>,
) -> impl IntoResponse {
    Json(serde_json::json!({
        "message": "Success",
        "user": claims.sub,
        "roles": claims.roles
    }))
}

fn create_app() -> Router {
    let auth_state = Arc::new(AuthState {
        secret: b"your-secret-key".to_vec(),
    });

    Router::new()
        .route("/api/v1/configs/:namespace/:key", get(protected_handler))
        .layer(axum::middleware::from_fn_with_state(
            auth_state.clone(),
            jwt_middleware,
        ))
        .with_state(auth_state)
}
```

### Multi-Authentication Support

```rust
enum AuthMethod {
    JWT(Claims),
    ApiKey(String),
    MTls(String),
}

async fn multi_auth_middleware(
    headers: HeaderMap,
    request: axum::extract::Request,
    next: Next,
) -> Result<Response, StatusCode> {
    let auth_method = if let Some(bearer) = headers
        .get("authorization")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "))
    {
        // Try JWT
        validate_jwt(bearer)
            .map(AuthMethod::JWT)
            .ok()
    } else if let Some(api_key) = headers
        .get("x-api-key")
        .and_then(|v| v.to_str().ok())
    {
        // Try API key
        validate_api_key(api_key)
            .map(|user| AuthMethod::ApiKey(user))
            .ok()
    } else {
        None
    }
    .ok_or(StatusCode::UNAUTHORIZED)?;

    request.extensions_mut().insert(auth_method);
    Ok(next.run(request).await)
}
```

## Security Best Practices

### 1. Always Use HTTPS in Production

```rust
// Redirect HTTP to HTTPS
async fn https_redirect(uri: Uri) -> Redirect {
    let https_uri = format!("https://{}{}", "your-domain.com", uri.path());
    Redirect::permanent(&https_uri)
}
```

### 2. Implement Token Rotation

```python
class TokenManager:
    def __init__(self):
        self.access_token = None
        self.refresh_token = None
        self.expires_at = None

    def get_token(self):
        if self.expires_at and time.time() >= self.expires_at:
            self.refresh()
        return self.access_token

    def refresh(self):
        response = requests.post(
            'https://auth.example.com/refresh',
            json={'refresh_token': self.refresh_token}
        )
        data = response.json()
        self.access_token = data['access_token']
        self.expires_at = time.time() + data['expires_in']
```

### 3. Rate Limit Per User

```rust
// Track rate limits per user, not just per IP
let user_id = claims.sub.clone();
rate_limiter.check_user_limit(&user_id)?;
```

### 4. Audit All Authentication Events

```rust
audit_log.record(AuditEvent {
    event_type: "authentication",
    user_id: claims.sub.clone(),
    ip_address: client_ip,
    timestamp: Utc::now(),
    success: true,
    metadata: json!({
        "method": "jwt",
        "roles": claims.roles
    }),
});
```

### 5. Implement Account Lockout

```rust
if failed_attempts >= 5 {
    lock_account(&user_id, Duration::minutes(15));
    return Err(SecurityError::AccountLocked);
}
```

### 6. Use Security Headers

```rust
use tower_http::set_header::SetResponseHeaderLayer;

app.layer(SetResponseHeaderLayer::overriding(
    header::STRICT_TRANSPORT_SECURITY,
    HeaderValue::from_static("max-age=31536000; includeSubDomains"),
))
.layer(SetResponseHeaderLayer::overriding(
    header::X_CONTENT_TYPE_OPTIONS,
    HeaderValue::from_static("nosniff"),
))
.layer(SetResponseHeaderLayer::overriding(
    header::X_FRAME_OPTIONS,
    HeaderValue::from_static("DENY"),
))
```

## Migration Guide

### From Development to JWT

**Step 1**: Add JWT dependency

```toml
[dependencies]
jsonwebtoken = "9.2"
```

**Step 2**: Implement JWT middleware

```rust
// See JWT implementation example above
```

**Step 3**: Update clients

```python
# Old (development)
headers = {
    'Authorization': 'Bearer dev-token',
    'X-User-ID': 'admin'
}

# New (JWT)
token = get_jwt_token('admin', 'secret')
headers = {
    'Authorization': f'Bearer {token}'
}
```

**Step 4**: Deploy with feature flag

```rust
let app = if config.use_jwt_auth {
    app.layer(jwt_middleware)
} else {
    app.layer(dev_auth_middleware)
};
```

**Step 5**: Monitor and validate

- Check authentication success rates
- Monitor token validation errors
- Verify audit logs

**Step 6**: Remove development auth

```rust
// Remove old middleware after successful migration
```

## Additional Resources

- [RFC 7519 - JWT](https://tools.ietf.org/html/rfc7519)
- [RFC 6749 - OAuth 2.0](https://tools.ietf.org/html/rfc6749)
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [OpenAPI Security Specification](openapi.yaml)
- [Error Handling Guide](errors.md)
- [Rate Limiting Guide](rate-limits.md)

---

**Version**: 0.5.0 | **Last Updated**: 2024-01-21
