# Performance Measurement Integration Guide

## Overview

This guide explains how to integrate the performance measurement framework into the IXGBE driver once the OAL seam layer and native validation are complete.

## Files Created

- `performance_framework.c` - Core performance measurement implementation
- `performance_framework.h` - Public API headers
- `test_performance_framework.sh` - TDD test suite

## Integration Steps

### 1. Add Performance Headers to Main Driver

In `src/ixgbe_main.c`, add:

```c
#include "performance_framework.h"

/* Global performance context for driver operations */
static struct perf_context g_driver_perf_ctx;
```

### 2. Initialize Performance Framework

In the driver init function (likely `ixgbe_init_module`), add:

```c
static int __init ixgbe_init_module(void)
{
    int ret;
    
    /* Initialize performance measurement framework */
    ret = perf_init();
    if (ret != 0) {
        pr_warn("ixgbe: Performance measurement framework init failed\n");
    }
    
    /* ... existing init code ... */
}
```

### 3. Instrument Critical Performance Slices

#### Driver Initialization
```c
PERF_SLICE_BEGIN(&g_driver_perf_ctx, PERF_SLICE_INIT, "ixgbe_probe");
/* ... probe/init code ... */
if (PERF_SLICE_END(&g_driver_perf_ctx)) {
    pr_warn("ixgbe: Init performance budget violation\n");
}
```

#### RX Packet Processing
```c
static bool ixgbe_clean_rx_irq(struct ixgbe_q_vector *q_vector,
                               struct ixgbe_ring *rx_ring,
                               int budget)
{
    struct perf_context rx_perf_ctx;
    
    while (likely(total_rx_packets < budget)) {
        PERF_SLICE_BEGIN(&rx_perf_ctx, PERF_SLICE_RX_PACKET, "rx_clean");
        
        /* ... existing RX processing ... */
        
        PERF_SLICE_END(&rx_perf_ctx);
        
        /* ... continue processing ... */
    }
}
```

#### TX Packet Processing
```c
netdev_tx_t ixgbe_xmit_frame_ring(struct sk_buff *skb,
                                  struct ixgbe_adapter *adapter,
                                  struct ixgbe_ring *tx_ring)
{
    struct perf_context tx_perf_ctx;
    
    PERF_SLICE_BEGIN(&tx_perf_ctx, PERF_SLICE_TX_PACKET, "tx_xmit");
    
    /* ... existing TX processing ... */
    
    if (PERF_SLICE_END(&tx_perf_ctx)) {
        adapter->tx_perf_violations++;
    }
    
    return NETDEV_TX_OK;
}
```

#### Interrupt Handling
```c
static irqreturn_t ixgbe_msix_other(int irq, void *data)
{
    struct perf_context irq_perf_ctx;
    
    PERF_SLICE_BEGIN(&irq_perf_ctx, PERF_SLICE_INTERRUPT, "msix_other");
    
    /* ... existing interrupt handling ... */
    
    PERF_SLICE_END(&irq_perf_ctx);
    
    return IRQ_HANDLED;
}
```

#### Cleanup Operations
```c
static void ixgbe_remove(struct pci_dev *pdev)
{
    PERF_SLICE_BEGIN(&g_driver_perf_ctx, PERF_SLICE_CLEANUP, "ixgbe_remove");
    
    /* ... existing cleanup code ... */
    
    PERF_SLICE_END(&g_driver_perf_ctx);
    
    /* Print final performance report */
    perf_print_report();
}
```

### 4. Add Sysfs Interface for Runtime Control

Add to `src/ixgbe_main.c`:

```c
/* Sysfs interface for performance monitoring control */
static ssize_t ixgbe_perf_enabled_show(struct device *dev,
                                       struct device_attribute *attr,
                                       char *buf)
{
    /* Implementation to show current performance monitoring state */
    return sprintf(buf, "%d\n", /* current state */);
}

static ssize_t ixgbe_perf_enabled_store(struct device *dev,
                                        struct device_attribute *attr,
                                        const char *buf, size_t count)
{
    int enabled;
    
    if (kstrtoint(buf, 10, &enabled))
        return -EINVAL;
    
    perf_set_enabled(enabled);
    return count;
}

static DEVICE_ATTR(perf_enabled, S_IRUGO | S_IWUSR,
                   ixgbe_perf_enabled_show, ixgbe_perf_enabled_store);

/* Add to device attribute group */
static struct attribute *ixgbe_attrs[] = {
    &dev_attr_perf_enabled.attr,
    NULL
};

static const struct attribute_group ixgbe_attr_group = {
    .attrs = ixgbe_attrs,
};
```

### 5. Makefile Integration

Add to the driver's Makefile:

```makefile
ixgbe-objs += performance_framework.o
```

## Performance Budget Tuning

The default budgets are conservative. Tune them based on actual workload:

```c
/* Example tuning based on measurement results */
perf_set_budget(PERF_SLICE_RX_PACKET, 800);  /* Tighten RX budget to 800ns */
perf_set_budget(PERF_SLICE_TX_PACKET, 1200); /* Allow more time for TX */
```

## Regression Detection

The framework automatically detects budget violations. Set up CI integration:

```bash
# In test scripts
./load_driver.sh
run_traffic_test.sh
if dmesg | grep "PERF_VIOLATION"; then
    echo "REGRESSION: Performance budget violations detected"
    exit 1
fi
```

## Monitoring

Monitor performance via:
- dmesg output for violations
- Sysfs interface: `/sys/class/net/ethX/device/perf_enabled`
- Direct API calls for custom monitoring tools

## Compliance Notes

- Framework uses only native OS APIs (no iflib/linuxkpi/DPDK)
- OAL seams properly separate FreeBSD vs Linux code paths
- Minimal source touch - only instrumentation points added
- TDD-validated with comprehensive test suite

This integration maintains the NON-NEGOTIABLE RULES while providing comprehensive performance monitoring and regression detection.