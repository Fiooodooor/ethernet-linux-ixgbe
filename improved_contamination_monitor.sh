#!/bin/bash
# Improved Framework Contamination Monitor - Context-Aware Scanning
# Risk Auditor - NIC Port v2 Rerun7

set -e

WORKSPACE="/root/.clawteam/workspaces/nic-port-v2-rerun7"
CONTAMINATION_LOG="$WORKSPACE/risk-auditor/contamination_monitor.log"
ALERT_THRESHOLD=1
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S UTC')

echo "[$TIMESTAMP] IMPROVED CONTAMINATION MONITOR START" | tee -a "$CONTAMINATION_LOG"

# Initialize counters
total_violations=0
critical_violations=0

echo "=== CONTEXT-AWARE FRAMEWORK SCAN ===" | tee -a "$CONTAMINATION_LOG"

# Check all agent workspaces for actual framework usage (not documentation)
for agent_dir in "$WORKSPACE"/*; do
    if [ -d "$agent_dir" ]; then
        agent_name=$(basename "$agent_dir")
        echo "Scanning $agent_name..." | tee -a "$CONTAMINATION_LOG"
        
        cd "$agent_dir"
        
        # Create temporary file with actual code usage (exclude comments and documentation)
        temp_scan=$(mktemp)
        
        # Find actual framework usage - exclude comments and strings mentioning frameworks
        find . -name "*.c" -o -name "*.h" | xargs grep -v "^\s*\*\|^\s*//\|^\s*#.*NO.*framework" | \
            grep -E "iflib_|linuxkpi_|rte_[a-z]|DPDK_" > "$temp_scan" 2>/dev/null || true
        
        # Count actual usage lines
        actual_violations=$(wc -l < "$temp_scan")
        
        if [ "$actual_violations" -gt 0 ]; then
            echo "🚨 $agent_name: $actual_violations ACTUAL FRAMEWORK USAGE DETECTED!" | tee -a "$CONTAMINATION_LOG"
            echo "Violations:" | tee -a "$CONTAMINATION_LOG"
            cat "$temp_scan" | head -10 | tee -a "$CONTAMINATION_LOG"
            critical_violations=$((critical_violations + 1))
        else
            # Check for documentation references (informational only)
            doc_refs=$(find . -name "*.c" -o -name "*.h" | xargs grep "iflib\|linuxkpi\|DPDK" 2>/dev/null | wc -l)
            if [ "$doc_refs" -gt 0 ]; then
                echo "📝 $agent_name: CLEAN (docs mention frameworks in policy/comments)" | tee -a "$CONTAMINATION_LOG"
            else
                echo "✅ $agent_name: CLEAN" | tee -a "$CONTAMINATION_LOG"
            fi
        fi
        
        rm -f "$temp_scan"
        total_violations=$((total_violations + actual_violations))
    fi
done

echo "" | tee -a "$CONTAMINATION_LOG"
echo "=== IMPROVED CONTAMINATION SUMMARY ===" | tee -a "$CONTAMINATION_LOG"
echo "Actual framework usage violations: $total_violations" | tee -a "$CONTAMINATION_LOG"
echo "Agents with actual violations: $critical_violations" | tee -a "$CONTAMINATION_LOG"

# Generate alerts only for actual violations
if [ "$total_violations" -gt 0 ]; then
    echo "🚨🚨🚨 CRITICAL CONTAMINATION ALERT 🚨🚨🚨" | tee -a "$CONTAMINATION_LOG"
    echo "ACTUAL FRAMEWORK USAGE DETECTED!" | tee -a "$CONTAMINATION_LOG"
    echo "IMMEDIATE ACTION REQUIRED!" | tee -a "$CONTAMINATION_LOG"
    
    cat > "$WORKSPACE/risk-auditor/CONTAMINATION_ALERT.txt" << EOF
🚨 CRITICAL FRAMEWORK CONTAMINATION DETECTED 🚨

Date: $TIMESTAMP
Actual Usage Violations: $total_violations
Agents Affected: $critical_violations

ACTUAL framework API usage detected (not just documentation).
See $CONTAMINATION_LOG for details.
EOF
    
    clawteam inbox send nic-port-v2-rerun7 orchestrator "🚨 ACTUAL FRAMEWORK USAGE DETECTED: $total_violations violations across $critical_violations agents."
    exit 1
else
    echo "✅ NO ACTUAL FRAMEWORK USAGE DETECTED" | tee -a "$CONTAMINATION_LOG"
    echo "All detected references were in comments/documentation (acceptable)" | tee -a "$CONTAMINATION_LOG"
    rm -f "$WORKSPACE/risk-auditor/CONTAMINATION_ALERT.txt"
    exit 0
fi