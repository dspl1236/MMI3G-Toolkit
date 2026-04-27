#!/bin/ksh
# ============================================================
# Nav Database Unblocker - Restore / Uninstall
# Removes the manage_cd.sh patch, restoring factory activation
# ============================================================

# --- platform.sh (shared variant detection + getTime helper) ---
# Defines MMI_VARIANT / MMI_VARIANT_ID / MMI_TRAIN and mmi_logstamp().
# Must be sourced before any code that calls mmi_logstamp.
_SDPATH_GUESS="${SDPATH:-${0%/*}}"
if [ -f "${_SDPATH_GUESS}/scripts/common/platform.sh" ]; then
    . "${_SDPATH_GUESS}/scripts/common/platform.sh"
elif [ -f "/mnt/efs-system/scripts/common/platform.sh" ]; then
    . "/mnt/efs-system/scripts/common/platform.sh"
else
    # Inline minimal fallback (DrGER2 review corrections applied)
    MMI_VARIANT="UNKNOWN"; MMI_VARIANT_ID=""
    for _f in /etc/pci-3g_*.cfg; do
        [ -f "$_f" ] || continue
        MMI_VARIANT_ID="$(echo "$_f" | sed -n 's,^/etc/pci-3g_\([0-9]*\)\.cfg$,\1,p')"
        case "$MMI_VARIANT_ID" in
            9304) MMI_VARIANT="MMI3G_BASIC" ;;
            9308) MMI_VARIANT="MMI3G_HIGH" ;;
            9411|9436|9478) MMI_VARIANT="MMI3GP" ;;
        esac
        break
    done
    MMI_TRAIN="$(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
    [ -z "$MMI_TRAIN" ] && MMI_TRAIN="$(sloginfo -m 10000 -s 5 2>/dev/null | sed -n 's/^.* +++ Train //p' | sed -n 1p)"
    [ -z "$MMI_TRAIN" ] && MMI_TRAIN="n/a"
    if [ "$MMI_VARIANT" = "MMI3GP" ] && echo "$MMI_TRAIN" | grep -q "_VW_"; then
        MMI_VARIANT="RNS850"
    fi
    mmi_logstamp() {
        if command -v getTime >/dev/null 2>&1; then
            _T="$(getTime 2>/dev/null)"
            [ -n "$_T" ] && { date -r "$_T" +%Y%m%d-%H%M%S 2>/dev/null || echo "epoch-$_T"; return 0; }
        fi
        date +%Y%m%d-%H%M%S 2>/dev/null
    }
    mmi_getTime() {
        if command -v getTime >/dev/null 2>&1; then getTime 2>/dev/null; else date +%s 2>/dev/null; fi
    }
fi
# --- end platform.sh source ---

SDPATH="${1:-${0%/*}}"
LOGFILE="${SDPATH}/var/nav-restore-$(mmi_logstamp).log"
EFSDIR="/mnt/efs-system"
MANAGE_CD="${EFSDIR}/usr/bin/manage_cd.sh"

exec > ${LOGFILE} 2>&1

echo "============================================"
echo " Nav Unblocker - Restore Factory Activation"
echo " $(date)"
echo "============================================"
echo ""

# Hold F3S reclaim for the duration of this script (see research/F3S_FORMAT.md)
# Guarded: if platform.sh provided it, use it; otherwise inline the minimum.
if command -v mmi_reclaim_hold >/dev/null 2>&1; then
    mmi_reclaim_hold
else
    touch /tmp/disableReclaim 2>/dev/null
    trap 'rm -f /tmp/disableReclaim 2>/dev/null' EXIT INT TERM
fi

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
