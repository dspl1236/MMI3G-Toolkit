# Custom Firmware Patches — IFS Patching for Google Earth

## Overview

This document describes how to build minimal IFS patches that add
Google Earth support to firmware variants where it was removed.
The approach modifies only the necessary files (srv-starter.cfg
and lsd.jxe) rather than replacing the entire firmware with a
different region's build.

**Status: DOCUMENTED — NOT YET BUILT OR TESTED**

## The Problem

US/NAR firmware variants had Google Earth surgically removed:

| Component | EU VW (K0821) | Audi NAR (K0942) | US RNS-850 (K0711) |
|-----------|--------------|------------------|---------------------|
| IFS version | 2123 | 2145 | 1906 |
| Process 97 | run_gemmi.sh | run_gemmi.sh | pintest (REPLACED) |
| Package 28 HostsProcess | 97 (connected) | 97 (connected) | EMPTY (gutted) |
| RANGE_GOOGLE_EARTH | =0 (blocked) | (none, allowed) | =0 (blocked) |
| EOLFLAG_GOOGLE_EARTH | =0 (default) | =0 (default) | =0 (default) |
| GEMMI binaries | In nav maps | In nav maps | Not included |
| ProcessCount | 100 | 101 | 98 |

## Congo's Approach (Full EU Flash)

Congo (audi-mib.bg) resolves this by flashing the EU K0821 firmware
which has the complete GEMMI infrastructure. His page states:
"K0821 adds the Google Earth map option."

Pros: Complete, proven solution
Cons: Replaces entire firmware, loses NAR features (SiriusXM, etc.)

## Our Approach (Minimal IFS Patch)

Patch only the files that differ, preserving everything else:

### Changes Required in IFS

**1. mmi3g-srv-starter.cfg**

Replace Process 97 definition:
```xml
<!-- BEFORE (US RNS-850): -->
<Process>
  <Number>97</Number>
  <n>/usr/bin/pintest</n>
  <Args>-n 4096 -p 8245 -b</Args>
  ...
</Process>

<!-- AFTER (matches EU/Audi): -->
<Process>
  <Number>97</Number>
  <n>/usr/bin/run_gemmi.sh</n>
  <Args/>
  ...
</Process>
```

Reconnect Package 28:
```xml
<!-- BEFORE: -->
<HostsProcess/>

<!-- AFTER: -->
<HostsProcess>97</HostsProcess>
```

**2. lsd.jxe (JAR archive)**

In `resources/sysconst/variants/no_online_services.properties`:
```
# BEFORE:
RANGE_EOLFLAG_GOOGLE_EARTH=0
RANGE_EOLFLAG_ONLINE_SEARCH=0
RANGE_EOLFLAG_ONLINE_SERVICES=0

# AFTER: Remove all three RANGE_ lines entirely
# (matches Audi behavior — no restriction)
```

In `resources/sysconst/sysconst.properties`:
```
# BEFORE:
EOLFLAG_GOOGLE_EARTH=0

# AFTER:
EOLFLAG_GOOGLE_EARTH=1
```

**3. ifs-root-version.txt**

```
# BEFORE:
version = 1906

# AFTER:
version = 1907
```

### Files NOT Modified

Everything else in the IFS stays untouched:
- MMI3GApplication (main app binary)
- QNX kernel and drivers
- Java VM (J9)
- All other srv-starter processes
- Radio/media/phone functionality
- CAN bus configuration
- Bootloader
- Emergency IFS

## Build Pipeline

Using existing MMI3G-Toolkit tools:

```
Step 1: inflate_ifs.py
        Decompress the target IFS
        Input: ifs-root.ifs (from user's Flashdaten)
        Output: ifs-root-decompressed.ifs

Step 2: extract_qnx_ifs.py
        Extract file tree from decompressed IFS
        Output: extracted/ directory with all files

Step 3: Patch srv-starter.cfg
        - Replace Process 97 (pintest → run_gemmi.sh)
        - Connect Package 28 HostsProcess to 97

Step 4: Patch lsd.jxe
        - Extract JAR: unzip lsd.jxe
        - Edit no_online_services.properties (remove RANGE_ lines)
        - Edit sysconst.properties (set EOLFLAG_GOOGLE_EARTH=1)
        - Repackage JAR: zip lsd.jxe (STORE, no compression)
        - Or use eol_modifier.py (needs --remove-range feature)

Step 5: Update ifs-root-version.txt
        - Bump version: 1906 → 1907

Step 6: patch_ifs.py
        Replace modified files in the decompressed IFS
        Input: original decompressed IFS + patched files
        Output: patched decompressed IFS

Step 7: repack_ifs.py
        Recompress the IFS (LZO1X, byte-identical to Harman)
        Output: ifs-root-patched.ifs

Step 8: mu_crc_patcher.py
        Recalculate SWDL checksums for metainfo2.txt
        Output: updated metainfo2.txt with correct CRCs

Step 9: Package as SWDL update
        Create SD card directory structure matching SWDL format
        User flashes via Engineering Menu (SETUP + PHONE)
```

## Versioning Strategy

### Upgrade Path
```
OEM firmware:     version 1906 (original)
GE patch:         version 1907 (our patch)
Revert to stock:  version 1908 (original files, bumped version)
```

Each step looks like an "upgrade" to SWDL → always accepted.

### Engineering Menu Override

Confirmed from community (t7p_club, Feb 2022): The Engineering
Menu accepts same-version flashing (shown as "90 → 90") with
manual checkbox selection. This means:

- Upgrades: automatic (version check passes)
- Same version: manual (check boxes in Engineering Menu)
- Downgrades: manual (check boxes)
- Users can ALWAYS revert to any version via Engineering Menu

### Version Numbering Convention

```
OEM version + 1  = MMI3G-Toolkit patch
OEM version + 2  = MMI3G-Toolkit revert (stock files)
OEM version + 10 = Reserved for future patches
```

Example for RNS-850 K0711:
```
1906  = OEM (original)
1907  = +Google Earth patch
1908  = Revert to stock
1916  = Reserved for future feature patches
```

## Version Matching

Each firmware version has a different IFS with different binary
content. Users MUST match their firmware version:

| Firmware | Train | IFS Version | Target |
|----------|-------|-------------|--------|
| K0711 | HN+_US_VW_K0711 | 1906 | US RNS-850 |
| K0821 | HN+_EU_VW_K0821 | 2123 | EU RNS-850 (already has GE) |
| K0942_3 | HN+R_US_AU_K0942_3 | varies | US Audi (EFS patch, no IFS needed) |
| K0942_6 | HN+_US_AU3G_K0942_6 | 2145 | US Audi newer HW |

The `ge_probe.sh` script reports the firmware train name, which
users can share to get the correct patch.

## Safety Considerations

1. **Always ship patch + revert as a pair** — users must be able
   to get back to stock with a single SD card flash.

2. **Backup before flash** — the Engineering Menu shows component
   versions before flashing. Document the expected values.

3. **Only IFS is modified** — EFS, IPL, FPGA, emergency IFS, and
   all ECU firmwares are untouched. The car will boot even if the
   IFS patch is bad (emergency IFS takes over).

4. **Emergency IFS** — QNX boots from emergency IFS if the main
   IFS fails. This provides a recovery path independent of our
   changes. The emergency IFS is NEVER modified.

5. **CRC verification** — SWDL validates per-chunk CRC32 during
   flash. Our mu_crc_patcher.py recalculates these correctly.
   Incorrect CRCs cause the update to abort (safe failure).

6. **Test on one car first** — build for a specific known
   firmware version, test on a volunteer's car, verify all
   functionality before distributing.

7. **Version pinning** — don't distribute "universal" patches.
   Each patch targets a specific firmware version. Mismatched
   versions could cause boot failures.

## Distribution Plan

**Phase 1: SD Card Scripts (Current)**
- ge_probe.sh — diagnostic
- ge_activate.sh — deploy + enable + direct launch
- ge_restore.sh — clean revert
- No IFS modification needed for Audi (writable EFS)
- Direct launch bypasses UI menu for RNS-850

**Phase 2: Pre-built IFS Patches (Future)**
- Build patches for specific firmware versions
- Ship as GitHub Releases (patch + revert pair)
- User matches version → downloads → flashes via Engineering Menu
- Only for RNS-850 (Audi doesn't need IFS patch)

**Phase 3: Automated Patcher Tool (Future)**
- User provides their IFS from Flashdaten
- Tool patches and packages automatically
- Generates both patch and revert SD cards
- Web app integration possible

## Comparison with Congo's Service

| Aspect | Congo (audi-mib.bg) | MMI3G-Toolkit |
|--------|---------------------|---------------|
| Price | €90 one-time | Free |
| Method (MMI3G+) | Binary patch of gemmi_final | EOL flag + disableAuthKey |
| Method (RNS-850) | Flash EU K0821 firmware | Minimal IFS patch |
| Proxy required | Yes (MMI3G+), No (RNS-850) | No (direct to Google) |
| NAR features | Lost (full EU flash) | Preserved (minimal patch) |
| Warranty | 6 months (MIB only) | Community supported |
| VIN-specific | Yes (per-car activation) | No (universal patch) |
| Open source | No | Yes |

## References

- `research/EOL_FLAGS_AND_GOOGLE_EARTH.md` — Complete protocol analysis
- `research/SWDL_UPDATE_SYSTEM.md` — Firmware update system
- `research/CUSTOM_DRIVER_INJECTION.md` — Driver loading methods
- `tools/inflate_ifs.py` — IFS decompression
- `tools/patch_ifs.py` — IFS file replacement
- `tools/repack_ifs.py` — IFS recompression
- `tools/mu_crc_patcher.py` — SWDL CRC fixing
- `tools/eol_modifier.py` — EOL flag modification
- DrGER2/GEMMI-Monitor — GEMMI logging and monitoring
- audi-mib.bg — Congo's Google Earth restoration service
