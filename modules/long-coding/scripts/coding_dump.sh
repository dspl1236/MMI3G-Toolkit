#!/bin/ksh
# ============================================================
# Coding Context Dump
# Writes a context report to the SD card: MMI identification,
# installed coding screens, and instructions for reading actual
# adaptation values.
# ============================================================
#
# WHY THIS DOES NOT DUMP ADAPTATION VALUES:
#
# The per3 / keyValue namespace where adaptation values live
# (car-device list 0x00100000-0x0010003F, CAN-assignment
# 0x00140000-0x001400FF, etc.) is only readable through the
# DSI persistence API. That API is Java-only and IPC-based —
# a shell script on the MMI cannot call it.
#
# The long-coding module's GEM SCREENS (CodingMain.esd,
# CodingCarConfig.esd, CodingBusRouting.esd) do work, because
# they render inside the J9 Java VM which speaks DSI natively.
# Open them from the GEM after activating this module.
#
# This script instead captures the context around a coding
# session: identifier info, what screens are installed, and
# whether the vehicle has been modified (unblocker patch,
# engineering menu status).
#
# ============================================================

SDPATH="${1:-/fs/sda1}"
for sd in /fs/sda1 /fs/sda0 /fs/sd1 /fs/sd0; do
    [ -d "$sd" ] && SDPATH="$sd" && break
done

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTDIR="${SDPATH}/var/coding"
OUTFILE="${OUTDIR}/coding-context-${TIMESTAMP}.txt"
mkdir -p ${OUTDIR} 2>/dev/null

{
echo "################################################################"
echo "#  MMI3G Long-Coding Context Report"
echo "#  Generated: $(date)"
echo "################################################################"
echo ""
echo "This report captures the context around a coding session."
echo "It does NOT contain the actual per3 adaptation values —"
echo "those are only readable through the GEM screens installed"
echo "by this module (they run in Java and can hit the DSI"
echo "persistence namespace directly)."
echo ""

# ---------- Identification ----------
echo "================================================================"
echo "  VEHICLE / MMI IDENTIFICATION"
echo "================================================================"

TRAIN="$(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
printf "  %-32s %s\n" "Train name:" "${TRAIN:-n/a}"

MU_VERSION="$(sed -n 's/^version = //p' /etc/version/MainUnit-version.txt 2>/dev/null | head -1)"
printf "  %-32s %s\n" "MU software version:" "${MU_VERSION:-n/a}"

MU_VARIANT="$(sed -n 's,^<VariantName>,,;s,</VariantName>\r\?$,,p' /etc/mmi3g-srv-starter.cfg 2>/dev/null | head -1)"
printf "  %-32s %s\n" "MU variant:" "${MU_VARIANT:-n/a}"

HW_SAMPLE="$([ -f /etc/hwSample ] && cat /etc/hwSample 2>/dev/null)"
printf "  %-32s %s\n" "MU hwSample:" "${HW_SAMPLE:-n/a}"

echo ""

# ---------- Installed coding screens ----------
echo "================================================================"
echo "  INSTALLED LONG-CODING GEM SCREENS"
echo "================================================================"
COUNT=0
for f in /mnt/efs-system/engdefs/Coding*.esd; do
    if [ -f "$f" ]; then
        SIZE=$(ls -la "$f" | awk '{print $5}')
        printf "  %-50s %s bytes\n" "$(basename $f)" "$SIZE"
        COUNT=$((COUNT + 1))
    fi
done
if [ $COUNT -eq 0 ]; then
    echo "  No Coding*.esd screens found."
    echo "  Run coding_install.sh first to install them."
fi
echo ""

# ---------- Engineering menu state ----------
echo "================================================================"
echo "  GEM / ENGINEERING MENU STATE"
echo "================================================================"
if [ -d /mnt/efs-system/engdefs ]; then
    ESDCOUNT=$(ls /mnt/efs-system/engdefs/*.esd 2>/dev/null | wc -l)
    printf "  %-32s %s files\n" "engdefs/ screens total:" "$ESDCOUNT"
else
    echo "  engdefs/ not present — GEM infrastructure missing"
fi

if [ -f /mnt/efs-system/lsd/AppDevelopment.jar ]; then
    JARSIZE=$(ls -la /mnt/efs-system/lsd/AppDevelopment.jar | awk '{print $5}')
    printf "  %-32s %s bytes\n" "AppDevelopment.jar:" "$JARSIZE"
else
    echo "  AppDevelopment.jar NOT FOUND — GEM cannot render"
fi
echo ""

# ---------- Nav unblocker state ----------
echo "================================================================"
echo "  NAV UNBLOCKER STATE (affects what coding changes stick)"
echo "================================================================"
if grep -q 'acios_db.ini' /usr/bin/manage_cd.sh 2>/dev/null; then
    echo "  LVM unblocker patch:  PRESENT (manage_cd.sh method)"
elif [ -f /etc/mmelauncher.cfg ] && grep -q 'mme-becker.sh' /etc/mmelauncher.cfg 2>/dev/null; then
    echo "  LVM unblocker patch:  PRESENT (legacy Keldo/Vlasoff method)"
else
    echo "  LVM unblocker patch:  not present"
fi
echo ""

# ---------- Instructions ----------
echo "================================================================"
echo "  HOW TO READ AND CHANGE ADAPTATION VALUES"
echo "================================================================"
echo ""
echo "  1. READ current values:"
echo "       Open the GEM (CAR + BACK on 3G+, CAR + SETUP on 3G High)"
echo "       Navigate to /coding (the screens this module installs)."
echo "       Screens use DSI keyValue bindings so values are live."
echo ""
echo "  2. CHANGE values (safely):"
echo "       Use VCDS or ODIS — address 5F (Information Electr.),"
echo "       Adaptation (10). The channel number maps to the per3"
echo "       address: channel N is at 0x001000<N> for car-device"
echo "       or 0x0014<addr> for CAN-assignment (see"
echo "       research/PER3_ADDRESS_MAP.md)."
echo ""
echo "  3. CONFIRM changes:"
echo "       Re-run this script and re-open the coding GEM screens"
echo "       after rebooting the MMI."
echo ""

echo "################################################################"
echo "# Report written to: ${OUTFILE}"
echo "################################################################"

} > ${OUTFILE} 2>&1

echo "Coding context report written."
echo "Output: ${OUTFILE}"
echo ""
echo "For actual per3 adaptation values, open the coding screens"
echo "in the GEM (under /coding)."
sync
