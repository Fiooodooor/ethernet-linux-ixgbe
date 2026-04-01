#!/bin/bash
# Build Verification Gates
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

WORKSPACE="/root/.clawteam/workspaces/nic-port-v2-rerun7/verification-executor"
LOG_DIR="$WORKSPACE/verification_logs"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

echo "=== BUILD VERIFICATION GATES ==="

# Check for FreeBSD target
if [ -d "/root/.clawteam/workspaces/nic-port-v2-rerun7/coder" ]; then
    echo "Found FreeBSD target workspace"
    FREEBSD_TARGET="/root/.clawteam/workspaces/nic-port-v2-rerun7/coder"
elif find /root/.clawteam/workspaces/nic-port-v2-rerun7 -name "*freebsd*" -type d 2>/dev/null | head -1; then
    echo "Found FreeBSD target directory"
    FREEBSD_TARGET=$(find /root/.clawteam/workspaces/nic-port-v2-rerun7 -name "*freebsd*" -type d 2>/dev/null | head -1)
else
    echo "FreeBSD target not yet available - will verify Linux baseline"
    FREEBSD_TARGET=""
fi

# Verify Linux source build capability
cd "$WORKSPACE/src"
if [ -f "Makefile" ]; then
    echo -e "${GREEN}✓ Build system found${NC}"
    echo "Makefile available for build verification"
else
    echo -e "${RED}✗ No build system found${NC}"
fi

echo "Build verification prepared for execution when dependencies ready"
