#!/bin/ksh
# diskinfo.sh - Dump disk/partition info to SD card
SDCARD=""
for d in /mnt/sdcard10t12 /mnt/sdcard20t12 /mnt/sdcard10t11 /mnt/sdcard20t11; do
    [ -d "$d" ] && SDCARD="$d" && break
done
[ -z "$SDCARD" ] && exit 1
mount -u $SDCARD
mkdir -p ${SDCARD}/var/logs
{
echo "=== Disk Usage ==="
df -h 2>/dev/null
echo ""
echo "=== Mount Points ==="
mount 2>/dev/null
echo ""
echo "=== HDD Devices ==="
ls -la /dev/hd0* 2>/dev/null
echo ""
echo "=== Partition Layout ==="
fdisk /dev/hd0 show 2>/dev/null
} > "${SDCARD}/var/logs/diskinfo-$(date +%Y%m%d-%H%M%S).txt"
sync
echo "Disk info saved"
