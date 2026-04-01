# Native Validator Report Template

## Validation Metadata
- **Validator ID**: native-validator  
- **Team**: nic-port-v2-rerun7
- **Date**: $(date)
- **Task ID**: [TO_BE_FILLED]
- **Review Round**: [1-5]

## Code Under Review
- **Author**: [coder/maker]
- **Files Modified**: [LIST_FILES]
- **Commit Hash**: [GIT_HASH]
- **Purpose**: [DESCRIPTION]

## Non-Negotiable Rules Validation

### ✅ RULE 1: Zero Framework Calls
- [ ] No iflib framework usage detected
- [ ] No DPDK/RTE API calls detected  
- [ ] No LinuxKPI calls detected
- [ ] Native OS APIs used exclusively

**Status**: PASS/FAIL  
**Details**: [EXPLANATION]

### ✅ RULE 2: Native OS API Usage Only
- [ ] malloc/free for memory management
- [ ] device_*/bus_*/pci_* for device ops
- [ ] intr_* for interrupt handling
- [ ] Standard C library functions

**Status**: PASS/FAIL  
**Details**: [EXPLANATION]

### ✅ RULE 3: Thin OAL Seams Only
- [ ] Uses #ifdef trees for compatibility
- [ ] Implements inline wrappers when needed
- [ ] Leverages weak symbols appropriately
- [ ] No framework abstractions

**Status**: PASS/FAIL  
**Details**: [EXPLANATION]

### ✅ RULE 4: TDD-First Implementation
- [ ] Failing test exists before implementation
- [ ] Implementation passes existing tests
- [ ] No new test failures introduced
- [ ] Code verifiable via test suite

**Status**: PASS/FAIL  
**Details**: [EXPLANATION]

### ✅ RULE 5: Minimal Source Touch
- [ ] Uses wrapper functions over rewrites
- [ ] Original code structure preserved
- [ ] Seam layers handle OS differences
- [ ] Changes are surgical, not wholesale

**Status**: PASS/FAIL  
**Details**: [EXPLANATION]

## Validation Decision

**OVERALL RESULT**: APPROVE / REJECT

### If APPROVE:
Code complies with all non-negotiable rules for native porting. Ready for integration.

### If REJECT:
The following violations must be addressed:

1. **[VIOLATION_TYPE]**: [SPECIFIC_ISSUE]
   - **Location**: [FILE:LINE]  
   - **Required Fix**: [REMEDIATION]

2. **[VIOLATION_TYPE]**: [SPECIFIC_ISSUE]
   - **Location**: [FILE:LINE]
   - **Required Fix**: [REMEDIATION]

## Required Actions (If Rejected)

**Round [N] Feedback**:
- [ ] [SPECIFIC_ACTION_1]
- [ ] [SPECIFIC_ACTION_2]  
- [ ] [SPECIFIC_ACTION_3]

**Validation Command Used**:
```bash
./native_validation_check.sh
```

## Handoff Instructions

**If validation passes all rules**: Mark task as completed and notify orchestrator.

**If specialized issues arise**: Hand off to portability-validator with context.

**If maximum rounds exceeded (5)**: Escalate to orchestrator for intervention.

---

*This validation ensures zero framework contamination in ported code per the non-negotiable rules of the nic-port-v2-rerun7 project.*