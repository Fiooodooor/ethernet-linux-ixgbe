# Linux ixgbe Driver Dependencies and API Surface Analysis

## Objective
Map Linux driver dependencies, data-path entry points, and kernel API surface for ixgbe driver to enable clean FreeBSD porting with native OS API calls only.

## Analysis Structure
1. [Core Data Structures](#core-data-structures)
2. [Kernel API Dependencies](#kernel-api-dependencies)
3. [Data Path Entry Points](#data-path-entry-points)
4. [Driver Init/Exit Flows](#driver-init-exit-flows)
5. [Hardware Abstraction Layer](#hardware-abstraction-layer)
6. [Memory Management](#memory-management)
7. [Interrupt Handling](#interrupt-handling)
8. [Network Stack Integration](#network-stack-integration)
9. [OS Adaptation Layer (OAL) Requirements](#oal-requirements)

## Initial Driver File Structure
```
Core Driver Files:
- ixgbe_main.c       (458,385 bytes) - Main driver logic, entry points
- ixgbe.h            (45,334 bytes)  - Primary header with data structures
- ixgbe_type.h       (176,884 bytes) - Hardware type definitions
- ixgbe_ethtool.c    (187,403 bytes) - Ethtool interface
- ixgbe_lib.c        (28,510 bytes)  - Library functions

Hardware Abstraction:
- ixgbe_api.c/h      - Hardware API layer
- ixgbe_common.c/h   - Common hardware functions
- ixgbe_82598.c/h    - 82598 specific
- ixgbe_82599.c/h    - 82599 specific  
- ixgbe_x540.c/h     - X540 specific
- ixgbe_x550.c/h     - X550 specific
- ixgbe_e610.c/h     - E610 specific
- ixgbe_phy.c/h      - PHY management

Features:
- ixgbe_dcb*.c/h     - Data Center Bridging
- ixgbe_sriov.c/h    - SR-IOV support
- ixgbe_fcoe.c/h     - Fibre Channel over Ethernet
- ixgbe_ptp*.c/h     - Precision Time Protocol
- ixgbe_xsk.c        - XDP socket support

Compatibility Layer:
- kcompat*.c/h       - Kernel compatibility abstraction
```

## Core Linux Kernel Dependencies Identified

### 1. Critical Include Dependencies
```c
// Core Linux networking
#include <linux/netdevice.h>
#include <linux/ethtool.h>  
#include <linux/pci.h>
#include <linux/vmalloc.h>
#include <linux/highmem.h>
#include <linux/interrupt.h>
#include <linux/dma-mapping.h>

// Network stack headers
#include <net/tcp.h>
#include <net/ip.h>
#include <net/ipv6.h>
#include <net/checksum.h>
#include <net/ip6_checksum.h>
```

### 2. Main Driver Entry Points
**Network Device Operations (struct net_device_ops):**
- `.ndo_open = ixgbe_open` - Interface up
- `.ndo_stop = ixgbe_close` - Interface down  
- `.ndo_start_xmit = ixgbe_xmit_frame` - Packet transmission
- `.ndo_set_rx_mode = ixgbe_set_rx_mode` - RX mode configuration
- `.ndo_set_mac_address = ixgbe_set_mac` - MAC address setting
- `.ndo_change_mtu = ixgbe_change_mtu` - MTU changes
- `.ndo_tx_timeout = ixgbe_tx_timeout` - TX timeout handling
- `.ndo_vlan_rx_add_vid = ixgbe_vlan_rx_add_vid` - VLAN setup

**PCI Driver Entry Points:**
- PCI device table: `ixgbe_pci_tbl[]` 
- Probe function: `ixgbe_probe()`
- Remove function: `ixgbe_remove()`

### 3. Interrupt Handling Framework
**MSI-X Handlers:**
- `ixgbe_msix_other()` - Non-queue interrupts (admin)
- `ixgbe_msix_clean_rings()` - Per-queue data path interrupts
- `ixgbe_intr()` - Legacy interrupt handler

### 4. Core Data Structures

#### Primary Adapter Structure
```c
struct ixgbe_adapter {
    struct net_device *netdev;         // Linux netdevice
    struct pci_dev *pdev;              // PCI device structure
    struct bpf_prog *xdp_prog;         // XDP program
    struct ixgbe_hw hw;                // Hardware abstraction
    
    // Ring structures (TX/RX data path)
    struct ixgbe_ring *tx_ring[MAX_TX_QUEUES];
    struct ixgbe_ring *rx_ring[MAX_RX_QUEUES];
    struct ixgbe_ring *xdp_ring[IXGBE_MAX_XDP_QS];
    struct ixgbe_q_vector *q_vector[MAX_MSIX_Q_VECTORS];
    
    // Feature flags (Linux-specific capabilities)
    u32 flags;                         // MSI/DCB/SRIOV/etc capabilities
    u32 flags2;                        // Additional feature flags
};
```

#### Ring Data Structures
- `struct ixgbe_ring` - TX/RX queue descriptor rings
- `struct ixgbe_tx_buffer` - TX buffer metadata  
- `struct ixgbe_rx_buffer` - RX buffer metadata
- `struct ixgbe_q_vector` - Interrupt vector abstraction

### 5. Memory Management and DMA Dependencies

#### DMA Operations
```c
// Core DMA mapping functions
dma_map_single(dev, addr, len, direction)   -> FreeBSD: bus_dma_tag/map
dma_map_page(dev, page, offset, len, dir)
dma_unmap_single(dev, dma_addr, len, dir)   
dma_unmap_page(dev, dma_addr, len, dir)
dma_mapping_error(dev, dma_addr)            -> FreeBSD: error checking
dma_set_mask(&pdev->dev, DMA_BIT_MASK(64))  -> FreeBSD: bus_dma setup
dma_set_coherent_mask(&pdev->dev, mask)
```

#### Page/Buffer Management
```c
dev_alloc_pages(order)                      -> FreeBSD: contigmalloc/malloc
alloc_page(GFP_ATOMIC)                      -> FreeBSD: malloc(M_NOWAIT)
__free_pages(page, order)                   -> FreeBSD: free/contigfree
skb_alloc()                                 -> FreeBSD: m_gethdr/m_get
dev_kfree_skb_any(skb)                      -> FreeBSD: m_freem
```

### 6. PCI Configuration and Device Management

#### PCI Setup Functions
```c
pci_enable_device_mem(pdev)                 -> FreeBSD: pci_enable_busmaster
pci_request_mem_regions(pdev, name)         -> FreeBSD: bus_alloc_resource
pci_set_master(pdev)                        -> FreeBSD: pci_enable_busmaster
pci_save_state(pdev)                        -> FreeBSD: pci_save_state
pci_restore_state(pdev)                     -> FreeBSD: pci_restore_state
ioremap(phys_addr, size)                    -> FreeBSD: bus_space_map
iounmap(virt_addr)                          -> FreeBSD: bus_space_unmap
```

### 7. Interrupt Management

#### MSI-X and Legacy Interrupts
```c
pci_enable_msix_range(pdev, entries, min, max) -> FreeBSD: pci_alloc_msix
pci_disable_msix(pdev)                         -> FreeBSD: pci_release_msi
request_irq(irq, handler, flags, name, dev)    -> FreeBSD: bus_setup_intr
free_irq(irq, dev)                             -> FreeBSD: bus_teardown_intr

// Interrupt handler signature
irqreturn_t handler(int irq, void *dev_id)     -> FreeBSD: void handler(void *arg)
```

### 8. Kernel Threading and Work Queues

#### Work Queue System
```c
struct workqueue_struct *ixgbe_wq;             -> FreeBSD: taskqueue
struct work_struct service_task;               -> FreeBSD: struct task
INIT_WORK(&adapter->service_task, func);       -> FreeBSD: TASK_INIT
queue_work(ixgbe_wq, &adapter->service_task);  -> FreeBSD: taskqueue_enqueue
flush_workqueue(ixgbe_wq);                     -> FreeBSD: taskqueue_drain_all
```

### 9. Network Stack Integration

#### SKB Buffer Management  
```c
struct sk_buff -> struct mbuf (FreeBSD equivalent)
- skb->data -> m->m_data
- skb->len -> m->m_len  
- skb_put(skb, len) -> m_append(m, len, data)
- skb_push(skb, len) -> M_PREPEND(m, len, how)
- skb_pull(skb, len) -> m_adj(m, len)
```

#### Network Device Registration
```c
alloc_etherdev_mq(sizeof, queues)     -> FreeBSD: if_alloc(IFT_ETHER)
register_netdev(netdev)               -> FreeBSD: if_attach(ifp)
unregister_netdev(netdev)             -> FreeBSD: if_detach(ifp)
netif_carrier_on/off(netdev)          -> FreeBSD: if_link_state_change
netif_start_queue(netdev)             -> FreeBSD: ifp->if_drv_flags |= IFF_DRV_RUNNING
netif_stop_queue(netdev)              -> FreeBSD: ifp->if_drv_flags &= ~IFF_DRV_RUNNING
```

### 10. Timer and Scheduling APIs
```c
mod_timer(&timer, jiffies + timeout)  -> FreeBSD: callout_reset
del_timer_sync(&timer)                -> FreeBSD: callout_stop
msleep(ms)                            -> FreeBSD: pause/DELAY
usleep_range(min, max)                -> FreeBSD: DELAY  
```

### 11. Hardware Abstraction Layer (HAL)

#### Key HAL Structures
```c
struct ixgbe_hw {
    u8 *hw_addr;                      // MMIO base address mapping
    void *back;                       // Back pointer to adapter
    struct ixgbe_mac_info mac;        // MAC layer abstraction
    struct ixgbe_phy_info phy;        // PHY layer abstraction  
    struct ixgbe_bus_info bus;        // Bus/PCI info
    struct ixgbe_mbx_info mbx;        // Mailbox for SR-IOV
};
```

### 12. Critical OAL Seam Requirements

**High Priority Seams (must implement first):**
1. **DMA/Bus Memory Management** - Most critical for data path
2. **PCI Device Management** - Required for device initialization
3. **Interrupt Handling** - Core for MSI-X operation
4. **Network Buffer Management** - SKB->mbuf translation
5. **Hardware Register Access** - MMIO read/write operations

**Medium Priority Seams:**
1. **Work Queue/Task Management** - Background processing 
2. **Timer Services** - Link monitoring and housekeeping
3. **Sysctl/Module Parameters** - Configuration interface
4. **PCI Power Management** - Sleep/wake functionality

**Low Priority Seams:**
1. **debugfs/sysfs** - Debugging interfaces
2. **ethtool** - Advanced configuration (can use native FreeBSD)
3. **Netlink/DCB** - Data center features

## Status
- **Core dependency mapping: COMPLETE**
- **Memory/DMA analysis: COMPLETE**
- **Interrupt framework mapping: COMPLETE**  
- **Network integration analysis: COMPLETE**
- **HAL structure analysis: COMPLETE**
- **OAL seam prioritization: COMPLETE**

Next: Document validation and handoff preparation...