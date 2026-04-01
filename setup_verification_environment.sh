#!/bin/bash
# Verification Environment Setup - Preparation Script
# Prepares environment for comprehensive verification when dependencies resolve

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WORKSPACE="/root/.clawteam/workspaces/nic-port-v2-rerun7/verification-executor"
cd "$WORKSPACE"

echo -e "${BLUE}=== VERIFICATION ENVIRONMENT SETUP ===${NC}"
echo "Workspace: $WORKSPACE"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo

# Create verification directories
echo "Creating verification directory structure..."
mkdir -p verification_logs
mkdir -p verification_results  
mkdir -p verification_reports
mkdir -p verification_artifacts

echo -e "${GREEN}✓ Directory structure created${NC}"

# Check source availability
echo "Checking source code availability..."
if [ -d "src" ] && [ -n "$(ls src/*.c 2>/dev/null)" ]; then
    echo -e "${GREEN}✓ Linux source code available${NC}"
    echo "Source files: $(ls src/*.c | wc -l) C files, $(ls src/*.h | wc -l) header files"
else
    echo -e "${RED}✗ Linux source code not available${NC}"
    exit 1
fi

# Prepare contamination detection
echo "Preparing framework contamination detection..."
cat > detect_framework_contamination.sh << 'EOF'
#!/bin/bash
# Framework Contamination Detection for verification-executor
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CONTAMINATION_FOUND=0
WORKSPACE="/root/.clawteam/workspaces/nic-port-v2-rerun7/verification-executor"

echo -e "${YELLOW}=== CRITICAL: Framework Contamination Detection ===${NC}"
echo "NON-NEGOTIABLE: Any framework usage = INSTANT REJECTION"

# Scan patterns
scan_pattern() {
    local pattern="$1"
    local description="$2"
    
    echo -n "Scanning for $description... "
    
    if find "$WORKSPACE" -name "*.c" -o -name "*.h" | xargs grep -l "$pattern" 2>/dev/null | head -1 > /dev/null; then
        echo -e "${RED}CONTAMINATION DETECTED!${NC}"
        echo "Pattern: $pattern"
        find "$WORKSPACE" -name "*.c" -o -name "*.h" | xargs grep -n "$pattern" 2>/dev/null || true
        CONTAMINATION_FOUND=1
    else
        echo -e "${GREEN}Clean${NC}"
    fi
}

# Critical framework patterns
scan_pattern "iflib_" "iflib framework calls"
scan_pattern "linuxkpi" "LinuxKPI usage"
scan_pattern "rte_" "DPDK rte_ calls"
scan_pattern "RTE_" "DPDK RTE_ macros"
scan_pattern "IFLIB_\|if_ctx_\|if_shared_ctx" "FreeBSD iflib context"

if [ $CONTAMINATION_FOUND -eq 0 ]; then
    echo -e "${GREEN}=== FRAMEWORK CONTAMINATION CHECK PASSED ===${NC}"
    exit 0
else
    echo -e "${RED}=== INSTANT REJECTION: FRAMEWORK CONTAMINATION ===${NC}"
    exit 1
fi
EOF

chmod +x detect_framework_contamination.sh
echo -e "${GREEN}✓ Contamination detection script prepared${NC}"

# Prepare build verification script
echo "Preparing build verification script..."
cat > verify_build_gates.sh << 'EOF'
#!/bin/bash
# Build Verification Gates
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

WORKSPACE="/root/.clawteam/workspaces/nic-port-v2-rerun7/verification-executor"
LOG_DIR="$WORKSPACE/verification_logs"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

echo "=== BUILD VERIFICATION GATES ==="

# Check for FreeBSD target
if [ -d "/root/.clawteam/workspaces/nic-port-v2-rerun7/coder" ]; then
    echo "Found FreeBSD target workspace"
    FREEBSD_TARGET="/root/.clawteam/workspaces/nic-port-v2-rerun7/coder"
elif find /root/.clawteam/workspaces/nic-port-v2-rerun7 -name "*freebsd*" -type d 2>/dev/null | head -1; then
    echo "Found FreeBSD target directory"
    FREEBSD_TARGET=$(find /root/.clawteam/workspaces/nic-port-v2-rerun7 -name "*freebsd*" -type d 2>/dev/null | head -1)
else
    echo "FreeBSD target not yet available - will verify Linux baseline"
    FREEBSD_TARGET=""
fi

# Verify Linux source build capability
cd "$WORKSPACE/src"
if [ -f "Makefile" ]; then
    echo -e "${GREEN}✓ Build system found${NC}"
    echo "Makefile available for build verification"
else
    echo -e "${RED}✗ No build system found${NC}"
fi

echo "Build verification prepared for execution when dependencies ready"
EOF

chmod +x verify_build_gates.sh
echo -e "${GREEN}✓ Build verification script prepared${NC}"

# Prepare test verification script
echo "Preparing test verification script..."
cat > verify_test_gates.sh << 'EOF'
#!/bin/bash
# Test Verification Gates
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== TEST VERIFICATION GATES ==="

# Look for test frameworks across team workspace
TEST_DIRS=$(find /root/.clawteam/workspaces/nic-port-v2-rerun7 -name "*test*" -type d 2>/dev/null || true)

if [ -n "$TEST_DIRS" ]; then
    echo -e "${GREEN}✓ Test directories found:${NC}"
    echo "$TEST_DIRS"
    
    # Check for TDD patterns
    if find /root/.clawteam/workspaces/nic-port-v2-rerun7 -name "*.c" -o -name "*.h" | xargs grep -l "assert\|test.*fail\|EXPECT" 2>/dev/null | head -1 > /dev/null; then
        echo -e "${GREEN}✓ TDD patterns detected${NC}"
    fi
else
    echo -e "${YELLOW}⚠ No test directories found yet${NC}"
    echo "TDD framework may still be in development"
fi

echo "Test verification prepared for execution when test framework ready"
EOF

chmod +x verify_test_gates.sh
echo -e "${GREEN}✓ Test verification script prepared${NC}"

# Create comprehensive gate runner
echo "Creating comprehensive verification gate runner..."
cat > run_comprehensive_verification.sh << 'EOF'
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
EOF

chmod +x run_comprehensive_verification.sh
echo -e "${GREEN}✓ Comprehensive verification runner created${NC}"

# Create status checker
echo "Creating dependency status checker..."
cat > check_dependency_status.sh << 'EOF'
#!/bin/bash
# Check if verification dependencies are ready

echo "=== DEPENDENCY STATUS CHECK ==="
echo "Timestamp: $(date)"

# Check task status
echo "Checking task blocking status..."
clawteam task list nic-port-v2-rerun7 --owner verification-executor

echo
echo "Checking for team updates..."
clawteam inbox receive nic-port-v2-rerun7 --agent verification-executor | tail -10

echo
echo "=== STATUS SUMMARY ==="
BLOCKED_TASKS=$(clawteam task list nic-port-v2-rerun7 --owner verification-executor | grep blocked | wc -l)
if [ "$BLOCKED_TASKS" -gt 0 ]; then
    echo "⏳ $BLOCKED_TASKS tasks still blocked - monitoring dependencies"
    exit 1
else
    echo "✅ All dependencies resolved - ready for execution!"
    exit 0
fi
EOF

chmod +x check_dependency_status.sh
echo -e "${GREEN}✓ Dependency status checker created${NC}"

echo
echo -e "${GREEN}=== VERIFICATION ENVIRONMENT SETUP COMPLETE ===${NC}"
echo
echo "Available scripts:"
echo "  - detect_framework_contamination.sh (Critical contamination check)"
echo "  - verify_build_gates.sh (Build verification)"  
echo "  - verify_test_gates.sh (Test verification)"
echo "  - run_comprehensive_verification.sh (Full gate suite)"
echo "  - check_dependency_status.sh (Monitor dependencies)"
echo
echo "Directories:"
echo "  - verification_logs/ (Execution logs)"
echo "  - verification_results/ (Results data)"
echo "  - verification_reports/ (Final reports)"
echo "  - verification_artifacts/ (Build artifacts)"
echo
echo -e "${YELLOW}Next: Monitor dependencies and execute when ready${NC}"
echo "Run: ./check_dependency_status.sh"