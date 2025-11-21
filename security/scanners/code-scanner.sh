#!/usr/bin/env bash
#
# Code Security Scanner for LLM Config Manager
#
# Performs static code analysis for security issues using cargo-clippy and other tools
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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v cargo &> /dev/null; then
        log_error "Cargo is not installed"
        exit 1
    fi

    log_info "Prerequisites check passed"
}

# Create report directory
create_report_dir() {
    mkdir -p "${REPORT_DIR}"
}

# Run Clippy with security lints
run_clippy() {
    log_section "Running Clippy Security Lints"

    cd "${PROJECT_ROOT}"

    local report_file="${REPORT_DIR}/clippy-security-${TIMESTAMP}.txt"

    log_info "Running cargo clippy with security lints..."

    # Security-focused clippy lints
    cargo clippy --all-targets --all-features -- \
        -W clippy::all \
        -W clippy::pedantic \
        -W clippy::nursery \
        -W clippy::cargo \
        -W unsafe-code \
        -W missing-docs \
        -A clippy::module-name-repetitions \
        -A clippy::missing-errors-doc \
        -A clippy::missing-panics-doc \
        > "${report_file}" 2>&1 || true

    cat "${report_file}"

    # Count issues
    local issue_count=$(grep -c "warning:" "${report_file}" || echo "0")
    log_info "Found ${issue_count} potential issues"

    if [ "${issue_count}" -gt 0 ]; then
        return 1
    fi

    return 0
}

# Scan for unsafe code
scan_unsafe_code() {
    log_section "Scanning for Unsafe Code"

    cd "${PROJECT_ROOT}"

    local report_file="${REPORT_DIR}/unsafe-code-${TIMESTAMP}.txt"

    log_info "Searching for unsafe code blocks..."

    # Find all unsafe blocks
    grep -rn "unsafe" --include="*.rs" crates/ > "${report_file}" 2>&1 || true

    local unsafe_count=$(wc -l < "${report_file}" || echo "0")

    if [ "${unsafe_count}" -gt 0 ]; then
        log_warn "Found ${unsafe_count} instances of unsafe code"
        cat "${report_file}"
        echo "⚠ Review all unsafe code blocks for security implications"
    else
        log_info "✓ No unsafe code found"
        echo "No unsafe code blocks found" > "${report_file}"
    fi
}

# Scan for TODO/FIXME security comments
scan_security_todos() {
    log_section "Scanning for Security TODOs"

    cd "${PROJECT_ROOT}"

    local report_file="${REPORT_DIR}/security-todos-${TIMESTAMP}.txt"

    log_info "Searching for security-related TODOs..."

    # Search for security-related comments
    grep -rn -E "(TODO|FIXME|XXX|HACK).*(security|auth|crypto|password|secret|token)" \
        --include="*.rs" crates/ > "${report_file}" 2>&1 || true

    local todo_count=$(wc -l < "${report_file}" || echo "0")

    if [ "${todo_count}" -gt 0 ]; then
        log_warn "Found ${todo_count} security-related TODOs"
        cat "${report_file}"
    else
        log_info "✓ No security TODOs found"
        echo "No security-related TODOs found" > "${report_file}"
    fi
}

# Scan for hardcoded secrets
scan_secrets() {
    log_section "Scanning for Hardcoded Secrets"

    cd "${PROJECT_ROOT}"

    local report_file="${REPORT_DIR}/secrets-scan-${TIMESTAMP}.txt"

    log_info "Scanning for potential hardcoded secrets..."

    # Patterns to search for
    local patterns=(
        "password\s*=\s*['\"][^'\"]+['\"]"
        "api[_-]?key\s*=\s*['\"][^'\"]+['\"]"
        "secret\s*=\s*['\"][^'\"]+['\"]"
        "token\s*=\s*['\"][^'\"]+['\"]"
        "private[_-]?key\s*=\s*['\"][^'\"]+['\"]"
        "aws[_-]?access[_-]?key"
        "BEGIN (RSA|DSA|EC) PRIVATE KEY"
    )

    > "${report_file}"

    for pattern in "${patterns[@]}"; do
        grep -rn -iE "${pattern}" --include="*.rs" --include="*.toml" crates/ >> "${report_file}" 2>&1 || true
    done

    local secret_count=$(wc -l < "${report_file}" || echo "0")

    if [ "${secret_count}" -gt 0 ]; then
        log_warn "Found ${secret_count} potential hardcoded secrets"
        cat "${report_file}"
        log_warn "⚠ Review all findings - may contain false positives"
    else
        log_info "✓ No hardcoded secrets detected"
        echo "No hardcoded secrets detected" > "${report_file}"
    fi
}

# Check for SQL injection vulnerabilities
scan_sql_injection() {
    log_section "Scanning for Potential SQL Injection Vulnerabilities"

    cd "${PROJECT_ROOT}"

    local report_file="${REPORT_DIR}/sql-injection-${TIMESTAMP}.txt"

    log_info "Checking for unsafe SQL construction..."

    # Look for string concatenation with SQL queries
    grep -rn -E "format!\(.*SELECT|format!\(.*INSERT|format!\(.*UPDATE|format!\(.*DELETE" \
        --include="*.rs" crates/ > "${report_file}" 2>&1 || true

    # Also check for direct string interpolation
    grep -rn -E "\&format!\(.*sql" --include="*.rs" crates/ >> "${report_file}" 2>&1 || true

    local vuln_count=$(wc -l < "${report_file}" || echo "0")

    if [ "${vuln_count}" -gt 0 ]; then
        log_warn "Found ${vuln_count} potential SQL injection risks"
        cat "${report_file}"
        log_warn "⚠ Use parameterized queries instead of string concatenation"
    else
        log_info "✓ No obvious SQL injection vulnerabilities found"
        echo "No SQL injection vulnerabilities detected" > "${report_file}"
    fi
}

# Generate security report
generate_security_report() {
    log_section "Generating Security Code Analysis Report"

    local report_file="${REPORT_DIR}/code-security-report-${TIMESTAMP}.md"

    cat > "${report_file}" <<EOF
# Code Security Analysis Report
**Generated**: $(date)
**Project**: LLM Config Manager

## Summary

This report contains findings from static code security analysis.

## Clippy Security Lints

$(cat "${REPORT_DIR}/clippy-security-${TIMESTAMP}.txt" 2>/dev/null || echo "No results")

## Unsafe Code Analysis

$(cat "${REPORT_DIR}/unsafe-code-${TIMESTAMP}.txt" 2>/dev/null || echo "No unsafe code found")

## Security TODOs

$(cat "${REPORT_DIR}/security-todos-${TIMESTAMP}.txt" 2>/dev/null || echo "No security TODOs found")

## Hardcoded Secrets Scan

$(cat "${REPORT_DIR}/secrets-scan-${TIMESTAMP}.txt" 2>/dev/null || echo "No secrets detected")

## SQL Injection Vulnerability Scan

$(cat "${REPORT_DIR}/sql-injection-${TIMESTAMP}.txt" 2>/dev/null || echo "No SQL injection vulnerabilities found")

## Recommendations

1. Address all Clippy warnings
2. Review and justify all unsafe code blocks
3. Resolve security-related TODOs
4. Remove or properly secure any hardcoded credentials
5. Use parameterized queries for all SQL operations
6. Enable additional security lints in CI/CD

## Best Practices

- Avoid unsafe code when possible
- Use the security crate for input validation
- Never hardcode secrets
- Use prepared statements for SQL
- Keep dependencies up to date
- Enable all security-related compiler warnings

EOF

    log_info "Security report generated: ${report_file}"
}

# Display summary
display_summary() {
    log_section "Scan Summary"

    echo "Report directory: ${REPORT_DIR}"
    echo "Latest reports:"
    ls -lht "${REPORT_DIR}" | grep -E "clippy|unsafe|todos|secrets|sql" | head -10
}

# Main function
main() {
    log_info "Starting Code Security Analysis"
    log_info "Project: ${PROJECT_ROOT}"

    check_prerequisites
    create_report_dir

    local exit_code=0

    if ! run_clippy; then
        exit_code=1
    fi

    scan_unsafe_code
    scan_security_todos
    scan_secrets
    scan_sql_injection
    generate_security_report
    display_summary

    if [ ${exit_code} -eq 0 ]; then
        log_info "✓ Code security scan completed successfully"
    else
        log_warn "⚠ Code security scan completed with findings - Review required"
    fi

    exit ${exit_code}
}

main "$@"
