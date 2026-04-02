/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright (c) 2025 FreeBSD ixgbe Driver Port
 * 
 * Advanced API Mappings Implementation
 * 
 * Implementation of complex Linux kernel APIs that require more than
 * simple macro substitution. These functions provide FreeBSD native
 * implementations for advanced Linux kernel functionality.
 */

#include "ixgbe_advanced_oal.h"
#include "ixgbe_type.h"
#include <sys/firmware.h>
#include <sys/reboot.h>

/* Forward declaration for DMA map callback */
static void ixgbe_dma_map_addr(void *arg, bus_dma_segment_t *segs, int nseg,
    int error);

/*
 * ===== ADVANCED INTERRUPT HANDLING IMPLEMENTATION =====
 */

int
ixgbe_pci_enable_msix(device_t dev, struct ixgbe_msix_entry *entries, int count)
{
    int actual_count;
    int error;

    if (dev == NULL || entries == NULL || count <= 0)
        return EINVAL;

    /* Allocate MSI-X vectors */
    actual_count = count;
    error = pci_alloc_msix(dev, &actual_count);
    if (error != 0)
        return error;

    if (actual_count != count) {
        /*
         * Fewer vectors allocated than requested; release the allocation
         * before reporting the error so we don't leak MSI-X resources.
         */
        pci_release_msi(dev);
        return ENOSPC;
    }

    /* Fill in the vector assignments */
    for (int i = 0; i < actual_count; i++) {
        entries[i].vector = i + 1;  /* MSI-X vectors start at 1 */
        entries[i].entry = i;
    }

    return 0;
}

void
ixgbe_pci_disable_msix(device_t dev)
{
    pci_release_msi(dev);
}

int
ixgbe_request_irq(struct ixgbe_adapter *adapter, struct ixgbe_irq_data *irq,
                 driver_intr_t handler, void *arg, const char *name)
{
    int error;
    
    /* Allocate interrupt resource */
    irq->res = bus_alloc_resource_any(adapter->dev, SYS_RES_IRQ, &irq->rid, 
                                     RF_SHAREABLE | RF_ACTIVE);
    if (irq->res == NULL)
        return ENXIO;
        
    /* Set up interrupt handler */
    error = bus_setup_intr(adapter->dev, irq->res, 
                          INTR_TYPE_NET | INTR_MPSAFE,
                          NULL, handler, arg, &irq->cookie);
    if (error != 0) {
        bus_release_resource(adapter->dev, SYS_RES_IRQ, irq->rid, irq->res);
        return error;
    }
    
    irq->handler = handler;
    irq->arg = arg;
    strlcpy(irq->name, name, sizeof(irq->name));
    
    return 0;
}

void
ixgbe_free_irq(struct ixgbe_adapter *adapter, struct ixgbe_irq_data *irq)
{
    if (irq->cookie != NULL) {
        bus_teardown_intr(adapter->dev, irq->res, irq->cookie);
        irq->cookie = NULL;
    }
    
    if (irq->res != NULL) {
        bus_release_resource(adapter->dev, SYS_RES_IRQ, irq->rid, irq->res);
        irq->res = NULL;
    }
}

/*
 * ===== ADVANCED DMA IMPLEMENTATION =====
 */

int
ixgbe_dma_tag_create(struct ixgbe_adapter *adapter, bus_dma_tag_t *tag,
                    bus_size_t maxsize, int nsegments, bus_size_t maxsegsize)
{
    if (adapter == NULL || adapter->dev == NULL || tag == NULL)
        return EINVAL;

    return bus_dma_tag_create(
        bus_get_dma_tag(adapter->dev),  /* parent */
        1,                              /* alignment */
        0,                              /* boundary */
        BUS_SPACE_MAXADDR,              /* lowaddr */
        BUS_SPACE_MAXADDR,              /* highaddr */
        NULL, NULL,                     /* filter, filterarg */
        maxsize,                        /* maxsize */
        nsegments,                      /* nsegments */
        maxsegsize,                     /* maxsegsize */
        0,                              /* flags */
        NULL, NULL,                     /* lockfunc, lockarg */
        tag);                           /* dmat */
}

int
ixgbe_dma_mem_alloc(struct ixgbe_adapter *adapter, struct ixgbe_dma_mem *mem,
                   bus_size_t size, bus_size_t alignment)
{
    int error;

    if (adapter == NULL || adapter->dev == NULL || mem == NULL)
        return EINVAL;

    /* Create DMA tag */
    error = bus_dma_tag_create(
        bus_get_dma_tag(adapter->dev),  /* parent */
        alignment,                      /* alignment */
        0,                              /* boundary */
        BUS_SPACE_MAXADDR,              /* lowaddr */
        BUS_SPACE_MAXADDR,              /* highaddr */
        NULL, NULL,                     /* filter, filterarg */
        size,                           /* maxsize */
        1,                              /* nsegments */
        size,                           /* maxsegsize */
        BUS_DMA_COHERENT,               /* flags */
        NULL, NULL,                     /* lockfunc, lockarg */
        &mem->dma_tag);                 /* dmat */
    if (error != 0)
        return error;
        
    /* Allocate DMA memory */
    error = bus_dmamem_alloc(mem->dma_tag,
                            &mem->dma_vaddr,
                            BUS_DMA_COHERENT | BUS_DMA_NOWAIT,
                            &mem->dma_map);
    if (error != 0) {
        bus_dma_tag_destroy(mem->dma_tag);
        return error;
    }
    
    /* Get physical address */
    error = bus_dmamap_load(mem->dma_tag, mem->dma_map,
                           mem->dma_vaddr, size,
                           ixgbe_dma_map_addr, &mem->dma_paddr,
                           BUS_DMA_NOWAIT);
    if (error != 0) {
        bus_dmamem_free(mem->dma_tag, mem->dma_vaddr, mem->dma_map);
        bus_dma_tag_destroy(mem->dma_tag);
        return error;
    }
    
    mem->dma_size = size;
    return 0;
}

static void
ixgbe_dma_map_addr(void *arg, bus_dma_segment_t *segs, int nseg, int error)
{
    bus_addr_t *addr = arg;
    
    if (error == 0)
        *addr = segs[0].ds_addr;
}

void
ixgbe_dma_mem_free(struct ixgbe_adapter *adapter, struct ixgbe_dma_mem *mem)
{
    if (mem->dma_map != NULL) {
        bus_dmamap_unload(mem->dma_tag, mem->dma_map);
        bus_dmamem_free(mem->dma_tag, mem->dma_vaddr, mem->dma_map);
    }
    
    if (mem->dma_tag != NULL)
        bus_dma_tag_destroy(mem->dma_tag);
        
    memset(mem, 0, sizeof(*mem));
}

/*
 * ===== ADVANCED WORKQUEUE IMPLEMENTATION =====
 */

/* System workqueue simulation */
struct taskqueue *ixgbe_system_wq = NULL;

static void
ixgbe_init_system_wq(void)
{
    if (ixgbe_system_wq == NULL) {
        ixgbe_system_wq = taskqueue_thread;
    }
}

void
ixgbe_init_delayed_work(struct ixgbe_delayed_work *dwork,
                       void (*function)(struct ixgbe_work *))
{
    ixgbe_init_system_wq();
    
    INIT_WORK(&dwork->work, function);
    callout_init(&dwork->callout, 1);
    dwork->delay = 0;
}

static void
ixgbe_delayed_work_callout(void *arg)
{
    struct ixgbe_delayed_work *dwork = arg;
    ixgbe_schedule_work(&dwork->work);
}

int
ixgbe_schedule_delayed_work(struct ixgbe_delayed_work *dwork, int delay_jiffies)
{
    int was_pending;
    
    was_pending = callout_pending(&dwork->callout);
    
    if (delay_jiffies == 0) {
        callout_stop(&dwork->callout);
        ixgbe_schedule_work(&dwork->work);
    } else {
        dwork->delay = delay_jiffies;
        callout_reset(&dwork->callout, delay_jiffies,
                     ixgbe_delayed_work_callout, dwork);
    }
    
    return was_pending;
}

int
ixgbe_cancel_delayed_work(struct ixgbe_delayed_work *dwork)
{
    return callout_stop(&dwork->callout);
}

int
ixgbe_cancel_delayed_work_sync(struct ixgbe_delayed_work *dwork)
{
    int was_pending = callout_drain(&dwork->callout);
    /* Also need to wait for any running work */
    taskqueue_drain(ixgbe_system_wq, &dwork->work.task);
    return was_pending;
}

/*
 * ===== POWER MANAGEMENT IMPLEMENTATION =====
 */

int
ixgbe_pci_set_power_state(device_t dev, pci_power_t state)
{
    if (dev == NULL)
        return ENODEV;

    /* FreeBSD power management through PCI subsystem */
    switch (state) {
    case PCI_D0:
        return pci_set_powerstate(dev, PCI_POWERSTATE_D0);
    case PCI_D1:
        return pci_set_powerstate(dev, PCI_POWERSTATE_D1);
    case PCI_D2:
        return pci_set_powerstate(dev, PCI_POWERSTATE_D2);  
    case PCI_D3hot:
        return pci_set_powerstate(dev, PCI_POWERSTATE_D3);
    default:
        return EINVAL;
    }
}

pci_power_t
ixgbe_pci_get_power_state(device_t dev)
{
    int state;

    if (dev == NULL)
        return PCI_D0;

    state = pci_get_powerstate(dev);

    switch (state) {
    case PCI_POWERSTATE_D0:  return PCI_D0;
    case PCI_POWERSTATE_D1:  return PCI_D1;
    case PCI_POWERSTATE_D2:  return PCI_D2;
    case PCI_POWERSTATE_D3:  return PCI_D3hot;
    default:                 return PCI_D0;
    }
}

int
ixgbe_pci_enable_wake(device_t dev, pci_power_t state, bool enable)
{
    /* Simplified wake-on-LAN support */
    uint16_t pmcsr;
    int pmreg;

    if (dev == NULL)
        return ENODEV;

    if (pci_find_cap(dev, PCIY_PMG, &pmreg) != 0)
        return ENODEV;
        
    pmcsr = pci_read_config(dev, pmreg + PCIR_POWER_STATUS, 2);
    
    if (enable) {
        pmcsr |= PCIM_PSTAT_PMEENABLE;
    } else {
        pmcsr &= ~PCIM_PSTAT_PMEENABLE;
    }
    
    pci_write_config(dev, pmreg + PCIR_POWER_STATUS, pmcsr, 2);
    return 0;
}

/*
 * ===== ADVANCED MEMORY MANAGEMENT IMPLEMENTATION =====
 */

void *
ixgbe_alloc_pages(size_t order, int flags)
{
    size_t size = PAGE_SIZE << order;
    int malloc_flags = M_NOWAIT;
    
    if (flags & __GFP_ZERO)
        malloc_flags |= M_ZERO;
        
    return contigmalloc(size, M_DEVBUF, malloc_flags, 
                       0, ~0, PAGE_SIZE, 0);
}

void
ixgbe_free_pages(void *addr, size_t order)
{
    size_t size = PAGE_SIZE << order;
    contigfree(addr, size, M_DEVBUF);
}

/*
 * ===== CPU/NUMA SUPPORT IMPLEMENTATION =====
 */

static SLIST_HEAD(, ixgbe_cpu_notifier) cpu_notifier_list = 
    SLIST_HEAD_INITIALIZER(cpu_notifier_list);
static struct mtx cpu_notifier_lock;
static int cpu_notifier_init = 0;

struct ixgbe_cpu_notifier {
    ixgbe_cpu_notifier_fn fn;
    SLIST_ENTRY(ixgbe_cpu_notifier) entries;
};

static void
ixgbe_cpu_notifier_init(void)
{
    if (!cpu_notifier_init) {
        mtx_init(&cpu_notifier_lock, "ixgbe_cpu_notifier", NULL, MTX_DEF);
        cpu_notifier_init = 1;
    }
}

int
ixgbe_register_cpu_notifier(ixgbe_cpu_notifier_fn fn)
{
    struct ixgbe_cpu_notifier *notifier;
    
    ixgbe_cpu_notifier_init();
    
    notifier = malloc(sizeof(*notifier), M_DEVBUF, M_NOWAIT);
    if (notifier == NULL)
        return ENOMEM;
        
    notifier->fn = fn;
    
    mtx_lock(&cpu_notifier_lock);
    SLIST_INSERT_HEAD(&cpu_notifier_list, notifier, entries);
    mtx_unlock(&cpu_notifier_lock);
    
    return 0;
}

void
ixgbe_unregister_cpu_notifier(ixgbe_cpu_notifier_fn fn)
{
    struct ixgbe_cpu_notifier *notifier;
    
    ixgbe_cpu_notifier_init();
    
    mtx_lock(&cpu_notifier_lock);
    SLIST_FOREACH(notifier, &cpu_notifier_list, entries) {
        if (notifier->fn == fn) {
            SLIST_REMOVE(&cpu_notifier_list, notifier, ixgbe_cpu_notifier, entries);
            break;
        }
    }
    mtx_unlock(&cpu_notifier_lock);
    
    if (notifier != NULL)
        free(notifier, M_DEVBUF);
}

/*
 * ===== PERFORMANCE COUNTER IMPLEMENTATION =====
 */

/* Simple performance counter implementation */
static struct mtx perf_counter_lock;
static int perf_counter_init = 0;

static void
ixgbe_perf_counter_init(void)
{
    if (!perf_counter_init) {
        mtx_init(&perf_counter_lock, "ixgbe_perf", NULL, MTX_DEF);
        perf_counter_init = 1;
    }
}

void
ixgbe_perf_counter_inc(const char *name)
{
    ixgbe_perf_counter_add(name, 1);
}

void  
ixgbe_perf_counter_add(const char *name, uint64_t value)
{
    ixgbe_perf_counter_init();
    
    /* In a full implementation, this would update actual performance counters */
    /* For now, just log significant events */
    if (value > 1000) {
        printf("ixgbe: perf counter %s: %lu\n", name, value);
    }
}

/*
 * ===== REBOOT NOTIFICATION IMPLEMENTATION =====
 */

static SLIST_HEAD(, ixgbe_reboot_notifier) reboot_notifier_list = 
    SLIST_HEAD_INITIALIZER(reboot_notifier_list);
static struct mtx reboot_notifier_lock;
static int reboot_notifier_init = 0;
static eventhandler_tag reboot_event_tag = NULL;

struct ixgbe_reboot_notifier {
    ixgbe_reboot_notifier_fn fn;
    SLIST_ENTRY(ixgbe_reboot_notifier) entries;
};

static void
ixgbe_reboot_event_handler(void *arg, int howto)
{
    struct ixgbe_reboot_notifier *notifier;
    
    mtx_lock(&reboot_notifier_lock);
    SLIST_FOREACH(notifier, &reboot_notifier_list, entries) {
        notifier->fn(howto, NULL);
    }
    mtx_unlock(&reboot_notifier_lock);
}

static void
ixgbe_reboot_notifier_init(void)
{
    if (!reboot_notifier_init) {
        mtx_init(&reboot_notifier_lock, "ixgbe_reboot", NULL, MTX_DEF);
        reboot_event_tag = EVENTHANDLER_REGISTER(shutdown_pre_sync,
                                                ixgbe_reboot_event_handler,
                                                NULL, SHUTDOWN_PRI_FIRST);
        reboot_notifier_init = 1;
    }
}

int
ixgbe_register_reboot_notifier(ixgbe_reboot_notifier_fn fn)
{
    struct ixgbe_reboot_notifier *notifier;
    
    ixgbe_reboot_notifier_init();
    
    notifier = malloc(sizeof(*notifier), M_DEVBUF, M_NOWAIT);
    if (notifier == NULL)
        return ENOMEM;
        
    notifier->fn = fn;
    
    mtx_lock(&reboot_notifier_lock);
    SLIST_INSERT_HEAD(&reboot_notifier_list, notifier, entries);
    mtx_unlock(&reboot_notifier_lock);
    
    return 0;
}

void
ixgbe_unregister_reboot_notifier(ixgbe_reboot_notifier_fn fn)
{
    struct ixgbe_reboot_notifier *notifier;
    
    ixgbe_reboot_notifier_init();
    
    mtx_lock(&reboot_notifier_lock);
    SLIST_FOREACH(notifier, &reboot_notifier_list, entries) {
        if (notifier->fn == fn) {
            SLIST_REMOVE(&reboot_notifier_list, notifier, ixgbe_reboot_notifier, entries);
            break;
        }
    }
    mtx_unlock(&reboot_notifier_lock);
    
    if (notifier != NULL)
        free(notifier, M_DEVBUF);
}

/*
 * ===== SYSCTL INTEGRATION =====
 */

SYSCTL_NODE(_hw, OID_AUTO, ixgbe, CTLFLAG_RD, 0, "ixgbe driver parameters");

int
ixgbe_sysctl_setup(struct ixgbe_adapter *adapter)
{
    struct sysctl_ctx_list *ctx = device_get_sysctl_ctx(adapter->dev);
    struct sysctl_oid *tree = device_get_sysctl_tree(adapter->dev);
    
    /* Add driver-specific sysctls */
    SYSCTL_ADD_INT(ctx, SYSCTL_CHILDREN(tree), OID_AUTO,
                   "num_queues", CTLFLAG_RD, &adapter->num_queues, 0,
                   "Number of queues");
                   
    SYSCTL_ADD_INT(ctx, SYSCTL_CHILDREN(tree), OID_AUTO,
                   "rx_buffer_len", CTLFLAG_RW, &adapter->rx_buffer_len, 0,
                   "RX buffer length");
    
    return 0;
}

void
ixgbe_sysctl_teardown(struct ixgbe_adapter *adapter)
{
    /* FreeBSD automatically cleans up device sysctls */
}

/*
 * ===== FIRMWARE LOADING SUPPORT =====
 */

const struct firmware *
ixgbe_request_firmware(const char *name, device_t dev)
{
    const struct firmware *fw;
    
    fw = firmware_get(name);
    if (fw == NULL) {
        if (dev != NULL) {
            device_printf(dev, "Failed to load firmware '%s'\n", name);
        }
    }
    
    return fw;
}

void
ixgbe_release_firmware(const struct firmware *fw)
{
    if (fw != NULL) {
        firmware_put(fw, FIRMWARE_UNLOAD);
    }
}