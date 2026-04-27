#!/bin/ksh
# ============================================================
# Nav Unblocker - Status Check
# Reports patch state and nav database activation status
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
LOGFILE="${SDPATH}/var/nav-status-$(mmi_logstamp).log"
EFSDIR="/mnt/efs-system"
MANAGE_CD="${EFSDIR}/usr/bin/manage_cd.sh"

{
echo "============================================"
echo " Nav Unblocker Status Report"
echo " $(date)"
echo " Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo "============================================"
echo ""

echo "--- manage_cd.sh Patch (DrGER2 method) ---"
if [ -f "${MANAGE_CD}" ]; then
    if grep -q "acios_db.ini" "${MANAGE_CD}" 2>/dev/null; then
        echo "STATUS: PATCHED (unblocker active)"
        echo ""
        echo "Patch lines in manage_cd.sh:"
        grep -n "acios_db\|slay\|Unblocker\|Keldo" "${MANAGE_CD}" 2>/dev/null
    else
        echo "STATUS: NOT PATCHED (factory default)"
    fi
else
    echo "STATUS: manage_cd.sh NOT FOUND (unexpected)"
fi
echo ""

echo "--- Legacy mme-becker.sh Patch ---"
if [ -f "${EFSDIR}/sbin/mme-becker.sh" ]; then
    if grep -q "acios_db.ini" "${EFSDIR}/sbin/mme-becker.sh" 2>/dev/null; then
        echo "STATUS: Legacy Keldo/Vlasoff patch PRESENT"
    else
        echo "STATUS: mme-becker.sh exists but NOT patched"
    fi
else
    echo "STATUS: No mme-becker.sh (normal for first install)"
fi
echo ""

echo "--- mmelauncher.cfg ---"
if [ -f "${EFSDIR}/etc/mmelauncher.cfg.pre-navdb.bak" ]; then
    echo "STATUS: Legacy backup found (mmelauncher was modified)"
elif [ -f "${EFSDIR}/etc/mmelauncher.cfg" ]; then
    if grep -q "mme-becker.sh" "${EFSDIR}/etc/mmelauncher.cfg" 2>/dev/null; then
        echo "STATUS: mmelauncher points to mme-becker.sh (legacy)"
    else
        echo "STATUS: Factory default (points to mme-becker binary)"
    fi
fi
echo ""

echo "--- FSC Files ---"
if [ -d "/mnt/efs-persist/FSC" ]; then
    FSCCOUNT=$(ls /mnt/efs-persist/FSC/*.fsc 2>/dev/null | wc -l)
    echo "FSC files found: ${FSCCOUNT}"
    ls -la /mnt/efs-persist/FSC/*.fsc 2>/dev/null
else
    echo "FSC directory not found"
fi
echo ""

echo "--- Nav Database ---"
if [ -f "/mnt/lvm/acios_db.ini" ]; then
    echo "acios_db.ini: EXISTS"
    echo "Contents (first 5 lines):"
    head -5 /mnt/lvm/acios_db.ini 2>/dev/null
else
    echo "acios_db.ini: NOT FOUND"
    echo "(Normal if vdev-logvolmgr was terminated by patch)"
fi
echo ""

echo "--- vdev-logvolmgr Process ---"
VLMGR=$(pidin -fNA 2>/dev/null | grep vdev-logvolmgr)
if [ -n "$VLMGR" ]; then
    echo "STATUS: RUNNING"
    echo "${VLMGR}"
else
    echo "STATUS: NOT RUNNING (expected if patch is active)"
fi
echo ""

echo "--- Nav HDD Partition ---"
if mount | grep -q "/mnt/nav"; then
    echo "STATUS: /mnt/nav is mounted"
    df -h /mnt/nav 2>/dev/null
else
    echo "STATUS: /mnt/nav not mounted"
fi
echo ""
echo "============================================"
} > ${LOGFILE} 2>&1

cat ${LOGFILE}
echo ""
echo "Report saved to: ${LOGFILE}"
