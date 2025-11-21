# Integration Guide

Learn how to integrate LLM Config Manager into your applications using various programming languages and frameworks.

## Table of Contents

1. [Integration Overview](#integration-overview)
2. [REST API Integration](#rest-api-integration)
3. [Python Integration](#python-integration)
4. [Node.js Integration](#nodejs-integration)
5. [Go Integration](#go-integration)
6. [Rust Integration](#rust-integration)
7. [Framework Integrations](#framework-integrations)
8. [Best Practices](#best-practices)

## Integration Overview

LLM Config Manager can be integrated into your applications in three ways:

1. **REST API**: HTTP-based API for any language
2. **Client Libraries**: Language-specific SDKs (coming soon)
3. **Direct Library**: Rust library for native integration

### Choosing an Integration Method

| Method | Use Case | Pros | Cons |
|--------|----------|------|------|
| **REST API** | Any language, microservices | Universal, language-agnostic | Network overhead |
| **Client Library** | Python, Node.js, Go apps | Type-safe, easier to use | Language-specific |
| **Rust Library** | Rust applications | Native performance, no network | Rust only |

## REST API Integration

The REST API is the most flexible integration method and works with any programming language.

### Base URL

```
http://localhost:8080/api/v1
```

### Authentication

Currently, the API supports basic authentication. JWT-based authentication is planned for future releases.

```bash
# Set authentication header (if enabled)
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:8080/api/v1/configs/app/llm/model?env=production
```

### API Endpoints

#### Get Configuration

```http
GET /api/v1/configs/:namespace/:key?env=:environment
```

**Example:**
```bash
curl http://localhost:8080/api/v1/configs/app/llm/model?env=production
```

**Response:**
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

#### Set Configuration

```http
POST /api/v1/configs/:namespace/:key
Content-Type: application/json

{
  "value": "config-value",
  "env": "production",
  "user": "admin",
  "is_secret": false,
  "description": "Optional description"
}
```

**Example:**
```bash
curl -X POST http://localhost:8080/api/v1/configs/app/llm/model \
  -H "Content-Type: application/json" \
  -d '{
    "value": "gpt-4",
    "env": "production",
    "user": "admin"
  }'
```

#### List Configurations

```http
GET /api/v1/configs/:namespace?env=:environment
```

**Example:**
```bash
curl http://localhost:8080/api/v1/configs/app/llm?env=production
```

#### View History

```http
GET /api/v1/configs/:namespace/:key/history?env=:environment
```

#### Rollback

```http
POST /api/v1/configs/:namespace/:key/rollback/:version?env=:environment
```

#### Delete Configuration

```http
DELETE /api/v1/configs/:namespace/:key?env=:environment
```

### Error Handling

The API returns standard HTTP status codes:

- `200 OK`: Success
- `201 Created`: Configuration created
- `400 Bad Request`: Invalid request
- `404 Not Found`: Configuration not found
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server error

**Error Response Format:**
```json
{
  "error": "Error message",
  "code": "ERROR_CODE",
  "details": "Additional details"
}
```

## Python Integration

### Using Requests Library

```python
import requests
import json
from typing import Optional, Dict, Any

class LLMConfigClient:
    """Client for LLM Config Manager API"""

    def __init__(self, base_url: str = "http://localhost:8080"):
        self.base_url = base_url
        self.api_base = f"{base_url}/api/v1"

    def get_config(self, namespace: str, key: str, env: str = "production") -> Optional[Dict[str, Any]]:
        """Get a configuration value"""
        url = f"{self.api_base}/configs/{namespace}/{key}"
        params = {"env": env}

        try:
            response = requests.get(url, params=params)
            response.raise_for_status()
            return response.json()
        except requests.RequestException as e:
            print(f"Error fetching config: {e}")
            return None

    def set_config(self, namespace: str, key: str, value: Any,
                   env: str = "production", user: str = "system",
                   is_secret: bool = False, description: str = "") -> bool:
        """Set a configuration value"""
        url = f"{self.api_base}/configs/{namespace}/{key}"
        payload = {
            "value": value,
            "env": env,
            "user": user,
            "is_secret": is_secret,
            "description": description
        }

        try:
            response = requests.post(url, json=payload)
            response.raise_for_status()
            return True
        except requests.RequestException as e:
            print(f"Error setting config: {e}")
            return False

    def list_configs(self, namespace: str, env: str = "production") -> list:
        """List all configurations in a namespace"""
        url = f"{self.api_base}/configs/{namespace}"
        params = {"env": env}

        try:
            response = requests.get(url, params=params)
            response.raise_for_status()
            return response.json().get("configs", [])
        except requests.RequestException as e:
            print(f"Error listing configs: {e}")
            return []

    def get_history(self, namespace: str, key: str, env: str = "production") -> list:
        """Get version history for a configuration"""
        url = f"{self.api_base}/configs/{namespace}/{key}/history"
        params = {"env": env}

        try:
            response = requests.get(url, params=params)
            response.raise_for_status()
            return response.json().get("history", [])
        except requests.RequestException as e:
            print(f"Error fetching history: {e}")
            return []

    def rollback(self, namespace: str, key: str, version: int, env: str = "production") -> bool:
        """Rollback to a previous version"""
        url = f"{self.api_base}/configs/{namespace}/{key}/rollback/{version}"
        params = {"env": env}

        try:
            response = requests.post(url, params=params)
            response.raise_for_status()
            return True
        except requests.RequestException as e:
            print(f"Error rolling back: {e}")
            return False

# Usage example
if __name__ == "__main__":
    # Initialize client
    client = LLMConfigClient()

    # Set LLM configuration
    client.set_config("app/llm", "model", "gpt-4", env="production")
    client.set_config("app/llm", "temperature", 0.7, env="production")
    client.set_config("app/llm", "max_tokens", 2000, env="production")

    # Set API key (secret)
    client.set_config("app/llm", "api_key", "sk-proj-...",
                     env="production", is_secret=True)

    # Get configuration
    model_config = client.get_config("app/llm", "model", env="production")
    print(f"Model: {model_config['value']}")

    # List all configurations
    configs = client.list_configs("app/llm", env="production")
    for config in configs:
        print(f"{config['key']}: {config['value']}")
```

### Using with OpenAI SDK

```python
from openai import OpenAI
from llm_config_client import LLMConfigClient

class ConfiguredOpenAI:
    """OpenAI client configured from LLM Config Manager"""

    def __init__(self, env: str = "production"):
        self.config_client = LLMConfigClient()
        self.env = env
        self.client = self._initialize_client()

    def _initialize_client(self) -> OpenAI:
        """Initialize OpenAI client with config from LLM Config Manager"""
        # Get API key from config
        api_key_config = self.config_client.get_config(
            "app/llm", "api_key", env=self.env
        )

        if not api_key_config:
            raise ValueError("API key not found in config")

        return OpenAI(api_key=api_key_config["value"])

    def get_model(self) -> str:
        """Get configured model"""
        model_config = self.config_client.get_config(
            "app/llm", "model", env=self.env
        )
        return model_config["value"] if model_config else "gpt-3.5-turbo"

    def get_temperature(self) -> float:
        """Get configured temperature"""
        temp_config = self.config_client.get_config(
            "app/llm", "temperature", env=self.env
        )
        return float(temp_config["value"]) if temp_config else 0.7

    def chat_completion(self, messages: list) -> str:
        """Create a chat completion with configured settings"""
        response = self.client.chat.completions.create(
            model=self.get_model(),
            messages=messages,
            temperature=self.get_temperature()
        )
        return response.choices[0].message.content

# Usage
client = ConfiguredOpenAI(env="production")
response = client.chat_completion([
    {"role": "user", "content": "Hello, world!"}
])
print(response)
```

### FastAPI Integration

```python
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from llm_config_client import LLMConfigClient

app = FastAPI()
config_client = LLMConfigClient()

class ChatRequest(BaseModel):
    message: str
    env: str = "production"

@app.on_event("startup")
async def startup_event():
    """Initialize configurations on startup"""
    # Load default configurations
    default_configs = {
        "model": "gpt-4",
        "temperature": 0.7,
        "max_tokens": 2000
    }

    for key, value in default_configs.items():
        config_client.set_config("app/llm", key, value)

@app.post("/chat")
async def chat(request: ChatRequest):
    """Chat endpoint using LLM Config Manager"""
    # Get configurations
    model = config_client.get_config("app/llm", "model", env=request.env)
    temp = config_client.get_config("app/llm", "temperature", env=request.env)

    if not model or not temp:
        raise HTTPException(status_code=500, detail="Configuration not found")

    # Use configurations for LLM call
    return {
        "response": f"Using model {model['value']} with temp {temp['value']}",
        "config_version": model["version"]
    }

@app.get("/config/{namespace}/{key}")
async def get_config(namespace: str, key: str, env: str = "production"):
    """Get configuration endpoint"""
    config = config_client.get_config(namespace, key, env=env)
    if not config:
        raise HTTPException(status_code=404, detail="Configuration not found")
    return config
```

## Node.js Integration

### Using Axios

```javascript
const axios = require('axios');

class LLMConfigClient {
  constructor(baseUrl = 'http://localhost:8080') {
    this.baseUrl = baseUrl;
    this.apiBase = `${baseUrl}/api/v1`;
  }

  async getConfig(namespace, key, env = 'production') {
    try {
      const response = await axios.get(
        `${this.apiBase}/configs/${namespace}/${key}`,
        { params: { env } }
      );
      return response.data;
    } catch (error) {
      console.error('Error fetching config:', error.message);
      return null;
    }
  }

  async setConfig(namespace, key, value, options = {}) {
    const {
      env = 'production',
      user = 'system',
      isSecret = false,
      description = ''
    } = options;

    try {
      const response = await axios.post(
        `${this.apiBase}/configs/${namespace}/${key}`,
        { value, env, user, is_secret: isSecret, description }
      );
      return response.data;
    } catch (error) {
      console.error('Error setting config:', error.message);
      return null;
    }
  }

  async listConfigs(namespace, env = 'production') {
    try {
      const response = await axios.get(
        `${this.apiBase}/configs/${namespace}`,
        { params: { env } }
      );
      return response.data.configs || [];
    } catch (error) {
      console.error('Error listing configs:', error.message);
      return [];
    }
  }

  async getHistory(namespace, key, env = 'production') {
    try {
      const response = await axios.get(
        `${this.apiBase}/configs/${namespace}/${key}/history`,
        { params: { env } }
      );
      return response.data.history || [];
    } catch (error) {
      console.error('Error fetching history:', error.message);
      return [];
    }
  }

  async rollback(namespace, key, version, env = 'production') {
    try {
      await axios.post(
        `${this.apiBase}/configs/${namespace}/${key}/rollback/${version}`,
        null,
        { params: { env } }
      );
      return true;
    } catch (error) {
      console.error('Error rolling back:', error.message);
      return false;
    }
  }
}

// Usage example
async function main() {
  const client = new LLMConfigClient();

  // Set configurations
  await client.setConfig('app/llm', 'model', 'gpt-4');
  await client.setConfig('app/llm', 'temperature', 0.7);
  await client.setConfig('app/llm', 'api_key', 'sk-proj-...', {
    isSecret: true
  });

  // Get configuration
  const modelConfig = await client.getConfig('app/llm', 'model');
  console.log('Model:', modelConfig.value);

  // List all configs
  const configs = await client.listConfigs('app/llm');
  configs.forEach(config => {
    console.log(`${config.key}: ${config.value}`);
  });
}

module.exports = LLMConfigClient;
```

### Express.js Integration

```javascript
const express = require('express');
const LLMConfigClient = require('./llm-config-client');

const app = express();
const configClient = new LLMConfigClient();

app.use(express.json());

// Middleware to inject configs
app.use(async (req, res, next) => {
  req.llmConfig = configClient;
  next();
});

// Chat endpoint
app.post('/chat', async (req, res) => {
  const { message, env = 'production' } = req.body;

  // Get configurations
  const model = await req.llmConfig.getConfig('app/llm', 'model', env);
  const temperature = await req.llmConfig.getConfig('app/llm', 'temperature', env);
  const apiKey = await req.llmConfig.getConfig('app/llm', 'api_key', env);

  if (!model || !temperature || !apiKey) {
    return res.status(500).json({ error: 'Configuration not found' });
  }

  // Use configurations for LLM call
  res.json({
    response: `Using model ${model.value} with temperature ${temperature.value}`,
    config_version: model.version
  });
});

// Config management endpoint
app.get('/config/:namespace/:key', async (req, res) => {
  const { namespace, key } = req.params;
  const { env = 'production' } = req.query;

  const config = await req.llmConfig.getConfig(namespace, key, env);
  if (!config) {
    return res.status(404).json({ error: 'Configuration not found' });
  }

  res.json(config);
});

app.listen(3000, () => {
  console.log('Server running on port 3000');
});
```

### TypeScript Integration

```typescript
import axios, { AxiosInstance } from 'axios';

interface ConfigValue {
  namespace: string;
  key: string;
  value: any;
  env: string;
  version: number;
  created_at: string;
  updated_at: string;
}

interface SetConfigOptions {
  env?: string;
  user?: string;
  isSecret?: boolean;
  description?: string;
}

class LLMConfigClient {
  private client: AxiosInstance;

  constructor(baseUrl: string = 'http://localhost:8080') {
    this.client = axios.create({
      baseURL: `${baseUrl}/api/v1`,
      timeout: 5000,
    });
  }

  async getConfig(
    namespace: string,
    key: string,
    env: string = 'production'
  ): Promise<ConfigValue | null> {
    try {
      const response = await this.client.get<ConfigValue>(
        `/configs/${namespace}/${key}`,
        { params: { env } }
      );
      return response.data;
    } catch (error) {
      console.error('Error fetching config:', error);
      return null;
    }
  }

  async setConfig(
    namespace: string,
    key: string,
    value: any,
    options: SetConfigOptions = {}
  ): Promise<boolean> {
    const {
      env = 'production',
      user = 'system',
      isSecret = false,
      description = '',
    } = options;

    try {
      await this.client.post(`/configs/${namespace}/${key}`, {
        value,
        env,
        user,
        is_secret: isSecret,
        description,
      });
      return true;
    } catch (error) {
      console.error('Error setting config:', error);
      return false;
    }
  }

  async listConfigs(
    namespace: string,
    env: string = 'production'
  ): Promise<ConfigValue[]> {
    try {
      const response = await this.client.get<{ configs: ConfigValue[] }>(
        `/configs/${namespace}`,
        { params: { env } }
      );
      return response.data.configs || [];
    } catch (error) {
      console.error('Error listing configs:', error);
      return [];
    }
  }
}

export default LLMConfigClient;
```

## Go Integration

```go
package main

import (
    "bytes"
    "encoding/json"
    "fmt"
    "io"
    "net/http"
    "net/url"
)

// LLMConfigClient is a client for LLM Config Manager API
type LLMConfigClient struct {
    BaseURL string
    Client  *http.Client
}

// ConfigValue represents a configuration value
type ConfigValue struct {
    Namespace string      `json:"namespace"`
    Key       string      `json:"key"`
    Value     interface{} `json:"value"`
    Env       string      `json:"env"`
    Version   int         `json:"version"`
    CreatedAt string      `json:"created_at"`
    UpdatedAt string      `json:"updated_at"`
}

// SetConfigRequest represents a request to set a configuration
type SetConfigRequest struct {
    Value       interface{} `json:"value"`
    Env         string      `json:"env"`
    User        string      `json:"user"`
    IsSecret    bool        `json:"is_secret"`
    Description string      `json:"description,omitempty"`
}

// NewLLMConfigClient creates a new LLM Config Manager client
func NewLLMConfigClient(baseURL string) *LLMConfigClient {
    if baseURL == "" {
        baseURL = "http://localhost:8080"
    }
    return &LLMConfigClient{
        BaseURL: baseURL,
        Client:  &http.Client{},
    }
}

// GetConfig retrieves a configuration value
func (c *LLMConfigClient) GetConfig(namespace, key, env string) (*ConfigValue, error) {
    if env == "" {
        env = "production"
    }

    apiURL := fmt.Sprintf("%s/api/v1/configs/%s/%s", c.BaseURL, namespace, key)
    params := url.Values{}
    params.Add("env", env)

    resp, err := c.Client.Get(apiURL + "?" + params.Encode())
    if err != nil {
        return nil, fmt.Errorf("error fetching config: %w", err)
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
    }

    var config ConfigValue
    if err := json.NewDecoder(resp.Body).Decode(&config); err != nil {
        return nil, fmt.Errorf("error decoding response: %w", err)
    }

    return &config, nil
}

// SetConfig sets a configuration value
func (c *LLMConfigClient) SetConfig(namespace, key string, req SetConfigRequest) error {
    if req.Env == "" {
        req.Env = "production"
    }
    if req.User == "" {
        req.User = "system"
    }

    apiURL := fmt.Sprintf("%s/api/v1/configs/%s/%s", c.BaseURL, namespace, key)

    body, err := json.Marshal(req)
    if err != nil {
        return fmt.Errorf("error marshaling request: %w", err)
    }

    resp, err := c.Client.Post(apiURL, "application/json", bytes.NewBuffer(body))
    if err != nil {
        return fmt.Errorf("error setting config: %w", err)
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
        body, _ := io.ReadAll(resp.Body)
        return fmt.Errorf("unexpected status code: %d, body: %s", resp.StatusCode, string(body))
    }

    return nil
}

// ListConfigs lists all configurations in a namespace
func (c *LLMConfigClient) ListConfigs(namespace, env string) ([]ConfigValue, error) {
    if env == "" {
        env = "production"
    }

    apiURL := fmt.Sprintf("%s/api/v1/configs/%s", c.BaseURL, namespace)
    params := url.Values{}
    params.Add("env", env)

    resp, err := c.Client.Get(apiURL + "?" + params.Encode())
    if err != nil {
        return nil, fmt.Errorf("error listing configs: %w", err)
    }
    defer resp.Body.Close()

    var result struct {
        Configs []ConfigValue `json:"configs"`
    }
    if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
        return nil, fmt.Errorf("error decoding response: %w", err)
    }

    return result.Configs, nil
}

// Usage example
func main() {
    client := NewLLMConfigClient("http://localhost:8080")

    // Set configuration
    err := client.SetConfig("app/llm", "model", SetConfigRequest{
        Value: "gpt-4",
        Env:   "production",
        User:  "admin",
    })
    if err != nil {
        fmt.Printf("Error setting config: %v\n", err)
        return
    }

    // Get configuration
    config, err := client.GetConfig("app/llm", "model", "production")
    if err != nil {
        fmt.Printf("Error getting config: %v\n", err)
        return
    }
    fmt.Printf("Model: %v\n", config.Value)

    // List configurations
    configs, err := client.ListConfigs("app/llm", "production")
    if err != nil {
        fmt.Printf("Error listing configs: %v\n", err)
        return
    }
    for _, cfg := range configs {
        fmt.Printf("%s: %v\n", cfg.Key, cfg.Value)
    }
}
```

## Rust Integration

### Using the Library Directly

```rust
use llm_config_core::{ConfigManager, Environment, ConfigValue};
use std::error::Error;
use std::sync::Arc;

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // Initialize manager
    let manager = Arc::new(ConfigManager::new(".llm-config")?);

    // Set configurations
    manager.set(
        "app/llm",
        "model",
        ConfigValue::String("gpt-4".to_string()),
        Environment::Production,
        "admin",
    )?;

    manager.set(
        "app/llm",
        "temperature",
        ConfigValue::Float(0.7),
        Environment::Production,
        "admin",
    )?;

    // Set secret (encrypted)
    manager.set_secret(
        "app/llm",
        "api_key",
        b"sk-proj-...",
        Environment::Production,
        "admin",
    )?;

    // Get configuration
    if let Some(entry) = manager.get("app/llm", "model", Environment::Production)? {
        println!("Model: {:?}", entry.value);
    }

    // List configurations
    let configs = manager.list("app/llm", Environment::Production)?;
    for config in configs {
        println!("{}: {:?}", config.key, config.value);
    }

    // View history
    let history = manager.history("app/llm", "model", Environment::Production)?;
    for entry in history {
        println!("Version {}: {:?}", entry.version, entry.value);
    }

    // Rollback
    manager.rollback("app/llm", "model", 1, Environment::Production)?;

    Ok(())
}
```

### Using the REST API Client

```rust
use reqwest::{Client, StatusCode};
use serde::{Deserialize, Serialize};
use std::error::Error;

#[derive(Debug, Serialize, Deserialize)]
struct ConfigValue {
    namespace: String,
    key: String,
    value: serde_json::Value,
    env: String,
    version: i32,
}

#[derive(Debug, Serialize)]
struct SetConfigRequest {
    value: serde_json::Value,
    env: String,
    user: String,
    is_secret: bool,
}

struct LLMConfigClient {
    base_url: String,
    client: Client,
}

impl LLMConfigClient {
    fn new(base_url: String) -> Self {
        Self {
            base_url,
            client: Client::new(),
        }
    }

    async fn get_config(
        &self,
        namespace: &str,
        key: &str,
        env: &str,
    ) -> Result<Option<ConfigValue>, Box<dyn Error>> {
        let url = format!(
            "{}/api/v1/configs/{}/{}?env={}",
            self.base_url, namespace, key, env
        );

        let response = self.client.get(&url).send().await?;

        match response.status() {
            StatusCode::OK => Ok(Some(response.json().await?)),
            StatusCode::NOT_FOUND => Ok(None),
            _ => Err(format!("Unexpected status: {}", response.status()).into()),
        }
    }

    async fn set_config(
        &self,
        namespace: &str,
        key: &str,
        value: serde_json::Value,
        env: &str,
        user: &str,
        is_secret: bool,
    ) -> Result<(), Box<dyn Error>> {
        let url = format!("{}/api/v1/configs/{}/{}", self.base_url, namespace, key);

        let request = SetConfigRequest {
            value,
            env: env.to_string(),
            user: user.to_string(),
            is_secret,
        };

        let response = self.client.post(&url).json(&request).send().await?;

        if !response.status().is_success() {
            return Err(format!("Failed to set config: {}", response.status()).into());
        }

        Ok(())
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let client = LLMConfigClient::new("http://localhost:8080".to_string());

    // Set configuration
    client
        .set_config(
            "app/llm",
            "model",
            serde_json::json!("gpt-4"),
            "production",
            "admin",
            false,
        )
        .await?;

    // Get configuration
    if let Some(config) = client.get_config("app/llm", "model", "production").await? {
        println!("Model: {:?}", config.value);
    }

    Ok(())
}
```

## Framework Integrations

### Django Integration

```python
# settings.py
from llm_config_client import LLMConfigClient

# Initialize config client
config_client = LLMConfigClient(
    base_url=os.environ.get('LLM_CONFIG_URL', 'http://localhost:8080')
)

# Load configurations
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'production')

# LLM Settings
LLM_MODEL = config_client.get_config('app/llm', 'model', env=ENVIRONMENT)['value']
LLM_TEMPERATURE = float(config_client.get_config('app/llm', 'temperature', env=ENVIRONMENT)['value'])
LLM_API_KEY = config_client.get_config('app/llm', 'api_key', env=ENVIRONMENT)['value']
```

### Flask Integration

```python
from flask import Flask
from llm_config_client import LLMConfigClient

app = Flask(__name__)
config_client = LLMConfigClient()

@app.before_request
def load_config():
    """Load configuration before each request"""
    g.llm_config = {
        'model': config_client.get_config('app/llm', 'model')['value'],
        'temperature': config_client.get_config('app/llm', 'temperature')['value'],
    }
```

### Next.js Integration

```typescript
// lib/config.ts
import LLMConfigClient from './llm-config-client';

const configClient = new LLMConfigClient(
  process.env.LLM_CONFIG_URL || 'http://localhost:8080'
);

export async function getServerSideProps() {
  const model = await configClient.getConfig('app/llm', 'model', process.env.NODE_ENV);

  return {
    props: {
      model: model?.value || 'gpt-3.5-turbo',
    },
  };
}
```

## Best Practices

### 1. Use Environment Variables for URLs

```bash
export LLM_CONFIG_URL=http://localhost:8080
```

```python
config_client = LLMConfigClient(
    base_url=os.environ.get('LLM_CONFIG_URL', 'http://localhost:8080')
)
```

### 2. Implement Caching

```python
from functools import lru_cache
from datetime import datetime, timedelta

class CachedLLMConfigClient(LLMConfigClient):
    def __init__(self, *args, cache_ttl=300, **kwargs):
        super().__init__(*args, **kwargs)
        self.cache = {}
        self.cache_ttl = cache_ttl

    def get_config(self, namespace, key, env="production"):
        cache_key = f"{namespace}/{key}/{env}"

        # Check cache
        if cache_key in self.cache:
            value, timestamp = self.cache[cache_key]
            if datetime.now() - timestamp < timedelta(seconds=self.cache_ttl):
                return value

        # Fetch from API
        value = super().get_config(namespace, key, env)
        self.cache[cache_key] = (value, datetime.now())
        return value
```

### 3. Handle Errors Gracefully

```python
def get_config_with_fallback(client, namespace, key, env, default):
    """Get config with fallback to default value"""
    try:
        config = client.get_config(namespace, key, env)
        return config['value'] if config else default
    except Exception as e:
        logger.error(f"Error fetching config {namespace}/{key}: {e}")
        return default

# Usage
model = get_config_with_fallback(
    client, 'app/llm', 'model', 'production', 'gpt-3.5-turbo'
)
```

### 4. Use Type Hints

```python
from typing import TypedDict, Optional

class LLMConfig(TypedDict):
    model: str
    temperature: float
    max_tokens: int
    api_key: str

def get_llm_config(env: str = "production") -> Optional[LLMConfig]:
    """Get LLM configuration with type safety"""
    try:
        return {
            'model': client.get_config('app/llm', 'model', env)['value'],
            'temperature': float(client.get_config('app/llm', 'temperature', env)['value']),
            'max_tokens': int(client.get_config('app/llm', 'max_tokens', env)['value']),
            'api_key': client.get_config('app/llm', 'api_key', env)['value'],
        }
    except Exception as e:
        logger.error(f"Error loading LLM config: {e}")
        return None
```

### 5. Implement Retry Logic

```python
import time
from functools import wraps

def retry(max_attempts=3, delay=1, backoff=2):
    """Retry decorator with exponential backoff"""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            attempt = 0
            current_delay = delay

            while attempt < max_attempts:
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    attempt += 1
                    if attempt == max_attempts:
                        raise

                    time.sleep(current_delay)
                    current_delay *= backoff

        return wrapper
    return decorator

class ResilientLLMConfigClient(LLMConfigClient):
    @retry(max_attempts=3, delay=1, backoff=2)
    def get_config(self, *args, **kwargs):
        return super().get_config(*args, **kwargs)
```

### 6. Monitor Configuration Changes

```python
import hashlib
import time

class MonitoredLLMConfigClient(LLMConfigClient):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.config_hashes = {}

    def watch_config(self, namespace, key, env, callback, interval=60):
        """Watch for configuration changes"""
        cache_key = f"{namespace}/{key}/{env}"

        while True:
            config = self.get_config(namespace, key, env)
            if config:
                value_hash = hashlib.md5(
                    str(config['value']).encode()
                ).hexdigest()

                if cache_key in self.config_hashes:
                    if self.config_hashes[cache_key] != value_hash:
                        callback(config)

                self.config_hashes[cache_key] = value_hash

            time.sleep(interval)
```

## Next Steps

- Review [Use Cases & Examples](examples/) for real-world integration scenarios
- Check [Configuration Guide](configuration.md) for advanced configuration options
- See [Troubleshooting Guide](troubleshooting.md) for common integration issues

## Support

For integration help:
- GitHub Discussions: https://github.com/llm-devops/llm-config-manager/discussions
- Discord: https://discord.gg/llm-config-manager
- Email: support@llm-config-manager.io
