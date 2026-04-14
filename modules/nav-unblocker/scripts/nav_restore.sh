#!/bin/ksh
# ============================================================
# Nav Database Unblocker - Restore / Uninstall
# Removes the manage_cd.sh patch, restoring factory activation
# ============================================================

SDPATH="${1:-$(dirname $0)}"
LOGFILE="${SDPATH}/var/nav-restore-$(date +%Y%m%d-%H%M%S).log"
EFSDIR="/mnt/efs-system"
MANAGE_CD="${EFSDIR}/usr/bin/manage_cd.sh"

exec > ${LOGFILE} 2>&1

echo "============================================"
echo " Nav Unblocker - Restore Factory Activation"
echo " $(date)"
echo "============================================"
echo ""

mount -uw ${EFSDIR}

# Try to restore from our backup first
BACKUPDIR="${SDPATH}/var/navunblocker-backup"
if [ -f "${BACKUPDIR}/manage_cd.sh.original" ]; then
    echo "[ACTI]  Restoring manage_cd.sh from backup..."
    cp -v "${BACKUPDIR}/manage_cd.sh.original" "${MANAGE_CD}"
    echo "[OK]    Restored from SD card backup"
else
    # No backup — try to strip just our appended lines
    echo "[INFO]  No backup found on SD card"
    echo "[ACTI]  Attempting to strip patch from manage_cd.sh..."
    
    if [ -f "${MANAGE_CD}" ]; then
        # Create temp file without our patch lines
        grep -v "acios_db.ini" "${MANAGE_CD}" | \
        grep -v "MMI3G-Toolkit Nav Unblocker" | \
        grep -v "Disables H-B nav database" | \
        grep -v "Installed:" > "${MANAGE_CD}.clean"
        
        mv "${MANAGE_CD}.clean" "${MANAGE_CD}"
        chmod +x "${MANAGE_CD}"
        echo "[OK]    Patch lines stripped"
    else
        echo "[ERROR] manage_cd.sh not found!"
        exit 1
    fi
fi

sync
echo ""
echo "Nav database activation restored to factory behavior."
echo "Reboot MMI for changes to take effect."
echo ""
echo "WARNING: If you have an updated nav database without"
echo "a valid FSC file, navigation will be blocked after reboot."
echo "============================================"
