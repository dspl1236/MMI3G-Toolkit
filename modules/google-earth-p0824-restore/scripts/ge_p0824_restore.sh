#!/bin/ksh

_SDPATH_GUESS="${SDPATH:-$(dirname $0)}"
if [ -f "${_SDPATH_GUESS}/scripts/common/platform.sh" ]; then
    . "${_SDPATH_GUESS}/scripts/common/platform.sh"
elif [ -f "/mnt/efs-system/scripts/common/platform.sh" ]; then
    . "/mnt/efs-system/scripts/common/platform.sh"
fi

SDPATH="${1:-${_SDPATH_GUESS}}"
TS=$(date +%H%M%S 2>/dev/null || echo "000000")
if command -v mmi_logstamp >/dev/null 2>&1; then TS="$(mmi_logstamp)"; fi

OUTDIR="${SDPATH}/var/google-earth"
LOG="${OUTDIR}/ge-p0824-restore-${TS}.log"
mkdir -p "${OUTDIR}" 2>/dev/null

NAVDIR="/mnt/nav"
STATE_ROOT="${NAVDIR}/.mmi3g_toolkit/google-earth-p0824"
ACTIVE_META="${STATE_ROOT}/active.env"
GEMMI_TARGET="${NAVDIR}/gemmi"

exec > "${LOG}" 2>&1

echo "============================================"
echo " Google Earth P0824 Donor Restore"
echo " $(date)"
echo " Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo "============================================"
echo ""

if [ ! -f "${ACTIVE_META}" ]; then
    echo "[INFO] No active deploy metadata found at ${ACTIVE_META}"
    echo "       Nothing to restore."
    exit 0
fi

. "${ACTIVE_META}"

if [ "${BACKUP_STATE}" = "present" ] && [ ! -d "${BACKUP_PATH}" ]; then
    echo "[ERROR] Expected backup directory missing: ${BACKUP_PATH}"
    echo "       Refusing to remove ${TARGET}"
    exit 1
fi

mount -uw "${NAVDIR}" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to remount ${NAVDIR} read-write"
    exit 1
fi
echo "[OK] ${NAVDIR} remounted rw"

if [ -d "${TARGET}" ]; then
    echo "[RESTORE] Removing current ${TARGET}"
    rm -rf "${TARGET}"
fi

if [ "${BACKUP_STATE}" = "present" ]; then
    echo "[RESTORE] Restoring ${BACKUP_PATH} -> ${TARGET}"
    cp -R "${BACKUP_PATH}" "${TARGET}"
    if [ ! -d "${TARGET}" ]; then
        echo "[ERROR] Restore copy failed"
        exit 1
    fi
    echo "[OK] Previous GEMMI tree restored"
else
    echo "[OK] Previous state was 'absent'; ${TARGET} removed"
fi

rm -f "${ACTIVE_META}"
sync 2>/dev/null

echo ""
echo "============================================"
echo " Restore Summary"
echo "============================================"
echo " Target: ${TARGET}"
echo " Backup: ${BACKUP_STATE} ${BACKUP_PATH}"
echo ""
echo " Reboot required before retesting."
echo "============================================"
