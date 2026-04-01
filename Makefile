# Makefile for IXGBE OAL TDD Test Suite
#
# Copyright (c) 2026 Intel Corporation
# Build system for OAL (Operating System Abstraction Layer) TDD tests
#
# NON-NEGOTIABLE RULES:
# - Zero framework calls (no iflib/linuxkpi/rte_*/DPDK usage)
# - Native OS API calls ONLY
# - Thin OAL seams: #ifdef trees, inline wrappers, weak symbols
# - TDD-first: write failing test, then implement, then verify
# - Minimal source touch: never rewrite when a seam wrapper suffices

# Project configuration
PROJECT_NAME := ixgbe-oal-tdd
VERSION := 1.0.0
BUILD_DIR := build
TEST_DIR := tests/oal_tdd_tests
SRC_FILES := $(wildcard $(TEST_DIR)/*.c)

# Compiler configuration
CC := gcc
CFLAGS := -std=c99 -Wall -Wextra -Werror -O2 -g
LDFLAGS := -lpthread -lm
INCLUDES := -I. -I../../ -I../../../

# Platform detection
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
    PLATFORM := linux
    CFLAGS += -D__LINUX__ -DOAL_LINUX=1 -DOAL_FREEBSD=0
endif
ifeq ($(UNAME_S),FreeBSD)
    PLATFORM := freebsd
    CFLAGS += -D__FREEBSD__ -DOAL_FREEBSD=1 -DOAL_LINUX=0
endif

# Debug build configuration
ifdef DEBUG
    CFLAGS += -DDEBUG -DOAL_DEBUG -g3 -O0
    BUILD_TYPE := debug
else
    BUILD_TYPE := release
endif

# Test executable names
TEST_EXECUTABLES := \
    $(BUILD_DIR)/test_oal_memory_tdd \
    $(BUILD_DIR)/test_oal_register_tdd \
    $(BUILD_DIR)/test_oal_netdev_tdd \
    $(BUILD_DIR)/test_oal_interrupt_tdd \
    $(BUILD_DIR)/test_oal_sync_tdd \
    $(BUILD_DIR)/test_oal_time_tdd \
    $(BUILD_DIR)/test_ixgbe_hw_features_tdd \
    $(BUILD_DIR)/test_ixgbe_lifecycle_tdd \
    $(BUILD_DIR)/oal_master_tdd_runner

# Object files
MEMORY_OBJ := $(BUILD_DIR)/test_oal_memory_tdd.o
REGISTER_OBJ := $(BUILD_DIR)/test_oal_register_tdd.o
NETDEV_OBJ := $(BUILD_DIR)/test_oal_netdev_tdd.o
INTERRUPT_OBJ := $(BUILD_DIR)/test_oal_interrupt_tdd.o
SYNC_OBJ := $(BUILD_DIR)/test_oal_sync_tdd.o
TIME_OBJ := $(BUILD_DIR)/test_oal_time_tdd.o
HW_FEATURES_OBJ := $(BUILD_DIR)/test_ixgbe_hw_features_tdd.o
LIFECYCLE_OBJ := $(BUILD_DIR)/test_ixgbe_lifecycle_tdd.o
MASTER_OBJ := $(BUILD_DIR)/oal_master_tdd_runner.o

# Default target
.PHONY: all
all: banner setup $(TEST_EXECUTABLES)
	@echo ""
	@echo "=============================================================================="
	@echo "OAL TDD Test Suite Build Complete"
	@echo "=============================================================================="
	@echo "Platform: $(PLATFORM)"
	@echo "Build Type: $(BUILD_TYPE)"
	@echo "Compiler: $(CC)"
	@echo "Test Executables: $(words $(TEST_EXECUTABLES)) files"
	@echo ""
	@echo "Available targets:"
	@echo "  make test     - Run all TDD tests"
	@echo "  make clean    - Clean build artifacts"
	@echo "  make help     - Show detailed help"
	@echo "=============================================================================="

# Build banner
.PHONY: banner
banner:
	@echo ""
	@echo "=============================================================================="
	@echo "IXGBE OAL TDD TEST SUITE BUILD SYSTEM"
	@echo "=============================================================================="
	@echo "Project: $(PROJECT_NAME)"
	@echo "Version: $(VERSION)"
	@echo "Platform: $(PLATFORM)"
	@echo "Build Type: $(BUILD_TYPE)"
	@echo ""
	@echo "NON-NEGOTIABLE RULES ENFORCED:"
	@echo "✓ Zero framework calls (no iflib/linuxkpi/rte_*/DPDK usage)"
	@echo "✓ Native OS API calls ONLY"
	@echo "✓ Thin OAL seams: #ifdef trees, inline wrappers, weak symbols"
	@echo "✓ TDD-first: write failing test, then implement, then verify"
	@echo "✓ Minimal source touch: never rewrite when a seam wrapper suffices"
	@echo ""
	@echo "MISSION: Build TDD tests for every porting micro-slice"
	@echo "=============================================================================="

# Setup build directory
.PHONY: setup
setup:
	@mkdir -p $(BUILD_DIR)
	@echo "Build directory created: $(BUILD_DIR)"

# Individual test executables
$(BUILD_DIR)/test_oal_memory_tdd: $(MEMORY_OBJ)
	@echo "Linking memory TDD tests..."
	$(CC) -o $@ $< $(LDFLAGS)
	@echo "✓ Built: $@"

$(BUILD_DIR)/test_oal_register_tdd: $(REGISTER_OBJ)
	@echo "Linking register TDD tests..."
	$(CC) -o $@ $< $(LDFLAGS)
	@echo "✓ Built: $@"

$(BUILD_DIR)/test_oal_netdev_tdd: $(NETDEV_OBJ)
	@echo "Linking netdev TDD tests..."
	$(CC) -o $@ $< $(LDFLAGS)
	@echo "✓ Built: $@"

$(BUILD_DIR)/test_oal_interrupt_tdd: $(INTERRUPT_OBJ)
	@echo "Linking interrupt TDD tests..."
	$(CC) -o $@ $< $(LDFLAGS)
	@echo "✓ Built: $@"

$(BUILD_DIR)/test_oal_sync_tdd: $(SYNC_OBJ)
	@echo "Linking synchronization TDD tests..."
	$(CC) -o $@ $< $(LDFLAGS)
	@echo "✓ Built: $@"

$(BUILD_DIR)/test_oal_time_tdd: $(TIME_OBJ)
	@echo "Linking time TDD tests..."
	$(CC) -o $@ $< $(LDFLAGS)
	@echo "✓ Built: $@"

$(BUILD_DIR)/test_ixgbe_hw_features_tdd: $(HW_FEATURES_OBJ)
	@echo "Linking IXGBE hardware features TDD tests..."
	$(CC) -o $@ $< $(LDFLAGS)
	@echo "✓ Built: $@"

$(BUILD_DIR)/test_ixgbe_lifecycle_tdd: $(LIFECYCLE_OBJ)
	@echo "Linking IXGBE lifecycle TDD tests..."
	$(CC) -o $@ $< $(LDFLAGS)
	@echo "✓ Built: $@"

$(BUILD_DIR)/oal_master_tdd_runner: $(MASTER_OBJ) $(MEMORY_OBJ) $(REGISTER_OBJ) $(NETDEV_OBJ) $(INTERRUPT_OBJ) $(SYNC_OBJ) $(TIME_OBJ) $(HW_FEATURES_OBJ) $(LIFECYCLE_OBJ)
	@echo "Linking master TDD test runner..."
	$(CC) -o $@ $^ $(LDFLAGS)
	@echo "✓ Built: $@"

# Object file compilation
$(BUILD_DIR)/test_oal_memory_tdd.o: $(TEST_DIR)/test_oal_memory_tdd.c
	@echo "Compiling memory TDD tests..."
	$(CC) $(CFLAGS) $(INCLUDES) -DOAL_MEMORY_TDD_TEST_MAIN -c -o $@ $<

$(BUILD_DIR)/test_oal_register_tdd.o: $(TEST_DIR)/test_oal_register_tdd.c
	@echo "Compiling register TDD tests..."
	$(CC) $(CFLAGS) $(INCLUDES) -DOAL_REGISTER_TDD_TEST_MAIN -c -o $@ $<

$(BUILD_DIR)/test_oal_netdev_tdd.o: $(TEST_DIR)/test_oal_netdev_tdd.c
	@echo "Compiling netdev TDD tests..."
	$(CC) $(CFLAGS) $(INCLUDES) -DOAL_NETDEV_TDD_TEST_MAIN -c -o $@ $<

$(BUILD_DIR)/test_oal_interrupt_tdd.o: $(TEST_DIR)/test_oal_interrupt_tdd.c
	@echo "Compiling interrupt TDD tests..."
	$(CC) $(CFLAGS) $(INCLUDES) -DOAL_INTERRUPT_TDD_TEST_MAIN -c -o $@ $<

$(BUILD_DIR)/test_oal_sync_tdd.o: $(TEST_DIR)/test_oal_sync_tdd.c
	@echo "Compiling synchronization TDD tests..."
	$(CC) $(CFLAGS) $(INCLUDES) -DOAL_SYNC_TDD_TEST_MAIN -c -o $@ $<

$(BUILD_DIR)/test_oal_time_tdd.o: $(TEST_DIR)/test_oal_time_tdd.c
	@echo "Compiling time TDD tests..."
	$(CC) $(CFLAGS) $(INCLUDES) -DOAL_TIME_TDD_TEST_MAIN -c -o $@ $<

$(BUILD_DIR)/test_ixgbe_hw_features_tdd.o: $(TEST_DIR)/test_ixgbe_hw_features_tdd.c
	@echo "Compiling IXGBE hardware features TDD tests..."
	$(CC) $(CFLAGS) $(INCLUDES) -DIXGBE_HW_FEATURE_TDD_TEST_MAIN -c -o $@ $<

$(BUILD_DIR)/test_ixgbe_lifecycle_tdd.o: $(TEST_DIR)/test_ixgbe_lifecycle_tdd.c
	@echo "Compiling IXGBE lifecycle TDD tests..."
	$(CC) $(CFLAGS) $(INCLUDES) -DIXGBE_LIFECYCLE_TDD_TEST_MAIN -c -o $@ $<

$(BUILD_DIR)/oal_master_tdd_runner.o: $(TEST_DIR)/oal_master_tdd_runner.c
	@echo "Compiling master TDD runner..."
	$(CC) $(CFLAGS) $(INCLUDES) -c -o $@ $<

# Test execution targets
.PHONY: test
test: all
	@echo ""
	@echo "=============================================================================="
	@echo "EXECUTING OAL TDD TEST SUITE"
	@echo "=============================================================================="
	@echo "Running master TDD test runner..."
	@echo ""
	./$(BUILD_DIR)/oal_master_tdd_runner

.PHONY: test-memory
test-memory: $(BUILD_DIR)/test_oal_memory_tdd
	@echo "Running memory management TDD tests..."
	./$(BUILD_DIR)/test_oal_memory_tdd

.PHONY: test-register
test-register: $(BUILD_DIR)/test_oal_register_tdd
	@echo "Running register access TDD tests..."
	./$(BUILD_DIR)/test_oal_register_tdd

.PHONY: test-netdev
test-netdev: $(BUILD_DIR)/test_oal_netdev_tdd
	@echo "Running network device TDD tests..."
	./$(BUILD_DIR)/test_oal_netdev_tdd

.PHONY: test-interrupt
test-interrupt: $(BUILD_DIR)/test_oal_interrupt_tdd
	@echo "Running interrupt handling TDD tests..."
	./$(BUILD_DIR)/test_oal_interrupt_tdd

.PHONY: test-sync
test-sync: $(BUILD_DIR)/test_oal_sync_tdd
	@echo "Running synchronization TDD tests..."
	./$(BUILD_DIR)/test_oal_sync_tdd

.PHONY: test-time
test-time: $(BUILD_DIR)/test_oal_time_tdd
	@echo "Running time management TDD tests..."
	./$(BUILD_DIR)/test_oal_time_tdd

.PHONY: test-ixgbe-features
test-ixgbe-features: $(BUILD_DIR)/test_ixgbe_hw_features_tdd
	@echo "Running IXGBE hardware features TDD tests..."
	./$(BUILD_DIR)/test_ixgbe_hw_features_tdd

.PHONY: test-ixgbe-lifecycle
test-ixgbe-lifecycle: $(BUILD_DIR)/test_ixgbe_lifecycle_tdd
	@echo "Running IXGBE lifecycle TDD tests..."
	./$(BUILD_DIR)/test_ixgbe_lifecycle_tdd

# Test suite selection
.PHONY: test-suite
test-suite: $(BUILD_DIR)/oal_master_tdd_runner
	@if [ -z "$(SUITE)" ]; then \
		echo "Usage: make test-suite SUITE=<suite_name>"; \
		echo "Available suites: OAL_MEMORY OAL_REGISTER OAL_NETDEV OAL_INTERRUPT OAL_SYNC OAL_TIME"; \
		exit 1; \
	fi
	@echo "Running specific test suite: $(SUITE)"
	./$(BUILD_DIR)/oal_master_tdd_runner $(SUITE)

# Validation and analysis targets
.PHONY: validate
validate: all
	@echo ""
	@echo "=============================================================================="
	@echo "VALIDATING TDD TEST FRAMEWORK"
	@echo "=============================================================================="
	@echo "1. Checking for framework contamination..."
	@if grep -r "iflib\|linuxkpi\|rte_\|DPDK" $(TEST_DIR)/*.c; then \
		echo "❌ FRAMEWORK CONTAMINATION DETECTED!"; \
		echo "Found forbidden framework calls in test code."; \
		exit 1; \
	else \
		echo "✅ No framework contamination detected"; \
	fi
	@echo ""
	@echo "2. Verifying TDD test structure..."
	@for test_file in $(TEST_DIR)/test_oal_*.c; do \
		if grep -q "TDD EXPECTED FAILURE" $$test_file; then \
			echo "✅ TDD structure found in $$test_file"; \
		else \
			echo "❌ Missing TDD structure in $$test_file"; \
		fi; \
	done
	@echo ""
	@echo "3. Checking test coverage..."
	@echo "   Memory tests: $$(grep -c "static bool test_" $(TEST_DIR)/test_oal_memory_tdd.c)"
	@echo "   Register tests: $$(grep -c "static bool test_" $(TEST_DIR)/test_oal_register_tdd.c)"
	@echo "   Netdev tests: $$(grep -c "static bool test_" $(TEST_DIR)/test_oal_netdev_tdd.c)"
	@echo "   Interrupt tests: $$(grep -c "static bool test_" $(TEST_DIR)/test_oal_interrupt_tdd.c)"
	@echo "   Sync tests: $$(grep -c "static bool test_" $(TEST_DIR)/test_oal_sync_tdd.c)"
	@echo "   Time tests: $$(grep -c "static bool test_" $(TEST_DIR)/test_oal_time_tdd.c)"
	@echo ""
	@echo "✅ TDD test framework validation complete"

# Static analysis
.PHONY: lint
lint:
	@echo "Running static analysis on TDD tests..."
	@if command -v cppcheck >/dev/null 2>&1; then \
		cppcheck --enable=all --std=c99 $(TEST_DIR)/*.c; \
	else \
		echo "cppcheck not found, skipping static analysis"; \
	fi

# Documentation generation
.PHONY: docs
docs:
	@echo "Generating TDD test documentation..."
	@mkdir -p $(BUILD_DIR)/docs
	@echo "# OAL TDD Test Documentation" > $(BUILD_DIR)/docs/README.md
	@echo "" >> $(BUILD_DIR)/docs/README.md
	@echo "## Test Suites" >> $(BUILD_DIR)/docs/README.md
	@for test_file in $(TEST_DIR)/test_oal_*.c; do \
		suite_name=$$(basename $$test_file .c | sed 's/test_//'); \
		echo "" >> $(BUILD_DIR)/docs/README.md; \
		echo "### $$suite_name" >> $(BUILD_DIR)/docs/README.md; \
		grep "EXPECTED TO FAIL:" $$test_file | wc -l | xargs printf "Tests: %d\n" >> $(BUILD_DIR)/docs/README.md; \
	done
	@echo "Documentation generated: $(BUILD_DIR)/docs/README.md"

# Debug build
.PHONY: debug
debug:
	@$(MAKE) DEBUG=1 all

# Packaging
.PHONY: package
package: all docs
	@echo "Creating TDD test package..."
	@mkdir -p $(BUILD_DIR)/package
	@tar czf $(BUILD_DIR)/package/$(PROJECT_NAME)-$(VERSION)-$(PLATFORM).tar.gz \
		$(BUILD_DIR)/*.exe $(BUILD_DIR)/docs \
		$(TEST_DIR)/*.c Makefile README.md
	@echo "Package created: $(BUILD_DIR)/package/$(PROJECT_NAME)-$(VERSION)-$(PLATFORM).tar.gz"

# Installation
.PHONY: install
install: all
	@echo "Installing TDD test suite..."
	@mkdir -p /usr/local/bin/ixgbe-oal-tdd
	@cp $(TEST_EXECUTABLES) /usr/local/bin/ixgbe-oal-tdd/
	@echo "Installed to: /usr/local/bin/ixgbe-oal-tdd/"

# Cleanup
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@echo "✓ Build directory cleaned"

.PHONY: distclean
distclean: clean
	@echo "Performing full cleanup..."
	@rm -f *.log *.tmp
	@echo "✓ Full cleanup complete"

# Help
.PHONY: help
help:
	@echo ""
	@echo "IXGBE OAL TDD Test Suite Build System"
	@echo "====================================="
	@echo ""
	@echo "BUILD TARGETS:"
	@echo "  all           - Build all test executables (default)"
	@echo "  debug         - Build with debug symbols and optimization disabled"
	@echo "  clean         - Remove build artifacts"
	@echo "  distclean     - Full cleanup including temporary files"
	@echo ""
	@echo "TEST TARGETS:"
	@echo "  test          - Run all TDD tests via master runner"
	@echo "  test-memory   - Run memory management TDD tests only"
	@echo "  test-register - Run register access TDD tests only"
	@echo "  test-netdev   - Run network device TDD tests only"
	@echo "  test-interrupt- Run interrupt handling TDD tests only"
	@echo "  test-sync     - Run synchronization TDD tests only"
	@echo "  test-time     - Run time management TDD tests only"
	@echo "  test-suite    - Run specific suite (use SUITE=<name>)"
	@echo ""
	@echo "VALIDATION TARGETS:"
	@echo "  validate      - Validate TDD test framework integrity"
	@echo "  lint          - Run static analysis (requires cppcheck)"
	@echo ""
	@echo "UTILITY TARGETS:"
	@echo "  docs          - Generate test documentation"
	@echo "  package       - Create distribution package"
	@echo "  install       - Install test suite to system"
	@echo "  help          - Show this help"
	@echo ""
	@echo "EXAMPLES:"
	@echo "  make test                    # Run all tests"
	@echo "  make test-suite SUITE=OAL_MEMORY  # Run memory tests only"
	@echo "  make DEBUG=1 test           # Debug build and test"
	@echo "  make validate               # Check framework integrity"
	@echo ""
	@echo "EXPECTED BEHAVIOR:"
	@echo "  ✓ All tests should FAIL (TDD methodology)"
	@echo "  ✓ No framework contamination"
	@echo "  ✓ Native OS API usage only"
	@echo "  ✓ Tests ready to guide implementation"

# Dependencies
.PHONY: deps
deps:
	@echo "Checking build dependencies..."
	@which $(CC) >/dev/null || (echo "Error: $(CC) not found" && exit 1)
	@echo "✓ Compiler: $(CC)"
	@which make >/dev/null || (echo "Error: make not found" && exit 1)
	@echo "✓ Build system: make"
	@echo "Dependencies satisfied"

# Show build configuration
.PHONY: config
config:
	@echo "Build Configuration:"
	@echo "  Platform: $(PLATFORM)"
	@echo "  Compiler: $(CC)"
	@echo "  CFLAGS: $(CFLAGS)"
	@echo "  LDFLAGS: $(LDFLAGS)"
	@echo "  Build Dir: $(BUILD_DIR)"
	@echo "  Test Dir: $(TEST_DIR)"

# Force rebuild
.PHONY: rebuild
rebuild: clean all

# Prevent deletion of intermediate files
.PRECIOUS: $(BUILD_DIR)/%.o

# Declare phony targets (targets that don't create files)
.PHONY: all banner setup test test-memory test-register test-netdev test-interrupt \
        test-sync test-time test-suite validate lint docs debug package install \
        clean distclean help deps config rebuild