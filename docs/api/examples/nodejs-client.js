#!/usr/bin/env node
/**
 * LLM Config Manager - Node.js Client Example
 *
 * This example demonstrates how to integrate the LLM Config Manager API
 * into Node.js applications with proper error handling, rate limiting,
 * and retry logic.
 *
 * Requirements:
 *   npm install axios
 */

const axios = require('axios');

/**
 * Custom error classes
 */
class ConfigClientError extends Error {
  constructor(message) {
    super(message);
    this.name = 'ConfigClientError';
  }
}

class RateLimitError extends ConfigClientError {
  constructor(message, retryAfter) {
    super(message);
    this.name = 'RateLimitError';
    this.retryAfter = retryAfter;
  }
}

class AuthenticationError extends ConfigClientError {
  constructor(message) {
    super(message);
    this.name = 'AuthenticationError';
  }
}

class NotFoundError extends ConfigClientError {
  constructor(message) {
    super(message);
    this.name = 'NotFoundError';
  }
}

/**
 * LLM Config Manager Client
 *
 * Features:
 * - Automatic retry with exponential backoff
 * - Rate limit handling
 * - Connection pooling
 * - Request caching
 * - Comprehensive error handling
 */
class LLMConfigClient {
  /**
   * Initialize the client
   *
   * @param {Object} options - Configuration options
   * @param {string} options.baseUrl - API base URL
   * @param {string} options.token - Authentication token
   * @param {number} options.timeout - Request timeout in ms
   * @param {number} options.maxRetries - Maximum retry attempts
   */
  constructor(options = {}) {
    this.baseUrl = (options.baseUrl || 'http://localhost:8080/api/v1').replace(/\/$/, '');
    this.token = options.token || null;
    this.timeout = options.timeout || 10000;
    this.maxRetries = options.maxRetries || 3;

    // Rate limit tracking
    this.rateLimit = null;
    this.rateRemaining = null;
    this.rateReset = null;

    // Create axios instance
    this.client = axios.create({
      baseURL: this.baseUrl,
      timeout: this.timeout,
      headers: this._getHeaders(),
    });

    // Response interceptor for rate limit tracking
    this.client.interceptors.response.use(
      (response) => {
        this._updateRateLimits(response);
        return response;
      },
      (error) => {
        if (error.response) {
          this._updateRateLimits(error.response);
        }
        return Promise.reject(error);
      }
    );
  }

  /**
   * Get request headers
   * @private
   */
  _getHeaders() {
    const headers = {
      'Content-Type': 'application/json',
      'User-Agent': 'LLMConfigClient/1.0',
    };

    if (this.token) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }

    return headers;
  }

  /**
   * Update rate limit info from response headers
   * @private
   */
  _updateRateLimits(response) {
    this.rateLimit = parseInt(response.headers['x-ratelimit-limit'] || 0);
    this.rateRemaining = parseInt(response.headers['x-ratelimit-remaining'] || 0);
    this.rateReset = parseInt(response.headers['x-ratelimit-reset'] || 0);

    // Log warning if rate limit is low
    if (this.rateLimit > 0 && this.rateRemaining < this.rateLimit * 0.1) {
      console.warn(`Rate limit low: ${this.rateRemaining}/${this.rateLimit} remaining`);
    }
  }

  /**
   * Handle API error responses
   * @private
   */
  _handleError(error) {
    if (!error.response) {
      throw new ConfigClientError(`Network error: ${error.message}`);
    }

    const { status, data } = error.response;
    const errorType = data.error || 'Unknown Error';
    const errorMessage = data.message || 'No error message provided';

    switch (status) {
      case 401:
        throw new AuthenticationError(`Authentication failed: ${errorMessage}`);
      case 404:
        throw new NotFoundError(errorMessage);
      case 429:
        const retryAfter = parseInt(error.response.headers['retry-after'] || 60);
        throw new RateLimitError(errorMessage, retryAfter);
      default:
        throw new ConfigClientError(`${errorType}: ${errorMessage}`);
    }
  }

  /**
   * Sleep for specified milliseconds
   * @private
   */
  _sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  /**
   * Calculate exponential backoff delay
   * @private
   */
  _calculateBackoff(attempt, baseDelay = 1000, maxDelay = 60000) {
    const delay = Math.min(baseDelay * Math.pow(2, attempt), maxDelay);
    const jitter = Math.random() * delay * 0.1; // 10% jitter
    return delay + jitter;
  }

  /**
   * Make HTTP request with error handling and retry logic
   * @private
   */
  async _request(method, path, options = {}) {
    for (let attempt = 0; attempt < this.maxRetries; attempt++) {
      try {
        const response = await this.client.request({
          method,
          url: path,
          ...options,
        });

        return response.data;
      } catch (error) {
        // Handle rate limiting
        if (error.response?.status === 429) {
          const retryAfter = parseInt(error.response.headers['retry-after'] || 60);
          console.warn(`Rate limited. Waiting ${retryAfter}s...`);
          await this._sleep(retryAfter * 1000);

          if (attempt < this.maxRetries - 1) {
            continue;
          }
        }

        // Retry on server errors with exponential backoff
        if (error.response?.status >= 500) {
          if (attempt < this.maxRetries - 1) {
            const delay = this._calculateBackoff(attempt);
            console.warn(`Server error. Retrying in ${delay / 1000}s...`);
            await this._sleep(delay);
            continue;
          }
        }

        // Don't retry on client errors
        if (error.response?.status >= 400 && error.response?.status < 500) {
          this._handleError(error);
        }

        // Last attempt or non-retryable error
        if (attempt === this.maxRetries - 1) {
          this._handleError(error);
        }
      }
    }

    throw new ConfigClientError('Request failed after maximum retries');
  }

  /**
   * Get a configuration value
   *
   * @param {string} namespace - Configuration namespace (e.g., "app/llm")
   * @param {string} key - Configuration key (e.g., "model")
   * @param {string} env - Environment (default: "production")
   * @param {boolean} withOverrides - Include environment overrides
   * @returns {Promise<Object|null>} Configuration data or null if not found
   *
   * @example
   * const client = new LLMConfigClient({ token: 'your-token' });
   * const config = await client.getConfig('app/llm', 'model', 'production');
   * console.log(config.value); // 'gpt-4'
   */
  async getConfig(namespace, key, env = 'production', withOverrides = false) {
    try {
      const params = { env };
      if (withOverrides) {
        params.with_overrides = 'true';
      }

      return await this._request('GET', `/configs/${namespace}/${key}`, { params });
    } catch (error) {
      if (error instanceof NotFoundError) {
        return null;
      }
      throw error;
    }
  }

  /**
   * Set a configuration value
   *
   * @param {string} namespace - Configuration namespace
   * @param {string} key - Configuration key
   * @param {*} value - Configuration value (any JSON type)
   * @param {string} env - Environment
   * @param {string} user - User making the change
   * @param {boolean} secret - Whether to encrypt as secret
   * @returns {Promise<Object>} Created/updated configuration data
   *
   * @example
   * const client = new LLMConfigClient({ token: 'your-token' });
   * const config = await client.setConfig(
   *   'app/llm', 'model', 'gpt-4', 'production', 'admin'
   * );
   * console.log(config.version); // 4
   */
  async setConfig(namespace, key, value, env = 'production', user = 'api-user', secret = false) {
    const data = { value, env, user, secret };
    return await this._request('POST', `/configs/${namespace}/${key}`, { data });
  }

  /**
   * Delete a configuration
   *
   * @param {string} namespace - Configuration namespace
   * @param {string} key - Configuration key
   * @param {string} env - Environment
   * @returns {Promise<boolean>} True if deleted, false if not found
   *
   * @example
   * const client = new LLMConfigClient({ token: 'your-token' });
   * const deleted = await client.deleteConfig('app/llm', 'old_config', 'development');
   * console.log(deleted); // true
   */
  async deleteConfig(namespace, key, env = 'production') {
    try {
      await this._request('DELETE', `/configs/${namespace}/${key}`, {
        params: { env },
      });
      return true;
    } catch (error) {
      if (error instanceof NotFoundError) {
        return false;
      }
      throw error;
    }
  }

  /**
   * List all configurations in a namespace
   *
   * @param {string} namespace - Configuration namespace
   * @param {string} env - Environment
   * @returns {Promise<Array>} List of configuration entries
   *
   * @example
   * const client = new LLMConfigClient({ token: 'your-token' });
   * const configs = await client.listConfigs('app/llm', 'production');
   * configs.forEach(config => {
   *   console.log(`${config.key}: ${config.value}`);
   * });
   */
  async listConfigs(namespace, env = 'production') {
    return await this._request('GET', `/configs/${namespace}`, {
      params: { env },
    });
  }

  /**
   * Get version history for a configuration
   *
   * @param {string} namespace - Configuration namespace
   * @param {string} key - Configuration key
   * @param {string} env - Environment
   * @returns {Promise<Array>} List of version entries (newest first)
   *
   * @example
   * const client = new LLMConfigClient({ token: 'your-token' });
   * const history = await client.getHistory('app/llm', 'model', 'production');
   * history.forEach(version => {
   *   console.log(`v${version.version}: ${version.value}`);
   * });
   */
  async getHistory(namespace, key, env = 'production') {
    try {
      return await this._request('GET', `/configs/${namespace}/${key}/history`, {
        params: { env },
      });
    } catch (error) {
      if (error instanceof NotFoundError) {
        return [];
      }
      throw error;
    }
  }

  /**
   * Rollback a configuration to a specific version
   *
   * @param {string} namespace - Configuration namespace
   * @param {string} key - Configuration key
   * @param {number} version - Version number to rollback to
   * @param {string} env - Environment
   * @returns {Promise<Object>} Rolled-back configuration data
   *
   * @example
   * const client = new LLMConfigClient({ token: 'your-token' });
   * const config = await client.rollback('app/llm', 'model', 2, 'production');
   * console.log(`Rolled back to v${version}: ${config.value}`);
   */
  async rollback(namespace, key, version, env = 'production') {
    return await this._request('POST', `/configs/${namespace}/${key}/rollback/${version}`, {
      params: { env },
    });
  }

  /**
   * Check API health status
   *
   * @returns {Promise<Object>} Health status information
   *
   * @example
   * const client = new LLMConfigClient();
   * const health = await client.healthCheck();
   * console.log(health.status); // 'healthy'
   */
  async healthCheck() {
    return await this._request('GET', '/health');
  }

  /**
   * Get current rate limit status
   *
   * @returns {Object} Rate limit information
   */
  getRateLimitStatus() {
    return {
      limit: this.rateLimit || 0,
      remaining: this.rateRemaining || 0,
      reset: this.rateReset || 0,
      resetTime: this.rateReset ? new Date(this.rateReset * 1000) : null,
    };
  }
}

/**
 * Simple cache implementation for config values
 */
class ConfigCache {
  constructor(ttlSeconds = 300) {
    this.cache = new Map();
    this.ttl = ttlSeconds * 1000; // Convert to milliseconds
  }

  _getKey(namespace, key, env) {
    return `${namespace}:${key}:${env}`;
  }

  get(namespace, key, env) {
    const cacheKey = this._getKey(namespace, key, env);
    const entry = this.cache.get(cacheKey);

    if (!entry) {
      return null;
    }

    // Check if expired
    if (Date.now() > entry.expiresAt) {
      this.cache.delete(cacheKey);
      return null;
    }

    return entry.value;
  }

  set(namespace, key, env, value) {
    const cacheKey = this._getKey(namespace, key, env);
    this.cache.set(cacheKey, {
      value,
      expiresAt: Date.now() + this.ttl,
    });
  }

  clear() {
    this.cache.clear();
  }
}

/**
 * Client with caching support
 */
class CachedLLMConfigClient extends LLMConfigClient {
  constructor(options = {}) {
    super(options);
    this.cache = new ConfigCache(options.cacheTtl || 300);
  }

  async getConfig(namespace, key, env = 'production', withOverrides = false) {
    // Don't cache with overrides
    if (withOverrides) {
      return super.getConfig(namespace, key, env, withOverrides);
    }

    // Check cache
    const cached = this.cache.get(namespace, key, env);
    if (cached) {
      return cached;
    }

    // Fetch and cache
    const config = await super.getConfig(namespace, key, env, withOverrides);
    if (config) {
      this.cache.set(namespace, key, env, config);
    }

    return config;
  }

  clearCache() {
    this.cache.clear();
  }
}

/**
 * Example usage
 */
async function main() {
  // Initialize client
  const client = new LLMConfigClient({
    baseUrl: 'http://localhost:8080/api/v1',
    token: 'your-auth-token',
    timeout: 10000,
    maxRetries: 3,
  });

  try {
    // Check API health
    console.log('=== Health Check ===');
    const health = await client.healthCheck();
    console.log(`Status: ${health.status}`);
    console.log(`Version: ${health.version}`);
    console.log();

    // Set configuration
    console.log('=== Set Configuration ===');
    const config = await client.setConfig('app/llm', 'model', 'gpt-4', 'production', 'admin');
    console.log(`Set config: ${config.key} = ${config.value}`);
    console.log(`Version: ${config.version}`);
    console.log();

    // Get configuration
    console.log('=== Get Configuration ===');
    const getConfig = await client.getConfig('app/llm', 'model', 'production');
    if (getConfig) {
      console.log(`Model: ${getConfig.value}`);
      console.log(`Version: ${getConfig.version}`);
      console.log(`Updated by: ${getConfig.metadata.updated_by}`);
    }
    console.log();

    // List configurations
    console.log('=== List Configurations ===');
    const configs = await client.listConfigs('app/llm', 'production');
    configs.forEach((cfg) => {
      console.log(`- ${cfg.key}: ${cfg.value}`);
    });
    console.log();

    // Get history
    console.log('=== Version History ===');
    const history = await client.getHistory('app/llm', 'model', 'production');
    history.forEach((version) => {
      console.log(`Version ${version.version}: ${version.value}`);
      console.log(`  Created by: ${version.created_by}`);
      console.log(`  Created at: ${version.created_at}`);
    });
    console.log();

    // Check rate limit status
    console.log('=== Rate Limit Status ===');
    const rateLimit = client.getRateLimitStatus();
    console.log(`Limit: ${rateLimit.limit}`);
    console.log(`Remaining: ${rateLimit.remaining}`);
    if (rateLimit.resetTime) {
      console.log(`Resets at: ${rateLimit.resetTime}`);
    }
    console.log();

    // Example with caching
    console.log('=== Cached Configuration ===');
    const cachedClient = new CachedLLMConfigClient({
      baseUrl: 'http://localhost:8080/api/v1',
      token: 'your-auth-token',
      cacheTtl: 300, // 5 minutes
    });

    const cachedConfig = await cachedClient.getConfig('app/llm', 'model', 'production');
    console.log(`Model (cached): ${cachedConfig ? cachedConfig.value : 'Not found'}`);
  } catch (error) {
    console.error('Error:', error.message);
    if (error instanceof RateLimitError) {
      console.error(`Retry after ${error.retryAfter} seconds`);
    }
  }
}

// Export classes
module.exports = {
  LLMConfigClient,
  CachedLLMConfigClient,
  ConfigClientError,
  RateLimitError,
  AuthenticationError,
  NotFoundError,
};

// Run example if executed directly
if (require.main === module) {
  main().catch(console.error);
}
