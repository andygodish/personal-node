#!/usr/bin/env bash
#
# Hardware Audit Script for Bitcoin Full Node + Electrs
# Supports macOS and Linux
#

set -e

# --- Threshold Baselines ---
MIN_CPU_CORES=2
MIN_RAM_GB=4
REC_RAM_GB=8
MIN_DISK_FREE_GB=750  # ~710GB blockchain + ~80GB electrs index + buffer

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}     BITCOIN NODE HARDWARE READINESS REPORT        ${NC}"
echo -e "${BLUE}====================================================${NC}"
echo -e "Timestamp: $(date)"
echo ""

# Detect OS
OS_TYPE="$(uname -s)"
echo -e "Operating System : ${OS_TYPE} ($(uname -r))"

# 1. CPU Audit
ARCH="$(uname -m)"
if [ "$OS_TYPE" = "Darwin" ]; then
    CPU_CORES=$(sysctl -n hw.ncpu)
    CPU_MODEL=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Apple Silicon / Generic")
else
    CPU_CORES=$(nproc)
    CPU_MODEL=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | sed 's/^[ \t]*//')
fi

echo -e "Architecture     : ${ARCH}"
echo -e "CPU Model        : ${CPU_MODEL}"
echo -e "Logical Cores    : ${CPU_CORES}"

# 2. RAM Audit
if [ "$OS_TYPE" = "Darwin" ]; then
    RAM_BYTES=$(sysctl -n hw.memsize)
    TOTAL_RAM_GB=$((RAM_BYTES / 1024 / 1024 / 1024))
else
    TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))
fi

echo -e "Total System RAM : ${TOTAL_RAM_GB} GB"

# 3. Storage Audit (Root Volume)
if [ "$OS_TYPE" = "Darwin" ]; then
    # Free space on root partition in GB
    DISK_FREE_GB=$(df -g / | awk 'NR==2 {print $4}')
    
    # Check if NVMe/SSD
    IS_SSD=$(diskutil info / | grep "Solid State" | awk '{print $3}' || echo "Unknown")
    PROTOCOL=$(diskutil info / | grep "Protocol" | awk '{print $2}' || echo "Unknown")
    STORAGE_TYPE="${PROTOCOL} (SSD: ${IS_SSD})"
else
    DISK_FREE_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    
    # Check rotation on primary block device (0 = SSD/NVMe, 1 = HDD)
    ROOT_DEV=$(df / | awk 'NR==2 {print $1}' | sed 's/[0-9]*$//' | sed 's/p[0-9]*$//' | sed 's#/dev/##')
    ROTATION=$(cat /sys/block/${ROOT_DEV}/queue/rotational 2>/dev/null || echo "1")
    if [ "$ROTATION" = "0" ]; then
        STORAGE_TYPE="SSD / NVMe"
    else
        STORAGE_TYPE="Spinning HDD"
    fi
fi

echo -e "Storage Type     : ${STORAGE_TYPE}"
echo -e "Free Disk Space  : ${DISK_FREE_GB} GB available"
echo ""

# --- ASSESSMENT MATRIX ---
echo -e "${BLUE}----------------------------------------------------${NC}"
echo -e "${BLUE}                 EVALUATION METRICS                 ${NC}"
echo -e "${BLUE}----------------------------------------------------${NC}"

FAIL_COUNT=0
WARN_COUNT=0

# CPU Assessment
if [ "$CPU_CORES" -ge "$MIN_CPU_CORES" ]; then
    echo -e "CPU Cores        : [ ${GREEN}PASS${NC} ] (${CPU_CORES} cores available)"
else
    echo -e "CPU Cores        : [ ${RED}FAIL${NC} ] (${CPU_CORES} cores is below minimum of ${MIN_CPU_CORES})"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# RAM Assessment
if [ "$TOTAL_RAM_GB" -ge "$REC_RAM_GB" ]; then
    echo -e "RAM Capacity     : [ ${GREEN}PASS${NC} ] (${TOTAL_RAM_GB} GB allows fast UTXO caching)"
elif [ "$TOTAL_RAM_GB" -ge "$MIN_RAM_GB" ]; then
    echo -e "RAM Capacity     : [ ${YELLOW}WARN${NC} ] (${TOTAL_RAM_GB} GB works, but allocate lower dbcache)"
    WARN_COUNT=$((WARN_COUNT + 1))
else
    echo -e "RAM Capacity     : [ ${RED}FAIL${NC} ] (${TOTAL_RAM_GB} GB is insufficient)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Drive Type Assessment
if [[ "$STORAGE_TYPE" == *"PCI"* ]] || [[ "$STORAGE_TYPE" == *"NVMe"* ]] || [[ "$STORAGE_TYPE" == *"Yes"* ]]; then
    echo -e "Disk Speed       : [ ${GREEN}PASS${NC} ] (High-speed solid-state media detected)"
else
    echo -e "Disk Speed       : [ ${YELLOW}WARN${NC} ] (Mechanical HDDs will severely slow electrs indexing)"
    WARN_COUNT=$((WARN_COUNT + 1))
fi

# Disk Space Assessment
if [ "$DISK_FREE_GB" -ge "$MIN_DISK_FREE_GB" ]; then
    echo -e "Free Disk Space  : [ ${GREEN}PASS${NC} ] (${DISK_FREE_GB} GB is enough for full node + electrs)"
else
    echo -e "Free Disk Space  : [ ${YELLOW}WARN${NC} ] (${DISK_FREE_GB} GB is insufficient for a COMPLETE sync)"
    echo -e "                   ↳ Note: Sufficient for testing/partial sync, but full sync needs ~750GB+"
    WARN_COUNT=$((WARN_COUNT + 1))
fi

echo -e "${BLUE}====================================================${NC}"

# Final Verdict
if [ "$FAIL_COUNT" -eq 0 ] && [ "$WARN_COUNT" -eq 0 ]; then
    echo -e "VERDICT          : ${GREEN}READY FOR FULL DEPLOYMENT${NC}"
elif [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "VERDICT          : ${YELLOW}SUITABLE FOR TEST / CONSTRAINED RUN${NC}"
else
    echo -e "VERDICT          : ${RED}NOT RECOMMENDED (HARDWARE CONSTRAINTS)${NC}"
fi
echo -e "${BLUE}====================================================${NC}"