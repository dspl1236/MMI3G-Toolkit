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

# Restore strategy (in order of preference):
#   1. The -ORIG file our own installer left on the MMI at
#      /mnt/efs-system/usr/bin/manage_cd.sh-ORIG (most reliable —
#      exact byte-for-byte original, preserved perms/timestamps)
#   2. An SD-side backup under var/navunblocker-backup/
#   3. Strip patch lines from the current file (last resort)
ORIG_ON_MMI="${MANAGE_CD}-ORIG"
BACKUPDIR="${SDPATH}/var/navunblocker-backup"

if [ -f "${ORIG_ON_MMI}" ]; then
    echo "[ACTI]  Restoring from on-MMI -ORIG backup..."
    cp -v "${ORIG_ON_MMI}" "${MANAGE_CD}"
    chmod 0777 "${MANAGE_CD}"
    touch -r "${ORIG_ON_MMI}" "${MANAGE_CD}"
    rm -v "${ORIG_ON_MMI}"
    echo "[OK]    Restored from ${ORIG_ON_MMI}"
elif [ -f "${BACKUPDIR}/manage_cd.sh.original" ]; then
    echo "[ACTI]  Restoring manage_cd.sh from SD-side backup..."
    cp -v "${BACKUPDIR}/manage_cd.sh.original" "${MANAGE_CD}"
    chmod 0777 "${MANAGE_CD}"
    echo "[OK]    Restored from SD card backup"
else
    # No backup — strip the patch lines we know we appended
    echo "[INFO]  No backup found (neither on-MMI nor on SD)"
    echo "[ACTI]  Attempting to strip patch lines from manage_cd.sh..."

    if [ -f "${MANAGE_CD}" ]; then
        grep -v "acios_db.ini" "${MANAGE_CD}" | \
        grep -v "MMI3G NavUnblocker patch" | \
        grep -v "MMI3G-Toolkit Nav Unblocker" | \
        grep -v "Disables H-B nav database" | \
        grep -v "Installed:" > "${MANAGE_CD}.clean"

        mv "${MANAGE_CD}.clean" "${MANAGE_CD}"
        chmod 0777 "${MANAGE_CD}"
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
