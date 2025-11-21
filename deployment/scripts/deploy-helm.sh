#!/usr/bin/env bash
#
# Deploy LLM Config Manager using Helm
#
# Usage: ./deploy-helm.sh [install|upgrade|uninstall|status]
#

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELM_CHART="${PROJECT_ROOT}/deployment/helm/llm-config-manager"
RELEASE_NAME="${RELEASE_NAME:-llm-config}"
NAMESPACE="${NAMESPACE:-llm-config}"
VALUES_FILE="${VALUES_FILE:-}"

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v helm &> /dev/null; then
        log_error "Helm is not installed"
        exit 1
    fi

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi

    log_info "Connected to cluster: $(kubectl config current-context)"
    log_info "Helm version: $(helm version --short)"
    log_info "Prerequisites check passed"
}

# Create values file
create_values_file() {
    local env="${1:-production}"
    local output_file="${PROJECT_ROOT}/deployment/helm/values-${env}.yaml"

    log_info "Creating values file for ${env} environment..."

    local encryption_key=$(openssl rand -base64 32)
    local db_password=$(openssl rand -base64 24)
    local redis_password=$(openssl rand -base64 24)
    local grafana_password=$(openssl rand -base64 16)

    cat > "${output_file}" <<EOF
# LLM Config Manager Helm Values - ${env}
# Generated: $(date)

replicaCount: 3

image:
  repository: llm-config-manager
  tag: "latest"
  pullPolicy: IfNotPresent

resources:
  limits:
    cpu: 2000m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

persistence:
  enabled: true
  storageClass: "standard"
  data:
    size: 50Gi
  cache:
    size: 20Gi
  backups:
    size: 100Gi
  logs:
    size: 10Gi

secrets:
  encryptionKey: "${encryption_key}"
  apiTokenSecret: "$(openssl rand -base64 32)"

postgresql:
  enabled: true
  auth:
    username: llm_config_user
    password: "${db_password}"
    database: llm_config
  primary:
    persistence:
      enabled: true
      size: 50Gi

redis:
  enabled: true
  auth:
    enabled: true
    password: "${redis_password}"
  master:
    persistence:
      enabled: true
      size: 10Gi

monitoring:
  prometheus:
    enabled: true
    serviceMonitor:
      enabled: true
  grafana:
    enabled: true
    adminUser: admin
    adminPassword: "${grafana_password}"

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: api.llm-config.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: llm-config-tls-cert
      hosts:
        - api.llm-config.example.com

networkPolicy:
  enabled: true
EOF

    chmod 600 "${output_file}"
    log_info "Values file created at ${output_file}"
    log_warn "IMPORTANT: Update the ingress host and store the generated passwords securely!"
    echo ""
    echo "Generated credentials:"
    echo "  - PostgreSQL password: ${db_password}"
    echo "  - Redis password: ${redis_password}"
    echo "  - Grafana password: ${grafana_password}"
    echo ""
}

# Install Helm dependencies
install_dependencies() {
    log_info "Installing Helm dependencies..."

    cd "${HELM_CHART}"
    helm dependency update

    log_info "Dependencies installed"
}

# Lint Helm chart
lint_chart() {
    log_info "Linting Helm chart..."

    local lint_args=("${HELM_CHART}")

    if [[ -n "${VALUES_FILE}" ]]; then
        lint_args+=("-f" "${VALUES_FILE}")
    fi

    helm lint "${lint_args[@]}"

    log_info "Lint passed"
}

# Dry run
dry_run() {
    log_info "Performing dry run..."

    local install_args=(
        "${RELEASE_NAME}"
        "${HELM_CHART}"
        "--namespace" "${NAMESPACE}"
        "--create-namespace"
        "--dry-run"
        "--debug"
    )

    if [[ -n "${VALUES_FILE}" ]]; then
        install_args+=("-f" "${VALUES_FILE}")
    fi

    helm install "${install_args[@]}"

    log_info "Dry run complete"
}

# Install chart
install_chart() {
    log_info "Installing Helm chart..."

    local install_args=(
        "${RELEASE_NAME}"
        "${HELM_CHART}"
        "--namespace" "${NAMESPACE}"
        "--create-namespace"
        "--wait"
        "--timeout" "10m"
    )

    if [[ -n "${VALUES_FILE}" ]]; then
        install_args+=("-f" "${VALUES_FILE}")
    fi

    helm install "${install_args[@]}"

    log_info "Installation complete"
}

# Upgrade chart
upgrade_chart() {
    log_info "Upgrading Helm chart..."

    local upgrade_args=(
        "${RELEASE_NAME}"
        "${HELM_CHART}"
        "--namespace" "${NAMESPACE}"
        "--wait"
        "--timeout" "10m"
        "--install"
    )

    if [[ -n "${VALUES_FILE}" ]]; then
        upgrade_args+=("-f" "${VALUES_FILE}")
    fi

    helm upgrade "${upgrade_args[@]}"

    log_info "Upgrade complete"
}

# Uninstall chart
uninstall_chart() {
    log_warn "Uninstalling Helm release..."

    read -p "Are you sure you want to uninstall ${RELEASE_NAME}? (yes/no): " confirm

    if [[ "${confirm}" != "yes" ]]; then
        log_info "Uninstall cancelled"
        exit 0
    fi

    helm uninstall "${RELEASE_NAME}" --namespace "${NAMESPACE}"

    log_info "Uninstall complete"

    read -p "Delete namespace ${NAMESPACE}? (yes/no): " delete_ns
    if [[ "${delete_ns}" == "yes" ]]; then
        kubectl delete namespace "${NAMESPACE}"
        log_info "Namespace deleted"
    fi
}

# Show status
show_status() {
    log_info "Release status:"

    helm status "${RELEASE_NAME}" --namespace "${NAMESPACE}"

    echo ""
    log_info "Pods:"
    kubectl get pods -n "${NAMESPACE}"

    echo ""
    log_info "Services:"
    kubectl get svc -n "${NAMESPACE}"
}

# Get values
get_values() {
    helm get values "${RELEASE_NAME}" --namespace "${NAMESPACE}"
}

# Rollback
rollback() {
    local revision="${1:-}"

    if [[ -z "${revision}" ]]; then
        log_info "Available revisions:"
        helm history "${RELEASE_NAME}" --namespace "${NAMESPACE}"
        read -p "Enter revision number to rollback to: " revision
    fi

    log_info "Rolling back to revision ${revision}..."

    helm rollback "${RELEASE_NAME}" "${revision}" --namespace "${NAMESPACE}" --wait

    log_info "Rollback complete"
}

# View logs
view_logs() {
    local pod=$(kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/name=llm-config-manager -o jsonpath='{.items[0].metadata.name}')

    if [[ -n "${pod}" ]]; then
        kubectl logs -n "${NAMESPACE}" -f "${pod}"
    else
        log_error "No pods found"
        exit 1
    fi
}

# Main function
main() {
    local command="${1:-install}"

    case "${command}" in
        install)
            check_prerequisites
            install_dependencies
            lint_chart
            install_chart
            show_status
            ;;
        upgrade)
            check_prerequisites
            lint_chart
            upgrade_chart
            show_status
            ;;
        uninstall)
            uninstall_chart
            ;;
        status)
            show_status
            ;;
        values)
            get_values
            ;;
        logs)
            view_logs
            ;;
        rollback)
            rollback "${2:-}"
            ;;
        lint)
            lint_chart
            ;;
        dry-run)
            check_prerequisites
            lint_chart
            dry_run
            ;;
        create-values)
            create_values_file "${2:-production}"
            ;;
        *)
            echo "Usage: $0 [install|upgrade|uninstall|status|values|logs|rollback|lint|dry-run|create-values]"
            echo ""
            echo "Environment variables:"
            echo "  RELEASE_NAME    - Helm release name (default: llm-config)"
            echo "  NAMESPACE       - Kubernetes namespace (default: llm-config)"
            echo "  VALUES_FILE     - Path to values file"
            exit 1
            ;;
    esac
}

main "$@"
