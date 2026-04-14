#!/bin/ksh
# ============================================================
# Splash Screen Installer
# Custom boot logo for MMI 3G High, 3G+, and RNS-850
# ============================================================
# Copies startup_generic.png from SD card to MMI flash.
# Backs up existing splash screens first.
#
# Image requirements:
#   - 800x480 PNG for MMI 3G High / 3G+
#   - 400x240 PNG for MMI 3G Basic
#   - 8-bit or 24-bit color depth
#   - Filename: startup_generic.png
# ============================================================

SDPATH="${1:-$(dirname $0)}"
LOGFILE="${SDPATH}/var/splash-$(date +%Y%m%d-%H%M%S).log"
EFSDIR="/mnt/efs-system"
SPLASHDIR="${EFSDIR}/etc/splashscreens"

exec > ${LOGFILE} 2>&1

echo "============================================"
echo " Splash Screen Installer"
echo " $(date)"
echo " Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo "============================================"
echo ""

# --- Verify source image ---
SRCIMAGE="${SDPATH}/splashscreens/startup_generic.png"
if [ ! -f "${SRCIMAGE}" ]; then
    echo "[ERROR] startup_generic.png not found in splashscreens/"
    echo "[ERROR] Place your 800x480 PNG in the splashscreens folder"
    exit 1
fi

IMGSIZE=$(ls -l "${SRCIMAGE}" | awk '{print $5}')
echo "[OK]    Source image found (${IMGSIZE} bytes)"
echo ""

# --- Remount ---
echo "[ACTI]  Remounting efs-system rw..."
mount -uw ${EFSDIR}
if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to remount"
    exit 1
fi
echo "[OK]    Remounted"
echo ""

# --- Verify destination ---
if [ ! -d "${SPLASHDIR}" ]; then
    echo "[ERROR] Splash screen directory not found!"
    echo "[ERROR] ${SPLASHDIR}"
    echo "[ERROR] Your firmware may not support custom splash screens"
    exit 1
fi

# --- Backup existing screens ---
BACKUPDIR="${SDPATH}/var/splash-backup-$(date +%Y%m%d)"
mkdir -p ${BACKUPDIR}

echo "[ACTI]  Backing up existing splash screens..."
cp -v ${SPLASHDIR}/*.png ${BACKUPDIR}/ 2>/dev/null
cp -v ${SPLASHDIR}/*.txt ${BACKUPDIR}/ 2>/dev/null
echo "[OK]    Backup saved to SD: var/splash-backup-*/"
echo ""

# --- Install custom splash ---
echo "[ACTI]  Installing custom splash screen..."
cp -v "${SRCIMAGE}" "${SPLASHDIR}/startup_generic.png"
if [ $? -eq 0 ]; then
    echo "[OK]    startup_generic.png installed"
else
    echo "[ERROR] Failed to copy splash screen!"
    exit 1
fi
echo ""

# --- Sync ---
sync

echo "============================================"
echo " Splash Screen Installed!"
echo ""
echo " Reboot MMI to see your new boot screen:"
echo "   Hold MENU + rotary knob + upper-right soft key"
echo ""
echo " If it doesn't appear, also try:"
echo "   GEM > /car/carcodingvehicle > Update Splashscreen"
echo ""
echo " To restore original: copy backed up PNGs from"
echo "   SD:/var/splash-backup-*/ back to splashscreens/"
echo "   folder and run script again."
echo ""
echo " Log: ${LOGFILE}"
echo "============================================"
