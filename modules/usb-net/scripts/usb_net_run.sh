#!/bin/ksh
# ============================================================
# MMI3G-Toolkit  usb-net  —  Universal ASIX USB-Ethernet
# ------------------------------------------------------------
# Loads a universal devn-asix driver (AX88772 / 772A / 772B / 772C
# + 88178/Linksys/NetGear rebadges) into the running io-net, brings up
# the link, and enables telnet. The driver is harvested from later HN+
# firmware (MU9498) which contains Harman's own AX88772B init, with its
# dormant 772B match activated — so modern cheap adapters work, not just
# the old 772/772A.  Loads from USB only; never modifies the read-only
# firmware (a bad run just needs a reboot).
#
# Modes:
#   dhcp    — DHCP from your router/switch (default)
#   static  — 172.16.42.1/24 (direct cable to a PC)
#   lte     — DHCP + DNS + DLinkReplacesPPP (use the USB adapter for
#             Audi/VW online services instead of the dead 3G modem)
#   github.com/dspl1236/MMI3G-Toolkit
# ============================================================
DRV="devn-asix-universal.so"
USBROOT="$1"; [ -z "$USBROOT" ] && USBROOT="/fs/usb0"
MODE="${2:-dhcp}"

DRVPATH=""
for c in "${USBROOT}/${DRV}" "${USBROOT}/scripts/USBNet/${DRV}" "${USBROOT}/bin/${DRV}"; do
    [ -f "$c" ] && DRVPATH="$c" && break
done
[ -z "$DRVPATH" ] && DRVPATH=$(ls "${USBROOT}"/*/"${DRV}" "${USBROOT}"/*/*/"${DRV}" 2>/dev/null | head -1)
DTSTAMP=$(date +%Y%m%d_%H%M%S 2>/dev/null || echo nodate)
LOG="${USBROOT}/mmi_usbnet_${DTSTAMP}.txt"
TMPD=/tmp; [ -d /fs/tmpfs ] && TMPD=/fs/tmpfs

echo "MMI3G-Toolkit usb-net (universal) — $(date 2>/dev/null)" > "$LOG"
echo "driver=$DRVPATH  mode=$MODE" >> "$LOG"
if [ -z "$DRVPATH" ]; then echo "[ERR] ${DRV} not found on USB" >> "$LOG"; exit 1; fi

# --- load the driver from a writable path (RO firmware untouched) ---
cp "$DRVPATH" "${TMPD}/${DRV}" 2>>"$LOG"
if [ -e /dev/io-net ]; then
    echo "[OK] io-net — mounting universal ASIX driver" >> "$LOG"
    mount -T io-net -o "verbose" "${TMPD}/${DRV}" >> "$LOG" 2>&1
elif [ -x /sbin/io-pkt-v4-hc ] || [ -x /usr/sbin/io-pkt-v4-hc ]; then
    echo "[OK] io-pkt — mounting universal ASIX driver via stack" >> "$LOG"
    mount -T io-pkt -o "verbose" "${TMPD}/${DRV}" >> "$LOG" 2>&1
else
    echo "[ERR] no io-net / io-pkt stack" >> "$LOG"
fi
sleep 5

# --- find the interface (MMI3G+ USB ethernet is usually en5) ---
IFACE=""
for ifc in en5 en0 en1 en2; do
    ifconfig "$ifc" >/dev/null 2>&1 && IFACE="$ifc" && break
done
echo "[..] interface=${IFACE:-NONE}" >> "$LOG"
[ -n "$IFACE" ] && echo "[..] MAC: $(ifconfig "$IFACE" 2>/dev/null | sed -n 's/.*address: *//p')" >> "$LOG"

# --- address ---
if [ -n "$IFACE" ]; then
    if [ "$MODE" = "static" ]; then
        ifconfig "$IFACE" 172.16.42.1 netmask 255.255.255.0 up
        echo "[..] static 172.16.42.1/24" >> "$LOG"
    else
        dhcp.client -i "$IFACE" >> "$LOG" 2>&1 &
        sleep 6
        ifconfig "$IFACE" 2>/dev/null | grep -q "inet " || \
            { ifconfig "$IFACE" 172.16.42.1 netmask 255.255.255.0 up; echo "[..] no lease -> static 172.16.42.1" >> "$LOG"; }
    fi
fi

# --- lte mode: make the unit use the USB adapter for online services ---
if [ "$MODE" = "lte" ]; then
    mount -uw /mnt/efs-system  2>/dev/null
    mount -uw /mnt/efs-persist 2>/dev/null
    mount -uw /HBpersistence   2>/dev/null
    [ -d /HBpersistence ] && touch /HBpersistence/DLinkReplacesPPP 2>/dev/null
    touch /mnt/efs-persist/usedhcp 2>/dev/null
    DHCPUP=/mnt/efs-system/etc/dhcp-up
    cat > "$DHCPUP" 2>/dev/null <<'DUP'
#!/bin/ksh
if [ -n "$new_domain_name_servers" ]; then
    echo "# dhcp-up" > /etc/resolv.conf
    for ns in $new_domain_name_servers; do echo "nameserver $ns" >> /etc/resolv.conf; done
elif [ -n "$new_routers" ]; then
    echo "nameserver $new_routers" > /etc/resolv.conf
fi
DUP
    chmod +x "$DHCPUP" 2>/dev/null
    echo "nameserver 8.8.8.8" > /etc/resolv.conf 2>/dev/null
    echo "[..] lte: DLinkReplacesPPP + usedhcp set, dhcp-up installed, DNS 8.8.8.8" >> "$LOG"
fi

# --- telnet: inetd (port 23) + raw root shell on 2323 (session only) ---
slay -f inetd 2>/dev/null; sleep 1
/usr/sbin/inetd 2>/dev/null &
echo "2323 stream tcp nowait root /bin/ksh ksh -i" > /dev/shmem/inetd_2323.conf
/usr/sbin/inetd /dev/shmem/inetd_2323.conf 2>/dev/null &

{
    echo ""; echo "--- ifconfig ---"; ifconfig 2>&1
    echo ""; echo "--- driver log ---"; sloginfo 2>/dev/null | grep -iE 'asix|devn-ax|mii|media|baset|duplex|transceiver|8877' | tail -25
    echo ""; echo "telnet: port 23 (login root) or 2323 (raw shell) once you have an inet address."
    [ "$MODE" = "lte" ] && echo "lte: reboot the unit for DLinkReplacesPPP to take effect for online services."
} >> "$LOG" 2>&1
echo "usb-net done (mode=$MODE)" > "${USBROOT}/mmi_ran.txt"
sync
