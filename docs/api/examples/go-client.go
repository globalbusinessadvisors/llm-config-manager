package main

/*
LLM Config Manager - Go Client Example

This example demonstrates how to integrate the LLM Config Manager API
into Go applications with proper error handling, rate limiting,
and retry logic.

Requirements:
	go get github.com/go-resty/resty/v2
*/

import (
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/go-resty/resty/v2"
)

// ConfigClientError represents client errors
type ConfigClientError struct {
	StatusCode int
	Message    string
}

func (e *ConfigClientError) Error() string {
	return fmt.Sprintf("config client error (status %d): %s", e.StatusCode, e.Message)
}

// ErrorResponse represents API error responses
type ErrorResponse struct {
	Error   string `json:"error"`
	Message string `json:"message"`
}

// HealthResponse represents health check response
type HealthResponse struct {
	Status  string `json:"status"`
	Service string `json:"service"`
	Version string `json:"version"`
}

// ConfigMetadata represents configuration metadata
type ConfigMetadata struct {
	CreatedAt   string   `json:"created_at"`
	CreatedBy   string   `json:"created_by"`
	UpdatedAt   string   `json:"updated_at"`
	UpdatedBy   string   `json:"updated_by"`
	Tags        []string `json:"tags"`
	Description *string  `json:"description"`
}

// ConfigResponse represents a configuration entry
type ConfigResponse struct {
	ID          string                 `json:"id"`
	Namespace   string                 `json:"namespace"`
	Key         string                 `json:"key"`
	Value       interface{}            `json:"value"`
	Environment string                 `json:"environment"`
	Version     int64                  `json:"version"`
	Metadata    ConfigMetadata         `json:"metadata"`
}

// SetConfigRequest represents a request to set configuration
type SetConfigRequest struct {
	Value  interface{} `json:"value"`
	Env    string      `json:"env"`
	User   string      `json:"user"`
	Secret bool        `json:"secret"`
}

// VersionEntry represents a version history entry
type VersionEntry struct {
	Version           int64       `json:"version"`
	Value             interface{} `json:"value"`
	CreatedAt         string      `json:"created_at"`
	CreatedBy         string      `json:"created_by"`
	ChangeDescription *string     `json:"change_description"`
}

// RateLimitInfo tracks rate limit status
type RateLimitInfo struct {
	Limit     int
	Remaining int
	Reset     int64
	ResetTime time.Time
}

// LLMConfigClient provides access to the LLM Config Manager API
type LLMConfigClient struct {
	baseURL    string
	token      string
	httpClient *resty.Client
	rateLimit  *RateLimitInfo
}

// NewLLMConfigClient creates a new client instance
func NewLLMConfigClient(baseURL, token string) *LLMConfigClient {
	client := resty.New().
		SetBaseURL(baseURL).
		SetTimeout(10 * time.Second).
		SetRetryCount(3).
		SetRetryWaitTime(1 * time.Second).
		SetRetryMaxWaitTime(30 * time.Second)

	if token != "" {
		client.SetAuthToken(token)
	}

	llmClient := &LLMConfigClient{
		baseURL:    baseURL,
		token:      token,
		httpClient: client,
		rateLimit:  &RateLimitInfo{},
	}

	// Add response middleware to track rate limits
	client.OnAfterResponse(func(c *resty.Client, resp *resty.Response) error {
		llmClient.updateRateLimits(resp)
		return nil
	})

	// Add retry condition for rate limiting
	client.AddRetryCondition(func(r *resty.Response, err error) bool {
		if r.StatusCode() == 429 {
			retryAfter := r.Header().Get("Retry-After")
			if retryAfter != "" {
				duration, _ := time.ParseDuration(retryAfter + "s")
				log.Printf("Rate limited. Waiting %v...", duration)
				time.Sleep(duration)
				return true
			}
			time.Sleep(60 * time.Second)
			return true
		}
		return r.StatusCode() >= 500
	})

	return llmClient
}

// updateRateLimits updates rate limit info from response headers
func (c *LLMConfigClient) updateRateLimits(resp *resty.Response) {
	if limit := resp.Header().Get("X-RateLimit-Limit"); limit != "" {
		fmt.Sscanf(limit, "%d", &c.rateLimit.Limit)
	}
	if remaining := resp.Header().Get("X-RateLimit-Remaining"); remaining != "" {
		fmt.Sscanf(remaining, "%d", &c.rateLimit.Remaining)
	}
	if reset := resp.Header().Get("X-RateLimit-Reset"); reset != "" {
		var resetTimestamp int64
		fmt.Sscanf(reset, "%d", &resetTimestamp)
		c.rateLimit.Reset = resetTimestamp
		c.rateLimit.ResetTime = time.Unix(resetTimestamp, 0)
	}

	// Log warning if rate limit is low
	if c.rateLimit.Limit > 0 && c.rateLimit.Remaining < c.rateLimit.Limit/10 {
		log.Printf("Warning: Rate limit low: %d/%d remaining",
			c.rateLimit.Remaining, c.rateLimit.Limit)
	}
}

// handleErrorResponse handles API error responses
func (c *LLMConfigClient) handleErrorResponse(resp *resty.Response) error {
	var errorResp ErrorResponse
	if err := json.Unmarshal(resp.Body(), &errorResp); err != nil {
		return &ConfigClientError{
			StatusCode: resp.StatusCode(),
			Message:    string(resp.Body()),
		}
	}

	return &ConfigClientError{
		StatusCode: resp.StatusCode(),
		Message:    errorResp.Message,
	}
}

// GetConfig retrieves a configuration value
func (c *LLMConfigClient) GetConfig(namespace, key, env string, withOverrides bool) (*ConfigResponse, error) {
	var result ConfigResponse

	resp, err := c.httpClient.R().
		SetQueryParams(map[string]string{
			"env":            env,
			"with_overrides": fmt.Sprintf("%t", withOverrides),
		}).
		SetResult(&result).
		Get(fmt.Sprintf("/configs/%s/%s", namespace, key))

	if err != nil {
		return nil, err
	}

	if resp.IsError() {
		if resp.StatusCode() == 404 {
			return nil, nil
		}
		return nil, c.handleErrorResponse(resp)
	}

	return &result, nil
}

// SetConfig sets a configuration value
func (c *LLMConfigClient) SetConfig(namespace, key string, value interface{}, env, user string, secret bool) (*ConfigResponse, error) {
	var result ConfigResponse

	req := SetConfigRequest{
		Value:  value,
		Env:    env,
		User:   user,
		Secret: secret,
	}

	resp, err := c.httpClient.R().
		SetBody(req).
		SetResult(&result).
		Post(fmt.Sprintf("/configs/%s/%s", namespace, key))

	if err != nil {
		return nil, err
	}

	if resp.IsError() {
		return nil, c.handleErrorResponse(resp)
	}

	return &result, nil
}

// DeleteConfig deletes a configuration
func (c *LLMConfigClient) DeleteConfig(namespace, key, env string) (bool, error) {
	resp, err := c.httpClient.R().
		SetQueryParam("env", env).
		Delete(fmt.Sprintf("/configs/%s/%s", namespace, key))

	if err != nil {
		return false, err
	}

	if resp.StatusCode() == 404 {
		return false, nil
	}

	if resp.IsError() {
		return false, c.handleErrorResponse(resp)
	}

	return true, nil
}

// ListConfigs lists all configurations in a namespace
func (c *LLMConfigClient) ListConfigs(namespace, env string) ([]ConfigResponse, error) {
	var result []ConfigResponse

	resp, err := c.httpClient.R().
		SetQueryParam("env", env).
		SetResult(&result).
		Get(fmt.Sprintf("/configs/%s", namespace))

	if err != nil {
		return nil, err
	}

	if resp.IsError() {
		return nil, c.handleErrorResponse(resp)
	}

	return result, nil
}

// GetHistory retrieves version history for a configuration
func (c *LLMConfigClient) GetHistory(namespace, key, env string) ([]VersionEntry, error) {
	var result []VersionEntry

	resp, err := c.httpClient.R().
		SetQueryParam("env", env).
		SetResult(&result).
		Get(fmt.Sprintf("/configs/%s/%s/history", namespace, key))

	if err != nil {
		return nil, err
	}

	if resp.StatusCode() == 404 {
		return []VersionEntry{}, nil
	}

	if resp.IsError() {
		return nil, c.handleErrorResponse(resp)
	}

	return result, nil
}

// Rollback rolls back a configuration to a specific version
func (c *LLMConfigClient) Rollback(namespace, key string, version int64, env string) (*ConfigResponse, error) {
	var result ConfigResponse

	resp, err := c.httpClient.R().
		SetQueryParam("env", env).
		SetResult(&result).
		Post(fmt.Sprintf("/configs/%s/%s/rollback/%d", namespace, key, version))

	if err != nil {
		return nil, err
	}

	if resp.IsError() {
		return nil, c.handleErrorResponse(resp)
	}

	return &result, nil
}

// HealthCheck checks API health status
func (c *LLMConfigClient) HealthCheck() (*HealthResponse, error) {
	var result HealthResponse

	resp, err := c.httpClient.R().
		SetResult(&result).
		Get("/health")

	if err != nil {
		return nil, err
	}

	if resp.IsError() {
		return nil, c.handleErrorResponse(resp)
	}

	return &result, nil
}

// GetRateLimitStatus returns current rate limit status
func (c *LLMConfigClient) GetRateLimitStatus() *RateLimitInfo {
	return c.rateLimit
}

// Example usage
func main() {
	// Initialize client
	client := NewLLMConfigClient(
		"http://localhost:8080/api/v1",
		"your-auth-token",
	)

	// Check API health
	fmt.Println("=== Health Check ===")
	health, err := client.HealthCheck()
	if err != nil {
		log.Fatalf("Health check failed: %v", err)
	}
	fmt.Printf("Status: %s\n", health.Status)
	fmt.Printf("Version: %s\n", health.Version)
	fmt.Println()

	// Set configuration
	fmt.Println("=== Set Configuration ===")
	config, err := client.SetConfig(
		"app/llm",
		"model",
		"gpt-4",
		"production",
		"admin",
		false,
	)
	if err != nil {
		log.Fatalf("Failed to set config: %v", err)
	}
	fmt.Printf("Set config: %s = %v\n", config.Key, config.Value)
	fmt.Printf("Version: %d\n", config.Version)
	fmt.Println()

	// Get configuration
	fmt.Println("=== Get Configuration ===")
	config, err = client.GetConfig("app/llm", "model", "production", false)
	if err != nil {
		log.Fatalf("Failed to get config: %v", err)
	}
	if config != nil {
		fmt.Printf("Model: %v\n", config.Value)
		fmt.Printf("Version: %d\n", config.Version)
		fmt.Printf("Updated by: %s\n", config.Metadata.UpdatedBy)
	}
	fmt.Println()

	// List configurations
	fmt.Println("=== List Configurations ===")
	configs, err := client.ListConfigs("app/llm", "production")
	if err != nil {
		log.Fatalf("Failed to list configs: %v", err)
	}
	for _, cfg := range configs {
		fmt.Printf("- %s: %v\n", cfg.Key, cfg.Value)
	}
	fmt.Println()

	// Get history
	fmt.Println("=== Version History ===")
	history, err := client.GetHistory("app/llm", "model", "production")
	if err != nil {
		log.Fatalf("Failed to get history: %v", err)
	}
	for _, version := range history {
		fmt.Printf("Version %d: %v\n", version.Version, version.Value)
		fmt.Printf("  Created by: %s\n", version.CreatedBy)
		fmt.Printf("  Created at: %s\n", version.CreatedAt)
	}
	fmt.Println()

	// Check rate limit status
	fmt.Println("=== Rate Limit Status ===")
	rateLimit := client.GetRateLimitStatus()
	fmt.Printf("Limit: %d\n", rateLimit.Limit)
	fmt.Printf("Remaining: %d\n", rateLimit.Remaining)
	if !rateLimit.ResetTime.IsZero() {
		fmt.Printf("Resets at: %s\n", rateLimit.ResetTime.Format(time.RFC3339))
	}
}
