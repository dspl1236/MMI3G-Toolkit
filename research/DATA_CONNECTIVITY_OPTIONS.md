# MMI Data Connectivity Options
# For GEMMI (Google Earth), Audi Connect, and online services
# Part of MMI-Toolkit research

## The Problem

US 3G networks shut down in 2022. The MMI's built-in 2G/3G modem
no longer has a network to connect to. GEMMI (Google Earth) needs
data connectivity to fetch satellite tiles.

## Hardware Already Available

- **TP-Link TL-MR3020** — Andrew's existing travel router (purchased 2024)
- **UGREEN USB to Ethernet (AX88772D)** — Andrew's existing USB ethernet adapter
  - QNX has native devn-asix.so driver for AX88772/A/B
  - AX88772D may work but is untested — D revision not listed in QNX docs
  - If it doesn't work, D-Link DUB-E100 is the confirmed-compatible fallback
- **DrGER LAN setup** — already installed on Andrew's A6 (usedhcp + DLinkReplacesPPP flags set)

## Option 1: Phone WiFi Hotspot (No SIM card needed)

```
Phone (WiFi hotspot, existing data plan)
  → TL-MR3020 in WISP Client Mode (connects to phone WiFi)
    → Ethernet cable
      → D-Link DUB-E100 USB adapter
        → MMI USB port
          → MMI sees wired internet via DrGER LAN setup
```

**Pros:** No extra SIM, no monthly cost, uses existing phone data
**Cons:** Phone must be in car with hotspot on, battery drain
**Setup:** TL-MR3020 WISP mode → connect to phone SSID → ethernet bridges automatically

## Option 2: Dedicated LTE USB Modem

```
LTE USB modem (with SIM card, e.g. Digi/T-Mobile prepaid)
  → TL-MR3020 in 3G/4G Router Mode
    → Ethernet cable
      → D-Link DUB-E100
        → MMI USB port
```

**Pros:** Always-on, no phone needed, dedicated connection
**Cons:** Monthly SIM cost, need compatible USB modem
**Compatible modems:** Most USB LTE sticks (Huawei E3372, ZTE MF833V, etc.)

## Option 3: Bluetooth PAN (Theoretical — NOT proven)

The MMI Bluetooth stack supports HFP (calls) and A2DP (audio streaming)
but likely does NOT support PAN (Personal Area Network) or DUN (Dial-Up
Networking) profiles. Bluetooth data tethering would require:

1. PAN/DUN profile support in the MMI's Bluetooth stack
2. Phone configured as Bluetooth NAP (Network Access Point)
3. MMI configured as Bluetooth PANU client

**Status:** Unlikely to work without significant software changes.
The MMI's QNX Bluetooth stack (io-bluetooth) may not have PAN support
compiled in. Would need to check available Bluetooth profiles.

**To verify:** Check `pidin ar | grep bluetooth` and look for PAN-related
binaries or check `/etc/bluetooth/` config files in a future system-info dump.

## Option 4: WiFi Client Mode (Theoretical)

The MMI has a WiFi chip (uap0 interface) but it operates as an
Access Point (AP mode), not a client. It broadcasts 192.168.1.1
but cannot connect TO other WiFi networks.

**Status:** Would require changing WiFi driver mode from AP to client.
Possible with QNX WiFi driver reconfiguration but risky — could
break the existing WiFi AP functionality.

## Recommended Setup

**Option 1 (phone hotspot)** is the quickest path:
1. Set TL-MR3020 to WISP Client Router mode
2. Configure it to connect to your phone's WiFi hotspot
3. Connect ethernet from TL-MR3020 → DUB-E100 → MMI USB
4. DrGER LAN setup is already installed — just plug in and go
5. Power TL-MR3020 from car USB or cigarette lighter adapter

The TL-MR3020 is small enough to live permanently in the glove box.

## Network Architecture (when connected)

```
Internet
  ↓
Phone / LTE Modem
  ↓ (WiFi or USB)
TL-MR3020 (192.168.0.254)
  ↓ (Ethernet)
D-Link DUB-E100 (USB Ethernet)
  ↓ (USB)
MMI USB Port
  ↓ (DrGER LAN setup)
QNX network stack
  ↓
en5 interface (DHCP client)
  ↓
GEMMI / Audi Connect / Online services
```
