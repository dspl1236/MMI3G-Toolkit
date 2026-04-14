#!/bin/ksh
# ============================================================
# LTE / LAN Status Check
# Diagnoses USB Ethernet connectivity and fair mode state
# ============================================================

SDPATH="${1:-$(dirname $0)}"
LOGFILE="${SDPATH}/var/lte-status-$(date +%Y%m%d-%H%M%S).txt"

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
