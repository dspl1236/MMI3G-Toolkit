# StreetView Restoration Research — April 2026

## Status: RESEARCH (not yet implemented)

## Background

Google officially killed StreetView for Audi connect vehicles on **December 4, 2017**.
NHTSA TSB 91-17-66 (MC-10133260-9999) confirmed: "Google Streetview was turned off...
no service software or hardware upgrade would re-enable this feature."

DrGER's Croatian contributor demonstrated working StreetView on an MU9411 test bench
(Saturday April 26, 2026), proving restoration is possible.

## Discovery: cb_client Is The Key

Google didn't remove the StreetView tile infrastructure — they blocked the **client identifier**.

```
BLOCKED:   cb_client=earth         → 403 Forbidden
BLOCKED:   cb_client=auto.audi     → 403 Forbidden  
WORKS:     cb_client=maps_sv.tactile → 200 OK + JPEG tiles!
WORKS:     cb_client=apiv3          → 200 OK + JPEG tiles!
```

**Tiles are FREE. No API key needed. Just change the cb_client string.**

## Binary Endpoints (libembeddedearth.so)

StreetView URLs are hardcoded at these offsets (same in K0942_3 and K0942_6):

```
0x01069770: http://cbk0.google.com/cbk
0x010697a0: http://cbk0.google.com/cbk?output=tile&panoid=%1&zoom=$[level]&x=$[x]&y=$[y]&cb_client=earth
0x01069800: http://cbk0.google.com
```

These are NOT in our current 9-hostname patch list. cbk0.google.com requests
currently go directly to Google (and get rejected with cb_client=earth).

## The Two Problems

### Problem 1: HTTPS Required

Google serves StreetView tiles over HTTPS only. HTTP returns 403.

```
HTTP  cbk0.google.com/cbk?output=tile&panoid=X&cb_client=maps_sv.tactile → 403
HTTPS cbk0.google.com/cbk?output=tile&panoid=X&cb_client=maps_sv.tactile → 200 ✅
```

QNX has NO SSL libraries:
- No libssl.so, no libcrypto.so, no libcurl.so
- GEMMI's curl is statically compiled into gemmi_final (not accessible)
- Map tiles work because kh.google.com serves over plain HTTP

### Problem 2: Metadata Endpoint Dead

The panoid lookup endpoint (how GEMMI finds StreetView at a location) is completely dead:

```
cbk0.google.com/cbk?output=xml&ll=lat,lng  → 404 (regardless of cb_client)
cbk0.google.com/cbk?output=json&ll=lat,lng → 404
geo0.ggpht.com/cbk?output=xml&ll=lat,lng   → 404
```

Without metadata, GEMMI can't discover that StreetView is available at a location.
Coverage tiles (mts0.google.com/vt?lyrs=svv) still work and show WHERE StreetView
exists, but don't provide panoid values.

## Solution: BearSSL in gemmi_proxy

### What is BearSSL?

BearSSL is a lightweight, pure-C TLS implementation:
- ~50KB compiled code size
- Zero external dependencies (no libssl, no libcrypto)
- Simple API for TLS client connections
- Can be statically linked into any binary
- Cross-compiles to any architecture with a C compiler
- Source: https://bearssl.org / https://www.bearssl.org/gitweb/?p=BearSSL

### Architecture: gemmi_proxy v6

```
gemmi_proxy v6 (~120KB, QNX SH4):
  dlopen("libsocket.so.2")  → sockets + DNS (already working)
  BearSSL (statically linked) → TLS for StreetView HTTPS

  Request routing:
    /dbRoot*    → local file (16KB)          [existing]
    /geauth*    → local auth (16b + 136b)    [existing]
    /flatfile*  → HTTP to kh.google.com      [existing, map tiles]
    /cbk*       → HTTPS to cbk0.google.com   [NEW, StreetView tiles]
                  + rewrite cb_client=earth → maps_sv.tactile
```

### Build Process

1. Download BearSSL source
2. Cross-compile for SH4: `sh4-linux-gnu-gcc -c -ml -m4 -O2 src/*.c`
3. Archive: `sh4-linux-gnu-ar rcs libbearssl.a *.o`
4. Link into gemmi_proxy: existing socket dlopen + static BearSSL
5. Proxy uses BearSSL to wrap socket connections in TLS for cbk0 requests

### cb_client Rewrite

GEMMI sends:
```
GET /cbk?output=tile&panoid=X&zoom=3&x=5&y=2&cb_client=earth HTTP/1.0
Host: cbk0.google.com
```

Proxy rewrites to:
```
GET /cbk?output=tile&panoid=X&zoom=3&x=5&y=2&cb_client=maps_sv.tactile HTTP/1.1
Host: cbk0.google.com
```

### Binary Patches Needed

Add cbk0.google.com to hostname patch list in libembeddedearth_oncar.so:
```
0x01069770: "http://cbk0.google.com/cbk" → "http://127.0.0.1xxxxxx/cbk"
0x01069800: "http://cbk0.google.com"     → "http://127.0.0.1xxxxx"
```

Note: URL at 0x010697a0 contains the full tile request template with cb_client=earth.
The proxy handles the cb_client rewrite, so we only need to redirect the hostname.
But the string lengths differ — need to verify null-padding works here.

## Metadata — SOLVED! (SingleImageSearch, FREE, no API key!)

**BREAKTHROUGH**: The `streetlevel` Python library revealed Google's internal
metadata endpoint still works without an API key:

```
Endpoint: maps.googleapis.com/maps/api/js/GeoPhotoService.SingleImageSearch
Client:   apiv3 (free, no API key required!)
Method:   GET with protobuf-encoded URL parameters

Template URL (just insert lat/lng):
  ?pb=!1m5!1sapiv3!5sUS!11m2!1m1!1b0!2m4!1m2!3d{LAT}!4d{LNG}!2d50.0
  !3m10!2m2!1sen!2sen!9m1!1e2!11m4!1m3!1e2!2b1!3e2
  !4m9!1e1!1e2!1e3!1e4!1e6!1e8!1e12!5m0!6m0
```

Response: JSON array (~12KB), extract with simple string matching:
- panoid: first 22-char string after `[2,"`
- lat/lng: floats after `null,null,`
- yaw: float after `],[` following coords

Proxy builds old XML format GEMMI expects (183 bytes):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<panorama>
<data_properties pano_id="ayBC-ygonQ1soy18NI7sLw" lat="41.081251"
                 lng="-81.518998" pano_yaw_deg="294.5"/>
</panorama>
```

### Complete Pipeline — ALL FREE, ALL ON-CAR:
```
GEMMI → /cbk?output=xml&ll=lat,lng → proxy
  → HTTPS SingleImageSearch (BearSSL) → extract panoid
  → build XML response → return to GEMMI

GEMMI → /cbk?output=tile&panoid=X → proxy  
  → HTTPS cbk0.google.com (BearSSL, cb_client=maps_sv.tactile)
  → return JPEG tile → StreetView!
```

## StreetView Assets (Ready to Deploy)

From K0942_6 firmware (in payload/models/):
```
streetviewguy.png        816 bytes  — peg man icon
audisvcursor.png       4,107 bytes  — StreetView cursor
audisvinfocursor.png   5,168 bytes  — StreetView info cursor
audisvjumpcursor.png   3,105 bytes  — StreetView jump cursor
Total: 13 KB
```

These are already on the car's HDD at /mnt/nav/gemmi/models/ if GEMMI was
installed from firmware. But including them in the payload ensures they exist.

## GEMMI StreetView Parameters

From run_gemmi.sh (stock firmware):
```
-streetviewtexeldensity 2.0    ← StreetView is a first-class GEMMI feature
```

RSE (rear seat) variant:
```
-maxcpu 1.0 -targetcpu 1.0 -streetviewtexeldensity 2.0 -rse
```

## Reference: mhhauto Approach (ARM/MIB2, NOT our platform)

mhhauto's GE restoration for MIB2 (ARM) uses a separate `streetview` binary
(1.1MB ARM ELF) that routes all StreetView through xgx.ddns.net:

```
http://xgx.ddns.net/cbk?output=tile&panoid=%s&zoom=%u&x=%u&y=%u&cb_client=auto.audi
http://xgx.ddns.net/cbk?output=xml&ll=%.6f,%.6f&cb_client=auto.audi
http://xgx.ddns.net/maps/api/streetview?fov=60&size=%dx%d&location=%lf,%lf&heading=%d
```

xgx.ddns.net proxies to Google with an API key. This approach works but
creates a dependency on someone else's server.

## Reference: QNX Security

Black Hat Asia 2018: "Dissecting QNX" (Wetzels & Abassi)
https://i.blackhat.com/briefings/asia/2018/asia-18-Wetzels_Abassi_dissecting_qnx__WP.pdf
May contain insights useful for binary analysis and IFS work.

## Next Steps

1. [ ] Download and cross-compile BearSSL for SH4
2. [ ] Build gemmi_proxy v6 with static BearSSL
3. [ ] Test HTTPS tile fetch from QNX
4. [ ] Add cbk0.google.com patches to libembeddedearth_oncar.so
5. [ ] Solve metadata (panoid lookup) — likely needs hausofdub relay for this part only
6. [ ] Test StreetView end-to-end on the car
7. [ ] Add StreetView module to web app (separate from GE or combined?)

## BREAKTHROUGH: dbRoot coverageOverlayUrl (April 29, 2026)

### Root Cause Found

The `coverageOverlayUrl` field in the dbRoot protobuf defaults to EMPTY STRING.
Without this field set, GEMMI never shows StreetView coverage overlays (blue lines
on roads) and never triggers the pegman icon or metadata lookups.

### Protobuf Schema (from Google Earth Enterprise open source)

Source: github.com/google/earthenterprise/blob/master/earth_enterprise/src/keyhole/proto/dbroot/dbroot_v2.proto

```protobuf
message DbRootProto {
  // ... many other fields ...
  optional AutopiaOptionsProto autopia_options = 44;
}

message AutopiaOptionsProto {
  // Url of panorama metadata server
  optional string metadata_server_url = 1
    [default = "http://cbk0.google.com/cbk"];

  // Url of depthmap server
  optional string depthmap_server_url = 2
    [default = "http://cbk0.google.com/cbk"];

  // Url of the coverage overlay KML.
  // NOT SPECIFYING THIS VALUE WILL RESULT IN NO COVERAGE
  // OVERLAYS BEING SHOWN while dragging the pegman in autopia.
  optional string coverage_overlay_url = 3 [default = ""];

  // QPS throttle for imagery requests
  optional float max_imagery_qps = 4;

  // QPS throttle for metadata/depthmap requests  
  optional float max_metadata_depthmap_qps = 5;
}
```

### Current State

Our custom dbRoot raw protobuf is only 5 bytes:
```
field 17.3 = 1  (a single disable flag)
```

We need to add field 44 (AutopiaOptionsProto) with:
```
field 44.3 = "http://127.0.0.1/sv_coverage.kml"  (coverage overlay URL)
```

The metadata and depthmap URLs default to http://cbk0.google.com/cbk,
which our .so patches redirect to 127.0.0.1 (our proxy). So those
are already handled.

### What Needs to Happen

1. **Rebuild dbRoot protobuf** — add field 44 with coverage_overlay_url
2. **Re-encrypt** using same XGX/wrapper format as current dbRoot_custom.bin
3. **Add coverage handler to proxy** — serve sv_coverage.kml (a KML file
   that tells GEMMI where StreetView is available)
4. **Test** — GEMMI should show blue SV lines → metadata lookup → tiles

### The StreetView Activation Chain

```
1. dbRoot.autopia_options.coverage_overlay_url → proxy serves KML
2. GEMMI loads coverage KML → shows blue lines on roads where SV exists
3. User zooms to street level → GEMMI queries cbk0 for metadata at lat/lng
4. Proxy forwards metadata → gets panoid + heading
5. GEMMI shows pegman icon
6. User clicks pegman → tile requests via /cbk?output=tile
7. Proxy rewrites cb_client + HTTPS via BearSSL → JPEG tiles returned
8. StreetView renders!
```

### Next Steps

- [ ] Reverse-engineer dbRoot encryption format (XGX wrapper)
- [ ] Rebuild dbRoot with coverage_overlay_url
- [ ] Create sv_coverage.kml handler in proxy
- [ ] Solve metadata endpoint (still dead on Google's side)
- [ ] Test end-to-end
