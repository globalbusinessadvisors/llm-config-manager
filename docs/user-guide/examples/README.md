# Use Cases & Examples

Real-world examples and use cases for LLM Config Manager.

## Available Examples

### 1. [LLM Application Configuration](llm-application.md)
Complete configuration setup for LLM-powered applications including:
- Model selection per environment
- Temperature and parameter tuning
- API key management
- Cost optimization
- Multi-provider setup

### 2. [Feature Flags & Rollouts](feature-flags.md)
Dynamic feature management including:
- Feature toggles
- Gradual rollouts
- A/B testing
- Canary deployments
- Kill switches

### 3. [Multi-Tenant Configuration](multi-tenant.md)
SaaS and multi-tenant scenarios including:
- Tenant-specific settings
- Quota management
- Feature tiers
- Custom branding
- Isolated configurations

### 4. [Microservices Configuration](microservices.md)
Distributed system configuration including:
- Service discovery
- Circuit breaker settings
- Retry policies
- Timeout configuration
- Service mesh integration

### 5. [CI/CD Integration](cicd-integration.md)
DevOps workflow integration including:
- Configuration deployment
- Environment promotion
- Rollback strategies
- Testing configurations
- GitOps workflows

## Quick Examples

### Basic LLM Configuration

```bash
# Set up OpenAI configuration
llm-config set llm/openai model "gpt-4" --env production
llm-config set llm/openai temperature 0.7 --env production
llm-config set llm/openai max_tokens 2000 --env production
llm-config set llm/openai api_key "sk-..." --env production --secret

# Development uses cheaper model
llm-config set llm/openai model "gpt-3.5-turbo" --env development
llm-config set llm/openai temperature 0.9 --env development
```

### Feature Flag

```bash
# Enable new feature in staging
llm-config set features new_chat_ui true --env staging

# Rollout to 10% of production users
llm-config set features new_chat_ui_rollout 0.1 --env production

# Full rollout
llm-config set features new_chat_ui_rollout 1.0 --env production
```

### Multi-Tenant Setup

```bash
# Configure tenant-specific rate limits
llm-config set tenants/acme rate_limit 10000 --env production
llm-config set tenants/startup rate_limit 1000 --env production

# Tenant-specific features
llm-config set tenants/acme features '{"advanced": true, "api_access": true}' --env production
```

## Integration Examples

### Python Application

```python
from llm_config_client import LLMConfigClient
from openai import OpenAI

class ConfiguredLLMApp:
    def __init__(self, env="production"):
        self.config = LLMConfigClient()
        self.env = env
        self.openai = self._setup_openai()

    def _setup_openai(self):
        api_key = self.config.get_config("llm/openai", "api_key", self.env)["value"]
        return OpenAI(api_key=api_key)

    def chat(self, message):
        model = self.config.get_config("llm/openai", "model", self.env)["value"]
        temp = float(self.config.get_config("llm/openai", "temperature", self.env)["value"])

        response = self.openai.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": message}],
            temperature=temp
        )
        return response.choices[0].message.content

# Usage
app = ConfiguredLLMApp(env="production")
response = app.chat("Hello, world!")
```

### Node.js Application

```javascript
const LLMConfigClient = require('./llm-config-client');
const OpenAI = require('openai');

class ConfiguredLLMApp {
  constructor(env = 'production') {
    this.config = new LLMConfigClient();
    this.env = env;
  }

  async initialize() {
    const apiKey = await this.config.getConfig('llm/openai', 'api_key', this.env);
    this.openai = new OpenAI({ apiKey: apiKey.value });
  }

  async chat(message) {
    const model = await this.config.getConfig('llm/openai', 'model', this.env);
    const temp = await this.config.getConfig('llm/openai', 'temperature', this.env);

    const response = await this.openai.chat.completions.create({
      model: model.value,
      messages: [{ role: 'user', content: message }],
      temperature: parseFloat(temp.value)
    });

    return response.choices[0].message.content;
  }
}

// Usage
const app = new ConfiguredLLMApp('production');
await app.initialize();
const response = await app.chat('Hello, world!');
```

## Best Practices

### 1. Use Namespaces Effectively

```bash
# Good: Organized hierarchy
llm-config set app/llm/openai model "gpt-4"
llm-config set app/llm/anthropic model "claude-2"
llm-config set app/database/postgres host "localhost"

# Bad: Flat structure
llm-config set openai_model "gpt-4"
llm-config set anthropic_model "claude-2"
```

### 2. Environment-Specific Values

```bash
# Development: Fast and cheap
llm-config set app/llm model "gpt-3.5-turbo" --env development
llm-config set app/llm temperature 0.9 --env development

# Production: Accurate and controlled
llm-config set app/llm model "gpt-4" --env production
llm-config set app/llm temperature 0.5 --env production
```

### 3. Secret Management

```bash
# Always use --secret flag for sensitive data
llm-config set app/llm api_key "sk-..." --secret --env production
llm-config set app/database password "pwd123" --secret --env production

# Never store secrets in plain text
# BAD: llm-config set app/llm api_key "sk-..." --env production
```

### 4. Version Control

```bash
# Check history before making changes
llm-config history app/llm model --env production

# Make change
llm-config set app/llm model "gpt-4-turbo" --env production

# Rollback if needed
llm-config rollback app/llm model --version 5 --env production
```

### 5. Testing Configurations

```bash
# Test in staging first
llm-config set app/llm model "gpt-4-turbo" --env staging

# Validate
curl http://staging-api.example.com/health

# Promote to production
llm-config set app/llm model "gpt-4-turbo" --env production
```

## Performance Tips

### 1. Use Caching

```python
from functools import lru_cache

class CachedConfig:
    @lru_cache(maxsize=100)
    def get_config(self, namespace, key, env):
        return self.client.get_config(namespace, key, env)
```

### 2. Batch Configuration Loads

```python
# Good: Load all configs at startup
class App:
    def __init__(self):
        self.config = self._load_config()

    def _load_config(self):
        configs = self.client.list_configs("app/llm", "production")
        return {c["key"]: c["value"] for c in configs}

# Bad: Load on every request
def handle_request():
    model = client.get_config("app/llm", "model", "production")  # Slow!
```

### 3. Use Local Caching

```python
import time

class ConfigWithCache:
    def __init__(self, ttl=300):
        self.cache = {}
        self.ttl = ttl

    def get_config(self, namespace, key, env):
        cache_key = f"{namespace}/{key}/{env}"

        if cache_key in self.cache:
            value, timestamp = self.cache[cache_key]
            if time.time() - timestamp < self.ttl:
                return value

        value = self.client.get_config(namespace, key, env)
        self.cache[cache_key] = (value, time.time())
        return value
```

## Security Examples

### 1. Secure API Key Rotation

```bash
# Generate new API key
NEW_KEY="sk-proj-new-key..."

# Store new key with different name
llm-config set app/llm api_key_v2 "$NEW_KEY" --secret --env production

# Update application to use new key
# Deploy and verify

# Remove old key
llm-config delete app/llm api_key --env production
llm-config set app/llm api_key "$NEW_KEY" --secret --env production
llm-config delete app/llm api_key_v2 --env production
```

### 2. RBAC Setup

```bash
# Create read-only user for monitoring
llm-config rbac create-user monitoring --role readonly

# Create developer with limited access
llm-config rbac create-user developer --role developer
llm-config rbac grant developer app/llm read,write

# Admin with full access
llm-config rbac create-user admin --role admin
```

### 3. Audit Logging

```bash
# Enable audit logging
export LLM_CONFIG_AUDIT_ENABLED=true
export LLM_CONFIG_AUDIT_LOG_PATH="/var/log/llm-config/audit.log"

# View audit logs
tail -f /var/log/llm-config/audit.log | jq
```

## Troubleshooting Examples

### Check Configuration

```bash
# Verify configuration is set
llm-config get app/llm model --env production

# List all configurations
llm-config list app/llm --env production

# Check version history
llm-config history app/llm model --env production
```

### Test API Connectivity

```bash
# Health check
curl http://localhost:8080/health

# Test configuration retrieval
curl http://localhost:8080/api/v1/configs/app/llm/model?env=production

# Check with verbose output
curl -v http://localhost:8080/api/v1/configs/app/llm/model?env=production
```

### Debug Issues

```bash
# Enable debug logging
export RUST_LOG=debug
llm-config-server --config config.yaml

# Check server logs
tail -f /var/log/llm-config/app.log

# Validate configuration
llm-config-server --config config.yaml --validate
```

## Next Steps

- Explore detailed examples in individual files
- Review [Integration Guide](../integration.md) for implementation details
- Check [Configuration Guide](../configuration.md) for advanced settings
- See [Troubleshooting Guide](../troubleshooting.md) for common issues
