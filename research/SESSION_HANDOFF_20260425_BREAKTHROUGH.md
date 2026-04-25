# SESSION HANDOFF — April 25, 2026 — FIRST TILE SERVED!

## BREAKTHROUGH
```
[TILE]  qt=0 z=1 x=0 y=0 10772b JPEG -> 10633b GEE
```
First satellite tile successfully fetched from Google, encrypted with GEE XOR,
and served to GEMMI on the Audi MMI3G+. GEMMI crashes after receiving it —
the GEE packet wrapper format needs adjustment.

## Complete Working Flow (Confirmed)
```
[ROOT]  dbRoot (16959b)                          ← from xgx.ddns.net
[AUTH]  /geauth (39b) -> 16b UPSTREAM            ← first auth (16b)
[AUTH]  /geauth (49b) -> 136b UPSTREAM           ← second auth (136b, REQUIRED)
[QT]    q2-0-q.1033 -> 145b UPSTREAM             ← quadtree root
[QT]    q2-0310-q.1033 -> 1149b UPSTREAM         ← deeper quadtree (real data!)
[TILE]  qt=0 z=1 x=0 y=0 10772b JPEG -> 10633b  ← TILE SERVED!
[QT]    q2-03103320+q2-0313+...+f1c-0310332-t.939 -> 28827b  ← multi-query
```

## Key Discoveries

### 1. xgx.ddns.net IS a Real Server (Not a Stub!)
Previously thought xgx was a stub. WRONG! It serves:
- dbRoot: 16959 bytes (encrypted DbRootProto)
- Auth: 16b first call, 136b second call (both needed)
- Quadtree root (q2-0): 145 bytes
- Deeper quadtree (q2-0310): 1149 bytes (REAL tile index!)
- Multi-query responses: up to 28827 bytes
- It does NOT serve imagery tiles (f1-*) — returns 404

### 2. Auth Requires Two Calls
- First POST /geauth (39 bytes payload) → 16 bytes response
- Second POST /geauth (49 bytes payload) → 136 bytes response
- The 136-byte response is REQUIRED — 16-byte-only auth loops forever
- Must forward auth to xgx.ddns.net upstream

### 3. Multi-Query URLs
GEMMI bundles multiple requests in one URL using '+' separator:
```
/flatfile?q2-03103320-q.1033+q2-0313-q.1033+q2-03103321-q.1033+q2-0301-q.1033+f1c-0310332-t.939&v=1
```
This contains 4 quadtree requests AND 1 tile request.
Currently proxied entirely to xgx, but tile portions need our translation.

### 4. Tile Request Formats
- `f1-XXXX-i.YYY` = imagery tile (channel 1, version YYY)
- `f1c-XXXX-t.YYY` = terrain tile? (channel 1c, type t)
- The 'c' might mean "compressed" or "cobrand"
- Quadtree path "0310332" = specific map location

### 5. GEE Packet Format Issue
Our current packet wrapper:
```python
def make_gee_packet(raw_data):
    compressed = zlib.compress(raw_data, 6)
    return gee_encode(magic[0x7468dead] + size[4] + compressed)
```
GEMMI crashes after receiving this. Possible issues:
- Imagery tiles might not use zlib compression
- Different magic number for imagery vs quadtree
- Missing metadata (image dimensions, format, etc.)
- The tile might need to be raw JPEG, just XOR encrypted (no zlib)

## Files

### On Car (/mnt/nav/gemmi/)
- `libembeddedearth.so` — FINAL (2 code patches + 192.168.0.91)
- `gemmi_final` — patched v3 (auth NOP, harmless)
- `run_gemmi.sh` — 999 retries + auto /etc/hosts
- Originals backed up as .orig

### On PC (D:\MMI\)
- `proxy/gemmi_tile_proxy.py` — v10c (WORKING proxy)
- `proxy/tile_cache/` — cached upstream responses + tile
- `libembeddedearth.so.FINAL` — for re-deployment

## Next Session: Fix the Tile Format

### Priority 1: Fix make_gee_packet for imagery
Try these variations:
1. Raw JPEG encrypted with GEE XOR (no zlib, no magic header)
2. GEE packet with uncompressed JPEG (zlib level 0)
3. Different magic number for imagery packets
4. Check GEE source for imagery packet format vs quadtree packet format

### Priority 2: Handle multi-query tile requests
Parse '+' separated queries, intercept f1/f1c tile portions,
translate to Google tiles, let quadtree portions go to xgx.

### Priority 3: Street View
- gemmi_final needs cbk0.google.com patches (3 URLs)
- Street View uses different tile format
- Lower priority than satellite imagery

## GEE Source References
- `etencoder.cc` — encryption ✅ (implemented, verified)
- `quadtreepacket.h` — quadtree format ✅ (studied, understood)
- Need: imagery packet format (how tiles are wrapped)
- Need: `tileservice.cpp` or `fdbservice.cpp` tile serving code

## mhhauto Community Update
ruthr posted 5 hours before session end:
> "libearthmobile.so has been patched. Stage 1 and Stage 2 are passing.
> The client is requesting flatfiles, imaginary, etc. The server/proxy
> has been relocated to the EU to eliminate the high ping."
Confirms our approach is 100% correct. They have a working solution
about to be released publicly.

## Stats
- 232 commits on MMI3G-Toolkit
- Session duration: ~8 hours
- Proxy versions: v1 through v10c
- Binary patch versions: v1 through FINAL
