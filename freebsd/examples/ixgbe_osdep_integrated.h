/*
 * SPDX-License-Identifier: BSD-3-Clause  
 * Copyright (c) 2025 FreeBSD ixgbe Driver Port
 *
 * Integration Example: Linux ixgbe_osdep.h -> FreeBSD OAL Integration
 *
 * This shows how to modify the original Linux ixgbe_osdep.h to use
 * our FreeBSD OAL with minimal changes to the Linux source code.
 * 
 * INTEGRATION STRATEGY:
 * 1. Replace Linux includes with FreeBSD OAL include
 * 2. Use conditional compilation for platform differences  
 * 3. Preserve all original macro names and signatures
 * 4. Zero changes to ixgbe_*.c source files
 */

#ifndef _IXGBE_OSDEP_H_
#define _IXGBE_OSDEP_H_

/*
 * Platform Detection and OAL Integration
 */
#ifdef __FreeBSD__
  /* FreeBSD: Use our native OAL instead of Linux APIs */
  #include "ixgbe_oal.h"           /* Our FreeBSD OAL */
  #include "ixgbe_osdep_freebsd.h" /* FreeBSD-specific osdep */
  
#else
  /* Linux: Use original Linux kernel APIs */ 
  #include "kcompat.h"
  #include "kcompat_kthread.h"
  #include <linux/pci.h>
  #include <linux/netdevice.h>
  #include <linux/vmalloc.h>
  #include <linux/aer.h>
  #include <linux/delay.h>
  #include <linux/interrupt.h>
  #include <linux/if_ether.h>
  #include <linux/sched.h>
  
  /* Original Linux definitions continue unchanged... */
  
#endif /* __FreeBSD__ */

/*
 * Common definitions that work on both platforms
 * (These remain unchanged from original Linux driver)
 */

#define IXGBE_SFP_DETECT_RETRIES	2
#define IXGBE_DEAD_READ_RETRIES     10
#define IXGBE_DEAD_READ_REG         0xdeadbeefU
#define IXGBE_FAILED_READ_REG       0xffffffffU
#define IXGBE_FAILED_READ_RETRIES   5
#define IXGBE_FAILED_READ_CFG_DWORD 0xffffffffU
#define IXGBE_FAILED_READ_CFG_WORD  0xffffU
#define IXGBE_FAILED_READ_CFG_BYTE  0xffU
#define IXGBE_EEPROM_GRANT_ATTEMPS  100

/*
 * Hardware Access Macros - Unified Interface
 * (Same macro names, platform-specific implementations)
 */
#ifndef IXGBE_READ_REG
#define IXGBE_READ_REG(h, r) ixgbe_read_reg(h, r, false)
#endif

#ifndef IXGBE_WRITE_REG
#define IXGBE_WRITE_REG(h, r, v) ixgbe_write_reg(h, r, v)
#endif

#define IXGBE_READ_REG_ARRAY(a, reg, offset) \
    IXGBE_READ_REG((a), (reg) + ((offset) << 2))

#define IXGBE_WRITE_REG_ARRAY(a, reg, offset, value) \
    IXGBE_WRITE_REG((a), (reg) + ((offset) << 2), (value))

#define IXGBE_WRITE_FLUSH(a) IXGBE_READ_REG(a, IXGBE_STATUS)

/*
 * Platform-Specific 64-bit I/O
 */ 
#ifndef writeq
#ifdef __FreeBSD__
  /* FreeBSD: Use our OAL implementation */
  /* (Already defined in ixgbe_oal.h) */
#else
  /* Linux: Standard Linux implementation */
  #define writeq(val, addr) do { \
      writel((u32) (val), addr); \
      writel((u32) (val >> 32), (addr + 4)); \
  } while (0);
#endif
#endif /* writeq */

/*
 * Forward Declarations - Platform Independent
 */
struct ixgbe_hw;

/*
 * Example: Memory Management Macro Preservation
 * Original Linux macros preserved, but implementation differs by platform
 */
#ifndef ixgbe_malloc
  /* Defined by platform-specific headers */
  #ifdef __FreeBSD__ 
    /* Uses ixgbe_malloc from OAL */
  #else
    /* Uses Linux kzalloc */
    #define ixgbe_malloc(hw, size) kzalloc(size, GFP_KERNEL)
  #endif
#endif

/*
 * Example: Synchronization Macro Preservation  
 */
#ifndef ixgbe_lock
  /* Defined by platform-specific headers */
  #ifdef __FreeBSD__
    /* Uses FreeBSD mtx from OAL */
  #else
    /* Uses Linux mutex */
    #define ixgbe_lock mutex
  #endif
#endif

/*
 * Boolean Definitions - Common to Both Platforms
 */
#undef TRUE
#define TRUE true
#undef FALSE
#define FALSE false

/*
 * Static and IOMEM annotations  
 */
#define STATIC static
#ifndef IOMEM
#define IOMEM  /* Platform-specific or empty */
#endif

/*
 * Cross-Platform Hardware Context Access
 * These function signatures are identical on both platforms
 */
extern struct net_device *ixgbe_hw_to_netdev(const struct ixgbe_hw *hw);
extern struct ixgbe_msg *ixgbe_hw_to_msg(const struct ixgbe_hw *hw);
extern u16 ixgbe_read_pci_cfg_word(struct ixgbe_hw *hw, u32 reg);
extern void ixgbe_write_pci_cfg_word(struct ixgbe_hw *hw, u32 reg, u16 value);
extern void ewarn(struct ixgbe_hw *hw, const char *str);

/*
 * Cross-Platform Error Reporting
 * Same interface, different implementations
 */
enum {
    IXGBE_ERROR_SOFTWARE,
    IXGBE_ERROR_POLLING,
    IXGBE_ERROR_INVALID_STATE,
    IXGBE_ERROR_UNSUPPORTED,
    IXGBE_ERROR_ARGUMENT,
    IXGBE_ERROR_CAUTION,
};

/* ERROR_REPORT macro defined by platform-specific headers */

/*
 * Unreferenced Parameter Macros - Cross Platform  
 */
#define UNREFERENCED_XPARAMETER
#define UNREFERENCED_1PARAMETER(_p) do { \
    (void)(_p); \
} while (0)
#define UNREFERENCED_2PARAMETER(_p, _q) do { \
    (void)(_p); (void)(_q); \
} while (0)
/* ... etc for 3PARAMETER, 4PARAMETER ... */

/*
 * Integration Validation - Compile-Time Checks
 */
#ifdef __FreeBSD__
  /* Ensure our OAL is properly included */
  #ifndef _IXGBE_OAL_H_
    #error "FreeBSD OAL not included - check include paths"
  #endif
  
  /* Verify no Linux contamination in FreeBSD build */
  #ifdef LINUX_VERSION_CODE
    #error "Linux headers detected in FreeBSD build - contamination!"
  #endif
  
#endif /* __FreeBSD__ */

/*
 * Debug and Assertion Support
 */
#ifdef DEBUG
  #ifndef ASSERT
    #ifdef __FreeBSD__
      #define ASSERT(x) KASSERT((x), ("ixgbe assertion failed: " #x))
    #else
      #define ASSERT(x) BUG_ON(!(x))
    #endif
  #endif
#else
  #define ASSERT(x) do {} while (0)
#endif

#define DEBUGFUNC(S) do {} while (0)

/*
 * Platform Feature Detection
 */
#ifdef __FreeBSD__
  /* FreeBSD-specific feature flags */
  #if __FreeBSD_version >= 1300000
    #define IXGBE_HAVE_NETMAP 1
  #endif
  
#else
  /* Linux-specific feature detection */
  #ifdef CONFIG_NET_POLL_CONTROLLER
    #define IXGBE_HAVE_NETPOLL 1
  #endif
  
#endif

#endif /* _IXGBE_OSDEP_H_ */

/*
 * INTEGRATION NOTES:
 *
 * 1. MINIMAL CHANGES: Original Linux driver source files (ixgbe_*.c) 
 *    require ZERO changes. Only this osdep.h header is modified.
 *
 * 2. CONDITIONAL COMPILATION: #ifdef __FreeBSD__ blocks isolate 
 *    platform differences while preserving common interfaces.
 *
 * 3. MACRO PRESERVATION: All original Linux macro names and signatures
 *    are preserved. Only the underlying implementations differ.
 *
 * 4. VALIDATION: Compile-time checks prevent Linux/FreeBSD contamination
 *    and ensure proper OAL inclusion.
 *
 * 5. MAINTAINABILITY: Linux upstream changes can be merged with minimal
 *    conflict since the core driver logic remains unchanged.
 *
 * 6. TESTING: Both platforms can be built from the same source tree
 *    using different toolchains and include paths.
 *
 * This integration strategy allows the Linux ixgbe driver to be
 * compiled for FreeBSD with our native OAL while maintaining full
 * compatibility with the original Linux codebase.
 */