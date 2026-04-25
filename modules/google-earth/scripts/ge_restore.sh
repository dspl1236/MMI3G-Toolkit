#!/bin/ksh
# ============================================================
# MMI3G-Toolkit — Google Earth Restore
# Reverts all changes made by ge_activate.sh
# ============================================================

BACKUP="/mnt/nav/.mmi3g_toolkit/google-earth"
GEMMI="/mnt/nav/gemmi"

echo "=== Google Earth Restore ==="

if [ ! -f "$BACKUP/libembeddedearth.so.orig" ]; then
    echo "ERROR: No backup found at $BACKUP/"
    echo "Cannot revert without original files."
    exit 1
fi

# Stop everything
slay gemmi_final 2>/dev/null
sleep 1

# Restore original binary
echo "Restoring original libembeddedearth.so..."
cp "$BACKUP/libembeddedearth.so.orig" "$GEMMI/libembeddedearth.so"

# Restore run_gemmi.sh
if [ -f "$BACKUP/run_gemmi.sh.orig" ]; then
    cp "$BACKUP/run_gemmi.sh.orig" "$GEMMI/run_gemmi.sh"
fi

# Restore /etc/hosts
if [ -f "$BACKUP/hosts.orig" ]; then
    cp "$BACKUP/hosts.orig" /etc/hosts
fi

# Remove deployed files
rm -f "$GEMMI/dbRoot_custom.bin"
rm -f "$GEMMI/auth_resp1.bin"
rm -f "$GEMMI/auth_resp2.bin"
rm -f "$GEMMI/gemmi_server.sh"
rm -f "$GEMMI/gemmi_control.sh"

# Clear cache
rm -rf /mnt/img-cache/gemmi/cache/* 2>/dev/null

echo ""
echo "=== Restore Complete ==="
echo "Original files restored. Hard reboot to apply."
