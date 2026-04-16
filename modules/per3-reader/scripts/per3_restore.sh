#!/bin/ksh
# ============================================================
# per3-reader uninstaller
# ============================================================
# Removes our per3-reader.jar from the DSITracer slot and
# restores any original DSITracer.jar we backed up.
# ============================================================

SDPATH="${1:-$(dirname $0)}"
EFSDIR="/mnt/efs-system"
LSDDIR="${EFSDIR}/lsd"
TARGET="${LSDDIR}/DSITracer.jar"

echo "============================================"
echo " per3-reader Uninstaller"
echo " $(date)"
echo "============================================"
echo ""

mount -uw ${EFSDIR}
if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to remount ${EFSDIR} rw"
    exit 1
fi

if [ -f "${TARGET}.bak" ]; then
    echo "[ACTI]  Restoring original DSITracer.jar from backup..."
    mv "${TARGET}.bak" "${TARGET}"
    chmod 0644 "${TARGET}"
    echo "[OK]    Restored"
elif [ -f "${TARGET}" ]; then
    echo "[ACTI]  No backup exists — simply removing per3-reader.jar"
    rm -v "${TARGET}"
    echo "[OK]    Removed"
else
    echo "[INFO]  Nothing to remove — DSITracer slot is already empty"
fi

sync
mount -ur ${EFSDIR} 2>/dev/null

echo ""
echo "per3-reader uninstalled. Reboot MMI to take effect:"
echo "   Hold MENU + rotary knob + upper-right soft key"
