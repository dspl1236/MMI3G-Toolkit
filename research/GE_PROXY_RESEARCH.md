# Google Earth Proxy Research — April 24, 2026

## Architecture Overview

GEMMI (Google Earth Module for MMI) is a Google Earth Enterprise (GEE) client, NOT a
standard Google Earth client. It uses the GEE "flatfile" protocol, not Google Maps tiles.

### GEE Protocol Flow
```
1. Client → GET /dbRoot.v5     → Server returns encrypted DbRootProto
2. Client → POST /geauth       → Server returns auth token (16 bytes)
3. Client → GET /flatfile?q2-0 → Quadtree root packet (tile index)
4. Client → GET /flatfile?q2-0-q.N → Deeper quadtree levels
5. Client → GET /flatfile?f1-XXXX-i.Y → Imagery tile (encrypted)
6. Client → GET /flatfile?f2-XXXX-i.Y → Terrain tile (encrypted)
```

### Key Differences from Google Maps
- Tiles are NOT standard JPEG/PNG — they're GEE encrypted binary packets
- Tile indexing uses quadtree paths (q2-0, q2-0-q.1, etc.), not x/y/z
- All data is XOR-encrypted with a modified algorithm (not simple XOR)
- The encryption key (1016 bytes) is embedded in the dbRoot file
- dbRoot contains server URLs, layer info, and copyright data as protobuf

## GEE Encryption Algorithm (from open-source GEE: etencoder.cc)
- Modified XOR: rotates through key with offsets 16,0,8,16,0,8...
- Processes 8 bytes at a time, key stride of 24
- Uses default key (1016 bytes, constant since Keyhole days)
- Same algorithm for encode and decode (XOR is symmetric)

## xgx.ddns.net Analysis (mhhauto free release server)

**Server:** nginx/1.27.2 at 195.29.217.188
**Status:** ALIVE as of April 24, 2026
**Requires:** GEMMI User-Agent header (returns 403 without it)

### Endpoints
| Endpoint | Response | Notes |
|----------|----------|-------|
| GET /dbRoot.v5 | 16959 bytes | Custom encrypted dbRoot |
| POST /geauth | 16 bytes | Echo cmd byte + 15 nulls |
| GET /flatfile?q2-0 | 145 bytes | Minimal quadtree root |
| GET /flatfile?q2-0-q.N | 404 | No deeper quadtree |
| GET /flatfile?f1-*-i.* | 404 | **No imagery tiles!** |
| GET /flatfile?f2-*-i.* | 404 | **No terrain tiles!** |

### Conclusion
xgx.ddns.net is a **STUB SERVER** — it only provides enough to initialize
GEMMI but does NOT serve actual satellite imagery. This explains the blank
tiles on the car when using the XGX .so.

## Commercial Solutions

### audi-mib.bg (congo/gotze)
- Price: €90 (MMI3G+), €180 (MIB1/2)
- Per-vehicle licensing (VIN-locked?)
- Full tile serving — satellite imagery works
- Has been running since January 2021
- Patches both gemmi_final AND libembeddedearth.so
- Custom server with actual tile data
- 6-month warranty for MIB, none for MMI3G+

### How They Likely Work
Option A: Full GEE Server
  - Run Open GEE (google/earthenterprise) on a server
  - Import public satellite imagery (Landsat, Sentinel, commercial)
  - Serve tiles in native GEE format
  - Most reliable but requires significant storage/compute

Option B: Google Tile Translation Proxy  
  - Fetch tiles from Google's public servers
  - Re-encrypt with GEE key for GEMMI consumption
  - Requires understanding the GEE packet format
  - Lighter weight but Google could change their tile API

Option C: Cached Tile Database
  - Pre-fetch and cache tiles for common zoom levels
  - Store in GEE flatfile format
  - Serve from nginx/static files
  - Limited coverage but fast and reliable

## Open Source GEE Server (google/earthenterprise)

### Architecture
- **GEE Fusion** — processes raw imagery into GEE database format
- **GEE Server** — Apache-based server with mod_fdb (flatfile database)
- **GEE Portable** — offline globe viewer

### Setting Up a Tile Server
1. Install Open GEE on Linux (Ubuntu recommended)
2. Import satellite imagery via GEE Fusion
3. Build globe database
4. Publish to GEE Server
5. Point GEMMI at the server

### Data Sources (free satellite imagery)
- Landsat (USGS) — 30m resolution, global
- Sentinel-2 (ESA) — 10m resolution, global
- NAIP (USDA) — 1m resolution, US only
- Google Earth Engine — petabytes of data

## Next Steps for Our Proxy

### Phase 1: Validate with Working Commercial Server
- If affordable, get audi-mib.bg activation (€90)
- Capture actual tile requests/responses
- Understand the complete protocol including tile format
- Use as reference implementation

### Phase 2: Build Translation Proxy
- Serve proper dbRoot with tile URLs → our proxy
- Handle auth (16-byte response, done)
- Build quadtree packets that index available imagery
- Fetch tiles from Google/Bing/MapBox and convert to GEE format
- Key challenge: GEE tile encryption + quadtree packet format

### Phase 3: Open GEE Server
- Install Open GEE on a Linux server/VPS
- Import free satellite imagery
- Generate proper GEE globe database
- Serve to GEMMI directly
- Most complete solution but most complex setup

## Binary Patches Summary (verified working)

### libembeddedearth.so (2 code patches)
- `0x343d20`: Force auth function → return 1 (mov #1,r0; rts; nop)
- `0x3470a0`: Skip auth handler → rts; nop
- ~22 hostname string redirects to proxy IP

### gemmi_final (optional, for Street View)
- 3 Street View URL redirects (cbk0.google.com → proxy)
- No code patches needed

## Files
- `/home/claude/gemmi_release/GEMMI/` — mhhauto release files
- `D:\MMI\proxy\dbRoot_xgx.bin` — xgx.ddns.net dbRoot (16959b)
- GEE encryption source: `etencoder.cc` in google/earthenterprise repo
