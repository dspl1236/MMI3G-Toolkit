# usb-net — Universal ASIX USB-Ethernet (MMI3G+ / RNS-850)

Gets a **USB-to-Ethernet adapter working** on Audi MMI3G+ and VW RNS-850 (Harman HN+) so you
can reach the unit over the network (telnet/qconn) and restore data connectivity — **without
modifying the read-only firmware**.

## What's new
The built-in `devn-asix.so` only recognizes **AX88772 / 772A**. Modern cheap adapters are
**AX88772B / 772C**, which attach but **fail to transmit** on the old driver (RX works, ping
doesn't). This module ships **`devn-asix-universal.so`** — taken from later HN+ firmware
(**MU9498**) that contains Harman's own **`ax_enable_88772B`** init, with its dormant 772B
match **activated**. One driver now covers:

| Chip | USB ID | Status |
|------|--------|--------|
| AX88772 / 772A | `0b95:7720` / `772a` | ✅ |
| **AX88772B / 772C** | `0b95:772b` | ✅ (the fix — proper TX/medium-mode init) |
| AX88178 + Linksys/NetGear rebadges | various | ✅ |
| AX88172 (USB 1.1) | `0b95:1720` | ❌ dropped (its slot was reused for 772B) |

## Modes
- **dhcp** — address from your router/switch (default).
- **static** — `172.16.42.1/24`, direct cable to a PC.
- **lte** — DHCP **+** sets `DLinkReplacesPPP` so the unit uses the USB adapter for **online
  services** (replacing the dead internal 3G modem — the DrGER2 LTE use case, on a driver that
  also handles 772B/C). Reboot after for it to take effect.

## Brick-safe
Loaded from the USB stick into the running io-net (`mount -T io-net /tmp/...`) — the read-only
flash/IFS is never touched, so a bad run just needs a reboot.

## Use
Build a stick with the toolkit web app (or copy `copie_scr.sh` + `usb_net_run.sh`→`run.sh` +
`devn-asix-universal.so` to a FAT32 root). Boot the unit fully, **then** insert the stick.
Read `mmi_usbnet_<timestamp>.txt`; if it shows an `inet`, `telnet <IP>` (port 23 `root`, or
2323 raw shell). `/etc` is read-only — re-insert after each reboot.

## Status
**Beta.** Validated on a Porsche PCM 3.1 (PCM-Forge issue #7). MMI3G+/RNS-850 use the same
QNX 6.3 io-net SH4 driver ABI — and the driver is itself from MMI3G+ MU9498 firmware — so it's
expected to work, pending an Audi/VW bench confirmation. Rebuild from your own firmware with
`tools/asix_universal_patch.py` (in PCM-Forge).

Supersedes the **lte-setup** module (now deprecated): its old AX88772B/D overrides never worked
on io-net (`did=` is io-pkt-only).
