#!/bin/ksh
# ============================================================
# MMI3G-Toolkit — Static IP Network Setup (AX88772D)
# Direct PC-to-car connection via USB Ethernet
# Uses device ID override for AX88772D adapters
# NO REBOOT NEEDED — works immediately
# ============================================================

_SDPATH_GUESS="${SDPATH:-${0%/*}}"
if [ -f "${_SDPATH_GUESS}/scripts/common/platform.sh" ]; then
    . "${_SDPATH_GUESS}/scripts/common/platform.sh"
fi
SDPATH="${_SDPATH_GUESS}"
OUTDIR="${SDPATH}/var/lte-setup"
mkdir -p "${OUTDIR}" 2>/dev/null

exec > "${OUTDIR}/lte_static_772d.log" 2>&1

echo "============================================"
echo " Static IP Network Setup (AX88772D)"
echo " $(date 2>/dev/null)"
echo "============================================"
echo ""

echo "[STEP 1] Checking USB ethernet state..."
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
        io-pkt-v4-hc -d asix did=0x772D,vid=0x0B95,speed=100,duplex=1,verbose &
        sleep 3
    fi
else
    echo "  en5 not found — starting fresh (772D override)"
    io-pkt-v4-hc -d asix did=0x772D,vid=0x0B95,speed=100,duplex=1,verbose &
    sleep 3
fi

echo ""
echo "[STEP 2] Configuring static IP..."
ifconfig en5 172.16.42.1 netmask 255.255.255.0 up
sleep 1

echo ""
echo "[STEP 3] Starting telnet/ftp services..."
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
echo " Setup complete (AX88772D mode)"
echo ""
echo " Car IP:  172.16.42.1"
echo " PC IP:   set to 172.16.42.2"
echo " Netmask: 255.255.255.0"
echo " Access:  telnet 172.16.42.1"
echo ""
echo " Non-persistent — reverts on reboot"
echo "============================================"
