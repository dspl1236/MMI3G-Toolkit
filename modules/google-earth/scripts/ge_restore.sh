#!/bin/ksh
# ============================================================
# MMI3G-Toolkit — Google Earth Restore
# Reverts all changes made by ge_enable.sh
# ============================================================

_SDPATH_GUESS="${SDPATH:-$(dirname $0)}"
if [ -f "${_SDPATH_GUESS}/scripts/common/platform.sh" ]; then
    . "${_SDPATH_GUESS}/scripts/common/platform.sh"
fi
SDPATH="${_SDPATH_GUESS}"

DRIVERS_INI="/mnt/efs-system/lsd/drivers.ini"
EFSDIR="/mnt/efs-system"
BACKUP="${SDPATH}/var/backup/google-earth"

echo "============================================"
echo " Google Earth Restore"
echo "============================================"

# Remount rw
mount -uw ${EFSDIR} 2>/dev/null

# Find most recent backup
LATEST=""
for bak in ${BACKUP}/drivers.ini.bak-*; do
    [ -f "$bak" ] && LATEST="$bak"
done

if [ -n "$LATEST" ] && [ -f "$LATEST" ]; then
    echo "[RESTORE] Restoring drivers.ini from $LATEST"
    cp "$LATEST" "$DRIVERS_INI"
    echo "[OK] drivers.ini restored"
else
    # Manual removal of our additions
    if [ -f "$DRIVERS_INI" ] && grep -q "MMI3G-Toolkit" "$DRIVERS_INI"; then
        echo "[RESTORE] Removing MMI3G-Toolkit additions from drivers.ini"
        # Remove our comment and the disableAuthKey line
        grep -v "Google Earth auth bypass\|Connection/disableAuthKey" "$DRIVERS_INI" > /tmp/drivers_clean.ini
        cp /tmp/drivers_clean.ini "$DRIVERS_INI"
        rm -f /tmp/drivers_clean.ini
        echo "[OK] Removed disableAuthKey from drivers.ini"
    else
        echo "[INFO] No changes found to revert"
    fi
fi

# Remove /etc/hosts entries if we added any
if [ -f /etc/hosts ] && grep -q "MMI3G-Toolkit\|kh.google.com" /etc/hosts 2>/dev/null; then
    grep -v "kh.google.com\|cbk0.google.com\|maps.googleapis.com\|mw1.google.com" /etc/hosts > /tmp/hosts_clean
    cp /tmp/hosts_clean /etc/hosts
    rm -f /tmp/hosts_clean
    echo "[OK] Removed DNS redirects from /etc/hosts"
fi

echo ""
echo "============================================"
echo " Restore complete — reboot to apply"
echo "============================================"
