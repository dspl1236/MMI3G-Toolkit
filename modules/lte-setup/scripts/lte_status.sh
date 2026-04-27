#!/bin/ksh
# ============================================================
# LTE / LAN Status Check
# Diagnoses USB Ethernet connectivity and fair mode state
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
LOGFILE="${SDPATH}/var/lte-status-$(mmi_logstamp).txt"

{
echo "============================================"
echo " LTE / LAN Status Report"
echo " $(date)"
echo " Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo "============================================"
echo ""

echo "--- Fair Mode (DLinkReplacesPPP) ---"
if [ -f "/HBpersistence/DLinkReplacesPPP" ]; then
    echo "STATUS: ENABLED"
elif [ -f "/mnt/efs-persist/HBpersistence/DLinkReplacesPPP" ]; then
    echo "STATUS: ENABLED (efs-persist path)"
else
    echo "STATUS: DISABLED (factory PPP mode)"
fi
echo ""

echo "--- DHCP Marker ---"
if [ -f "/mnt/efs-persist/usedhcp" ]; then
    echo "STATUS: usedhcp EXISTS (DHCP client enabled)"
else
    echo "STATUS: usedhcp NOT FOUND (DHCP disabled)"
fi
echo ""

echo "--- ASIX Driver ---"
ls -la /lib/dll/devnp-asix.so 2>/dev/null || \
ls -la /mnt/ifs-root/lib/dll/devnp-asix.so 2>/dev/null || \
echo "devnp-asix.so: NOT FOUND"
echo ""

echo "--- en5 Interface (USB Ethernet) ---"
EN5=$(ifconfig en5 2>/dev/null)
if [ -n "$EN5" ]; then
    echo "STATUS: ACTIVE"
    echo "$EN5"
else
    echo "STATUS: NOT PRESENT"
    echo "(Is D-Link DUB-E100 plugged in?)"
fi
echo ""

echo "--- ppp0 Interface (Internal 3G modem) ---"
PPP0=$(ifconfig ppp0 2>/dev/null)
if [ -n "$PPP0" ]; then
    echo "STATUS: ACTIVE"
    echo "$PPP0"
else
    echo "STATUS: NOT PRESENT (expected in fair mode)"
fi
echo ""

echo "--- All Network Interfaces ---"
ifconfig -a 2>/dev/null
echo ""

echo "--- Routing Table ---"
netstat -rn 2>/dev/null
echo ""

echo "--- DNS Configuration ---"
echo "/etc/resolv.conf:"
cat /etc/resolv.conf 2>/dev/null || echo "(empty or missing)"
echo ""

echo "--- dhcp-up Script ---"
if [ -f "/mnt/efs-system/etc/dhcp-up" ]; then
    echo "STATUS: INSTALLED"
    ls -la /mnt/efs-system/etc/dhcp-up
else
    echo "STATUS: NOT INSTALLED"
fi
echo ""

echo "--- USB Devices ---"
usb 2>/dev/null || echo "usb: not available"
echo ""

echo "--- Connectivity Test ---"
# Try to ping the default gateway
GW=$(netstat -rn 2>/dev/null | grep "^default" | awk '{print $2}')
if [ -n "$GW" ]; then
    echo "Default gateway: $GW"
    ping -c 1 -w 3 $GW >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Gateway ping: SUCCESS"
    else
        echo "Gateway ping: FAILED"
    fi
else
    echo "No default gateway found"
fi
echo ""

echo "============================================"
} > ${LOGFILE} 2>&1

cat ${LOGFILE}
echo ""
echo "Report saved to: ${LOGFILE}"
