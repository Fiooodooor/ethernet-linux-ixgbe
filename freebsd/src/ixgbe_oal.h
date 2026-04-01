/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright (c) 2025 FreeBSD ixgbe Driver Port
 * 
 * OS Abstraction Layer (OAL) for Linux->FreeBSD API Mapping
 * 
 * This header provides thin wrapper seams that map Linux kernel APIs
 * to their FreeBSD equivalents. The mappings follow these principles:
 * 
 * 1. ZERO framework dependencies (no iflib, linuxkpi, DPDK, etc.)
 * 2. Native FreeBSD APIs only
 * 3. Minimal source code changes to original Linux driver
 * 4. Thin inline wrappers and preprocessor macros
 * 5. #ifdef trees for platform-specific code paths
 * 
 * Each mapping is documented with the Linux->FreeBSD equivalent.
 */

#ifndef _IXGBE_OAL_H_
#define _IXGBE_OAL_H_

/* FreeBSD system headers */
#include <sys/param.h>
#include <sys/bus.h>
#include <sys/endian.h>
#include <sys/kernel.h>
#include <sys/lock.h>
#include <sys/malloc.h>
#include <sys/mbuf.h>
#include <sys/module.h>
#include <sys/mutex.h>
#include <sys/rman.h>
#include <sys/socket.h>
#include <sys/sockio.h>
#include <sys/sysctl.h>
#include <sys/taskqueue.h>
#include <sys/time.h>

#include <dev/pci/pcivar.h>
#include <dev/pci/pcireg.h>

#include <net/bpf.h>
#include <net/ethernet.h>
#include <net/if.h>
#include <net/if_var.h>
#include <net/if_arp.h>
#include <net/if_dl.h>
#include <net/if_media.h>
#include <net/if_types.h>
#include <net/if_vlan_var.h>

#include <netinet/in.h>
#include <netinet/in_systm.h>
#include <netinet/if_ether.h>
#include <netinet/ip.h>
#include <netinet/ip6.h>
#include <netinet/tcp.h>
#include <netinet/udp.h>

#include <machine/bus.h>
#include <machine/in_cksum.h>
#include <machine/resource.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * ===== FUNDAMENTAL TYPE MAPPINGS =====
 */

/* Linux types -> FreeBSD types */
typedef uint8_t  u8;
typedef uint16_t u16; 
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t   s8;
typedef int16_t  s16;
typedef int32_t  s32;
typedef int64_t  s64;

typedef bus_addr_t dma_addr_t;
typedef vm_paddr_t phys_addr_t;

/* Boolean definitions */
#ifndef true
#define true 1
#define false 0
#endif

#ifndef TRUE
#define TRUE true
#define FALSE false
#endif

/*
 * ===== MEMORY MANAGEMENT MAPPINGS =====
 */

/* Memory allocation flags mapping */
#define GFP_KERNEL    M_NOWAIT
#define GFP_ATOMIC    M_NOWAIT
#define GFP_NOWAIT    M_NOWAIT

/* Linux kmalloc/kfree -> FreeBSD malloc/free */
static inline void *
ixgbe_malloc(void *hw_unused, size_t size)
{
    return malloc(size, M_DEVBUF, M_NOWAIT | M_ZERO);
}

static inline void *
ixgbe_calloc(void *hw_unused, size_t num, size_t size)
{
    size_t total = num * size;
    void *ptr = malloc(total, M_DEVBUF, M_NOWAIT | M_ZERO);
    if (ptr)
        memset(ptr, 0, total);
    return ptr;
}

static inline void
ixgbe_free(void *hw_unused, void *ptr)
{
    if (ptr)
        free(ptr, M_DEVBUF);
}

/* Linux vmalloc/vfree -> FreeBSD contigmalloc/contigfree */
static inline void *
ixgbe_vmalloc(size_t size)
{
    return contigmalloc(size, M_DEVBUF, M_NOWAIT, 0, ~0, 1, 0);
}

static inline void
ixgbe_vfree(void *ptr)
{
    if (ptr) {
        /* Note: Would need to track size for contigfree in real implementation */
        contigfree(ptr, 0, M_DEVBUF);  /* Size tracking needed */
    }
}

/*
 * ===== DMA MEMORY MANAGEMENT =====
 */

/* Linux dma_alloc_coherent -> FreeBSD bus_dmamem_alloc */
static inline void *
ixgbe_dma_alloc_coherent(void *dev, size_t size, bus_addr_t *dma_handle)
{
    void *vaddr;
    
    /* Simplified mapping - real implementation needs bus_dma tag setup */
    vaddr = contigmalloc(size, M_DEVBUF, M_NOWAIT, 0, ~0, PAGE_SIZE, 0);
    if (vaddr && dma_handle) {
        *dma_handle = vtophys(vaddr);
    }
    return vaddr;
}

static inline void
ixgbe_dma_free_coherent(void *dev, size_t size, void *vaddr, bus_addr_t dma_handle)
{
    if (vaddr) {
        contigfree(vaddr, size, M_DEVBUF);
    }
}

/*
 * ===== SYNCHRONIZATION PRIMITIVES =====
 */

/* Linux mutex -> FreeBSD mtx */
typedef struct mtx ixgbe_lock;

#define ixgbe_init_lock(lock) \
    mtx_init((lock), "ixgbe_lock", NULL, MTX_DEF)

#define ixgbe_destroy_lock(lock) \
    mtx_destroy(lock)

#define ixgbe_acquire_lock(lock) \
    mtx_lock(lock)

#define ixgbe_release_lock(lock) \
    mtx_unlock(lock)

/* Linux spinlock -> FreeBSD spinlock */
typedef struct mtx ixgbe_spinlock;

static inline void
ixgbe_spin_lock_init(ixgbe_spinlock *lock)
{
    mtx_init(lock, "ixgbe_spin", NULL, MTX_SPIN);
}

static inline void
ixgbe_spin_lock_irqsave(ixgbe_spinlock *lock, unsigned long *flags)
{
    *flags = intr_disable();
    mtx_lock_spin(lock);
}

static inline void
ixgbe_spin_unlock_irqrestore(ixgbe_spinlock *lock, unsigned long flags)
{
    mtx_unlock_spin(lock);
    intr_restore(flags);
}

/*
 * ===== TIMING AND DELAY FUNCTIONS =====
 */

/* Linux udelay -> FreeBSD DELAY */
#define usec_delay(x)  DELAY(x)

/* Linux msleep -> FreeBSD pause */
#define msec_delay(x)  pause("ixgbe", ((x) * hz) / 1000)

/* Jiffies and time conversions */
#define jiffies        ticks
#define HZ             hz

static inline unsigned long
msecs_to_jiffies(unsigned int msecs)
{
    return (msecs * hz) / 1000;
}

static inline unsigned int
jiffies_to_msecs(unsigned long jiffies)
{
    return (jiffies * 1000) / hz;
}

/*
 * ===== BYTE ORDER CONVERSIONS =====
 */

/* Linux byte order -> FreeBSD byte order */
#define IXGBE_CPU_TO_BE16(x)   htobe16(x)
#define IXGBE_BE16_TO_CPU(x)   be16toh(x)
#define IXGBE_CPU_TO_BE32(x)   htobe32(x)
#define IXGBE_BE32_TO_CPU(x)   be32toh(x)

#define IXGBE_CPU_TO_LE16(x)   htole16(x)
#define IXGBE_LE16_TO_CPU(x)   le16toh(x)
#define IXGBE_CPU_TO_LE32(x)   htole32(x)
#define IXGBE_LE32_TO_CPU(x)   le32toh(x)
#define IXGBE_CPU_TO_LE64(x)   htole64(x)
#define IXGBE_LE64_TO_CPU(x)   le64toh(x)

/* Linux htonl family -> FreeBSD */
#define IXGBE_HTONL(x)         htonl(x)
#define IXGBE_NTOHL(x)         ntohl(x)
#define IXGBE_NTOHS(x)         ntohs(x)

/* Special LE32 operations */
#define IXGBE_LE32_TO_CPUS(x)  do { *(x) = le32toh(*(x)); } while(0)

/*
 * ===== PCI CONFIGURATION SPACE ACCESS =====
 */

/* Forward declaration of ixgbe_hw structure */
struct ixgbe_hw;

/* PCI config space read/write functions */
extern uint16_t ixgbe_read_pci_cfg_word(struct ixgbe_hw *hw, uint32_t reg);
extern void ixgbe_write_pci_cfg_word(struct ixgbe_hw *hw, uint32_t reg, uint16_t value);

#define IXGBE_READ_PCIE_WORD   ixgbe_read_pci_cfg_word
#define IXGBE_WRITE_PCIE_WORD  ixgbe_write_pci_cfg_word

/*
 * ===== I/O MEMORY ACCESS =====
 */

/* Linux ioremap -> FreeBSD bus_space_map */
#define IOMEM              /* annotation only */

/* Register read/write macros will use bus_space_* functions */
extern uint32_t ixgbe_read_reg(struct ixgbe_hw *hw, uint32_t reg, bool quiet);
extern void ixgbe_write_reg(struct ixgbe_hw *hw, uint32_t reg, uint32_t value);

#define IXGBE_READ_REG(hw, reg)           ixgbe_read_reg(hw, reg, false)
#define IXGBE_R32_Q(hw, reg)             ixgbe_read_reg(hw, reg, true)
#define IXGBE_WRITE_REG(hw, reg, val)    ixgbe_write_reg(hw, reg, val)

#define IXGBE_READ_REG_ARRAY(hw, reg, offset) \
    IXGBE_READ_REG((hw), (reg) + ((offset) << 2))

#define IXGBE_WRITE_REG_ARRAY(hw, reg, offset, value) \
    IXGBE_WRITE_REG((hw), (reg) + ((offset) << 2), (value))

/* Special register operations */
#define IXGBE_WRITE_FLUSH(hw)  IXGBE_READ_REG(hw, IXGBE_STATUS)

/* 64-bit I/O operations for platforms without native writeq */
#ifndef writeq
static inline void 
ixgbe_writeq(uint64_t val, volatile void *addr)
{
    uint32_t low = (uint32_t)val;
    uint32_t high = (uint32_t)(val >> 32);
    
    writel(low, addr);
    writel(high, (char*)addr + 4);
}
#define writeq ixgbe_writeq
#endif

/*
 * ===== NETWORK DEVICE INTEGRATION =====
 */

/* Linux netdev -> FreeBSD ifnet mappings */
struct net_device; /* Forward declaration */

/* Get ifnet from ixgbe_hw */
extern struct ifnet *ixgbe_hw_to_ifnet(const struct ixgbe_hw *hw);

/* Message level structure for FreeBSD equivalent */
struct ixgbe_msg {
    uint16_t msg_enable;
};

extern struct ixgbe_msg *ixgbe_hw_to_msg(const struct ixgbe_hw *hw);

/*
 * ===== LOGGING AND DEBUG MACROS =====
 */

/* Linux printk levels -> FreeBSD device_printf */
#define hw_dbg(hw, fmt, args...)  \
    if_printf(ixgbe_hw_to_ifnet(hw), fmt, ##args)

#define hw_err(hw, fmt, args...)  \
    if_printf(ixgbe_hw_to_ifnet(hw), "ERROR: " fmt, ##args)

#define e_dev_info(fmt, args...)  \
    device_printf(adapter->dev, fmt, ##args)

#define e_dev_warn(fmt, args...)  \
    device_printf(adapter->dev, "WARNING: " fmt, ##args)

#define e_dev_err(fmt, args...)   \
    device_printf(adapter->dev, "ERROR: " fmt, ##args)

#define e_dev_notice(fmt, args...) \
    device_printf(adapter->dev, "NOTICE: " fmt, ##args)

/* Network interface logging */
#define e_info(msglvl, fmt, args...) \
    if_printf(adapter->ifp, fmt, ##args)

#define e_err(msglvl, fmt, args...)  \
    if_printf(adapter->ifp, "ERROR: " fmt, ##args)

#define e_warn(msglvl, fmt, args...) \
    if_printf(adapter->ifp, "WARNING: " fmt, ##args)

#define e_crit(msglvl, fmt, args...) \
    if_printf(adapter->ifp, "CRITICAL: " fmt, ##args)

#define e_dbg(msglvl, fmt, args...)  \
    if_printf(adapter->ifp, "DEBUG: " fmt, ##args)

/*
 * ===== ERROR REPORTING =====
 */

/* Linux ERROR_REPORT -> FreeBSD logging */
enum {
    IXGBE_ERROR_SOFTWARE,
    IXGBE_ERROR_POLLING, 
    IXGBE_ERROR_INVALID_STATE,
    IXGBE_ERROR_UNSUPPORTED,
    IXGBE_ERROR_ARGUMENT,
    IXGBE_ERROR_CAUTION,
};

#define ERROR_REPORT(level, fmt, args...) do {                        \
    switch (level) {                                                  \
    case IXGBE_ERROR_SOFTWARE:                                        \
    case IXGBE_ERROR_CAUTION:                                         \
    case IXGBE_ERROR_POLLING:                                         \
        if_printf(ixgbe_hw_to_ifnet(hw), "WARNING: " fmt, ##args);    \
        break;                                                        \
    case IXGBE_ERROR_INVALID_STATE:                                   \
    case IXGBE_ERROR_UNSUPPORTED:                                     \
    case IXGBE_ERROR_ARGUMENT:                                        \
        if_printf(ixgbe_hw_to_ifnet(hw), "ERROR: " fmt, ##args);      \
        break;                                                        \
    default:                                                          \
        break;                                                        \
    }                                                                 \
} while (0)

#define ERROR_REPORT1 ERROR_REPORT
#define ERROR_REPORT2 ERROR_REPORT  
#define ERROR_REPORT3 ERROR_REPORT

/*
 * ===== ASSERTION AND DEBUG SUPPORT =====
 */

#ifdef DEBUG
#define ASSERT(x)  KASSERT((x), ("ixgbe assertion failed: " #x))
#else
#define ASSERT(x)  do {} while (0)
#endif

#define DEBUGFUNC(s)  do {} while (0)

/*
 * ===== UNREFERENCED PARAMETER MACROS =====
 */

#define UNREFERENCED_XPARAMETER
#define UNREFERENCED_1PARAMETER(p)      __unused p
#define UNREFERENCED_2PARAMETER(p, q)   __unused p; __unused q
#define UNREFERENCED_3PARAMETER(p, q, r) __unused p; __unused q; __unused r
#define UNREFERENCED_4PARAMETER(p, q, r, s) __unused p; __unused q; __unused r; __unused s

/*
 * ===== WORKQUEUE/TASKQUEUE MAPPING =====
 */

/* Linux work_struct -> FreeBSD task */
struct ixgbe_work {
    struct task task;
    void (*function)(struct ixgbe_work *);
    void *data;
};

#define INIT_WORK(work, func) do {                     \
    TASK_INIT(&(work)->task, 0, ixgbe_task_wrapper,   \
              (work));                                 \
    (work)->function = (func);                         \
} while (0)

extern void ixgbe_task_wrapper(void *context, int pending);
extern void ixgbe_schedule_work(struct ixgbe_work *work);

/*
 * ===== TIMER SUPPORT =====
 */

/* Linux timer_list -> FreeBSD callout */
struct ixgbe_timer {
    struct callout callout;
    void (*function)(unsigned long);
    unsigned long data;
};

extern void ixgbe_setup_timer(struct ixgbe_timer *timer, 
                             void (*func)(unsigned long), unsigned long data);
extern void ixgbe_mod_timer(struct ixgbe_timer *timer, unsigned long expires);
extern void ixgbe_del_timer(struct ixgbe_timer *timer);

/*
 * ===== CONSTANTS AND LIMITS =====
 */

#define IXGBE_DEAD_READ_RETRIES    10
#define IXGBE_DEAD_READ_REG        0xdeadbeefU
#define IXGBE_FAILED_READ_REG      0xffffffffU
#define IXGBE_FAILED_READ_RETRIES  5

#define IXGBE_EEPROM_GRANT_ATTEMPS 100

/* Static modifier for FreeBSD */
#define STATIC static

/*
 * ===== MODULE MACROS =====
 */

/* Linux MODULE_* -> FreeBSD DRIVER_MODULE */
#ifdef _KERNEL
MALLOC_DECLARE(M_IXGBE);
extern devclass_t ixgbe_devclass;
#endif

/*
 * ===== CONDITIONAL COMPILATION HELPERS =====
 */

/* Define feature availability based on FreeBSD version */
#if __FreeBSD_version >= 1200000
#define IXGBE_HAVE_NETMAP        1
#define IXGBE_HAVE_HWPMC         1
#endif

#ifdef __cplusplus
}
#endif

#endif /* _IXGBE_OAL_H_ */