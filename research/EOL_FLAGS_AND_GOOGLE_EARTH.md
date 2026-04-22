# EOL Flags & Google Earth Restoration Research

## Overview

The MMI3G/RNS-850 UI is implemented in `lsd.jxe`, a ~27MB J9 JXE bundle
at `/mnt/ifs-root/lsd/lsd.jxe`. This file is a standard ZIP archive
containing 342 files including compiled Java classes (`rom.classes`),
configuration properties, resources, and certificates.

**EOL (End-of-Line) flags** in `sysconst.properties` control which features
are available. These are set at the factory based on market (NAR/EU/CN/JP)
and variant (Audi/VW/Bentley). The key discovery: the same binary contains
code for ALL markets — features are enabled/disabled purely by flag values.

## lsd.jxe Structure

```
lsd.jxe (27MB ZIP, 342 files)
├── rom.classes              — compiled J9 class archive
├── project.properties
├── startup.properties
├── META-INF/
│   ├── JXE.MF
│   ├── certs/               — VW root CA, T-Systems, VeriSign
│   └── properties/
│       ├── MMI3G_MyAudi.properties[.eu|.nar]
│       ├── poiproducer.properties[.eu|.nar]
│       └── cert.properties
├── resources/
│   ├── bundles.properties   — OSGi bundle list
│   ├── lastmode.properties
│   ├── atip.properties
│   ├── sysconst/
│   │   ├── sysconst.properties    ← MASTER CONFIG (1617 EOLFLAG entries)
│   │   ├── sysconst.config
│   │   ├── map.properties
│   │   ├── variant.properties     ← variant selector
│   │   └── variants/
│   │       ├── high_nav_nar.properties        ← Audi NAR
│   │       ├── high_nav_eu_rdw.properties     ← Audi EU
│   │       ├── vw_high_nar.properties         ← VW NAR (Touareg)
│   │       ├── vw_high_eu.properties          ← VW EU
│   │       ├── bentley_high.properties
│   │       ├── con_high_nav_*.properties      ← Continental
│   │       ├── nad_active.properties          ← NAD modem active
│   │       ├── nav_active.properties
│   │       ├── hfp_active.properties
│   │       ├── no_online_services.properties
│   │       └── ...
│   └── [App resources, HMI images, message data]
└── org/dsi/info/DSIInfo.bin
```

## Google Earth — Key EOL Flags

### Master defaults (sysconst.properties)

```properties
EOLFLAG_GOOGLE_EARTH=0                  # OFF by default
EOLFLAG_INNOVATIONFEATURES=0            # OFF — controls GE UI toggle
EOLFLAG_ONLINE_SERVICES=0               # OFF — online services menu
EOLFLAG_NAD=0                           # OFF — network adapter present
```

### Audi EU (high_nav_eu_rdw.properties)

```properties
EOLFLAG_INNOVATIONFEATURES=1            # ← ENABLES Google Earth UI
EOLFLAG_HU_VARIANT=5
EOLFLAG_HU_REGION=0                     # EU region
```

### Audi NAR (high_nav_nar.properties)

```properties
# NO EOLFLAG_INNOVATIONFEATURES set     # ← Google Earth UI absent
# NO EOLFLAG_GOOGLE_EARTH override
EOLFLAG_HU_VARIANT=6
EOLFLAG_HU_REGION=1                     # NAR region
```

### VW NAR (vw_high_nar.properties) — Daredoole's Touareg

```properties
# NO EOLFLAG_INNOVATIONFEATURES set
EOLFLAG_HU_VARIANT=15
EOLFLAG_HU_REGION=1                     # NAR region
```

### VW variants — Google Earth EXPLICITLY BLOCKED

```properties
# In vw_high_eu.properties, vw_high_cn.properties, vw_high_jp.properties:
RANGE_EOLFLAG_GOOGLE_EARTH=0            # RANGE_ prefix = hard constraint
# Comment: "Google Earth and Online Services are not available on VW"
```

### no_online_services.properties

```properties
RANGE_EOLFLAG_GOOGLE_EARTH=0            # Also blocks GE when no online
```

## Platform Comparison

| Feature | Audi EU | Audi NAR | VW EU | VW NAR |
|---------|---------|----------|-------|--------|
| GEMMI binaries | ✅ | ✅ (confirmed on C7 A6) | ✅ | ❌ Missing |
| EOLFLAG_GOOGLE_EARTH | 0 (default) | 0 (default) | 0 (RANGE blocked) | 0 (RANGE blocked) |
| EOLFLAG_INNOVATIONFEATURES | 1 | 0 | 0 | 0 |
| Google Earth UI visible | ✅ | ❌ | ❌ | ❌ |
| LAN connectivity | ✅ | ✅ (with DrGER script) | ✅ | ✅ (DrGER script) |

## Audi MMI3G+ — Google Earth Restoration Path

**Andrew's 2013 A6 (HN+R_US_AU_K0942_3)**

Your car already has:
- ✅ GEMMI 8.0.25 installed at `/mnt/nav/gemmi/gemmi_final`
- ✅ embeddedearth 5.2.0.6394
- ✅ AROMA 2.1.4 (20110707)
- ✅ libhydragoogle 5.0.3
- ✅ GEM `/googleearth/Console` screen present and reporting versions

What's needed:
1. **Set `EOLFLAG_INNOVATIONFEATURES=1`** in lsd.jxe
   - Use `eol_modifier.py --enable EOLFLAG_INNOVATIONFEATURES`
   - This enables the Google Earth toggle in Nav → Map Display
2. **Set `EOLFLAG_GOOGLE_EARTH=1`** (may also be needed)
3. **Internet connectivity** (LTE router via USB ethernet)
4. **Auth bypass** — modify `drivers.ini` for tile server redirect
   - Congo's script handles this, OR
   - Our GEMMI_PATCH_MAP.md documents the manual approach

### Deployment via IFS modification

```bash
# 1. Decompress IFS
python3 tools/inflate_ifs.py ifs-root.ifs --extract working/

# 2. Extract and modify lsd.jxe
python3 tools/eol_modifier.py working/lsd/lsd.jxe \
    --output working/lsd/lsd.jxe \
    --enable EOLFLAG_GOOGLE_EARTH \
    --enable EOLFLAG_INNOVATIONFEATURES

# 3. Rebuild IFS
python3 tools/patch_ifs.py ifs_decomp.ifs ifs_patched.ifs \
    --replace lsd/lsd.jxe=working/lsd/lsd.jxe

# 4. Recompress
python3 tools/repack_ifs.py ifs_patched.ifs new_ifs-root.ifs

# 5. Fix CRCs and flash
python3 tools/mu_crc_patcher.py ...
```

### Alternative: Runtime modification (no reflash)

If `sysconst.properties` is read from a writable location at runtime,
it may be possible to override flags without IFS modification. The
`SysConstManager.initFromProperties()` method (found in rom.classes)
loads properties at boot — need to investigate the load order.

## VW RNS-850 — Google Earth Restoration Path

**Daredoole's 2016 Touareg (HN+_US_VW_P0738)**

Current state:
- ❌ No GEMMI binaries (`/mnt/nav/gemmi/` does not exist)
- ❌ No Google Earth GEM screen
- ❌ `RANGE_EOLFLAG_GOOGLE_EARTH=0` in VW variants (hard block)
- ✅ LAN connectivity working (DrGER script + TP-Link MR3020)
- ✅ IP address assigned, can ping Google

### Step 1: Deploy GEMMI binaries from EU firmware

Source: `HN+R_EU_VW_P0824_RNS850` GEMMI package

Files to copy to `/mnt/nav/gemmi/`:
```
gemmi_final              — main binary (SH4 ELF)
libembeddedearth.so      — Google Earth renderer
libmessaging.so          — IPC library
drivers.ini              — configuration (modify for auth bypass)
run_gemmi.sh             — launch script
mapStylesWrite           — map style tool
models/                  — cursor/POI/traffic icons (80+ PNGs)
res/                     — VW fonts (3 TTFs)
```

### Step 2: Enable Google Earth in lsd.jxe

The VW variants have `RANGE_EOLFLAG_GOOGLE_EARTH=0` which is a hard
constraint. Two approaches:

**Option A:** Change variant from `vw_high_nar` to `high_nav_nar` (Audi)
- Removes the RANGE constraint
- Side effect: changes boot branding to Audi
- May cause other UI differences

**Option B:** Modify the VW variant properties
- Remove `RANGE_EOLFLAG_GOOGLE_EARTH=0` from VW variant
- Add `EOLFLAG_GOOGLE_EARTH=1`
- Add `EOLFLAG_INNOVATIONFEATURES=1`
- Requires IFS modification (same pipeline as Audi)

**Option C:** Congo's commercial solution
- Claims to work on US firmware
- Likely includes modified GEMMI binaries + patched drivers.ini
- May bypass the lsd.jxe UI requirement through an alternative display path

### Step 3: Auth bypass

The `drivers.ini` file controls Google Earth tile server authentication:
```ini
Connection/enableSeamlessLogin = true
```

Since Google's original tile servers are sunset, tiles must be proxied.
Congo's solution includes a tile redirect. Our GEMMI_PATCH_MAP.md
documents the architecture for a self-hosted approach.

### Step 4: Launch GEMMI

DrGER's GEMMI Monitor script handles the launch sequence.
The `run_gemmi.sh` script from the EU firmware:
1. Detects region from `/etc/hmi_country.txt`
2. Checks RSE flag
3. Creates cache directories at `/mnt/img-cache/gemmi/`
4. Launches `gemmi_final` with rendering parameters
5. Auto-restarts up to 5 times on crash

Key launch parameters:
```
-maxmem 55 -targetmem 40     # Memory limits
-maxfps 12                    # Frame rate cap
-trafficregion $myRegion      # 0=NAR, 1=ASIA, 2=EU
-maxpingtime 2000             # Tile server timeout
--tp=/etc/DefaultScope.hbtc   # Tile proxy config
--bp                          # Boot parameter
```

## GEMMI Binary Inventory (EU P0824)

| File | Purpose |
|------|---------|
| gemmi_final | Main Google Earth renderer (SH4 ELF) |
| libembeddedearth.so | Google Earth embedded library |
| libmessaging.so | IPC/messaging library |
| drivers.ini | Configuration (render, cache, network) |
| run_gemmi.sh | Launch script with region detect + restart |
| debug_gemmi.sh | Debug mode launcher |
| debug_memcpu.sh | Memory/CPU monitoring |
| pg.sh | Unknown (likely process group) |
| mapStylesWrite | Map style configuration tool |
| models/ | 80+ PNGs: cursors, POI icons, traffic overlays |
| res/ | VW fonts: ThesisSans Light/Regular/Semibold |

## drivers.ini Key Settings

```ini
# Cache: 1.8GB tile cache on HDD
DiskCache/cacheSize = 1800

# Network: seamless login (auth bypass relevant)
Connection/enableSeamlessLogin = true

# Rendering: DXT texture compression, mipmaps enabled
Render/textureCompressionDXTC = true
enableMipmaps = true

# Performance: icon scaling, drawable offsets
Drawables/iconScale = 1.5
Drawables/drawableOffset = 0.1

# Road rendering with car navigation POI
RoadRendering/EnableCarNavigationPOI = true

# Network: max 10 pending tile requests
Network/maxRequestsBacklog = 10
```

## Next Steps

### For Andrew's A6
1. [ ] Extract lsd.jxe from car's IFS
2. [ ] Run `eol_modifier.py --list` to check current flag state
3. [ ] Test with `EOLFLAG_INNOVATIONFEATURES=1` + `EOLFLAG_GOOGLE_EARTH=1`
4. [ ] Set up LTE connectivity (Digi WR11 XT already planned)
5. [ ] Test tile proxy / auth bypass

### For Daredoole's Touareg
1. [ ] Share this research on ClubTouareg thread
2. [ ] Deploy GEMMI binaries from EU P0824 firmware
3. [ ] Investigate `RANGE_` constraint bypass in lsd.jxe
4. [ ] Test with DrGER's GEMMI Monitor script
5. [ ] Coordinate with Congo on commercial solution compatibility

### Research Questions
- Does `SysConstManager` check RANGE constraints at runtime or build time?
- Can variant properties be overridden from a writable partition?
- Does the NAR MMI3GApplication binary support GEMMI IPC, or is it EU-only?
- What does the `--bp` flag do in gemmi_final?

## Source Firmware

| Train | Platform | Region | GEMMI | Google Earth UI |
|-------|----------|--------|-------|-----------------|
| HN+R_US_AU_K0942_3 | Audi MMI3G+ (MU9411) | NAR | ✅ Installed | ❌ Flag disabled |
| HN+R_EU_VW_P0824 | VW RNS-850 (MU9478) | EU | ✅ Full package | ✅ Enabled |
| HN+_EU_VW_P0534 | VW RNS-850 (MU9478) | EU | ✅ Full package | ✅ Enabled |
| HN+_US_VW_P0738 | VW RNS-850 (MU9478) | NAR | ❌ Not included | ❌ Blocked |

## Related Research

- **GEMMI_PATCH_MAP.md** — Binary patch points in gemmi_final and
  libembeddedearth.so for Google hostname and auth bypass
- **tools/eol_modifier.py** — CLI tool to modify EOL flags in lsd.jxe

## Congo's GEMMI Restoration — Reverse Engineering Analysis

### How It Works (inferred from forum analysis)

Congo (audi-mib.bg) runs a **proxy tile server** in Bulgaria that
intercepts GEMMI's Google Earth tile requests and fulfills them:

```
ORIGINAL (pre-Dec 2020):
  gemmi_final → VAG/Google GE servers → satellite tiles
  (blocked for pre-MY2018 after Dec 2020 license expiry)

CONGO'S APPROACH:
  patched gemmi_final → Congo's proxy → Google Earth API → tiles
  (proxy handles auth, VIN validation bypassed)
```

### Key Technical Findings

1. **gemmi_final is a standalone native SH4 binary** — it runs as a
   separate QNX process, NOT inside the J9 JVM. It provides map tile
   overlay data to MMI3GApplication via IPC.

2. **The RANGE_EOLFLAG_GOOGLE_EARTH=0 blocks the UI MENU only** — it
   prevents the Google Earth option from appearing in the nav map
   settings. But if gemmi_final is running and providing tile data,
   MMI3GApplication has code to consume it regardless.

3. **GEMMI binaries can be deployed to writable EFS** — they don't need
   to be in the read-only IFS. DrGER confirmed: "you can add the
   gemmi_final binary from any MMI3GP source easily enough."

4. **DataPST.db modification** — Congo likely modifies the SQLite HMI
   persistence database to enable the Google Earth UI option, bypassing
   the EOLFLAG check at the Java/UI layer.

5. **VIN/BTMAC binding** — Congo uses the vehicle's BTMAC and VIN to
   generate a unique activation package, tying the proxy authentication
   to a specific vehicle.

### What Congo's SD Card Package Contains (inferred)

```
1. gemmi_final          — patched binary (proxy hostname changed)
2. libembeddedearth.so  — Google Earth rendering library (~20MB)
3. GEMMI config files   — drivers.ini, res/, models/
4. run_gemmi.sh         — startup script for gemmi_final
5. DataPST.db patch     — enables GE UI option in Java layer
6. DNS/host redirect    — points GE hostname to proxy server
```

### The Proxy Server

Congo's proxy likely:
- Accepts tile requests from gemmi_final (same API as original VAG server)
- Authenticates against vehicle BTMAC/VIN (his licensing system)
- Fetches tiles from Google Earth API (using his own API key or scraping)
- Returns tiles to the MMI in the expected format

### Open Questions for Our Research

1. **Can we identify the Google Earth hostname?** — Check
   `libembeddedearth.so` strings for URLs/hostnames
2. **What's the tile API format?** — The request/response protocol
3. **Can DNS redirection replace binary patching?** — Simpler approach
   if gemmi_final reads hostname from config vs hardcoded
4. **Self-hosted tile proxy?** — An open-source proxy using free
   satellite imagery (Bing Maps, Mapbox, etc.) instead of Google

### Google Earth Server Endpoints (from gemmi_final strings)

```
# StreetView tile server (cbk = "click back" / panorama server)
http://cbk0.google.com/cbk?output=tile&panoid=%s&zoom=%u&x=%u&y=%u&cb_client=auto.audi
http://cbk0.google.com/cbk?output=xml&ll=%.6f,%.6f&cb_client=auto.audi
http://cbk0.google.com/cbk?output=xml&panoid=%s&cb_client=auto.audi

# Street View API
http://maps.googleapis.com/maps/api/streetview?fov=60&size=%dx%d&location=%lf,%lf&sensor=false

# KML POI overlays
http://maps.google.com/mapfiles/kml/pushpin/red-pushpin.png
http://maps.google.com/mapfiles/kml/paddle/red-circle.png

# Client identifier
cb_client=auto.audi
```

### Configurable Server (from libembeddedearth.so)

The strings `?server=` and `DefaultServer` in libembeddedearth.so
indicate the tile server hostname is **configurable**, not just
hardcoded. This opens three bypass approaches:

1. **DNS redirect** — Point `cbk0.google.com` to a proxy via
   `/etc/resolv.conf` or a local DNS server on the LTE router
2. **Command-line arg** — gemmi_final may accept a `-server` parameter
3. **Config file** — drivers.ini `Connection/` settings

### Developer Breadcrumb

Build path found in gemmi_final:
```
D:\CMandal\GEarth_products\sh4-qnx-m632-3.4.4-osp-trc-rel\gen\project\devctrl\interface\hydragoogle\src\dsi2\SPHydraGoogle.c
```

Developer: C. Mandal at Harman-Becker, using the "HydraGoogle" DSI
interface project. The `-osp-trc-rel` suffix indicates "OSP trace
release" build — an automotive-grade build with trace logging.

### gemmi_final Command-Line Options

```
-logintimeout <seconds>     — time to wait for login server
-nogooglepois               — disable Google POI overlay
-maxmem <megabytes>         — memory limit (default ~13MB)
-maxfps <fps>               — frame rate limit
-maxcpu <value>             — CPU usage limit (0-1)
-dontusegps                 — disable GPS input
-disableroute               — disable route drawing
-cursormodel <path>         — custom cursor model (default: AudiCursor.dae)
-gpssource <source>         — GPS data source
```

### Complete GEMMI Server Configuration Map

All configurable server parameters found in `libembeddedearth.so`:

| Parameter | Purpose |
|-----------|---------|
| `loginServer` | Primary login endpoint |
| `authServer` | Authentication server |
| `geFreeLoginServer` | **FREE login server** (no license!) |
| `disableAuthKey` | **Disable auth key validation!** |
| `enableSeamlessLogin` | Auto-login (already TRUE in drivers.ini) |
| `deauthServer` | De-authentication |
| `metaDataFetchServer` | Tile metadata |
| `depthMapFetchServer` | Depth map tiles |
| `reverseGeocodingServer` | Reverse geocoding |
| `csiLogServer` | Client-side logging |
| `bbsServer` | Bulletin board |
| `googleMFEServer` | Google Maps frontend |

### Protocol Flow

```
1. CONNECT    → kh.google.com (DefaultServer)
2. AUTH       → /geauth (or geFreeLoginServer)
3. DBROOT     → dbRoot.v5 (protobuf — contains all tile URLs)
4. TILES      → /flatfile?db=&t=&q=&channel=&version= 
5. STREETVIEW → cbk0.google.com/cbk?output=tile&...
6. WEATHER    → mw1.google.com/mw-weather/clouds/root.kmz
7. GEOCODE    → maps.google.com/maps/api/earth/GeocodeService
```

### Self-Hosted Proxy Architecture

The protocol is **Google Earth Enterprise** (GEE), which Google
open-sourced in 2017 (github.com/google/earthenterprise, archived).

A self-hosted tile proxy needs:

```
DNS: kh.google.com → 192.168.x.x (LTE router DNS override)

Proxy endpoints:
  /geauth              → return valid auth response (static)
  /dbRoot.v5           → return custom protobuf (points to proxy)
  /flatfile?q=QUADKEY  → fetch tile from Bing/Mapbox/etc, convert format
  /localdbroot         → local database config
```

### Bypass Approaches (Easiest to Hardest)

1. **drivers.ini + DNS redirect** (no binary mod)
   - Set `disableAuthKey` in drivers.ini on EFS
   - DNS redirect `kh.google.com` on LTE router
   - Proxy serves free tiles

2. **gemmi_final command-line args** (no binary mod)
   - Launch with custom server args
   - Modify `run_gemmi.sh` startup script

3. **dbRoot override** (no binary mod)
   - Serve custom dbRoot protobuf from proxy
   - dbRoot contains ALL server URLs — one redirect rules them all

4. **Binary patch** (Congo's likely approach)
   - Replace `kh.google.com` hostname in binary
   - Most reliable but requires binary modification

### Open-Source Tile Sources

| Source | Format | Free Tier |
|--------|--------|-----------|
| Bing Maps | Quadkey tiles | Yes (terms apply) |
| Mapbox | Raster tiles | 200K/month free |
| OpenStreetMap | PNG tiles | Free (attribution) |
| Thunderforest | PNG tiles | 150K/month free |
| Google Maps Static | PNG | 28K loads/month |

### Local DNS Redirect — No External Proxy Needed

gemmi_final uses standard POSIX DNS resolution. The lookup order is:

```
1. /etc/hosts          ← Static hostname file (checked FIRST)
2. /etc/host.conf      ← Resolution order config  
3. HOSTALIASES env var ← Shell-level aliases
4. /etc/resolv.conf    ← DNS server (checked LAST)
```

A simple SD card startup script can redirect ALL Google Earth traffic
locally by creating `/etc/hosts`:

```sh
#!/bin/ksh
# Redirect Google Earth to local tile proxy (LTE router)
PROXY_IP="192.168.0.1"   # Digi WR11 XT IP

echo "$PROXY_IP kh.google.com"          >> /etc/hosts
echo "$PROXY_IP cbk0.google.com"        >> /etc/hosts  
echo "$PROXY_IP maps.googleapis.com"    >> /etc/hosts
echo "$PROXY_IP mw1.google.com"         >> /etc/hosts
```

This keeps everything local — no external DNS server, no third-party
proxy. The Digi WR11 XT (Linux-based) runs a lightweight tile proxy
that serves satellite imagery from free sources.

### RANGE_ Flag Mechanism Explained

The `RANGE_` prefix in sysconst properties creates a **hard constraint**
on the allowed values for a flag. Normal `EOLFLAG_X=0` is a soft default
that can be overridden. `RANGE_EOLFLAG_X=0` means "the ONLY allowed
value for X is 0" — no other config file can set it to 1.

```
EOLFLAG_GOOGLE_EARTH=0         → soft default, CAN be overridden
RANGE_EOLFLAG_GOOGLE_EARTH=0   → HARD LOCK, cannot be overridden
```

### Per-Variant Google Earth Status

| HU_VARIANT | Platform | RANGE_GE Block? | GE Possible? |
|-----------|----------|-----------------|--------------|
| 5 | Audi EU | ❌ No | ✅ Yes — just flip flag |
| **6** | **Audi NAR** | **❌ No** | **✅ Yes — Andrew's car!** |
| 7 | Japan | ✅ Yes | ❌ Needs IFS mod |
| 8 | China | ❌ No | ✅ Yes |
| 9 | Korea | ✅ Yes | ❌ Needs IFS mod |
| 15 | VW EU/NAR | ✅ Yes | ❌ Needs IFS mod |
| 16 | Bentley | ✅ Yes | ❌ Needs IFS mod |

### Andrew's A6 — Google Earth Restoration Path

Andrew's car (HU_VARIANT=6, K0942_3) has NO RANGE_ blocks on
Google Earth. The complete restoration requires:

1. **Internet connection** — USB ethernet + Digi WR11 XT LTE router
2. **Flip EOLFLAG_GOOGLE_EARTH=1** — via DataPST.db on writable EFS
3. **Flip EOLFLAG_INNOVATIONFEATURES=1** — same method
4. **DNS redirect** — `/etc/hosts` pointing kh.google.com to tile proxy
5. **Tile proxy** — lightweight server on Digi WR11 XT serving free tiles
6. **GEMMI already installed** — confirmed present on K0942_3 firmware

No binary patching. No IFS modification. No RANGE_ constraint removal.
Just a persistence DB change + DNS redirect + local tile proxy.

### Fully Local Architecture (No External Dependencies)

```
┌─────────────────────┐     ┌──────────────────────┐
│  MMI3G+ (QNX)       │     │  Digi WR11 XT        │
│                     │     │  (Linux LTE router)  │
│  gemmi_final        │     │                      │
│    ↓                │     │  nginx/node proxy    │
│  /etc/hosts         │USB  │    ↓                 │
│  kh.google.com ─────┼────→│  Fetch tiles from    │
│     → 192.168.0.1   │eth  │  Bing/Mapbox/OSM     │
│                     │     │    ↓                 │
│  MMI3GApplication   │     │  Return in GEE       │
│  displays tiles     │     │  /flatfile? format   │
│                     │     │                      │
└─────────────────────┘     └──────────────────────┘
                                    │ LTE
                                    ↓
                            Free tile servers
                            (no Google needed)
```

All components are local. No data goes to Congo's server or any
third party beyond the tile imagery provider.

### CRITICAL FINDING: Google's Tile Server Is Still Live (April 2026)

Live testing of Google's GEE endpoints:

```
http://kh.google.com/                  → 404 (root, expected)
http://kh.google.com/dbRoot.v5         → 200 (16,930 bytes!) ← ALIVE!
http://kh.google.com/dbRoot.v5?output=proto&hl=en → 200 (17,627 bytes)
http://kh.google.com/flatfile?...      → 400 (endpoint exists, wrong params)
http://kh.google.com/geauth            → 404 (auth endpoint REMOVED!)
```

Key implications:
1. **The tile server still serves data** — dbRoot.v5 returns valid config
2. **The auth endpoint (/geauth) returns 404** — authentication may no
   longer be enforced server-side
3. **The flatfile endpoint exists** (returns 400, not 404) — just needs
   correct query parameters

### What This Means

If `/geauth` is gone and `disableAuthKey` is set in drivers.ini:
- gemmi_final skips client-side auth check
- Server no longer enforces auth (404 on /geauth)
- Tiles may be served without any authentication at all
- **NO PROXY NEEDED** — just DNS + flag flip + internet connection

### Local DNS Redirect Options

QNX supports these DNS/hostname resolution methods:

```sh
# Method 1: /etc/hosts (simplest, checked FIRST before DNS)
echo "216.239.32.55 kh.google.com" >> /etc/hosts

# Method 2: /etc/resolv.conf (DNS server override)
echo "nameserver 192.168.0.1" > /etc/resolv.conf

# Method 3: setconf (QNX system config)
setconf _CS_RESOLVE "nameserver 192.168.0.1"
```

For Google Earth restoration, `/etc/hosts` is likely NOT needed
because kh.google.com already resolves correctly. The issue was
authentication, not hostname resolution. With `disableAuthKey`,
the existing DNS should work as-is.

### Simplest Possible Google Earth Restoration

If the server truly no longer enforces auth:

```sh
#!/bin/ksh
# Google Earth Restoration — SD card script

# 1. Flip EOL flags (Andrew's car: HU_VARIANT=6, no RANGE_ block)
# This enables the GE menu option in the Java UI
sqlite3 /HBpersistence/DataPST.db \
  "UPDATE tb_intvalues SET pst_value=1 \
   WHERE pst_key=<EOLFLAG_GOOGLE_EARTH_KEY>"

# 2. Set disableAuthKey in drivers.ini (writable EFS)
echo "    Connection/disableAuthKey = true" >> \
  /mnt/efs-system/lsd/drivers.ini

# 3. Ensure GEMMI binaries are deployed
# (Already present on K0942_3 firmware)

# 4. Done — reboot and connect to internet
```

**UNTESTED** — this is the theory based on binary analysis and live
server testing. The actual per3/DataPST.db key addresses for the
EOL flags need to be determined by live testing.

### no_online_services.properties — The RANGE_ Lock

This file is loaded for specific HU_VARIANT values:

```
EOLFLAG_HU_VARIANT 7  → Japan      → RANGE_EOLFLAG_GOOGLE_EARTH=0
EOLFLAG_HU_VARIANT 9  → Korea      → RANGE_EOLFLAG_GOOGLE_EARTH=0
EOLFLAG_HU_VARIANT 15 → VW         → RANGE_EOLFLAG_GOOGLE_EARTH=0
EOLFLAG_HU_VARIANT 16 → Bentley    → RANGE_EOLFLAG_GOOGLE_EARTH=0
EOLFLAG_HU_VARIANT 19 → Bentley RSE→ RANGE_EOLFLAG_GOOGLE_EARTH=0
```

The `RANGE_` prefix means: "constrain the allowed values to ONLY this
value." When `RANGE_EOLFLAG_GOOGLE_EARTH=0` is set, no other config
file can override Google Earth to 1. The Java UI code checks:

```java
if (sysconst.isInRange("EOLFLAG_GOOGLE_EARTH", 1)) {
    // Show Google Earth option in nav menu
}
```

With RANGE=0, `isInRange(1)` returns false → menu option hidden.

**Audi NAR (variant 6) does NOT load this file** — Google Earth
can be enabled by simply setting the EOLFLAG to 1.

**VW/Bentley/Japan/Korea variants DO load this file** — Google Earth
requires either IFS modification (to remove the RANGE_ constraint)
or running gemmi_final independently (bypasses UI check entirely).

### GEMMI Deployment Path (CRITICAL)

GEMMI binaries live at **`/mnt/nav/gemmi/`** — the NAV HDD partition,
NOT on EFS. This is the path `run_gemmi.sh` checks:

```sh
if [ -x /mnt/nav/gemmi/gemmi_final ]; then
    export LD_LIBRARY_PATH=/mnt/nav/gemmi
    # ... launches gemmi_final with 55MB max memory, 12fps cap
fi
```

Cache directory: `/mnt/img-cache/gemmi/` (separate HDD partition)

When Congo says "don't worry about GEMMI files" — the binaries are
deployed automatically as part of **nav map updates**. EU nav packages
include the full GEMMI suite. NAR packages do not.

This explains why the GEMMI binaries are NOT in the IFS or EFS on
NAR firmware — they're part of the nav database content on the HDD.

### The Self-Provisioning Theory (April 2026)

Congo's service works on US RNS-850 which has ZERO GEMMI files in
firmware. He says "as long as the MMI has internet, it works" and
"don't worry about the GEMMI files."

Combined with our findings:
- kh.google.com/dbRoot.v5 returns HTTP 200 (server ALIVE)
- kh.google.com/geauth returns HTTP 404 (auth REMOVED)
- GEMMI binaries live at /mnt/nav/gemmi/ (nav HDD, writable)
- Google Earth Enterprise protocol supports client provisioning
- disableAuthKey parameter exists in the client

**Theory A: Congo's proxy serves everything**
His proxy provides: dbRoot config → GEMMI binaries → tile data.
The MMI downloads the ~23MB GEMMI package from his proxy on first
connect, caches it to /mnt/nav/gemmi/, and subsequent tile requests
also go through his proxy. One server, complete solution.

**Theory B: Google still serves everything, no proxy needed**
Google removed /geauth (404). The dbRoot.v5 is still served (200).
If disableAuthKey bypasses the client-side check AND Google's server
no longer enforces auth, then the MMI might connect directly to
Google, download the GEMMI binaries via the GEE provisioning
protocol, and fetch tiles — with no proxy at all.

**Theory C: Hybrid**
Congo's proxy was necessary when Google's auth was active (2020-2023).
Google may have since removed the auth check. Congo's proxy still
works but may no longer be required. The simplest test:

```
1. Set disableAuthKey = true in drivers.ini
2. Flip EOLFLAG_GOOGLE_EARTH=1
3. Connect internet (no proxy, no DNS redirect)
4. Reboot
5. Does GEMMI self-provision and start?
```

**Why this matters:** If Theory B or C is correct, Google Earth
restoration is a 2-line config change + internet connection. No
€90 service, no proxy server, no binary deployment. The community
could restore Google Earth on every HN+ platform car for free.

**Status: UNTESTED** — needs a car with internet connectivity.
Andrew's A6 is the ideal first test once the AX88772A adapter arrives.

### Complete Google Earth Server Infrastructure (April 22, 2026)

Full status of every known Google Earth / Keyhole server endpoint:

```
✅ ALIVE — Serving Data:
   kh.google.com/dbRoot.v5          → 200 (16,930 bytes, protobuf config)
   kh.google.com/dbRoot.v5?proto    → 200 (17,627 bytes, proto format)
   maps.googleapis.com/streetview   → 400 (alive, needs API key + params)
   www.keyhole.com                  → 301 → earth.google.com/web/

❌ AUTH REMOVED — All Return 404:
   kh.google.com/geauth             → 404 (primary auth, GONE)
   auth.keyhole.com                 → 404 (legacy Keyhole auth, GONE)
   geoauth.google.com               → 404 (Google geo auth, GONE)

❌ OFFLINE:
   geo.keyhole.com                  → 000 (connection refused)
   bbs.keyhole.com                  → 404 (community BBS, dead)
   cbk0.google.com/cbk              → 404 (StreetView, needs session)
   kh.google.com/flatfile           → 404 (tiles, needs dbRoot handshake)
```

### Original Google Earth Connection Flow

From community documentation and forum posts, the original GE
boot sequence required three servers on port 80:

```
1. www.keyhole.com/updatecheck/   → version number (plain text)
2. kh.google.com/geauth           → authenticate (POST request)
3. kh.google.com/dbRoot.v5        → download tile config (protobuf)
4. kh.google.com/flatfile?...     → fetch map tiles
5. cbk0.google.com/cbk?...        → fetch StreetView tiles
```

Step 2 is GONE across ALL three auth domains. Step 3 still works.
The `disableAuthKey` parameter in drivers.ini tells the GEMMI client
to skip step 2 entirely and proceed directly to step 3.

### libembeddedearth.so Server Configuration

All server endpoints are configurable via the binary:

| Parameter | Default | Purpose |
|-----------|---------|---------|
| DefaultServer | http://kh.google.com/ | Tile/data server |
| authServer | /geauth | Authentication (404) |
| deauthServer | (endpoint) | Logout |
| loginServer | (endpoint) | Login |
| geFreeLoginServer | kh.google.com | FREE login mode |
| bbsServer | bbs.keyhole.com | Community (dead) |
| googleMFEServer | (endpoint) | Maps Frontend |
| depthMapFetchServer | (endpoint) | StreetView depth |
| reverseGeocodingServer | (endpoint) | Address lookup |
| csiLogServer | (endpoint) | Client logging |
| metaDataFetchServer | (endpoint) | Metadata |

### Auth Flow Classes (from binary symbols)

```
GEFreeLoginServer        — Free login (no auth)
GEAuthBuffer             — Auth token buffer
GEAuthSignature          — Signature validation
LoginHandler             — Login state machine
LogoutHandler            — Clean logout
AsyncHandleAuthFailure   — Graceful auth failure
```

The auth flow sequence: `b_auth → b_login → b_render_init →
b_layer_init → b_first_earth`

With `disableAuthKey = true`, the auth step is skipped and the
client proceeds directly to render initialization.

### dbRoot.v5 — The Key File

The `dbRoot.v5` served by `kh.google.com` is a 16,930-byte binary
blob (protobuf format) that configures the entire tile-fetching
pipeline. It tells the client:
- Where to find satellite imagery tiles
- Where to find terrain data
- Layer configuration (roads, borders, labels)
- Tile server URLs and formats
- Cache configuration
- Available zoom levels

This file is the "phone book" for Google Earth. As long as Google
serves it, the client knows how to fetch everything else.

### srv-starter GEMMI Configuration Comparison (CRITICAL FINDING)

The `mmi3g-srv-starter.cfg` reveals exactly how GEMMI was removed
from the US firmware and how Congo restores it:

```
                          EU VW (K0821)    Audi NAR (K0942)    US RNS-850 (K0711)
                          ─────────────    ────────────────    ──────────────────
ProcessCount:             100              101                 98
Process 97:               run_gemmi.sh     run_gemmi.sh        pintest (REPLACED!)
Package 28 (GEMMI):       
  RequestState:           STOP             STOP                STOP
  HostsProcess:           97 (connected)   97 (connected)      EMPTY (gutted!)
```

**US RNS-850 was surgically modified:**
1. Process 97 replaced: `run_gemmi.sh` → `pintest` (test utility)
2. Package 28 disconnected: `HostsProcess` emptied
3. `no_online_services.properties` locks RANGE_ flags
4. GEMMI binaries not included in NAR nav updates

**How GEMMI launches on a working system:**
1. Boot → srv-starter loads → GEMMI package state = STOP
2. LSD Java app checks EOLFLAG_GOOGLE_EARTH
3. If flag = 1 AND user enables in menu → LSD sends START to srv-starter
4. srv-starter launches Process 97 (`/usr/bin/run_gemmi.sh`)
5. `run_gemmi.sh` checks `/mnt/nav/gemmi/gemmi_final` exists
6. Launches gemmi_final with rendering params
7. Google Earth overlay appears on nav map

**Congo's approach (confirmed via audi-mib.bg):**
Flash the EU K0821 firmware onto US RNS-850. The EU firmware has:
- Process 97 = run_gemmi.sh (GEMMI launcher present)
- Package 28 connected to Process 97
- GEMMI binaries deploy with EU nav maps
- Full Google Earth infrastructure

His page literally states: "K0821 adds the Google Earth map option"

### Custom SWDL Update Path (Alternative to Full EU Flash)

Instead of replacing the entire firmware with EU, a minimal
patch could add Google Earth to any US RNS-850:

**What needs to change in the IFS:**

1. `mmi3g-srv-starter.cfg`:
   - Replace Process 97 from `pintest` to `run_gemmi.sh`
   - Set Package 28 HostsProcess to 97

2. `lsd.jxe` (inside the JAR):
   - Remove `RANGE_EOLFLAG_GOOGLE_EARTH=0` from
     `no_online_services.properties`
   - Set `EOLFLAG_GOOGLE_EARTH=1` in `sysconst.properties`

3. Deploy GEMMI binaries to `/mnt/nav/gemmi/`
   (via SWDL Dir component, same as EU firmware does)

**Build pipeline:**
```
inflate_ifs.py  → decompress US RNS-850 IFS
patch_ifs.py    → replace srv-starter.cfg + lsd.jxe
repack_ifs.py   → recompress IFS
mu_crc_patcher  → fix checksums
Package as SWDL → user flashes via Engineering Menu
```

**Advantages over full EU flash:**
- Preserves NAR-specific features (SiriusXM, TPMS, etc.)
- Smaller update package (~50MB IFS vs full firmware)
- Less risk (fewer components modified)
- Users stay on their current firmware version
- Only the IFS needs to change

**User workflow:**
1. Identify current firmware version (ge_probe.sh reports this)
2. Download matching pre-patched IFS from GitHub Release
3. Copy to SD card in SWDL format
4. Flash via Engineering Menu (SETUP + PHONE)
5. Install GEMMI binaries (ge_activate.sh or EU nav maps)
6. Connect internet → Google Earth works

**Version matching requirement:**
Each firmware version has a different IFS. Users must match
their current version or update to a specific target version.
The probe script reports the firmware train name for matching.
