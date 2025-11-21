# LLM Application Configuration

Complete guide for configuring LLM-powered applications using LLM Config Manager.

## Table of Contents

1. [Basic Setup](#basic-setup)
2. [Multi-Provider Configuration](#multi-provider-configuration)
3. [Environment-Specific Settings](#environment-specific-settings)
4. [Cost Optimization](#cost-optimization)
5. [Performance Tuning](#performance-tuning)
6. [Advanced Patterns](#advanced-patterns)

## Basic Setup

### Single Provider (OpenAI)

```bash
# Production configuration
llm-config set llm/openai model "gpt-4" --env production
llm-config set llm/openai temperature 0.7 --env production
llm-config set llm/openai max_tokens 2000 --env production
llm-config set llm/openai top_p 0.9 --env production
llm-config set llm/openai frequency_penalty 0.0 --env production
llm-config set llm/openai presence_penalty 0.0 --env production
llm-config set llm/openai api_key "sk-proj-..." --env production --secret

# Development configuration (cheaper model)
llm-config set llm/openai model "gpt-3.5-turbo" --env development
llm-config set llm/openai temperature 0.9 --env development
llm-config set llm/openai max_tokens 1000 --env development
```

### Python Implementation

```python
from llm_config_client import LLMConfigClient
from openai import OpenAI
from typing import Dict, Any

class LLMApplication:
    """LLM application with configuration management"""

    def __init__(self, env: str = "production"):
        self.config_client = LLMConfigClient()
        self.env = env
        self.config = self._load_config()
        self.openai_client = self._initialize_openai()

    def _load_config(self) -> Dict[str, Any]:
        """Load all LLM configurations"""
        configs = self.config_client.list_configs("llm/openai", env=self.env)
        return {c["key"]: c["value"] for c in configs}

    def _initialize_openai(self) -> OpenAI:
        """Initialize OpenAI client with configured API key"""
        api_key = self.config_client.get_config(
            "llm/openai", "api_key", env=self.env
        )
        return OpenAI(api_key=api_key["value"])

    def chat_completion(self, messages: list, **kwargs) -> str:
        """Create chat completion with configured settings"""
        # Use configured defaults, allow overrides
        params = {
            "model": self.config.get("model", "gpt-3.5-turbo"),
            "temperature": float(self.config.get("temperature", 0.7)),
            "max_tokens": int(self.config.get("max_tokens", 2000)),
            "top_p": float(self.config.get("top_p", 0.9)),
            "frequency_penalty": float(self.config.get("frequency_penalty", 0.0)),
            "presence_penalty": float(self.config.get("presence_penalty", 0.0)),
        }
        params.update(kwargs)  # Allow runtime overrides

        response = self.openai_client.chat.completions.create(
            messages=messages,
            **params
        )

        return response.choices[0].message.content

    def reload_config(self):
        """Reload configuration (for hot reload support)"""
        self.config = self._load_config()

# Usage
app = LLMApplication(env="production")

# Simple chat
response = app.chat_completion([
    {"role": "user", "content": "Hello, world!"}
])

# With overrides
response = app.chat_completion(
    messages=[{"role": "user", "content": "Be creative!"}],
    temperature=0.9,  # Override configured temperature
    max_tokens=3000    # Override configured max_tokens
)
```

## Multi-Provider Configuration

### Configure Multiple Providers

```bash
# OpenAI
llm-config set llm/openai model "gpt-4" --env production
llm-config set llm/openai api_key "sk-..." --env production --secret
llm-config set llm/openai base_url "https://api.openai.com/v1" --env production

# Anthropic
llm-config set llm/anthropic model "claude-3-opus-20240229" --env production
llm-config set llm/anthropic api_key "sk-ant-..." --env production --secret
llm-config set llm/anthropic base_url "https://api.anthropic.com" --env production

# Google AI
llm-config set llm/google model "gemini-pro" --env production
llm-config set llm/google api_key "AIza..." --env production --secret

# Provider selection
llm-config set llm/default_provider "openai" --env production
```

### Python Implementation with Provider Abstraction

```python
from abc import ABC, abstractmethod
from typing import List, Dict
from llm_config_client import LLMConfigClient

class LLMProvider(ABC):
    """Abstract base class for LLM providers"""

    @abstractmethod
    def chat_completion(self, messages: List[Dict], **kwargs) -> str:
        pass

class OpenAIProvider(LLMProvider):
    """OpenAI provider implementation"""

    def __init__(self, config: Dict):
        from openai import OpenAI
        self.config = config
        self.client = OpenAI(api_key=config["api_key"])

    def chat_completion(self, messages: List[Dict], **kwargs) -> str:
        params = {
            "model": self.config.get("model", "gpt-4"),
            "temperature": float(self.config.get("temperature", 0.7)),
            "max_tokens": int(self.config.get("max_tokens", 2000)),
        }
        params.update(kwargs)

        response = self.client.chat.completions.create(
            messages=messages,
            **params
        )
        return response.choices[0].message.content

class AnthropicProvider(LLMProvider):
    """Anthropic provider implementation"""

    def __init__(self, config: Dict):
        from anthropic import Anthropic
        self.config = config
        self.client = Anthropic(api_key=config["api_key"])

    def chat_completion(self, messages: List[Dict], **kwargs) -> str:
        params = {
            "model": self.config.get("model", "claude-3-opus-20240229"),
            "max_tokens": int(self.config.get("max_tokens", 2000)),
        }
        params.update(kwargs)

        # Convert OpenAI-style messages to Anthropic format
        system_messages = [m["content"] for m in messages if m["role"] == "system"]
        user_messages = [m for m in messages if m["role"] != "system"]

        response = self.client.messages.create(
            system=system_messages[0] if system_messages else "",
            messages=user_messages,
            **params
        )
        return response.content[0].text

class MultiProviderLLM:
    """Multi-provider LLM with configuration management"""

    def __init__(self, env: str = "production"):
        self.config_client = LLMConfigClient()
        self.env = env
        self.providers = self._initialize_providers()
        self.default_provider = self._get_default_provider()

    def _initialize_providers(self) -> Dict[str, LLMProvider]:
        """Initialize all configured providers"""
        providers = {}

        # Initialize OpenAI
        openai_config = self._load_provider_config("openai")
        if openai_config:
            providers["openai"] = OpenAIProvider(openai_config)

        # Initialize Anthropic
        anthropic_config = self._load_provider_config("anthropic")
        if anthropic_config:
            providers["anthropic"] = AnthropicProvider(anthropic_config)

        return providers

    def _load_provider_config(self, provider: str) -> Dict:
        """Load configuration for a specific provider"""
        configs = self.config_client.list_configs(f"llm/{provider}", env=self.env)
        return {c["key"]: c["value"] for c in configs}

    def _get_default_provider(self) -> str:
        """Get the default provider from config"""
        config = self.config_client.get_config("llm", "default_provider", env=self.env)
        return config["value"] if config else "openai"

    def chat_completion(self, messages: List[Dict], provider: str = None, **kwargs) -> str:
        """Create chat completion using specified or default provider"""
        provider = provider or self.default_provider

        if provider not in self.providers:
            raise ValueError(f"Provider {provider} not configured")

        return self.providers[provider].chat_completion(messages, **kwargs)

    def switch_provider(self, provider: str):
        """Switch default provider"""
        if provider not in self.providers:
            raise ValueError(f"Provider {provider} not available")

        self.config_client.set_config(
            "llm", "default_provider", provider, env=self.env
        )
        self.default_provider = provider

# Usage
llm = MultiProviderLLM(env="production")

# Use default provider (OpenAI)
response = llm.chat_completion([
    {"role": "user", "content": "Hello!"}
])

# Use specific provider
response = llm.chat_completion(
    messages=[{"role": "user", "content": "Hello!"}],
    provider="anthropic"
)

# Switch default provider
llm.switch_provider("anthropic")
```

## Environment-Specific Settings

### Configure Per Environment

```bash
# Development: Fast and cheap
llm-config set llm/openai model "gpt-3.5-turbo" --env development
llm-config set llm/openai temperature 0.9 --env development
llm-config set llm/openai max_tokens 1000 --env development
llm-config set llm/openai timeout 30 --env development

# Staging: Production-like for testing
llm-config set llm/openai model "gpt-4" --env staging
llm-config set llm/openai temperature 0.7 --env staging
llm-config set llm/openai max_tokens 2000 --env staging
llm-config set llm/openai timeout 60 --env staging

# Production: Optimized for quality
llm-config set llm/openai model "gpt-4" --env production
llm-config set llm/openai temperature 0.5 --env production
llm-config set llm/openai max_tokens 2000 --env production
llm-config set llm/openai timeout 120 --env production

# Edge: Optimized for speed
llm-config set llm/openai model "gpt-3.5-turbo" --env edge
llm-config set llm/openai temperature 0.7 --env edge
llm-config set llm/openai max_tokens 500 --env edge
llm-config set llm/openai timeout 15 --env edge
```

## Cost Optimization

### Token Budgets

```bash
# Set token budgets per environment
llm-config set llm/budget daily_tokens 1000000 --env production
llm-config set llm/budget max_tokens_per_request 4000 --env production
llm-config set llm/budget cost_per_1k_tokens 0.03 --env production

# Development: Lower budget
llm-config set llm/budget daily_tokens 10000 --env development
llm-config set llm/budget max_tokens_per_request 2000 --env development
```

### Python Implementation with Cost Tracking

```python
from datetime import datetime, timedelta
from llm_config_client import LLMConfigClient
import tiktoken

class CostAwareLLM:
    """LLM with cost tracking and budget enforcement"""

    def __init__(self, env: str = "production"):
        self.config_client = LLMConfigClient()
        self.env = env
        self.budget = self._load_budget()
        self.usage = {"tokens": 0, "cost": 0.0, "last_reset": datetime.now()}

    def _load_budget(self) -> Dict:
        """Load budget configuration"""
        configs = self.config_client.list_configs("llm/budget", env=self.env)
        return {c["key"]: c["value"] for c in configs}

    def _count_tokens(self, text: str, model: str) -> int:
        """Count tokens in text"""
        encoding = tiktoken.encoding_for_model(model)
        return len(encoding.encode(text))

    def _check_budget(self, estimated_tokens: int) -> bool:
        """Check if request is within budget"""
        # Reset daily budget if needed
        if datetime.now() - self.usage["last_reset"] > timedelta(days=1):
            self.usage = {"tokens": 0, "cost": 0.0, "last_reset": datetime.now()}

        daily_limit = int(self.budget.get("daily_tokens", 1000000))
        return (self.usage["tokens"] + estimated_tokens) <= daily_limit

    def _calculate_cost(self, tokens: int) -> float:
        """Calculate cost based on token usage"""
        cost_per_1k = float(self.budget.get("cost_per_1k_tokens", 0.03))
        return (tokens / 1000) * cost_per_1k

    def chat_completion(self, messages: List[Dict], **kwargs) -> Dict:
        """Create chat completion with cost tracking"""
        # Estimate input tokens
        model = kwargs.get("model", "gpt-4")
        input_text = " ".join([m["content"] for m in messages])
        input_tokens = self._count_tokens(input_text, model)

        # Check budget
        max_tokens = int(kwargs.get("max_tokens", 2000))
        estimated_total = input_tokens + max_tokens

        if not self._check_budget(estimated_total):
            raise ValueError(f"Request would exceed daily budget. Used: {self.usage['tokens']}")

        # Make request (implementation depends on provider)
        response = self._make_request(messages, **kwargs)

        # Track usage
        output_tokens = self._count_tokens(response, model)
        total_tokens = input_tokens + output_tokens
        cost = self._calculate_cost(total_tokens)

        self.usage["tokens"] += total_tokens
        self.usage["cost"] += cost

        return {
            "response": response,
            "usage": {
                "input_tokens": input_tokens,
                "output_tokens": output_tokens,
                "total_tokens": total_tokens,
                "cost": cost
            },
            "budget": {
                "daily_used": self.usage["tokens"],
                "daily_limit": int(self.budget.get("daily_tokens", 1000000)),
                "daily_cost": self.usage["cost"]
            }
        }

# Usage
llm = CostAwareLLM(env="production")

result = llm.chat_completion([
    {"role": "user", "content": "Write a short story"}
])

print(f"Response: {result['response']}")
print(f"Cost: ${result['usage']['cost']:.4f}")
print(f"Daily budget used: {result['budget']['daily_used']} / {result['budget']['daily_limit']}")
```

## Performance Tuning

### Configure Timeouts and Retries

```bash
# Timeout settings
llm-config set llm/performance connection_timeout 10 --env production
llm-config set llm/performance read_timeout 120 --env production
llm-config set llm/performance write_timeout 30 --env production

# Retry settings
llm-config set llm/performance max_retries 3 --env production
llm-config set llm/performance retry_delay 1 --env production
llm-config set llm/performance retry_backoff 2 --env production

# Rate limiting
llm-config set llm/performance max_requests_per_minute 60 --env production
llm-config set llm/performance max_concurrent_requests 10 --env production
```

### Python Implementation with Resilience

```python
import time
from functools import wraps
from typing import Callable

class ResilientLLM:
    """LLM with retry logic and circuit breaker"""

    def __init__(self, env: str = "production"):
        self.config_client = LLMConfigClient()
        self.env = env
        self.perf_config = self._load_performance_config()
        self.circuit_breaker = {
            "failures": 0,
            "last_failure": None,
            "state": "closed"  # closed, open, half-open
        }

    def _load_performance_config(self) -> Dict:
        """Load performance configuration"""
        configs = self.config_client.list_configs("llm/performance", env=self.env)
        return {c["key"]: c["value"] for c in configs}

    def _retry_with_backoff(self, func: Callable, *args, **kwargs):
        """Retry function with exponential backoff"""
        max_retries = int(self.perf_config.get("max_retries", 3))
        retry_delay = float(self.perf_config.get("retry_delay", 1))
        backoff = float(self.perf_config.get("retry_backoff", 2))

        for attempt in range(max_retries):
            try:
                return func(*args, **kwargs)
            except Exception as e:
                if attempt == max_retries - 1:
                    raise

                delay = retry_delay * (backoff ** attempt)
                print(f"Retry {attempt + 1}/{max_retries} after {delay}s: {e}")
                time.sleep(delay)

    def _check_circuit_breaker(self):
        """Check if circuit breaker allows request"""
        if self.circuit_breaker["state"] == "open":
            # Check if we should try half-open
            if time.time() - self.circuit_breaker["last_failure"] > 60:
                self.circuit_breaker["state"] = "half-open"
            else:
                raise Exception("Circuit breaker is open")

    def _record_success(self):
        """Record successful request"""
        self.circuit_breaker["failures"] = 0
        if self.circuit_breaker["state"] == "half-open":
            self.circuit_breaker["state"] = "closed"

    def _record_failure(self):
        """Record failed request"""
        self.circuit_breaker["failures"] += 1
        self.circuit_breaker["last_failure"] = time.time()

        if self.circuit_breaker["failures"] >= 5:
            self.circuit_breaker["state"] = "open"

    def chat_completion(self, messages: List[Dict], **kwargs) -> str:
        """Create chat completion with resilience"""
        self._check_circuit_breaker()

        try:
            response = self._retry_with_backoff(
                self._make_request,
                messages,
                **kwargs
            )
            self._record_success()
            return response
        except Exception as e:
            self._record_failure()
            raise

# Usage
llm = ResilientLLM(env="production")

try:
    response = llm.chat_completion([
        {"role": "user", "content": "Hello!"}
    ])
except Exception as e:
    print(f"Request failed: {e}")
```

## Advanced Patterns

### Dynamic Model Selection

```bash
# Configure model selection rules
llm-config set llm/routing simple_queries "gpt-3.5-turbo" --env production
llm-config set llm/routing complex_queries "gpt-4" --env production
llm-config set llm/routing code_generation "gpt-4" --env production
llm-config set llm/routing translation "gpt-3.5-turbo" --env production

# Complexity thresholds
llm-config set llm/routing complexity_threshold 100 --env production
```

### Python Implementation

```python
class SmartLLM:
    """LLM with intelligent model selection"""

    def __init__(self, env: str = "production"):
        self.config_client = LLMConfigClient()
        self.env = env
        self.routing = self._load_routing_config()

    def _load_routing_config(self) -> Dict:
        """Load routing configuration"""
        configs = self.config_client.list_configs("llm/routing", env=self.env)
        return {c["key"]: c["value"] for c in configs}

    def _estimate_complexity(self, messages: List[Dict]) -> int:
        """Estimate query complexity"""
        text = " ".join([m["content"] for m in messages])

        # Simple heuristics
        complexity = len(text.split())

        # Check for code
        if "```" in text or "def " in text or "function" in text:
            complexity *= 2

        # Check for technical terms
        technical_terms = ["algorithm", "implement", "optimize", "design"]
        if any(term in text.lower() for term in technical_terms):
            complexity *= 1.5

        return int(complexity)

    def _select_model(self, messages: List[Dict], task_type: str = None) -> str:
        """Select appropriate model based on task"""
        if task_type:
            # Use explicit task type
            return self.routing.get(task_type, "gpt-4")

        # Estimate complexity
        complexity = self._estimate_complexity(messages)
        threshold = int(self.routing.get("complexity_threshold", 100))

        if complexity < threshold:
            return self.routing.get("simple_queries", "gpt-3.5-turbo")
        else:
            return self.routing.get("complex_queries", "gpt-4")

    def chat_completion(self, messages: List[Dict], task_type: str = None, **kwargs) -> Dict:
        """Create chat completion with smart model selection"""
        # Select model
        model = self._select_model(messages, task_type)

        # Override if explicitly provided
        if "model" in kwargs:
            model = kwargs.pop("model")

        # Make request
        response = self._make_request(messages, model=model, **kwargs)

        return {
            "response": response,
            "metadata": {
                "model_used": model,
                "task_type": task_type,
                "complexity": self._estimate_complexity(messages)
            }
        }

# Usage
llm = SmartLLM(env="production")

# Automatic model selection
result = llm.chat_completion([
    {"role": "user", "content": "What is 2+2?"}
])
print(f"Model used: {result['metadata']['model_used']}")  # gpt-3.5-turbo

# Explicit task type
result = llm.chat_completion(
    messages=[{"role": "user", "content": "Write a sorting algorithm"}],
    task_type="code_generation"
)
print(f"Model used: {result['metadata']['model_used']}")  # gpt-4
```

## Next Steps

- Review [Feature Flags Example](feature-flags.md) for dynamic configuration
- See [Multi-Tenant Example](multi-tenant.md) for SaaS applications
- Check [Integration Guide](../integration.md) for implementation details
