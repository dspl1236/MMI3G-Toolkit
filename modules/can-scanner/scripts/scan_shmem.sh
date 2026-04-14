#!/bin/ksh
# scan_shmem.sh - Deep scan of shared memory for CAN bus data
# Dumps all readable shared memory to SD for offline analysis

SDCARD=""
for d in /mnt/sdcard10t12 /mnt/sdcard20t12 /mnt/sdcard10t11 /mnt/sdcard20t11; do
    [ -d "$d" ] && SDCARD="$d" && break
done
[ -z "$SDCARD" ] && echo "No SD card" && exit 1

mount -u $SDCARD
OUTDIR="${SDCARD}/var/scanner/shmem-$(date +%Y%m%d-%H%M%S)"
mkdir -p ${OUTDIR}

echo "Dumping shared memory..."

# Dump all shmem files
for f in /dev/shmem/*; do
    if [ -f "$f" ]; then
        BASENAME=$(basename "$f")
        cp "$f" "${OUTDIR}/${BASENAME}" 2>/dev/null
    fi
done

# Also capture pidin memory map for the main MMI process
pidin -fNamb 2>/dev/null > ${OUTDIR}/_pidin_memory.txt

# Capture full syslog
sloginfo 2>/dev/null > ${OUTDIR}/_syslog_full.txt

# List all QNX resource managers
ls -laR /dev/ 2>/dev/null > ${OUTDIR}/_dev_tree.txt

sync
echo "Shared memory dumped to: ${OUTDIR}"
echo "Files: $(ls ${OUTDIR} | wc -l)"
