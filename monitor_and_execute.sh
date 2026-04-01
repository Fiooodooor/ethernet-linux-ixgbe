#!/bin/bash
# Continuous Dependency Monitor - Automated Verification Trigger
# Monitors dependencies and executes verification when ready

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

WORKSPACE="/root/.clawteam/workspaces/nic-port-v2-rerun7/verification-executor"
MONITOR_LOG="$WORKSPACE/verification_logs/dependency_monitor.log"

cd "$WORKSPACE"

# Ensure log directory exists
mkdir -p verification_logs

echo -e "${BLUE}=== VERIFICATION DEPENDENCY MONITOR ===${NC}"
echo "Monitoring dependencies for verification readiness..."
echo "Workspace: $WORKSPACE"
echo "Monitor log: $MONITOR_LOG"
echo "Started: $(date)"
echo

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$MONITOR_LOG"
}

check_task_status() {
    local blocked_count
    blocked_count=$(clawteam task list nic-port-v2-rerun7 --owner verification-executor | grep blocked | wc -l)
    echo "$blocked_count"
}

check_for_updates() {
    clawteam inbox receive nic-port-v2-rerun7 --agent verification-executor | tail -5 | tee -a "$MONITOR_LOG"
}

execute_verification() {
    echo -e "${GREEN}=== EXECUTING VERIFICATION SUITE ===${NC}"
    log_message "Starting verification execution"
    
    # Update task status to in_progress for the first available task
    FIRST_TASK=$(clawteam task list nic-port-v2-rerun7 --owner verification-executor | grep -v blocked | grep verification | head -1 | awk '{print $1}' || true)
    
    if [ -n "$FIRST_TASK" ]; then
        echo "Updating task $FIRST_TASK to in_progress"
        clawteam task update nic-port-v2-rerun7 "$FIRST_TASK" --status in_progress
        log_message "Task $FIRST_TASK marked as in_progress"
    fi
    
    # Execute comprehensive verification
    if ./run_comprehensive_verification.sh; then
        echo -e "${GREEN}✅ VERIFICATION COMPLETED SUCCESSFULLY${NC}"
        log_message "Verification completed successfully"
        
        # Update all tasks to completed
        clawteam task list nic-port-v2-rerun7 --owner verification-executor | grep verification | awk '{print $1}' | while read task_id; do
            clawteam task update nic-port-v2-rerun7 "$task_id" --status completed
            log_message "Task $task_id marked as completed"
        done
        
        # Send success message to orchestrator
        clawteam inbox send nic-port-v2-rerun7 orchestrator "All verification tasks completed successfully. Comprehensive gate suite executed with full compliance to NON-NEGOTIABLE rules. Ready for integration."
        log_message "Success notification sent to orchestrator"
        
        return 0
    else
        echo -e "${RED}❌ VERIFICATION FAILED${NC}"
        log_message "Verification failed - see verification logs for details"
        
        # Send failure message to orchestrator
        clawteam inbox send nic-port-v2-rerun7 orchestrator "Verification failed. Check verification_logs/ for detailed analysis and remediation requirements."
        log_message "Failure notification sent to orchestrator"
        
        return 1
    fi
}

# Initial status check
log_message "Starting dependency monitor"
INITIAL_BLOCKED=$(check_task_status)
echo "Initial blocked tasks: $INITIAL_BLOCKED"

if [ "$INITIAL_BLOCKED" -eq 0 ]; then
    echo -e "${GREEN}✅ Dependencies resolved - executing verification immediately${NC}"
    execute_verification
    exit $?
fi

# Monitor loop
MONITOR_COUNT=0
MAX_MONITORS=60  # Prevent infinite monitoring

echo -e "${YELLOW}⏳ Monitoring dependencies... (will check every 30 seconds)${NC}"
log_message "Entering monitoring loop - checking every 30 seconds"

while [ $MONITOR_COUNT -lt $MAX_MONITORS ]; do
    sleep 30
    ((MONITOR_COUNT++))
    
    echo -e "${BLUE}--- Check #$MONITOR_COUNT ($(date '+%H:%M:%S')) ---${NC}"
    
    # Check task status
    BLOCKED_COUNT=$(check_task_status)
    echo "Blocked tasks: $BLOCKED_COUNT"
    
    if [ "$BLOCKED_COUNT" -eq 0 ]; then
        echo -e "${GREEN}🎉 DEPENDENCIES RESOLVED! 🎉${NC}"
        log_message "Dependencies resolved - executing verification"
        execute_verification
        exit $?
    fi
    
    # Check for new messages
    echo "Checking for updates..."
    check_for_updates
    
    # Send periodic idle update
    if [ $((MONITOR_COUNT % 4)) -eq 0 ]; then
        clawteam lifecycle idle nic-port-v2-rerun7
        log_message "Sent idle notification (monitor cycle $MONITOR_COUNT)"
    fi
    
    echo "Still waiting... (check $MONITOR_COUNT/$MAX_MONITORS)"
    log_message "Monitor cycle $MONITOR_COUNT completed - still waiting"
done

echo -e "${YELLOW}⚠ Maximum monitor cycles reached${NC}"
log_message "Maximum monitor cycles reached - manual intervention may be required"

# Send timeout message to orchestrator
clawteam inbox send nic-port-v2-rerun7 orchestrator "verification-executor: Dependencies still blocked after extended monitoring. Manual review may be required."
log_message "Timeout notification sent to orchestrator"