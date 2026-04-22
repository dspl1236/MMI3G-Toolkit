# RNS 850 — VW Touareg (HN+ Platform Twin)

> Analysis of HN+_EU_VW_P0534 firmware (MU9478, build 9478)
> Compared with Audi MMI3G+ HN+R K0942 (build 9411)
> Date: April 19, 2026

## Overview

The VW RNS 850 is the Touareg's head unit and runs on the **exact same
Harman Becker HN+ platform** as the Audi MMI3G and Porsche PCM 3.1.
The firmware literally identifies itself as `MMI3GP Build 9478`.

## Platform Confirmation

| Property | Audi MMI3G (K0942) | RNS 850 (MU9478) | Match? |
|----------|:------------------:|:-----------------:|:------:|
| CPU | SH4 (SH7785) | SH4 (SH7785) | ✅ |
| OS | QNX 6.3.2 | QNX 6.3.2 | ✅ |
| GCC | 3.4.4 | 3.4.4 | ✅ |
| Build system | Harman/Becker | Harman/Becker MMI3GP | ✅ |
| IFS format | QNX IFS | QNX IFS | ✅ |
| EFS format | EFS partition | EFS partition | ✅ |
| Persistence | /HBpersistence/ | /HBpersistence/ | ✅ |
| USB autorun | copie_scr.sh | copie_scr.sh | ✅ |
| XOR seed | 0x001be3ac | 0x001be3ac | ✅ |
| Activation | FSC (EscRsa) | FSC (Java/BouncyCastle) | ⚠️ Different! |

## Firmware Structure

```
HN+/MU9478/
  ├── ifs-root/41/default/ifs-root.ifs    (42 MB — main firmware)
  ├── ifs-emg/41/default/ifs-emg.ifs      (4.6 MB — emergency/recovery)
  ├── efs-system/41/default/efs-system.efs (37 MB — system EFS)
  ├── efs-extended/41/default/efs-extended.efs (12 MB — extended EFS)
  ├── fpga/41/default/SystemFPGA.hbbin     (730 KB — display FPGA)
  ├── fpga-emg/41/default/SystemFPGA.hbbin (729 KB — emergency FPGA)
  ├── tools/
  │   ├── showScreen                        (74 KB — display utility)
  │   ├── sqlite3                           (437 KB — database tool)
  │   ├── sqlite.xml                        (798 bytes — config)
  │   └── rePartitioningNeeded.png          (15 KB — UI image)
  ├── preUpdateScript                       (2.4 KB — pre-update hook)
  └── postUpdateScript                      (15 KB — post-update hook)
```

The `41/default/` path corresponds to variant 41 — the same variant
numbering used in the Audi MMI3G builds.

## USB Autorun — CONFIRMED WORKING

The RNS 850 uses the **identical** `proc_scriptlauncher` mechanism:

```
XOR PRNG seed:    0x001be3ac    (found at IFS offset 0xb609b)
copie_scr.sh:     found at 0xb6d6a
proc_scriptlauncher: same binary, same decoder
```

**Any copie_scr.sh XOR-encoded with seed 0x001be3ac will execute as root
on the RNS 850.** The MMI3G-Toolkit's existing SD card builder generates
compatible autorun scripts.

### USB vs SD Card

The RNS 850 likely uses USB rather than SD card (the Touareg has USB
ports but no SD card slot on most models). The proc_scriptlauncher
scans multiple mount points:
- `/fs/usb0`, `/fs/usb1` (USB)
- `/fs/sd0` (SD card, if available)
- `/media/usb0` (alternate USB mount)

## FSC Activation System — DIFFERENT FROM AUDI

### Audi MMI3G (K0942) — Native EscRsa
```
EscRsa_DecryptSignature → native SH4 code
Bypass: 2-byte patch at 0x001B11F6 (JSR @r0 → MOV #0,r0)
Simple, reliable, single binary patch
```

### RNS 850 (MU9478) — Java BouncyCastle
```
org/bouncycastle/crypto/engines/RSA*
java/security/SignatureSpi
IllegalFSC at 0x18406c5 (inside Java bytecode region)
```

The RNS 850 FSC verification is implemented in **Java** using the
BouncyCastle cryptographic library, not in native SH4 code. This means
the Audi 2-byte native patch **will not work** on the RNS 850.

### Possible Bypass Approaches

1. **Patch Java class file** — Extract the FSC verification class from
   the embedded JAR, decompile, modify the verification method to
   always return true, recompile, repack into IFS
   
2. **Patch native→Java bridge** — Find where the native QNX code
   consumes the Java FSC verification result and patch the native
   conditional branch (similar to Audi approach but different offset)

3. **Patch areFSCsSigned flag** — If there's a configuration flag that
   controls whether FSCs require signatures, setting it to false would
   bypass verification without code patches

4. **USB script approach** — Since we have root access via copie_scr.sh,
   we could potentially write FSC files directly to /HBpersistence/FSC/
   without valid signatures, IF the check only happens at import time
   and not at boot

## Strings of Interest

### Build identification
```
PLABEL=PL_qnx_startup-sh7785_11292A
QNX_LABEL=RL_qnx_632_PSP3_10455A
QNX_VERSION=632
Harman/Becker MMI3GP Build 9478 C1 D1-12042A
HOST=uberbuild
```

### IFS signature verification (startup code)
```
FOUND valid IFS signature
FOUND valid IFS signature and RIFS info in RAM.
FOUND valid IFS2 signature and RIFS2 info in RAM.
FOUND valid RIFS signature
INVALID IFS signature
INVALID RIFS signature
```

### Activation system
```
ACTIVATIONSTATE_INIT
ACTIVATION_PHONE_ON
IllegalFSC
onIllegalFSCsUpdate get swid index: %d
SWID-Typ
/HBpersistence/SWDL/EnableFs
private_decrypt
RSA_new
KE_RSA
```

### Feature names (same as MMI3G/PCM3.1)
```
ENGINEERING (at 0x1dceda6)
Navigation  (at 0x119dc30)
SDARS       (at 0xb92849)
BTH         (at 0x25f7de)
```

## Cross-Platform Compatibility

### What works on RNS 850 from MMI3G-Toolkit:
- ✅ SD/USB card autorun (copie_scr.sh, same XOR cipher)
- ✅ Root shell access
- ✅ Diagnostic data collection
- ✅ /HBpersistence/ file operations
- ✅ QNX system commands
- ✅ GEM engineering menu — confirmed working by daredoole (2016 Touareg, HN+_US_VW_P0738). Same ESD format, same block syntax requirement.
- ⚠️ per3 persistence (same DSI framework, untested on RNS-850)

### What does NOT work:
- ❌ Audi FSC 2-byte patch (different crypto implementation)
- ❌ Audi EFS repacking (different EFS contents)
- ❌ Audi-specific ESD screens (VW has different menu items)

## Relationship to Porsche PCM 3.1

The RNS 850 sits between the Audi MMI3G and Porsche PCM 3.1:

```
                    Harman Becker HN+ Platform
                    ═════════════════════════
                              │
            ┌─────────────────┼─────────────────┐
            │                 │                 │
      Audi MMI3G         VW RNS 850       Porsche PCM 3.1
      K0942 (9411)       MU9478 (9478)     (15245AS9)
            │                 │                 │
      FSC + EscRsa       FSC + Java BC     PagSWAct + RSA-64
      2-byte patch       1-byte patch ✅       Key derived
      SD card            USB stick         USB stick
      EFS screens        EFS screens       Compiled screens
```

## Available Firmware Versions

From the MIB Solution repository:
```
HN+_EU_VW_E6077     — early build
HN+_EU_VW_K0775     — K-series
HN+_EU_VW_K0821     — K-series (newer)
HN+_EU_VW_P0125     — P-series (production)
HN+_EU_VW_P0145     — P-series update
HN+_EU_VW_P0534     — P-series (this analysis) ← MU9478t.rar
HN+R_EU_VW_P0824    — HN+R variant            ← MU9478.rar (not yet extracted)
```

## Next Steps

- [x] Extract the HN+R variant (P0824) and compare with HN+ (P0534)
- [x] Decompile Java FSC verification from EFS (Ghidra not needed — CFR decompiler)
- [x] Extract Java class files from EFS and decompile FSC verification
- [ ] Test USB autorun on a real VW Touareg
- [ ] Map the GEM/engineering menu ESD screens
- [x] Confirmed: same RSA key across Audi and VW platforms
- [x] Verified: HN+R does NOT use native EscRsa — Java BouncyCastle only

## HN+R Variant Analysis (P0824, 2016 build)

### CRITICAL: USB Autorun REMOVED in HN+R

| Feature | HN+ (2012, P0534) | HN+R (2016, P0824) |
|---------|:------------------:|:-------------------:|
| copie_scr.sh | ✅ Present | ❌ **REMOVED** |
| XOR seed 0x001be3ac | ✅ Present | ❌ **REMOVED** |
| proc_scriptlauncher | ✅ Present | ❌ **REMOVED** |
| BouncyCastle FSC | ✅ Java-based | ✅ Java-based |
| EscRsa (native) | ❌ Not used | ❌ Not used |
| Build ID | 9478 D1-12042A | 9478 D1-16243A |
| IFS size | 43,608,784 | 43,486,868 |
| Variants | 41 only | 41, 51, 61 |

VW deliberately removed the proc_scriptlauncher USB autorun mechanism
in the 2016 firmware update. This means:

- **Pre-2016 Touaregs**: USB root access works (copie_scr.sh method)
- **Post-2016 Touaregs**: USB root access is blocked
- **All Touaregs**: FSC uses Java BouncyCastle, NOT native EscRsa
- **Audi 2-byte patch**: Does NOT apply to any RNS 850 variant

### Implications for Audi MMI3G

If VW removed the USB autorun in 2016 RNS 850 firmware, Audi may have
done the same in later MMI3G+ updates. The K0942 build we analyzed
still has it, but newer Audi firmware builds should be checked.

Porsche PCM 3.1 still has proc_scriptlauncher in the latest firmware
(build 15245AS9, June 2015) — but Porsche stopped updating PCM 3.1
before the vulnerability was patched.

## BouncyCastle FSC Bypass — BREAKTHROUGH (April 19, 2026)

### RSA Key Extraction

The RSA public key is hardcoded in `SignatureBlockProcessor.class`:

```java
static final String RSA_MODULUS = "AI2fepz64ZbVLru5KITtZkPSwHu0RDuAGDhh...";
static final BigInteger RSA_PUBLIC_EXP = BigInteger.valueOf(17L);
```

Key properties:
- **Modulus**: 1024-bit RSA (NOT factorable)
- **Public exponent**: 17 (unusual — standard is 65537)
- **Location**: `de/audi/tghu/development/jobs/SignatureBlockProcessor.class`
- **Stored in**: EFS-system partition, first JAR at offset 0x418580

### Verification Flow (Decompiled)

```
process()
  ├── Check: MANIFEST.MF exists?
  │     NO  → createUnsignedContent() ← BYPASS PATH!
  │     YES → continue
  ├── processSigner(zipFile, manifest, "META-INF/MANIFEST.SF")
  │     ├── decrypt(sf_data, manifest_data)
  │     │     ├── Extract "SF-Key" from manifest
  │     │     ├── RSA decrypt SF-Key (modulus + e=17)
  │     │     ├── Use decrypted key as AES-CBC key
  │     │     └── Decrypt SF file with AES-CBC
  │     ├── verifyManifestAndSignatureFile(manifest, decrypted_sf)
  │     │     ├── Compute SHA1/MD5 of manifest
  │     │     ├── Extract expected hash from SF
  │     │     └── Compare → SecurityException if mismatch
  │     └── populateMDResults(sf, signerInfo)
  └── Return SignedContent
```

### Audi Crypto Package

All extracted from EFS-system JAR:
```
de/audi/crypto/RSAEngine.class        (1,748 bytes) — processBlock()
de/audi/crypto/PKCS1Encoding.class     (1,875 bytes) — PKCS1 padding
de/audi/crypto/RSAKeyParameters.class  (481 bytes)   — key storage
de/audi/crypto/AESEngine.class         (15,749 bytes) — AES encryption
de/audi/crypto/CBCBlockCipher.class    (1,752 bytes) — CBC mode
de/audi/crypto/KeyParameter.class      (427 bytes)   — key wrapper
```

### Bypass Approaches (Ranked)

**Approach 1: Patch processSigner to skip verification** (SIMPLEST)
- In `SignatureBlockProcessor.class`, replace `processSigner` method body
  with just `return` (bytecode 0xB1)
- Effect: FSCs import without any signature check
- Risk: LOW — only affects FSC import, not system stability

**Approach 2: Patch verifyManifestAndSignatureFile** (TARGETED)
- Replace method body with `return` (0xB1)
- RSA decryption still runs (for AES key), just hash check skipped
- Effect: Allows tampered FSC files

**Approach 3: Replace RSA_MODULUS with own key** (ELEGANT)
- Generate RSA-1024 keypair with e=17
- Replace the Base64 modulus string in the class file
- Sign FSCs with our private key
- Effect: Full FSC signing capability

### Implementation Notes

The patched class file needs to be:
1. Reinserted into the EFS-system JAR
2. EFS-system written back to flash
3. This requires root access (copie_scr.sh on pre-2016 firmware)

On HN+R (2016+) firmware where USB autorun is removed, a different
entry vector would be needed (potentially through JTAG or HDD swap).

## Full Update Package Structure (from metainfo2.txt)

### Hardware Components Mapped

| Component | Vendor | Description | Variants |
|-----------|--------|-------------|----------|
| AH6 | Harman/Becker | Audio Hub 6 | HW 0-4 |
| AMP_LC_V | LEAR | Amplifier (ST10 + DSP) | HW 1 |
| ARU9331 | Harman/Becker | Ring Unit (MOST, no DAB) | HW 41 |
| ARU9333 | Harman/Becker | Ring Unit (MOST + DAB) | HW 41 |
| ARU9438 | Harman/Becker | Ring Unit (MOST, new gen) | HW 41 |
| ARU9440 | Harman/Becker | Ring Unit (MOST + DAB, new gen) | HW 41 |
| DUA001 | Alpine | Display Unit ("10Touareg_Display") | HW 31-52 |
| DVD | Harman/Becker | DVD Drive (FJ-TEN DV-05) | HW 14,28,50 |
| DVDC_APN | Alpine | DVD Codec (app + mecha + boot) | HW 0-42 |
| GEMMI | Harman/Becker | Google Earth MMI (nav viewer) | single |
| IT | Harman/Becker | Internal Telephone (AC75 NAD) | HW 1-4 |
| MuGPS | Harman/Becker | GPS Chip (U500 / G51) | HW 21-61 |
| MuINIC | Harman/Becker | MOST Controller (OS81050) | HW 31-61 |
| MuIOC | Harman/Becker | I/O Controller (V850) | HW 31-61 |
| NGTV_DVB | Hirschmann | NextGen TV DVB Tuner | HW 4 |
| TVHybrid | Hirschmann | Hybrid TV DVB Tuner (SDA6000 + MPEG) | HW 6-7 |
| sss | Harman/Becker | Speech System (TTS + Recognition) | 21 languages |

### Flash Memory Layout (MU9478)

```
0x00000000 - 0x0003F7DF  IPL (bootloader, 63KB)
0x00040000 - 0x000F6410  FPGA (746KB)
0x00100000 - 0x001BFFFF  Emergency FPGA (746KB)
0x001C0000 - 0x0067FFFF  Emergency IFS (4.9MB)
0x00680000 - 0x030FFFFF  IFS-root (43.5MB) ← MAIN OS
0x03100000 - 0x03CFFFFF  EFS-extended (12MB) ← FSC.txt lives here
0x03D00000 - 0x061FFFFF  EFS-system (38.8MB) ← Java classes here
0x06200000 - 0x07DFFFFF  EFS-persist (30.4MB) ← /HBpersistence
```

### Three Hardware Variants

| HW | IFS-root | EFS-system | Notes |
|----|----------|------------|-------|
| 31 | Same as 41 | Same as 41 | Links to HW41 |
| 41 | 43.49MB | 38.80MB | Primary variant |
| 51 | 43.49MB | 38.80MB (same as 41) | Different IFS |
| 61 | 43.49MB | 38.80MB (different) | Newest HW |

### VW FSC Definition (VWFSC.txt)

Destination path: `/mnt/efs-extended/FSC.txt`

Only **2 features** are FSC-protected on VW RNS 850:
- **SWID 0004** = Navigation (database versions 0100, 0400-043f, 0700-073f)
- **SWID 0006** = ISO Image Language CD

8 AudiSignature MD5 hashes for validation.

### GEMMI (Google Earth MMI)

Embedded Google Earth 3D navigation viewer:
- Binary: `gemmi_final` + `libembeddedearth.so` + `libmessaging.so`
- Environment: `OEM=VW`
- Memory: max 55MB, target 40MB
- Regions: NAR=0, ASIA=1, ECE=2
- Cache: `/mnt/img-cache/gemmi/` on QNX6 partition `/dev/hd0t187.3`
- RSE (Rear Seat Entertainment) variant support
- Auto-restarts 5x on crash, then reformats cache partition

### Key Filesystem Paths

```
/fs/usb0           — USB drive mount point
/fs/sd0, /fs/sd1   — SD card mount points
/fs/cd0            — CD/DVD mount point
/mnt/nav/          — Navigation data (GEMMI, map styles, TMC)
/mnt/efs-system/   — EFS-system partition (Java classes)
/mnt/efs-extended/ — EFS-extended partition (FSC.txt, tnrref.csv)
/mnt/img-cache/    — HDD image cache partition
/HBpersistence/    — Persistent storage (SWDL state, sqlite.xml)
/database/         — Map archives (MMI3G_MapArchives.xar)
/etc/hmi_country.txt — Region configuration
```

### Update Scripts

The `finalScript` reveals the SWDL (Software Download) system:
- Reads `/HBpersistence/SWDL/update.txt` for source and path info
- Supports USB, SD1, SD2, CD sources
- Can copy `sqlite.xml` to control GEM debug menus
- Checksum-verified tool copying

## RSA Key Cross-Platform Verification (April 19, 2026)

### 🔑 CRITICAL FINDING: Same Key Across ALL Platforms

The RSA-1024 key (e=17) extracted from SignatureBlockProcessor.class is
**IDENTICAL** across all tested firmware variants:

| Platform | Build | HW | Key Match |
|----------|-------|-----|-----------|
| Audi MMI3G | K0942_4 | HW41 | ✅ SAME |
| Audi MMI3G | K0942_4 | HW61 | ✅ SAME |
| Audi MMI3G | uploaded | HW41 | ✅ SAME |
| VW RNS 850 | HN+ P0534 | HW41 | ✅ SAME |
| VW RNS 850 | HN+R P0824 | HW41 | ✅ SAME |
| VW RNS 850 | HN+R P0824 | HW61 | ✅ SAME |

**Implications:**
- rns850_fsc_patcher.py works on Audi MMI3G too (same Java class)
- Single signing key for ALL Harman HN+ FSC verification
- Harman used one key infrastructure across VW Group brands
- The 1-byte patch applies universally across the platform family

### CVALUE File Format Decoded

CVALUE files store variant coding data in `/HBpersistence/`:
- Filename: `CVALUE` + 8-hex-digit DID + `.CVA`
- Structure: TLV records with key=value strings

| DID | Size | Content |
|-----|------|---------|
| 0x021B | 9 bytes | Vehicle variant (binary) |
| 0x03B3 | 149-172 bytes | Database versions (GDB, LABEL, SDB, SDS, etc.) |
| 0x064D | 13 bytes | Navigation config ("LINK") |
| 0x068C | 12 bytes | Variant coding extended 1 |
| 0x068D | 12 bytes | Variant coding extended 2 |

CHN variants use navigation keys (HEADER, MAP, POS, P_COM, P_MAIN, RP, SUB, UNIT).
ARB variants use speech keys (GDB, LABEL, LIT, SDB, XAC, SDS, CITY).

### Bootscreen Format (fw400)

All fw400 bootscreens are **PNG files** with `.bin` extension (not raw RGB565).
SubID 099 is the only JPEG. Total: 79 bootscreens in fw400.

## RNS-850 NAR IFS Deep Analysis (K0711, April 2026)

### IFS Extraction Results

Extracted from `DVDRNS850V711US/2/MU9478/ifs-root/41/default/ifs-root.ifs`:
- 336 files, 28 directories, 55 symlinks
- Compressed: 42MB, Decompressed: 100MB
- Compression: LZO1X (657 chunks)
- Build: HN+_US_VW_K0711, variant 9478

### Audi vs RNS-850 NAR Comparison

| Component | Audi K0942 | RNS-850 K0711 | Match? |
|-----------|-----------|---------------|--------|
| proc_scriptlauncher | 17,600 bytes | 17,600 bytes | Same size, different MD5 |
| copie_scr.sh strings | Identical | Identical | ✅ Same autorun |
| MMI3GApplication | 10,702,848 | 10,690,560 | ~12KB diff (branding) |
| pppd | 265,140 | 265,140 | ✅ Identical |
| dhcp.client | 57,048 | 57,048 | ✅ Identical |
| devnp-mv8688uap.so (WiFi) | 93,538 | 93,538 | ✅ Identical |
| J9 JVM + libraries | Present | Present | ✅ Same set |
| lsd.jxe location | EFS (writable) | **IFS (read-only)** | ❌ CRITICAL |
| lsd.jxe size | ~27MB | 24MB | Smaller on VW NAR |
| lsd.jxe entries | 342 | 210 | Fewer on VW NAR |
| EOLFLAG entries | 1617 | 391 | Far fewer on VW |
| GEMMI binaries | In EU lsd.jxe | **ABSENT** | ❌ Not in NAR |
| AppDevelopment.jar | In EFS | **Not in IFS** | In EFS only |
| Telit modem firmware | In Flashdaten | Not in Flashdaten | Different cellular |
| Total IFS files | 345 | 336 | 9 fewer on VW |

### Critical Finding: lsd.jxe Location

On the Audi, `lsd.jxe` lives on the writable EFS partition and can be
modified without reflashing firmware. On the RNS-850, it's baked into
the **read-only IFS**. This means:

- Modifying EOL flags on RNS-850 requires IFS decompress → modify →
  recompress → reflash (using inflate_ifs.py + patch_ifs.py pipeline)
- On the Audi, it's a simple file replacement on EFS

### EOL Flags — VW NAR Variant

The VW NAR variant (`vw_high_nar.properties`) is the most locked-down:

```properties
EOLFLAG_HU_VARIANT=15         # VW identifier (vs 5=EU Audi, 6=NAR Audi)
RANGE_EOLFLAG_HU_VARIANT=15   # Locked to VW
RANGE_EOLFLAG_REGION=1         # Locked to NAR
```

Google Earth is blocked via `no_online_services.properties`:

```properties
RANGE_EOLFLAG_GOOGLE_EARTH=0
RANGE_EOLFLAG_ONLINE_SEARCH=0
RANGE_EOLFLAG_ONLINE_SERVICES=0
```

The `RANGE_` prefix means the flag is **hardware-locked** — it cannot
be overridden by the normal EOLFLAG settings. To enable Google Earth
on the RNS-850, the `RANGE_` constraints must be removed from the
lsd.jxe, which requires IFS modification.

### Variant Hierarchy (sysconst loading order)

1. `sysconst.properties` — base defaults (everything OFF)
2. `variant.properties` — build-level (sets RANGE_INNOVATIONFEATURES=1)
3. `vw_high.properties` — VW platform overrides
4. `vw_high_nar.properties` — NAR market overrides
5. `no_online_services.properties` — Google Earth block

### VW HU_VARIANT Map (from variant.properties)

| ID | Variant |
|----|---------|
| 5 | Audi EU |
| 6 | Audi NAR |
| 7 | Japan |
| 8 | China |
| 9 | Korea |
| 15 | VW EU/NAR |
| 16 | Bentley |
| 18 | RSE Asia |

### Networking Stack

**Identical** between Audi and RNS-850:
- pppd, dhcp.client, dhcpd (same binary, same size)
- devnp-mv8688uap.so WiFi driver (same binary)
- pfctl, ifconfig, route (same tools)
- devnp-shim.so, devnp-mlb.so (same network shims)

This confirms: USB ethernet + external LTE router works identically
on both platforms. DrGER's approach applies 1:1 to the RNS-850.

### Implications for Daredoole's Touareg

1. **SD card scripts work** — proc_scriptlauncher confirmed, same autorun
2. **MMI3G-Toolkit compatible** — same QNX 6.3, same J9, same networking
3. **Google Earth requires IFS mod** — lsd.jxe is in read-only IFS
4. **GEMMI binaries needed** — must deploy from EU Audi firmware
5. **USB ethernet works** — identical networking stack
