#!/bin/ksh
# ============================================================
# Long-Coding Module Installer
# Installs ESD screens to MMI GEM menu
# ============================================================

SDPATH="${1:-$(dirname $0)}"
LOGFILE="${SDPATH}/var/coding-install-$(date +%Y%m%d-%H%M%S).log"
EFSDIR="/mnt/efs-system"
MODULEDIR=$(dirname "$0")/..

exec > ${LOGFILE} 2>&1

echo "============================================"
echo " Long-Coding Module Installer"
echo " $(date)"
echo " Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo "============================================"
echo ""

# Remount efs-system rw
echo "[ACTI] Remounting efs-system rw..."
mount -uw ${EFSDIR} 2>&1
if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to remount efs-system. Is it locked?"
    exit 1
fi

# Ensure engdefs dir exists (should be created by gem-activator)
if [ ! -d "${EFSDIR}/engdefs" ]; then
    mkdir -p ${EFSDIR}/engdefs
    echo "[INST] Created ${EFSDIR}/engdefs/"
fi

# Ensure scripts dir exists
mkdir -p ${EFSDIR}/scripts/Coding 2>/dev/null

# Copy ESD files
echo "[ACTI] Installing ESD screens..."
for esd in CodingMain.esd CodingCarConfig.esd CodingBusRouting.esd; do
    SRC="${MODULEDIR}/engdefs/${esd}"
    DST="${EFSDIR}/engdefs/${esd}"
    if [ -f "$SRC" ]; then
        cp "$SRC" "$DST"
        chmod 644 "$DST"
        echo "[OK]   Installed $esd"
    else
        echo "[WARN] Source not found: $SRC"
    fi
done

# Copy helper scripts
echo "[ACTI] Installing helper scripts..."
for script in coding_dump.sh coding_changelog.sh; do
    SRC="${MODULEDIR}/scripts/${script}"
    DST="${EFSDIR}/scripts/Coding/${script}"
    if [ -f "$SRC" ]; then
        cp "$SRC" "$DST"
        chmod 755 "$DST"
        echo "[OK]   Installed ${script}"
    else
        echo "[WARN] Source not found: $SRC"
    fi
done

# Remount ro
mount -ur ${EFSDIR}
sync

echo ""
echo "============================================"
echo " Long-Coding module installed!"
echo ""
echo " Access via Green Engineering Menu:"
echo "   CAR + BACK (C7) or CAR + SETUP (older)"
echo "   Navigate to: /coding"
echo ""
echo " Screens:"
echo "   CodingMain       - overview"
echo "   CodingCarConfig  - car device flags"
echo "   CodingBusRouting - CAN bus assignments"
echo ""
echo " Actions:"
echo "   Dump ALL codings to SD"
echo "   Show last 10 changes"
echo ""
echo " IMPORTANT: This is a READ-ONLY module."
echo " To CHANGE adaptation values, use VCDS"
echo " or ODIS. This module shows current state."
echo "============================================"
