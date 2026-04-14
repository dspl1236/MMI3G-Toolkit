#!/bin/ksh
# fullreport.sh - Comprehensive system report to SD card
SDCARD=""
for d in /mnt/sdcard10t12 /mnt/sdcard20t12 /mnt/sdcard10t11 /mnt/sdcard20t11; do
    [ -d "$d" ] && SDCARD="$d" && break
done
[ -z "$SDCARD" ] && exit 1
mount -u $SDCARD
mkdir -p ${SDCARD}/var/reports
OUTFILE="${SDCARD}/var/reports/report-$(date +%Y%m%d-%H%M%S).txt"

{
echo "============================================"
echo " MMI3G+ Full System Report"
echo " $(date)"
echo "============================================"
echo ""
echo "=== FIRMWARE ==="
cat /dev/shmem/sw_trainname.txt 2>/dev/null
echo ""
echo "=== UPTIME ==="
uptime 2>/dev/null
echo ""
echo "=== SYSTEM INFO ==="
pidin info 2>/dev/null
echo ""
echo "=== PROCESS LIST ==="
pidin -fNap 2>/dev/null
echo ""
echo "=== MOUNTED FILESYSTEMS ==="
mount 2>/dev/null
echo ""
echo "=== DISK USAGE ==="
df -h 2>/dev/null
echo ""
echo "=== NETWORK INTERFACES ==="
ifconfig -a 2>/dev/null
echo ""
echo "=== ROUTING ==="
netstat -rn 2>/dev/null
echo ""
echo "=== DNS ==="
cat /etc/resolv.conf 2>/dev/null
echo ""
echo "=== SYSLOG (last 100 lines) ==="
sloginfo 2>/dev/null | tail -100
echo ""
echo "=== GEM SCREENS ==="
ls -la /mnt/efs-system/engdefs/*.esd 2>/dev/null
echo ""
echo "=== INSTALLED SCRIPTS ==="
ls -laR /mnt/efs-system/scripts/ 2>/dev/null
echo ""
echo "=== HDD PARTITIONS ==="
ls -la /dev/hd0* 2>/dev/null
echo ""
echo "=== USB ==="
usb 2>/dev/null
echo ""
echo "============================================"
echo " End of Report"
echo "============================================"
} > ${OUTFILE}

sync
echo "Report saved: ${OUTFILE}"
