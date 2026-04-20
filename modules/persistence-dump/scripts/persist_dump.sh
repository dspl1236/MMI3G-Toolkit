#!/bin/ksh
# persistence-dump — Capture full persistence state to SD card
# Use before/after VCDS changes to find what bytes changed
# Part of MMI3G-Toolkit: github.com/dspl1236/MMI3G-Toolkit

SDPATH="${1:-$(dirname $0)}"
TS=$(date +%H%M%S 2>/dev/null || echo "000000")
DUMP="${SDPATH}/dump_${TS}"
LOG="${SDPATH}/var/persist_dump_${TS}.log"

mkdir -p "${DUMP}/HBpersistence" "${DUMP}/efs_persist" "${DUMP}/shmem" "${DUMP}/coding" "${SDPATH}/var" 2>/dev/null

# Show status on MMI screen if showScreen available
if [ -x "${SDPATH}/bin/showScreen" ] && [ -f "${SDPATH}/lib/running.png" ]; then
    "${SDPATH}/bin/showScreen" "${SDPATH}/lib/running.png" 2>/dev/null
fi

exec > ${LOG} 2>&1

echo "============================================"
echo " MMI3G-Toolkit Persistence Dump"
echo " $(date 2>/dev/null)"
echo "============================================"

# Platform
echo ""
echo "--- Platform ---"
for f in /etc/pci-3g_*.cfg; do [ -f "$f" ] && echo "HW: $f"; done
TRAIN=$(cat /dev/shmem/sw_trainname.txt 2>/dev/null)
echo "Train: ${TRAIN:-unknown}"

# HBpersistence (main persistence storage)
echo ""
echo "--- /HBpersistence/ ---"
if [ -d /HBpersistence ]; then
    ls -laR /HBpersistence/ > "${DUMP}/HBpersistence_listing.txt" 2>&1
    # Copy ALL files under 128KB
    find /HBpersistence -type f -size -128k 2>/dev/null | while read f; do
        dest="${DUMP}/HBpersistence/$(echo $f | sed 's|/|_|g')"
        cp "$f" "$dest" 2>/dev/null
    done
    echo "Dumped $(ls ${DUMP}/HBpersistence/ | wc -l) files"
fi

# efs-persist (flash persistence partition)
echo ""
echo "--- /mnt/efs-persist/ ---"
if [ -d /mnt/efs-persist ]; then
    ls -laR /mnt/efs-persist/ > "${DUMP}/efs_persist_listing.txt" 2>&1
    find /mnt/efs-persist -type f -size -128k 2>/dev/null | while read f; do
        dest="${DUMP}/efs_persist/$(basename $f)"
        cp "$f" "$dest" 2>/dev/null
    done
    echo "Dumped $(ls ${DUMP}/efs_persist/ | wc -l) files"
fi

# Shared memory (runtime state including coding/adaptation)
echo ""
echo "--- /dev/shmem/ ---"
ls -la /dev/shmem/ > "${DUMP}/shmem_listing.txt" 2>&1
for f in /dev/shmem/*; do
    [ -f "$f" ] || continue
    sz=$(ls -la "$f" 2>/dev/null | awk '{print $5}')
    if [ -n "$sz" ] && [ "$sz" -lt 65536 ] 2>/dev/null; then
        cp "$f" "${DUMP}/shmem/$(basename $f)" 2>/dev/null
    fi
done
echo "Dumped $(ls ${DUMP}/shmem/ 2>/dev/null | wc -l) shmem files"

# Coding/adaptation state
echo ""
echo "--- Coding Data ---"
# Long coding bytes are often in shmem or persistence
for pattern in coding adapt engineer debug gem; do
    for dir in /HBpersistence /mnt/efs-persist /dev/shmem /mnt/persistence; do
        find "$dir" -name "*${pattern}*" -type f 2>/dev/null | while read f; do
            echo "Found: $f"
            cp "$f" "${DUMP}/coding/$(echo $f | sed 's|/|_|g')" 2>/dev/null
        done
    done
done

# GEM infrastructure check
echo ""
echo "--- GEM State ---"
[ -d /mnt/efs-system/engdefs ] && echo "engdefs/ EXISTS ($(ls /mnt/efs-system/engdefs/*.esd 2>/dev/null | wc -l) screens)" || echo "engdefs/ MISSING"
[ -f /mnt/efs-system/lsd/AppDevelopment.jar ] && echo "AppDevelopment.jar EXISTS" || echo "AppDevelopment.jar MISSING"

# engdefs listing
ls -la /mnt/efs-system/engdefs/ > "${DUMP}/engdefs_listing.txt" 2>&1

# Process list
echo ""
echo "--- Processes ---"
pidin ar > "${DUMP}/processes.txt" 2>&1

# IPC nodes
ls -la /dev/ipc/ > "${DUMP}/dev_ipc.txt" 2>&1

echo ""
echo "============================================"
echo " Dump saved to: ${DUMP}/"
echo " $(ls -R ${DUMP}/ | wc -l) total entries"
echo ""
echo " TO FIND GEM ENABLE BYTE:"
echo "   1. Save this dump as 'BEFORE'"
echo "   2. Enable GEM via VCDS (5F ch6=1)"  
echo "   3. Run this dump again as 'AFTER'"
echo "   4. Diff the two dumps"
echo "============================================"

# Also copy the log to the dump directory
cp "${LOG}" "${DUMP}/" 2>/dev/null
