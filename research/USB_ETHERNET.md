# USB Ethernet — Compatibility & Configuration

> Consolidated from USB_ETHERNET.md and USB_ETHERNET_COMPATIBILITY.md.

## Supported Chipsets

The MMI firmware (QNX 6.3.2) ships with exactly one USB ethernet driver: `/lib/dll/devn-asix.so`. No other chipsets work without IFS modification.

| Chipset | Status | Notes |
|---|---|---|
| ASIX AX88172 | Supported | |
| ASIX AX88172A | Supported | |
| ASIX AX88772 | Supported | DrGER reference adapter (D-Link DUB-E100) |
| ASIX AX88772A | Supported | Confirmed on A6 C7 — valid MAC, DHCP works |
| ASIX AX88772B | Supported | |
| ASIX AX88772D | Workaround | Not auto-detected; use `did=0x772D,vid=0x0B95` override |
| ASIX AX88178 | Incompatible | Wrong chip family, null MAC from EEPROM init mismatch |
| Realtek RTL8152/8153 | Incompatible | No driver in firmware |

## Confirmed Working Adapters

| Adapter | Chipset | Confirmed By |
|---|---|---|
| D-Link DUB-E100 | AX88772 | DrGER |
| Generic AX88772A | AX88772A | Andrew (A6 C7) — MAC `00:0E:C6:06:44:1D` |

## AX88772D Device ID Override

The AX88772D is register-compatible with AX88772 but has a different USB product ID. Force it with:

```sh
io-pkt-v4-hc -d asix did=0x772D,vid=0x0B95 &
```

Source: [QNX devn-asix.so documentation](https://qnx.com/developers/docs/6.4.0/neutrino/utilities/d/devn-asix.so.html)

## Speed Limitation (DrGER2 discovery)

Harman hardcodes `speed=10 duplex=1` in `/etc/umass-enum_def.cfg` (IFS, read-only). Every MMI3G with USB ethernet runs at 10baseT regardless of adapter capability.

### Fix

Our LTE scripts detect en5 and upgrade via `ifconfig en5 media 100baseTX mediaopt full-duplex`, or kill io-pkt and restart with `speed=100`.

### Process Chain

1. `vdev-medialauncher` detects USB insertion
2. Reads device match from `/etc/umass-enum_def.cfg`
3. Starts `io-pkt-v4-hc -d devn-asix.so speed=10 duplex=1`
4. `multicored` assigns IP 172.16.250.248/16 on en5
5. If `/mnt/efs-persist/usedhcp` exists, NWSProcess starts DHCP client

### Driver Options

| Option | Description | Default |
|---|---|---|
| `did=0xXXXX` | Force USB device ID | Auto-detect |
| `vid=0xXXXX` | Force USB vendor ID | Auto-detect |
| `speed=10\|100` | Force speed (Mbps) | Auto-negotiate |
| `duplex=0\|1` | Force half/full duplex | Auto-negotiate |
| `mac=XXXXXXXXXXXX` | Override MAC address | From hardware |
| `verbose=1..4` | Debug output (slogger) | 0 (off) |

## Other Network Drivers in Firmware

| Driver | Purpose |
|---|---|
| devnp-mv8688uap.so | Marvell 88W8688 WiFi (built-in AP, 192.168.1.1) |
| devnp-shim.so | io-net compatibility shim |
| devnp-mlb.so | MOST Link Bus (internal car network) |

## Attribution

Speed discovery and analysis by DrGER2. AX88772A testing by Andrew (A6 C7). AX88772D incompatibility confirmed by daredoole (RNS-850).
