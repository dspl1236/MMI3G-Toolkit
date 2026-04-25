# libembeddedearth.so Binary Patch Analysis

## Overview
11 total patches required to restore Google Earth on MMI3G+:
- 2 code patches (image validation bypass)
- 9 hostname patches (redirect server URLs to proxy IP)

## Code Patches

### PATCH 1 — Image Validation Bypass (0x343d20)
```
Original: 86 2f 1f c7 96 2f
Patched:  01 e0 0b 00 09 00  (mov #1,r0; rts; nop)
```
Forces image validation to return TRUE. Called from the JPEG/EXIF
image loader and the GL rendering engine.

### PATCH 2 — Post-Validation DRM Skip (0x3470a0)
```
Original: 86 2f 2d c7
Patched:  0b 00 09 00  (rts; nop)
```
Skips post-validation DRM/metadata processing.

## Hostname Patches (9 total)

All Google/Keyhole hostnames redirected to proxy IP (192.168.0.91).
Each hostname is replaced with the IP + null padding to preserve
string length.

| # | Offset | Original | Length | Purpose |
|---|--------|----------|--------|---------|
| 1 | 0x01043dd3 | `kh.google.com` | 13 | Tile server URL |
| 2 | 0x01044370 | `maps.google.com` | 15 | Maps API |
| 3 | 0x0104a434 | `geoauth.google.com` | 18 | **Auth server (critical!)** |
| 4 | 0x0104a4cf | `maps.google.com` | 15 | Maps server |
| 5 | 0x0104a500 | `geo.keyhole.com` | 15 | Legacy Keyhole |
| 6 | 0x0104a5bc | `kh.google.com` | 13 | Tile server hostname |
| 7 | 0x0104a5e0 | `bbs.keyhole.com` | 15 | Keyhole BBS |
| 8 | 0x0104a668 | `dev.keyhole.com` | 15 | Keyhole dev |
| 9 | 0x0104a6bc | `www.google.com` | 14 | Google web |

### Why All 9 Are Needed
- Missing `geoauth.google.com` (#3) → auth fails → GE greyed out
- Missing `geo.keyhole.com` (#5) → initialization fails
- All 9 must point to the proxy for GEMMI to complete startup

### Replacement Format
```
192.168.0.91\x00\x00...  (IP + null padding to match original length)
```

## Discovery Method
Compared stock binary against the XGX variant (which replaced all 9
hostnames with `xgx.ddns.net`), then the FINAL working binary (which
replaced `xgx.ddns.net` with `192.168.0.91`).

## Verified Working
- v18 proxy (xgx dbRoot) + FINAL2 binary → tiles at zoom 1-22+ ✅
- v19 proxy (custom dbRoot) + FINAL2 binary → tiles at zoom 1-22+ ✅
