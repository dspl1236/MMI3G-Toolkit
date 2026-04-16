#!/bin/ksh
# ============================================================
# GEM Status Check - Report GEM activation state
# Non-destructive - reads only, changes nothing
# ============================================================

SDPATH="${1:-$(dirname $0)}"
LOGFILE="${SDPATH}/var/gem-status-$(date +%Y%m%d-%H%M%S).log"
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
