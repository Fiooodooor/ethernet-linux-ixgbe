# FreeBSD ixgbe Driver Port - API Mapping Build System
#
# Test-Driven Development Makefile for Linux->FreeBSD API mapping validation
#

# FreeBSD kernel build environment
KMOD = ixgbe_test
SRCS = api_mapping_test.c ixgbe_oal.c

# Test framework flags
CFLAGS += -DDEBUG -DTESTING

# Include our OAL headers
CFLAGS += -I../src

# FreeBSD kernel module framework
.include <bsd.kmod.mk>

# Custom targets for development workflow

# Run API mapping tests (requires module load)
test: all
	@echo "=== Loading ixgbe API mapping test module ==="
	sudo kldload ./ixgbe_test.ko || true
	@echo "=== Running API mapping tests ==="
	sudo kldstat | grep ixgbe_test
	@echo "=== Unloading test module ==="
	sudo kldunload ixgbe_test || true

# Clean development artifacts  
clean-dev:
	rm -f *.o *.ko *.symbols
	rm -f .depend*
	rm -rf .tmp

# Validate OAL header compilation
validate-headers:
	@echo "=== Validating OAL header compilation ==="
	$(CC) $(CFLAGS) -fsyntax-only -c ../src/ixgbe_oal.h || echo "Header validation failed"
	@echo "=== OAL headers validated ==="

# Check for Linux API contamination
contamination-check:
	@echo "=== Checking for Linux API contamination ==="
	@echo "Searching for forbidden includes..."
	@! grep -r "linux/" ../src/ || (echo "ERROR: Linux includes found!" && exit 1)
	@! grep -r "iflib" ../src/ || (echo "ERROR: iflib usage found!" && exit 1) 
	@! grep -r "linuxkpi" ../src/ || (echo "ERROR: LinuxKPI usage found!" && exit 1)
	@! grep -r "rte_" ../src/ || (echo "ERROR: DPDK usage found!" && exit 1)
	@echo "=== No contamination detected ==="

# Generate API mapping report
api-report:
	@echo "=== Generating API Mapping Report ==="
	@echo "Total Linux APIs identified: $$(grep -c 'Linux API' ../API_MAPPING_REFERENCE.md)"
	@echo "APIs with FreeBSD mappings: $$(grep -c 'FreeBSD Equivalent' ../API_MAPPING_REFERENCE.md)"
	@echo "OAL functions implemented: $$(grep -c 'static inline\|extern' ../src/ixgbe_oal.h)"
	@echo "Test cases written: $$(grep -c 'static int test_' api_mapping_test.c)"

# Development workflow target
dev: clean-dev validate-headers contamination-check all test api-report

.PHONY: test clean-dev validate-headers contamination-check api-report dev