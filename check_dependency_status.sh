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
