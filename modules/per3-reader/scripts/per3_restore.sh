#!/bin/ksh
# ============================================================
# per3-reader uninstaller
# ============================================================
# Removes our per3-reader.jar from the DSITracer slot and
# restores any original DSITracer.jar we backed up.
# ============================================================

SDPATH="${1:-${0%/*}}"
EFSDIR="/mnt/efs-system"
LSDDIR="${EFSDIR}/lsd"
TARGET="${LSDDIR}/DSITracer.jar"

echo "============================================"
echo " per3-reader Uninstaller"
echo " $(date)"
echo "============================================"
echo ""

# --- Reclaim interlock (see research/F3S_FORMAT.md) ---
touch /tmp/disableReclaim
trap '_rc=$?; rm -f /tmp/disableReclaim 2>/dev/null; mount -ur '"${EFSDIR}"' 2>/dev/null; exit $_rc' EXIT INT TERM

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
rm -f /tmp/disableReclaim

echo ""
echo "per3-reader uninstalled. Reboot MMI to take effect:"
echo "   Hold MENU + rotary knob + upper-right soft key"
