#!/bin/ksh
# ============================================================
# MMI3G System Information Reporter
# One-shot comprehensive dump of MMI system state to SD card
# ============================================================
#
# This module does NOT install anything to flash. It runs on
# SD insert, collects system data, writes it to the SD card,
# and you're done. Safe and non-destructive.
#
# Inspired by DrGER2/MMI3G-Info (mmi3ginfo3)
#
# Output: var/sysinfo-YYYYMMDD-HHMMSS.txt on SD card
# ============================================================

SDPATH="${1:-$(dirname $0)}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTDIR="${SDPATH}/var/sysinfo"
OUTFILE="${OUTDIR}/sysinfo-${TIMESTAMP}.txt"

mkdir -p ${OUTDIR}

# Also capture individual files for easy parsing
FILESDIR="${OUTDIR}/${TIMESTAMP}"
mkdir -p ${FILESDIR}

{
echo "################################################################"
echo "#  MMI3G-Toolkit System Information Report"
echo "#  Generated: $(date)"
echo "#  Host: $(hostname 2>/dev/null || echo 'unknown')"
echo "################################################################"
echo ""

# === IDENTITY ===
echo "================================================================"
echo "  1. SYSTEM IDENTITY"
echo "================================================================"
echo ""

echo "--- Software Train ---"
TRAIN="$(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo "Train: ${TRAIN:-unknown}"
echo ""

echo "--- MMI Variant Detection ---"
if echo "$TRAIN" | grep -qi "HN+R"; then
    echo "Variant: MMI 3G+ with RSE (HN+R)"
elif echo "$TRAIN" | grep -qi "HN+"; then
    echo "Variant: MMI 3G+ (HN+)"
elif echo "$TRAIN" | grep -qi "HNav\|HN_\|BNav"; then
    echo "Variant: MMI 3G High (HNav)"
elif echo "$TRAIN" | grep -qi "RNS\|MU9478"; then
    echo "Variant: VW RNS-850"
else
    echo "Variant: Unknown ($TRAIN)"
fi
echo ""

echo "--- System Uptime ---"
uptime 2>/dev/null || echo "uptime: not available"
echo ""

# === FIRMWARE ===
echo "================================================================"
echo "  2. FIRMWARE & SOFTWARE VERSIONS"
echo "================================================================"
echo ""

echo "--- QNX Version ---"
uname -a 2>/dev/null || echo "uname: not available"
echo ""

echo "--- Software Train File ---"
cat /dev/shmem/sw_trainname.txt 2>/dev/null
echo ""

echo "--- MU Version Files ---"
for f in /mnt/efs-system/etc/sw_version*.txt /mnt/efs-system/etc/mu_version*.txt; do
    if [ -f "$f" ]; then
        echo "[$f]:"
        cat "$f" 2>/dev/null
        echo ""
    fi
done

echo "--- ifs-root Build Info ---"
if [ -f "/etc/build" ]; then
    cat /etc/build 2>/dev/null
fi
echo ""

# === HARDWARE ===
echo "================================================================"
echo "  3. HARDWARE & MEMORY"
echo "================================================================"
echo ""

echo "--- System Info (pidin info) ---"
pidin info 2>/dev/null || echo "pidin: not available"
echo ""

echo "--- CPU Info ---"
pidin -fA 2>/dev/null | head -3
echo ""

# === STORAGE ===
echo "================================================================"
echo "  4. STORAGE & FILESYSTEMS"
echo "================================================================"
echo ""

echo "--- Mount Points ---"
mount 2>/dev/null
echo ""

echo "--- Disk Usage ---"
df -h 2>/dev/null || df -k 2>/dev/null
echo ""

echo "--- HDD Devices ---"
ls -la /dev/hd0* 2>/dev/null || echo "No /dev/hd0 devices found"
echo ""

echo "--- SD Card Slots ---"
ls -la /dev/sdcard* 2>/dev/null || echo "No sdcard devices found"
echo ""

echo "--- SD Card Mounts ---"
mount | grep sdcard 2>/dev/null || echo "No SD cards mounted"
echo ""

# === NAVIGATION ===
echo "================================================================"
echo "  5. NAVIGATION DATABASE"
echo "================================================================"
echo ""

echo "--- Nav HDD Partition ---"
if mount | grep -q "/mnt/nav"; then
    echo "STATUS: /mnt/nav mounted"
    df -h /mnt/nav 2>/dev/null
else
    echo "STATUS: /mnt/nav not mounted"
fi
echo ""

echo "--- acios_db.ini ---"
if [ -f "/mnt/lvm/acios_db.ini" ]; then
    echo "STATUS: EXISTS"
    cat /mnt/lvm/acios_db.ini 2>/dev/null
elif [ -f "/mnt/efs-persist/navi/db/acios_db.ini" ]; then
    echo "STATUS: EXISTS (efs-persist)"
    cat /mnt/efs-persist/navi/db/acios_db.ini 2>/dev/null
else
    echo "STATUS: NOT FOUND"
fi
echo ""

echo "--- Nav Database PKG ---"
for pkg in /mnt/nav/db/pkgdb/PKG/*.pkg /mnt/nav/db/pkgdb/*.PKG; do
    if [ -f "$pkg" ]; then
        echo "PKG: $pkg"
        head -20 "$pkg" 2>/dev/null
        echo ""
    fi
done
ls /mnt/nav/db/pkgdb/ 2>/dev/null || echo "No pkgdb directory"
echo ""

echo "--- FSC Files ---"
ls -la /mnt/efs-persist/FSC/ 2>/dev/null || echo "No FSC directory"
echo ""

echo "--- Nav Unblocker Status ---"
MANAGE_CD="/mnt/efs-system/usr/bin/manage_cd.sh"
if [ -f "${MANAGE_CD}" ]; then
    if grep -q "acios_db.ini" "${MANAGE_CD}" 2>/dev/null; then
        echo "manage_cd.sh: PATCHED (DrGER2 unblocker)"
    else
        echo "manage_cd.sh: FACTORY (not patched)"
    fi
fi
if [ -f "/mnt/efs-system/sbin/mme-becker.sh" ]; then
    if grep -q "acios_db.ini" "/mnt/efs-system/sbin/mme-becker.sh" 2>/dev/null; then
        echo "mme-becker.sh: PATCHED (legacy Keldo/Vlasoff)"
    fi
fi
echo ""

echo "--- vdev-logvolmgr ---"
pidin -fNA 2>/dev/null | grep vdev-logvolmgr || echo "NOT RUNNING"
echo ""

# === NETWORK ===
echo "================================================================"
echo "  6. NETWORK & CONNECTIVITY"
echo "================================================================"
echo ""

echo "--- Network Interfaces ---"
ifconfig -a 2>/dev/null || echo "ifconfig: not available"
echo ""

echo "--- Routing Table ---"
netstat -rn 2>/dev/null || echo "netstat: not available"
echo ""

echo "--- DNS Configuration ---"
cat /etc/resolv.conf 2>/dev/null || echo "No resolv.conf"
echo ""

echo "--- Active Connections ---"
netstat -an 2>/dev/null | head -30
echo ""

echo "--- ARP Table ---"
arp -a 2>/dev/null || echo "arp: not available"
echo ""

# === GEM ===
echo "================================================================"
echo "  7. GREEN ENGINEERING MENU"
echo "================================================================"
echo ""

echo "--- engdefs Directory ---"
if [ -d "/mnt/efs-system/engdefs" ]; then
    echo "STATUS: EXISTS"
    ls -la /mnt/efs-system/engdefs/*.esd 2>/dev/null
else
    echo "STATUS: NOT FOUND (GEM may not be enabled)"
fi
echo ""

echo "--- AppDevelopment.jar ---"
ls -la /mnt/efs-system/lsd/AppDevelopment.jar 2>/dev/null || echo "NOT FOUND"
echo ""

echo "--- Custom Scripts ---"
if [ -d "/mnt/efs-system/scripts" ]; then
    echo "Installed scripts:"
    ls -laR /mnt/efs-system/scripts/ 2>/dev/null
else
    echo "No custom scripts directory"
fi
echo ""

# === SPLASH SCREENS ===
echo "================================================================"
echo "  8. SPLASH SCREENS"
echo "================================================================"
echo ""

if [ -d "/mnt/efs-system/etc/splashscreens" ]; then
    ls -la /mnt/efs-system/etc/splashscreens/ 2>/dev/null
    echo ""
    echo "--- StartupImageConfig.txt ---"
    cat /mnt/efs-system/etc/splashscreens/StartupImageConfig.txt 2>/dev/null
else
    echo "Splash screen directory not found"
fi
echo ""

# === USB ===
echo "================================================================"
echo "  9. USB DEVICES"
echo "================================================================"
echo ""

usb 2>/dev/null || echo "usb command: not available"
echo ""

echo "--- USB Mass Storage ---"
ls -la /dev/umass* 2>/dev/null || echo "No USB mass storage"
echo ""

# === PROCESSES ===
echo "================================================================"
echo "  10. RUNNING PROCESSES"
echo "================================================================"
echo ""

pidin -fNapb 2>/dev/null || echo "pidin: not available"
echo ""

# === SYSLOG ===
echo "================================================================"
echo "  11. SYSTEM LOG (last 200 lines)"
echo "================================================================"
echo ""

sloginfo 2>/dev/null | tail -200

echo ""
echo "################################################################"
echo "#  End of System Information Report"
echo "#  Saved to: ${OUTFILE}"
echo "################################################################"

} > ${OUTFILE} 2>&1

# --- Save individual data files for easy parsing ---
cat /dev/shmem/sw_trainname.txt > ${FILESDIR}/sw_train.txt 2>/dev/null
pidin info > ${FILESDIR}/pidin_info.txt 2>/dev/null
pidin -fNapb > ${FILESDIR}/processes.txt 2>/dev/null
mount > ${FILESDIR}/mounts.txt 2>/dev/null
df -h > ${FILESDIR}/disk_usage.txt 2>/dev/null
ifconfig -a > ${FILESDIR}/interfaces.txt 2>/dev/null
netstat -rn > ${FILESDIR}/routes.txt 2>/dev/null
cat /etc/resolv.conf > ${FILESDIR}/dns.txt 2>/dev/null
sloginfo > ${FILESDIR}/syslog.txt 2>/dev/null
ls -la /mnt/efs-system/engdefs/*.esd > ${FILESDIR}/gem_screens.txt 2>/dev/null
ls -la /mnt/efs-persist/FSC/ > ${FILESDIR}/fsc_files.txt 2>/dev/null
uname -a > ${FILESDIR}/uname.txt 2>/dev/null

# Copy manage_cd.sh and mmelauncher.cfg for inspection
cp /mnt/efs-system/usr/bin/manage_cd.sh ${FILESDIR}/ 2>/dev/null
cp /mnt/efs-system/etc/mmelauncher.cfg ${FILESDIR}/ 2>/dev/null

sync

echo ""
echo "============================================"
echo " System Information Report Complete"
echo " Main report: var/sysinfo/sysinfo-${TIMESTAMP}.txt"
echo " Raw files:   var/sysinfo/${TIMESTAMP}/"
echo " Safe to remove SD card."
echo "============================================"
