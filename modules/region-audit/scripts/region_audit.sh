#!/bin/ksh
# ============================================================
# region_audit.sh
# ============================================================
# Read-only region / VZE audit report for MMI3G+ and RNS-850.
# Writes a focused report to the SD card and never changes
# persistence or firmware state.
#
# If the optional per3-reader bundle is already installed, this
# script will also capture the live per3 values that back the GEM
# screen. Otherwise it falls back to the filesystem/runtime data
# that is visible from shell.
# ============================================================

# --- platform.sh (shared variant detection + getTime helper) ---
_SDPATH_GUESS="${SDPATH:-${0%/*}}"
if [ -f "${_SDPATH_GUESS}/scripts/common/platform.sh" ]; then
    . "${_SDPATH_GUESS}/scripts/common/platform.sh"
elif [ -f "/mnt/efs-system/scripts/common/platform.sh" ]; then
    . "/mnt/efs-system/scripts/common/platform.sh"
else
    MMI_VARIANT="UNKNOWN"
    MMI_VARIANT_ID=""
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
    MMI_SW_VERSION="$(sed -n 's/^version = //p' /etc/version/MainUnit-version.txt 2>/dev/null | sed -n 1p)"
    [ -z "$MMI_SW_VERSION" ] && MMI_SW_VERSION="n/a"
    MMI_HW_SAMPLE="$([ -f /etc/hwSample ] && cat /etc/hwSample 2>/dev/null)"
    [ -z "$MMI_HW_SAMPLE" ] && MMI_HW_SAMPLE="n/a"
    mmi_getTime() {
        if command -v getTime >/dev/null 2>&1; then
            getTime 2>/dev/null
        else
            date +%s 2>/dev/null
        fi
    }
    mmi_logstamp() {
        if command -v getTime >/dev/null 2>&1; then
            _T="$(getTime 2>/dev/null)"
            [ -n "$_T" ] && { date -r "$_T" +%Y%m%d-%H%M%S 2>/dev/null || echo "epoch-$_T"; return 0; }
        fi
        date +%Y%m%d-%H%M%S 2>/dev/null
    }
fi
# --- end platform.sh source ---

find_sdcard() {
    for d in /fs/sda1 /fs/sda0 /fs/sd1 /fs/sd0 /mnt/sdcard10t12 /mnt/sdcard20t12 /mnt/sdcard10t11 /mnt/sdcard20t11; do
        [ -d "$d" ] && echo "$d" && return 0
    done
    return 1
}

read_file_value() {
    _path="$1"
    _fallback="$2"
    if [ -f "$_path" ]; then
        _val="$(cat "$_path" 2>/dev/null | sed 's/"//g' | sed -n 1p)"
        [ -n "$_val" ] && echo "$_val" && return 0
    fi
    echo "$_fallback"
}

starter_variant() {
    sed -n 's,^<VariantName>,,;s,</VariantName>\r\?$,,p' /etc/mmi3g-srv-starter.cfg 2>/dev/null | sed -n 1p
}

find_per3_reader() {
    for p in \
        /mnt/efs-system/scripts/Per3Reader/per3_read.sh \
        /scripts/Per3Reader/per3_read.sh \
        /fs/sda1/scripts/per3_read.sh \
        /fs/sda0/scripts/per3_read.sh
    do
        [ -f "$p" ] && echo "$p" && return 0
    done
    return 1
}

region_label() {
    case "$1" in
        -1) echo "unknown" ;;
        0) echo "EU" ;;
        1) echo "Rest of the world" ;;
        2) echo "North America" ;;
        3) echo "China" ;;
        4) echo "Japan" ;;
        5) echo "Korea" ;;
        *) echo "unmapped" ;;
    esac
}

navdb_label() {
    case "$1" in
        -1) echo "unknown" ;;
        0) echo "Default" ;;
        1) echo "EU" ;;
        2) echo "North America" ;;
        3) echo "South America" ;;
        4) echo "AGCC" ;;
        5) echo "Korea" ;;
        6) echo "Japan" ;;
        7) echo "China" ;;
        8) echo "Asia/Pacific" ;;
        9) echo "South Africa" ;;
        10) echo "Australia" ;;
        11) echo "India" ;;
        12) echo "Taiwan (ROC)" ;;
        13) echo "AGCC_2 (arabic)" ;;
        14) echo "Turkey" ;;
        15) echo "Chile" ;;
        99) echo "no navi db" ;;
        *) echo "unmapped" ;;
    esac
}

per3_capture() {
    _reader="$1"
    _type="$2"
    _addr="$3"
    _label="$4"
    _value="$(ksh "$_reader" "$_type" "$_addr" 2>/dev/null | sed -n 1p)"
    if [ -n "$_value" ]; then
        printf "  %-32s %s\n" "$_label" "$_value"
    else
        printf "  %-32s %s\n" "$_label" "unavailable"
    fi
}

SDCARD="$(find_sdcard)"
if [ -z "$SDCARD" ]; then
    echo "No SD card found."
    exit 1
fi

mount -u "$SDCARD" 2>/dev/null
OUTDIR="${SDCARD}/var/region-audit"
OUTFILE="${OUTDIR}/region-audit-$(mmi_logstamp).txt"
mkdir -p "${OUTDIR}" 2>/dev/null

HMI_TYPE="$(read_file_value /etc/hmi_type.txt n/a)"
HMI_REGION="$(read_file_value /etc/hmi_country.txt n/a)"
STARTER_VARIANT="$(starter_variant)"
[ -z "$STARTER_VARIANT" ] && STARTER_VARIANT="n/a"
TRAIN_SHMEM="$(read_file_value /dev/shmem/sw_trainname.txt n/a)"
PER3_READER="$(find_per3_reader)"

{
echo "################################################################"
echo "#  MMI3G-Toolkit Region / VZE Audit"
echo "#  Generated: $(date) [QNX date]"
echo "#  Epoch from getTime: $(mmi_getTime 2>/dev/null || echo n/a)"
echo "################################################################"
echo ""

echo "================================================================"
echo "  IDENTIFICATION"
echo "================================================================"
printf "  %-32s %s (id=%s)\n" "Variant:" "${MMI_VARIANT}" "${MMI_VARIANT_ID:-n/a}"
printf "  %-32s %s\n" "Train name (helper):" "${MMI_TRAIN}"
printf "  %-32s %s\n" "Train name (/dev/shmem):" "${TRAIN_SHMEM}"
printf "  %-32s %s\n" "MU software version:" "${MMI_SW_VERSION}"
printf "  %-32s %s\n" "MU hwSample:" "${MMI_HW_SAMPLE}"
printf "  %-32s %s\n" "HMI type:" "${HMI_TYPE}"
printf "  %-32s %s\n" "HMI region file:" "${HMI_REGION}"
printf "  %-32s %s\n" "Starter VariantName:" "${STARTER_VARIANT}"
echo ""

echo "================================================================"
echo "  REGION-RELATED FILES"
echo "================================================================"
for f in /etc/hmi_country.txt /etc/hmi_type.txt /etc/hwSample /etc/version/MainUnit-version.txt /etc/mmi3g-srv-starter.cfg /dev/shmem/sw_trainname.txt; do
    if [ -f "$f" ]; then
        SIZE="$(ls -l "$f" 2>/dev/null | awk '{print $5}')"
        printf "  %-32s present (%s bytes)\n" "$f" "${SIZE:-?}"
    else
        printf "  %-32s missing\n" "$f"
    fi
done
echo ""

echo "================================================================"
echo "  GEM / MODULE INSTALL STATE"
echo "================================================================"
if [ -f /mnt/efs-system/engdefs/RegionAuditMain.esd ]; then
    echo "  RegionAuditMain.esd:             installed"
else
    echo "  RegionAuditMain.esd:             not installed"
fi
if [ -f /mnt/efs-system/lsd/AppDevelopment.jar ]; then
    echo "  AppDevelopment.jar:              present"
else
    echo "  AppDevelopment.jar:              missing"
fi
if [ -n "$PER3_READER" ]; then
    printf "  %-32s %s\n" "per3-reader shell client:" "$PER3_READER"
else
    echo "  per3-reader shell client:        not installed"
fi
echo ""

echo "================================================================"
echo "  LIVE PER3 VALUES"
echo "================================================================"
echo "  GEM screen addresses:"
echo "    0x0011000F  internal region code"
echo "    0x00100000  active HDD nav DB"
echo "    0x0010002D  traffic sign recognition"
echo "    0x0014005D  traffic sign CAN"
echo "    0x0013FFFE  VZE menu routing"
echo ""
if [ -n "$PER3_READER" ]; then
    mkdir -p /tmp/per3req 2>/dev/null
    REGION_CODE="$(ksh "$PER3_READER" int 0x0011000F 2>/dev/null | sed -n 1p)"
    NAVDB_CODE="$(ksh "$PER3_READER" int 0x00100000 2>/dev/null | sed -n 1p)"
    if [ -n "$REGION_CODE" ]; then
        printf "  %-32s %s (%s)\n" "Internal region code:" "$REGION_CODE" "$(region_label "$REGION_CODE")"
    else
        echo "  Internal region code:            unavailable"
    fi
    if [ -n "$NAVDB_CODE" ]; then
        printf "  %-32s %s (%s)\n" "Active HDD nav DB:" "$NAVDB_CODE" "$(navdb_label "$NAVDB_CODE")"
    else
        echo "  Active HDD nav DB:               unavailable"
    fi
    per3_capture "$PER3_READER" int 0x0010002D "Traffic Sign Recognition:"
    per3_capture "$PER3_READER" int 0x0014005D "Traffic Sign CAN:"
    per3_capture "$PER3_READER" int 0x0013FFFE "VZE menu routing:"
else
    echo "  per3-reader not installed, so shell cannot read live persistence."
    echo "  Open GEM /region to view those values live on-screen."
fi
echo ""

echo "================================================================"
echo "  INTERPRETATION NOTES"
echo "================================================================"
echo "  Internal region code mapping:"
echo "    -1 unknown, 0 EU, 1 Rest of world, 2 North America,"
echo "    3 China, 4 Japan, 5 Korea"
echo ""
echo "  VZE investigation workflow:"
echo "    1. Compare HMI region file vs internal region code."
echo "    2. Check whether Traffic Sign Recognition is enabled."
echo "    3. Check whether Traffic Sign CAN and menu routing are non-zero."
echo "    4. If shell reads are unavailable, use the GEM screen for live values."
echo ""

echo "################################################################"
echo "# Report written to: ${OUTFILE}"
echo "################################################################"
} > "${OUTFILE}" 2>&1

sync
echo "Region audit report written."
echo "Output: ${OUTFILE}"
