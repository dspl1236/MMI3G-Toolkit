#!/bin/ksh
# ============================================================
# GEM Infrastructure Setup
# For MMI 3G High, MMI 3G+, and RNS-850
# ============================================================
#
# IMPORTANT — READ THIS:
#
# This script does NOT enable the Green Engineering Menu by
# itself. There is no known SD-script method to set the GEM
# enable flag. That flag lives in persistent adaptation data
# on module 5F (Information Electronics), channel 6, and it
# can only be written via UDS — i.e. using VCDS, ODIS, or an
# equivalent diagnostic tool over the OBD-II port.
#
# What this script actually does:
#   1. Ensures /mnt/efs-system/engdefs/ exists (the directory
#      the GEM Java applet reads screen definitions from).
#   2. Verifies AppDevelopment.jar is present — without it,
#      the GEM cannot render even if the enable bit is set.
#   3. Reports what it found and what you need to do next.
#
# If you already ran a VCDS/ODIS adaptation on 5F channel 6
# and GEM opens with CAR+BACK (or CAR+SETUP) but no custom
# screens appear, this script makes sure the engdefs/ path
# is ready for the screens other modules install.
#
# --------------------------------------------------------
# How to actually enable GEM (one-time, with VCDS or ODIS):
# --------------------------------------------------------
#   VCDS:
#     Module 5F (Information Electr.)
#     → Adaptation (10)
#     → Channel 6
#     → Value 1
#     → Save
#     Reboot MMI. Now CAR+BACK (MMI 3G+) or CAR+SETUP (3G
#     High) opens the GEM.
#
#   ODIS E17:
#     Same path. Address word 5F, adaptation 10, channel 6.
#
# ============================================================

SDPATH="${1:-$(dirname $0)}"
EFSDIR="/mnt/efs-system"

# Source shared platform helper (with inline fallback)
if [ -f "${SDPATH}/scripts/common/platform.sh" ]; then
    . "${SDPATH}/scripts/common/platform.sh"
else
    MMI_VARIANT="UNKNOWN"
    for f in /etc/pci-3g_*.cfg; do
        [ -f "$f" ] || continue
        VID="$(echo "$f" | sed -n 's,^/etc/pci-3g_\([0-9]*\)\.cfg$,\1,p')"
        case "$VID" in
            9304) MMI_VARIANT="MMI3G_BASIC" ;;
            9308) MMI_VARIANT="MMI3G_HIGH" ;;
            9411|9436|9478) MMI_VARIANT="MMI3GP" ;;
        esac
        break
    done
    MMI_TRAIN="$(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
    [ -z "$MMI_TRAIN" ] && MMI_TRAIN="$(sloginfo -m 10000 -s 5 2>/dev/null | sed -n 's/^.* +++ Train //p' | sed -n 1p)"
    if [ "$MMI_VARIANT" = "MMI3GP" ] && echo "$MMI_TRAIN" | grep -q "_VW_"; then
        MMI_VARIANT="RNS850"
    fi
    mmi_logstamp() {
        if command -v getTime >/dev/null 2>&1; then
            T="$(getTime 2>/dev/null)"
            [ -n "$T" ] && { date -r "$T" +%Y%m%d-%H%M%S 2>/dev/null || echo "epoch-$T"; return 0; }
        fi
        date +%Y%m%d-%H%M%S 2>/dev/null
    }
fi

LOGFILE="${SDPATH}/var/gem-setup-$(mmi_logstamp).log"

# Make the log dir in case /var doesn't exist on this SD layout
mkdir -p "$(dirname ${LOGFILE})" 2>/dev/null
exec > ${LOGFILE} 2>&1

echo "============================================"
echo " GEM Infrastructure Setup"
echo " $(date) [QNX date — may be since-boot]"
echo " Variant: ${MMI_VARIANT}"
echo " Train:   ${MMI_TRAIN:-n/a}"
echo "============================================"
echo ""

# Key combo for the summary at the end
case "$MMI_VARIANT" in
    MMI3GP)        KEYCOMBO="CAR + BACK (hold ~5s)" ;;
    MMI3G_HIGH)    KEYCOMBO="CAR + SETUP (hold ~5s)" ;;
    MMI3G_BASIC)   KEYCOMBO="CAR + SETUP (hold ~5s)" ;;
    RNS850)        KEYCOMBO="CAR + SETUP (hold ~5s)" ;;
    *)             KEYCOMBO="CAR + BACK or CAR + SETUP (hold ~5s)" ;;
esac

# --- Remount efs-system read-write ---
echo "[STEP]  Remounting ${EFSDIR} rw..."
# Hold F3S reclaim for the duration of this script (see research/F3S_FORMAT.md)
# Guarded: if platform.sh provided it, use it; otherwise inline the minimum.
if command -v mmi_reclaim_hold >/dev/null 2>&1; then
    mmi_reclaim_hold
else
    touch /tmp/disableReclaim 2>/dev/null
    trap 'rm -f /tmp/disableReclaim 2>/dev/null' EXIT INT TERM
fi

mount -uw ${EFSDIR}
if [ $? -ne 0 ]; then
    echo "[ERROR] mount -uw failed on ${EFSDIR}"
    echo "[ERROR] Cannot proceed. Abort."
    exit 1
fi
echo "[OK]    ${EFSDIR} remounted rw"
echo ""

# --- Step 1: engdefs/ directory ---
echo "[STEP]  1/2 - engdefs directory"
if [ -d "${EFSDIR}/engdefs" ]; then
    ESDCOUNT=$(ls ${EFSDIR}/engdefs/*.esd 2>/dev/null | wc -l)
    echo "[OK]    ${EFSDIR}/engdefs/ exists (${ESDCOUNT} screen files)"
    ENGDEFS_OK=1
else
    mkdir -p ${EFSDIR}/engdefs
    if [ $? -eq 0 ]; then
        echo "[OK]    Created ${EFSDIR}/engdefs/"
        ENGDEFS_OK=1
    else
        echo "[ERROR] Could not create ${EFSDIR}/engdefs/"
        ENGDEFS_OK=0
    fi
fi
echo ""

# --- Step 2: AppDevelopment.jar check ---
echo "[STEP]  2/2 - GEM Java archive"
JAR_PATH=""
for candidate in \
    "${EFSDIR}/lsd/AppDevelopment.jar" \
    "${EFSDIR}/lsd/development/AppDevelopment.jar"
do
    if [ -f "${candidate}" ]; then
        JAR_PATH="${candidate}"
        break
    fi
done

if [ -n "${JAR_PATH}" ]; then
    JAR_SIZE=$(ls -la "${JAR_PATH}" | awk '{print $5}')
    echo "[OK]    Found: ${JAR_PATH} (${JAR_SIZE} bytes)"
    JAR_OK=1
else
    echo "[WARN]  AppDevelopment.jar not found under ${EFSDIR}/lsd/"
    echo "[WARN]  This JAR is part of the factory firmware."
    echo "[WARN]  If it is missing, GEM cannot render — reinstall"
    echo "[WARN]  the efs-system package from an original firmware ISO."
    JAR_OK=0
fi
echo ""

sync
mount -ur ${EFSDIR} 2>/dev/null

# --- Summary ---
echo "============================================"
echo " Infrastructure Setup Complete"
echo "============================================"
echo ""
echo " engdefs/        : $([ "$ENGDEFS_OK" = "1" ] && echo 'OK' || echo 'FAILED')"
echo " AppDevelopment  : $([ "$JAR_OK" = "1" ] && echo 'OK' || echo 'MISSING')"
echo ""
echo "------------------------------------------------------------"
echo " TO ACTUALLY ENABLE THE GEM (once, with a diagnostic tool):"
echo "------------------------------------------------------------"
echo ""
echo "   VCDS / VCP:"
echo "     Address 5F (Information Electr.)"
echo "     -> Adaptation (10)"
echo "     -> Channel 6"
echo "     -> New value: 1"
echo "     -> Save"
echo ""
echo "   ODIS E17:"
echo "     Same location — address 5F, adaptation 10, channel 6 = 1"
echo ""
echo "   After saving, reboot the MMI (hold MENU + knob + upper-"
echo "   right soft key) and open the GEM with: ${KEYCOMBO}"
echo ""
echo "   The SD-script workflow in this toolkit CANNOT set this"
echo "   flag — it lives in persistent adaptation data that is"
echo "   only writable over UDS (the OBD diagnostic protocol)."
echo ""
echo "------------------------------------------------------------"
echo " Log: ${LOGFILE}"
echo "============================================"
