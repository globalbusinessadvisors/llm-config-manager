//! HTTP server implementation

use crate::routes::{
    delete_config, get_config, get_history, health_check, list_configs, rollback_config,
    set_config, ApiState,
};
use axum::{
    routing::{delete, get, post},
    Router,
};
use llm_config_core::ConfigManager;
use std::net::SocketAddr;
use std::sync::Arc;
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;

/// Server configuration
#[derive(Debug, Clone)]
pub struct ServerConfig {
    pub host: String,
    pub port: u16,
    pub enable_cors: bool,
}

impl Default for ServerConfig {
    fn default() -> Self {
        Self {
            host: "127.0.0.1".to_string(),
            port: 8080,
            enable_cors: true,
        }
    }
}

/// Create and configure the Axum router
pub fn create_router(manager: Arc<ConfigManager>) -> Router {
    let state = ApiState { manager };

    // API v1 routes
    let api_routes = Router::new()
        // Config operations
        .route("/configs/:namespace/:key", get(get_config))
        .route("/configs/:namespace/:key", post(set_config))
        .route("/configs/:namespace/:key", delete(delete_config))
        .route("/configs/:namespace", get(list_configs))
        // Version history and rollback
        .route("/configs/:namespace/:key/history", get(get_history))
        .route(
            "/configs/:namespace/:key/rollback/:version",
            post(rollback_config),
        )
        .with_state(state);

    // Main router with health check
    Router::new()
        .route("/health", get(health_check))
        .nest("/api/v1", api_routes)
}

/// Start the HTTP server
pub async fn serve(
    manager: Arc<ConfigManager>,
    config: ServerConfig,
) -> anyhow::Result<()> {
    let app = create_router(manager);

    // Add middleware layers
    let app = app
        .layer(TraceLayer::new_for_http())
        .layer(if config.enable_cors {
            CorsLayer::new()
                .allow_origin(Any)
                .allow_methods(Any)
                .allow_headers(Any)
        } else {
            CorsLayer::permissive()
        });

    // Bind to address
    let addr: SocketAddr = format!("{}:{}", config.host, config.port).parse()?;
    tracing::info!("Starting LLM Config API server on {}", addr);

    // Create listener
    let listener = tokio::net::TcpListener::bind(addr).await?;

    // Serve with graceful shutdown
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await?;

    Ok(())
}

/// Graceful shutdown handler
async fn shutdown_signal() {
    let ctrl_c = async {
        tokio::signal::ctrl_c()
            .await
            .expect("Failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            .expect("Failed to install signal handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {
            tracing::info!("Received Ctrl+C, shutting down gracefully");
        },
        _ = terminate => {
            tracing::info!("Received SIGTERM, shutting down gracefully");
        },
    }
}

// Integration tests will be added in a separate test file
// For now, the API can be tested manually using curl or similar tools
