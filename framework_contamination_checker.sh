#!/bin/bash
# Framework Contamination Checker for Native Validator
# Purpose: Detect any forbidden framework/non-native API usage in ported code
# Author: native-validator
# Date: $(date)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Forbidden framework patterns - ANY of these = instant rejection
FORBIDDEN_PATTERNS=(
    "iflib_"           # FreeBSD iflib framework
    "linuxkpi_"        # Linux KPI framework  
    "rte_"             # DPDK RTE APIs
    "DPDK_"            # DPDK macros
    "dpdk_"            # DPDK lowercase
    "_RTE_"            # DPDK internal macros
    "struct rte_"      # DPDK structures
    "enum rte_"        # DPDK enumerations
)

# Acceptable native patterns (these are OK)
NATIVE_PATTERNS=(
    "malloc("          # Native memory allocation
    "free("            # Native memory deallocation
    "memset("          # Native memory operations
    "memcpy("          # Native memory operations
    "printf("          # Native I/O
    "device_"          # Native device APIs
    "bus_"             # Native bus APIs
    "pci_"             # Native PCI APIs
    "intr_"            # Native interrupt APIs
)

# Function to check a single file
check_file() {
    local file="$1"
    local violations=0
    local line_num=0
    
    echo "Checking: $file"
    
    while IFS= read -r line; do
        ((line_num++))
        
        # Check for forbidden patterns
        for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
            if echo "$line" | grep -q "$pattern"; then
                echo -e "${RED}VIOLATION${NC} Line $line_num: Found forbidden pattern '$pattern'"
                echo -e "  ${YELLOW}Line:${NC} $line"
                ((violations++))
            fi
        done
        
        # Check for includes that might indicate framework usage
        if echo "$line" | grep -q "#include.*iflib"; then
            echo -e "${RED}VIOLATION${NC} Line $line_num: Forbidden iflib include"
            echo -e "  ${YELLOW}Line:${NC} $line"
            ((violations++))
        fi
        
        if echo "$line" | grep -q "#include.*rte_"; then
            echo -e "${RED}VIOLATION${NC} Line $line_num: Forbidden DPDK include"
            echo -e "  ${YELLOW}Line:${NC} $line"
            ((violations++))
        fi
        
        if echo "$line" | grep -q "#include.*linuxkpi"; then
            echo -e "${RED}VIOLATION${NC} Line $line_num: Forbidden linuxkpi include"
            echo -e "  ${YELLOW}Line:${NC} $line"
            ((violations++))
        fi
        
    done < "$file"
    
    if [ $violations -eq 0 ]; then
        echo -e "${GREEN}CLEAN${NC}: No framework contamination found in $file"
    else
        echo -e "${RED}CONTAMINATED${NC}: $violations violations found in $file"
    fi
    
    return $violations
}

# Function to check all source files
check_all_sources() {
    local total_violations=0
    local files_checked=0
    
    echo "=== Framework Contamination Check ==="
    echo "Checking for forbidden patterns: ${FORBIDDEN_PATTERNS[*]}"
    echo ""
    
    # Find all C/H files
    while IFS= read -r -d '' file; do
        check_file "$file"
        file_violations=$?
        total_violations=$((total_violations + file_violations))
        ((files_checked++))
        echo ""
    done < <(find "${1:-src}" -type f \( -name "*.c" -o -name "*.h" \) -print0)
    
    echo "=== SUMMARY ==="
    echo "Files checked: $files_checked"
    
    if [ $total_violations -eq 0 ]; then
        echo -e "${GREEN}RESULT: APPROVE${NC} - No framework contamination detected"
        echo "All code uses native APIs only."
        return 0
    else
        echo -e "${RED}RESULT: REJECT${NC} - $total_violations framework violations found"
        echo ""
        echo "NON-NEGOTIABLE RULES VIOLATED:"
        echo "- Zero framework calls allowed"
        echo "- Use native OS API calls ONLY"
        echo "- Remove all iflib/linuxkpi/rte_*/DPDK usage"
        echo ""
        echo "REQUIRED ACTIONS:"
        echo "1. Replace framework calls with native equivalents"
        echo "2. Use thin OAL seams: #ifdef trees, inline wrappers, weak symbols"
        echo "3. Follow TDD-first: write failing test, implement, verify"
        echo "4. Minimal source touch: wrapper instead of rewrite when possible"
        return 1
    fi
}

# Main execution
if [ $# -eq 0 ]; then
    # Check current directory's src folder by default
    if [ -d "src" ]; then
        check_all_sources "src"
    else
        echo "Usage: $0 [source_directory]"
        echo "No 'src' directory found in current location"
        exit 1
    fi
else
    # Check specified directory
    check_all_sources "$1"
fi