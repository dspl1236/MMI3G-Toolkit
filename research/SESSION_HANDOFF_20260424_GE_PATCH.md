# SESSION HANDOFF — April 24, 2026 (Binary Patching Session)

## Key Achievement
**Auth bypass CONFIRMED** — gemmi_final binary patched, auth loop eliminated.

## Patches Deployed on Car

### gemmi_final.patched_v3 (on car at /mnt/nav/gemmi/gemmi_final)
- **Patch 1 @ 0x065b90:** OnAuthenticationFailed → `rts + nop` (immediate return)
- **Patch 2 @ 0x065c94:** `tst r8,r8` → `mov #1, r8` (force online=1)
- Effect: auth failures silently ignored, online flag forced to 1
- Originals backed up as gemmi_final.orig, gemmi_final.orig2

### libembeddedearth.so.patched_v4 (on car at /mnt/nav/gemmi/libembeddedearth.so)
- DefaultServer: `http://kh.google.com/` → `http://192.168.0.91/`
- geFreeLoginServer: `kh.google.com` → NULLED (13 zero bytes)
- /geauth path: NULLED (7 zero bytes)
- Original backed up as libembeddedearth.so.orig

### drivers.ini (on car at /mnt/nav/gemmi/drivers.ini)
- `Connection/disableAuthKey = true` INSIDE SETTINGS block
- `maxLoginAttempts` REMOVED (causes GE toggle to grey out)

### /etc/hosts (NON-PERSISTENT, resets on reboot)
- `192.168.0.91 kh.google.com` — must be re-added after each reboot

### run_gemmi.sh
- `restart_countdown=999` (was 5, stock is 5)

## Observed Behavior with Patches

### What Works
```
frame 0: OnBeginLogin()
Starting to log in
On logged In online = 0          ← libembeddedearth.so says offline
frame 7: OnEndLogin()
Finished logging in online, took 0.476s  ← BUT gemmi_final forces LOGGED_IN
frame 5: OnLayersReady()         ← Layers ready!
```
- NO auth loop (was: infinite "login failed" / "NOT_LOGGED_IN" retry)
- NO auth requests to proxy (auth server nulled)
- State = LOGGED_IN
- OnLayersReady fires

### What Doesn't Work
- **No tile requests at all** — netstat shows zero outgoing connections
- GEMMI gets dbRoot (16930 bytes) from proxy but never requests /flatfile tiles
- GE screen shows on car but no satellite imagery loads

### Root Cause Theory
libembeddedearth.so has its OWN internal online flag separate from gemmi_final's
state machine. We patched gemmi_final to say LOGGED_IN, but the earth rendering
engine inside libembeddedearth.so still thinks it's offline. It won't fetch tiles
because ITS online flag is false.

The `online = 0` in the log is the value FROM libembeddedearth.so. Our patch
forces gemmi_final to take the LOGGED_IN code path regardless, but
libembeddedearth.so's tile fetcher independently checks its own online state.

## Files on Andrew's PC (D:\MMI\)
- gemmi_final.patched, gemmi_final.patched_v2, gemmi_final.patched_v3
- libembeddedearth.so.patched_v3, libembeddedearth.so.patched_v4
- proxy/ — gemmi_tile_proxy.py + dbRoot.v5.cached

## Ghidra Analysis
- Ghidra 11.3.1 installed at /home/claude/ghidra_11.3.1_PUBLIC/
- libembeddedearth.so imported into /tmp/ghidra_project (SH4 LE)
- Analysis may still be running (20MB binary, slow on SH4)
- gemmi_final analysis NOT yet run (would be faster, 2MB)

## Next Steps (Priority Order)

### 1. Patch libembeddedearth.so's internal online flag
- Find where libembeddedearth.so checks online status before tile fetch
- Force it to return true
- Requires Ghidra decompilation of the earth module
- Key function: the one that calls OnLoggedIn callback with online parameter

### 2. Try embedded dbRoot fallback
- Return 404 for /dbRoot.v5 from proxy
- GEMMI has "dbroot.v5.embedded" string — might have built-in fallback
- Embedded dbRoot might have different behavior (no auth requirement)

### 3. Open GEE server approach
- Set up a local Google Earth Enterprise server
- It generates its own encrypted dbRoot with proper tile URLs
- Point GEMMI at the local GEE server instead of Google
- This is the commercial solution approach (congo, audi-mib.bg)

### 4. Study congo's patch approach
- congo patches gemmi_final (not libembeddedearth.so!)
- His patch likely modifies more than just the auth callback
- Might patch the tile fetch logic or the dbRoot parsing
- €75-180 for the solution

## Repo State
- **228 commits** on MMI3G-Toolkit
- P0824 module moved to GitHub Release (CORS fix)
- CLI-only badge for web builder
- Webapp blank page bug fixed
- 34/34 tests green

## Key Learnings
1. Auth flow is in gemmi_final (callbacks), auth MECHANISM is in libembeddedearth.so
2. OnAuthenticationFailed and OnLoggedIn are separate callbacks
3. Null auth server → OnLoggedIn(online=0) instead of OnAuthFailed
4. Auth server present → OnAuthFailed (never reaches OnLoggedIn)
5. gemmi_final state machine and libembeddedearth.so tile engine have INDEPENDENT online flags
6. Patching gemmi_final alone is not enough — need to patch libembeddedearth.so too
7. Google's dbRoot is encrypted but parseable by GEMMI (doesn't crash)
8. run_gemmi.sh has 5 retries then reformats img-cache — set to 999 for testing
