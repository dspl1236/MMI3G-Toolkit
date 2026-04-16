#!/bin/ksh
# ============================================================
# GEM Status Check - Report GEM activation state
# Non-destructive - reads only, changes nothing
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
            9411|9478) MMI_VARIANT="MMI3GP" ;;
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
LOGFILE="${SDPATH}/var/gem-status-$(mmi_logstamp).log"
EFSDIR="/mnt/efs-system"

{
echo "============================================"
echo " GEM Status Report"
echo " $(date)"
echo " Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo "============================================"
echo ""

echo "--- engdefs Directory ---"
if [ -d "${EFSDIR}/engdefs" ]; then
    echo "EXISTS: ${EFSDIR}/engdefs/"
    echo "Screen definitions:"
    ls -la ${EFSDIR}/engdefs/*.esd 2>/dev/null || echo "  (none found)"
else
    echo "NOT FOUND: ${EFSDIR}/engdefs/"
    echo "GEM is likely NOT enabled"
fi
echo ""

echo "--- AppDevelopment.jar ---"
if [ -f "${EFSDIR}/lsd/AppDevelopment.jar" ]; then
    echo "EXISTS: $(ls -la ${EFSDIR}/lsd/AppDevelopment.jar)"
else
    echo "NOT FOUND — GEM Java archive missing from firmware"
fi
echo ""

echo "--- Legacy marker file (old gem_enable.sh left this; it's a no-op) ---"
LEGACY_MARKER="${EFSDIR}/engdefs/.gem_enabled"
if [ -f "${LEGACY_MARKER}" ]; then
    echo "PRESENT (harmless placebo — ignore, or let gem_disable.sh remove it)"
else
    echo "Not present"
fi
echo ""

echo "--- GEM enable bit (adaptation 5F channel 6) ---"
echo "This value lives in persistent adaptation data on module 5F and"
echo "cannot be read from the MMI's SD-script environment — the QNX"
echo "system on the head unit does not ship a UDS client binary."
echo "Use VCDS (address 5F -> Adaptation -> channel 6) to read it."
echo ""

echo "--- Scripts Directory ---"
if [ -d "${EFSDIR}/scripts" ]; then
    echo "Custom scripts installed:"
    ls -laR ${EFSDIR}/scripts/ 2>/dev/null
else
    echo "No custom scripts directory found"
fi
echo ""

echo "--- Key Combo Hint ---"
TRAIN="$(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
if echo "$TRAIN" | grep -qi "HN+"; then
    echo "MMI 3G+ detected — try: CAR + BACK (hold 5 sec)"
else
    echo "MMI 3G/other — try: CAR + SETUP (hold 5 sec)"
fi
echo ""
echo "============================================"
} > ${LOGFILE} 2>&1

# Also output to console (visible in GEM if run from there)
cat ${LOGFILE}
echo ""
echo "Report saved to: ${LOGFILE}"
