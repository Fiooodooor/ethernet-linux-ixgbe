#!/bin/bash
# Comprehensive Verification Execution - Main Runner
set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

WORKSPACE="/root/.clawteam/workspaces/nic-port-v2-rerun7/verification-executor"
LOG_DIR="$WORKSPACE/verification_logs"
RESULTS_DIR="$WORKSPACE/verification_results"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

cd "$WORKSPACE"

echo -e "${BLUE}=== COMPREHENSIVE VERIFICATION EXECUTION ===${NC}"
echo "Timestamp: $(date)"
echo "Workspace: $WORKSPACE"
echo "Logs: $LOG_DIR"
echo

GATES_PASSED=0
GATES_FAILED=0

# Function to run gate
run_gate() {
    local gate_name="$1"
    local gate_script="$2"
    local log_file="$LOG_DIR/${gate_name}_${TIMESTAMP}.log"
    
    echo -e "${BLUE}--- $gate_name ---${NC}"
    
    if [ -f "$gate_script" ] && [ -x "$gate_script" ]; then
        if ./"$gate_script" > "$log_file" 2>&1; then
            echo -e "${GREEN}✓ $gate_name PASSED${NC}"
            ((GATES_PASSED++))
        else
            echo -e "${RED}✗ $gate_name FAILED${NC}"
            echo "See $log_file for details"
            ((GATES_FAILED++))
            
            # For contamination, this is instant failure
            if [ "$gate_name" = "Framework-Contamination" ]; then
                echo -e "${RED}INSTANT REJECTION: Framework contamination detected${NC}"
                exit 1
            fi
        fi
    else
        echo -e "${YELLOW}⚠ $gate_name script not ready${NC}"
    fi
}

# GATE 1: CRITICAL - Framework Contamination (MUST BE FIRST)
run_gate "Framework-Contamination" "detect_framework_contamination.sh"

# GATE 2: Build Verification
run_gate "Build-Verification" "verify_build_gates.sh"

# GATE 3: Test Verification  
run_gate "Test-Verification" "verify_test_gates.sh"

# Summary
echo
echo -e "${BLUE}=== VERIFICATION SUMMARY ===${NC}"
echo "Gates Passed: $GATES_PASSED"
echo "Gates Failed: $GATES_FAILED"
echo "Timestamp: $(date)"

if [ $GATES_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL VERIFICATION GATES PASSED! 🎉${NC}"
    echo "Ready for integration"
    exit 0
else
    echo -e "${RED}❌ $GATES_FAILED GATES FAILED ❌${NC}"
    echo "Remediation required"
    exit 1
fi
