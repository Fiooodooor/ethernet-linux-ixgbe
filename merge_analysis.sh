#!/bin/bash
# 
# MERGE_ANALYSIS.sh - Automated merge preparation and conflict analysis
# For ixgbe NIC Port to FreeBSD project
# Agent: merge-strategist
# Team: nic-port-v2-rerun7
#

set -e

# Configuration
TEAM="nic-port-v2-rerun7"
BASE_BRANCH="main"
CURRENT_BRANCH="clawteam/nic-port-v2-rerun7/merge-strategist"
WORKDIR="/root/.clawteam/workspaces/nic-port-v2-rerun7/merge-strategist"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to check team branch changes
analyze_team_branches() {
    log "Analyzing changes across team branches..."
    
    cd "$WORKDIR"
    
    # Get list of team branches with changes
    local branches_with_changes=()
    
    for branch in clawteam/${TEAM}/{api-mapper,seam-architect,coder,tdd-writer,linux-analyst,kpi-auditor,risk-auditor,code-reviewer,native-validator,portability-validator,performance-engineer,verification-executor}; do
        if git show-branch "$branch" "$BASE_BRANCH" 2>/dev/null | grep -q "^[*+]"; then
            local commit_count=$(git rev-list --count "$BASE_BRANCH..$branch" 2>/dev/null || echo "0")
            if [ "$commit_count" -gt 0 ]; then
                branches_with_changes+=("$branch:$commit_count")
                log "Branch $branch has $commit_count commits ahead of main"
            fi
        fi
    done
    
    if [ ${#branches_with_changes[@]} -eq 0 ]; then
        warn "No team branches found with changes ahead of main"
        return 1
    fi
    
    # Create summary report
    cat > BRANCH_ANALYSIS.md << EOF
# Branch Analysis Report
Generated: $(date)

## Branches with Changes

EOF
    
    for branch_info in "${branches_with_changes[@]}"; do
        local branch="${branch_info%:*}"
        local count="${branch_info#*:}"
        echo "- **$branch**: $count commits" >> BRANCH_ANALYSIS.md
        
        # Get recent commits for each branch
        echo "  - Recent commits:" >> BRANCH_ANALYSIS.md
        git log --oneline -3 "$branch" | sed 's/^/    - /' >> BRANCH_ANALYSIS.md
        echo "" >> BRANCH_ANALYSIS.md
    done
    
    success "Branch analysis complete - see BRANCH_ANALYSIS.md"
    return 0
}

# Function to detect potential conflicts
detect_conflicts() {
    log "Detecting potential merge conflicts..."
    
    cd "$WORKDIR"
    
    # Create conflict detection report
    cat > CONFLICT_ANALYSIS.md << EOF
# Merge Conflict Analysis
Generated: $(date)

## Conflict Detection Summary

EOF
    
    local conflict_count=0
    
    # Check each team branch for conflicts with main
    for branch in clawteam/${TEAM}/{api-mapper,seam-architect,coder,tdd-writer,linux-analyst,kpi-auditor,risk-auditor,code-reviewer,native-validator,portability-validator,performance-engineer,verification-executor}; do
        if git rev-parse --verify "$branch" >/dev/null 2>&1; then
            log "Checking conflicts for $branch..."
            
            # Attempt to determine merge conflicts without actually merging
            if ! git merge-tree "$BASE_BRANCH" "$branch" > /tmp/merge_analysis_$$ 2>&1; then
                warn "Could not analyze merge tree for $branch"
                continue
            fi
            
            # Check if merge tree output indicates conflicts
            if grep -q "<<<<<<< " /tmp/merge_analysis_$$; then
                error "Conflicts detected in $branch"
                echo "### Conflicts in $branch" >> CONFLICT_ANALYSIS.md
                echo "" >> CONFLICT_ANALYSIS.md
                grep -A 5 -B 5 "<<<<<<< " /tmp/merge_analysis_$$ | head -20 >> CONFLICT_ANALYSIS.md
                echo "" >> CONFLICT_ANALYSIS.md
                ((conflict_count++))
            else
                success "No conflicts detected in $branch"
                echo "- **$branch**: No conflicts detected" >> CONFLICT_ANALYSIS.md
            fi
            
            rm -f /tmp/merge_analysis_$$
        fi
    done
    
    echo "" >> CONFLICT_ANALYSIS.md
    echo "**Total branches with conflicts: $conflict_count**" >> CONFLICT_ANALYSIS.md
    
    if [ $conflict_count -gt 0 ]; then
        error "Conflicts detected in $conflict_count branches"
        return 1
    else
        success "No merge conflicts detected"
        return 0
    fi
}

# Function to analyze API compliance
check_api_compliance() {
    log "Checking for framework contamination and API compliance..."
    
    cd "$WORKDIR"
    
    # Framework patterns to detect (NON-NEGOTIABLE violations)
    local forbidden_patterns=(
        "iflib_"
        "linuxkpi_"
        "rte_"
        "dpdk_"
        "DPDK"
        "RTE_"
        "iflib.h"
        "linuxkpi.h"
    )
    
    cat > API_COMPLIANCE.md << EOF
# API Compliance Report
Generated: $(date)

## Framework Contamination Check

Checking for NON-NEGOTIABLE violations:
- Zero framework calls (iflib/linuxkpi/rte_*/DPDK)
- Native OS API calls ONLY

EOF
    
    local violations=0
    
    # Check all source files for forbidden patterns
    find src -name "*.c" -o -name "*.h" | while read -r file; do
        for pattern in "${forbidden_patterns[@]}"; do
            if grep -n "$pattern" "$file" 2>/dev/null; then
                error "Framework contamination found: $pattern in $file"
                echo "- **VIOLATION**: $pattern found in $file" >> API_COMPLIANCE.md
                grep -n "$pattern" "$file" | head -3 | sed 's/^/  - Line /' >> API_COMPLIANCE.md
                ((violations++))
            fi
        done
    done
    
    if [ $violations -eq 0 ]; then
        success "No framework contamination detected"
        echo "✅ **NO VIOLATIONS FOUND**" >> API_COMPLIANCE.md
    else
        error "$violations framework violations detected"
        echo "❌ **$violations VIOLATIONS FOUND**" >> API_COMPLIANCE.md
    fi
    
    echo "" >> API_COMPLIANCE.md
    echo "## Native API Usage Verification" >> API_COMPLIANCE.md
    
    # Look for proper FreeBSD patterns
    local good_patterns=(
        "malloc("
        "free("
        "bus_dma"
        "ifnet"
        "if_"
        "mtx_"
        "sx_"
    )
    
    for pattern in "${good_patterns[@]}"; do
        local count=$(find src -name "*.c" -o -name "*.h" -exec grep -l "$pattern" {} \; 2>/dev/null | wc -l)
        echo "- **$pattern**: Found in $count files" >> API_COMPLIANCE.md
    done
    
    return $violations
}

# Function to prepare merge order
plan_merge_order() {
    log "Planning merge execution order..."
    
    cd "$WORKDIR"
    
    # Define merge order based on dependencies and risk
    cat > MERGE_ORDER.md << EOF
# Merge Execution Plan
Generated: $(date)

## Merge Order Strategy

Based on dependency analysis and risk assessment:

### Phase 1: Foundation (Low Risk)
1. **risk-auditor** - Risk assessments and monitoring infrastructure
2. **linux-analyst** - Dependency mapping and analysis
3. **api-mapper** - API translation tables and mappings

### Phase 2: Architecture (Medium Risk)  
4. **seam-architect** - OAL seam layer design and headers
5. **kpi-auditor** - API compliance validation framework
6. **code-reviewer** - Code quality and style standards

### Phase 3: Implementation (High Risk)
7. **tdd-writer** - Test infrastructure and failing tests
8. **coder** - Native OAL implementation code
9. **native-validator** - Framework contamination prevention

### Phase 4: Validation (Critical Risk)
10. **portability-validator** - Cross-platform verification
11. **performance-engineer** - Performance validation and optimization
12. **verification-executor** - Final integration testing

## Risk Mitigation Per Phase

EOF
    
    # Add risk mitigation details for each phase
    cat >> MERGE_ORDER.md << 'EOF'
### Phase 1 Risks
- **Low impact**: Documentation and analysis only
- **Mitigation**: Review outputs before proceeding
- **Rollback**: Simple revert if issues found

### Phase 2 Risks
- **Medium impact**: Architecture changes affect downstream
- **Mitigation**: Validate seam design before implementation merge
- **Rollback**: Architecture rollback may require downstream rollback

### Phase 3 Risks  
- **High impact**: Core implementation changes
- **Mitigation**: TDD-driven development, incremental integration
- **Rollback**: Complex rollback, may require phase restart

### Phase 4 Risks
- **Critical impact**: Final integration affects entire system
- **Mitigation**: Comprehensive testing, staged rollout
- **Rollback**: Full system rollback required

## Pre-Merge Checklist

- [ ] All foundation tasks completed
- [ ] API compliance verified (zero framework contamination)
- [ ] Conflict analysis complete
- [ ] Merge tooling prepared
- [ ] Validation environment ready
- [ ] Rollback procedure tested

EOF

    success "Merge execution plan created - see MERGE_ORDER.md"
}

# Main execution function
main() {
    log "Starting merge preparation analysis for $TEAM"
    
    # Ensure we're in the right directory
    cd "$WORKDIR"
    
    # Record current state
    log "Current branch: $(git branch --show-current)"
    log "Current commit: $(git rev-parse HEAD)"
    
    # Run analysis phases
    if analyze_team_branches; then
        success "Team branch analysis completed"
    else
        warn "Team branch analysis had issues, continuing..."
    fi
    
    if detect_conflicts; then
        success "Conflict detection completed"
    else
        error "Conflicts detected - manual resolution required"
    fi
    
    if check_api_compliance; then
        success "API compliance check passed"
    else
        error "API compliance violations found - immediate attention required"
    fi
    
    plan_merge_order
    
    # Generate final summary
    cat > MERGE_READINESS_SUMMARY.md << EOF
# Merge Readiness Summary
Generated: $(date)

## Status Overview
- **Branch Analysis**: $([ -f BRANCH_ANALYSIS.md ] && echo "✅ Complete" || echo "❌ Failed")
- **Conflict Detection**: $([ -f CONFLICT_ANALYSIS.md ] && echo "✅ Complete" || echo "❌ Failed")  
- **API Compliance**: $([ -f API_COMPLIANCE.md ] && echo "✅ Complete" || echo "❌ Failed")
- **Merge Planning**: $([ -f MERGE_ORDER.md ] && echo "✅ Complete" || echo "❌ Failed")

## Next Actions
1. Review generated analysis reports
2. Address any detected issues
3. Coordinate with orchestrator for merge approval
4. Execute merge plan when all dependencies satisfied

## Generated Reports
- [Branch Analysis](./BRANCH_ANALYSIS.md)
- [Conflict Analysis](./CONFLICT_ANALYSIS.md)
- [API Compliance Report](./API_COMPLIANCE.md)
- [Merge Execution Plan](./MERGE_ORDER.md)

EOF

    success "Merge preparation analysis complete!"
    log "Review MERGE_READINESS_SUMMARY.md for next steps"
}

# Execute main function
main "$@"