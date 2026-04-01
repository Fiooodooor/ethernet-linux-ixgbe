#!/usr/bin/env bash
# TDD Test Script for Performance Framework
# Follows TDD-first principle: write failing test, then implement, then verify

set -euo pipefail

FRAMEWORK_DIR="/root/.clawteam/workspaces/nic-port-v2-rerun7/performance-engineer"
TEST_OUTPUT="/tmp/perf_test_output.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    exit 1
}

# Test 1: Framework compilation test
test_framework_compilation() {
    log "Testing performance framework compilation..."
    
    cd "$FRAMEWORK_DIR"
    
    # Compile for Linux target (we're on Linux, can't cross-compile FreeBSD easily)
    gcc -D__linux__ -DPERF_TEST_MODE -o perf_test_linux performance_framework.c 2>/dev/null || {
        fail "Performance framework failed to compile for Linux"
    }
    
    # Test compilation check for FreeBSD code paths (syntax check only)
    gcc -D__FreeBSD__ -fsyntax-only performance_framework.c 2>/dev/null || {
        log "Warning: FreeBSD compilation check failed (cross-compilation not available)"
    }
    
    pass "Framework compiles successfully for Linux target"
}

# Test 2: Basic functionality test
test_framework_functionality() {
    log "Testing performance framework basic functionality..."
    
    cd "$FRAMEWORK_DIR"
    
    # Run the test executable
    ./perf_test_linux > "$TEST_OUTPUT" 2>&1 || {
        fail "Performance framework test execution failed"
    }
    
    # Check for expected output patterns
    if grep -q "PASS:" "$TEST_OUTPUT"; then
        pass "Framework functionality tests passed"
    else
        fail "Framework functionality tests failed - see $TEST_OUTPUT"
    fi
    
    # Check for violation detection
    if grep -q "Budget violation correctly detected" "$TEST_OUTPUT"; then
        pass "Budget violation detection working"
    else
        fail "Budget violation detection not working"
    fi
    
    # Check for performance report generation
    if grep -q "=== IXGBE Performance Report ===" "$TEST_OUTPUT"; then
        pass "Performance report generation working"
    else
        fail "Performance report generation not working"
    fi
}

# Test 3: OAL seam compliance test
test_oal_seam_compliance() {
    log "Testing OAL seam compliance..."
    
    cd "$FRAMEWORK_DIR"
    
    # Check for forbidden framework usage in actual code (not comments)
    if grep -v '^[[:space:]]*\*' performance_framework.c performance_framework.h | grep -E '\biflib\b|\blinuxkpi\b|\brte_[a-zA-Z]|\bDPDK\b' | grep -v 'usage.*rejection'; then
        fail "Framework violates OAL seam rules - contains forbidden framework calls"
    fi
    
    # Check for proper OS abstraction
    if ! grep -q "#ifdef __FreeBSD__" performance_framework.c; then
        fail "Framework missing FreeBSD OS abstraction"
    fi
    
    if ! grep -E "#ifdef __linux__|#elif.*__linux__" performance_framework.c; then
        fail "Framework missing Linux OS abstraction"
    fi
    
    pass "OAL seam compliance verified - no framework contamination"
}

# Test 4: Performance budget validation test
test_performance_budgets() {
    log "Testing performance budget definitions..."
    
    cd "$FRAMEWORK_DIR"
    
    # Extract budget definitions
    if ! grep -q "PERF_BUDGET_.*_NS" performance_framework.c; then
        fail "Performance budgets not defined"
    fi
    
    # Validate reasonable budget values (not too strict, not too lenient)
    init_budget=$(grep "PERF_BUDGET_INIT_NS" performance_framework.c | grep -o '[0-9]\+' || echo "0")
    if [ "$init_budget" -lt 1000 ] || [ "$init_budget" -gt 1000000 ]; then
        fail "Init budget outside reasonable range: $init_budget ns"
    fi
    
    pass "Performance budgets defined with reasonable values"
}

# Test 5: Integration test preparation
test_integration_readiness() {
    log "Testing integration readiness..."
    
    cd "$FRAMEWORK_DIR"
    
    # Check header file exists and is includable
    if [ ! -f "performance_framework.h" ]; then
        fail "Performance framework header file missing"
    fi
    
    # Check for public API completeness
    required_functions=("perf_init" "perf_slice_start" "perf_slice_end" "perf_get_stats")
    for func in "${required_functions[@]}"; do
        if ! grep -q "$func" performance_framework.h; then
            fail "Missing required function declaration: $func"
        fi
    done
    
    pass "Framework ready for integration into IXGBE driver"
}

# Main test execution
main() {
    echo "=== TDD Performance Framework Tests ==="
    echo "Following TDD principle: write failing test, implement, verify"
    echo
    
    test_framework_compilation
    test_framework_functionality  
    test_oal_seam_compliance
    test_performance_budgets
    test_integration_readiness
    
    echo
    echo -e "${GREEN}=== ALL TESTS PASSED ===${NC}"
    echo "Performance framework is ready for integration"
    
    # Cleanup test artifacts
    rm -f "$FRAMEWORK_DIR/perf_test_linux"
    rm -f "$TEST_OUTPUT"
}

main "$@"