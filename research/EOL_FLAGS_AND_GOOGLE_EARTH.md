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
