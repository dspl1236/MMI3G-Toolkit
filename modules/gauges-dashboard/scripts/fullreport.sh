#!/bin/ksh
# fullreport.sh - Comprehensive system report to SD card
# --- platform.sh (shared variant detection + getTime helper) ---
# Defines MMI_VARIANT / MMI_VARIANT_ID / MMI_TRAIN and mmi_logstamp().
# Must be sourced before any code that calls mmi_logstamp.
_SDPATH_GUESS="${SDPATH:-$(dirname $0)}"
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
            9411|9478) MMI_VARIANT="MMI3GP" ;;
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
[ -z "$SDCARD" ] && exit 1
mount -u $SDCARD
mkdir -p ${SDCARD}/var/reports
OUTFILE="${SDCARD}/var/reports/report-$(mmi_logstamp).txt"

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
