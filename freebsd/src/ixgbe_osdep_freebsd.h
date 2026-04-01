/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright (c) 2025 FreeBSD ixgbe Driver Port
 * 
 * FreeBSD OS Abstraction Layer Integration
 * 
 * This is a FreeBSD-native version of ixgbe_osdep.h that replaces
 * Linux kernel APIs with FreeBSD equivalents through thin OAL seams.
 * 
 * Original Linux ixgbe_osdep.h concepts preserved, but implemented
 * using native FreeBSD APIs instead of LinuxKPI/iflib frameworks.
 */

#ifndef _IXGBE_OSDEP_FREEBSD_H_
#define _IXGBE_OSDEP_FREEBSD_H_

/* Include our OAL mapping layer */
#include "ixgbe_oal.h"

/* FreeBSD-specific includes not in OAL */
#include <sys/endian.h>
#include <machine/bus.h>

/*
 * ===== BYTE ORDER MACROS (FreeBSD native) =====
 */

#define IXGBE_CPU_TO_BE16(_x) htobe16(_x)
#define IXGBE_BE16_TO_CPU(_x) be16toh(_x)
#define IXGBE_CPU_TO_BE32(_x) htobe32(_x)
#define IXGBE_BE32_TO_CPU(_x) be32toh(_x)

#define IXGBE_CPU_TO_LE16(_x) htole16(_x)
#define IXGBE_LE16_TO_CPU(_x) le16toh(_x)
#define IXGBE_CPU_TO_LE32(_x) htole32(_x)
#define IXGBE_LE32_TO_CPU(_x) le32toh(_x)
#define IXGBE_CPU_TO_LE64(_x) htole64(_x)
#define IXGBE_LE64_TO_CPU(_x) le64toh(_x)

#define IXGBE_LE32_TO_CPUS(_x) do { *(_x) = le32toh(*(_x)); } while(0)

#define IXGBE_HTONL(_i) htonl(_i)
#define IXGBE_NTOHL(_i) ntohl(_i)
#define IXGBE_NTOHS(_i) ntohs(_i)

/*
 * ===== TIMING FUNCTIONS =====
 */

/* FreeBSD native delay functions */
#define msec_delay(_x) pause("ixgbe", ((_x) * hz) / 1000)
#define usec_delay(_x) DELAY(_x)

/*
 * ===== STATIC AND IOMEM ANNOTATIONS =====
 */

#define STATIC static
#define IOMEM   /* FreeBSD doesn't need __iomem annotation */

/*
 * ===== ASSERTION AND DEBUG =====
 */

#ifdef DEBUG
#define ASSERT(_x)    KASSERT((_x), ("ixgbe assertion failed: " #_x))
#else
#define ASSERT(_x)    do {} while (0)
#endif

#define DEBUGFUNC(S)  do {} while (0)

/*
 * ===== HARDWARE ACCESS CONSTANTS =====
 */

#define IXGBE_SFP_DETECT_RETRIES   2
#define IXGBE_DEAD_READ_RETRIES    10
#define IXGBE_DEAD_READ_REG        0xdeadbeefU
#define IXGBE_FAILED_READ_REG      0xffffffffU
#define IXGBE_FAILED_READ_RETRIES  5
#define IXGBE_FAILED_READ_CFG_DWORD 0xffffffffU
#define IXGBE_FAILED_READ_CFG_WORD  0xffffU
#define IXGBE_FAILED_READ_CFG_BYTE  0xffU

#define IXGBE_EEPROM_GRANT_ATTEMPS 100

/*
 * ===== FORWARD DECLARATIONS =====
 */

struct ixgbe_hw;
struct ixgbe_msg {
    u16 msg_enable;
};

/* Context access functions (implemented in ixgbe_oal.c) */
struct ifnet *ixgbe_hw_to_ifnet(const struct ixgbe_hw *hw);
struct ixgbe_msg *ixgbe_hw_to_msg(const struct ixgbe_hw *hw);
device_t ixgbe_pf_to_dev(struct ixgbe_adapter *adapter);

/*
 * ===== LOGGING MACROS (FreeBSD native) =====
 */

/* Firmware log hex dump */
#define ixgbe_info_fwlog(hw, rowsize, groupsize, buf, len) do {        \
    struct ifnet *ifp = ixgbe_hw_to_ifnet(hw);                       \
    if (ifp) {                                                        \
        if_printf(ifp, "FWLOG dump (%zu bytes):\n", (size_t)(len));  \
        /* Could add hex dump implementation here */                  \
    }                                                                 \
} while (0)

/* Hardware-level logging */
#define hw_dbg(hw, format, arg...) do {                     \
    struct ifnet *ifp = ixgbe_hw_to_ifnet(hw);             \
    if (ifp)                                               \
        if_printf(ifp, "DEBUG: " format, ##arg);           \
} while (0)

#define hw_err(hw, format, arg...) do {                     \
    struct ifnet *ifp = ixgbe_hw_to_ifnet(hw);             \
    if (ifp)                                               \
        if_printf(ifp, "ERROR: " format, ##arg);           \
} while (0)

/* Device-level logging */
#define e_dev_info(format, arg...) \
    device_printf(ixgbe_pf_to_dev(adapter), format, ##arg)

#define e_dev_warn(format, arg...) \
    device_printf(ixgbe_pf_to_dev(adapter), "WARNING: " format, ##arg)

#define e_dev_err(format, arg...) \
    device_printf(ixgbe_pf_to_dev(adapter), "ERROR: " format, ##arg)

#define e_dev_notice(format, arg...) \
    device_printf(ixgbe_pf_to_dev(adapter), "NOTICE: " format, ##arg)

/* Interface-level logging */
#define e_dbg(msglvl, format, arg...) do {        \
    if (adapter->ifp)                             \
        if_printf(adapter->ifp, "DEBUG: " format, ##arg); \
} while (0)

#define e_info(msglvl, format, arg...) do {       \
    if (adapter->ifp)                             \
        if_printf(adapter->ifp, format, ##arg);   \
} while (0)

#define e_err(msglvl, format, arg...) do {        \
    if (adapter->ifp)                             \
        if_printf(adapter->ifp, "ERROR: " format, ##arg); \
} while (0)

#define e_warn(msglvl, format, arg...) do {       \
    if (adapter->ifp)                             \
        if_printf(adapter->ifp, "WARNING: " format, ##arg); \
} while (0)

#define e_crit(msglvl, format, arg...) do {       \
    if (adapter->ifp)                             \
        if_printf(adapter->ifp, "CRITICAL: " format, ##arg); \
} while (0)

/*
 * ===== REGISTER ACCESS MACROS =====
 */

/* Array register access */
#define IXGBE_WRITE_REG_ARRAY(a, reg, offset, value) \
    IXGBE_WRITE_REG((a), (reg) + ((offset) << 2), (value))

#define IXGBE_READ_REG_ARRAY(a, reg, offset) \
    IXGBE_READ_REG((a), (reg) + ((offset) << 2))

/* Core register access (implemented in ixgbe_oal.c) */
#define IXGBE_READ_REG(h, r)      ixgbe_read_reg(h, r, false)
#define IXGBE_R32_Q(h, r)         ixgbe_read_reg(h, r, true)
#define IXGBE_R8_Q(h, r)          ixgbe_read_reg_byte(h, r)
#define IXGBE_WRITE_REG(h, r, v)  ixgbe_write_reg(h, r, v)

/* 64-bit register writes */
#ifndef writeq
#define writeq(val, addr) do {                    \
    uint32_t low = (uint32_t)(val);               \
    uint32_t high = (uint32_t)((val) >> 32);     \
    writel(low, addr);                            \
    writel(high, (char*)(addr) + 4);             \
} while (0)
#endif

/* Register flush */
#define IXGBE_WRITE_FLUSH(a) IXGBE_READ_REG(a, IXGBE_STATUS)

/*
 * ===== PCI CONFIGURATION ACCESS =====
 */

extern u16 ixgbe_read_pci_cfg_word(struct ixgbe_hw *hw, u32 reg);
extern void ixgbe_write_pci_cfg_word(struct ixgbe_hw *hw, u32 reg, u16 value);
extern u8 ixgbe_read_pci_cfg_byte(struct ixgbe_hw *hw, u32 reg);
extern void ixgbe_write_pci_cfg_byte(struct ixgbe_hw *hw, u32 reg, u8 value);
extern u32 ixgbe_read_pci_cfg_dword(struct ixgbe_hw *hw, u32 reg);
extern void ixgbe_write_pci_cfg_dword(struct ixgbe_hw *hw, u32 reg, u32 value);

#define IXGBE_READ_PCIE_WORD   ixgbe_read_pci_cfg_word
#define IXGBE_WRITE_PCIE_WORD  ixgbe_write_pci_cfg_word

/*
 * ===== ERROR REPORTING =====
 */

enum {
    IXGBE_ERROR_SOFTWARE,
    IXGBE_ERROR_POLLING,
    IXGBE_ERROR_INVALID_STATE,
    IXGBE_ERROR_UNSUPPORTED,
    IXGBE_ERROR_ARGUMENT,
    IXGBE_ERROR_CAUTION,
};

#define ERROR_REPORT(level, format, arg...) do {                        \
    struct ifnet *ifp = ixgbe_hw_to_ifnet(hw);                         \
    switch (level) {                                                    \
    case IXGBE_ERROR_SOFTWARE:                                          \
    case IXGBE_ERROR_CAUTION:                                           \
    case IXGBE_ERROR_POLLING:                                           \
        if (ifp)                                                        \
            if_printf(ifp, "WARNING: " format, ##arg);                 \
        break;                                                          \
    case IXGBE_ERROR_INVALID_STATE:                                     \
    case IXGBE_ERROR_UNSUPPORTED:                                       \
    case IXGBE_ERROR_ARGUMENT:                                          \
        if (ifp)                                                        \
            if_printf(ifp, "ERROR: " format, ##arg);                   \
        break;                                                          \
    default:                                                            \
        break;                                                          \
    }                                                                   \
} while (0)

#define ERROR_REPORT1 ERROR_REPORT
#define ERROR_REPORT2 ERROR_REPORT
#define ERROR_REPORT3 ERROR_REPORT

/*
 * ===== MEMORY ALLOCATION =====
 */

/* Use OAL memory functions */
#define ixgbe_malloc(hw, size)     ixgbe_malloc(hw, size)
#define ixgbe_calloc(hw, cnt, sz)  ixgbe_calloc(hw, cnt, sz)  
#define ixgbe_free(hw, ptr)        ixgbe_free(hw, ptr)

/*
 * ===== SYNCHRONIZATION =====
 */

/* Use OAL lock functions */
typedef ixgbe_lock mutex;
#define ixgbe_lock                 ixgbe_lock
#define ixgbe_init_lock(lock)      ixgbe_init_lock(lock)
#define ixgbe_destroy_lock(lock)   ixgbe_destroy_lock(lock)
#define ixgbe_acquire_lock(lock)   ixgbe_acquire_lock(lock)
#define ixgbe_release_lock(lock)   ixgbe_release_lock(lock)

/*
 * ===== UNREFERENCED PARAMETERS =====
 */

#define UNREFERENCED_XPARAMETER
#define UNREFERENCED_1PARAMETER(_p) do {       \
    (void)(_p);                                \
} while (0)
#define UNREFERENCED_2PARAMETER(_p, _q) do {   \
    (void)(_p);                                \
    (void)(_q);                                \
} while (0)
#define UNREFERENCED_3PARAMETER(_p, _q, _r) do { \
    (void)(_p);                                \
    (void)(_q);                                \
    (void)(_r);                                \
} while (0)
#define UNREFERENCED_4PARAMETER(_p, _q, _r, _s) do { \
    (void)(_p);                                \
    (void)(_q);                                \
    (void)(_r);                                \
    (void)(_s);                                \
} while (0)

/*
 * ===== BOOLEAN DEFINITIONS =====
 */

#undef TRUE
#define TRUE true
#undef FALSE  
#define FALSE false

/*
 * ===== WARNING FUNCTION =====
 */

extern void ewarn(struct ixgbe_hw *hw, const char *str);
#define EWARN(H, W) ewarn(H, W)

#endif /* _IXGBE_OSDEP_FREEBSD_H_ */