# USB Ethernet Adapter Compatibility Guide
# For MMI 3G / 3G+ / RNS-850 LAN connectivity
# Part of MMI-Toolkit research

## CRITICAL: Only ASIX chipsets work!

The MMI firmware (QNX 6.3.2) ships with exactly ONE USB ethernet driver:

```
/lib/dll/devn-asix.so
```

No other USB ethernet drivers are included. Realtek, SMSC, Pegasus,
and all other chipsets will NOT work without adding custom drivers
(which requires modifying the IFS — not practical).

## Supported Chipsets (devn-asix.so)

| Chipset | Speed | Status |
|---|---|---|
| ASIX AX88172 | 10/100 | Supported |
| ASIX AX88172A | 10/100 | Supported |
| ASIX AX88178 | 10/100/1000 | Supported |
| ASIX AX88772 | 10/100 | Supported — DrGER confirmed |
| ASIX AX88772A | 10/100 | Supported |
| ASIX AX88772B | 10/100 | Supported |
| ASIX AX88772D | 10/100 | ❌ NOT COMPATIBLE — confirmed by daredoole (Touareg RNS-850). USB detected but no en5 device created. |

## Confirmed Working Adapters

| Adapter | Chipset | Confirmed By |
|---|---|---|
| D-Link DUB-E100 | ASIX AX88772 | DrGER — reference adapter |
| UGREEN USB Ethernet (RJ45) | ASIX AX88772D | ❌ NOT COMPATIBLE — D revision not supported by QNX devn-asix.so driver |

## How to Verify Chipset Before Buying

Look for "ASIX AX88772" or "AX88178" in the product specs or reviews.
Common brands using ASIX chips:
- D-Link (DUB-E100, DUB-E100 rev C)
- UGREEN (some models — check chip version)
- Cable Matters
- Plugable (some models)

WARNING: Many cheap USB ethernet adapters use Realtek RTL8152/RTL8153
chipsets. These will NOT work with the MMI.

## NOT Compatible (no drivers in firmware)

| Chipset | Common Adapters |
|---|---|
| Realtek RTL8150 | Various budget adapters |
| Realtek RTL8152/RTL8153 | Most modern USB-C ethernet adapters |
| SMSC LAN9500/9514 | Some embedded boards |
| Pegasus (ADMtek AN986) | Older SMC adapters |
| Microchip LAN78xx | Raspberry Pi ethernet |
| Intel i82574/i210 | Enterprise adapters |

## Adapter Detection

When plugged in, a compatible adapter appears as interface `en5`
(or similar `enX`). Check with system-info or from the GEM:
- Network interfaces section shows new `enX` interface
- DHCP assigns an IP if DrGER LAN setup is installed

## Other Drivers in MMI Firmware

| Driver | Purpose |
|---|---|
| devnp-mv8688uap.so | Marvell 88W8688 WiFi (built-in AP, 192.168.1.1) |
| devnp-shim.so | io-net compatibility shim |
| devnp-mlb.so | MOST Link Bus (internal car network) |

## QNX devn-asix.so Driver — Device ID Override (CRITICAL)

Official QNX documentation confirms the ASIX driver supports
explicit USB device ID override via command-line parameters:

```sh
io-pkt-v4-hc -d asix did=0xXXXX,vid=0xXXXX &
```

### AX88772D Fix — No Hex Patching Needed

The AX88772D fails only because its USB product ID isn't in the
driver's auto-detection table. The register layout is compatible
with AX88772/A/B. Forcing the device ID bypasses auto-detection:

```sh
# ASIX-branded AX88772D
io-pkt-v4-hc -d asix did=0x772D,vid=0x0B95 &

# Third-party AX88772D (check lsusb for your adapter's IDs)
io-pkt-v4-hc -d asix did=0x0074,vid=0x1790 &
```

This can be added to a startup script or run from an SD card module.

### All Driver Options

| Option | Description | Default |
|--------|-------------|---------|
| `did=0xXXXX` | Force USB device ID | Auto-detect |
| `vid=0xXXXX` | Force USB vendor ID | Auto-detect |
| `busnum=0xXX` | Target USB bus | Any |
| `devnum=0xXX` | Target USB device | Any |
| `speed=10\|100` | Force speed (Mbps) | Auto-negotiate |
| `duplex=0\|1` | Force half/full duplex | Auto-negotiate |
| `mac=XXXXXXXXXXXX` | Override MAC address | From hardware |
| `verbose=1..4` | Debug output (slogger) | 0 (off) |
| `wait=num` | Seconds to wait for USB | 60 |
| `mtu=num` | Max transmission unit | 1514 |
| `promiscuous` | Pass all packets | Disabled |

### Source

QNX Neutrino 6.4.0 documentation:
https://qnx.com/developers/docs/6.4.0/neutrino/utilities/d/devn-asix.so.html
