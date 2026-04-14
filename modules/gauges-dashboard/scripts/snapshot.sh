#!/bin/ksh
# snapshot.sh - Save vehicle data snapshot to SD card
# Called from GEM GaugesDashboard screen

SDCARD=""
for d in /mnt/sdcard10t12 /mnt/sdcard20t12 /mnt/sdcard10t11 /mnt/sdcard20t11; do
    if [ -d "$d" ]; then
        SDCARD="$d"
        break
    fi
done

if [ -z "$SDCARD" ]; then
    echo "No SD card found"
    exit 1
fi

mount -u $SDCARD
OUTDIR="${SDCARD}/var/snapshots"
mkdir -p ${OUTDIR}
OUTFILE="${OUTDIR}/snap-$(date +%Y%m%d-%H%M%S).txt"

echo "============================================" > ${OUTFILE}
echo " MMI3G+ Vehicle Data Snapshot" >> ${OUTFILE}
echo " $(date)" >> ${OUTFILE}
echo " Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)" >> ${OUTFILE}
echo "============================================" >> ${OUTFILE}
echo "" >> ${OUTFILE}

echo "--- Uptime ---" >> ${OUTFILE}
uptime >> ${OUTFILE} 2>&1
echo "" >> ${OUTFILE}

echo "--- Memory ---" >> ${OUTFILE}
pidin info >> ${OUTFILE} 2>&1
echo "" >> ${OUTFILE}

echo "--- Mounted Filesystems ---" >> ${OUTFILE}
df -h >> ${OUTFILE} 2>&1
echo "" >> ${OUTFILE}

echo "--- Network Interfaces ---" >> ${OUTFILE}
ifconfig -a >> ${OUTFILE} 2>&1
echo "" >> ${OUTFILE}

echo "--- Routing Table ---" >> ${OUTFILE}
netstat -rn >> ${OUTFILE} 2>&1
echo "" >> ${OUTFILE}

echo "--- DNS Config ---" >> ${OUTFILE}
cat /etc/resolv.conf >> ${OUTFILE} 2>&1
echo "" >> ${OUTFILE}

echo "--- USB Devices ---" >> ${OUTFILE}
ls -la /dev/umass* >> ${OUTFILE} 2>&1
usb >> ${OUTFILE} 2>&1
echo "" >> ${OUTFILE}

echo "--- Process Count ---" >> ${OUTFILE}
pidin | wc -l >> ${OUTFILE} 2>&1
echo "" >> ${OUTFILE}

echo "--- HDD Status ---" >> ${OUTFILE}
ls -la /dev/hd0* >> ${OUTFILE} 2>&1
echo "" >> ${OUTFILE}

echo "Snapshot saved: ${OUTFILE}"
sync
