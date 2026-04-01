#!/bin/bash
#
# MONITOR_DEPENDENCIES.sh - Monitor team progress and dependency unblocking
# For merge-strategist role - tracks when merge tasks become ready
#

set -e

TEAM="nic-port-v2-rerun7"
AGENT="merge-strategist"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[READY]${NC} $1"; }
warn() { echo -e "${YELLOW}[WAITING]${NC} $1"; }
error() { echo -e "${RED}[BLOCKED]${NC} $1"; }

# Function to check my task status
check_my_tasks() {
    log "Checking merge-strategist tasks..."
    
    local ready_tasks=0
    local blocked_tasks=0
    
    # Get my tasks
    while IFS= read -r line; do
        if [[ "$line" == *"pending"* ]] && [[ "$line" == *"merge-stra"* ]]; then
            local task_id=$(echo "$line" | awk '{print $1}')
            success "Task $task_id is READY TO START"
            ((ready_tasks++))
        elif [[ "$line" == *"blocked"* ]] && [[ "$line" == *"merge-stra"* ]]; then
            local task_id=$(echo "$line" | awk '{print $1}')
            error "Task $task_id is still BLOCKED"
            ((blocked_tasks++))
        fi
    done < <(clawteam task list $TEAM --owner $AGENT | tail -n +4)
    
    if [ $ready_tasks -gt 0 ]; then
        success "$ready_tasks merge tasks READY TO EXECUTE"
        return 0
    else
        warn "$blocked_tasks merge tasks still blocked"
        return 1
    fi
}

# Function to analyze team progress
check_team_progress() {
    log "Analyzing overall team progress..."
    
    # Count tasks by status
    local completed=$(clawteam task list $TEAM --status completed | tail -n +4 | wc -l)
    local in_progress=$(clawteam task list $TEAM --status in_progress | tail -n +4 | wc -l)  
    local pending=$(clawteam task list $TEAM --status pending | tail -n +4 | wc -l)
    local blocked=$(clawteam task list $TEAM --status blocked | tail -n +4 | wc -l)
    
    log "Task Status: ✅ $completed completed | 🔄 $in_progress active | ⏳ $pending ready | 🔒 $blocked blocked"
    
    # Check critical path tasks
    log "Checking critical dependency tasks..."
    
    # Key tasks that unblock merge work
    local critical_tasks=(
        "56f827e2" # tdd-writer - TDD test infrastructure 
        "2012f032" # coder - Native implementation
        "73b08af0" # native-validator - Framework compliance
        "0ea7a34b" # verification-executor - Final validation
    )
    
    for task_id in "${critical_tasks[@]}"; do
        local status=$(clawteam task get $TEAM $task_id 2>/dev/null | grep "Status:" | awk '{print $2}')
        case "$status" in
            "completed") success "Critical task $task_id: COMPLETED" ;;
            "in_progress") warn "Critical task $task_id: IN PROGRESS" ;;
            "pending") warn "Critical task $task_id: PENDING" ;;  
            "blocked") error "Critical task $task_id: BLOCKED" ;;
            *) warn "Critical task $task_id: $status" ;;
        esac
    done
}

# Function to check for new branch changes
check_branch_changes() {
    log "Checking for new team branch changes..."
    
    cd /root/.clawteam/workspaces/$TEAM/$AGENT
    
    local new_changes=0
    
    # Update our view of all branches
    git fetch --all >/dev/null 2>&1 || true
    
    # Check each team branch for new commits
    for branch in clawteam/${TEAM}/{api-mapper,seam-architect,coder,tdd-writer,linux-analyst,kpi-auditor,risk-auditor,code-reviewer,native-validator,portability-validator,performance-engineer,verification-executor}; do
        if git rev-parse --verify "$branch" >/dev/null 2>&1; then
            local commit_count=$(git rev-list --count main..$branch 2>/dev/null || echo "0")
            if [ "$commit_count" -gt 0 ]; then
                local agent_name=${branch##*/}
                local latest_commit=$(git log --oneline -1 $branch | cut -c1-7)
                success "Agent $agent_name: $commit_count commits (latest: $latest_commit)"
                ((new_changes++))
            fi
        fi
    done
    
    if [ $new_changes -eq 0 ]; then
        warn "No team branches have new commits"
    else
        log "Found changes in $new_changes agent branches"
    fi
}

# Function to get recent team messages
check_team_messages() {
    log "Checking for new team messages..."
    
    local messages=$(clawteam inbox receive $TEAM --agent $AGENT 2>/dev/null | tail -5)
    if [ -n "$messages" ]; then
        while IFS= read -r line; do
            if [[ "$line" == *"from="* ]]; then
                echo "  📨 $line"
            fi
        done <<< "$messages"
    else
        log "No new messages"
    fi
}

# Main monitoring function
main() {
    echo "🔍 MERGE-STRATEGIST DEPENDENCY MONITOR"
    echo "======================================="
    echo "Team: $TEAM"
    echo "Time: $(date)"
    echo ""
    
    # Check if I can start working
    if check_my_tasks; then
        echo ""
        echo "🚀 EXECUTE MERGE TASKS:"
        echo "clawteam task update $TEAM <task-id> --status in_progress"
        echo ""
    fi
    
    echo ""
    check_team_progress
    
    echo ""
    check_branch_changes
    
    echo ""
    check_team_messages
    
    echo ""
    echo "======================================="
    echo "Next check: $(date -d '+5 minutes')"
    echo "Monitor command: watch -n 300 $0"
}

# Run main function
main "$@"