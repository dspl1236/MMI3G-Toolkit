#!/bin/ksh
# ============================================================
# GEM Activator — Enable Engineering Menu from SD card
# Works on MMI3G+, MMI3G High, and RNS-850
#
# Creates /HBpersistence/DBGModeActive — the same file marker
# checked by both Audi MMI3GApplication and Porsche PCM3Root.
# Confirmed working on Cayenne 958 PCM 3.1 (dspl1236).
#
# After reboot, open GEM with:
#   MMI 3G+:  CAR + BACK (hold ~5s)
#   MMI 3G:   CAR + SETUP (hold ~5s)
#   RNS-850:  CAR + SETUP (hold ~5s)
#
# Part of MMI-Toolkit: github.com/dspl1236/MMI-Toolkit
# ============================================================

SDPATH="${1:-$(dirname $0)}"

# Source platform.sh for QNX compatibility shims
if [ -f "${SDPATH}/scripts/common/platform.sh" ]; then
    . "${SDPATH}/scripts/common/platform.sh"
elif [ -f "/mnt/efs-system/scripts/common/platform.sh" ]; then
    . "/mnt/efs-system/scripts/common/platform.sh"
fi

LOG="${SDPATH}/var/gem_enable.log"
mkdir -p "${SDPATH}/var" 2>/dev/null

{
echo "============================================"
echo " MMI-Toolkit GEM Activator"
echo " $(date 2>/dev/null)"
echo " Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo "============================================"
echo ""

# Ensure /HBpersistence is writable
if [ ! -d /HBpersistence ]; then
    echo "[ERROR] /HBpersistence not found"
    exit 1
fi
mount -uw /HBpersistence 2>/dev/null

# === THE KEY: Create DBGModeActive ===
if [ -f /HBpersistence/DBGModeActive ]; then
    echo "[OK] /HBpersistence/DBGModeActive already exists"
    echo "     GEM is already enabled"
else
    touch /HBpersistence/DBGModeActive
    if [ -f /HBpersistence/DBGModeActive ]; then
        echo "[OK] Created /HBpersistence/DBGModeActive"
        echo "     GEM ENABLED — reboot MMI to activate"
    else
        echo "[ERROR] Failed to create DBGModeActive"
        exit 1
    fi
fi

# Also ensure engdefs directory exists for custom screens
EFSDIR="/mnt/efs-system"
if [ -d "$EFSDIR" ]; then
    mount -uw "$EFSDIR" 2>/dev/null
    mkdir -p "${EFSDIR}/engdefs" 2>/dev/null
    echo "[OK] engdefs/ directory ready"
    
    # Copy any ESD screens from SD card
    if [ -d "${SDPATH}/engdefs" ]; then
        for esd in ${SDPATH}/engdefs/*.esd; do
            [ -f "$esd" ] || continue
            cp "$esd" "${EFSDIR}/engdefs/" 2>/dev/null
            echo "[INST] $(basename $esd)"
        done
    fi
    sync
    mount -ur "$EFSDIR" 2>/dev/null
fi

# Backup activation state to SD
echo ""
echo "--- Activation State ---"
ls -la /HBpersistence/DBGModeActive 2>/dev/null
ls -la /HBpersistence/PagSWAct* 2>/dev/null

echo ""
echo "============================================"
echo " REBOOT MMI to activate GEM"
echo " Hold MENU + rotary knob + top-right softkey"
echo " Then open GEM: CAR + BACK (hold 5 sec)"
echo "============================================"
} > "$LOG" 2>&1

# Also output to console
cat "$LOG"

# Show GEM enabled screen
if [ -x "${SDPATH}/bin/showScreen" ] && [ -f "${SDPATH}/lib/gem_enabled.png" ]; then
    "${SDPATH}/bin/showScreen" "${SDPATH}/lib/gem_enabled.png" 2>/dev/null &
fi
