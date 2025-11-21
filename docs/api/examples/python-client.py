#!/usr/bin/env python3
"""
LLM Config Manager - Python Client Example

This example demonstrates how to integrate the LLM Config Manager API
into Python applications with proper error handling, rate limiting,
and retry logic.

Requirements:
    pip install requests
"""

import json
import logging
import time
from datetime import datetime
from functools import lru_cache
from typing import Any, Dict, List, Optional

import requests
from requests.adapters import HTTPAdapter
from requests.exceptions import ConnectionError, HTTPError, Timeout
from urllib3.util.retry import Retry

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class ConfigClientError(Exception):
    """Base exception for config client errors"""
    pass


class RateLimitError(ConfigClientError):
    """Rate limit exceeded error"""
    pass


class AuthenticationError(ConfigClientError):
    """Authentication failed error"""
    pass


class NotFoundError(ConfigClientError):
    """Configuration not found error"""
    pass


class LLMConfigClient:
    """
    Client for the LLM Config Manager API.

    Features:
    - Automatic retry with exponential backoff
    - Rate limit handling
    - Connection pooling
    - Request caching
    - Comprehensive error handling
    """

    def __init__(
        self,
        base_url: str = "http://localhost:8080/api/v1",
        token: Optional[str] = None,
        timeout: int = 10,
        max_retries: int = 3,
        pool_connections: int = 10,
        pool_maxsize: int = 10
    ):
        """
        Initialize the client.

        Args:
            base_url: API base URL
            token: Authentication token
            timeout: Request timeout in seconds
            max_retries: Maximum number of retry attempts
            pool_connections: Number of connection pools
            pool_maxsize: Maximum size of connection pool
        """
        self.base_url = base_url.rstrip('/')
        self.token = token
        self.timeout = timeout
        self.max_retries = max_retries

        # Rate limit tracking
        self.rate_limit = None
        self.rate_remaining = None
        self.rate_reset = None

        # Create session with connection pooling and retry logic
        self.session = self._create_session(pool_connections, pool_maxsize)

    def _create_session(self, pool_connections: int, pool_maxsize: int) -> requests.Session:
        """Create requests session with retry logic and connection pooling"""
        session = requests.Session()

        # Configure retry strategy
        retry_strategy = Retry(
            total=self.max_retries,
            backoff_factor=1,
            status_forcelist=[500, 502, 503, 504],
            allowed_methods=["GET", "POST", "DELETE"]
        )

        # Configure connection pooling
        adapter = HTTPAdapter(
            pool_connections=pool_connections,
            pool_maxsize=pool_maxsize,
            max_retries=retry_strategy
        )

        session.mount("http://", adapter)
        session.mount("https://", adapter)

        return session

    def _get_headers(self) -> Dict[str, str]:
        """Get request headers with authentication"""
        headers = {
            'Content-Type': 'application/json',
            'User-Agent': 'LLMConfigClient/1.0'
        }

        if self.token:
            headers['Authorization'] = f'Bearer {self.token}'

        return headers

    def _update_rate_limits(self, response: requests.Response):
        """Update rate limit info from response headers"""
        self.rate_limit = int(response.headers.get('X-RateLimit-Limit', 0))
        self.rate_remaining = int(response.headers.get('X-RateLimit-Remaining', 0))
        self.rate_reset = int(response.headers.get('X-RateLimit-Reset', 0))

        # Log warning if rate limit is low
        if self.rate_limit > 0 and self.rate_remaining < self.rate_limit * 0.1:
            logger.warning(
                f"Rate limit low: {self.rate_remaining}/{self.rate_limit} remaining"
            )

    def _handle_error(self, response: requests.Response):
        """Handle API error responses"""
        try:
            error_data = response.json()
            error_type = error_data.get('error', 'Unknown Error')
            error_message = error_data.get('message', 'No error message provided')
        except json.JSONDecodeError:
            error_type = response.reason
            error_message = response.text

        if response.status_code == 401:
            raise AuthenticationError(f"Authentication failed: {error_message}")
        elif response.status_code == 404:
            raise NotFoundError(error_message)
        elif response.status_code == 429:
            raise RateLimitError(error_message)
        else:
            raise ConfigClientError(f"{error_type}: {error_message}")

    def _request(
        self,
        method: str,
        path: str,
        **kwargs
    ) -> Dict[str, Any]:
        """
        Make HTTP request with error handling and rate limit management.

        Args:
            method: HTTP method
            path: API path
            **kwargs: Additional request arguments

        Returns:
            Response data as dictionary

        Raises:
            ConfigClientError: On API errors
            RateLimitError: When rate limited
            AuthenticationError: On auth failures
        """
        url = f"{self.base_url}{path}"
        headers = self._get_headers()

        # Merge headers
        if 'headers' in kwargs:
            headers.update(kwargs['headers'])
        kwargs['headers'] = headers

        # Set timeout if not provided
        if 'timeout' not in kwargs:
            kwargs['timeout'] = self.timeout

        # Make request
        try:
            response = self.session.request(method, url, **kwargs)
            self._update_rate_limits(response)

            # Handle rate limiting
            if response.status_code == 429:
                retry_after = int(response.headers.get('Retry-After', 60))
                logger.warning(f"Rate limited. Waiting {retry_after}s...")
                time.sleep(retry_after)
                return self._request(method, path, **kwargs)

            # Raise for HTTP errors
            response.raise_for_status()

            # Return JSON response or empty dict for 204
            if response.status_code == 204:
                return {}

            return response.json()

        except HTTPError as e:
            self._handle_error(e.response)
        except (ConnectionError, Timeout) as e:
            raise ConfigClientError(f"Network error: {str(e)}")

    def get_config(
        self,
        namespace: str,
        key: str,
        env: str = "production",
        with_overrides: bool = False
    ) -> Optional[Dict[str, Any]]:
        """
        Get a configuration value.

        Args:
            namespace: Configuration namespace (e.g., "app/llm")
            key: Configuration key (e.g., "model")
            env: Environment (default: "production")
            with_overrides: Include environment overrides

        Returns:
            Configuration data or None if not found

        Example:
            >>> client = LLMConfigClient(token="your-token")
            >>> config = client.get_config("app/llm", "model", "production")
            >>> print(config['value'])
            'gpt-4'
        """
        params = {'env': env}
        if with_overrides:
            params['with_overrides'] = 'true'

        try:
            return self._request(
                'GET',
                f'/configs/{namespace}/{key}',
                params=params
            )
        except NotFoundError:
            return None

    def set_config(
        self,
        namespace: str,
        key: str,
        value: Any,
        env: str = "production",
        user: str = "api-user",
        secret: bool = False
    ) -> Dict[str, Any]:
        """
        Set a configuration value.

        Args:
            namespace: Configuration namespace
            key: Configuration key
            value: Configuration value (any JSON type)
            env: Environment
            user: User making the change
            secret: Whether to encrypt as secret

        Returns:
            Created/updated configuration data

        Example:
            >>> client = LLMConfigClient(token="your-token")
            >>> config = client.set_config(
            ...     "app/llm", "model", "gpt-4", "production", "admin"
            ... )
            >>> print(config['version'])
            4
        """
        data = {
            'value': value,
            'env': env,
            'user': user,
            'secret': secret
        }

        return self._request(
            'POST',
            f'/configs/{namespace}/{key}',
            json=data
        )

    def delete_config(
        self,
        namespace: str,
        key: str,
        env: str = "production"
    ) -> bool:
        """
        Delete a configuration.

        Args:
            namespace: Configuration namespace
            key: Configuration key
            env: Environment

        Returns:
            True if deleted, False if not found

        Example:
            >>> client = LLMConfigClient(token="your-token")
            >>> deleted = client.delete_config("app/llm", "old_config", "development")
            >>> print(deleted)
            True
        """
        try:
            self._request(
                'DELETE',
                f'/configs/{namespace}/{key}',
                params={'env': env}
            )
            return True
        except NotFoundError:
            return False

    def list_configs(
        self,
        namespace: str,
        env: str = "production"
    ) -> List[Dict[str, Any]]:
        """
        List all configurations in a namespace.

        Args:
            namespace: Configuration namespace
            env: Environment

        Returns:
            List of configuration entries

        Example:
            >>> client = LLMConfigClient(token="your-token")
            >>> configs = client.list_configs("app/llm", "production")
            >>> for config in configs:
            ...     print(f"{config['key']}: {config['value']}")
            model: gpt-4
            temperature: 0.7
        """
        return self._request(
            'GET',
            f'/configs/{namespace}',
            params={'env': env}
        )

    def get_history(
        self,
        namespace: str,
        key: str,
        env: str = "production"
    ) -> List[Dict[str, Any]]:
        """
        Get version history for a configuration.

        Args:
            namespace: Configuration namespace
            key: Configuration key
            env: Environment

        Returns:
            List of version entries (newest first)

        Example:
            >>> client = LLMConfigClient(token="your-token")
            >>> history = client.get_history("app/llm", "model", "production")
            >>> for version in history:
            ...     print(f"v{version['version']}: {version['value']}")
            v3: gpt-4
            v2: gpt-3.5-turbo
            v1: gpt-3.5
        """
        try:
            return self._request(
                'GET',
                f'/configs/{namespace}/{key}/history',
                params={'env': env}
            )
        except NotFoundError:
            return []

    def rollback(
        self,
        namespace: str,
        key: str,
        version: int,
        env: str = "production"
    ) -> Dict[str, Any]:
        """
        Rollback a configuration to a specific version.

        Args:
            namespace: Configuration namespace
            key: Configuration key
            version: Version number to rollback to
            env: Environment

        Returns:
            Rolled-back configuration data

        Example:
            >>> client = LLMConfigClient(token="your-token")
            >>> config = client.rollback("app/llm", "model", 2, "production")
            >>> print(f"Rolled back to v{version}: {config['value']}")
            Rolled back to v2: gpt-3.5-turbo
        """
        return self._request(
            'POST',
            f'/configs/{namespace}/{key}/rollback/{version}',
            params={'env': env}
        )

    def health_check(self) -> Dict[str, Any]:
        """
        Check API health status.

        Returns:
            Health status information

        Example:
            >>> client = LLMConfigClient()
            >>> health = client.health_check()
            >>> print(health['status'])
            healthy
        """
        return self._request('GET', '/health')

    def get_rate_limit_status(self) -> Dict[str, int]:
        """
        Get current rate limit status.

        Returns:
            Dictionary with limit, remaining, and reset timestamp
        """
        return {
            'limit': self.rate_limit or 0,
            'remaining': self.rate_remaining or 0,
            'reset': self.rate_reset or 0,
            'reset_time': datetime.fromtimestamp(self.rate_reset) if self.rate_reset else None
        }


# Utility functions

@lru_cache(maxsize=256)
def get_config_cached(
    client: LLMConfigClient,
    namespace: str,
    key: str,
    env: str,
    ttl_hash: int
) -> Optional[Dict[str, Any]]:
    """
    Get config with caching.

    Args:
        client: LLMConfigClient instance
        namespace: Configuration namespace
        key: Configuration key
        env: Environment
        ttl_hash: TTL hash for cache invalidation

    Returns:
        Configuration data or None
    """
    return client.get_config(namespace, key, env)


def get_ttl_hash(seconds: int = 300) -> int:
    """
    Get TTL hash for cache invalidation.

    Args:
        seconds: TTL in seconds

    Returns:
        Hash that changes every `seconds`
    """
    return round(time.time() / seconds)


# Example usage
def main():
    """Example usage of the LLM Config Client"""

    # Initialize client
    client = LLMConfigClient(
        base_url="http://localhost:8080/api/v1",
        token="your-auth-token",
        timeout=10,
        max_retries=3
    )

    # Check API health
    print("=== Health Check ===")
    health = client.health_check()
    print(f"Status: {health['status']}")
    print(f"Version: {health['version']}")
    print()

    # Set configuration
    print("=== Set Configuration ===")
    config = client.set_config(
        namespace="app/llm",
        key="model",
        value="gpt-4",
        env="production",
        user="admin"
    )
    print(f"Set config: {config['key']} = {config['value']}")
    print(f"Version: {config['version']}")
    print()

    # Get configuration
    print("=== Get Configuration ===")
    config = client.get_config("app/llm", "model", "production")
    if config:
        print(f"Model: {config['value']}")
        print(f"Version: {config['version']}")
        print(f"Updated by: {config['metadata']['updated_by']}")
    print()

    # List configurations
    print("=== List Configurations ===")
    configs = client.list_configs("app/llm", "production")
    for cfg in configs:
        print(f"- {cfg['key']}: {cfg['value']}")
    print()

    # Get history
    print("=== Version History ===")
    history = client.get_history("app/llm", "model", "production")
    for version in history:
        print(f"Version {version['version']}: {version['value']}")
        print(f"  Created by: {version['created_by']}")
        print(f"  Created at: {version['created_at']}")
    print()

    # Check rate limit status
    print("=== Rate Limit Status ===")
    rate_limit = client.get_rate_limit_status()
    print(f"Limit: {rate_limit['limit']}")
    print(f"Remaining: {rate_limit['remaining']}")
    if rate_limit['reset_time']:
        print(f"Resets at: {rate_limit['reset_time']}")
    print()

    # Example with caching (5 minute TTL)
    print("=== Cached Configuration ===")
    config = get_config_cached(
        client, "app/llm", "model", "production", get_ttl_hash(300)
    )
    print(f"Model (cached): {config['value'] if config else 'Not found'}")


if __name__ == '__main__':
    main()
