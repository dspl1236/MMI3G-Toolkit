#!/bin/ksh
# ============================================================
# MMI3G-Toolkit — Google Earth Restore
# Reverts all changes made by ge_deploy.sh
# Restores original GEMMI binaries and cleans up proxy
# ============================================================

SDPATH="${1:-${0%/*}/..}"
GEMMI="/mnt/nav/gemmi"

OUTDIR="${SDPATH}/var/google-earth"
mkdir -p "${OUTDIR}" 2>/dev/null
LOG="${OUTDIR}/ge-restore.log"

exec > "${LOG}" 2>&1

echo "=== Google Earth Restore ==="
echo ""

# Remount writable
mount -u -o rw /dev/hd0t77 /mnt/nav 2>/dev/null

# Stop GEMMI and proxy
echo "Stopping GEMMI..."
slay -f gemmi_proxy 2>/dev/null
slay -f gemmi_final 2>/dev/null
sleep 2

# Restore original .so
if [ -f "${GEMMI}/libembeddedearth.so.orig" ]; then
    echo "Restoring original libembeddedearth.so..."
    rm -f "${GEMMI}/libembeddedearth.so" 2>/dev/null
    cp "${GEMMI}/libembeddedearth.so.orig" "${GEMMI}/libembeddedearth.so"
    echo "[OK] Original .so restored"
else
    echo "[WARN] No backup found at ${GEMMI}/libembeddedearth.so.orig"
    echo "Cannot revert .so without original backup."
fi

# Restore original run_gemmi.sh (remove proxy startup)
if grep -q "gemmi_proxy" "${GEMMI}/run_gemmi.sh" 2>/dev/null; then
    grep -v "gemmi_proxy\|Start on-car proxy\|sleep 1" "${GEMMI}/run_gemmi.sh" > "${GEMMI}/run_gemmi.sh.tmp"
    mv "${GEMMI}/run_gemmi.sh.tmp" "${GEMMI}/run_gemmi.sh"
    chmod +x "${GEMMI}/run_gemmi.sh"
    echo "[OK] Removed proxy startup from run_gemmi.sh"
fi

# Clean /etc/hosts (remove any GE-related entries)
if grep -q "kh.google.com\|geoauth.google.com\|cbk0.google.com" /etc/hosts 2>/dev/null; then
    grep -v "kh.google.com\|geoauth.google.com\|maps.google.com\|cbk0.google.com" /etc/hosts > /etc/hosts.tmp
    cp /etc/hosts.tmp /etc/hosts
    rm /etc/hosts.tmp 2>/dev/null
    echo "[OK] Cleaned /etc/hosts"
fi

# Remove deployed GE files (keep GEMMI core)
rm -f "${GEMMI}/dbRoot_custom.bin"
rm -f "${GEMMI}/auth_resp1.bin"
rm -f "${GEMMI}/auth_resp2.bin"
rm -f "${GEMMI}/gemmi_proxy"
rm -f "${GEMMI}/gemmi_server.sh"
rm -f "${GEMMI}/gemmi_control.sh"
echo "[OK] Removed deployed GE files"

# Clear tile cache
rm -rf /mnt/img-cache/gemmi/cache/* 2>/dev/null
rm -rf /mnt/img-cache/gemmi/scache/* 2>/dev/null
rm -rf /mnt/img-cache/gemmi/temp/* 2>/dev/null
echo "[OK] Tile cache cleared"

echo ""
echo "=== Restore Complete ==="
echo "Original files restored. Eject SD card, then hard reboot."
