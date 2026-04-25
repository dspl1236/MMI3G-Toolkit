#!/bin/sh
# Google Earth Restoration — Uninstaller
# Reverts to stock GEMMI configuration

BACKUP_DIR="/mnt/nav/.mmi3g_toolkit/google-earth"
GE_DIR="/mnt/nav/gemmi"

echo "=== Google Earth Restoration — Uninstaller ==="

if [ ! -f "$BACKUP_DIR/libembeddedearth.so.orig" ]; then
    echo "ERROR: No backup found at $BACKUP_DIR/"
    echo "Cannot revert without original files."
    exit 1
fi

# Stop everything
slay gemmi_final 2>/dev/null
sleep 1

# Restore originals
echo "Restoring original files..."
cp "$BACKUP_DIR/libembeddedearth.so.orig" "$GE_DIR/libembeddedearth.so"
if [ -f "$BACKUP_DIR/run_gemmi.sh.orig" ]; then
    cp "$BACKUP_DIR/run_gemmi.sh.orig" "$GE_DIR/run_gemmi.sh"
fi

# Remove our files
rm -f "$GE_DIR/dbRoot_custom.bin"
rm -f "$GE_DIR/auth_resp1.bin"
rm -f "$GE_DIR/auth_resp2.bin"
rm -f "$GE_DIR/gemmi_server.sh"
rm -f "$GE_DIR/gemmi_control.sh"

# Remove hosts entry
# QNX doesn't have sed -i, so we rebuild the file
if [ -f /etc/hosts ]; then
    grep -v "kh.google.com" /etc/hosts > /tmp/hosts_clean
    cp /tmp/hosts_clean /etc/hosts
    rm /tmp/hosts_clean
fi

# Clear cache
rm -rf /mnt/img-cache/gemmi/cache/* 2>/dev/null

echo "=== Uninstall Complete ==="
echo "Original files restored. Reboot to apply."
