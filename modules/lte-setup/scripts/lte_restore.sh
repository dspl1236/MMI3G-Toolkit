#!/bin/ksh
# ============================================================
# LTE / LAN Setup — Restore / Uninstall
# Removes fair mode, restores factory PPP modem configuration
# ============================================================

SDPATH="${1:-$(dirname $0)}"
LOGFILE="${SDPATH}/var/lte-restore-$(date +%Y%m%d-%H%M%S).log"

exec > ${LOGFILE} 2>&1

echo "============================================"
echo " LTE Setup — Restore Factory Configuration"
echo " $(date)"
echo "============================================"
echo ""

mount -uw /mnt/efs-system 2>/dev/null
mount -uw /mnt/efs-persist 2>/dev/null
mount -uw /HBpersistence 2>/dev/null

echo "[ACTI]  Removing DLinkReplacesPPP flag..."
rm -f /HBpersistence/DLinkReplacesPPP 2>/dev/null
rm -f /mnt/efs-persist/HBpersistence/DLinkReplacesPPP 2>/dev/null
echo "[OK]    Flag removed"

echo "[ACTI]  Removing DHCP marker..."
rm -f /mnt/efs-persist/usedhcp 2>/dev/null
echo "[OK]    usedhcp removed"

echo "[ACTI]  Removing dhcp-up script..."
DHCPUP="/mnt/efs-system/etc/dhcp-up"
BACKUPDIR="${SDPATH}/var/lte-backup-$(ls -dt ${SDPATH}/var/lte-backup-* 2>/dev/null | head -1 | xargs basename 2>/dev/null)"
if [ -f "${SDPATH}/var/${BACKUPDIR}/dhcp-up.bak" ]; then
    cp -v "${SDPATH}/var/${BACKUPDIR}/dhcp-up.bak" "${DHCPUP}"
    echo "[OK]    Restored original dhcp-up from backup"
else
    rm -f ${DHCPUP} 2>/dev/null
    echo "[OK]    dhcp-up removed"
fi

sync
echo ""
echo "Factory PPP modem configuration restored."
echo "Reboot MMI for changes to take effect."
echo ""
echo "Note: The internal 3G modem will only work if your"
echo "carrier still supports 3G data. Most carriers have"
echo "sunset their 3G networks as of 2022-2023."
echo "============================================"
