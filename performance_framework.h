/* SPDX-License-Identifier: GPL-2.0-only */
/* Performance Measurement Framework Headers for IXGBE Driver Port
 * Copyright (C) 2024 Intel Corporation
 * 
 * NON-NEGOTIABLE RULES:
 * - Zero framework calls. No iflib/linuxkpi/rte/DPDK usage.
 * - Native OS API calls ONLY.
 * - Thin OAL seams with ifdef trees, inline wrappers, weak symbols.
 */

#ifndef _PERFORMANCE_FRAMEWORK_H_
#define _PERFORMANCE_FRAMEWORK_H_

#include <stdint.h>

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

/* Function prototypes */
int perf_init(void);
void perf_slice_start(struct perf_context *ctx, enum perf_slice slice, const char *name);
int perf_slice_end(struct perf_context *ctx);
void perf_get_stats(enum perf_slice slice, uint64_t *violations, uint64_t *total_measurements);
void perf_set_enabled(int enabled);
void perf_set_budget(enum perf_slice slice, uint64_t budget_ns);
void perf_print_report(void);

/* Convenience macros for instrumentation */
#define PERF_SLICE_BEGIN(ctx, slice, name) perf_slice_start(ctx, slice, name)
#define PERF_SLICE_END(ctx) perf_slice_end(ctx)

#endif /* _PERFORMANCE_FRAMEWORK_H_ */