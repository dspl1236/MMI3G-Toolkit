# Google Earth Restoration for MMI3G+ — Complete Guide

## Status: WORKING ✅
Satellite imagery confirmed rendering on Audi MMI3G+ (K0942 firmware).
Tiles from Google's live servers (kh.google.com) at zoom levels 1-22+.

## Architecture

### Current (PC Proxy)
```
MMI3G+ (GEMMI) → /etc/hosts → PC Proxy (port 80)
                                 ├── dbRoot: local file
                                 ├── Auth: local cached responses
                                 └── QT + Tiles: kh.google.com (HTTPS)
```

### Target (Self-Contained SD Card)
```
MMI3G+ (GEMMI) → /etc/hosts → 127.0.0.1 mini-server
                                 ├── dbRoot: /mnt/nav/gemmi/dbRoot.bin
                                 ├── Auth: /mnt/nav/gemmi/auth.bin
                                 └── QT + Tiles: kh.google.com (direct via LTE)
                                     (server URL configured IN the dbRoot)
```

## Components

### 1. Binary Patches (libembeddedearth.so)

**CODE PATCH 1 — Image Validation Bypass (0x343d20)**
```
Original: 86 2f 1f c7 96 2f  (function prologue)
Patched:  01 e0 0b 00 09 00  (mov #1,r0; rts; nop)
```
Forces image validation to return TRUE. Called from:
- Image loader (JPEG/EXIF processing pipeline)
- Rendering engine (GL/shader pipeline)

**CODE PATCH 2 — Post-Validation Skip (0x3470a0)**
```
Original: 86 2f 2d c7  (function prologue)
Patched:  0b 00 09 00  (rts; nop)
```
Skips post-validation DRM/metadata processing.

**Purpose:** These are NOT auth patches. They bypass tile data validation
in the image processing pipeline. Auth is handled by redirecting the
auth server URL (either via hostname patches or via the dbRoot config).

### 2. dbRoot Configuration

The dbRoot is an encrypted protobuf containing server configuration.
Key fields discovered inside the decrypted dbRoot:

```
[geoServer.host]   — tile/quadtree server (set to kh.google.com)
[ypServer.host]    — yellow pages server
[authServer.host]  — authentication server (set to 127.0.0.1 for local)
```

Plus KML layer URLs for borders, roads, labels, weather, etc.

**dbRoot format:** EncryptedDbRootProto protobuf
- Field 1: encryption_type = 0 (XOR)
- Field 2: encryption_data = 1016-byte GEE default key
- Field 3: dbroot_data = encrypt(KhPkt(DbRootProto))

**KhPkt format:** magic(0x7468dead) + size(4) + zlib(data)

### 3. GEE Encryption Algorithm

From open-source `google/earthenterprise` (etencoder.cc).
Modified XOR with rotating key offset.

```python
def gee_encode(data, key):
    data = bytearray(data)
    keylen = len(key); dp = 0; off = 8; kp = 0
    while dp + 8 <= len(data):
        off = (off + 8) % 24; kp = off
        while dp + 8 <= len(data) and kp < keylen:
            for i in range(8): data[dp+i] ^= key[kp+i]
            dp += 8; kp += 24
    if dp < len(data):
        while kp >= keylen:          # CRITICAL: check kp, not off
            off = (off + 8) % 24; kp = off
        while dp < len(data):
            data[dp] ^= key[kp]; dp += 1; kp += 1
    return bytes(data)
```

**Key:** 1016-byte default key (public, from GEE open source).
**Bug found:** Original remaining-bytes handler checked `off >= keylen`
(never true, off < 24). Fixed to `kp >= keylen`.

### 4. Tile Format

**Imagery tiles:** `gee_encode(raw_jpeg)` — XOR encrypted 256x256 JPEG
**Terrain tiles:** `gee_encode(KhPkt(terrain_data))` — encrypted KhPkt
**Quadtree packets:** `gee_encode(KhPkt(QuadtreePacket16))` — encrypted KhPkt

### 5. Quadtree Coordinate System

GEE uses a quadtree path starting with root "0". Digit convention:
```
order[right][top] = { {0, 3}, {1, 2} }

Digit 0: col_bit=0, row_bit=0  (bottom-left)
Digit 1: col_bit=1, row_bit=0  (bottom-right)
Digit 2: col_bit=1, row_bit=1  (top-right)
Digit 3: col_bit=0, row_bit=1  (top-left)
```

Conversion to Google Maps x,y,z:
```python
def gee_path_to_xyz(qtpath):
    path = qtpath[1:]  # strip root "0"
    z = len(path)
    col = row = 0
    for i, ch in enumerate(path):
        d = int(ch)
        bit = z - 1 - i
        if d == 0:   cb, rb = 0, 0
        elif d == 1: cb, rb = 1, 0
        elif d == 2: cb, rb = 1, 1
        elif d == 3: cb, rb = 0, 1
        col |= cb << bit; row |= rb << bit
    google_y = (2**z - 1) - row
    return col, google_y, z
```

### 6. Auth Protocol

Two-phase authentication:
1. POST /geauth (39 bytes) → 16 bytes (cmd echo + nulls)
2. POST /geauth (49 bytes) → 136 bytes (static response, cacheable)

Both responses are static and can be served from local files.

## kh.google.com — Still Live!

Google's Earth servers still respond to the old GEE flatfile protocol:
- `GET /dbRoot.v5?output=proto&hl=en&gl=us` → 17627 bytes
- `GET /flatfile?q2-0` → 145 bytes (quadtree root)
- `GET /flatfile?f1-0-i.1030` → 6910 bytes (root tile, JPEG)
- Tiles served at zoom levels 1-22+ with real satellite imagery

## SD Card Payload (TODO)

### Files to Deploy
```
/mnt/nav/gemmi/
  ├── libembeddedearth.so      (code patches applied)
  ├── dbRoot.bin               (custom, geoServer→kh.google.com)
  ├── auth_resp1.bin           (16 bytes, cached)
  ├── auth_resp2.bin           (136 bytes, cached)
  ├── run_gemmi.sh             (starts mini-server + GEMMI)
  └── gemmi_server.sh          (minimal HTTP server for dbRoot/auth)
```

### Installation Script
1. Backup originals as *.orig
2. Apply code patches to libembeddedearth.so (2 offsets, 10 bytes total)
3. Deploy dbRoot and auth files
4. Deploy modified run_gemmi.sh with mini-server startup
5. Set /etc/hosts: kh.google.com → 127.0.0.1

### Mini HTTP Server (gemmi_server.sh)
Shell script using nc.shle that:
- Listens on 127.0.0.1:80
- Serves /dbRoot.v5 → dbRoot.bin (local)
- Serves /geauth → auth response (local)
- All other requests → 302 redirect to https://kh.google.com
  (or transparent proxy if car's network supports it)

## Discovery Timeline
- Auth bypass: hostname redirects + cached responses
- GEE encryption: open-source algorithm with bug fix
- Tile format: encrypted raw JPEG (discovered by decoding xgx tiles)
- Coordinate system: reverse-engineered from GEE source
- kh.google.com: discovered still live and serving tiles
- Image validation patches: reverse-engineered from SH4 disassembly
- dbRoot server config: discovered geoServer/authServer fields

## Credits
- GEE encryption algorithm: google/earthenterprise (Apache 2.0)
- Binary patch offsets: community research (mhhauto)
- Proxy, analysis, and documentation: dspl1236/MMI3G-Toolkit

## Web App — SD Card Payload Generator (TODO)

Browser-based tool (like PCM-Forge docs/index.html) that:

1. **User uploads** their `libembeddedearth.so` from `/mnt/nav/gemmi/`
2. **Web app verifies** firmware version (K0942, etc.)
3. **Applies patches:**
   - CODE PATCH 1 @ 0x343d20 (image validation bypass)
   - CODE PATCH 2 @ 0x3470a0 (post-validation skip)
4. **Generates:**
   - Custom dbRoot (geoServer → kh.google.com)
   - Cached auth responses
   - Mini HTTP server script
   - Modified run_gemmi.sh
   - Installation script
5. **Downloads** complete SD card package as ZIP
6. **Instructions** for deployment via engineering shell

### Tech Stack
- Pure HTML/JS (runs in browser, no server needed)
- Binary patching via ArrayBuffer/DataView
- GEE encryption for dbRoot generation
- ZIP packaging via JSZip or similar

### User Experience
1. Open web page
2. Upload .so file
3. Click "Generate"
4. Download ZIP
5. Copy to SD card
6. Run install script from MMI shell
7. Google Earth works! 🛰️

## Web App Integration (docs/index.html)

### Google Earth Module Features
1. **Binary Patcher** — applies 2 code patches + hostname patches to libembeddedearth.so
   - User uploads their original .so (or selects firmware version)
   - App applies patches at 0x343d20 and 0x3470a0
   - App patches hostname strings (kh.google.com → 127.0.0.1 for dbRoot)
   - Downloads patched .so

2. **dbRoot Generator** — builds custom dbRoot with user's config
   - geoServer.host → kh.google.com (default)
   - Embedded GEE encryption key (public, from open source)
   - Downloads dbRoot_custom.bin

3. **SD Card Package Builder** — generates complete deployment package
   - Patched libembeddedearth.so
   - Custom dbRoot
   - Cached auth responses
   - Mini server script (gemmi_server.sh)
   - Modified run_gemmi.sh
   - Install/uninstall scripts
   - All in a ZIP ready to extract to SD card

4. **Instructions** — step-by-step with screenshots
   - How to access engineering shell
   - How to deploy via SD card
   - How to verify it's working
   - How to revert to stock

### SD Card Structure
```
SD:/
├── install_ge.sh           (main installer)
├── uninstall_ge.sh         (revert to stock)  
├── gemmi/
│   ├── libembeddedearth.so (patched)
│   ├── dbRoot_custom.bin
│   ├── auth_resp1.bin
│   ├── auth_resp2.bin
│   ├── gemmi_server.sh     (mini HTTP server)
│   ├── gemmi_control.sh    (start/stop/restart)
│   └── run_gemmi.sh        (modified startup)
└── README.txt
```
