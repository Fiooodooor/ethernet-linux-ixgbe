# IXGBE Performance Measurement Architecture

## Design Philosophy

The performance measurement framework follows strict architectural principles:

1. **Zero Framework Dependencies**: No iflib/linuxkpi/rte_/DPDK usage
2. **Native OS APIs Only**: Direct system calls and OS primitives
3. **Thin OAL Seams**: Minimal abstraction with ifdef trees and inline wrappers
4. **TDD-First Development**: Comprehensive test coverage before implementation
5. **Minimal Source Touch**: Instrumentation points only, no core rewrites

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    IXGBE Driver                             │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐          │
│  │ RX Handler  │ │ TX Handler  │ │ IRQ Handler │   ...    │
│  │     │       │ │     │       │ │     │       │          │
│  │     ▼       │ │     ▼       │ │     ▼       │          │
│  │ PERF_BEGIN  │ │ PERF_BEGIN  │ │ PERF_BEGIN  │          │
│  │     │       │ │     │       │ │     │       │          │
│  │   [work]    │ │   [work]    │ │   [work]    │          │
│  │     │       │ │     │       │ │     │       │          │
│  │ PERF_END    │ │ PERF_END    │ │ PERF_END    │          │
│  └─────────────┘ └─────────────┘ └─────────────┘          │
│         │               │               │                  │
│         ▼               ▼               ▼                  │
├─────────────────────────────────────────────────────────────┤
│                Performance Framework                        │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ perf_slice_start() / perf_slice_end()                │  │
│  │  ├─ TSC timestamp capture                            │  │
│  │  ├─ Budget violation detection                       │  │
│  │  └─ Statistics tracking                              │  │
│  └───────────────────────────────────────────────────────┘  │
│         │                                                   │
│         ▼                                                   │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ OAL Seam Layer (OS Abstraction)                      │  │
│  │  ┌─────────────────┐    ┌─────────────────┐         │  │
│  │  │ FreeBSD         │    │ Linux           │         │  │
│  │  │ - rdtsc()       │    │ - inline asm    │         │  │
│  │  │ - sysctlbyname │    │ - /proc/cpuinfo │         │  │
│  │  │ - machine/      │    │ - sys/ headers  │         │  │
│  │  │   cpufunc.h     │    │                 │         │  │
│  │  └─────────────────┘    └─────────────────┘         │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Performance Slices

The framework measures five critical performance slices:

### 1. PERF_SLICE_INIT (100μs budget)
- Driver initialization and probe functions
- Memory allocation and hardware setup
- One-time setup operations

### 2. PERF_SLICE_RX_PACKET (1μs budget)  
- Per-packet receive processing
- Most critical for throughput
- High-frequency measurement

### 3. PERF_SLICE_TX_PACKET (1μs budget)
- Per-packet transmit processing  
- Critical for latency and throughput
- High-frequency measurement

### 4. PERF_SLICE_INTERRUPT (500ns budget)
- Interrupt service routines
- Most latency-sensitive operations
- Extremely tight budget

### 5. PERF_SLICE_CLEANUP (50μs budget)
- Driver removal and cleanup
- Resource deallocation
- Error handling paths

## Implementation Details

### High-Precision Timing

The framework uses Time Stamp Counter (TSC) for sub-microsecond precision:

**FreeBSD Implementation:**
- Uses native `rdtsc()` from `machine/cpufunc.h`
- Calibrates via `machdep.tsc_freq` sysctl
- Fallback to `hw.clockrate` if needed

**Linux Implementation:**  
- Inline assembly `rdtsc` instruction
- Calibrates via `/proc/cpuinfo` parsing
- Conservative 2GHz fallback

### Budget Violation Detection

```c
elapsed_ns = (end_tsc - start_tsc) * 1000000000 / tsc_frequency;
if (elapsed_ns > budget_ns) {
    log_violation();
    increment_violation_counter();
}
```

### OAL Seam Pattern

```c
#ifdef __FreeBSD__
static inline uint64_t perf_read_tsc(void) {
    return rdtsc(); /* Native FreeBSD call */
}
#elif defined(__linux__)
static inline uint64_t perf_read_tsc(void) {
    uint32_t lo, hi;
    __asm__ __volatile__ ("rdtsc" : "=a" (lo), "=d" (hi));
    return ((uint64_t)hi << 32) | lo;
}
#endif
```

## Usage Patterns

### Basic Instrumentation
```c
struct perf_context ctx;
PERF_SLICE_BEGIN(&ctx, PERF_SLICE_RX_PACKET, "ixgbe_rx_clean");
/* ... critical code section ... */
if (PERF_SLICE_END(&ctx)) {
    handle_performance_regression();
}
```

### Conditional Measurement
```c
#ifdef IXGBE_PERF_MONITORING
struct perf_context ctx;
PERF_SLICE_BEGIN(&ctx, slice_type, operation_name);
#endif
/* ... always-execute code ... */
#ifdef IXGBE_PERF_MONITORING
PERF_SLICE_END(&ctx);
#endif
```

### Statistics Gathering
```c
uint64_t violations, total;
perf_get_stats(PERF_SLICE_RX_PACKET, &violations, &total);
double violation_rate = (double)violations / total * 100.0;
```

## Regression Detection Strategy

### CI Integration
1. **Baseline Establishment**: Run reference workload, capture baseline stats
2. **Change Testing**: Apply changes, run same workload
3. **Regression Detection**: Compare violation rates
4. **Threshold Enforcement**: Fail build if violations exceed threshold (e.g., 1%)

### Production Monitoring
1. **Continuous Measurement**: Always-on in production builds
2. **Telemetry**: Export stats via sysfs/proc interfaces
3. **Alerting**: Log violations for monitoring system pickup
4. **Adaptive Budgets**: Allow runtime budget adjustment

## Memory and Performance Impact

### Framework Overhead
- **Memory**: ~200 bytes per-CPU for tracking structures
- **CPU**: ~20ns overhead per measurement (TSC read + arithmetic)
- **Cache**: Minimal impact due to inline implementation

### Design Optimizations
- **Inline Functions**: Zero function call overhead
- **Compile-Time Disabling**: Complete elimination with `#ifdef`
- **Branch Prediction**: Hot paths optimized for budget compliance
- **Lock-Free**: No synchronization primitives in fast path

## Compliance Verification

### TDD Test Coverage
- Compilation testing for both OS targets
- Functional testing of measurement accuracy
- OAL seam compliance verification
- Budget threshold validation
- Integration readiness verification

### Framework Contamination Prevention
- Static analysis for forbidden API usage
- Automated scanning for iflib/linuxkpi/DPDK references
- OS abstraction layer validation
- Native API verification

## Tuning Guidelines

### Budget Calibration
1. **Baseline Measurement**: Run without budgets, collect timing data
2. **Percentile Analysis**: Set budgets at 95th percentile + 20% margin
3. **Workload Validation**: Test against realistic traffic patterns
4. **Iterative Refinement**: Adjust based on false positive rates

### Platform Optimization
- **TSC Frequency Verification**: Validate calibration accuracy
- **CPU Scaling Impact**: Account for frequency scaling effects
- **NUMA Considerations**: Per-socket calibration if needed
- **Virtualization**: Adjust for hypervisor overhead

This architecture provides comprehensive performance monitoring while maintaining strict adherence to the project's architectural principles and zero-framework-contamination requirements.