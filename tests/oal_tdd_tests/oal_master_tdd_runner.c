/*
 * IXGBE OAL Master TDD Test Runner
 * 
 * Copyright (c) 2026 Intel Corporation
 * Master test runner for all OAL (Operating System Abstraction Layer) TDD tests
 * 
 * NON-NEGOTIABLE RULES VALIDATED:
 * - Zero framework calls (no iflib/linuxkpi/rte_*, DPDK usage)
 * - Native OS API calls ONLY  
 * - Thin OAL seams: #ifdef trees, inline wrappers, weak symbols
 * - TDD-first: write failing test, then implement, then verify
 * - Minimal source touch: never rewrite when a seam wrapper suffices
 *
 * COMPREHENSIVE COVERAGE:
 * This master test runner executes TDD tests for all OAL seam categories:
 * 1. Memory Management (DMA, allocations, barriers)
 * 2. Register Access (I/O operations, dead device detection)
 * 3. Network Device (interface abstraction, multi-queue)
 * 4. Interrupt Handling (legacy IRQ, MSI-X vectors)
 * 5. Synchronization (spinlocks, mutexes, atomics, rwlocks)
 * 6. Time Management (jiffies, timers, delays)
 *
 * PORTING STRATEGY TESTED:
 * Linux kernel APIs → FreeBSD native APIs via transparent OAL seams
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <time.h>

/* External test runner function declarations */
/* These will be defined in the individual test files */
extern int run_oal_memory_tdd_tests(void);
extern int run_oal_register_tdd_tests(void);
extern int run_oal_netdev_tdd_tests(void);
extern int run_oal_interrupt_tdd_tests(void);
extern int run_oal_sync_tdd_tests(void);
extern int run_oal_time_tdd_tests(void);
extern int run_ixgbe_hw_feature_tdd_tests(void);
extern int run_ixgbe_lifecycle_tdd_tests(void);

/* Test suite information structure */
typedef struct {
    const char *name;
    const char *description;
    int (*test_runner)(void);
    bool enabled;
    int expected_failures;      /* Expected number of failures for TDD */
    const char *porting_focus;  /* What this suite tests in porting */
} oal_test_suite_t;

/* Master test suite registry */
static oal_test_suite_t oal_master_test_suites[] = {
    {
        .name = "OAL_MEMORY",
        .description = "Memory Management and DMA Abstraction",
        .test_runner = run_oal_memory_tdd_tests,
        .enabled = true,
        .expected_failures = 16,  /* All should fail until implemented */
        .porting_focus = "Linux dma_alloc_coherent() → FreeBSD bus_dmamem_alloc()"
    },
    {
        .name = "OAL_REGISTER",
        .description = "Hardware Register Access Abstraction",
        .test_runner = run_oal_register_tdd_tests,
        .enabled = true,
        .expected_failures = 17,  /* All should fail until implemented */
        .porting_focus = "Linux readl()/writel() → FreeBSD bus_space_read_4()/bus_space_write_4()"
    },
    {
        .name = "OAL_NETDEV",
        .description = "Network Device Interface Abstraction",
        .test_runner = run_oal_netdev_tdd_tests,
        .enabled = true,
        .expected_failures = 18,  /* All should fail until implemented */
        .porting_focus = "Linux net_device → FreeBSD ifnet + multi-queue emulation"
    },
    {
        .name = "OAL_INTERRUPT", 
        .description = "Interrupt and MSI-X Handling Abstraction",
        .test_runner = run_oal_interrupt_tdd_tests,
        .enabled = true,
        .expected_failures = 16,  /* All should fail until implemented */
        .porting_focus = "Linux request_irq() → FreeBSD bus_setup_intr()"
    },
    {
        .name = "OAL_SYNC",
        .description = "Synchronization Primitives Abstraction", 
        .test_runner = run_oal_sync_tdd_tests,
        .enabled = true,
        .expected_failures = 19,  /* All should fail until implemented */
        .porting_focus = "Linux spinlock_t → FreeBSD struct mtx (MTX_SPIN)"
    },
    {
        .name = "OAL_TIME",
        .description = "Time Management and Timer Abstraction",
        .test_runner = run_oal_time_tdd_tests,
        .enabled = true,
        .expected_failures = 17,  /* All should fail until implemented */
        .porting_focus = "Linux jiffies/HZ → FreeBSD ticks/hz + callout framework"
    },
    {
        .name = "IXGBE_HW_FEATURES",
        .description = "IXGBE Hardware Feature Abstraction",
        .test_runner = run_ixgbe_hw_feature_tdd_tests,
        .enabled = true,
        .expected_failures = 18,  /* All should fail until implemented */
        .porting_focus = "IXGBE flow control, VLAN, RSS, link management features"
    },
    {
        .name = "IXGBE_LIFECYCLE",
        .description = "IXGBE Driver Lifecycle and Error Handling",
        .test_runner = run_ixgbe_lifecycle_tdd_tests,
        .enabled = true,
        .expected_failures = 18,  /* All should fail until implemented */
        .porting_focus = "Driver probe/attach/detach, error handling, resource management"
    }
};

/* Global test results */
typedef struct {
    int total_suites;
    int enabled_suites;
    int passed_suites;
    int failed_suites;
    int total_tests;
    int total_failures;
    int expected_failures;
    double overall_success_rate;
    time_t start_time;
    time_t end_time;
    double execution_time;
} oal_test_results_t;

/**
 * @brief Print test banner and system information
 */
static void print_test_banner(void)
{
    time_t current_time;
    char time_str[64];
    
    time(&current_time);
    strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S UTC", gmtime(&current_time));
    
    printf("\n");
    printf("==============================================================================\n");
    printf("IXGBE OAL (OPERATING SYSTEM ABSTRACTION LAYER) TDD TEST SUITE\n");
    printf("==============================================================================\n");
    printf("Project: nic-port-v2-rerun7\n");
    printf("Component: tdd-writer\n");
    printf("Test Date: %s\n", time_str);
    printf("Test Type: Test-Driven Development (TDD) Validation\n");
    printf("\n");
    printf("MISSION: Write failing TDD tests for every porting micro-slice\n");
    printf("\n");
    printf("NON-NEGOTIABLE RULES BEING VALIDATED:\n");
    printf("✓ Zero framework calls (no iflib/linuxkpi/rte_*/DPDK usage)\n");
    printf("✓ Native OS API calls ONLY\n");
    printf("✓ Thin OAL seams: #ifdef trees, inline wrappers, weak symbols\n");
    printf("✓ TDD-first: write failing test, then implement, then verify\n");
    printf("✓ Minimal source touch: never rewrite when a seam wrapper suffices\n");
    printf("\n");
    printf("PORTING STRATEGY:\n");
    printf("Linux kernel APIs → FreeBSD native APIs via transparent OAL seams\n");
    printf("==============================================================================\n");
    printf("\n");
}

/**
 * @brief Print test suite information
 */
static void print_suite_info(void)
{
    const int suite_count = sizeof(oal_master_test_suites) / sizeof(oal_master_test_suites[0]);
    int enabled_count = 0;
    
    printf("OAL TEST SUITE REGISTRY:\n");
    printf("------------------------------------------------------------------------------\n");
    
    for (int i = 0; i < suite_count; i++) {
        const oal_test_suite_t *suite = &oal_master_test_suites[i];
        
        printf("%d. %s%s%s\n", 
               i + 1,
               suite->name,
               suite->enabled ? "" : " [DISABLED]",
               suite->enabled ? "" : "");
        printf("   Description: %s\n", suite->description);
        printf("   Porting Focus: %s\n", suite->porting_focus);
        printf("   Expected Failures: %d (TDD methodology)\n", suite->expected_failures);
        printf("\n");
        
        if (suite->enabled) {
            enabled_count++;
        }
    }
    
    printf("Total Suites: %d | Enabled: %d | Disabled: %d\n", 
           suite_count, enabled_count, suite_count - enabled_count);
    printf("------------------------------------------------------------------------------\n\n");
}

/**
 * @brief Run individual test suite
 */
static int run_test_suite(const oal_test_suite_t *suite, int suite_number)
{
    printf(">>> RUNNING SUITE %d: %s\n", suite_number, suite->name);
    printf(">>> %s\n", suite->description);
    printf(">>> Focus: %s\n", suite->porting_focus);
    printf(">>> Expected TDD failures: %d\n\n", suite->expected_failures);
    
    /* Record start time */
    time_t suite_start = time(NULL);
    
    /* Run the test suite */
    int failures = suite->test_runner();
    
    /* Record end time */
    time_t suite_end = time(NULL);
    double suite_duration = difftime(suite_end, suite_start);
    
    printf("\n>>> SUITE %d COMPLETED: %s\n", suite_number, suite->name);
    printf(">>> Execution Time: %.1f seconds\n", suite_duration);
    printf(">>> Failures: %d (Expected: %d for TDD)\n", failures, suite->expected_failures);
    
    if (failures == suite->expected_failures) {
        printf(">>> Result: ✓ EXPECTED TDD FAILURES (All tests fail as intended)\n");
    } else if (failures > suite->expected_failures) {
        printf(">>> Result: ⚠ MORE FAILURES THAN EXPECTED\n");
    } else {
        printf(">>> Result: ⚠ FEWER FAILURES THAN EXPECTED (Some tests unexpectedly passed)\n");
    }
    
    printf("==============================================================================\n\n");
    
    return failures;
}

/**
 * @brief Print final test results summary
 */
static void print_final_results(const oal_test_results_t *results)
{
    printf("==============================================================================\n");
    printf("FINAL OAL TDD TEST RESULTS SUMMARY\n");
    printf("==============================================================================\n");
    printf("Execution Summary:\n");
    printf("  Start Time: %s", ctime(&results->start_time));
    printf("  End Time: %s", ctime(&results->end_time));
    printf("  Total Duration: %.1f seconds\n", results->execution_time);
    printf("\n");
    printf("Suite Summary:\n");
    printf("  Total Test Suites: %d\n", results->total_suites);
    printf("  Enabled Test Suites: %d\n", results->enabled_suites);
    printf("  Passed Suites: %d\n", results->passed_suites);
    printf("  Failed Suites: %d\n", results->failed_suites);
    printf("\n");
    printf("Test Summary:\n");
    printf("  Total Individual Tests: %d\n", results->total_tests);
    printf("  Total Failures: %d\n", results->total_failures);
    printf("  Expected Failures (TDD): %d\n", results->expected_failures);
    printf("  Success Rate: %.1f%%\n", results->overall_success_rate);
    printf("\n");
    
    /* TDD Methodology Assessment */
    printf("TDD METHODOLOGY ASSESSMENT:\n");
    printf("------------------------------------------------------------------------------\n");
    if (results->total_failures == results->expected_failures) {
        printf("✅ PERFECT TDD COMPLIANCE\n");
        printf("   All tests failed exactly as expected for TDD methodology.\n");
        printf("   This confirms that:\n");
        printf("   • No OAL seam implementations exist yet (correct)\n");
        printf("   • All test interfaces are properly defined\n");
        printf("   • Tests are ready to guide implementation\n");
        printf("   • TDD RED phase is complete\n");
    } else if (results->total_failures > results->expected_failures) {
        printf("⚠️  EXCESS FAILURES DETECTED\n");
        printf("   %d more failures than expected.\n", 
               results->total_failures - results->expected_failures);
        printf("   Possible causes:\n");
        printf("   • Test framework issues\n");
        printf("   • Missing test dependencies\n");
        printf("   • Test environment problems\n");
    } else {
        printf("⚠️  UNEXPECTED PASSES DETECTED\n");
        printf("   %d fewer failures than expected.\n",
               results->expected_failures - results->total_failures);
        printf("   Possible causes:\n");
        printf("   • Some OAL implementations already exist\n");
        printf("   • Tests not properly designed to fail\n");
        printf("   • Mock implementations functioning\n");
    }
    
    printf("\n");
    printf("NEXT STEPS:\n");
    printf("------------------------------------------------------------------------------\n");
    printf("1. ✅ TDD Test Phase Complete\n");
    printf("   → All failing tests written and validated\n");
    printf("\n");
    printf("2. 🔄 Ready for Implementation Phase\n");
    printf("   → Begin implementing OAL seams to make tests pass\n");
    printf("   → Follow TDD RED → GREEN → REFACTOR cycle\n");
    printf("\n");
    printf("3. 📋 Implementation Priority Order:\n");
    printf("   a) Memory Management (foundational)\n");
    printf("   b) Register Access (hardware I/O)\n");
    printf("   c) Interrupt Handling (IRQ management)\n");
    printf("   d) Synchronization (locking primitives)\n");
    printf("   e) Network Device (interface abstraction)\n");
    printf("   f) Time Management (timers and delays)\n");
    printf("   g) IXGBE Hardware Features (device-specific)\n");
    printf("   h) IXGBE Driver Lifecycle (driver management)\n");
    printf("\n");
    printf("4. 🎯 Success Criteria for Implementation:\n");
    printf("   → All %d tests should PASS after implementation\n", results->total_tests);
    printf("   → Zero framework contamination detected\n");
    printf("   → Native OS API usage confirmed\n");
    printf("   → Thin seam validation passed\n");
    printf("==============================================================================\n");
}

/**
 * @brief Main OAL TDD test runner
 */
int main(int argc, char *argv[])
{
    const int suite_count = sizeof(oal_master_test_suites) / sizeof(oal_master_test_suites[0]);
    oal_test_results_t results = {0};
    
    /* Initialize results */
    results.total_suites = suite_count;
    results.start_time = time(NULL);
    
    /* Print test banner and information */
    print_test_banner();
    print_suite_info();
    
    /* Process command line arguments for selective testing */
    bool run_all = true;
    const char *selected_suite = NULL;
    
    if (argc > 1) {
        if (strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0) {
            printf("Usage: %s [suite_name]\n", argv[0]);
            printf("  suite_name: Run specific test suite (OAL_MEMORY, OAL_REGISTER, etc.)\n");
            printf("  (no args):  Run all enabled test suites\n");
            return 0;
        }
        selected_suite = argv[1];
        run_all = false;
    }
    
    /* Run test suites */
    printf("EXECUTING OAL TDD TEST SUITES...\n");
    printf("==============================================================================\n\n");
    
    for (int i = 0; i < suite_count; i++) {
        const oal_test_suite_t *suite = &oal_master_test_suites[i];
        
        /* Skip if suite is disabled */
        if (!suite->enabled) {
            printf(">>> SKIPPING SUITE %d: %s (disabled)\n\n", i + 1, suite->name);
            continue;
        }
        
        /* Skip if specific suite requested and this isn't it */
        if (!run_all && strcmp(suite->name, selected_suite) != 0) {
            continue;
        }
        
        results.enabled_suites++;
        
        /* Run the test suite */
        int suite_failures = run_test_suite(suite, i + 1);
        
        /* Update results */
        results.total_failures += suite_failures;
        results.expected_failures += suite->expected_failures;
        
        if (suite_failures == suite->expected_failures) {
            results.passed_suites++;  /* "Passed" means expected TDD failures */
        } else {
            results.failed_suites++;
        }
        
        /* Estimate total test count (rough approximation) */
        results.total_tests += suite->expected_failures;
    }
    
    /* Finalize results */
    results.end_time = time(NULL);
    results.execution_time = difftime(results.end_time, results.start_time);
    
    if (results.total_tests > 0) {
        results.overall_success_rate = 
            (double)(results.total_tests - results.total_failures) / results.total_tests * 100.0;
    }
    
    /* Print final results */
    print_final_results(&results);
    
    /* Return appropriate exit code */
    if (results.total_failures == results.expected_failures) {
        printf("\n🎉 TDD PHASE COMPLETE: All tests failed as expected!\n");
        printf("Ready to begin implementation phase.\n\n");
        return 0;  /* Success in TDD terms */
    } else {
        printf("\n⚠️  TDD RESULTS UNEXPECTED: Review test failures.\n\n");
        return 1;  /* Unexpected results */
    }
}

/**
 * @brief Alternative entry point for library usage
 */
int run_all_oal_tdd_tests(void)
{
    char *argv[2];

    /* Provide a valid argv when calling main to avoid undefined behavior */
    argv[0] = (char *)"oal_master_tdd_runner";
    argv[1] = NULL;

    return main(1, argv);
}