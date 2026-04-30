#!/bin/ksh
# ============================================================
# MMI3G-Toolkit — Static IP Network Setup
# Direct PC-to-car connection via USB Ethernet
# NO REBOOT NEEDED — works immediately
# ============================================================
#
# Connect: USB ethernet adapter → ethernet cable → PC
# PC static IP: 172.16.42.2, netmask 255.255.255.0
# Then: telnet 172.16.42.1 (or PuTTY → Telnet → 172.16.42.1)

_SDPATH_GUESS="${SDPATH:-${0%/*}}"
if [ -f "${_SDPATH_GUESS}/scripts/common/platform.sh" ]; then
    . "${_SDPATH_GUESS}/scripts/common/platform.sh"
fi
SDPATH="${_SDPATH_GUESS}"
OUTDIR="${SDPATH}/var/lte-setup"
mkdir -p "${OUTDIR}" 2>/dev/null

exec > "${OUTDIR}/lte_static.log" 2>&1

echo "============================================"
echo " Static IP Network Setup"
echo " $(date 2>/dev/null)"
echo "============================================"
echo ""

echo "[STEP 1] Starting USB ethernet driver..."
io-pkt-v4-hc -d asix speed=100,duplex=1,verbose &
sleep 3

echo "[STEP 2] Configuring static IP..."
ifconfig en5 172.16.42.1 netmask 255.255.255.0 up
sleep 1

echo "[STEP 3] Starting telnet/ftp services..."
inetd &
sleep 1

echo "[STEP 4] Network state:"
ifconfig en5 2>&1

echo ""
echo "============================================"
echo " Setup complete"
echo ""
echo " Car IP:  172.16.42.1"
echo " PC IP:   set to 172.16.42.2"
echo " Netmask: 255.255.255.0"
echo " Access:  telnet 172.16.42.1"
echo ""
echo " Non-persistent — reverts on reboot"
echo "============================================"
