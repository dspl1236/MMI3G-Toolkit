#!/bin/ksh
# Grab key binaries from the MMI for offline analysis
# Usage: ksh grab_binaries.sh [sd_root]
#
# Copies NDR, NavigationNdrInfo, and other useful binaries to SD card

SDROOT="${1:-/mnt/sdcard10t12}"
DUMPDIR="${SDROOT}/mmi_binaries"
mkdir -p "$DUMPDIR" 2>/dev/null

echo "=== MMI Binary Extraction ==="
echo "Output: $DUMPDIR"
echo ""

# NDR binary (the resource manager we're talking to)
if [ -f /proc/boot/ndr ]; then
    cp /proc/boot/ndr "$DUMPDIR/ndr_boot"
    echo "[OK] /proc/boot/ndr ($(ls -la /proc/boot/ndr | awk '{print $5}') bytes)"
fi

# NavigationNdrInfo (has debug symbols on PCM — check MMI too)
for path in /mnt/data/tools/NavigationNdrInfo /HBbin/NavigationNdrInfo /usr/bin/NavigationNdrInfo; do
    if [ -f "$path" ]; then
        cp "$path" "$DUMPDIR/NavigationNdrInfo"
        echo "[OK] $path ($(ls -la "$path" | awk '{print $5}') bytes)"
        break
    fi
done

# taco (Harman diagnostic suite)
for path in /mnt/data/tools/taco /HBbin/taco; do
    if [ -f "$path" ]; then
        cp "$path" "$DUMPDIR/taco"
        echo "[OK] $path"
        break
    fi
done

# MMI3GApplication (main app — 10+ MB, skip if too large)
for path in /mnt/ifs1/HBbin/MMI3GApplication /HBbin/MMI3GApplication; do
    if [ -f "$path" ]; then
        SIZE=$(ls -la "$path" | awk '{print $5}')
        echo "[INFO] MMI3GApplication at $path ($SIZE bytes)"
        echo "  Too large to copy — analyze in-place or via telnet"
        break
    fi
done

# HFS config (CAN routing)
if [ -f /etc/hfs.cfg ]; then
    cp /etc/hfs.cfg "$DUMPDIR/hfs.cfg"
    echo "[OK] /etc/hfs.cfg"
fi

# inetd config
if [ -f /etc/inetd.conf ]; then
    cp /etc/inetd.conf "$DUMPDIR/inetd.conf"
    echo "[OK] /etc/inetd.conf"
fi

# Shadow (for hashcat)
if [ -f /etc/shadow ]; then
    cp /etc/shadow "$DUMPDIR/shadow"
    echo "[OK] /etc/shadow"
fi

# Firmware version
for vf in /mnt/ifs1/HBproject/version.txt /HBproject/version.txt; do
    if [ -f "$vf" ]; then
        cp "$vf" "$DUMPDIR/version.txt"
        echo "[OK] $vf"
        break
    fi
done

# ESD screens
mkdir -p "$DUMPDIR/engdefs" 2>/dev/null
for dir in /HBpersistence/engdefs /mnt/ifs1/engdefs /mnt/flash/efs1/engdefs; do
    if [ -d "$dir" ]; then
        cp "$dir"/*.esd "$DUMPDIR/engdefs/" 2>/dev/null
        echo "[OK] ESDs from $dir"
    fi
done

# dev-ipc info
cat /dev/ipc/ioc/debug > "$DUMPDIR/ioc_debug.txt" 2>&1
echo "[OK] IOC debug info"

# Process list
pidin ar > "$DUMPDIR/pidin.txt" 2>&1
echo "[OK] Process list"

# Mount table
mount > "$DUMPDIR/mount.txt" 2>&1
echo "[OK] Mount table"

echo ""
echo "=== Extraction Complete ==="
ls -la "$DUMPDIR/"
