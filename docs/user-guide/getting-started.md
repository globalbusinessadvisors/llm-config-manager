# Getting Started with LLM Config Manager

Welcome to LLM Config Manager! This guide will help you get up and running in just 5 minutes.

## Table of Contents

1. [What is LLM Config Manager?](#what-is-llm-config-manager)
2. [Prerequisites](#prerequisites)
3. [Quick Start (5 Minutes)](#quick-start-5-minutes)
4. [Installation Options](#installation-options)
5. [Your First Configuration](#your-first-configuration)
6. [Next Steps](#next-steps)

## What is LLM Config Manager?

LLM Config Manager is an enterprise-grade configuration management system designed specifically for Large Language Model (LLM) applications. It helps you:

- **Securely store** API keys and secrets with military-grade encryption
- **Manage configurations** across multiple environments (dev, staging, production)
- **Track changes** with git-style versioning and rollback capabilities
- **Control access** with role-based permissions
- **Scale easily** with built-in caching and distributed architecture

### Key Benefits

- **Security First**: AES-256-GCM encryption, OWASP compliant
- **Production Ready**: Battle-tested with 200+ tests
- **Fast**: Sub-millisecond latency for cached operations
- **Easy to Use**: Simple CLI, REST API, and library integrations
- **Well Documented**: Comprehensive guides and examples

## Prerequisites

### Minimum Requirements

- **Operating System**: Linux, macOS, or Windows (via WSL2)
- **Memory**: 512MB RAM minimum (2GB recommended)
- **Disk Space**: 100MB free space
- **Network**: Internet access for initial setup

### For Building from Source

- **Rust**: 1.75 or higher ([Install Rust](https://rustup.rs/))
- **Git**: For cloning the repository

### For Docker Installation

- **Docker**: 20.10+ ([Install Docker](https://docs.docker.com/get-docker/))
- **Docker Compose**: 2.0+ (usually included with Docker Desktop)

## Quick Start (5 Minutes)

### Option 1: Docker (Recommended for Beginners)

This is the fastest way to get started:

```bash
# 1. Create a directory for your configuration data
mkdir -p ~/llm-config-data
cd ~/llm-config-data

# 2. Generate an encryption key
docker run --rm llm-devops/llm-config-manager:latest keygen > .encryption-key

# 3. Start the server
docker run -d \
  --name llm-config \
  -p 8080:8080 \
  -v $(pwd):/var/lib/llm-config/data \
  -e LLM_CONFIG_KEY=$(cat .encryption-key) \
  llm-devops/llm-config-manager:latest

# 4. Verify it's running
curl http://localhost:8080/health
```

**Expected output:**
```json
{
  "status": "healthy",
  "version": "0.5.0",
  "uptime": "5s"
}
```

Congratulations! LLM Config Manager is now running on your machine.

### Option 2: From Source

If you prefer building from source:

```bash
# 1. Clone the repository
git clone https://github.com/llm-devops/llm-config-manager.git
cd llm-config-manager

# 2. Build the project
cargo build --release

# 3. Generate encryption key
export LLM_CONFIG_KEY=$(./target/release/llm-config keygen)

# 4. Start the server
./target/release/llm-config-server --host 0.0.0.0 --port 8080
```

**Expected output:**
```
2025-11-21T12:00:00.000Z INFO Starting LLM Config API server on 0.0.0.0:8080
```

## Installation Options

Choose the installation method that best fits your needs:

### 1. Docker (Best for Quick Start)

**Advantages:**
- No compilation required
- Isolated environment
- Easy updates
- Cross-platform

**Installation:**
```bash
docker pull llm-devops/llm-config-manager:latest
```

### 2. Docker Compose (Best for Development)

**Advantages:**
- Complete stack with monitoring
- Includes PostgreSQL and Redis
- Easy multi-service setup
- Production-like environment

**Installation:**
```bash
# Clone repository
git clone https://github.com/llm-devops/llm-config-manager.git
cd llm-config-manager

# Start all services
docker-compose up -d

# Access services:
# - API: http://localhost:8080
# - Grafana: http://localhost:3000 (admin/admin)
# - Prometheus: http://localhost:9091
```

### 3. From Source (Best for Development/Customization)

**Advantages:**
- Full control over build
- Can modify code
- Native performance
- Latest features

**Installation:**
```bash
# Install Rust (if not already installed)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Clone and build
git clone https://github.com/llm-devops/llm-config-manager.git
cd llm-config-manager
cargo build --release

# Binaries are in target/release/:
# - llm-config (CLI tool)
# - llm-config-server (API server)
```

### 4. Kubernetes (Best for Production)

**Advantages:**
- High availability
- Auto-scaling
- Production-grade orchestration
- Easy rollbacks

**Installation:**
```bash
# Using Helm (recommended)
helm repo add llm-config https://charts.llm-config-manager.io
helm install llm-config llm-config/llm-config-manager \
  --set encryptionKey="$(openssl rand -base64 32)" \
  --set replicaCount=3

# Access via LoadBalancer or Ingress
kubectl get service llm-config
```

See the [Deployment Guide](../DEPLOYMENT.md) for detailed production setup instructions.

## Your First Configuration

Now that LLM Config Manager is running, let's store and retrieve your first configuration.

### Step 1: Generate an Encryption Key

If you haven't already, generate an encryption key:

```bash
# For Docker
docker exec llm-config llm-config keygen

# For source installation
./target/release/llm-config keygen
```

**Output:**
```
EQa/CnulhQNT7jEWj5f8TyQN2YnCh2Lp9oIctKAMDdc=
```

Set this as an environment variable:

```bash
export LLM_CONFIG_KEY="EQa/CnulhQNT7jEWj5f8TyQN2YnCh2Lp9oIctKAMDdc="
```

### Step 2: Store Your First Configuration

Let's configure an LLM model:

```bash
# Using CLI
llm-config set app/llm model "gpt-4" --env production

# Or using the REST API
curl -X POST http://localhost:8080/api/v1/configs/app/llm/model \
  -H "Content-Type: application/json" \
  -d '{
    "value": "gpt-4",
    "env": "production",
    "user": "admin"
  }'
```

**Expected output:**
```json
{
  "success": true,
  "message": "Configuration stored successfully",
  "version": 1
}
```

### Step 3: Store a Secret

Now let's store an API key securely:

```bash
# Using CLI (secret flag encrypts the value)
llm-config set app/llm api_key "sk-proj-abc123..." --env production --secret

# Or using the REST API
curl -X POST http://localhost:8080/api/v1/configs/app/llm/api_key \
  -H "Content-Type: application/json" \
  -d '{
    "value": "sk-proj-abc123...",
    "env": "production",
    "user": "admin",
    "is_secret": true
  }'
```

**Note:** Secrets are automatically encrypted using AES-256-GCM before storage.

### Step 4: Retrieve Configurations

Retrieve your stored configurations:

```bash
# Get a specific configuration
llm-config get app/llm model --env production

# Or using REST API
curl http://localhost:8080/api/v1/configs/app/llm/model?env=production
```

**Output:**
```json
{
  "namespace": "app/llm",
  "key": "model",
  "value": "gpt-4",
  "env": "production",
  "version": 1,
  "created_at": "2025-11-21T12:00:00Z",
  "updated_at": "2025-11-21T12:00:00Z"
}
```

### Step 5: List All Configurations

See all configurations in a namespace:

```bash
# Using CLI
llm-config list app/llm --env production

# Or using REST API
curl http://localhost:8080/api/v1/configs/app/llm?env=production
```

**Output:**
```json
{
  "configs": [
    {
      "key": "model",
      "value": "gpt-4",
      "version": 1
    },
    {
      "key": "api_key",
      "value": "[ENCRYPTED]",
      "version": 1
    }
  ],
  "count": 2
}
```

### Step 6: View Version History

See the history of a configuration:

```bash
# Using CLI
llm-config history app/llm model --env production

# Or using REST API
curl http://localhost:8080/api/v1/configs/app/llm/model/history?env=production
```

**Output:**
```json
{
  "history": [
    {
      "version": 1,
      "value": "gpt-4",
      "user": "admin",
      "timestamp": "2025-11-21T12:00:00Z",
      "action": "create"
    }
  ]
}
```

## Next Steps

Congratulations! You've successfully set up LLM Config Manager and created your first configurations.

### Learn More

1. **[Integration Guide](integration.md)** - Integrate with your applications
   - Python, Node.js, Go, and Rust examples
   - Framework-specific integrations
   - SDK usage

2. **[Configuration Guide](configuration.md)** - Advanced configuration options
   - Environment variables
   - Multi-environment setup
   - Best practices

3. **[Use Cases & Examples](examples/)** - Real-world scenarios
   - LLM application configuration
   - Feature flags
   - A/B testing
   - Multi-tenant setups

4. **[Troubleshooting Guide](troubleshooting.md)** - Solve common issues
   - Error messages explained
   - Performance optimization
   - FAQ

### Common Next Steps

#### Set Up Multiple Environments

```bash
# Development environment
llm-config set app/llm model "gpt-3.5-turbo" --env development
llm-config set app/llm temperature 0.9 --env development

# Staging environment
llm-config set app/llm model "gpt-4" --env staging
llm-config set app/llm temperature 0.7 --env staging

# Production environment
llm-config set app/llm model "gpt-4" --env production
llm-config set app/llm temperature 0.5 --env production
```

#### Enable Monitoring

If using Docker Compose, access the monitoring dashboard:

```bash
# Open Grafana
open http://localhost:3000

# Default credentials: admin/admin
```

#### Set Up Backup

```bash
# Export configurations for backup
llm-config export --output backup.yaml

# Import configurations
llm-config import --input backup.yaml
```

#### Configure RBAC

```bash
# Create a read-only user
llm-config rbac create-user reader --role read-only

# Grant specific permissions
llm-config rbac grant reader app/llm read
```

### Get Help

- **Documentation**: Full documentation at [docs/](../)
- **Issues**: Report bugs at [GitHub Issues](https://github.com/llm-devops/llm-config-manager/issues)
- **Discussions**: Join the community at [GitHub Discussions](https://github.com/llm-devops/llm-config-manager/discussions)
- **Discord**: Chat with us on [Discord](https://discord.gg/llm-config-manager)
- **Email**: enterprise@llm-config-manager.io for enterprise support

## Quick Reference

### Essential Commands

```bash
# Key generation
llm-config keygen

# Set configuration
llm-config set <namespace> <key> <value> --env <env>

# Get configuration
llm-config get <namespace> <key> --env <env>

# List configurations
llm-config list <namespace> --env <env>

# View history
llm-config history <namespace> <key> --env <env>

# Rollback to previous version
llm-config rollback <namespace> <key> --version <version> --env <env>

# Export/Import
llm-config export --output backup.yaml
llm-config import --input backup.yaml

# Start server
llm-config-server --host 0.0.0.0 --port 8080
```

### Essential API Endpoints

```bash
# Health check
GET /health

# Get configuration
GET /api/v1/configs/:namespace/:key?env=production

# Set configuration
POST /api/v1/configs/:namespace/:key

# List configurations
GET /api/v1/configs/:namespace?env=production

# Version history
GET /api/v1/configs/:namespace/:key/history?env=production

# Rollback
POST /api/v1/configs/:namespace/:key/rollback/:version?env=production

# Delete configuration
DELETE /api/v1/configs/:namespace/:key?env=production
```

## Troubleshooting

### Common Issues

#### Issue: "Cannot connect to server"

**Solution:**
```bash
# Check if server is running
curl http://localhost:8080/health

# Check Docker logs
docker logs llm-config

# Restart server
docker restart llm-config
```

#### Issue: "Encryption key not set"

**Solution:**
```bash
# Generate and set encryption key
export LLM_CONFIG_KEY=$(llm-config keygen)

# For Docker
docker run -d \
  -e LLM_CONFIG_KEY=$(llm-config keygen) \
  llm-devops/llm-config-manager:latest
```

#### Issue: "Permission denied"

**Solution:**
```bash
# Check file permissions
ls -la ~/.llm-config/

# Fix permissions
chmod 700 ~/.llm-config/
chmod 600 ~/.llm-config/config.db
```

For more troubleshooting help, see the [Troubleshooting Guide](troubleshooting.md).

## Summary

You've learned how to:

- Install LLM Config Manager using Docker or from source
- Generate encryption keys for secure storage
- Store and retrieve configurations
- Store secrets with automatic encryption
- View configuration history
- Access the REST API

Now you're ready to integrate LLM Config Manager into your applications! Continue to the [Integration Guide](integration.md) to learn how to use it in your code.
