#!/bin/ksh
# ============================================================
# LTE / LAN Setup — Restore / Uninstall
# Removes fair mode, restores factory PPP modem configuration
# ============================================================

# --- platform.sh (shared variant detection + getTime helper) ---
# Defines MMI_VARIANT / MMI_VARIANT_ID / MMI_TRAIN and mmi_logstamp().
# Must be sourced before any code that calls mmi_logstamp.
_SDPATH_GUESS="${SDPATH:-${0%/*}}"
if [ -f "${_SDPATH_GUESS}/scripts/common/platform.sh" ]; then
    . "${_SDPATH_GUESS}/scripts/common/platform.sh"
elif [ -f "/mnt/efs-system/scripts/common/platform.sh" ]; then
    . "/mnt/efs-system/scripts/common/platform.sh"
else
    # Inline minimal fallback (DrGER2 review corrections applied)
    MMI_VARIANT="UNKNOWN"; MMI_VARIANT_ID=""
    for _f in /etc/pci-3g_*.cfg; do
        [ -f "$_f" ] || continue
        MMI_VARIANT_ID="$(echo "$_f" | sed -n 's,^/etc/pci-3g_\([0-9]*\)\.cfg$,\1,p')"
        case "$MMI_VARIANT_ID" in
            9304) MMI_VARIANT="MMI3G_BASIC" ;;
            9308) MMI_VARIANT="MMI3G_HIGH" ;;
            9411|9436|9478) MMI_VARIANT="MMI3GP" ;;
        esac
        break
    done
    MMI_TRAIN="$(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
    [ -z "$MMI_TRAIN" ] && MMI_TRAIN="$(sloginfo -m 10000 -s 5 2>/dev/null | sed -n 's/^.* +++ Train //p' | sed -n 1p)"
    [ -z "$MMI_TRAIN" ] && MMI_TRAIN="n/a"
    if [ "$MMI_VARIANT" = "MMI3GP" ] && echo "$MMI_TRAIN" | grep -q "_VW_"; then
        MMI_VARIANT="RNS850"
    fi
    mmi_logstamp() {
        if command -v getTime >/dev/null 2>&1; then
            _T="$(getTime 2>/dev/null)"
            [ -n "$_T" ] && { date -r "$_T" +%Y%m%d-%H%M%S 2>/dev/null || echo "epoch-$_T"; return 0; }
        fi
        date +%Y%m%d-%H%M%S 2>/dev/null
    }
    mmi_getTime() {
        if command -v getTime >/dev/null 2>&1; then getTime 2>/dev/null; else date +%s 2>/dev/null; fi
    }
fi
# --- end platform.sh source ---

SDPATH="${1:-${0%/*}}"
LOGFILE="${SDPATH}/var/lte-restore-$(mmi_logstamp).log"

exec > ${LOGFILE} 2>&1

echo "============================================"
echo " LTE Setup — Restore Factory Configuration"
echo " $(date)"
echo "============================================"
echo ""

# Hold F3S reclaim for the duration of this script (see research/F3S_FORMAT.md)
# Guarded: if platform.sh provided it, use it; otherwise inline the minimum.
if command -v mmi_reclaim_hold >/dev/null 2>&1; then
    mmi_reclaim_hold
else
    touch /tmp/disableReclaim 2>/dev/null
    trap 'rm -f /tmp/disableReclaim 2>/dev/null' EXIT INT TERM
fi

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

echo "[ACTI]  Removing port 2323 shell from inetd.conf..."
INETD_CONF="/etc/inetd.conf"
if grep -q "2323" "$INETD_CONF" 2>/dev/null; then
    sed '/2323.*ksh/d' "$INETD_CONF" > /tmp/inetd_clean.conf 2>/dev/null
    sed '/MMI3G-Toolkit LTE/d' /tmp/inetd_clean.conf > "$INETD_CONF" 2>/dev/null
    rm -f /tmp/inetd_clean.conf
    echo "[OK]    Port 2323 removed from inetd.conf"
else
    echo "[OK]    Port 2323 not in inetd.conf (already clean)"
fi

echo "[ACTI]  Restoring root password..."
SHADOW_EFS="/mnt/efs-system/etc/shadow"
SHADOW_ORIG="${SHADOW_EFS}-orig"
if [ -f "$SHADOW_ORIG" ]; then
    cp "$SHADOW_ORIG" "$SHADOW_EFS" 2>/dev/null
    echo "[OK]    Original shadow restored from ${SHADOW_ORIG}"
else
    echo "[WARN]  No shadow-orig found — password state unchanged"
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
