# Multi-stage Dockerfile for LLM Config Manager
# Production-ready, optimized for size and security

# Stage 1: Builder
FROM rust:1.75-slim-bookworm as builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN useradd -m -u 1000 -s /bin/bash llmconfig

# Set working directory
WORKDIR /build

# Copy manifests
COPY Cargo.toml Cargo.lock ./
COPY crates ./crates

# Build dependencies separately for better caching
RUN mkdir -p src && \
    echo "fn main() {}" > src/main.rs && \
    cargo build --release --bin llm-config-server && \
    rm -rf src

# Build the actual application
COPY . .
RUN cargo build --release --bin llm-config-server

# Strip debug symbols to reduce binary size
RUN strip /build/target/release/llm-config-server

# Stage 2: Runtime
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Create app user and directories
RUN useradd -m -u 1000 -s /bin/bash llmconfig && \
    mkdir -p /var/lib/llm-config/data \
             /var/lib/llm-config/cache \
             /var/lib/llm-config/backups \
             /var/log/llm-config \
             /etc/llm-config && \
    chown -R llmconfig:llmconfig /var/lib/llm-config /var/log/llm-config /etc/llm-config

# Copy binary from builder
COPY --from=builder /build/target/release/llm-config-server /usr/local/bin/

# Copy configuration files
COPY config/production.yaml /etc/llm-config/config.yaml

# Set permissions
RUN chmod 755 /usr/local/bin/llm-config-server && \
    chmod 600 /etc/llm-config/config.yaml

# Switch to non-root user
USER llmconfig

# Set working directory
WORKDIR /home/llmconfig

# Expose ports
EXPOSE 8080 9090

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/usr/local/bin/llm-config-server", "health-check"]

# Environment variables
ENV RUST_LOG=info \
    LLM_CONFIG_DATA_DIR=/var/lib/llm-config/data \
    LLM_CONFIG_CACHE_DIR=/var/lib/llm-config/cache \
    LLM_CONFIG_LOG_DIR=/var/log/llm-config

# Run the application
CMD ["/usr/local/bin/llm-config-server", "--config", "/etc/llm-config/config.yaml"]

# Metadata
LABEL maintainer="LLM DevOps Team" \
      version="1.0.0" \
      description="LLM Config Manager - Enterprise configuration management platform"
