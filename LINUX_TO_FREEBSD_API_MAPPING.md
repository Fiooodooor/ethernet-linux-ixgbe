# Linux to FreeBSD API Mapping for ixgbe Driver

## Critical Path: Linux API → FreeBSD Native Equivalent

### 1. Memory/DMA Management APIs

| Linux API | FreeBSD Native Equivalent | Notes |
|-----------|--------------------------|-------|
| `dma_map_single(dev, ptr, len, dir)` | `bus_dmamap_load()` | Use bus_dma framework |
| `dma_map_page(dev, page, off, len, dir)` | `bus_dmamap_load()` | Page-based mapping |
| `dma_unmap_single(dev, addr, len, dir)` | `bus_dmamap_unload()` | Clean unmap |
| `dma_mapping_error(dev, addr)` | Check `bus_dmamap_load()` return | Error handling |
| `dma_alloc_coherent()` | `bus_dmamem_alloc()` | Coherent memory |
| `dev_alloc_pages(order)` | `contigmalloc()` or `malloc()` | Contiguous allocation |
| `__free_pages(page, order)` | `free()` or `contigfree()` | Memory free |

### 2. PCI Configuration

| Linux API | FreeBSD Equivalent | Notes |
|-----------|-------------------|-------|
| `pci_enable_device_mem(pdev)` | `pci_enable_busmaster(dev)` | Enable device |
| `pci_request_mem_regions(pdev, name)` | `bus_alloc_resource(dev, SYS_RES_MEMORY, ...)` | Reserve regions |
| `pci_set_master(pdev)` | `pci_enable_busmaster(dev)` | Bus mastering |
| `ioremap(phys, size)` | `bus_space_map()` or `rman_get_virtual()` | MMIO mapping |
| `iounmap(virt)` | `bus_space_unmap()` | MMIO unmap |
| `pci_save_state()` | `pci_save_state(dev)` | State management |

### 3. Interrupt Handling

| Linux API | FreeBSD Equivalent | Notes |
|-----------|-------------------|-------|
| `pci_enable_msix_range()` | `pci_alloc_msix()` | MSI-X allocation |
| `request_irq(irq, handler, flags, name, dev)` | `bus_setup_intr()` | Interrupt setup |
| `free_irq(irq, dev)` | `bus_teardown_intr()` | Interrupt teardown |
| `irqreturn_t handler(int, void*)` | `void handler(void *arg)` | Handler signature |
| `IRQ_HANDLED/IRQ_NONE` | `void return` | No return value needed |

### 4. Network Buffer Management

| Linux SKB API | FreeBSD mbuf Equivalent | Notes |
|---------------|------------------------|-------|
| `struct sk_buff` | `struct mbuf` | Core network buffer |
| `alloc_skb(size, flags)` | `m_gethdr(how, type)` | Buffer allocation |
| `dev_kfree_skb_any(skb)` | `m_freem(m)` | Buffer free |
| `skb_put(skb, len)` | `m_append(m, len, cp)` | Add data to end |
| `skb_push(skb, len)` | `M_PREPEND(m, len, how)` | Add data to front |
| `skb_pull(skb, len)` | `m_adj(m, len)` | Remove from front |
| `skb->data` | `mtod(m, type)` | Data pointer |
| `skb->len` | `m->m_pkthdr.len` | Total length |

### 5. Network Device Operations

| Linux netdev API | FreeBSD ifnet Equivalent | Notes |
|------------------|-------------------------|-------|
| `alloc_etherdev_mq(size, queues)` | `if_alloc(IFT_ETHER)` | Device allocation |
| `register_netdev(netdev)` | `ether_ifattach(ifp, eaddr)` | Device registration |
| `unregister_netdev(netdev)` | `ether_ifdetach(ifp)` | Device unregistration |
| `netif_carrier_on(netdev)` | `if_link_state_change(ifp, LINK_STATE_UP)` | Link state |
| `netif_start_queue(netdev)` | `ifp->if_drv_flags \|= IFF_DRV_RUNNING` | Enable TX |
| `netif_stop_queue(netdev)` | `ifp->if_drv_flags &= ~IFF_DRV_RUNNING` | Disable TX |

### 6. Work Queue/Task Management

| Linux API | FreeBSD Equivalent | Notes |
|-----------|-------------------|-------|
| `struct workqueue_struct` | `struct taskqueue` | Task queue structure |
| `struct work_struct` | `struct task` | Task structure |
| `INIT_WORK(work, func)` | `TASK_INIT(task, prio, func, arg)` | Task initialization |
| `queue_work(wq, work)` | `taskqueue_enqueue(tq, task)` | Enqueue task |
| `flush_workqueue(wq)` | `taskqueue_drain_all(tq)` | Drain all tasks |
| `create_singlethread_workqueue(name)` | `taskqueue_create(name, flags, func, arg)` | Create queue |

### 7. Timing and Delays

| Linux API | FreeBSD Equivalent | Notes |
|-----------|-------------------|-------|
| `mod_timer(timer, jiffies + timeout)` | `callout_reset(&co, ticks, func, arg)` | Timer setup |
| `del_timer_sync(timer)` | `callout_stop(&co)` | Timer stop |
| `msleep(ms)` | `pause("ixgbe", hz * ms / 1000)` | Millisecond sleep |
| `usleep_range(min, max)` | `DELAY(microseconds)` | Microsecond delay |
| `jiffies` | `ticks` | System tick counter |

### 8. Synchronization Primitives

| Linux API | FreeBSD Equivalent | Notes |
|-----------|-------------------|-------|
| `spin_lock_irqsave()` | `mtx_lock_spin()` | Spinlock with IRQ disable |
| `spin_unlock_irqrestore()` | `mtx_unlock_spin()` | Spinlock unlock |
| `mutex_lock()` | `mtx_lock()` | Mutex lock |
| `mutex_unlock()` | `mtx_unlock()` | Mutex unlock |
| `DEFINE_SPINLOCK()` | `MTX_SYSINIT()` | Static spinlock definition |

### 9. Module/Driver Registration

| Linux API | FreeBSD Equivalent | Notes |
|-----------|-------------------|-------|
| `module_init(func)` | `DRIVER_MODULE()` | Module initialization |
| `module_exit(func)` | Part of `DRIVER_MODULE()` | Module cleanup |
| `MODULE_LICENSE()` | Not required | License declaration |
| `MODULE_DEVICE_TABLE()` | Static PCI ID table | Device matching |

## Implementation Strategy

### Phase 1: Core OAL Headers
1. Create `ixgbe_oal.h` with FreeBSD-specific defines
2. Map critical data types (DMA addresses, etc.)
3. Define platform-specific feature flags

### Phase 2: Memory Management Layer
1. Implement DMA mapping wrapper functions
2. Create buffer allocation/free wrappers
3. Handle coherent vs. non-coherent memory

### Phase 3: Device Integration Layer
1. PCI configuration and resource management
2. Interrupt allocation and handling
3. Register access macros/inlines

### Phase 4: Network Integration
1. SKB to mbuf conversion layer
2. Network device registration
3. Interface state management

### Phase 5: Background Processing
1. Work queue to taskqueue mapping
2. Timer services implementation
3. Module parameter system

## Critical Notes for Implementation

1. **Zero Framework Dependency**: All mappings must use native FreeBSD APIs only
2. **Thin Wrapper Approach**: Use inline functions or macros where possible
3. **Compile-Time Selection**: Use `#ifdef __FreeBSD__` trees for platform selection
4. **Preserved Function Signatures**: Keep Linux function signatures intact in wrapper layer
5. **Error Code Mapping**: Linux and FreeBSD error codes need translation layer

## Next Phase Deliverables

This analysis enables the seam-architect to create:
1. Platform-specific header files (`ixgbe_oal_freebsd.h`)
2. Wrapper function implementations
3. Build system modifications
4. Test framework for validation

**CRITICAL**: No iflib, linuxkpi, rte_, or DPDK dependencies allowed in implementation.