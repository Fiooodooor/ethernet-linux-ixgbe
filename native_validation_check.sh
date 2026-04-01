#!/bin/bash
# Simple Framework Contamination Checker
# Purpose: Detect forbidden framework usage for native-validator role

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo "=== NATIVE VALIDATOR CONTAMINATION CHECK ==="
echo "Scanning for forbidden framework calls..."
echo ""

total_violations=0

# Check for iflib framework usage
echo "1. Checking for iflib framework usage..."
if grep -rn "iflib_" src/ 2>/dev/null; then
    echo -e "${RED}VIOLATION: iflib framework usage detected${NC}"
    ((total_violations++))
else
    echo -e "${GREEN}✓ No iflib framework calls found${NC}"
fi

echo ""

# Check for DPDK/RTE usage  
echo "2. Checking for DPDK/RTE framework usage..."
if grep -rn "rte_\|_RTE_\|DPDK\|dpdk\|struct rte_\|enum rte_" src/ 2>/dev/null; then
    echo -e "${RED}VIOLATION: DPDK/RTE framework usage detected${NC}"
    ((total_violations++))
else
    echo -e "${GREEN}✓ No DPDK/RTE framework calls found${NC}"
fi

echo ""

# Check for LinuxKPI usage
echo "3. Checking for LinuxKPI framework usage..."  
if grep -rn "linuxkpi" src/ 2>/dev/null; then
    echo -e "${RED}VIOLATION: LinuxKPI framework usage detected${NC}"
    ((total_violations++))
else
    echo -e "${GREEN}✓ No LinuxKPI framework calls found${NC}"
fi

echo ""

# Check for framework includes
echo "4. Checking for framework includes..."
if grep -rn "#include.*iflib\|#include.*rte_\|#include.*linuxkpi" src/ 2>/dev/null; then
    echo -e "${RED}VIOLATION: Framework includes detected${NC}"
    ((total_violations++))
else
    echo -e "${GREEN}✓ No framework includes found${NC}"
fi

echo ""
echo "=== NATIVE VALIDATOR DECISION ==="

if [ $total_violations -eq 0 ]; then
    echo -e "${GREEN}APPROVE${NC}: Code passes native validation"
    echo "✓ Zero framework calls detected"
    echo "✓ Uses native OS APIs only"
    echo "✓ Complies with NON-NEGOTIABLE RULES"
    exit 0
else
    echo -e "${RED}REJECT${NC}: $total_violations framework violations found"
    echo ""
    echo "NON-NEGOTIABLE RULES VIOLATED:"
    echo "❌ Zero framework calls required"
    echo "❌ Native OS API calls ONLY"  
    echo "❌ No iflib/linuxkpi/rte_*/DPDK usage"
    echo ""
    echo "REQUIRED REMEDIATION:"
    echo "1. Remove all framework API calls"
    echo "2. Replace with native equivalents"
    echo "3. Use thin OAL seams: #ifdef trees, inline wrappers, weak symbols" 
    echo "4. Follow TDD-first: test → implement → verify"
    echo "5. Minimal source touch: wrapper > rewrite"
    exit 1
fi