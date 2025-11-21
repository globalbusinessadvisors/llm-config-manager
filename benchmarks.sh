#!/bin/bash
# Performance Benchmark Runner for LLM Config Manager
#
# This script runs all performance benchmarks and generates reports.
# Benchmarks use Criterion.rs framework for accurate performance measurements.

set -e

echo "========================================"
echo "LLM Config Manager - Performance Benchmarks"
echo "========================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to run benchmarks for a crate
run_bench() {
    local crate=$1
    echo -e "${BLUE}Running benchmarks for: $crate${NC}"
    cargo bench --package $crate
    echo ""
}

# Parse command line arguments
BENCH_TARGET="${1:-all}"

case "$BENCH_TARGET" in
    "core")
        run_bench "llm-config-core"
        ;;
    "cache")
        run_bench "llm-config-cache"
        ;;
    "crypto")
        run_bench "llm-config-crypto"
        ;;
    "rbac")
        run_bench "llm-config-rbac"
        ;;
    "all")
        echo "Running all benchmarks..."
        echo ""
        run_bench "llm-config-core"
        run_bench "llm-config-cache"
        run_bench "llm-config-crypto"
        run_bench "llm-config-rbac"
        ;;
    "help")
        echo "Usage: ./benchmarks.sh [target]"
        echo ""
        echo "Targets:"
        echo "  core   - Run core configuration manager benchmarks"
        echo "  cache  - Run cache performance benchmarks"
        echo "  crypto - Run cryptographic operation benchmarks"
        echo "  rbac   - Run RBAC permission checking benchmarks"
        echo "  all    - Run all benchmarks (default)"
        echo "  help   - Show this help message"
        echo ""
        echo "Examples:"
        echo "  ./benchmarks.sh           # Run all benchmarks"
        echo "  ./benchmarks.sh core      # Run only core benchmarks"
        echo "  ./benchmarks.sh cache     # Run only cache benchmarks"
        exit 0
        ;;
    *)
        echo "Unknown target: $BENCH_TARGET"
        echo "Run './benchmarks.sh help' for usage information"
        exit 1
        ;;
esac

echo -e "${GREEN}✓ Benchmark run complete${NC}"
echo ""
echo "Results are saved in target/criterion/"
echo "Open target/criterion/report/index.html to view detailed results"
