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
| ASIX AX88772D | 10/100 | Likely works (same family, untested) |

## Confirmed Working Adapters

| Adapter | Chipset | Confirmed By |
|---|---|---|
| D-Link DUB-E100 | ASIX AX88772 | DrGER — reference adapter |
| UGREEN USB Ethernet (RJ45) | ASIX AX88772D | Andrew — untested, likely works |

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
