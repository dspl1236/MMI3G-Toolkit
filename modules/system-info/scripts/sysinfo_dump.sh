#!/bin/ksh
# ============================================================
# MMI3G-Toolkit — Comprehensive System Diagnostic
# Single-pass data gathering: system state, activations,
# backups, credentials, variant ID, and CAN/persistence state
#
# Runs entirely from SD card. No flash writes.
# Part of MMI3G-Toolkit: github.com/dspl1236/MMI3G-Toolkit
# ============================================================

SDPATH="${1:-$(dirname $0)}"
TS=$(date +%H%M%S 2>/dev/null || echo "000000")

# Use getTime if available (QNX epoch timestamp)
if command -v getTime >/dev/null 2>&1; then
    EPOCH=$(getTime 2>/dev/null)
    TS="epoch-${EPOCH}"
fi

OUTDIR="${SDPATH}/var/sysinfo/${TS}"
REPORT="${SDPATH}/var/sysinfo/sysinfo-${TS}.txt"
BACKUP="${SDPATH}/var/backup"

mkdir -p "${OUTDIR}" "${BACKUP}" "${SDPATH}/var" 2>/dev/null

# Show status on screen if showScreen available
if [ -x "${SDPATH}/bin/showScreen" ] && [ -f "${SDPATH}/lib/diag.png" ]; then
    "${SDPATH}/bin/showScreen" "${SDPATH}/lib/diag.png" 2>/dev/null &
fi

{
echo "################################################################"
echo "#  MMI3G-Toolkit System Information Report"
echo "#  Generated: $(date 2>/dev/null)"
echo "#  Host: $(hostname 2>/dev/null || echo unknown)"
echo "################################################################"

# ============================================================
# 1. SYSTEM IDENTITY
# ============================================================
echo ""
echo "================================================================"
echo "  1. SYSTEM IDENTITY"
echo "================================================================"

echo ""
echo "--- Software Train ---"
TRAIN=$(cat /dev/shmem/sw_trainname.txt 2>/dev/null)
echo "Train: ${TRAIN:-unknown}"
cp /dev/shmem/sw_trainname.txt "${OUTDIR}/sw_train.txt" 2>/dev/null

echo ""
echo "--- MMI Variant Detection ---"
for f in /etc/pci-3g_*.cfg; do
    [ -f "$f" ] || continue
    VID=$(echo "$f" | sed -n 's|.*/pci-3g_\([0-9]*\)\.cfg|\1|p')
    case "$VID" in
        9304) echo "Variant: MMI 3G Basic ($VID)" ;;
        9308) echo "Variant: MMI 3G High ($VID)" ;;
        9411) echo "Variant: MMI 3G+ ($VID)" ;;
        9436) echo "Variant: MMI 3G+ Gen2 ($VID)" ;;
        9478) echo "Variant: MMI 3G+ Gen3 ($VID)" ;;
        *)    echo "Variant: Unknown ($VID)" ;;
    esac
done
# Check for RSE (rear seat entertainment)
echo "$TRAIN" | grep -q "HN+R" && echo "  RSE: Yes (HN+R train)" || echo "  RSE: No"
# Check for VW/Porsche
echo "$TRAIN" | grep -q "_VW_" && echo "  Platform: VW (RNS-850)"
echo "$TRAIN" | grep -q "_AU_" && echo "  Platform: Audi"

echo ""
echo "--- QNX Version ---"
uname -a 2>/dev/null

echo ""
echo "--- System Uptime / pidin info ---"
pidin info 2>/dev/null
pidin info > "${OUTDIR}/pidin_info.txt" 2>/dev/null

# ============================================================
# 2. GEM & ENGINEERING STATUS
# ============================================================
echo ""
echo "================================================================"
echo "  2. GEM & ENGINEERING STATUS"
echo "================================================================"

echo ""
echo "--- DBGModeActive (GEM file marker) ---"
if [ -f /HBpersistence/DBGModeActive ]; then
    echo "STATUS: ENABLED (/HBpersistence/DBGModeActive exists)"
    ls -la /HBpersistence/DBGModeActive
else
    echo "STATUS: DISABLED (file not present)"
fi

echo ""
echo "--- engdefs Directory ---"
if [ -d /mnt/efs-system/engdefs ]; then
    ESDCOUNT=$(ls /mnt/efs-system/engdefs/*.esd 2>/dev/null | wc -l)
    echo "STATUS: EXISTS (${ESDCOUNT} screen files)"
    ls -la /mnt/efs-system/engdefs/*.esd > "${OUTDIR}/engdefs_listing.txt" 2>/dev/null
else
    echo "STATUS: NOT FOUND"
fi

echo ""
echo "--- AppDevelopment.jar ---"
for j in /mnt/efs-system/lsd/AppDevelopment.jar /mnt/efs-system/lsd/development/AppDevelopment.jar; do
    [ -f "$j" ] && echo "FOUND: $j ($(ls -la "$j" | awk '{print $5}') bytes)"
done

# ============================================================
# 3. ACTIVATION & FEATURE STATE
# ============================================================
echo ""
echo "================================================================"
echo "  3. ACTIVATION & FEATURE STATE"
echo "================================================================"

echo ""
echo "--- Porsche Activation (PagSWAct) ---"
if [ -f /HBpersistence/PagSWAct.002 ]; then
    echo "FOUND: /HBpersistence/PagSWAct.002"
    ls -la /HBpersistence/PagSWAct.002
    cp /HBpersistence/PagSWAct.002 "${BACKUP}/PagSWAct.002" 2>/dev/null
    echo "  (backed up to SD)"
else
    echo "NOT FOUND (Audi systems don't use this)"
fi

echo ""
echo "--- Nav Database ---"
if [ -f /mnt/efs-persist/acios_db.ini ]; then
    echo "Nav DB config:"
    cat /mnt/efs-persist/acios_db.ini 2>/dev/null | grep -v "^#" | grep -v "^$"
    cp /mnt/efs-persist/acios_db.ini "${BACKUP}/acios_db.ini" 2>/dev/null
fi

echo ""
echo "--- Nav Unblocker Status ---"
if [ -f /mnt/efs-system/scripts/setdatabase.cfg ]; then
    if grep -q "manage_cd" /mnt/efs-system/scripts/setdatabase.cfg 2>/dev/null; then
        echo "manage_cd.sh: PATCHED (DrGER2 unblocker)"
    else
        echo "manage_cd.sh: Stock"
    fi
fi

echo ""
echo "--- FSC Files (Feature activation codes) ---"
ls -laR /HBpersistence/FSC/ 2>/dev/null || echo "No FSC directory"
# Backup FSC files
if [ -d /HBpersistence/FSC ]; then
    mkdir -p "${BACKUP}/FSC" 2>/dev/null
    cp -R /HBpersistence/FSC/* "${BACKUP}/FSC/" 2>/dev/null
    echo "  (backed up to SD)"
fi

echo ""
echo "--- GEMMI (Google Earth) ---"
if [ -f /mnt/nav/gemmi/gemmi_final ]; then
    echo "INSTALLED: /mnt/nav/gemmi/gemmi_final"
    ls -la /mnt/nav/gemmi/ 2>/dev/null
    # Check if running
    pidin ar 2>/dev/null | grep -q gemmi && echo "RUNNING: Yes" || echo "RUNNING: No"
else
    echo "NOT INSTALLED"
fi

echo ""
echo "--- LAN/Network Flags ---"
[ -f /HBpersistence/usedhcp ] && echo "usedhcp: SET (DrGER LAN mode)" || echo "usedhcp: not set"
[ -f /HBpersistence/DLinkReplacesPPP ] && echo "DLinkReplacesPPP: SET" || echo "DLinkReplacesPPP: not set"

# ============================================================
# 4. CREDENTIALS & PASSWORDS
# ============================================================
echo ""
echo "================================================================"
echo "  4. CREDENTIALS & PASSWORDS"
echo "================================================================"

echo ""
echo "--- WiFi Hotspot Config ---"
for f in /mnt/efs-persist/wlan_*.conf /mnt/efs-system/etc/wpa_supplicant.conf /etc/wpa_supplicant.conf; do
    if [ -f "$f" ]; then
        echo "FOUND: $f"
        cat "$f" 2>/dev/null
        cp "$f" "${BACKUP}/$(basename $f)" 2>/dev/null
    fi
done

echo ""
echo "--- Bluetooth Pairing ---"
if [ -f /HBpersistence/bdaddr.txt ]; then
    echo "BT Address: $(cat /HBpersistence/bdaddr.txt 2>/dev/null)"
    cp /HBpersistence/bdaddr.txt "${BACKUP}/bdaddr.txt" 2>/dev/null
fi

echo ""
echo "--- Audi Connect / myaudi ---"
for f in /mnt/efs-system/scripts/Connectivity/common.cfg /lsd/MMI3G_MyAudi.properties; do
    if [ -f "$f" ]; then
        echo "FOUND: $f"
        grep -i "user\|pass\|key\|token\|auth\|ssid\|psk" "$f" 2>/dev/null
        cp "$f" "${BACKUP}/$(basename $f)" 2>/dev/null
    fi
done

echo ""
echo "--- VIN ---"
if [ -f /HBpersistence/vin ]; then
    echo "VIN: $(cat /HBpersistence/vin 2>/dev/null)"
fi

# ============================================================
# 5. STORAGE & PARTITIONS
# ============================================================
echo ""
echo "================================================================"
echo "  5. STORAGE & PARTITIONS"
echo "================================================================"

echo ""
echo "--- Mount Points ---"
mount 2>/dev/null | sort
mount > "${OUTDIR}/mounts.txt" 2>/dev/null

echo ""
echo "--- Disk Usage ---"
df -k 2>/dev/null
df -k > "${OUTDIR}/disk_usage.txt" 2>/dev/null

echo ""
echo "--- Flash Partitions ---"
ls -la /dev/fs* 2>/dev/null
ls -la /dev/hd* 2>/dev/null
ls -la /dev/sdcard* 2>/dev/null

# ============================================================
# 6. NETWORK
# ============================================================
echo ""
echo "================================================================"
echo "  6. NETWORK"
echo "================================================================"

echo ""
echo "--- Interfaces ---"
ifconfig -a 2>/dev/null
ifconfig -a > "${OUTDIR}/interfaces.txt" 2>/dev/null

echo ""
echo "--- Routes ---"
netstat -rn 2>/dev/null
netstat -rn > "${OUTDIR}/routes.txt" 2>/dev/null

echo ""
echo "--- DNS ---"
cat /etc/resolv.conf 2>/dev/null
cat /etc/resolv.conf > "${OUTDIR}/dns.txt" 2>/dev/null

# ============================================================
# 7. INSTALLED SCRIPTS & MODIFICATIONS
# ============================================================
echo ""
echo "================================================================"
echo "  7. INSTALLED SCRIPTS & MODIFICATIONS"
echo "================================================================"

echo ""
echo "--- Custom Scripts on EFS ---"
ls -laR /mnt/efs-system/scripts/ 2>/dev/null

echo ""
echo "--- Splash Screens ---"
ls -la /mnt/efs-system/lsd/startup-*.png 2>/dev/null | wc -l
echo " splash screen PNGs found"
if [ -f /mnt/efs-system/lsd/StartupImageConfig.txt ]; then
    cat /mnt/efs-system/lsd/StartupImageConfig.txt 2>/dev/null
fi

# ============================================================
# 8. HBpersistence SNAPSHOT
# ============================================================
echo ""
echo "================================================================"
echo "  8. HBpersistence SNAPSHOT"
echo "================================================================"

echo ""
echo "--- File Listing ---"
ls -laR /HBpersistence/ > "${OUTDIR}/HBpersistence_listing.txt" 2>&1
echo "Full listing saved to: HBpersistence_listing.txt"

# Backup key persistence files
mkdir -p "${BACKUP}/HBpersistence" 2>/dev/null
for f in /HBpersistence/DBGModeActive \
         /HBpersistence/PagSWAct.002 \
         /HBpersistence/usedhcp \
         /HBpersistence/DLinkReplacesPPP \
         /HBpersistence/vin \
         /HBpersistence/bdaddr.txt \
         /HBpersistence/audiomixer*.txt \
         /HBpersistence/TouchCalib.bin; do
    [ -f "$f" ] && cp "$f" "${BACKUP}/HBpersistence/" 2>/dev/null
done
echo "Key files backed up to SD"

# ============================================================
# 9. PROCESSES
# ============================================================
echo ""
echo "================================================================"
echo "  9. RUNNING PROCESSES"
echo "================================================================"

pidin ar > "${OUTDIR}/processes.txt" 2>/dev/null
# Show unique process names only
pidin ar 2>/dev/null | awk '{print $1}' | sort -u | grep -v "^name$" | grep -v "^$"

# ============================================================
# 10. SYSLOG
# ============================================================
echo ""
echo "================================================================"
echo "  10. SYSTEM LOG"
echo "================================================================"

sloginfo 2>/dev/null | sed -n '1,200p' > "${OUTDIR}/syslog.txt" 2>/dev/null
echo "Syslog saved (first 200 lines)"

# ============================================================
echo ""
echo "################################################################"
echo "#  End of System Information Report"
echo "#  Data:    ${OUTDIR}/"
echo "#  Backups: ${BACKUP}/"
echo "#  Report:  ${REPORT}"
echo "################################################################"

} > "${REPORT}" 2>&1

# Copy report to the data dir too
cp "${REPORT}" "${OUTDIR}/" 2>/dev/null
