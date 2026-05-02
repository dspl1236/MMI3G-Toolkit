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
#
# NOTE: vdev-medialauncher may already start io-pkt with speed=10
# from /etc/umass-enum_def.cfg. We detect this and fix it.

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

echo "[STEP 1] Checking USB ethernet state..."
# Check if vdev-medialauncher already started io-pkt + en5
EXISTING=$(ifconfig en5 2>/dev/null)
if [ -n "$EXISTING" ]; then
    echo "  [OK] en5 already exists (vdev-medialauncher)"
    echo "  Upgrading speed: 10baseT → 100baseTX"
    ifconfig en5 media 100baseTX mediaopt full-duplex 2>&1
    if [ $? -eq 0 ]; then
        echo "  [OK] Speed upgraded to 100baseTX full-duplex"
    else
        echo "  [WARN] ifconfig media change failed — killing and restarting"
        slay -f io-pkt-v4-hc 2>/dev/null
        sleep 2
        io-pkt-v4-hc -d asix speed=100,duplex=1,verbose &
        sleep 3
    fi
else
    echo "  en5 not found — starting fresh"
    io-pkt-v4-hc -d asix speed=100,duplex=1,verbose &
    sleep 3
fi

echo ""
echo "[STEP 2] Configuring static IP..."
ifconfig en5 172.16.42.1 netmask 255.255.255.0 up
sleep 1

echo ""
echo "[STEP 3] Starting telnet/ftp services..."
# Check if inetd already running
pidin -p inetd -f a 2>/dev/null | grep -q inetd
if [ $? -eq 0 ]; then
    echo "  [OK] inetd already running"
else
    inetd &
    sleep 1
    echo "  [OK] inetd started"
fi

echo ""
echo "[STEP 4] Network state:"
ifconfig en5 2>&1
echo ""
nicinfo en5 2>&1

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
