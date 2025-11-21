#!/usr/bin/env bash
#
# Deploy LLM Config Manager using Docker Compose
#
# Usage: ./deploy-docker.sh [start|stop|restart|logs|status]
#

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.yml"
ENV_FILE="${PROJECT_ROOT}/.env"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi

    log_info "Prerequisites check passed"
}

# Create environment file
create_env_file() {
    if [[ ! -f "${ENV_FILE}" ]]; then
        log_info "Creating .env file..."

        cat > "${ENV_FILE}" <<EOF
# LLM Config Manager Environment Variables

# Encryption key (generate with: openssl rand -base64 32)
ENCRYPTION_KEY=$(openssl rand -base64 32)

# Database password
DB_PASSWORD=$(openssl rand -base64 24)

# Redis password
REDIS_PASSWORD=$(openssl rand -base64 24)

# Grafana admin password
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 16)

# Environment
ENVIRONMENT=production
EOF

        chmod 600 "${ENV_FILE}"
        log_info "Environment file created at ${ENV_FILE}"
        log_warn "Please review and update the generated secrets if needed"
    else
        log_info "Environment file already exists"
    fi
}

# Build Docker image
build_image() {
    log_info "Building Docker image..."

    cd "${PROJECT_ROOT}"
    docker build -t llm-config-manager:latest .

    log_info "Docker image built successfully"
}

# Start services
start_services() {
    log_info "Starting services..."

    cd "${PROJECT_ROOT}"

    if docker compose version &> /dev/null; then
        docker compose -f "${COMPOSE_FILE}" up -d
    else
        docker-compose -f "${COMPOSE_FILE}" up -d
    fi

    log_info "Services started successfully"
    log_info "Waiting for services to be healthy..."

    sleep 10

    # Check health
    check_health
}

# Stop services
stop_services() {
    log_info "Stopping services..."

    cd "${PROJECT_ROOT}"

    if docker compose version &> /dev/null; then
        docker compose -f "${COMPOSE_FILE}" down
    else
        docker-compose -f "${COMPOSE_FILE}" down
    fi

    log_info "Services stopped successfully"
}

# Restart services
restart_services() {
    log_info "Restarting services..."
    stop_services
    start_services
}

# View logs
view_logs() {
    cd "${PROJECT_ROOT}"

    if docker compose version &> /dev/null; then
        docker compose -f "${COMPOSE_FILE}" logs -f
    else
        docker-compose -f "${COMPOSE_FILE}" logs -f
    fi
}

# Check service health
check_health() {
    log_info "Checking service health..."

    # Check main application
    if curl -f -s http://localhost:8080/health > /dev/null 2>&1; then
        log_info "LLM Config Manager is healthy"
    else
        log_warn "LLM Config Manager health check failed"
    fi

    # Check Prometheus
    if curl -f -s http://localhost:9091/-/healthy > /dev/null 2>&1; then
        log_info "Prometheus is healthy"
    else
        log_warn "Prometheus health check failed"
    fi

    # Check Grafana
    if curl -f -s http://localhost:3000/api/health > /dev/null 2>&1; then
        log_info "Grafana is healthy"
    else
        log_warn "Grafana health check failed"
    fi
}

# Show service status
show_status() {
    log_info "Service status:"

    cd "${PROJECT_ROOT}"

    if docker compose version &> /dev/null; then
        docker compose -f "${COMPOSE_FILE}" ps
    else
        docker-compose -f "${COMPOSE_FILE}" ps
    fi

    echo ""
    log_info "Access URLs:"
    echo "  - Application: http://localhost:8080"
    echo "  - Metrics: http://localhost:9090/metrics"
    echo "  - Prometheus: http://localhost:9091"
    echo "  - Grafana: http://localhost:3000 (admin/admin)"
}

# Main function
main() {
    local command="${1:-start}"

    case "${command}" in
        start)
            check_prerequisites
            create_env_file
            build_image
            start_services
            show_status
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            show_status
            ;;
        logs)
            view_logs
            ;;
        status)
            show_status
            ;;
        health)
            check_health
            ;;
        build)
            check_prerequisites
            build_image
            ;;
        *)
            echo "Usage: $0 [start|stop|restart|logs|status|health|build]"
            exit 1
            ;;
    esac
}

main "$@"
