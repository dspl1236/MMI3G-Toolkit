#!/bin/ksh
# ============================================================
# Coding Dump — triggered from GEM CodingMain screen
# Writes adaptation snapshot to SD card
# ============================================================

SDPATH="${1:-/fs/sda1}"
# Try common SD paths
for sd in /fs/sda1 /fs/sda0 /fs/sd1 /fs/sd0; do
    if [ -d "$sd" ]; then
        SDPATH=$sd
        break
    fi
done

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTDIR="${SDPATH}/var/coding"
OUTFILE="${OUTDIR}/coding-${TIMESTAMP}.txt"
mkdir -p ${OUTDIR} 2>/dev/null

# Re-use the per3 reader approach from variant-dump
PER3_READ=""
for candidate in /usr/bin/per3_read /opt/bin/per3_read /usr/bin/readper3 /bin/per3; do
    if [ -x "$candidate" ]; then
        PER3_READ="$candidate"
        break
    fi
done

read_per3() {
    ADDR=$1
    if [ -n "$PER3_READ" ]; then
        "$PER3_READ" $ADDR 2>/dev/null
    else
        echo "n/a"
    fi
}

{
echo "################################################################"
echo "# MMI3G Coding/Adaptation Snapshot"
echo "# Generated: $(date)"
echo "# Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo "################################################################"
echo ""
echo "This is a snapshot of adaptation values at one moment in time."
echo "Use this BEFORE and AFTER VCDS/ODIS changes to see what moved."
echo ""

echo "=== CAR DEVICE LIST (0x001000xx) ==="
for addr in \
    00100000 00100001 00100002 00100010 00100011 00100012 00100013 \
    00100014 00100015 00100016 00100017 00100018 00100019 0010001A \
    0010001B 0010001C 0010001D 0010001E 0010001F 00100020 00100021 \
    00100022 00100023 00100024 00100025 00100026 00100027 00100028 \
    00100029 0010002A 0010002B 0010002C 0010002D 0010002E 0010002F \
    00100030 00100031 00100032 00100033 00100034 00100035 00100036 \
    00100037 00100064 00100070 00100071 00100088 00100089; do
    VAL=$(read_per3 0x$addr)
    printf "  0x%s = %s\n" $addr "$VAL"
done
echo ""

echo "=== CAN BUS ASSIGNMENT (0x001400xx) ==="
for addr in \
    0014003D 0014003F 00140040 00140041 00140042 00140043 00140044 \
    00140045 00140046 00140047 00140048 00140049 0014004A 0014004B \
    0014004C 0014004D 0014004E 0014004F 00140050 00140051 00140053 \
    00140054 00140055 00140056 00140057 00140059 0014005A 0014005B \
    0014005D 0014005E 0014005F 0014007C 0014007D 0014007E 00140098; do
    VAL=$(read_per3 0x$addr)
    printf "  0x%s = %s\n" $addr "$VAL"
done
echo ""

echo "=== FEATURE CAN CHANNEL SLIDERS (0x001400xx sliders) ==="
i=0
while [ $i -le 30 ]; do
    ADDR=$(printf "001400%02x" $i)
    VAL=$(read_per3 0x$ADDR)
    printf "  0x%s (channel %d) = %s\n" $ADDR $i "$VAL"
    i=$((i+1))
done
echo ""

echo "Done. Report at: $OUTFILE"
} > "$OUTFILE" 2>&1

sync
echo "Coding snapshot saved to: $OUTFILE"
