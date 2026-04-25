#!/bin/sh
# Google Earth Restoration — SD Card Installer
# Run from engineering shell: sh /mnt/sd/install_ge.sh
#
# Requires: root shell, LTE internet (Digi WR11 or similar)
# Deploys: patched libembeddedearth.so, custom dbRoot, auth cache,
#          mini HTTP server, control scripts

SD="/mnt/sd"
GE_DIR="/mnt/nav/gemmi"
BACKUP_DIR="/mnt/nav/.mmi3g_toolkit/google-earth"
LOG="/tmp/ge_install.log"

echo "=== Google Earth Restoration Installer ===" | tee $LOG
echo "$(date)" >> $LOG

# Sanity checks
if [ ! -d "$GE_DIR" ]; then
    echo "ERROR: $GE_DIR not found. Is GEMMI installed?" | tee -a $LOG
    exit 1
fi

if [ ! -f "$SD/gemmi/libembeddedearth.so" ]; then
    echo "ERROR: SD card payload not found at $SD/gemmi/" | tee -a $LOG
    echo "Expected files: libembeddedearth.so, dbRoot_custom.bin," | tee -a $LOG
    echo "  auth_resp1.bin, auth_resp2.bin, gemmi_server.sh" | tee -a $LOG
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR" 2>/dev/null

# Backup originals (only if not already backed up)
if [ ! -f "$BACKUP_DIR/libembeddedearth.so.orig" ]; then
    echo "Backing up originals..." | tee -a $LOG
    cp "$GE_DIR/libembeddedearth.so" "$BACKUP_DIR/libembeddedearth.so.orig"
    cp "$GE_DIR/run_gemmi.sh" "$BACKUP_DIR/run_gemmi.sh.orig" 2>/dev/null
    echo "  Backed up to $BACKUP_DIR/" | tee -a $LOG
else
    echo "Backups already exist, skipping." | tee -a $LOG
fi

# Stop GEMMI
echo "Stopping GEMMI..." | tee -a $LOG
slay gemmi_final 2>/dev/null
sleep 1

# Deploy patched files
echo "Deploying patched files..." | tee -a $LOG
cp "$SD/gemmi/libembeddedearth.so" "$GE_DIR/libembeddedearth.so"
cp "$SD/gemmi/dbRoot_custom.bin" "$GE_DIR/dbRoot_custom.bin"
cp "$SD/gemmi/auth_resp1.bin" "$GE_DIR/auth_resp1.bin"
cp "$SD/gemmi/auth_resp2.bin" "$GE_DIR/auth_resp2.bin"
cp "$SD/gemmi/gemmi_server.sh" "$GE_DIR/gemmi_server.sh"
cp "$SD/gemmi/gemmi_control.sh" "$GE_DIR/gemmi_control.sh"
chmod +x "$GE_DIR/gemmi_server.sh" "$GE_DIR/gemmi_control.sh"

# Deploy run_gemmi.sh (starts mini server before GEMMI)
cp "$SD/gemmi/run_gemmi.sh" "$GE_DIR/run_gemmi.sh"
chmod +x "$GE_DIR/run_gemmi.sh"

# Set up /etc/hosts
if ! grep -q "127.0.0.1 kh.google.com" /etc/hosts 2>/dev/null; then
    echo "Adding hosts entry..." | tee -a $LOG
    echo "127.0.0.1 kh.google.com" >> /etc/hosts
fi

# Clear GEMMI cache (force fresh tile download)
echo "Clearing GEMMI cache..." | tee -a $LOG
rm -rf /mnt/img-cache/gemmi/cache/* 2>/dev/null

echo "" | tee -a $LOG
echo "=== Installation Complete ===" | tee -a $LOG
echo "Files deployed to $GE_DIR/" | tee -a $LOG
echo "Reboot the MMI to activate Google Earth." | tee -a $LOG
echo "" | tee -a $LOG
echo "To revert: sh $SD/gemmi/uninstall_ge.sh" | tee -a $LOG
