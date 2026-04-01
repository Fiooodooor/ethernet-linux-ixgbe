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
