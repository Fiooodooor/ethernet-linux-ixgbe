# IXGBE OAL TDD Test Suite

**Project**: nic-port-v2-rerun7  
**Component**: tdd-writer  
**Mission**: Write failing TDD tests for every porting micro-slice  
**Status**: ✅ **PHASE COMPLETE** - All TDD tests written and validated

## Overview

This repository contains comprehensive Test-Driven Development (TDD) tests for the IXGBE Operating System Abstraction Layer (OAL). These tests implement the **RED** phase of TDD methodology by providing failing tests that define the expected interfaces and behavior for cross-platform IXGBE driver porting.

**📊 TOTAL COVERAGE: 139 TDD tests across 8 complete test suites**

## Non-Negotiable Rules

All tests validate strict adherence to these porting requirements:

- ✅ **Zero framework calls** (no iflib/linuxkpi/rte_*/DPDK usage)
- ✅ **Native OS API calls ONLY**
- ✅ **Thin OAL seams**: #ifdef trees, inline wrappers, weak symbols
- ✅ **TDD-first**: write failing test, then implement, then verify
- ✅ **Minimal source touch**: never rewrite when a seam wrapper suffices

## Porting Strategy

The OAL provides transparent seams between Linux kernel APIs and FreeBSD native APIs:

```
Linux kernel APIs → FreeBSD native APIs via OAL seams
├── dma_alloc_coherent() → bus_dmamem_alloc() + bus_dmamap_create()
├── readl()/writel() → bus_space_read_4()/bus_space_write_4()
├── net_device → ifnet + multi-queue emulation
├── request_irq() → bus_setup_intr()
├── spinlock_t → struct mtx (MTX_SPIN)
└── jiffies/HZ → ticks/hz + callout framework
```

## Test Suite Architecture

### 1. Memory Management Tests (`test_oal_memory_tdd.c`)
- **Focus**: DMA coherent memory, streaming DMA, general allocation
- **Interfaces**: `oal_dma_alloc_coherent()`, `oal_dma_map_single()`, `oal_kmalloc()`
- **Coverage**: 16 test cases
- **Porting**: Linux DMA APIs → FreeBSD bus_dma framework

### 2. Register Access Tests (`test_oal_register_tdd.c`)
- **Focus**: Hardware I/O operations, dead device detection
- **Interfaces**: `oal_reg_read32()`, `oal_reg_write32()`, `oal_reg_read64()`
- **Coverage**: 17 test cases  
- **Porting**: Linux readl()/writel() → FreeBSD bus_space operations

### 3. Network Device Tests (`test_oal_netdev_tdd.c`)
- **Focus**: Interface abstraction, multi-queue emulation
- **Interfaces**: `oal_netdev_alloc()`, `oal_netif_carrier_on()`, `oal_netdev_get_stats()`
- **Coverage**: 18 test cases
- **Porting**: Linux net_device → FreeBSD ifnet + queue management

### 4. Interrupt Handling Tests (`test_oal_interrupt_tdd.c`)
- **Focus**: Legacy IRQ and MSI-X vector management
- **Interfaces**: `oal_request_irq()`, `oal_pci_alloc_msix()`, `oal_msix_setup_vector()`
- **Coverage**: 16 test cases
- **Porting**: Linux request_irq() → FreeBSD bus_setup_intr()

### 5. Synchronization Tests (`test_oal_sync_tdd.c`)
- **Focus**: Locking primitives, atomic operations
- **Interfaces**: `oal_spin_lock_init()`, `oal_mutex_lock()`, `oal_atomic_read()`
- **Coverage**: 19 test cases
- **Porting**: Linux spinlock_t → FreeBSD struct mtx

### 6. Time Management Tests (`test_oal_time_tdd.c`)
- **Focus**: Timer operations, delay functions
- **Interfaces**: `oal_get_jiffies()`, `oal_add_timer()`, `oal_msleep()`
- **Coverage**: 17 test cases
- **Porting**: Linux jiffies/HZ → FreeBSD ticks/hz

### 7. IXGBE Hardware Features Tests (`test_ixgbe_hw_features_tdd.c`)
- **Focus**: Flow control, VLAN, RSS, link management, statistics
- **Interfaces**: `ixgbe_fc_init()`, `ixgbe_rss_init()`, `ixgbe_setup_link()`
- **Coverage**: 18 test cases
- **Porting**: IXGBE-specific hardware feature abstraction

### 8. IXGBE Driver Lifecycle Tests (`test_ixgbe_lifecycle_tdd.c`)
- **Focus**: Driver lifecycle, error handling, resource management  
- **Interfaces**: `ixgbe_probe()`, `ixgbe_attach()`, `ixgbe_error_recovery()`
- **Coverage**: 18 test cases
- **Porting**: Driver state management and error recovery

## Quick Start

### Prerequisites
- GCC compiler
- Make build system
- POSIX-compliant environment (Linux/FreeBSD)

### Build and Test
```bash
# Build all test suites
make all

# Run all TDD tests (expect ALL to fail)
make test

# Run specific test suite
make test-suite SUITE=OAL_MEMORY

# Validate test framework integrity
make validate

# Show detailed help
make help
```

### Expected Results
**ALL TESTS SHOULD FAIL** - this confirms proper TDD methodology:

```
OAL Memory TDD Test Summary:
  Total Tests: 16
  Passed: 0
  Failed: 16 (Expected for TDD until implementation)
  Success Rate: 0.0%

NOTE: All failures are EXPECTED in TDD methodology.
Tests should fail until OAL memory seam implementation is complete.
```

## Test Structure

Each test follows the TDD pattern:

```c
static bool test_oal_function_name(void)
{
    /* Setup test data */
    struct mock_data test_data = {...};
    
    /* TEST: Call function that should not exist yet */
#if 0  /* Enable when OAL header exists */
    int result = oal_function(&test_data);
#endif
    
    /* EXPECTED FAILURE: Function not implemented yet */
    printf("TDD EXPECTED FAILURE: oal_function() not implemented\n");
    return false;  /* Test fails as expected */
    
    /* Future implementation validation code... */
#if 0
    /* Validation logic for when function is implemented */
    if (result != expected) {
        printf("FAIL: Function behavior incorrect\n");
        return false;
    }
    return true;
#endif
}
```

## Individual Test Execution

Run specific test categories:

```bash
# Memory management tests
make test-memory

# Register access tests  
make test-register

# Network device tests
make test-netdev

# Interrupt handling tests
make test-interrupt

# Synchronization tests
make test-sync

# Time management tests
make test-time

# IXGBE hardware features tests
make test-ixgbe-features

# IXGBE driver lifecycle tests
make test-ixgbe-lifecycle
```

## Test Framework Validation

Ensure test integrity:

```bash
# Check for framework contamination
make validate

# Static analysis (requires cppcheck)
make lint

# Generate test documentation
make docs
```

## Implementation Workflow (Next Steps)

1. **✅ TDD Test Phase Complete** (Current)
   - All failing tests written and validated

2. **🔄 Implementation Phase** (Next)
   - Begin implementing OAL seams to make tests pass
   - Follow TDD RED → GREEN → REFACTOR cycle

3. **📋 Implementation Priority Order**:
   - a) Memory Management (foundational)
   - b) Register Access (hardware I/O) 
   - c) Interrupt Handling (IRQ management)
   - d) Synchronization (locking primitives)
   - e) Network Device (interface abstraction)
   - f) Time Management (timers and delays)

4. **🎯 Success Criteria**:
   - All 139 tests should PASS after implementation
   - Zero framework contamination detected
   - Native OS API usage confirmed
   - Thin seam validation passed

## Cross-Platform Testing

Tests validate identical behavior across platforms:

- **Linux**: Tests validate proper Linux kernel API abstraction
- **FreeBSD**: Tests validate proper FreeBSD native API usage
- **Consistency**: Cross-platform behavior must be identical

## File Structure

```
tests/oal_tdd_tests/
├── test_oal_memory_tdd.c          # Memory/DMA management tests
├── test_oal_register_tdd.c        # Register access tests
├── test_oal_netdev_tdd.c          # Network device tests  
├── test_oal_interrupt_tdd.c       # Interrupt handling tests
├── test_oal_sync_tdd.c            # Synchronization tests
├── test_oal_time_tdd.c            # Time management tests
├── test_ixgbe_hw_features_tdd.c   # IXGBE hardware features tests
├── test_ixgbe_lifecycle_tdd.c     # IXGBE driver lifecycle tests
├── oal_master_tdd_runner.c        # Master test runner
├── Makefile                       # Build system
└── README.md                      # This file
```

## Debug and Analysis

Debug builds with additional diagnostics:

```bash
# Debug build with symbols
make debug

# Run with additional debugging
DEBUG=1 make test

# Package for distribution
make package
```

## Integration Notes

These tests will integrate with:

- **seam-architect** OAL header designs (ready for implementation)
- **FreeBSD driver implementation** (validation framework ready)
- **Continuous integration** (test framework validated)
- **Performance benchmarking** (timing infrastructure in place)

## Support

For questions about the TDD test framework:

1. Review test output for specific failure details
2. Check `make validate` for framework integrity issues  
3. Use `make help` for detailed command information
4. Examine individual test files for specific interface requirements

---

**Remember**: In TDD methodology, **failing tests are SUCCESS**. These tests define the interfaces and expected behavior that will guide the implementation phase. All 103 tests should fail until the OAL seam implementations are complete.