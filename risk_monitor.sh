#!/bin/bash
# Risk Monitor - Continuous project risk assessment
# Risk Auditor - NIC Port v2 Rerun7

WORKSPACE="/root/.clawteam/workspaces/nic-port-v2-rerun7"
RISK_LOG="$WORKSPACE/risk-auditor/risk_monitor.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S UTC')

echo "[$TIMESTAMP] RISK MONITOR START" >> "$RISK_LOG"

# Check 1: Agent Progress Verification
echo "=== AGENT PROGRESS AUDIT ===" >> "$RISK_LOG"
for agent_dir in "$WORKSPACE"/*; do
    if [ -d "$agent_dir" ]; then
        agent_name=$(basename "$agent_dir")
        if [ "$agent_name" != "risk-auditor" ]; then
            # Check for unique files indicating actual work
            cd "$agent_dir"
            unique_files=$(find . -name "*.c" -o -name "*.h" | xargs ls -la | grep -v "Apr  1 17:31" | wc -l)
            if [ "$unique_files" -eq 0 ]; then
                echo "⚠️  $agent_name: NO UNIQUE WORK DETECTED" >> "$RISK_LOG"
            else
                echo "✅ $agent_name: $unique_files unique files found" >> "$RISK_LOG"
            fi
        fi
    fi
done

# Check 2: Framework Contamination Scan
echo "=== FRAMEWORK CONTAMINATION CHECK ===" >> "$RISK_LOG"
cd "$WORKSPACE/risk-auditor"
contamination_count=$(grep -r "iflib\|linuxkpi\|rte_\|DPDK" src/ 2>/dev/null | wc -l)
if [ "$contamination_count" -gt 0 ]; then
    echo "🚨 CONTAMINATION DETECTED: $contamination_count instances" >> "$RISK_LOG"
else
    echo "✅ No framework contamination detected" >> "$RISK_LOG"
fi

# Check 3: Linux Kernel API Usage
linux_apis=$(grep -r "linux/\|asm/\|__linux__" src/ 2>/dev/null | wc -l)
echo "📊 Linux API calls detected: $linux_apis" >> "$RISK_LOG"

# Check 4: TDD Compliance Check
echo "=== TDD COMPLIANCE AUDIT ===" >> "$RISK_LOG"
for agent_dir in "$WORKSPACE"/*; do
    if [ -d "$agent_dir" ]; then
        agent_name=$(basename "$agent_dir")
        test_files=$(find "$agent_dir" -name "*test*" -o -name "*Test*" | wc -l)
        if [ "$test_files" -eq 0 ]; then
            echo "⚠️  $agent_name: NO TEST FILES FOUND - TDD VIOLATION" >> "$RISK_LOG"
        else
            echo "✅ $agent_name: $test_files test files found" >> "$RISK_LOG"
        fi
    fi
done

# Check 5: Gate Status Tracking
echo "=== GATE STATUS CHECK ===" >> "$RISK_LOG"
# This would need to interface with orchestrator status - for now log placeholder
echo "📊 Monitoring phase gate status - requires orchestrator integration" >> "$RISK_LOG"

echo "[$TIMESTAMP] RISK MONITOR END" >> "$RISK_LOG"
echo "---" >> "$RISK_LOG"

# Risk scoring and alert generation
risk_score=0

# Calculate risk score based on findings
if [ "$contamination_count" -gt 0 ]; then
    risk_score=$((risk_score + 10))
fi

if [ "$linux_apis" -gt 300 ]; then
    risk_score=$((risk_score + 8))
fi

# Output risk level
if [ "$risk_score" -gt 15 ]; then
    echo "🚨 CRITICAL RISK LEVEL: $risk_score" >> "$RISK_LOG"
elif [ "$risk_score" -gt 10 ]; then
    echo "⚠️  HIGH RISK LEVEL: $risk_score" >> "$RISK_LOG"
elif [ "$risk_score" -gt 5 ]; then
    echo "📊 MEDIUM RISK LEVEL: $risk_score" >> "$RISK_LOG"
else
    echo "✅ LOW RISK LEVEL: $risk_score" >> "$RISK_LOG"
fi

echo "Risk monitoring complete: $TIMESTAMP"