#!/bin/ksh
# ============================================================
# MMI3G Variant / Adaptation Dumper
# Dumps per3 car-function, car-device, CAN assignment values
# ============================================================
#
# READ-ONLY. Writes a structured report to SD card only.
#
# Reads the per3 namespace via the keyValue mechanism —
# the same API that GEM screens use for live data display.
# We enumerate all the known addresses from our research
# (see research/PER3_ADDRESS_MAP.md) and capture their
# current values on this specific vehicle.
#
# Inspired by jilleb/mib2-toolbox Adaptations & VariantInfo.
#
# Output: var/variant/variant-YYYYMMDD-HHMMSS.txt on SD card
# ============================================================

SDPATH="${1:-$(dirname $0)}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTDIR="${SDPATH}/var/variant"
OUTFILE="${OUTDIR}/variant-${TIMESTAMP}.txt"
mkdir -p ${OUTDIR}

# QNX utility to read per3 values — location varies by MMI variant
PER3_READ=""
for candidate in /usr/bin/per3_read /opt/bin/per3_read /usr/bin/readper3 /bin/per3; do
    if [ -x "$candidate" ]; then
        PER3_READ="$candidate"
        break
    fi
done

# Helper to read a per3 address
# Usage: read_per3 <addr_hex> <type>  (type = int|string)
read_per3() {
    ADDR=$1
    TYPE=${2:-int}
    if [ -n "$PER3_READ" ]; then
        "$PER3_READ" $ADDR 2>/dev/null
    else
        # Fall back to reading from /dev/shmem or using sloginfo-style mechanism
        # (some variants expose per3 via shmem snapshot files)
        if [ -f /dev/shmem/per3_$ADDR ]; then
            cat /dev/shmem/per3_$ADDR 2>/dev/null
        else
            echo "n/a (no per3 reader)"
        fi
    fi
}

{
echo "################################################################"
echo "#  MMI3G-Toolkit Variant / Adaptation Dump"
echo "#  Generated: $(date)"
echo "#  Train:   $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo "################################################################"
echo ""

if [ -z "$PER3_READ" ]; then
    echo "!!! No per3 reader utility found. Some sections will show n/a."
    echo "    Searched: /usr/bin/per3_read /opt/bin/per3_read /usr/bin/readper3 /bin/per3"
    echo ""
    echo "    The GEM key-value system accesses per3 at the Java layer."
    echo "    This script falls back to /dev/shmem/ snapshots if available."
    echo ""
fi

# === Static strings ===
echo "================================================================"
echo "  IDENTIFICATION STRINGS"
echo "================================================================"
for ADDR_DESC in \
    "0x00120004|Train name" \
    "0x00120001|Current version" \
    "0x00110006|VW spare part number" \
    "0x0011000A|Serial number" \
    "0x0011000C|VW system name" \
    "0x000103EE|Display SPN (1)" \
    "0x000103F0|Display SPN (2)" \
    "0x000103F3|Display SPN (3)" \
    "0x00010400|HW version front" \
    "0x00010401|HW version right" \
    "0x00010402|HW version left" \
    "0x00500009|SW-Version" \
    "0x0050000E|HW-Version" \
    "0x0050000F|Touchpad version" \
; do
    ADDR=${ADDR_DESC%|*}
    DESC=${ADDR_DESC#*|}
    VAL=$(read_per3 $ADDR string)
    printf "  %-24s %s = %s\n" "$DESC" "$ADDR" "$VAL"
done
echo ""

# === Live sensor data ===
echo "================================================================"
echo "  LIVE SENSOR DATA"
echo "================================================================"
for ADDR_DESC in \
    "0x00000004|FOT temperature" \
    "0x00000023|Battery voltage (x100mV)" \
    "0x00000024|Cable code info (hex)" \
    "0x00120000|Count down" \
    "0x00120002|HW index IT" \
    "0x00120003|Unexpected resets" \
    "0x00300007|Connected HUC/BTHS (hex)" \
    "0x00500000|Eject disabled" \
; do
    ADDR=${ADDR_DESC%|*}
    DESC=${ADDR_DESC#*|}
    VAL=$(read_per3 $ADDR int)
    printf "  %-32s %s = %s\n" "$DESC" "$ADDR" "$VAL"
done
echo ""

# === Car Device List ===
echo "================================================================"
echo "  CAR DEVICE LIST (0x001000xx) — installed features"
echo "================================================================"
for ADDR_DESC in \
    "0x00100000|Air condition" \
    "0x00100001|Aux heating" \
    "0x00100002|Seat heating (initial)" \
    "0x00100010|Head-up display" \
    "0x00100011|Adaptive cruise control (ACC)" \
    "0x00100012|Suspension (air)" \
    "0x00100013|Tyre pressure (RDK)" \
    "0x00100014|Interior light" \
    "0x00100015|Exterior light" \
    "0x00100016|Exterior light 2" \
    "0x00100017|Fog light" \
    "0x00100018|Park distance control" \
    "0x00100019|Rearview camera" \
    "0x0010001A|Wiper" \
    "0x0010001B|Door locking" \
    "0x0010001C|Mirror" \
    "0x0010001D|On-board computer" \
    "0x0010001E|Clock" \
    "0x0010001F|Service interval" \
    "0x00100020|Central units master (ZEM)" \
    "0x00100021|Compass" \
    "0x00100022|Charisma (Drive Select)" \
    "0x00100023|Lane departure warning (HCA)" \
    "0x00100024|Lane change assist (SWA)" \
    "0x00100025|Braking way reduction (AWV)" \
    "0x00100026|Seat memory front" \
    "0x00100027|Seat memory rear" \
    "0x00100028|Hybrid" \
    "0x00100029|Universal garage door opener" \
    "0x0010002A|Night vision" \
    "0x0010002B|Sideview camera" \
    "0x0010002C|Reversible seat-belt tensioner (RGS)" \
    "0x0010002D|Traffic sign recognition (VZE)" \
    "0x0010002E|Rear seat entertainment" \
    "0x0010002F|Weariness recognition (MKE)" \
    "0x00100030|MFL (multi-function wheel)" \
    "0x00100031|VIN" \
    "0x00100032|Battery level gauge" \
    "0x00100033|Oil level gauge" \
    "0x00100034|Sliding roof" \
    "0x00100035|Trailer" \
    "0x00100036|Driver monitoring" \
    "0x00100037|Programmed keys" \
    "0x00100064|Transmission (#24)" \
    "0x00100070|Seat heating" \
    "0x00100071|Tilt angle display" \
    "0x00100088|Day/night map mode" \
    "0x00100089|RDK (tyre monitoring)" \
; do
    ADDR=${ADDR_DESC%|*}
    DESC=${ADDR_DESC#*|}
    VAL=$(read_per3 $ADDR int)
    printf "  %-40s %s = %s\n" "$DESC" "$ADDR" "$VAL"
done
echo ""

# === CAN Bus Assignment ===
echo "================================================================"
echo "  CAN BUS ASSIGNMENT (0x001400xx) — 0=Komfort, 1=Dashboard"
echo "================================================================"
for ADDR_DESC in \
    "0x0014003D|Air condition" \
    "0x0014003F|Auxiliary heating" \
    "0x00140040|Head-up display" \
    "0x00140041|Adaptive cruise control" \
    "0x00140042|Suspension" \
    "0x00140043|Tyre pressure (RDK)" \
    "0x00140044|Interior light" \
    "0x00140045|Exterior light" \
    "0x00140046|Park distance control" \
    "0x00140047|Rearview camera" \
    "0x00140048|Wiper" \
    "0x00140049|Door locking" \
    "0x0014004A|Mirror" \
    "0x0014004B|On-board computer" \
    "0x0014004C|Seat memory front" \
    "0x0014004D|Clock" \
    "0x0014004E|Service interval" \
    "0x0014004F|Central units master (ZEM)" \
    "0x00140050|Universal garage door opener" \
    "0x00140051|Compass" \
    "0x00140053|Charisma" \
    "0x00140054|Night vision" \
    "0x00140055|Lane departure warning" \
    "0x00140056|Lane change assist" \
    "0x00140057|Braking way reduction" \
    "0x00140059|Hybrid" \
    "0x0014005A|Sideview camera" \
    "0x0014005B|Reversible seat-belt tensioner" \
    "0x0014005D|Traffic sign recognition" \
    "0x0014005E|Weariness recognition" \
    "0x0014005F|Rear seat entertainment" \
    "0x0014007C|VIN activate" \
    "0x0014007D|Oil level gauge" \
    "0x0014007E|Seat heat" \
    "0x00140098|Tilt angle display" \
; do
    ADDR=${ADDR_DESC%|*}
    DESC=${ADDR_DESC#*|}
    VAL=$(read_per3 $ADDR int)
    printf "  %-40s %s = %s\n" "$DESC" "$ADDR" "$VAL"
done
echo ""

# === Feature CAN channel slider values ===
echo "================================================================"
echo "  FEATURE CAN CHANNEL ASSIGNMENT (0x001400xx sliders 0-31)"
echo "================================================================"
i=0
while [ $i -le 0x1E ]; do
    ADDR=$(printf "0x001400%02x" $i)
    VAL=$(read_per3 $ADDR int)
    printf "  Channel %-3d %s = %s\n" $i $ADDR "$VAL"
    i=$((i+1))
done
echo ""

# === Dump any per3 raw if available ===
echo "================================================================"
echo "  PERSISTENCE FILE INVENTORY"
echo "================================================================"
for p in /mnt/efs-persist /mnt/persist; do
    if [ -d "$p" ]; then
        echo "--- $p ---"
        find "$p" -type f 2>/dev/null | head -30
        echo ""
    fi
done

echo ""
echo "################################################################"
echo "#  Dump complete. Output: ${OUTFILE}"
echo "################################################################"

} > ${OUTFILE} 2>&1

echo "Variant dump complete. Output: ${OUTFILE}"
sync
