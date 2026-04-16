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

SDPATH="${1:-$(dirname $0)}"
LOGFILE="${SDPATH}/var/gem-cleanup-$(date +%Y%m%d-%H%M%S).log"
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
