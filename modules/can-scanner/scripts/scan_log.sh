#!/bin/ksh
# scan_log.sh - Log GEM namespace data to SD card
# Called from scanner GEM screen buttons
# Also scans /dev/shmem for any CAN-mapped data

SDCARD=""
for d in /mnt/sdcard10t12 /mnt/sdcard20t12 /mnt/sdcard10t11 /mnt/sdcard20t11; do
    [ -d "$d" ] && SDCARD="$d" && break
done
[ -z "$SDCARD" ] && echo "No SD card" && exit 1

mount -u $SDCARD
OUTDIR="${SDCARD}/var/scanner"
mkdir -p ${OUTDIR}
OUTFILE="${OUTDIR}/scan-$(date +%Y%m%d-%H%M%S).txt"

{
echo "========================================"
echo " CAN/Namespace Scan Results"
echo " $(date)"
echo " Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo "========================================"
echo ""

echo "--- /dev/shmem contents ---"
ls -la /dev/shmem/ 2>/dev/null
echo ""

echo "--- shmem readable files ---"
for f in /dev/shmem/*; do
    if [ -f "$f" ]; then
        SIZE=$(ls -l "$f" 2>/dev/null | awk '{print $5}')
        if [ "$SIZE" -gt 0 ] 2>/dev/null; then
            echo "[$f] (${SIZE} bytes):"
            # Only show first 200 bytes of each
            dd if="$f" bs=200 count=1 2>/dev/null | strings
            echo ""
        fi
    fi
done

echo "--- /dev/can* devices ---"
ls -la /dev/can* 2>/dev/null || echo "No /dev/can devices"
echo ""

echo "--- /dev/io-net/ ---"
ls -la /dev/io-net/ 2>/dev/null || echo "No io-net"
echo ""

echo "--- CAN-related processes ---"
pidin -fNA 2>/dev/null | grep -i "can\|bus\|gateway\|becker\|mme\|dsi\|j9" 
echo ""

echo "--- Syslog CAN entries (last 50) ---"
sloginfo 2>/dev/null | grep -i "can\|bus\|per\|key\|val\|dsi\|namespace" | tail -50
echo ""

echo "--- QNX resource managers ---"
ls /dev/ 2>/dev/null | grep -i "can\|bus\|dsi\|mme"
echo ""

echo "========================================"
echo " Scan complete. Check for non-zero values"
echo " in the GEM scanner screens."
echo "========================================"
} > ${OUTFILE}

sync
echo "Scan saved: ${OUTFILE}"
