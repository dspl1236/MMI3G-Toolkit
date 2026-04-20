#!/bin/ksh
# GEM Deactivator — Remove DBGModeActive to disable engineering menu
# Part of MMI3G-Toolkit: github.com/dspl1236/MMI3G-Toolkit

SDPATH="${1:-$(dirname $0)}"
LOG="${SDPATH}/var/gem_disable.log"
mkdir -p "${SDPATH}/var" 2>/dev/null

{
echo "============================================"
echo " MMI3G-Toolkit GEM Deactivator"
echo " $(date 2>/dev/null)"
echo "============================================"
echo ""

mount -uw /HBpersistence 2>/dev/null

if [ -f /HBpersistence/DBGModeActive ]; then
    rm -f /HBpersistence/DBGModeActive
    echo "[OK] Removed /HBpersistence/DBGModeActive"
    echo "     GEM DISABLED — reboot MMI to take effect"
else
    echo "[OK] /HBpersistence/DBGModeActive not present"
    echo "     GEM is already disabled"
fi

echo ""
echo " Reboot MMI after this to fully disable GEM."
echo "============================================"
} > "$LOG" 2>&1
cat "$LOG"
