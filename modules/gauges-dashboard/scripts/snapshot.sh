#!/bin/ksh
# snapshot.sh - Save vehicle data snapshot to SD card
# Called from GEM GaugesDashboard screen

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
OUTFILE="${OUTDIR}/snap-$(mmi_logstamp).txt"

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
