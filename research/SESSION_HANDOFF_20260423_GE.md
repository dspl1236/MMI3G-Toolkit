# SESSION HANDOFF — April 23, 2026 (Extended GE Session)

## Repos
- MMI3G-Toolkit: **210 commits** (was 200 at start)
- GitHub token: `D:\ECU FLASH\file.txt`
- Andrew's PC: 192.168.0.91 / MMI: 192.168.0.154

## What's Working
- ✅ Port 23 telnet + passwordless root (DrGER2 shadow method) — PERSISTENT
- ✅ Port 2323 raw shell — SESSION ONLY (inetd.conf is on read-only IFS)
- ✅ 203 ESDs installed (scanner, coding, games, toolkit)
- ✅ LTE/DHCP networking — stable, ASIX adapter works
- ✅ Webapp building SD cards, manifest in sync
- ✅ GE toggle in MMI works (SysConstManager NAD detection)
- ✅ GEMMI running (v8.0.25, libcurl/7.26.0, c-ares/1.7.3)
- ✅ Tile proxy intercepts requests — dbRoot served, auth intercepted
- ✅ DNS redirect via /etc/hosts works (c-ares DOES use /etc/hosts)
- ✅ Online services (news/weather/Audi) unaffected by kh.google.com redirect

## Google Earth — THE REMAINING PROBLEM

### Architecture Confirmed
```
MMI (/etc/hosts) → 192.168.0.91 (PC proxy port 80)
  GET /dbRoot.v5?cobrand=AUDI  → proxy serves cached generic dbRoot (16930 bytes) ✅
  POST /geauth (39 bytes)      → proxy returns fake 200 ❌ WRONG FORMAT
  → "Authentication failed. NOT_LOGGED_IN set" → retry loop
```

### Auth Protocol Captured
GEMMI POST /geauth body (39 bytes):
```
Hex: 0000000003fd8ba6e1d7daa565e94c6db548e60b44869d0a6ea382d86e09514e582d756e736574
```
Structure:
- Bytes 0-3: `00000000` (header/padding)
- Byte 4: `03` (command type = login)
- Bytes 5-20: 16-byte hash (derived from dbRoot or session)
- Bytes 21-28: 8 additional bytes
- Byte 29: `09` (length prefix)
- Bytes 30-38: "QNX-unset" (OS=QNX, token=unset → wants a token back)

Headers:
```
User-Agent: GoogleEarth/5.2.0000.6394(MMI3G;QNX (0.0.0.0);en-US;kml:2.2;client:Free;type:default)
Accept: application/vnd.google-earth.kml+xml, application/vnd.google-earth.kmz, image/*, */*
Content-Type: application/octet-stream
```

### What disableAuthKey Does (and Doesn't)
- `Connection/disableAuthKey = true` INSIDE SETTINGS{} block
- Does NOT prevent auth — the auth protocol fires from libembeddedearth.so regardless
- BUT it prevents GE toggle from greying out — important for UI access
- `maxLoginAttempts = 0` causes toggle to grey out — DO NOT USE

### drivers.ini — CURRENT STATE (correct)
```
SETTINGS {
    ...existing settings...
    Connection/disableAuthKey = true
}
```
Located at: `/mnt/nav/gemmi/drivers.ini` (writable nav HDD)

### dbRoot.v5 — Encrypted
- Google serves plain dbRoot at `kh.google.com/dbRoot.v5` (200, 16930 bytes)
- Google 404s `cobrand=AUDI` requests
- File is XOR-encrypted (EncryptedDbRootProto format)
- XOR key confirmed at offset 8: `45f4bd0b79e26a4522 05922c17cd0671f849104667510042 25c6e861 2c662908`
- Decrypted content needs further analysis (zlib decompression + protobuf parsing)
- Contains all server URLs including auth endpoint — modifying this could bypass auth

### Proxy Location
- Script: `D:\MMI\proxy\gemmi_tile_proxy.py`
- Cache: `D:\MMI\proxy\dbRoot.v5.cached`
- Also in repo: `tools/gemmi_tile_proxy.py` + `tools/dbRoot.v5.cached`

### NEXT STEPS for GE (in priority order)

1. **Decode the dbRoot protobuf** — decrypt (XOR), decompress (zlib), parse protobuf
   - Find the auth server URL in the protobuf
   - Find the tile server URL templates
   - Modify to remove auth requirement or change URLs
   - Re-encrypt and serve modified version

2. **Craft correct auth response** — if dbRoot can't be modified
   - The 39-byte POST body gives us the protocol format
   - Need to reverse-engineer what GEMMI expects back
   - Could binary-search by trying different response formats
   - Or analyze libembeddedearth.so (20MB, SH4A binary) for the auth handler

3. **Binary patch libembeddedearth.so** — nuclear option
   - File is on writable /mnt/nav/gemmi/ (not IFS!)
   - Could NOP out the auth check
   - Could change the hostname (kh.google.com → custom domain)
   - Risky but file is easily replaceable (backup + copy)

4. **Study congo/audi-mib.bg approach** — they solved this exact problem
   - They binary-patch libembeddedearth.so to redirect to their servers
   - They run a permanent proxy that handles the protocol translation
   - Their price: €75-180

## Filesystem Key Facts
- `/mnt/nav/gemmi/` — WRITABLE (nav HDD, 10GB free)
- `/mnt/nav/gemmi/libembeddedearth.so` — 20MB, WRITABLE, SH4A binary
- `/mnt/nav/gemmi/drivers.ini` — WRITABLE
- `/mnt/efs-system/` — 96% full (only 3.4KB free!)
- `/etc/hosts` — writable but resets on reboot (IFS copy in RAM)
- `/etc/resolv.conf` — `nameserver 192.168.0.1` (router)
- `/lsd/lsd.jxe` — symlink → /mnt/ifs-root/lsd/lsd.jxe (IFS, read-only)
- `/lsd/` directory — WRITABLE (EFS)

## Bugs Fixed This Session
- Manifest.json regeneration after file changes
- EFS remount before each module (gem-activator triggers F3S reclaim)
- GE probe checks both drivers.ini paths (GEMMI + EFS)
- maxLoginAttempts = 0 causes GE toggle to grey out (removed)
- disableAuthKey must be INSIDE SETTINGS{} block

## Other Pending Items
- Game JARs missing from CLI builder (webapp handles them)
- Port 2323 not persistent (inetd.conf is IFS) — port 23 is the real path
- Test GEM screens (Scanner, Coding, Games) — ESDs installed but not verified on display

## BINARY ANALYSIS RESULTS (Late Session)

### gemmi_final (2.1MB, SH4A ELF, stripped)
- Built from: `D:\CMandal\GEarth_products\sh4-qnx-m632-3.4.4-osp-trc-rel\`
- HydraGoogleClient v5.0.3
- Contains: Street View URLs (`cbk0.google.com`), cookie handling, auth flow strings
- Does NOT contain `kh.google.com` — that's in libembeddedearth.so
- Congo patches THIS binary to redirect (but hostname is in the .so)

### libembeddedearth.so (20.8MB, SH4A ELF, not stripped)
**Auth Config Block at ~offset 17081400:**
```
auth.google.com                    ← auth server
/cgi-bin/viewer_reg_login          ← registration login path
retries                            ← retry count
authInfo                           ← auth info
disableAuthKey                     ← config toggle (from drivers.ini)
expiration                         ← session expiration
cookie                             ← cookie handling  
deauthServer                       ← deauth server
/deactivate                        ← deauth path
googleMFEServer                    ← Maps FE server
http://maps.google.com             ← maps URL
geFreeLoginServer                  ← FREE LOGIN SERVER
kh.google.com         @17081788    ← value for geFreeLoginServer
/geauth               @17081804    ← auth endpoint path
bbsServer                          ← BBS server
bbs.keyhole.com                    ← keyhole BBS
```

**Default Server URL:**
```
DefaultServer
http://kh.google.com/    @17055180  ← base URL for dbRoot + tiles
```

### Key Byte Offsets for Patching
| Offset | String | Purpose |
|--------|--------|---------|
| 17055180 | `http://kh.google.com/` | DefaultServer URL (21 bytes) |
| 17081464 | `disableAuthKey` | Config field name |
| 17081788 | `kh.google.com` | geFreeLoginServer value (13 bytes) |
| 17081804 | `/geauth` | Auth endpoint path (7 bytes) |

### Auth Protocol (from proxy captures)
- GEMMI POSTs 39 bytes to `/geauth`
- Body: 4-byte header + 1-byte command (0x03) + 16-byte hash + 8 extra bytes + "QNX-unset"
- "QNX-unset" = OS name + empty token (wants token back)
- GEMMI uses HTTP cookies for session (Set-Cookie/Cookie headers)
- But auth validation is DEEPER than cookies — checks binary response body
- Neither plain text, empty body, nor Set-Cookie responses break the auth loop

### Auth Approaches Tried and Failed
1. ❌ `disableAuthKey = true` outside SETTINGS block (not read)
2. ❌ `disableAuthKey = true` inside SETTINGS block (overridden by dbRoot)
3. ❌ `maxLoginAttempts = 0` (greys out GE toggle)
4. ❌ Proxy returns "authorized" text
5. ❌ Proxy returns empty 200
6. ❌ Proxy returns Set-Cookie headers
7. ❌ Proxy returns "1"

### NEXT SESSION: Binary Patch Options

**Option A: Null out geFreeLoginServer**
- At offset 17081788, replace `kh.google.com` with 13 null bytes
- GEMMI can't find auth server → might skip auth or use embedded dbRoot

**Option B: NOP the auth check**
- Disassemble libembeddedearth.so (SH4A architecture)
- Find the auth validation function
- Patch the conditional jump to always-pass
- Requires Ghidra with SH4A support

**Option C: Build custom dbRoot protobuf**
- Create minimal DbRootProto with `disable_authentication = true` (field 3)
- Encrypt with GEE etEncoder (1016-byte key, rotated XOR)
- Serve from proxy instead of Google's encrypted version
- Challenge: Google's public server may use different encryption than GEE

**Option D: Patch DefaultServer URL**
- At offset 17055180, replace `http://kh.google.com/` with proxy URL
- `http://192.168.0.91/` is 20 chars (original is 21) — needs padding
- Or use a 13-char hostname to match exactly

### Files on Andrew's PC
- `D:\MMI\gemmi_final` — 2.1MB binary (from car)
- `D:\MMI\libembeddedearth.so` — 20.8MB library (from car)
- `D:\MMI\proxy\gemmi_tile_proxy.py` — latest proxy with cookie auth
- `D:\MMI\proxy\dbRoot.v5.cached` — cached generic dbRoot (16.9KB)
