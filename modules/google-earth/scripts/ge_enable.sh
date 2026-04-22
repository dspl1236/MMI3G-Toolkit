#!/bin/ksh
# ============================================================
# MMI3G-Toolkit — Google Earth Enabler
# !!!! EXPERIMENTAL — USE AT YOUR OWN RISK !!!!
#
# This script attempts to enable Google Earth by:
#   1. Backing up drivers.ini
#   2. Adding disableAuthKey to drivers.ini
#   3. Creating /etc/hosts redirect (optional)
#   4. Checking GEMMI binary presence
#
# It does NOT modify:
#   - lsd.jxe (read-only IFS on some variants)
#   - DataPST.db (EOL flag key addresses unknown)
#   - Any firmware files
#
# Based on:
#   - gemmi_final binary analysis (configurable server params)
#   - Live server test: kh.google.com/dbRoot.v5 returns 200
#   - Live server test: /geauth returns 404 (auth REMOVED)
#   - disableAuthKey parameter found in libembeddedearth.so
#
# Variant compatibility:
#   ✅ Audi EU (HU_VARIANT=5) — no RANGE_ block
#   ✅ Audi NAR (HU_VARIANT=6) — no RANGE_ block
#   ✅ China (HU_VARIANT=8) — no RANGE_ block
#   ⚠️ VW (HU_VARIANT=15) — RANGE_ blocked, needs additional work
#   ⚠️ Bentley (HU_VARIANT=16) — RANGE_ blocked
#   ❌ Japan (HU_VARIANT=7) — RANGE_ blocked
#   ❌ Korea (HU_VARIANT=9) — RANGE_ blocked
#
# Part of MMI3G-Toolkit: github.com/dspl1236/MMI3G-Toolkit
# ============================================================

# --- platform.sh ---
_SDPATH_GUESS="${SDPATH:-$(dirname $0)}"
if [ -f "${_SDPATH_GUESS}/scripts/common/platform.sh" ]; then
    . "${_SDPATH_GUESS}/scripts/common/platform.sh"
elif [ -f "/mnt/efs-system/scripts/common/platform.sh" ]; then
    . "/mnt/efs-system/scripts/common/platform.sh"
fi

SDPATH="${_SDPATH_GUESS}"
TS=$(date +%H%M%S 2>/dev/null || echo "000000")
if command -v getTime >/dev/null 2>&1; then TS="epoch-$(getTime)"; fi

OUTDIR="${SDPATH}/var/google-earth"
LOG="${OUTDIR}/ge-enable-${TS}.log"
BACKUP="${SDPATH}/var/backup/google-earth"
mkdir -p "${OUTDIR}" 2>/dev/null
mkdir -p "${BACKUP}" 2>/dev/null

exec > "${LOG}" 2>&1

echo "============================================"
echo " Google Earth Enabler — EXPERIMENTAL"
echo " $(date)"
echo " Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo " Variant: ${MMI_VARIANT:-unknown} (${MMI_VARIANT_ID:-?})"
echo "============================================"
echo ""

DRIVERS_INI="/mnt/efs-system/lsd/drivers.ini"
EFSDIR="/mnt/efs-system"
CHANGES=0

# ============================================================
# Step 1: Variant check
# ============================================================
echo "[STEP 1] Variant compatibility check..."

RANGE_BLOCKED=0
case "${MMI_VARIANT_ID}" in
    9304|9308|9411)
        echo "  Audi variant (${MMI_VARIANT}) — no RANGE_ block on GE"
        echo "  ✅ Compatible"
        ;;
    9478)
        echo "  VW/RNS-850 variant — RANGE_ block may apply"
        echo "  ⚠️ May need additional work (IFS mod for full UI)"
        echo "  ⚠️ gemmi_final can still run independently"
        RANGE_BLOCKED=1
        ;;
    *)
        echo "  Unknown variant (${MMI_VARIANT_ID})"
        echo "  ⚠️ Proceeding with caution"
        ;;
esac
echo ""

# ============================================================
# Step 2: Remount EFS read-write
# ============================================================
echo "[STEP 2] Remounting EFS read-write..."
mount -uw ${EFSDIR} 2>/dev/null
if [ $? -eq 0 ]; then
    echo "  [OK] EFS remounted rw"
else
    echo "  [WARN] Remount failed (may already be rw)"
fi
echo ""

# ============================================================
# Step 3: Backup drivers.ini
# ============================================================
echo "[STEP 3] Backing up drivers.ini..."
if [ -f "$DRIVERS_INI" ]; then
    cp "$DRIVERS_INI" "${BACKUP}/drivers.ini.bak-${TS}"
    echo "  [OK] Backed up to ${BACKUP}/drivers.ini.bak-${TS}"
else
    echo "  [WARN] drivers.ini not found at $DRIVERS_INI"
    echo "  [WARN] Cannot proceed with drivers.ini modification"
fi
echo ""

# ============================================================
# Step 4: Add disableAuthKey to drivers.ini
# ============================================================
echo "[STEP 4] Checking disableAuthKey in drivers.ini..."
if [ -f "$DRIVERS_INI" ]; then
    if grep -q "disableAuthKey" "$DRIVERS_INI" 2>/dev/null; then
        echo "  [OK] disableAuthKey already present"
    else
        echo "  [MOD] Adding disableAuthKey = true"
        echo "" >> "$DRIVERS_INI"
        echo "    ; Google Earth auth bypass (MMI3G-Toolkit)" >> "$DRIVERS_INI"
        echo "    Connection/disableAuthKey = true" >> "$DRIVERS_INI"
        CHANGES=$((CHANGES + 1))
        echo "  [OK] Added to drivers.ini"
    fi
fi
echo ""

# ============================================================
# Step 5: Check /etc/hosts capability
# ============================================================
echo "[STEP 5] DNS/hosts redirect check..."

echo "  Current /etc/hosts:"
if [ -f /etc/hosts ]; then
    cat /etc/hosts
else
    echo "  (no hosts file — normal for QNX)"
fi
echo ""

# We don't automatically modify /etc/hosts because:
# 1. With disableAuthKey, direct connection to Google might work
# 2. /etc/hosts changes don't persist across reboots
# 3. A proxy server would need to be running to receive redirected traffic
echo "  [INFO] /etc/hosts redirect NOT applied automatically"
echo "  [INFO] If direct Google connection fails, a proxy + hosts"
echo "         redirect can be configured manually:"
echo "         echo '192.168.0.1 kh.google.com' >> /etc/hosts"
echo ""

# ============================================================
# Step 6: GEMMI binary check
# ============================================================
echo "[STEP 6] GEMMI binary inventory..."

GEMMI_READY=0
for dir in /mnt/efs-system/gemmi /mnt/nav/gemmi; do
    if [ -d "$dir" ] && [ -f "$dir/gemmi_final" ]; then
        echo "  [OK] gemmi_final found at $dir"
        GEMMI_READY=1
    fi
done

if [ $GEMMI_READY -eq 0 ]; then
    echo "  [WARN] gemmi_final NOT found"
    echo "  [INFO] GEMMI binaries may need to be deployed from EU firmware"
    echo "  [INFO] The gemmi-dump module can extract these from an EU source"
fi
echo ""

# ============================================================
# Step 7: Network connectivity test
# ============================================================
echo "[STEP 7] Network connectivity..."

HAS_NET=0
if ifconfig en5 2>/dev/null | grep -q "inet"; then
    echo "  [OK] en5 interface has IP address"
    HAS_NET=1
elif ifconfig ppp0 2>/dev/null | grep -q "inet"; then
    echo "  [OK] ppp0 interface has IP address"
    HAS_NET=1
else
    echo "  [WARN] No active internet interface detected"
    echo "  [INFO] Google Earth requires internet connectivity"
    echo "  [INFO] Connect USB ethernet + LTE router first"
fi
echo ""

# ============================================================
# Summary
# ============================================================
echo "============================================"
echo " Summary"
echo "============================================"
echo ""
echo " Changes made:     $CHANGES"
echo " Variant:          ${MMI_VARIANT:-unknown} (RANGE blocked: $([ $RANGE_BLOCKED -eq 1 ] && echo 'YES' || echo 'NO'))"
echo " disableAuthKey:   $(grep -q disableAuthKey "$DRIVERS_INI" 2>/dev/null && echo 'SET' || echo 'NOT SET')"
echo " GEMMI binaries:   $([ $GEMMI_READY -eq 1 ] && echo 'PRESENT' || echo 'NOT FOUND')"
echo " Internet:         $([ $HAS_NET -eq 1 ] && echo 'CONNECTED' || echo 'NOT CONNECTED')"
echo " Backup:           ${BACKUP}/"
echo ""

if [ $CHANGES -gt 0 ]; then
    echo " ⚠️ REBOOT REQUIRED for changes to take effect"
    echo ""
    echo " After reboot:"
    echo "   1. Ensure internet is connected"
    echo "   2. Open NAV → Map Settings → check for Google Earth option"
    echo "   3. If GE option appears, enable it"
    echo "   4. If GE option does NOT appear:"
    echo "      - The EOL flags may need to be flipped in DataPST.db"
    echo "      - Or the lsd.jxe sysconst needs modification"
    echo "      - Run ge_probe.sh and share results on GitHub"
fi

echo ""
echo " Log: ${LOG}"
echo " Restore: cp ${BACKUP}/drivers.ini.bak-${TS} $DRIVERS_INI"
echo "============================================"
