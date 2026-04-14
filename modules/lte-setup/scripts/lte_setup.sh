#!/bin/ksh
# ============================================================
# MMI3G+ LTE / LAN Setup
# Provision USB Ethernet for mobile data connectivity
# ============================================================
#
# HOW IT WORKS:
#
# The MMI3G+ has a built-in ASIX USB Ethernet driver
# (devnp-asix.so) that recognizes D-Link DUB-E100 adapters
# (rev A4/B1, vendor 0x2001). When a compatible adapter is
# plugged into the AMI USB port, the system creates network
# interface "en5".
#
# In factory configuration, the MMI uses its internal 3G
# modem via PPP for Audi Connect services. Since AT&T/other
# carriers sunset their 3G networks, this modem no longer
# works. "Fair mode" (aka "DLink mode") tells the MMI to
# use the USB Ethernet adapter instead of the internal modem.
#
# HARDWARE REQUIRED:
#   - D-Link DUB-E100 (rev A4 or B1 — silver, NOT black)
#     OR Gembird NIC-U1 (same ASIX chipset)
#   - USB hub (if also using AMI for music)
#   - LTE router (TP-Link TL-MR3020 or similar)
#     configured on 192.168.0.1 subnet
#   - AMI-to-USB adapter cable
#
# WHAT THIS SCRIPT DOES:
#   1. Creates /HBpersistence/DLinkReplacesPPP flag file
#   2. Creates /mnt/efs-persist/usedhcp marker
#   3. Creates /etc/dhcp-up script for DNS resolution
#   4. Configures DHCP client for en5 interface
#
# Based on DrGER2/MMI3GP-LAN-Setup and community research
# from Audizine, A5OC, and ClubTouareg forums.
#
# COMPATIBILITY: MMI 3G+ only (HN+ systems with devnp-asix.so)
#   MMI 3G High does NOT have the ASIX USB driver.
#   RNS-850 support is confirmed by ClubTouareg community.
#
# ============================================================

SDPATH="${1:-$(dirname $0)}"
LOGFILE="${SDPATH}/var/lte-setup-$(date +%Y%m%d-%H%M%S).log"
EFSDIR="/mnt/efs-system"
EFSPERSIST="/mnt/efs-persist"

exec > ${LOGFILE} 2>&1

echo "============================================"
echo " MMI3G+ LTE / LAN Setup"
echo " $(date)"
echo " Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo "============================================"
echo ""

# --- Variant check ---
TRAIN="$(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
if echo "$TRAIN" | grep -qi "HN+\|RNS"; then
    echo "[OK]    Compatible variant detected: $TRAIN"
elif echo "$TRAIN" | grep -qi "HNav\|HN_"; then
    echo "[WARN]  MMI 3G High detected — this unit may NOT have"
    echo "[WARN]  the ASIX USB Ethernet driver (devnp-asix.so)."
    echo "[WARN]  LTE setup is designed for MMI 3G+ (HN+) systems."
    echo "[WARN]  Proceeding anyway — check log for errors."
else
    echo "[INFO]  Variant: $TRAIN"
fi
echo ""

# --- Check for ASIX driver ---
echo "[CHECK] Verifying ASIX USB Ethernet driver..."
if [ -f "/mnt/ifs-root/lib/dll/devnp-asix.so" ]; then
    echo "[OK]    devnp-asix.so found in ifs-root"
elif [ -f "/lib/dll/devnp-asix.so" ]; then
    echo "[OK]    devnp-asix.so found"
else
    echo "[WARN]  devnp-asix.so NOT found!"
    echo "[WARN]  USB Ethernet may not work on this unit."
fi
echo ""

# --- Remount filesystems ---
echo "[ACTI]  Remounting filesystems rw..."
mount -uw ${EFSDIR} 2>/dev/null
mount -uw ${EFSPERSIST} 2>/dev/null
mount -uw /HBpersistence 2>/dev/null
echo "[OK]    Filesystems remounted"
echo ""

# --- Backup current state ---
BACKUPDIR="${SDPATH}/var/lte-backup-$(date +%Y%m%d)"
mkdir -p ${BACKUPDIR}

# Save current network config
ifconfig -a > ${BACKUPDIR}/ifconfig_before.txt 2>/dev/null
netstat -rn > ${BACKUPDIR}/routes_before.txt 2>/dev/null
cat /etc/resolv.conf > ${BACKUPDIR}/resolv_before.txt 2>/dev/null
echo "[BACK]  Network state backed up"
echo ""

# === STEP 1: DLinkReplacesPPP flag ===
echo "[STEP]  1/4 — Setting DLinkReplacesPPP flag..."

# This flag tells NWSProcess to use USB Ethernet (en5) instead
# of the internal 3G PPP modem for data connectivity.
if [ -d "/HBpersistence" ]; then
    if [ -f "/HBpersistence/DLinkReplacesPPP" ]; then
        echo "[OK]    DLinkReplacesPPP already exists"
    else
        touch /HBpersistence/DLinkReplacesPPP
        if [ -f "/HBpersistence/DLinkReplacesPPP" ]; then
            echo "[OK]    Created /HBpersistence/DLinkReplacesPPP"
        else
            echo "[ERROR] Failed to create DLinkReplacesPPP flag!"
        fi
    fi
else
    echo "[WARN]  /HBpersistence not found — trying efs-persist"
    mkdir -p ${EFSPERSIST}/HBpersistence 2>/dev/null
    touch ${EFSPERSIST}/HBpersistence/DLinkReplacesPPP 2>/dev/null
    echo "[INFO]  Created flag in efs-persist fallback location"
fi
echo ""

# === STEP 2: DHCP marker ===
echo "[STEP]  2/4 — Enabling DHCP client..."

# When /mnt/efs-persist/usedhcp exists, NWSProcess starts the
# DHCP client on en5 when the USB Ethernet device appears.
if [ -f "${EFSPERSIST}/usedhcp" ]; then
    echo "[OK]    usedhcp marker already exists"
else
    touch ${EFSPERSIST}/usedhcp
    if [ -f "${EFSPERSIST}/usedhcp" ]; then
        echo "[OK]    Created ${EFSPERSIST}/usedhcp"
    else
        echo "[ERROR] Failed to create usedhcp marker!"
    fi
fi
echo ""

# === STEP 3: dhcp-up script ===
echo "[STEP]  3/4 — Installing dhcp-up script..."

# The DHCP client runs /etc/dhcp-up after obtaining a lease.
# This script populates /etc/resolv.conf with DNS servers
# from the DHCP response so hostname resolution works.
DHCPUP="${EFSDIR}/etc/dhcp-up"

# Back up existing if present
if [ -f "${DHCPUP}" ]; then
    cp -v "${DHCPUP}" "${BACKUPDIR}/dhcp-up.bak"
    echo "[BACK]  Existing dhcp-up backed up"
fi

cat > ${DHCPUP} << 'DHCPEOF'
#!/bin/ksh
# dhcp-up - Called by dhcp.client after obtaining a lease
# Populates resolv.conf with DNS servers from DHCP
# Installed by MMI3G-Toolkit LTE Setup module

# $new_domain_name_servers contains space-separated DNS IPs
if [ -n "$new_domain_name_servers" ]; then
    echo "# Generated by dhcp-up $(date)" > /etc/resolv.conf
    for ns in $new_domain_name_servers; do
        echo "nameserver $ns" >> /etc/resolv.conf
    done
else
    # Fallback to router gateway as DNS
    if [ -n "$new_routers" ]; then
        echo "# Generated by dhcp-up (fallback) $(date)" > /etc/resolv.conf
        echo "nameserver $new_routers" >> /etc/resolv.conf
    fi
fi
DHCPEOF

chmod +x ${DHCPUP}
echo "[OK]    dhcp-up script installed"
echo ""

# === STEP 4: DNS fallback ===
echo "[STEP]  4/4 — Setting fallback DNS..."

# Write a fallback resolv.conf pointing to common router gateway.
# The dhcp-up script will overwrite this with the actual DNS
# servers from the DHCP lease at runtime.
if [ ! -f "/etc/resolv.conf" ] || [ ! -s "/etc/resolv.conf" ]; then
    echo "nameserver 192.168.0.1" > /etc/resolv.conf
    echo "[OK]    Fallback DNS set to 192.168.0.1"
else
    echo "[OK]    resolv.conf already has content"
    cat /etc/resolv.conf
fi
echo ""

# --- Sync ---
sync

echo "============================================"
echo " LTE / LAN Setup Complete!"
echo ""
echo " IMPORTANT: Reboot MMI for changes to take effect."
echo "   Hold MENU + rotary knob + upper-right soft key"
echo ""
echo " HARDWARE SETUP:"
echo "   1. Connect D-Link DUB-E100 (rev A4/B1) to AMI USB"
echo "   2. Connect LTE router to D-Link via Ethernet"
echo "   3. Configure router:"
echo "      - LAN IP: 192.168.0.1"
echo "      - DHCP: enabled (pool 192.168.0.100+)"
echo "      - WAN: WiFi hotspot from your phone"
echo ""
echo " VERIFY CONNECTION:"
echo "   After reboot with hardware connected:"
echo "   - GEM > /gauges/network for status"
echo "   - Or run lte_status.sh for full diagnostic"
echo "   - en5 interface should show 192.168.0.x IP"
echo ""
echo " Compatible adapters:"
echo "   - D-Link DUB-E100 rev A4 (ven=2001, dev=3c05)"
echo "   - D-Link DUB-E100 rev B1 (ven=2001, dev=1a02)"
echo "   - Gembird NIC-U1 (same ASIX AX88772 chipset)"
echo ""
echo " To uninstall: run lte_restore.sh"
echo " Log: ${LOGFILE}"
echo "============================================"
