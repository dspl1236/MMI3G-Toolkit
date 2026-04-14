#!/bin/ksh
# syslog.sh - Dump QNX syslog to SD card
SDCARD=""
for d in /mnt/sdcard10t12 /mnt/sdcard20t12 /mnt/sdcard10t11 /mnt/sdcard20t11; do
    [ -d "$d" ] && SDCARD="$d" && break
done
[ -z "$SDCARD" ] && exit 1
mount -u $SDCARD
mkdir -p ${SDCARD}/var/logs
sloginfo > "${SDCARD}/var/logs/syslog-$(date +%Y%m%d-%H%M%S).txt" 2>&1
sync
echo "Syslog saved"
