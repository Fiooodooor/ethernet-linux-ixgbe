#!/bin/bash
# Framework Contamination Monitor - Continuous Scanning
# Risk Auditor - NIC Port v2 Rerun7
# 
# NON-NEGOTIABLE RULES ENFORCED:
# - Zero framework calls. Any iflib/linuxkpi/rte_*/DPDK usage = instant rejection.
# - Native OS API calls ONLY.

set -e

WORKSPACE="/root/.clawteam/workspaces/nic-port-v2-rerun7"
CONTAMINATION_LOG="$WORKSPACE/risk-auditor/contamination_monitor.log"
ALERT_THRESHOLD=1
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S UTC')

echo "[$TIMESTAMP] CONTAMINATION MONITOR START" | tee -a "$CONTAMINATION_LOG"

# Initialize counters
total_violations=0
critical_violations=0

echo "=== FORBIDDEN FRAMEWORK SCAN ===" | tee -a "$CONTAMINATION_LOG"

# Check all agent workspaces for framework contamination
for agent_dir in "$WORKSPACE"/*; do
    if [ -d "$agent_dir" ]; then
        agent_name=$(basename "$agent_dir")
        echo "Scanning $agent_name..." | tee -a "$CONTAMINATION_LOG"
        
        cd "$agent_dir"
        
        # Scan for forbidden frameworks
        iflib_count=$(find . -name "*.c" -o -name "*.h" | xargs grep -l "iflib" 2>/dev/null | wc -l)
        linuxkpi_count=$(find . -name "*.c" -o -name "*.h" | xargs grep -l "linuxkpi" 2>/dev/null | wc -l)
        rte_count=$(find . -name "*.c" -o -name "*.h" | xargs grep -l "rte_" 2>/dev/null | wc -l)
        dpdk_count=$(find . -name "*.c" -o -name "*.h" | xargs grep -l "DPDK\|dpdk" 2>/dev/null | wc -l)
        
        agent_violations=$((iflib_count + linuxkpi_count + rte_count + dpdk_count))
        
        if [ "$agent_violations" -gt 0 ]; then
            echo "🚨 $agent_name: $agent_violations FRAMEWORK VIOLATIONS DETECTED!" | tee -a "$CONTAMINATION_LOG"
            echo "  - iflib: $iflib_count files" | tee -a "$CONTAMINATION_LOG"
            echo "  - linuxkpi: $linuxkpi_count files" | tee -a "$CONTAMINATION_LOG"
            echo "  - rte_: $rte_count files" | tee -a "$CONTAMINATION_LOG"
            echo "  - DPDK: $dpdk_count files" | tee -a "$CONTAMINATION_LOG"
            
            # List specific files with violations
            find . -name "*.c" -o -name "*.h" | xargs grep -l "iflib\|linuxkpi\|rte_\|DPDK\|dpdk" 2>/dev/null | while read file; do
                echo "    CONTAMINATED FILE: $file" | tee -a "$CONTAMINATION_LOG"
            done
            
            critical_violations=$((critical_violations + 1))
        else
            echo "✅ $agent_name: CLEAN" | tee -a "$CONTAMINATION_LOG"
        fi
        
        total_violations=$((total_violations + agent_violations))
    fi
done

echo "" | tee -a "$CONTAMINATION_LOG"
echo "=== CONTAMINATION SUMMARY ===" | tee -a "$CONTAMINATION_LOG"
echo "Total framework violations: $total_violations" | tee -a "$CONTAMINATION_LOG"
echo "Agents with violations: $critical_violations" | tee -a "$CONTAMINATION_LOG"

# Generate alerts if violations found
if [ "$total_violations" -gt "$ALERT_THRESHOLD" ]; then
    echo "" | tee -a "$CONTAMINATION_LOG"
    echo "🚨🚨🚨 CRITICAL CONTAMINATION ALERT 🚨🚨🚨" | tee -a "$CONTAMINATION_LOG"
    echo "NON-NEGOTIABLE RULE VIOLATION DETECTED!" | tee -a "$CONTAMINATION_LOG"
    echo "IMMEDIATE ACTION REQUIRED!" | tee -a "$CONTAMINATION_LOG"
    echo "" | tee -a "$CONTAMINATION_LOG"
    
    # Create alert file for orchestrator
    cat > "$WORKSPACE/risk-auditor/CONTAMINATION_ALERT.txt" << EOF
🚨 CRITICAL FRAMEWORK CONTAMINATION DETECTED 🚨

Date: $TIMESTAMP
Total Violations: $total_violations
Agents Affected: $critical_violations

NON-NEGOTIABLE RULE VIOLATED:
"Zero framework calls. Any iflib/linuxkpi/rte_*/DPDK usage = instant rejection."

IMMEDIATE ACTION REQUIRED:
1. Remove all framework dependencies
2. Implement pure OAL seams following api-mapper pattern
3. Use native OS APIs only

See $CONTAMINATION_LOG for detailed violation report.
EOF
    
    echo "CONTAMINATION ALERT GENERATED: CONTAMINATION_ALERT.txt"
    
    # Try to notify orchestrator
    if command -v clawteam > /dev/null; then
        clawteam inbox send nic-port-v2-rerun7 orchestrator "🚨 FRAMEWORK CONTAMINATION DETECTED: $total_violations violations across $critical_violations agents. NON-NEGOTIABLE RULE VIOLATION! See risk-auditor/CONTAMINATION_ALERT.txt"
    fi
    
else
    echo "✅ NO FRAMEWORK CONTAMINATION DETECTED" | tee -a "$CONTAMINATION_LOG"
    
    # Remove any existing alert files
    rm -f "$WORKSPACE/risk-auditor/CONTAMINATION_ALERT.txt"
fi

# Check for proper OAL seam usage
echo "" | tee -a "$CONTAMINATION_LOG"
echo "=== OAL SEAM COMPLIANCE CHECK ===" | tee -a "$CONTAMINATION_LOG"

oal_agents=0
for agent_dir in "$WORKSPACE"/*; do
    if [ -d "$agent_dir" ]; then
        agent_name=$(basename "$agent_dir")
        cd "$agent_dir"
        
        # Look for OAL seam files
        oal_files=$(find . -name "*oal*" -o -name "*seam*" | wc -l)
        ifdef_usage=$(find . -name "*.c" -o -name "*.h" | xargs grep -l "#ifdef.*BSD\|#ifdef.*LINUX" 2>/dev/null | wc -l)
        
        if [ "$oal_files" -gt 0 ] || [ "$ifdef_usage" -gt 0 ]; then
            echo "✅ $agent_name: OAL seam implementation detected ($oal_files OAL files, $ifdef_usage files with OS ifdefs)" | tee -a "$CONTAMINATION_LOG"
            oal_agents=$((oal_agents + 1))
        else
            echo "⚠️  $agent_name: NO OAL seams detected" | tee -a "$CONTAMINATION_LOG"
        fi
    fi
done

echo "OAL seam implementations: $oal_agents agents" | tee -a "$CONTAMINATION_LOG"

echo "[$TIMESTAMP] CONTAMINATION MONITOR END" | tee -a "$CONTAMINATION_LOG"
echo "---" | tee -a "$CONTAMINATION_LOG"

# Exit with appropriate code
if [ "$total_violations" -gt "$ALERT_THRESHOLD" ]; then
    exit 1  # Critical failure
else
    exit 0  # Clean
fi