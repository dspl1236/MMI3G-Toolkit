#!/bin/ksh
# scan_log.sh - Log GEM namespace data to SD card
# Called from scanner GEM screen buttons
# Also scans /dev/shmem for any CAN-mapped data

# --- platform.sh (shared variant detection + getTime helper) ---
# Defines MMI_VARIANT / MMI_VARIANT_ID / MMI_TRAIN and mmi_logstamp().
# Must be sourced before any code that calls mmi_logstamp.
_SDPATH_GUESS="${SDPATH:-${0%/*}}"
if [ -f "${_SDPATH_GUESS}/scripts/common/platform.sh" ]; then
    . "${_SDPATH_GUESS}/scripts/common/platform.sh"
elif [ -f "/mnt/efs-system/scripts/common/platform.sh" ]; then
    . "/mnt/efs-system/scripts/common/platform.sh"
else
    # Inline minimal fallback (DrGER2 review corrections applied)
    MMI_VARIANT="UNKNOWN"; MMI_VARIANT_ID=""
    for _f in /etc/pci-3g_*.cfg; do
        [ -f "$_f" ] || continue
        MMI_VARIANT_ID="$(echo "$_f" | sed -n 's,^/etc/pci-3g_\([0-9]*\)\.cfg$,\1,p')"
        case "$MMI_VARIANT_ID" in
            9304) MMI_VARIANT="MMI3G_BASIC" ;;
            9308) MMI_VARIANT="MMI3G_HIGH" ;;
            9411|9436|9478) MMI_VARIANT="MMI3GP" ;;
        esac
        break
    done
    MMI_TRAIN="$(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
    [ -z "$MMI_TRAIN" ] && MMI_TRAIN="$(sloginfo -m 10000 -s 5 2>/dev/null | sed -n 's/^.* +++ Train //p' | sed -n 1p)"
    [ -z "$MMI_TRAIN" ] && MMI_TRAIN="n/a"
    if [ "$MMI_VARIANT" = "MMI3GP" ] && echo "$MMI_TRAIN" | grep -q "_VW_"; then
        MMI_VARIANT="RNS850"
    fi
    mmi_logstamp() {
        if command -v getTime >/dev/null 2>&1; then
            _T="$(getTime 2>/dev/null)"
            [ -n "$_T" ] && { date -r "$_T" +%Y%m%d-%H%M%S 2>/dev/null || echo "epoch-$_T"; return 0; }
        fi
        date +%Y%m%d-%H%M%S 2>/dev/null
    }
    mmi_getTime() {
        if command -v getTime >/dev/null 2>&1; then getTime 2>/dev/null; else date +%s 2>/dev/null; fi
    }
fi
# --- end platform.sh source ---

SDCARD=""
for d in /mnt/sdcard10t12 /mnt/sdcard20t12 /mnt/sdcard10t11 /mnt/sdcard20t11; do
    [ -d "$d" ] && SDCARD="$d" && break
done
[ -z "$SDCARD" ] && echo "No SD card" && exit 1

mount -u $SDCARD
OUTDIR="${SDCARD}/var/scanner"
mkdir -p ${OUTDIR}
OUTFILE="${OUTDIR}/scan-$(mmi_logstamp).txt"

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
