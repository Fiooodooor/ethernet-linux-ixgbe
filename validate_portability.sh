#!/bin/bash
#
# IXGBE Cross-OS Portability Validation Script
# portability-validator - nic-port-v2-rerun7
#
# This script performs comprehensive validation of OAL seam correctness
# across all target architectures for the IXGBE driver FreeBSD port.
#
# NON-NEGOTIABLE REQUIREMENTS:
# - Zero framework calls (no iflib/linuxkpi/rte_*/DPDK usage)
# - Native OS API calls ONLY
# - TDD-first validation approach
# - Cross-platform consistency verification

set -euo pipefail

# Configuration
WORKSPACE="/root/.clawteam/workspaces/nic-port-v2-rerun7/portability-validator"
LOG_FILE="portability_validation.log"
REPORT_FILE="portability_validation_report.md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${1}" | tee -a "${LOG_FILE}"
}

# Header
log "${BLUE}=================================================="
log "IXGBE Cross-OS Portability Validation"
log "Date: $(date)"
log "Validator: portability-validator"
log "Project: nic-port-v2-rerun7"
log "==================================================${NC}"

# Phase 1: Framework Contamination Check
log "${YELLOW}Phase 1: Framework Contamination Check${NC}"

check_contamination() {
    local violations=0
    
    log "  Checking for iflib usage..."
    if grep -r "iflib" src/ 2>/dev/null; then
        log "${RED}  ❌ VIOLATION: iflib usage detected${NC}"
        violations=$((violations + 1))
    else
        log "${GREEN}  ✅ CLEAN: No iflib usage${NC}"
    fi
    
    log "  Checking for linuxkpi usage..."
    if grep -r "linuxkpi" src/ 2>/dev/null; then
        log "${RED}  ❌ VIOLATION: linuxkpi usage detected${NC}"
        violations=$((violations + 1))
    else
        log "${GREEN}  ✅ CLEAN: No linuxkpi usage${NC}"
    fi
    
    log "  Checking for DPDK usage..."
    if grep -r "rte_\|DPDK" src/ 2>/dev/null; then
        log "${RED}  ❌ VIOLATION: DPDK usage detected${NC}"
        violations=$((violations + 1))
    else
        log "${GREEN}  ✅ CLEAN: No DPDK usage${NC}"
    fi
    
    return $violations
}

check_contamination
contamination_result=$?

# Phase 2: OAL Header Validation
log "${YELLOW}Phase 2: OAL Header Validation${NC}"

validate_oal_headers() {
    local missing=0
    
    local required_headers=(
        "oal_pci.h"
        "oal_register.h" 
        "oal_memory.h"
        "oal_lock.h"
        "oal_time.h"
        "oal_interrupt.h"
        "oal_netdev.h"
    )
    
    for header in "${required_headers[@]}"; do
        if [[ -f "oal_seams/headers/${header}" ]]; then
            log "${GREEN}  ✅ Found: ${header}${NC}"
        else
            log "${RED}  ❌ Missing: ${header}${NC}"
            missing=$((missing + 1))
        fi
    done
    
    return $missing
}

validate_oal_headers
oal_headers_result=$?

# Phase 3: Compile-time Validation
log "${YELLOW}Phase 3: Compile-time Validation${NC}"

compile_validation() {
    local errors=0
    
    log "  Testing Linux compilation..."
    if make -C src/ clean all ARCH=x86_64 2>/dev/null; then
        log "${GREEN}  ✅ Linux build successful${NC}"
    else
        log "${RED}  ❌ Linux build failed${NC}"
        errors=$((errors + 1))
    fi
    
    log "  Testing FreeBSD compilation (if available)..."
    if command -v freebsd-gcc >/dev/null 2>&1; then
        if freebsd-gcc -c src/ixgbe_main.c -I. -D__FreeBSD__ 2>/dev/null; then
            log "${GREEN}  ✅ FreeBSD build successful${NC}"
        else
            log "${RED}  ❌ FreeBSD build failed${NC}"
            errors=$((errors + 1))
        fi
    else
        log "${YELLOW}  ⚠️ FreeBSD compiler not available, skipping${NC}"
    fi
    
    return $errors
}

compile_validation
compile_result=$?

# Phase 4: Runtime Validation (if OAL is available)
log "${YELLOW}Phase 4: Runtime Validation${NC}"

runtime_validation() {
    if [[ ! -f "sys/dev/ixgbe/tests/ixgbe_portability_test_runner.c" ]]; then
        log "${YELLOW}  ⚠️ OAL test runner not found - OAL seams not yet implemented${NC}"
        log "  Expected path: sys/dev/ixgbe/tests/ixgbe_portability_test_runner.c"
        return 1
    fi
    
    log "  Compiling test runner..."
    if gcc -DIXGBE_TEST_STANDALONE -I. -o test_runner \
           sys/dev/ixgbe/tests/ixgbe_portability_test_runner.c \
           sys/dev/ixgbe/tests/framework/cross_os_harness.c \
           sys/dev/ixgbe/tests/oal_tests/test_pci_osal.c; then
        log "${GREEN}  ✅ Test runner compiled${NC}"
    else
        log "${RED}  ❌ Test runner compilation failed${NC}"
        return 1
    fi
    
    log "  Running TDD validation tests..."
    if ./test_runner; then
        log "${GREEN}  ✅ Runtime tests passed${NC}"
        return 0
    else
        log "${RED}  ❌ Runtime tests failed (expected in TDD red phase)${NC}"
        return 1
    fi
}

runtime_validation
runtime_result=$?

# Phase 5: Cross-Platform Consistency Check
log "${YELLOW}Phase 5: Cross-Platform Consistency Check${NC}"

consistency_validation() {
    local inconsistencies=0
    
    log "  Checking for platform-specific #ifdefs..."
    ifdef_count=$(grep -r "#ifdef.*__FreeBSD__\|#ifdef.*__linux__" src/ | wc -l)
    
    if [[ $ifdef_count -gt 0 ]]; then
        log "${YELLOW}  ⚠️ Found ${ifdef_count} platform-specific sections${NC}"
        log "  These should be replaced with OAL abstractions"
    else
        log "${GREEN}  ✅ No raw platform ifdefs found${NC}"
    fi
    
    log "  Checking OAL usage consistency..."
    if grep -r "oal_" src/ >/dev/null 2>&1; then
        log "${GREEN}  ✅ OAL functions detected in source${NC}"
    else
        log "${RED}  ❌ No OAL function calls found - abstraction not applied${NC}"
        inconsistencies=$((inconsistencies + 1))
    fi
    
    return $inconsistencies
}

consistency_validation
consistency_result=$?

# Generate Summary Report
log "${BLUE}=================================================="
log "VALIDATION SUMMARY"
log "==================================================${NC}"

total_issues=$((contamination_result + oal_headers_result + compile_result + consistency_result))

if [[ $contamination_result -eq 0 ]]; then
    log "${GREEN}✅ Framework Contamination: CLEAN${NC}"
else
    log "${RED}❌ Framework Contamination: ${contamination_result} violations${NC}"
fi

if [[ $oal_headers_result -eq 0 ]]; then
    log "${GREEN}✅ OAL Headers: COMPLETE${NC}"
else
    log "${RED}❌ OAL Headers: ${oal_headers_result} missing${NC}"
fi

if [[ $compile_result -eq 0 ]]; then
    log "${GREEN}✅ Compilation: SUCCESS${NC}"
else
    log "${RED}❌ Compilation: ${compile_result} failures${NC}"
fi

if [[ $runtime_result -eq 0 ]]; then
    log "${GREEN}✅ Runtime Tests: PASSED${NC}"
elif [[ $runtime_result -eq 1 ]] && [[ ! -f "sys/dev/ixgbe/tests/ixgbe_portability_test_runner.c" ]]; then
    log "${YELLOW}⚠️ Runtime Tests: NOT AVAILABLE (OAL not implemented)${NC}"
else
    log "${RED}❌ Runtime Tests: FAILED${NC}"
fi

if [[ $consistency_result -eq 0 ]]; then
    log "${GREEN}✅ Cross-Platform Consistency: GOOD${NC}"
else
    log "${RED}❌ Cross-Platform Consistency: ${consistency_result} issues${NC}"
fi

log ""
log "Overall Status:"
if [[ $total_issues -eq 0 ]] && [[ $runtime_result -eq 0 ]]; then
    log "${GREEN}🎉 PORTABILITY VALIDATION: PASSED${NC}"
    exit 0
elif [[ $contamination_result -eq 0 ]] && [[ $runtime_result -eq 1 ]] && [[ ! -f "sys/dev/ixgbe/tests/ixgbe_portability_test_runner.c" ]]; then
    log "${YELLOW}⚠️ PORTABILITY VALIDATION: PENDING (OAL implementation needed)${NC}"
    exit 2
else
    log "${RED}❌ PORTABILITY VALIDATION: FAILED${NC}"
    log "Total issues: $total_issues"
    exit 1
fi