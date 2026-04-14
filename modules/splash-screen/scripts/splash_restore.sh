#!/bin/ksh
# ============================================================
# Splash Screen Restore
# Restores factory default splash screens from backup
# ============================================================

SDPATH="${1:-$(dirname $0)}"
LOGFILE="${SDPATH}/var/splash-restore-$(date +%Y%m%d-%H%M%S).log"
EFSDIR="/mnt/efs-system"
SPLASHDIR="${EFSDIR}/etc/splashscreens"

exec > ${LOGFILE} 2>&1

echo "Splash Screen Restore"
echo "====================="

# Find the most recent backup
BACKUPDIR=$(ls -dt ${SDPATH}/var/splash-backup-* 2>/dev/null | head -1)
if [ -z "${BACKUPDIR}" ] || [ ! -d "${BACKUPDIR}" ]; then
    echo "[ERROR] No backup found in var/splash-backup-*/"
    echo "[ERROR] Run the installer first to create a backup"
    exit 1
fi

echo "[OK]    Using backup: ${BACKUPDIR}"

mount -uw ${EFSDIR}

echo "[ACTI]  Restoring splash screens..."
cp -v ${BACKUPDIR}/*.png ${SPLASHDIR}/ 2>/dev/null
cp -v ${BACKUPDIR}/*.txt ${SPLASHDIR}/ 2>/dev/null

sync
echo ""
echo "Restored. Reboot MMI to see original splash screen."
