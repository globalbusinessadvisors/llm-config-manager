#!/usr/bin/env bash
#
# Dependency Vulnerability Scanner for LLM Config Manager
#
# Scans project dependencies for known vulnerabilities using cargo-audit
#

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REPORT_DIR="${PROJECT_ROOT}/security/reports"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_section() {
    echo -e "\n${BLUE}==== $* ====${NC}\n"
}

# Check if cargo-audit is installed
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v cargo &> /dev/null; then
        log_error "Cargo is not installed"
        exit 1
    fi

    if ! cargo audit --version &> /dev/null; then
        log_warn "cargo-audit not found. Installing..."
        cargo install cargo-audit
    fi

    log_info "Prerequisites check passed"
}

# Create report directory
create_report_dir() {
    mkdir -p "${REPORT_DIR}"
}

# Scan dependencies for vulnerabilities
scan_dependencies() {
    log_section "Scanning Dependencies for Vulnerabilities"

    cd "${PROJECT_ROOT}"

    local report_file="${REPORT_DIR}/dependency-scan-${TIMESTAMP}.json"
    local summary_file="${REPORT_DIR}/dependency-scan-${TIMESTAMP}.txt"

    # Run cargo audit
    log_info "Running cargo audit..."

    if cargo audit --json > "${report_file}" 2>&1; then
        log_info "✓ No vulnerabilities found"
        echo "Scan completed: $(date)" > "${summary_file}"
        echo "Status: PASSED" >> "${summary_file}"
        echo "Vulnerabilities: 0" >> "${summary_file}"
        return 0
    else
        log_warn "⚠ Vulnerabilities detected"

        # Generate human-readable summary
        cargo audit 2>&1 | tee "${summary_file}"

        # Count vulnerabilities
        local vuln_count=$(jq '.vulnerabilities.count' "${report_file}" 2>/dev/null || echo "unknown")
        log_warn "Found ${vuln_count} vulnerabilities"

        return 1
    fi
}

# Check for outdated dependencies
check_outdated() {
    log_section "Checking for Outdated Dependencies"

    cd "${PROJECT_ROOT}"

    local report_file="${REPORT_DIR}/outdated-deps-${TIMESTAMP}.txt"

    if command -v cargo-outdated &> /dev/null; then
        log_info "Running cargo-outdated..."
        cargo outdated > "${report_file}" 2>&1
        cat "${report_file}"
    else
        log_warn "cargo-outdated not installed. Install with: cargo install cargo-outdated"
    fi
}

# Check for unused dependencies
check_unused() {
    log_section "Checking for Unused Dependencies"

    cd "${PROJECT_ROOT}"

    if command -v cargo-udeps &> /dev/null; then
        log_info "Running cargo-udeps..."
        local report_file="${REPORT_DIR}/unused-deps-${TIMESTAMP}.txt"
        cargo +nightly udeps --all-targets > "${report_file}" 2>&1 || true
        cat "${report_file}"
    else
        log_warn "cargo-udeps not installed. Install with: cargo install cargo-udeps"
    fi
}

# Generate security advisory report
generate_advisory_report() {
    log_section "Generating Security Advisory Report"

    local advisory_file="${REPORT_DIR}/security-advisory-${TIMESTAMP}.md"

    cat > "${advisory_file}" <<EOF
# Security Advisory Report
**Generated**: $(date)
**Project**: LLM Config Manager

## Summary

This report contains security findings from dependency vulnerability scanning.

## Vulnerability Scan Results

$(cat "${REPORT_DIR}/dependency-scan-${TIMESTAMP}.txt" 2>/dev/null || echo "No scan results available")

## Recommendations

1. Update all dependencies with known vulnerabilities
2. Review and apply security patches
3. Monitor for new advisories
4. Consider alternative dependencies if patches are not available

## Next Steps

- Review each vulnerability
- Assess impact on the project
- Plan remediation
- Update dependencies
- Re-run scan to verify fixes

## Resources

- RustSec Advisory Database: https://rustsec.org/
- Cargo Audit Documentation: https://github.com/RustSec/rustsec/tree/main/cargo-audit

EOF

    log_info "Advisory report generated: ${advisory_file}"
}

# Display summary
display_summary() {
    log_section "Scan Summary"

    echo "Report directory: ${REPORT_DIR}"
    echo "Latest reports:"
    ls -lht "${REPORT_DIR}" | head -10
}

# Main function
main() {
    log_info "Starting Dependency Security Scan"
    log_info "Project: ${PROJECT_ROOT}"

    check_prerequisites
    create_report_dir

    local exit_code=0

    if ! scan_dependencies; then
        exit_code=1
    fi

    check_outdated
    check_unused
    generate_advisory_report
    display_summary

    if [ ${exit_code} -eq 0 ]; then
        log_info "✓ Security scan completed successfully - No vulnerabilities found"
    else
        log_warn "⚠ Security scan completed with findings - Review required"
    fi

    exit ${exit_code}
}

main "$@"
