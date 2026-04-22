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
  - AX88772D confirmed NOT compatible — D revision not recognized by QNX devn-asix.so (daredoole tested, Nov 2025)
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

## Option 4: WiFi Client Mode (Repurpose Built-in WiFi)

The MMI has a Marvell 88W8688 WiFi chip. Currently it runs as an
Access Point (192.168.1.1). Could we flip it to client mode and
connect directly to a phone hotspot — eliminating external hardware?

**The chip supports it** — the 88W8688 handles both AP and STA modes.

**But the software doesn't:**
```
What's in the firmware:
  devnp-mv8688uap.so    ← AP-only driver ("uap" = micro Access Point)
  sd8688_ap.bin          ← AP-only chip firmware
  helper_sd.bin          ← SDIO helper

What's MISSING for client mode:
  devnp-mv8688.so        ← STA/client mode driver (doesn't exist)
  sd8688.bin              ← STA mode chip firmware (not included)
  wpa_supplicant          ← WPA2 client auth (not in QNX build)
  DHCP client on wlan     ← need dhclient on WiFi interface
```

**To make this work would require:**
1. Find sd8688.bin STA firmware from Marvell SDK or Linux sources
2. Build or find a QNX 6.3 SH4 client-mode WiFi driver
3. Port wpa_supplicant to QNX 6.3.2 SH4
4. Configure DHCP client on the WiFi interface

**Status:** Hardware capable, software not present. Major project —
would need QNX 6.3 development tools (Momentics) and Marvell SDK.
Not practical as a quick fix, but could be a long-term community
project. If successful, it would eliminate ALL external hardware —
just phone hotspot → MMI WiFi client → GEMMI tiles.

**Risk:** Switching the WiFi chip to client mode would disable the
built-in hotspot AP. Could break existing WiFi-based diagnostics
and DrGER's LAN scripts that use the uap0 interface.

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

### WiFi Client Mode — Firmware Swap Discovery

The Marvell 88W8688 driver (`devnp-mv8688uap.so`) searches for
firmware in this order:

```
1. /tmp/FwImage/sd8688_ap.bin      ← checked FIRST
2. /tmp/FwImage/helper_sd.bin      ← helper checked FIRST
3. /FwImage/sd8688_ap.bin          ← IFS fallback (current)
4. /FwImage/helper_sd.bin          ← IFS fallback

Driver option: fwpath=xxx  (overrides search path, default /tmp)
```

The driver checks `/tmp/FwImage/` BEFORE the IFS copy. No IFS
modification needed to swap firmware.

#### Proposed Test

1. Download `sd8688.bin` (STA firmware) from Linux firmware repo
   https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/tree/mrvl/sd8688.bin
2. Place on SD card as `var/FwImage/sd8688_ap.bin` (same filename!)
3. Boot script:
   ```bash
   # Copy STA firmware where driver looks first
   mkdir -p /tmp/FwImage
   cp /mnt/sdcard/var/FwImage/sd8688_ap.bin /tmp/FwImage/
   # Kill AP driver
   slay -f devnp-mv8688uap
   sleep 2
   # Driver restarts, finds STA firmware in /tmp first
   ```
4. Or restart with fwpath override:
   ```bash
   io-pkt-v4 -d devnp-mv8688uap.so fwpath=/mnt/sdcard/var
   ```
5. Check `ifconfig` — look for `wlan0` or `sta0` instead of `uap0`

#### Risks

- Driver binary is AP-mode code — sends AP-specific commands
- STA firmware might not respond correctly to AP commands
- Worst case: WiFi crashes, reboot restores IFS firmware
- Best case: Marvell does mode logic in firmware, thin driver works

#### Status: UNTESTED / ALPHA

Documented for future experimentation. Safe to test — reboot
always restores clean IFS firmware. No permanent changes.

## FRF Firmware Decryption — WORKING

Successfully decrypted VW/Audi FRF flash containers using bri3d's
recursive XOR cipher with the public `frf.key` from VW_Flash.

### C7 Kombi (4G8920_10) Flash Layout

| Block | Type | Compressed | Uncompressed | Version |
|-------|------|-----------|--------------|---------|
| 1 | Boot/cal | 1.5KB | 3KB | - |
| 2 | Software | 461KB | 1MB | 0044 |
| 4 | Main app | 4.9MB | 12.5MB | 0016 |
| 5 | App pt2 | 3.8MB | 8.4MB | 0044 |
| 6 | Graphics | 4.8MB | 9.4MB | 0001 |
| 7 | Resources| 2.4MB | 5.2MB | 0008 |
| 9 | Config | 272B | 320B | 0044 |

Security: SA2 + SHA1-RSA1024 with CRC32
Encrypt method: 0x11 (not Simos 0x0A — different decompressor needed)

### Tools
- FRF decryption: `bri3d/VW_Flash/frf/decryptfrf.py`
- Key file: `bri3d/VW_Flash/data/frf.key` (4095 bytes, public)
- Produces ZIP → ODX (XML flash container)

### OEM LTE Module Swap — Research Path

**Status: Feasibility assessed, not yet attempted**

The MMI3G+ J794 contains a Telit UC864-AWS-AUTO 3G UMTS modem on an
internal LGA board. With 3G networks sunset globally, the question is
whether a compatible LTE module can be swapped in.

#### Current Architecture

```
NWSProcess → libmodemservice.so → pppd → USB serial → Telit UC864 → 3G
     (IFS)        (EFS, writable!)   (IFS)   (generic)    (hardware)
```

Key finding: `libmodemservice.so` is on the **writable EFS partition**,
NOT the read-only IFS. This means the modem service library can be
modified or replaced via SD card script — no firmware reflash needed.

#### AT Command Flow (from libmodemservice.so strings)

```
ATZ                    → Reset modem
AT+CBST=%d,%d,%d       → Set bearer service type
ATDT%s                 → Dial data connection
```

Standard PPP chat script. Most LTE modems support legacy PPP mode
(`ATDT*99#`) for backward compatibility.

#### Telit.bin — Modem Firmware

The Flashdaten includes `Telit/Main/100/default/Telit.bin` (13.8MB).
This is the modem's own firmware, flashed separately from QNX. Each
Telit module family has its own firmware blob.

#### What Would Need to Change for LTE

1. **Physical module** — Telit UC864 uses a specific LGA footprint.
   Telit LTE modules (LE910, LE920 series) use different form factors.
   An adapter PCB or a compatible LTE module would be needed.

2. **Telit.bin** — New modem firmware for the LTE module. Available
   from Telit for their supported modules.

3. **libmodemservice.so** (EFS, writable) — May work as-is if the LTE
   modem supports legacy PPP AT commands. If not, this `.so` can be
   replaced via SD card without reflashing IFS.

4. **APN configuration** — Update for carrier's LTE APN settings.

5. **pppd** (IFS) — Standard PPP daemon, likely compatible with any
   modem that presents a USB serial interface.

#### Feasibility Assessment

| Component | Difficulty | Notes |
|-----------|-----------|-------|
| Physical swap | Hard | Different LGA footprint, needs adapter |
| Modem firmware | Medium | Telit provides tools for flashing |
| libmodemservice.so | Easy | Writable EFS, replaceable via SD |
| APN/PPP config | Easy | Standard AT command changes |
| QNX USB serial driver | None | Generic `devc-serusb` handles any USB serial |

**Bottom line:** The software side is surprisingly doable — the blocker
is finding a physically compatible LTE module. The QNX side barely needs
to change since the cellular stack uses standard PPP over USB serial.

#### Alternative: External LTE (Proven, Recommended)

DrGER's approach bypasses all modem compatibility issues:

```
USB ethernet (AX88772A) → External LTE router → Any carrier SIM
```

The MMI doesn't care HOW it gets internet — it just needs `en5` to have
an IP address and DNS resolution. The existing DHCP config from the
original 3G connection (`/mnt/efs-persist/usedhcp`) is still in place.

#### Community References

- DrGER — A5OC thread: extensive research on Telit module internals
- daredoole — Confirmed AX88772A works, AX88772D does NOT
- Audi Service Action 91CD — Mojio OBD-II dongle (NOT an MMI solution)
- Audizine/AudiWorld — Multiple threads, nobody has done the LTE swap
