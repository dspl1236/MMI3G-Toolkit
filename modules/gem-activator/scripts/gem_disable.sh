#!/bin/ksh
# ============================================================
# GEM Deactivator - Disable Green Engineering Menu
# Reverses the activation performed by gem_enable.sh
# ============================================================

SDPATH="${1:-$(dirname $0)}"
LOGFILE="${SDPATH}/var/gem-deactivate-$(date +%Y%m%d-%H%M%S).log"
EFSDIR="/mnt/efs-system"

exec > ${LOGFILE} 2>&1

echo "============================================"
echo " GEM Deactivator"
echo " $(date)"
echo "============================================"
echo ""

mount -uw ${EFSDIR} 2>/dev/null
mount -uw /mnt/efs-persist 2>/dev/null

# Remove state marker
GEM_STATE="${EFSDIR}/engdefs/.gem_enabled"
if [ -f "${GEM_STATE}" ]; then
    rm -v ${GEM_STATE}
    echo "[OK] GEM state marker removed"
fi

# Try to clear via persist_data if available
if [ -x "/usr/bin/persist_data" ]; then
    /usr/bin/persist_data -w 5F 6 0 2>/dev/null
    echo "[OK] Adaptation channel 5F/6 set to 0"
fi

sync

echo ""
echo "GEM deactivated. Reboot MMI to take effect."
echo "If GEM persists, use VCDS to set 5F channel 6 = 0."
echo "============================================"
