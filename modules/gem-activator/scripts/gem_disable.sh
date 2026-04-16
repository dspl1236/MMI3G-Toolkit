#!/bin/ksh
# ============================================================
# GEM Infrastructure Cleanup
# Reverses the infrastructure setup performed by gem_enable.sh
# ============================================================
#
# IMPORTANT — READ THIS:
#
# This script does NOT disable the GEM enable flag. That flag
# lives in persistent adaptation data (module 5F, channel 6)
# and can only be cleared via VCDS, ODIS, or another diagnostic
# tool over the OBD-II port.
#
# What this script actually does:
#   1. Removes the legacy .gem_enabled marker file left by
#      earlier versions of this toolkit (harmless if absent).
#   2. Optionally removes custom screen definitions installed
#      by toolkit modules (gated — set FULL_CLEAN=1 to enable).
#
# To actually disable the GEM:
#   VCDS: address 5F -> Adaptation (10) -> channel 6 -> value 0
#   ODIS E17: same path.
# Reboot MMI to take effect. GEM key combo (CAR+BACK or
# CAR+SETUP) will no longer open the menu.
#
# ============================================================

# --- platform.sh (shared variant detection + getTime helper) ---
# Defines MMI_VARIANT / MMI_VARIANT_ID / MMI_TRAIN and mmi_logstamp().
# Must be sourced before any code that calls mmi_logstamp.
_SDPATH_GUESS="${SDPATH:-$(dirname $0)}"
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

SDPATH="${1:-$(dirname $0)}"
LOGFILE="${SDPATH}/var/gem-cleanup-$(mmi_logstamp).log"
EFSDIR="/mnt/efs-system"
FULL_CLEAN="${FULL_CLEAN:-0}"   # set to 1 in env to also purge toolkit screens

mkdir -p "$(dirname ${LOGFILE})" 2>/dev/null
exec > ${LOGFILE} 2>&1

echo "============================================"
echo " GEM Infrastructure Cleanup"
echo " $(date)"
echo "============================================"
echo ""

mount -uw ${EFSDIR}
if [ $? -ne 0 ]; then
    echo "[ERROR] mount -uw failed on ${EFSDIR}"
    exit 1
fi

# Remove legacy marker from old gem_enable.sh versions (harmless placebo)
LEGACY_MARKER="${EFSDIR}/engdefs/.gem_enabled"
if [ -f "${LEGACY_MARKER}" ]; then
    rm -v "${LEGACY_MARKER}"
    echo "[OK]    Removed legacy marker (was a no-op placebo, safe to delete)"
fi

if [ "${FULL_CLEAN}" = "1" ]; then
    echo ""
    echo "[INFO]  FULL_CLEAN=1 — removing toolkit screen definitions"
    echo "[INFO]  (Run core/uninstall.sh for the full module-aware cleanup)"
    # Narrow globs — only toolkit-owned prefixes, not any .esd Audi shipped
    for pattern in \
        "Gauges*.esd" \
        "SystemInfo*.esd" \
        "Scanner*.esd" \
        "Coding*.esd" \
        "GamesMenu*.esd" \
        "MapParser*.esd" \
        "NavUnblocker*.esd" \
        "PasswordFinder*.esd" \
        "Splash*.esd" \
        "VariantDump*.esd" \
        "LTE*.esd" \
        "JVMExtract*.esd" \
        "DiagTool*.esd"
    do
        for f in ${EFSDIR}/engdefs/${pattern}; do
            [ -f "${f}" ] && rm -v "${f}"
        done
    done
fi

sync
mount -ur ${EFSDIR} 2>/dev/null

echo ""
echo "============================================"
echo " Cleanup complete"
echo ""
echo " To actually disable GEM (so CAR+BACK does nothing):"
echo "   VCDS: address 5F -> Adaptation -> channel 6 -> value 0"
echo "   Reboot MMI after saving."
echo ""
echo " Log: ${LOGFILE}"
echo "============================================"
