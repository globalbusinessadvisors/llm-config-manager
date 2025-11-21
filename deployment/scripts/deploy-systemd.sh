#!/usr/bin/env bash
#
# Deploy LLM Config Manager as a systemd service
#
# Usage: sudo ./deploy-systemd.sh [install|uninstall|start|stop|restart|status|logs]
#

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SYSTEMD_DIR="${PROJECT_ROOT}/deployment/systemd"
BINARY_PATH="/usr/local/bin/llm-config-server"
CONFIG_PATH="/etc/llm-config/config.yaml"
ENV_PATH="/etc/llm-config/environment"
SECRETS_PATH="/etc/default/llm-config-manager"
SERVICE_USER="llmconfig"
SERVICE_GROUP="llmconfig"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v systemctl &> /dev/null; then
        log_error "systemd is not available on this system"
        exit 1
    fi

    if [[ ! -f "${PROJECT_ROOT}/target/release/llm-config-server" ]]; then
        log_error "Binary not found. Please build the project first with: cargo build --release"
        exit 1
    fi

    log_info "Prerequisites check passed"
}

# Create service user
create_user() {
    if id "${SERVICE_USER}" &> /dev/null; then
        log_info "User ${SERVICE_USER} already exists"
    else
        log_info "Creating service user ${SERVICE_USER}..."
        useradd -r -s /bin/false -m -d /var/lib/llm-config "${SERVICE_USER}"
        log_info "User created"
    fi
}

# Create directories
create_directories() {
    log_info "Creating directories..."

    mkdir -p /var/lib/llm-config/{data,cache,backups}
    mkdir -p /var/log/llm-config
    mkdir -p /etc/llm-config

    chown -R "${SERVICE_USER}:${SERVICE_GROUP}" /var/lib/llm-config
    chown -R "${SERVICE_USER}:${SERVICE_GROUP}" /var/log/llm-config
    chown -R "${SERVICE_USER}:${SERVICE_GROUP}" /etc/llm-config

    chmod 755 /var/lib/llm-config
    chmod 755 /var/log/llm-config
    chmod 755 /etc/llm-config

    log_info "Directories created"
}

# Install binary
install_binary() {
    log_info "Installing binary..."

    cp "${PROJECT_ROOT}/target/release/llm-config-server" "${BINARY_PATH}"
    chmod 755 "${BINARY_PATH}"
    chown root:root "${BINARY_PATH}"

    log_info "Binary installed at ${BINARY_PATH}"
}

# Install configuration
install_config() {
    log_info "Installing configuration..."

    # Copy production config
    if [[ -f "${PROJECT_ROOT}/config/production.yaml" ]]; then
        cp "${PROJECT_ROOT}/config/production.yaml" "${CONFIG_PATH}"
        chown "${SERVICE_USER}:${SERVICE_GROUP}" "${CONFIG_PATH}"
        chmod 600 "${CONFIG_PATH}"
        log_info "Configuration installed at ${CONFIG_PATH}"
    else
        log_warn "Production config not found, skipping..."
    fi

    # Copy environment file
    if [[ ! -f "${ENV_PATH}" ]]; then
        cp "${SYSTEMD_DIR}/environment" "${ENV_PATH}"
        chown "${SERVICE_USER}:${SERVICE_GROUP}" "${ENV_PATH}"
        chmod 600 "${ENV_PATH}"
        log_info "Environment file installed at ${ENV_PATH}"
    else
        log_info "Environment file already exists"
    fi
}

# Create secrets file
create_secrets() {
    if [[ -f "${SECRETS_PATH}" ]]; then
        log_info "Secrets file already exists"
        return
    fi

    log_info "Creating secrets file..."

    local encryption_key=$(openssl rand -base64 32)
    local db_password=$(openssl rand -base64 24)
    local redis_password=$(openssl rand -base64 24)

    cat > "${SECRETS_PATH}" <<EOF
# LLM Config Manager Secrets
# Generated: $(date)

# Encryption key
LLM_CONFIG_ENCRYPTION_KEY=${encryption_key}

# Database password
DATABASE_PASSWORD=${db_password}

# Redis password
REDIS_PASSWORD=${redis_password}

# API token
API_TOKEN_SECRET=$(openssl rand -base64 32)
EOF

    chmod 600 "${SECRETS_PATH}"
    chown root:root "${SECRETS_PATH}"

    log_info "Secrets file created at ${SECRETS_PATH}"
    log_warn "IMPORTANT: Store these credentials securely!"
    echo ""
    echo "Generated credentials:"
    echo "  - Database password: ${db_password}"
    echo "  - Redis password: ${redis_password}"
    echo ""
}

# Install systemd units
install_systemd_units() {
    log_info "Installing systemd units..."

    cp "${SYSTEMD_DIR}"/*.service /etc/systemd/system/
    cp "${SYSTEMD_DIR}"/*.timer /etc/systemd/system/

    chmod 644 /etc/systemd/system/llm-config-*.service
    chmod 644 /etc/systemd/system/llm-config-*.timer

    systemctl daemon-reload

    log_info "Systemd units installed"
}

# Enable services
enable_services() {
    log_info "Enabling services..."

    systemctl enable llm-config-manager.service
    systemctl enable llm-config-backup.timer
    systemctl enable llm-config-cleanup.timer
    systemctl enable llm-config-healthcheck.timer

    log_info "Services enabled"
}

# Start services
start_services() {
    log_info "Starting services..."

    systemctl start llm-config-manager.service
    systemctl start llm-config-backup.timer
    systemctl start llm-config-cleanup.timer
    systemctl start llm-config-healthcheck.timer

    log_info "Services started"
}

# Stop services
stop_services() {
    log_info "Stopping services..."

    systemctl stop llm-config-manager.service || true
    systemctl stop llm-config-backup.timer || true
    systemctl stop llm-config-cleanup.timer || true
    systemctl stop llm-config-healthcheck.timer || true

    log_info "Services stopped"
}

# Restart services
restart_services() {
    log_info "Restarting services..."

    systemctl restart llm-config-manager.service

    log_info "Services restarted"
}

# Show status
show_status() {
    log_info "Service status:"

    systemctl status llm-config-manager.service || true

    echo ""
    log_info "Timer status:"
    systemctl list-timers llm-config-*
}

# View logs
view_logs() {
    journalctl -u llm-config-manager -f
}

# Uninstall
uninstall() {
    log_warn "Uninstalling LLM Config Manager..."

    read -p "Are you sure you want to uninstall? (yes/no): " confirm

    if [[ "${confirm}" != "yes" ]]; then
        log_info "Uninstall cancelled"
        exit 0
    fi

    # Stop and disable services
    stop_services
    systemctl disable llm-config-manager.service || true
    systemctl disable llm-config-backup.timer || true
    systemctl disable llm-config-cleanup.timer || true
    systemctl disable llm-config-healthcheck.timer || true

    # Remove systemd units
    rm -f /etc/systemd/system/llm-config-*.service
    rm -f /etc/systemd/system/llm-config-*.timer
    systemctl daemon-reload

    # Remove binary
    rm -f "${BINARY_PATH}"

    # Remove configuration (optional)
    read -p "Remove configuration files? (yes/no): " remove_config
    if [[ "${remove_config}" == "yes" ]]; then
        rm -rf /etc/llm-config
        rm -f "${SECRETS_PATH}"
    fi

    # Remove data (optional)
    read -p "Remove data directories? This will delete all data! (yes/no): " remove_data
    if [[ "${remove_data}" == "yes" ]]; then
        rm -rf /var/lib/llm-config
        rm -rf /var/log/llm-config
    fi

    log_info "Uninstall complete"
}

# Full installation
full_install() {
    check_root
    check_prerequisites
    create_user
    create_directories
    install_binary
    install_config
    create_secrets
    install_systemd_units
    enable_services
    start_services
    show_status

    echo ""
    log_info "Installation complete!"
    log_info "The service is now running"
    log_info "Access the application at http://localhost:8080"
    log_info "View logs with: sudo journalctl -u llm-config-manager -f"
}

# Main function
main() {
    local command="${1:-install}"

    case "${command}" in
        install)
            full_install
            ;;
        uninstall)
            check_root
            uninstall
            ;;
        start)
            check_root
            start_services
            show_status
            ;;
        stop)
            check_root
            stop_services
            ;;
        restart)
            check_root
            restart_services
            show_status
            ;;
        status)
            show_status
            ;;
        logs)
            view_logs
            ;;
        *)
            echo "Usage: sudo $0 [install|uninstall|start|stop|restart|status|logs]"
            exit 1
            ;;
    esac
}

main "$@"
