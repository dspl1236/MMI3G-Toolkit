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
LOGFILE="${SDPATH}/var/gem-setup-$(date +%Y%m%d-%H%M%S).log"
EFSDIR="/mnt/efs-system"

# Make the log dir in case /var doesn't exist on this SD layout
mkdir -p "$(dirname ${LOGFILE})" 2>/dev/null
exec > ${LOGFILE} 2>&1

echo "============================================"
echo " GEM Infrastructure Setup"
echo " $(date)"
echo " Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo "============================================"
echo ""

# --- Detect MMI variant ---
TRAIN="$(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
if echo "$TRAIN" | grep -qi "HN+"; then
    VARIANT="MMI3GP"
    KEYCOMBO="CAR + BACK (hold ~5s)"
    echo "[INFO]  Detected MMI 3G+ (HN+)"
elif echo "$TRAIN" | grep -qi "HNav\|HN_"; then
    VARIANT="MMI3G"
    KEYCOMBO="CAR + SETUP (hold ~5s)"
    echo "[INFO]  Detected MMI 3G High (HNav)"
elif echo "$TRAIN" | grep -qi "RNS"; then
    VARIANT="RNS850"
    KEYCOMBO="CAR + SETUP (hold ~5s)"
    echo "[INFO]  Detected RNS-850"
else
    VARIANT="UNKNOWN"
    KEYCOMBO="CAR + BACK or CAR + SETUP (hold ~5s)"
    echo "[WARN]  Unknown train string: $TRAIN"
    echo "[WARN]  Proceeding with generic setup"
fi
echo ""

# --- Remount efs-system read-write ---
echo "[STEP]  Remounting ${EFSDIR} rw..."
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
