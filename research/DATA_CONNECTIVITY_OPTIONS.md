# MMI Data Connectivity Options
# For GEMMI (Google Earth), Audi Connect, and online services
# Part of MMI-Toolkit research

## The Problem

US 3G networks shut down in 2022. The MMI's built-in 2G/3G modem
no longer has a network to connect to. GEMMI (Google Earth) needs
data connectivity to fetch satellite tiles.

## Hardware Already Available

- **Digi TransPort WR11 XT** — Industrial 4G LTE cellular router (Andrew's primary)
  - 4G LTE Cat 1 with HSPA+ fallback
  - NA bands: B2/B4/B5/B12/B13
  - 9-30VDC power input — runs directly off car 12V!
  - Single RJ45 10/100 Ethernet out
  - Dual mini-SIM (2FF) slots with failover
  - Rugged aluminum, extended temp range — built for vehicles
  - Digi SureLink for resilient connection
- **TP-Link TL-MR3020** — Backup/alternative travel router (also owned)
- **UGREEN USB to Ethernet (AX88772D)** — Andrew's existing USB ethernet adapter
  - QNX has native devn-asix.so driver for AX88772/A/B
  - AX88772D may work but is untested — D revision not listed in QNX docs
  - If it doesn't work, D-Link DUB-E100 is the confirmed-compatible fallback
- **DrGER LAN setup** — already installed on Andrew's A6 (usedhcp + DLinkReplacesPPP flags set)

## Option 1: Digi WR11 XT — Permanent Always-On (Andrew's setup)

```
Car 12V → Digi WR11 XT (with SIM card, 9-30VDC input)
           → Ethernet cable
             → UGREEN AX88772D USB adapter
               → MMI USB port (AMI cable)
                 → DrGER LAN setup already installed
```

**Pros:** Always-on, no phone needed, industrial grade, 12V direct power,
         dual SIM failover, extended temp range, built for vehicles
**Cons:** Needs active SIM card with data plan
**Power:** Direct 12V from fuse box or cigarette lighter — no USB adapter needed
**SIM:** Mini-SIM (2FF), dual slots — use prepaid T-Mobile/AT&T IoT plans

## Option 2: Phone WiFi Hotspot (No SIM card needed)

```
Phone (WiFi hotspot, existing data plan)
  → TL-MR3020 in WISP Client Mode (connects to phone WiFi)
    → Ethernet cable
      → UGREEN AX88772D USB adapter
        → MMI USB port
          → MMI sees wired internet via DrGER LAN setup
```

**Pros:** No extra SIM, no monthly cost, uses existing phone data
**Cons:** Phone must be in car with hotspot on, battery drain
**Setup:** TL-MR3020 WISP mode → connect to phone SSID → ethernet bridges automatically

## Option 3: Dedicated LTE USB Modem (alternative)

```
LTE USB modem (with SIM card, e.g. Huawei E3372)
  → TL-MR3020 in 3G/4G Router Mode
    → Ethernet cable
      → UGREEN AX88772D
        → MMI USB port
```

**Pros:** Cheaper hardware than Digi WR11 XT
**Cons:** Needs USB power, less reliable, phone-style USB modem

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

**Option 1 (Digi WR11 XT)** is the best permanent installation:
1. Mount WR11 XT in trunk or under seat
2. Wire 12V from fuse box (9-30VDC input, no adapter needed)
3. Insert SIM card (prepaid T-Mobile/AT&T IoT data plan)
4. Ethernet cable from WR11 XT → UGREEN adapter → MMI USB
5. DrGER LAN setup is already installed — just plug in and go
6. Always-on LTE — GEMMI tiles load on every drive

**Option 2 (phone hotspot)** for zero monthly cost:
1. Set TL-MR3020 to WISP Client Router mode
2. Configure it to connect to your phone's WiFi hotspot
3. Connect ethernet from TL-MR3020 → UGREEN adapter → MMI USB
4. Power TL-MR3020 from car USB or cigarette lighter adapter

## Network Architecture (when connected)

```
Internet
  ↓
Digi WR11 XT (12V powered, SIM card)
  -or- Phone hotspot → TL-MR3020
  ↓ (Ethernet RJ45)
UGREEN AX88772D USB Ethernet adapter
  ↓ (USB via AMI cable)
MMI USB Port
  ↓ (DrGER LAN setup: usedhcp + DLinkReplacesPPP)
QNX network stack (devn-asix.so driver)
  ↓
en5 interface (DHCP client)
  ↓
GEMMI / Audi Connect / Online services
```

## GEMMI (Google Earth) Restoration

Once data connectivity is established, GEMMI needs to be fixed
to work with Google's current infrastructure.

### What Google Changed (December 2020)

Google disabled Google Earth for vehicles older than MY2018:
- `geoauth.google.com` (auth endpoint) → 404 Not Found
- `kh.google.com/kh/` (old tile format) → 403 Forbidden
- `mt0.google.com/vt?lyrs=s` (new tile format) → 200 OK (tiles still live!)

The satellite tiles still exist — Google just killed the old auth
endpoint and URL format that GEMMI uses.

### Fix Strategy: Self-Contained (No Proxy Server)

**Layer 1 — Auth Bypass (drivers.ini)**

libembeddedearth.so has configurable auth settings. Adding these
to /mnt/nav/gemmi/drivers.ini may skip auth entirely:

```ini
SETTINGS {
    ; ... existing settings ...
    
    ; Auth bypass
    maxLoginAttempts = 0
    disableAuthKey = true
    loginTimeout = 1
}
```

**Layer 2 — Tile Server Redirect**

Even with auth bypassed, the embedded dbRoot config still points
tiles to kh.google.com (403 blocked). Three sub-options:

  A. DefaultServer override in drivers.ini
     If this setting is honored, tiles redirect with zero binary patching.

  B. Local dbRoot file at /localdbroot path
     Custom protobuf pointing tiles to mt0.google.com.
     No binary patch needed — just a data file on the HDD.

  C. Binary patch in libembeddedearth.so (fallback)
     Swap kh.google.com (13 chars) → hausofdub.com (13 chars)
     Perfect byte-for-byte replacement at offset 0x104a5bc.
     Requires minimal PHP proxy on hausofdub.com to translate URL format.

### Patch Points (if binary patching needed)

In libembeddedearth.so (20.5 MB):
```
0x104a434: "geoauth.google.com"     (auth server — dead, 404)
0x104a5bc: "kh.google.com"          (tile server — blocked, 403)
0x1043dcc: "http://kh.google.com/"  (tile URL prefix)
```

### Testing Plan

1. Connect LTE (Digi WR11 XT → UGREEN → MMI USB)
2. Modify drivers.ini with auth bypass settings
3. Reboot MMI → check GEMMI logs via DrGER's logger scripts
4. If auth bypassed but tiles 403 → try DefaultServer override
5. If DefaultServer not honored → binary patch as fallback

### Known Working Solution (congo/audi-mib.bg)

congo (ruthr on a5oc.com) sells a patched binary for €75-180:
- Patches gemmi_final + libembeddedearth.so
- Redirects through his private proxy server
- VIN/FAZIT-specific activation
- Requires K900+ firmware (Andrew on K942 — compatible)
- audi-mib.bg — still active as of 2026
