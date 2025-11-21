#!/usr/bin/env bash
#
# Deploy LLM Config Manager to Kubernetes
#
# Usage: ./deploy-kubernetes.sh [install|upgrade|uninstall|status]
#

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
K8S_DIR="${PROJECT_ROOT}/deployment/kubernetes"
NAMESPACE="llm-config"

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

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi

    log_info "Connected to cluster: $(kubectl config current-context)"
    log_info "Prerequisites check passed"
}

# Generate secrets
generate_secrets() {
    log_info "Generating secrets..."

    local encryption_key=$(openssl rand -base64 32)
    local db_password=$(openssl rand -base64 24)
    local redis_password=$(openssl rand -base64 24)

    # Create temporary secrets file
    cat > "${K8S_DIR}/secrets-generated.yaml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: llm-config-manager-secrets
  namespace: ${NAMESPACE}
  labels:
    app: llm-config-manager
type: Opaque
stringData:
  ENCRYPTION_KEY: "${encryption_key}"
  API_TOKEN_SECRET: "$(openssl rand -base64 32)"

---
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secrets
  namespace: ${NAMESPACE}
type: Opaque
stringData:
  POSTGRES_PASSWORD: "${db_password}"
  POSTGRES_USER: "llm_config_user"
  POSTGRES_DB: "llm_config"

---
apiVersion: v1
kind: Secret
metadata:
  name: redis-secrets
  namespace: ${NAMESPACE}
type: Opaque
stringData:
  REDIS_PASSWORD: "${redis_password}"
EOF

    log_info "Secrets generated at ${K8S_DIR}/secrets-generated.yaml"
    log_warn "Store these credentials securely!"
}

# Install using kubectl
install_kubectl() {
    log_info "Installing with kubectl..."

    # Create namespace
    kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

    # Apply manifests
    log_info "Applying manifests..."
    kubectl apply -f "${K8S_DIR}/namespace.yaml"
    kubectl apply -f "${K8S_DIR}/secrets-generated.yaml"
    kubectl apply -f "${K8S_DIR}/configmap.yaml"
    kubectl apply -f "${K8S_DIR}/pvc.yaml"
    kubectl apply -f "${K8S_DIR}/rbac.yaml"
    kubectl apply -f "${K8S_DIR}/postgres.yaml"
    kubectl apply -f "${K8S_DIR}/redis.yaml"
    kubectl apply -f "${K8S_DIR}/deployment.yaml"
    kubectl apply -f "${K8S_DIR}/service.yaml"
    kubectl apply -f "${K8S_DIR}/ingress.yaml"
    kubectl apply -f "${K8S_DIR}/hpa.yaml"
    kubectl apply -f "${K8S_DIR}/pdb.yaml"
    kubectl apply -f "${K8S_DIR}/networkpolicy.yaml"

    # Optional: ServiceMonitor (requires Prometheus Operator)
    if kubectl get crd servicemonitors.monitoring.coreos.com &> /dev/null; then
        log_info "Installing ServiceMonitor..."
        kubectl apply -f "${K8S_DIR}/servicemonitor.yaml"
    else
        log_warn "Prometheus Operator not detected, skipping ServiceMonitor"
    fi

    log_info "Installation complete"
}

# Install using kustomize
install_kustomize() {
    log_info "Installing with kustomize..."

    kubectl apply -k "${K8S_DIR}"

    log_info "Installation complete"
}

# Wait for deployment
wait_for_deployment() {
    log_info "Waiting for deployment to be ready..."

    kubectl wait --for=condition=available --timeout=300s \
        deployment/llm-config-manager -n "${NAMESPACE}"

    log_info "Deployment is ready"
}

# Check health
check_health() {
    log_info "Checking application health..."

    local pod=$(kubectl get pods -n "${NAMESPACE}" -l app=llm-config-manager -o jsonpath='{.items[0].metadata.name}')

    if [[ -n "${pod}" ]]; then
        kubectl exec -n "${NAMESPACE}" "${pod}" -- curl -f http://localhost:8080/health
        log_info "Health check passed"
    else
        log_error "No pods found"
        return 1
    fi
}

# Show status
show_status() {
    log_info "Deployment status:"

    echo ""
    echo "=== Pods ==="
    kubectl get pods -n "${NAMESPACE}"

    echo ""
    echo "=== Services ==="
    kubectl get svc -n "${NAMESPACE}"

    echo ""
    echo "=== Ingress ==="
    kubectl get ingress -n "${NAMESPACE}"

    echo ""
    echo "=== PVCs ==="
    kubectl get pvc -n "${NAMESPACE}"

    echo ""
    echo "=== HPA ==="
    kubectl get hpa -n "${NAMESPACE}"
}

# View logs
view_logs() {
    local pod=$(kubectl get pods -n "${NAMESPACE}" -l app=llm-config-manager -o jsonpath='{.items[0].metadata.name}')

    if [[ -n "${pod}" ]]; then
        kubectl logs -n "${NAMESPACE}" -f "${pod}"
    else
        log_error "No pods found"
        exit 1
    fi
}

# Port forward
port_forward() {
    local pod=$(kubectl get pods -n "${NAMESPACE}" -l app=llm-config-manager -o jsonpath='{.items[0].metadata.name}')

    if [[ -n "${pod}" ]]; then
        log_info "Port forwarding to ${pod}..."
        log_info "Application will be available at http://localhost:8080"
        kubectl port-forward -n "${NAMESPACE}" "${pod}" 8080:8080
    else
        log_error "No pods found"
        exit 1
    fi
}

# Upgrade deployment
upgrade_deployment() {
    log_info "Upgrading deployment..."

    kubectl apply -f "${K8S_DIR}/configmap.yaml"
    kubectl apply -f "${K8S_DIR}/deployment.yaml"

    kubectl rollout status deployment/llm-config-manager -n "${NAMESPACE}"

    log_info "Upgrade complete"
}

# Uninstall
uninstall() {
    log_warn "Uninstalling LLM Config Manager..."

    read -p "Are you sure you want to uninstall? This will delete all resources. (yes/no): " confirm

    if [[ "${confirm}" != "yes" ]]; then
        log_info "Uninstall cancelled"
        exit 0
    fi

    kubectl delete -k "${K8S_DIR}" || true
    kubectl delete namespace "${NAMESPACE}" || true

    # Cleanup generated secrets
    rm -f "${K8S_DIR}/secrets-generated.yaml"

    log_info "Uninstall complete"
}

# Main function
main() {
    local command="${1:-install}"

    case "${command}" in
        install)
            check_prerequisites
            generate_secrets
            install_kubectl
            wait_for_deployment
            check_health
            show_status
            ;;
        install-kustomize)
            check_prerequisites
            generate_secrets
            install_kustomize
            wait_for_deployment
            check_health
            show_status
            ;;
        upgrade)
            check_prerequisites
            upgrade_deployment
            show_status
            ;;
        uninstall)
            uninstall
            ;;
        status)
            show_status
            ;;
        logs)
            view_logs
            ;;
        health)
            check_health
            ;;
        port-forward)
            port_forward
            ;;
        *)
            echo "Usage: $0 [install|install-kustomize|upgrade|uninstall|status|logs|health|port-forward]"
            exit 1
            ;;
    esac
}

main "$@"
