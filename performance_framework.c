/* SPDX-License-Identifier: GPL-2.0-only */
/* Performance Measurement Framework for IXGBE Driver Port
 * Copyright (C) 2024 Intel Corporation
 * 
 * NON-NEGOTIABLE RULES:
 * - Zero framework calls. No iflib/linuxkpi/rte/DPDK usage.
 * - Native OS API calls ONLY.
 * - Thin OAL seams with ifdef trees, inline wrappers, weak symbols.
 */

/* OS-specific includes with OAL abstraction */
#ifdef __FreeBSD__
#include <sys/types.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <sys/sysctl.h>
#include <machine/cpufunc.h>
#elif defined(__linux__)
#include <sys/types.h>
#include <sys/time.h>
#include <sys/resource.h>
#else
#error "Unsupported OS - only FreeBSD and Linux supported"
#endif

/* Common includes */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>

/* Performance budget thresholds (nanoseconds) per functional slice */
#define PERF_BUDGET_INIT_NS        100000    /* 100μs init budget */
#define PERF_BUDGET_RX_PACKET_NS   1000      /* 1μs per RX packet processing */
#define PERF_BUDGET_TX_PACKET_NS   1000      /* 1μs per TX packet processing */
#define PERF_BUDGET_INTERRUPT_NS   500       /* 500ns interrupt handling */
#define PERF_BUDGET_CLEANUP_NS     50000     /* 50μs cleanup budget */

/* Performance measurement slices */
enum perf_slice {
    PERF_SLICE_INIT = 0,
    PERF_SLICE_RX_PACKET,
    PERF_SLICE_TX_PACKET,
    PERF_SLICE_INTERRUPT,
    PERF_SLICE_CLEANUP,
    PERF_SLICE_MAX
};

/* Performance measurement context */
struct perf_context {
    uint64_t start_tsc;
    uint64_t end_tsc;
    uint64_t budget_ns;
    uint32_t slice_id;
    uint32_t measurement_id;
    char slice_name[32];
};

/* Global performance tracking */
static struct {
    uint64_t slice_budgets[PERF_SLICE_MAX];
    uint64_t slice_violations[PERF_SLICE_MAX];
    uint64_t total_measurements[PERF_SLICE_MAX];
    uint64_t tsc_frequency;
    int measurement_enabled;
} g_perf_tracker = {
    .slice_budgets = {
        [PERF_SLICE_INIT] = PERF_BUDGET_INIT_NS,
        [PERF_SLICE_RX_PACKET] = PERF_BUDGET_RX_PACKET_NS,
        [PERF_SLICE_TX_PACKET] = PERF_BUDGET_TX_PACKET_NS,
        [PERF_SLICE_INTERRUPT] = PERF_BUDGET_INTERRUPT_NS,
        [PERF_SLICE_CLEANUP] = PERF_BUDGET_CLEANUP_NS,
    },
    .measurement_enabled = 1
};

/* Native OS-specific high-precision timestamp functions */
#ifdef __FreeBSD__
static inline uint64_t
perf_read_tsc(void)
{
    return rdtsc(); /* FreeBSD provides rdtsc() in machine/cpufunc.h */
}

static int
perf_init_tsc_frequency(void)
{
    size_t size = sizeof(g_perf_tracker.tsc_frequency);
    if (sysctlbyname("machdep.tsc_freq", &g_perf_tracker.tsc_frequency, 
                     &size, NULL, 0) != 0) {
        /* Fallback: estimate from CPU frequency */
        if (sysctlbyname("hw.clockrate", &g_perf_tracker.tsc_frequency, 
                         &size, NULL, 0) == 0) {
            g_perf_tracker.tsc_frequency *= 1000000; /* MHz to Hz */
        } else {
            /* Conservative fallback */
            g_perf_tracker.tsc_frequency = 2000000000ULL; /* 2GHz */
        }
    }
    return 0;
}

#elif defined(__linux__)
static inline uint64_t
perf_read_tsc(void)
{
    uint32_t lo, hi;
    __asm__ __volatile__ ("rdtsc" : "=a" (lo), "=d" (hi));
    return ((uint64_t)hi << 32) | lo;
}

static int
perf_init_tsc_frequency(void)
{
    FILE *fp;
    char line[256];
    
    fp = fopen("/proc/cpuinfo", "r");
    if (!fp) {
        g_perf_tracker.tsc_frequency = 2000000000ULL; /* 2GHz fallback */
        return -1;
    }
    
    while (fgets(line, sizeof(line), fp)) {
        if (strncmp(line, "cpu MHz", 7) == 0) {
            double mhz;
            if (sscanf(line, "cpu MHz : %lf", &mhz) == 1) {
                g_perf_tracker.tsc_frequency = (uint64_t)(mhz * 1000000);
                break;
            }
        }
    }
    fclose(fp);
    
    if (g_perf_tracker.tsc_frequency == 0) {
        g_perf_tracker.tsc_frequency = 2000000000ULL; /* 2GHz fallback */
    }
    
    return 0;
}

#endif

/* Convert TSC cycles to nanoseconds */
static inline uint64_t
perf_tsc_to_ns(uint64_t tsc_cycles)
{
    return (tsc_cycles * 1000000000ULL) / g_perf_tracker.tsc_frequency;
}

/* Initialize performance measurement subsystem */
int
perf_init(void)
{
    memset(&g_perf_tracker.slice_violations, 0, sizeof(g_perf_tracker.slice_violations));
    memset(&g_perf_tracker.total_measurements, 0, sizeof(g_perf_tracker.total_measurements));
    
    return perf_init_tsc_frequency();
}

/* Start performance measurement for a slice */
void
perf_slice_start(struct perf_context *ctx, enum perf_slice slice, const char *name)
{
    if (!g_perf_tracker.measurement_enabled || !ctx) {
        return;
    }
    
    ctx->slice_id = slice;
    ctx->budget_ns = g_perf_tracker.slice_budgets[slice];
    ctx->start_tsc = perf_read_tsc();
    ctx->measurement_id = (uint32_t)ctx->start_tsc; /* Simple unique ID */
    
    strncpy(ctx->slice_name, name ? name : "unknown", sizeof(ctx->slice_name) - 1);
    ctx->slice_name[sizeof(ctx->slice_name) - 1] = '\0';
}

/* End performance measurement and check budget compliance */
int
perf_slice_end(struct perf_context *ctx)
{
    uint64_t elapsed_ns, elapsed_tsc;
    int budget_violation = 0;
    
    if (!g_perf_tracker.measurement_enabled || !ctx) {
        return 0;
    }
    
    ctx->end_tsc = perf_read_tsc();
    elapsed_tsc = ctx->end_tsc - ctx->start_tsc;
    elapsed_ns = perf_tsc_to_ns(elapsed_tsc);
    
    g_perf_tracker.total_measurements[ctx->slice_id]++;
    
    if (elapsed_ns > ctx->budget_ns) {
        g_perf_tracker.slice_violations[ctx->slice_id]++;
        budget_violation = 1;
        
        /* Log regression budget violation */
        fprintf(stderr, "PERF_VIOLATION: slice=%s id=%u elapsed=%lu ns budget=%lu ns\n",
                ctx->slice_name, ctx->measurement_id, elapsed_ns, ctx->budget_ns);
    }
    
    return budget_violation;
}

/* Get performance statistics */
void
perf_get_stats(enum perf_slice slice, uint64_t *violations, uint64_t *total_measurements)
{
    if (slice >= PERF_SLICE_MAX) {
        return;
    }
    
    if (violations) {
        *violations = g_perf_tracker.slice_violations[slice];
    }
    
    if (total_measurements) {
        *total_measurements = g_perf_tracker.total_measurements[slice];
    }
}

/* Enable/disable performance measurement */
void
perf_set_enabled(int enabled)
{
    g_perf_tracker.measurement_enabled = enabled ? 1 : 0;
}

/* Update budget for a slice (for tuning) */
void
perf_set_budget(enum perf_slice slice, uint64_t budget_ns)
{
    if (slice < PERF_SLICE_MAX) {
        g_perf_tracker.slice_budgets[slice] = budget_ns;
    }
}

/* Print comprehensive performance report */
void
perf_print_report(void)
{
    const char *slice_names[] = {
        [PERF_SLICE_INIT] = "INIT",
        [PERF_SLICE_RX_PACKET] = "RX_PACKET",
        [PERF_SLICE_TX_PACKET] = "TX_PACKET", 
        [PERF_SLICE_INTERRUPT] = "INTERRUPT",
        [PERF_SLICE_CLEANUP] = "CLEANUP"
    };
    
    printf("\n=== IXGBE Performance Report ===\n");
    printf("TSC Frequency: %lu Hz\n", g_perf_tracker.tsc_frequency);
    printf("Measurement Enabled: %s\n\n", g_perf_tracker.measurement_enabled ? "YES" : "NO");
    
    printf("%-12s %-10s %-12s %-12s %-8s\n", 
           "SLICE", "BUDGET(ns)", "VIOLATIONS", "TOTAL", "RATIO");
    printf("%-12s %-10s %-12s %-12s %-8s\n", 
           "------------", "----------", "------------", "------------", "--------");
    
    for (int i = 0; i < PERF_SLICE_MAX; i++) {
        double violation_ratio = 0.0;
        if (g_perf_tracker.total_measurements[i] > 0) {
            violation_ratio = (double)g_perf_tracker.slice_violations[i] / 
                            (double)g_perf_tracker.total_measurements[i] * 100.0;
        }
        
        printf("%-12s %-10lu %-12lu %-12lu %6.2f%%\n",
               slice_names[i],
               g_perf_tracker.slice_budgets[i],
               g_perf_tracker.slice_violations[i],
               g_perf_tracker.total_measurements[i],
               violation_ratio);
    }
    printf("\n");
}

/* Convenience macros for instrumentation */
#define PERF_SLICE_BEGIN(ctx, slice, name) perf_slice_start(ctx, slice, name)
#define PERF_SLICE_END(ctx) perf_slice_end(ctx)

/* TDD Test functions for the performance framework */
#ifdef PERF_TEST_MODE

static void
test_perf_basic_measurement(void)
{
    struct perf_context ctx;
    int violation;
    
    printf("Testing basic measurement...\n");
    
    PERF_SLICE_BEGIN(&ctx, PERF_SLICE_INIT, "test_init");
    usleep(1000); /* 1ms sleep - should violate 100μs budget */
    violation = PERF_SLICE_END(&ctx);
    
    if (violation) {
        printf("PASS: Budget violation correctly detected\n");
    } else {
        printf("FAIL: Budget violation not detected\n");
    }
}

static void 
test_perf_tsc_conversion(void)
{
    uint64_t tsc1, tsc2, elapsed_ns;
    
    printf("Testing TSC conversion...\n");
    
    tsc1 = perf_read_tsc();
    usleep(1000); /* 1ms */
    tsc2 = perf_read_tsc();
    
    elapsed_ns = perf_tsc_to_ns(tsc2 - tsc1);
    
    if (elapsed_ns >= 800000 && elapsed_ns <= 1500000) { /* 0.8-1.5ms tolerance */
        printf("PASS: TSC conversion within tolerance (%lu ns)\n", elapsed_ns);
    } else {
        printf("FAIL: TSC conversion out of tolerance (%lu ns)\n", elapsed_ns);
    }
}

int main(void)
{
    printf("=== Performance Framework TDD Tests ===\n");
    
    if (perf_init() != 0) {
        printf("FAIL: Performance framework initialization failed\n");
        return 1;
    }
    
    test_perf_basic_measurement();
    test_perf_tsc_conversion();
    
    perf_print_report();
    
    return 0;
}

#endif /* PERF_TEST_MODE */