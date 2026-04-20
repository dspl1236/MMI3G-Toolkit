#!/bin/ksh
# GEM Status — Check if engineering menu is enabled
# Part of MMI-Toolkit: github.com/dspl1236/MMI-Toolkit

SDPATH="${1:-$(dirname $0)}"
LOG="${SDPATH}/var/gem_status.log"
mkdir -p "${SDPATH}/var" 2>/dev/null

{
echo "============================================"
echo " MMI-Toolkit GEM Status"
echo " $(date 2>/dev/null)"
echo " Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo "============================================"
echo ""

# Check DBGModeActive (THE enable flag)
if [ -f /HBpersistence/DBGModeActive ]; then
    echo "[GEM] ENABLED — /HBpersistence/DBGModeActive exists"
    ls -la /HBpersistence/DBGModeActive
else
    echo "[GEM] DISABLED — /HBpersistence/DBGModeActive not found"
fi
echo ""

# Check engdefs
if [ -d /mnt/efs-system/engdefs ]; then
    COUNT=$(ls /mnt/efs-system/engdefs/*.esd 2>/dev/null | wc -l)
    echo "[ESD] engdefs/ exists — ${COUNT} screen files"
else
    echo "[ESD] engdefs/ not found"
fi

# Check AppDevelopment.jar
for j in /mnt/efs-system/lsd/AppDevelopment.jar /mnt/efs-system/lsd/development/AppDevelopment.jar; do
    [ -f "$j" ] && echo "[JAR] $(ls -la $j)"
done

# Check PagSWAct (Porsche activation — informational)
[ -f /HBpersistence/PagSWAct.002 ] && echo "[ACT] PagSWAct.002 present (Porsche activation file)"

echo ""
echo "============================================"
} > "$LOG" 2>&1
cat "$LOG"
