#!/bin/ksh
# ============================================================
# MMI3G Map/Nav Database Parser
# Extracts nav DB metadata, activation state, region info
# ============================================================
#
# READ-ONLY. Copies nav metadata to SD card for analysis.
#
# The Harman navigation system uses a descriptor file called
# acios_db.ini to identify the installed map database. This
# script extracts that file plus related metadata so you can
# know exactly what maps are installed, for what regions,
# at what version.
#
# Inspired by jilleb/mib2-toolbox MapConfigParser.html.
#
# Output: var/maps/map-info-YYYYMMDD-HHMMSS.txt and
#         var/maps/<timestamp>/ with copied config files
# ============================================================

SDPATH="${1:-$(dirname $0)}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTDIR="${SDPATH}/var/maps"
OUTFILE="${OUTDIR}/map-info-${TIMESTAMP}.txt"
FILESDIR="${OUTDIR}/${TIMESTAMP}"
mkdir -p ${OUTDIR} ${FILESDIR}

{
echo "################################################################"
echo "#  MMI3G-Toolkit Map / Nav DB Parser Report"
echo "#  Generated: $(date)"
echo "#  Train:   $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo "################################################################"
echo ""

# === acios_db.ini — the nav database descriptor ===
echo "================================================================"
echo "  ACIOS_DB.INI — Navigation Database Descriptor"
echo "================================================================"
echo ""

for candidate in \
    /mnt/lvm/acios_db.ini \
    /mnt/hdd/acios_db.ini \
    /mnt/efs-persist/acios_db.ini \
    /mnt/hdd/mme_db/acios_db.ini \
; do
    if [ -f "$candidate" ]; then
        echo "--- Found at: $candidate ---"
        cat "$candidate" 2>/dev/null
        cp "$candidate" "${FILESDIR}/acios_db.ini" 2>/dev/null
        echo ""
        break
    fi
done

# === FSC activation files ===
echo "================================================================"
echo "  FSC ACTIVATION FILES"
echo "================================================================"
echo ""
for searchdir in /mnt/efs-persist /mnt/persist /mnt/hdd /mnt/efs-system; do
    if [ -d "$searchdir" ]; then
        for f in $(find "$searchdir" -type f -name "*.fsc" 2>/dev/null); do
            echo "--- $f ($(wc -c < "$f" 2>/dev/null) bytes) ---"
            file "$f" 2>/dev/null
            # Copy to SD for offline analysis
            BASENAME=$(basename "$f")
            cp "$f" "${FILESDIR}/${BASENAME}" 2>/dev/null
            # Try to read first few bytes as text
            head -c 200 "$f" 2>/dev/null | xxd | head -5
            echo ""
        done
    fi
done

# === Nav HDD partition / mount ===
echo "================================================================"
echo "  NAV HDD PARTITION"
echo "================================================================"
echo ""
echo "--- Mount points ---"
mount 2>/dev/null | grep -i "nav\|map\|hdd\|lvm"
echo ""

echo "--- /mnt/hdd tree (top 50) ---"
if [ -d /mnt/hdd ]; then
    find /mnt/hdd -maxdepth 3 2>/dev/null | head -50
fi
echo ""

# === MME/Map database directory ===
echo "================================================================"
echo "  MAP DATABASE DIRECTORY"
echo "================================================================"
echo ""
for candidate in /mnt/hdd/mme_db /mnt/hdd/maps /mnt/hdd/Maps /mnt/hdd/navigation; do
    if [ -d "$candidate" ]; then
        echo "--- Contents of $candidate ---"
        ls -la "$candidate" 2>/dev/null | head -40
        echo ""
        # Find metadata files
        for f in $(find "$candidate" -maxdepth 3 -type f \( \
            -name "*.ini" \
            -o -name "version*" \
            -o -name "*.meta" \
            -o -name "*.xml" \
            -o -name "version.txt" \
            -o -name "ChecksumFile" \
            -o -name "package*.info" \
        \) 2>/dev/null | head -20); do
            echo "  --- $f ---"
            if [ -f "$f" ]; then
                SIZE=$(wc -c < "$f" 2>/dev/null)
                if [ "$SIZE" -lt 5000 ]; then
                    cat "$f" 2>/dev/null
                    BASENAME=$(basename "$f")
                    cp "$f" "${FILESDIR}/${BASENAME}" 2>/dev/null
                else
                    echo "  (file too large: $SIZE bytes — copying to SD anyway)"
                    BASENAME=$(basename "$f")
                    cp "$f" "${FILESDIR}/${BASENAME}" 2>/dev/null
                fi
                echo ""
            fi
        done
    fi
done

# === MAC address (needed for FSC activation) ===
echo "================================================================"
echo "  MAC ADDRESS (needed for FSC activation lookup)"
echo "================================================================"
echo ""
ifconfig 2>/dev/null | grep -i "hwaddr\|ether\|address" | head -5
echo ""

# === Nav unblocker state ===
echo "================================================================"
echo "  NAV UNBLOCKER STATE"
echo "================================================================"
echo ""
if [ -f /mnt/efs-system/usr/bin/manage_cd.sh ]; then
    if grep -q "acios_db.ini" /mnt/efs-system/usr/bin/manage_cd.sh 2>/dev/null; then
        echo "STATUS: UNBLOCKER PATCH DETECTED (nav DB activation bypassed)"
        echo "Patch lines:"
        grep -n "acios_db\|slay\|Unblocker" /mnt/efs-system/usr/bin/manage_cd.sh 2>/dev/null
    else
        echo "STATUS: manage_cd.sh is factory (FSC activation in effect)"
    fi
else
    echo "STATUS: manage_cd.sh not found"
fi
echo ""

# === Summary ===
echo "################################################################"
echo "#  Summary"
echo "################################################################"
echo ""
echo "Files copied to SD card: ${FILESDIR}"
ls -la "${FILESDIR}" 2>/dev/null
echo ""
echo "For further analysis, open the .ini / .xml files in a text editor."
echo "Use MapConfigParser.html (web tool) to render the acios_db.ini"
echo "as a human-readable table."

} > ${OUTFILE} 2>&1

echo "Map parser complete. Output: ${OUTFILE}"
sync
