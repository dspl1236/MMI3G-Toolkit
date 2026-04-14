#!/bin/ksh
# netstatus.sh - Network connectivity status dump
SDCARD=""
for d in /mnt/sdcard10t12 /mnt/sdcard20t12 /mnt/sdcard10t11 /mnt/sdcard20t11; do
    [ -d "$d" ] && SDCARD="$d" && break
done
[ -z "$SDCARD" ] && exit 1
mount -u $SDCARD
mkdir -p ${SDCARD}/var/logs
{
echo "=== Network Status ==="
echo "Date: $(date)"
echo ""
echo "--- Interfaces ---"
ifconfig -a 2>/dev/null
echo ""
echo "--- Routing ---"
netstat -rn 2>/dev/null
echo ""
echo "--- DNS ---"
cat /etc/resolv.conf 2>/dev/null
echo ""
echo "--- Connections ---"
netstat -an 2>/dev/null
echo ""
echo "--- ARP ---"
arp -a 2>/dev/null
} > "${SDCARD}/var/logs/netstatus-$(date +%Y%m%d-%H%M%S).txt"
sync
echo "Network status saved"
