/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright (c) 2025 FreeBSD ixgbe Driver Port
 * 
 * OS Abstraction Layer (OAL) Implementation
 * 
 * Implementation of Linux->FreeBSD API mapping functions that require
 * actual code beyond simple macro substitution.
 */

#include "ixgbe_oal.h"
#include "ixgbe_type.h"

/*
 * ===== MEMORY ALLOCATION TRACKING =====
 */

/* Simple size tracking for vmalloc/vfree mapping */
struct vmalloc_entry {
    void *addr;
    size_t size;
    SLIST_ENTRY(vmalloc_entry) entries;
};

static SLIST_HEAD(vmalloc_head, vmalloc_entry) vmalloc_list = 
    SLIST_HEAD_INITIALIZER(vmalloc_list);
static struct mtx vmalloc_lock;

static void
vmalloc_init(void)
{
    static int initialized = 0;
    if (!initialized) {
        mtx_init(&vmalloc_lock, "vmalloc_tracker", NULL, MTX_DEF);
        initialized = 1;
    }
}

void *
ixgbe_vmalloc_tracked(size_t size)
{
    struct vmalloc_entry *entry;
    void *ptr;
    
    vmalloc_init();
    
    ptr = contigmalloc(size, M_DEVBUF, M_NOWAIT, 0, ~0, 1, 0);
    if (ptr == NULL)
        return NULL;
        
    entry = malloc(sizeof(*entry), M_DEVBUF, M_NOWAIT);
    if (entry == NULL) {
        contigfree(ptr, size, M_DEVBUF);
        return NULL;
    }
    
    entry->addr = ptr;
    entry->size = size;
    
    mtx_lock(&vmalloc_lock);
    SLIST_INSERT_HEAD(&vmalloc_list, entry, entries);
    mtx_unlock(&vmalloc_lock);
    
    return ptr;
}

void
ixgbe_vfree_tracked(void *addr)
{
    struct vmalloc_entry *entry;
    size_t size = 0;
    
    if (addr == NULL)
        return;
        
    vmalloc_init();
    
    mtx_lock(&vmalloc_lock);
    SLIST_FOREACH(entry, &vmalloc_list, entries) {
        if (entry->addr == addr) {
            size = entry->size;
            SLIST_REMOVE(&vmalloc_list, entry, vmalloc_entry, entries);
            break;
        }
    }
    mtx_unlock(&vmalloc_lock);
    
    if (entry != NULL) {
        contigfree(addr, size, M_DEVBUF);
        free(entry, M_DEVBUF);
    }
}

/*
 * ===== PCI CONFIGURATION SPACE ACCESS =====
 */

uint16_t
ixgbe_read_pci_cfg_word(struct ixgbe_hw *hw, uint32_t reg)
{
    struct ixgbe_adapter *adapter = hw->back;
    
    if (adapter == NULL || adapter->dev == NULL)
        return 0xFFFF;
        
    return pci_read_config(adapter->dev, reg, 2);
}

void
ixgbe_write_pci_cfg_word(struct ixgbe_hw *hw, uint32_t reg, uint16_t value)
{
    struct ixgbe_adapter *adapter = hw->back;
    
    if (adapter == NULL || adapter->dev == NULL)
        return;
        
    pci_write_config(adapter->dev, reg, value, 2);
}

uint8_t
ixgbe_read_pci_cfg_byte(struct ixgbe_hw *hw, uint32_t reg)
{
    struct ixgbe_adapter *adapter = hw->back;
    
    if (adapter == NULL || adapter->dev == NULL)
        return 0xFF;
        
    return pci_read_config(adapter->dev, reg, 1);
}

void
ixgbe_write_pci_cfg_byte(struct ixgbe_hw *hw, uint32_t reg, uint8_t value)
{
    struct ixgbe_adapter *adapter = hw->back;
    
    if (adapter == NULL || adapter->dev == NULL)
        return;
        
    pci_write_config(adapter->dev, reg, value, 1);
}

uint32_t
ixgbe_read_pci_cfg_dword(struct ixgbe_hw *hw, uint32_t reg)
{
    struct ixgbe_adapter *adapter = hw->back;
    
    if (adapter == NULL || adapter->dev == NULL)
        return 0xFFFFFFFF;
        
    return pci_read_config(adapter->dev, reg, 4);
}

void
ixgbe_write_pci_cfg_dword(struct ixgbe_hw *hw, uint32_t reg, uint32_t value)
{
    struct ixgbe_adapter *adapter = hw->back;
    
    if (adapter == NULL || adapter->dev == NULL)
        return;
        
    pci_write_config(adapter->dev, reg, value, 4);
}

/*
 * ===== MMIO REGISTER ACCESS =====
 */

uint32_t
ixgbe_read_reg(struct ixgbe_hw *hw, uint32_t reg, bool quiet)
{
    struct ixgbe_adapter *adapter = hw->back;
    uint32_t value;
    
    if (adapter == NULL || hw->hw_addr == NULL) {
        if (!quiet)
            printf("ixgbe: Invalid hardware access attempt\n");
        return IXGBE_FAILED_READ_REG;
    }
    
    /* Use bus_space_read_4 for MMIO access */
    value = bus_space_read_4(adapter->osdep.mem_bus_space_tag,
                            adapter->osdep.mem_bus_space_handle, reg);
                            
    /* Check for hardware removal */
    if (value == IXGBE_FAILED_READ_REG) {
        if (!quiet)
            printf("ixgbe: Hardware read returned all 1s (0x%08x)\n", reg);
        hw->adapter_stopped = true;
    }
    
    return value;
}

void
ixgbe_write_reg(struct ixgbe_hw *hw, uint32_t reg, uint32_t value)
{
    struct ixgbe_adapter *adapter = hw->back;
    
    if (adapter == NULL || hw->hw_addr == NULL) {
        printf("ixgbe: Invalid hardware write attempt\n");
        return;
    }
    
    if (hw->adapter_stopped) {
        printf("ixgbe: Attempted write to stopped adapter\n");
        return;
    }
    
    /* Use bus_space_write_4 for MMIO access */
    bus_space_write_4(adapter->osdep.mem_bus_space_tag,
                      adapter->osdep.mem_bus_space_handle, reg, value);
}

uint8_t
ixgbe_read_reg_byte(struct ixgbe_hw *hw, uint32_t reg)
{
    struct ixgbe_adapter *adapter = hw->back;
    
    if (adapter == NULL || hw->hw_addr == NULL)
        return 0xFF;
        
    return bus_space_read_1(adapter->osdep.mem_bus_space_tag,
                           adapter->osdep.mem_bus_space_handle, reg);
}

/*
 * ===== DEVICE CONTEXT ACCESS =====
 */

struct ifnet *
ixgbe_hw_to_ifnet(const struct ixgbe_hw *hw)
{
    struct ixgbe_adapter *adapter = hw->back;
    return adapter ? adapter->ifp : NULL;
}

struct ixgbe_msg *
ixgbe_hw_to_msg(const struct ixgbe_hw *hw)
{
    struct ixgbe_adapter *adapter = hw->back;
    return adapter ? &adapter->msg : NULL;
}

device_t
ixgbe_pf_to_dev(struct ixgbe_adapter *adapter)
{
    return adapter ? adapter->dev : NULL;
}

/*
 * ===== WORKQUEUE/TASKQUEUE SUPPORT =====
 */

void
ixgbe_task_wrapper(void *context, int pending)
{
    struct ixgbe_work *work = context;
    
    if (work && work->function)
        work->function(work);
}

void
ixgbe_schedule_work(struct ixgbe_work *work)
{
    /* Schedule on system taskqueue */
    taskqueue_enqueue(taskqueue_thread, &work->task);
}

/*
 * ===== TIMER SUPPORT =====
 */

static void
ixgbe_callout_wrapper(void *arg)
{
    struct ixgbe_timer *timer = arg;
    
    if (timer && timer->function)
        timer->function(timer->data);
}

void
ixgbe_setup_timer(struct ixgbe_timer *timer, 
                  void (*function)(unsigned long), unsigned long data)
{
    if (timer == NULL)
        return;
        
    callout_init(&timer->callout, 1);
    timer->function = function;
    timer->data = data;
}

void
ixgbe_mod_timer(struct ixgbe_timer *timer, unsigned long expires)
{
    int ticks_delta;
    
    if (timer == NULL)
        return;
        
    /* Convert jiffies to ticks */
    ticks_delta = (int)(expires - jiffies);
    if (ticks_delta < 0)
        ticks_delta = 0;
        
    callout_reset(&timer->callout, ticks_delta, 
                  ixgbe_callout_wrapper, timer);
}

void
ixgbe_del_timer(struct ixgbe_timer *timer)
{
    if (timer == NULL)
        return;
        
    callout_stop(&timer->callout);
}

void
ixgbe_del_timer_sync(struct ixgbe_timer *timer)
{
    if (timer == NULL)
        return;
        
    callout_drain(&timer->callout);
}

/*
 * ===== ERROR WARNING FUNCTION =====
 */

void
ewarn(struct ixgbe_hw *hw, const char *str)
{
    struct ifnet *ifp = ixgbe_hw_to_ifnet(hw);
    
    if (ifp)
        if_printf(ifp, "WARNING: %s\n", str);
    else
        printf("ixgbe: WARNING: %s\n", str);
}

/*
 * ===== BIT MANIPULATION HELPERS =====
 */

int
ixgbe_test_bit(int nr, volatile unsigned long *addr)
{
    return ((*addr) & (1UL << nr)) != 0;
}

void
ixgbe_set_bit(int nr, volatile unsigned long *addr)
{
    *addr |= (1UL << nr);
}

void
ixgbe_clear_bit(int nr, volatile unsigned long *addr)
{
    *addr &= ~(1UL << nr);
}

int
ixgbe_test_and_set_bit(int nr, volatile unsigned long *addr)
{
    int old = ixgbe_test_bit(nr, addr);
    ixgbe_set_bit(nr, addr);
    return old;
}

int
ixgbe_test_and_clear_bit(int nr, volatile unsigned long *addr)
{
    int old = ixgbe_test_bit(nr, addr);
    ixgbe_clear_bit(nr, addr);
    return old;
}

/*
 * ===== DMA COHERENCY HELPERS =====
 */

void
ixgbe_dma_sync_single_for_cpu(struct ixgbe_adapter *adapter,
                              dma_addr_t dma_addr, size_t size, int direction)
{
    /* FreeBSD bus_dmamap_sync equivalent */
    if (adapter && adapter->dma_tag) {
        /* Sync for CPU access */
        bus_dmamap_sync(adapter->dma_tag, adapter->dma_map, 
                       BUS_DMASYNC_POSTREAD | BUS_DMASYNC_POSTWRITE);
    }
}

void
ixgbe_dma_sync_single_for_device(struct ixgbe_adapter *adapter,
                                 dma_addr_t dma_addr, size_t size, int direction)
{
    /* FreeBSD bus_dmamap_sync equivalent */
    if (adapter && adapter->dma_tag) {
        /* Sync for device access */
        bus_dmamap_sync(adapter->dma_tag, adapter->dma_map,
                       BUS_DMASYNC_PREREAD | BUS_DMASYNC_PREWRITE);
    }
}

/*
 * ===== INTERRUPT DISABLE/ENABLE HELPERS =====
 */

unsigned long
ixgbe_local_irq_save(void)
{
    return intr_disable();
}

void
ixgbe_local_irq_restore(unsigned long flags)
{
    intr_restore(flags);
}

/*
 * ===== STRING AND MEMORY UTILITIES =====
 */

/* These map to standard library functions available in FreeBSD kernel */

#ifndef HAVE_STRLCPY
size_t
ixgbe_strlcpy(char *dst, const char *src, size_t size)
{
    return strlcpy(dst, src, size);
}
#else
#define ixgbe_strlcpy strlcpy
#endif

#ifndef HAVE_STRLCAT  
size_t
ixgbe_strlcat(char *dst, const char *src, size_t size)
{
    return strlcat(dst, src, size);
}
#else
#define ixgbe_strlcat strlcat
#endif

/*
 * ===== ATOMIC OPERATIONS =====
 */

void
ixgbe_atomic_set(volatile int *addr, int value)
{
    atomic_store_rel_int(addr, value);
}

int
ixgbe_atomic_read(volatile int *addr)
{
    return atomic_load_acq_int(addr);
}

void
ixgbe_atomic_inc(volatile int *addr)
{
    atomic_add_int(addr, 1);
}

void
ixgbe_atomic_dec(volatile int *addr)
{
    atomic_subtract_int(addr, 1);
}

int
ixgbe_atomic_inc_return(volatile int *addr)
{
    return atomic_fetchadd_int(addr, 1) + 1;
}

int
ixgbe_atomic_dec_return(volatile int *addr)
{
    return atomic_fetchadd_int(addr, -1) - 1;
}

/*
 * ===== CHECKSUM HELPERS =====
 */

uint16_t
ixgbe_ip_fast_csum(void *iph, unsigned int ihl)
{
    /* FreeBSD has in_cksum for IP header checksum */
    return in_cksum_hdr((struct ip *)iph);
}

uint32_t
ixgbe_csum_tcpudp_magic(uint32_t saddr, uint32_t daddr,
                        unsigned short len, unsigned short proto,
                        uint32_t sum)
{
    /* Simplified implementation - may need refinement */
    sum += htons(len);
    sum += htons(proto);
    sum += (saddr & 0xffff) + (saddr >> 16);
    sum += (daddr & 0xffff) + (daddr >> 16);
    
    while (sum >> 16)
        sum = (sum & 0xffff) + (sum >> 16);
        
    return ~sum;
}