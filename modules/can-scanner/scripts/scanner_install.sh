#!/bin/ksh
# ============================================================
# MMI3G CAN / Namespace Address Scanner
# Discovers available data in GEM key-value address space
# ============================================================
#
# HOW IT WORKS:
#
# The GEM .esd format uses "keyValue value int per X 0xADDR" to
# read values from the MMI's internal namespace. Per 3 carries
# CAN bus / vehicle data, Per 1 carries MMI system data, and
# Per 7 carries GPS data.
#
# The problem: nobody has published a complete address map for
# the per 3 namespace. We know a few addresses work (battery
# voltage at 0x00000023), but RPM, boost, coolant temp, oil
# temp, speed — those addresses are unknown.
#
# This script generates a set of GEM scanner screens that
# probe address ranges systematically. Each screen shows 10
# addresses with 500ms polling. You open each screen in the
# GEM, wait a few seconds, and the script logs which addresses
# return non-zero values.
#
# APPROACH:
# 1. Install scanner .esd screens to engdefs
# 2. Install the logger script
# 3. Open GEM > /scanner > each sub-screen
# 4. For each screen, hit the "Log This Page" button
# 5. Results are saved to SD card
#
# The logger script uses sloginfo to capture what the GEM JVM
# reads from the namespace, and also reads /dev/shmem for any
# CAN data that may be memory-mapped.
#
# After scanning, review the results to build a custom gauges
# screen with only the addresses that return live data on your
# specific vehicle.
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
LOGFILE="${SDPATH}/var/scanner-install-$(mmi_logstamp).log"
EFSDIR="/mnt/efs-system"
ENGDEFS="${EFSDIR}/engdefs"
SCRIPTDIR="${EFSDIR}/scripts/Scanner"

exec > ${LOGFILE} 2>&1

echo "============================================"
echo " CAN / Namespace Address Scanner - Installer"
echo " $(date)"
echo " Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo "============================================"
echo ""

# --- Verify environment ---
if [ ! -d "${ENGDEFS}" ]; then
    echo "[ERROR] engdefs not found. Enable GEM first!"
    exit 1
fi

mount -uw ${EFSDIR}
mkdir -p ${SCRIPTDIR}

# --- Install scanner screens ---
echo "[ACTI]  Installing scanner GEM screens..."

if [ -d "${SDPATH}/engdefs" ]; then
    for esd in ${SDPATH}/engdefs/Scanner*.esd; do
        if [ -f "$esd" ]; then
            BASENAME=$(basename $esd)
            cp -v "$esd" "${ENGDEFS}/${BASENAME}"
            echo "[INST]  $BASENAME"
        fi
    done
fi

# --- Install logger script ---
echo "[ACTI]  Installing scanner logger script..."
if [ -f "${SDPATH}/scripts/scan_log.sh" ]; then
    cp -v "${SDPATH}/scripts/scan_log.sh" "${SCRIPTDIR}/scan_log.sh"
    chmod +x "${SCRIPTDIR}/scan_log.sh"
    echo "[INST]  scan_log.sh"
fi

if [ -f "${SDPATH}/scripts/scan_shmem.sh" ]; then
    cp -v "${SDPATH}/scripts/scan_shmem.sh" "${SCRIPTDIR}/scan_shmem.sh"
    chmod +x "${SCRIPTDIR}/scan_shmem.sh"
    echo "[INST]  scan_shmem.sh"
fi

sync

echo ""
echo "============================================"
echo " Scanner Installed!"
echo ""
echo " HOW TO USE:"
echo "   1. Reboot MMI"
echo "   2. Open GEM (CAR + BACK)"
echo "   3. Navigate to /scanner"
echo "   4. Open each sub-screen (per3_0x0000, etc.)"
echo "   5. Watch for non-zero values — those are live data"
echo "   6. Hit 'Log Results' on each page to save to SD"
echo "   7. Check SD: var/scanner/ for results"
echo ""
echo " Known live addresses (for reference):"
echo "   per 3 0x00000023 = Terminal 30 voltage"
echo "   per 3 0x00120004 = SW train name"
echo "   per 7 0x000200bb = GPS sats used"
echo "   per 7 0x000200bc = GPS sats visible"
echo "   per 1 0x00180000 = USB device count"
echo ""
echo " After scanning, the results will tell us which"
echo " addresses carry RPM, speed, boost, coolant, etc."
echo "============================================"
