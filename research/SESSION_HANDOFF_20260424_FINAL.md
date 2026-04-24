# SESSION HANDOFF — April 24, 2026 (FINAL — mhhauto discovery)

## BREAKTHROUGH: mhhauto GEMMI Restoration Found

Andrew found a community release on mhhauto.com with pre-patched binaries.
Source: `mhhauto.com/Thread-RELEASE-Google-Earth-GEMMI-restoration-for-MMI-3G-—-firmware-K0942-3`
Zip file saved at: `/mnt/user-data/uploads/GEMMI.zip` (also analyzed in session)

### mhhauto Patch Analysis (COMPLETE)

**libembeddedearth.so (K0942 version, offsets MATCH our NAR Audi):**

CODE PATCHES:
- `0x343d20`: `862f1fc7962f` → `01e00b000900` (mov #1,r0; rts; nop — force function return 1)
- `0x3470a0`: `862f2dc7` → `0b000900` (rts; nop — skip function entirely)

STRING PATCHES (all hostnames → xgx.ddns.net):
- `kh.google.com` at 5 locations
- `maps.google.com` at 6 locations  
- `geoauth.google.com` at 1 location
- `geo.keyhole.com`, `bbs.keyhole.com`, `dev.keyhole.com` at 1 each
- `www.google.com` at 1 location
- `mw1.google.com` at 1 location (weather)
- `cbk0.google.com` at 4 locations (Street View)
- Total: 22 hostname references, mhhauto patches ~18 of them

**gemmi_final (K0942 version):**
- ONLY string patches (Street View cbk0.google.com → xgx.ddns.net, 3 instances)
- NO code patches — auth bypass is entirely in libembeddedearth.so

### xgx.ddns.net Server (ALIVE as of April 24, 2026)
- IP: 195.29.217.188
- Server: nginx/1.27.2
- Requires GEMMI User-Agent for 200 response (else 403)
- `/dbRoot.v5` → returns 16959 bytes (custom, slightly different from Google's 16930)
- `/geauth` → returns 16 null bytes (0x00 * 16)
- `/flatfile?q2-0` → returns 145 bytes (metadata?)
- Other endpoints return 2 bytes

### Test Results

**With xgx.ddns.net .so (XGX version on car):**
- GE screen LOADED on car display ✅
- Blank tiles (no satellite imagery) ❌
- Ping: 130ms latency, 50% packet loss to xgx.ddns.net
- Likely the packet loss prevents tile loading

**With our proxy (FINAL version, 192.168.0.91):**
- Auth loop continues (39b first POST, 49b subsequent)
- "Not enough data" warning → switches to standard nav
- Code patches verified correct in binary
- dbRoot served (xgx's 16959 byte version)
- Auth response: 16 null bytes (matches xgx format)
- But NO tile requests ever appear

## Root Cause Theory (Updated)

The two code patches (0x343d20 and 0x3470a0) are NOT the auth bypass.
They likely bypass:
1. SSL certificate validation (to allow HTTP instead of HTTPS)
2. OR dbRoot signature verification
3. OR some other security check

Auth still loops regardless. The mhhauto server handles auth properly
(returns 16 null bytes which GEMMI eventually accepts). The auth loop
may be NORMAL behavior — it runs on a background thread while tiles
load on the main thread.

The REAL issue: tiles come from URLs inside the parsed dbRoot protobuf.
The xgx dbRoot (16959 bytes) likely contains tile URLs pointing to
xgx.ddns.net. When GEMMI resolves those, it needs DNS or /etc/hosts
to reach the right server.

## Files on Car (Current State)
- `/mnt/nav/gemmi/libembeddedearth.so` — FINAL version (code patches + 192.168.0.91)
- `/mnt/nav/gemmi/libembeddedearth.so.xgx` — XGX version (code patches + xgx.ddns.net)  
- `/mnt/nav/gemmi/libembeddedearth.so.orig` — original from car
- `/mnt/nav/gemmi/gemmi_final` — patched v3 (our auth NOP patches)
- `/mnt/nav/gemmi/gemmi_final.orig` — original from car
- `/mnt/nav/gemmi/run_gemmi.sh` — minimal with hosts auto-add + 999 retries

## Files on PC (D:\MMI\)
- libembeddedearth.so — original
- libembeddedearth.so.FINAL — code patches + 192.168.0.91
- libembeddedearth.so.XGX — code patches + xgx.ddns.net
- gemmi_final.patched_v3 — our auth NOP patches
- proxy/gemmi_tile_proxy.py — v6 with xgx dbRoot + 16-null-byte auth
- proxy/dbRoot_xgx.bin — 16959 bytes from xgx.ddns.net

## Next Steps

### 1. Analyze xgx dbRoot protobuf
- Decrypt/parse dbRoot_xgx.bin to find tile server URLs
- Compare with Google's dbRoot (dbRoot.v5.cached, 16930 bytes)
- The tile URLs inside determine where GEMMI fetches tiles from

### 2. Test XGX version with good network
- The XGX .so with xgx.ddns.net loaded GE but had 50% packet loss
- If we can improve the network path (or add xgx.ddns.net to /etc/hosts)
- Tiles might just need a stable connection

### 3. Build proper tile proxy
- Mirror what xgx.ddns.net does:
  - Serve custom dbRoot with tile URLs pointing to our proxy
  - Handle /geauth with 16 null bytes
  - Proxy tiles from Google's servers
  - Handle flatfile requests properly

### 4. Understand the two code patches
- What do functions at 0x343d20 and 0x3470a0 actually do?
- Ghidra analysis of libembeddedearth.so (still processing)
- These might be SSL/cert checks, not auth checks

## Repo: 229 commits, 34/34 tests green
