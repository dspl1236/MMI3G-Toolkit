# MMI3G/MMI3G+ firmware update format and verification

Harman's SWDL (SoftWare DownLoader) is the subsystem responsible for
applying firmware updates to an MMI3G head unit. This document specifies
the on-media file format, the verification mechanism, the update flow,
and the relationship between the various integrity mechanisms present
in the system.

**Headline finding:** firmware images are NOT cryptographically signed.
All integrity checks are CRC32 (zlib/IEEE polynomial), and Harman's own
update scripts include a first-class `skipCrc = true` bypass flag.

See also:
- `tools/mu_crc_patcher.py` — recomputes or bypasses CRCs on modified images
- `research/IFS_FORMAT.md` — the QNX IFS format (content inside ifs-root.ifs)
- `research/F3S_FORMAT.md` — the EFS filesystem (content inside efs-system.efs)

## Overview of an MU archive

A Media Update (MU) ships as a `.rar` or `.tar` archive with a
consistent directory structure. Taking `8R0906961FE` (HN+_US_AU3G_K0942_6
for MU9498) as the reference:

```
8R0906961FE/
├── finalScript                       # ksh: runs AFTER successful flash
├── metainfo2.txt                     # authoritative update manifest
├── MU9498/                           # the main unit payload
│   ├── preUpdateScript               # ksh: runs BEFORE flash begins
│   ├── postUpdateScript              # ksh: runs AFTER each component
│   ├── efs-extended/<variant>/default/efs-extended.efs
│   ├── efs-system/<variant>/default/efs-system.efs
│   ├── fpga/<variant>/default/SystemFPGA.hbbin
│   ├── fpga-emg/<variant>/default/SystemFPGA.hbbin
│   ├── ifs-emg/<variant>/default/ifs-emg.ifs
│   ├── ifs-root/<variant>/default/ifs-root.ifs
│   └── tools/                        # QNX binaries referenced by the scripts
│       ├── reboot                    # forces target reboot
│       ├── sqlite3                   # GEM dashboard support
│       ├── phonePersistenceConverter # migrates phonebook across FW versions
│       ├── rw_SWTrain                # writes SW train identifier
│       └── showScreen                # draws PNG to display during update
├── GEMMI/                            # Google Earth MMI payload
│   ├── preUpdateScript
│   ├── postUpdateScript
│   └── nav/                          # 26 MB GEMMI nav data
├── MU...MuGPS / MuIOC / MuINIC       # sub-component firmware
│   └── Main/<variant>/default/*.bin
├── AudiSupportedFscs/                # list of FSCs this release recognizes
├── TMCConfig/
│   ├── TMCConfig.dat
│   └── TMCConfig.dat.sig             # ONLY cryptographic signature in the MU
├── DVD / KBD_FB8 / AMP_LC_P / ...    # peripheral firmware for DVD, keyboard,
│                                     # amplifier, etc — each with its own
│                                     # <variant>/default/ subtree
└── sss/ Telit/ IDC_APN/ BoseG3_Q7/   # speech, UMTS modem, iPod adapter, Bose
```

The `<variant>` directories are hardware sample codes (`31`=C1, `41`=D1,
`51`=E1, `61`=F1, `62`=F2, etc). Each hardware sample may take different
firmware; links in metainfo2.txt often let multiple variants share one
file.

## `metainfo2.txt` format

`metainfo2.txt` is an INI-like manifest with CRLF line endings. Example
entry for `ifs-root.ifs`:

```ini
[MU9498\ifs-root\61\default\Application]
FileName = "ifs-root.ifs"
FileSize = "43742840"
CheckSum = "e298f61e"       ; block 0 (bytes 0 .. 524287)
CheckSum1 = "821077fd"      ; block 1 (bytes 524288 .. 1048575)
CheckSum2 = "7c5a4b2e"      ; block 2
...
CheckSum83 = "901ac015"     ; block 83 (last block, partial)
Version = "2145"
InstalledComponent = "sds"
InstalledVersion = "21.0.0"
InstalledComponent = "pssbss"
InstalledVersion = "3.0.0"
InstalledComponent = "gemmi"
InstalledVersion = "2.0.0"
AppName = "ifs-root image"
FlashStartAddress = "0x00680000"
```

### Section naming

Sections are headed `[Device\SubComponent\Variant\Profile\Kind]` using
literal backslashes (not forward slashes). Device is `MU9498`, `MuIOC`,
`AudiSupportedFscs`, etc. Variant identifies the hardware sample the
payload targets. Profile is usually `default`. Kind is typically
`Application` (main firmware) or `Bootloader`.

A `Link = "[other-section]"` directive inside a section means "use the
same file and checksums as the referenced section." This is how e.g. the
variant-41 and variant-51 entries share one ifs-root binary.

### Field reference

| Field | Type | Purpose |
|---|---|---|
| `FileName` | string | Path to the payload, relative to the section directory |
| `FileSize` | decimal | Size of the file in bytes |
| `CheckSum` | hex | CRC32 of the first 512 KB of the file |
| `CheckSum1..N` | hex | CRC32 of each subsequent 512 KB block |
| `Version` | decimal | Component version number |
| `FlashStartAddress` | hex | NOR flash target offset for this component |
| `AppName` | string | Human-readable component name |
| `InstalledComponent` | string | (repeating) bundled sub-component name |
| `InstalledVersion` | string | (repeating) bundled sub-component version |
| `Source` | string | Source path within the MU (for Dir entries) |
| `Destination` | string | Target path on device (for Dir/File entries) |
| `IsDestinationInFFS` | bool | True if target is in flash filesystem |
| `UpdateOnlyExisting` | bool | Skip if file doesn't already exist |
| `DeleteDestinationDirBeforeCopy` | bool | Wipe target dir first |
| `CheckType` | enum | `CRC32_CheckReadData`, `CRC32_CheckWrittenData`, or `skip` |
| `CheckPoint` | decimal | Progress checkpoint interval (bytes, usually 2097152) |
| `CheckSumSize` | decimal | Bytes per CRC block (always 524288 = 512 KB in practice) |
| `UseForUnit` | enum | `MU and RSU`, `MU only`, `RSU only` |
| `CompatibilityVersion` | string | Format-version marker |

### Top-level keys in `[common]`

```ini
[common]
release = "HN+_US_AU3G_K0942_6"
vendor = "HBAS"
variant = "9498"
region = "USA"
finalScript = "./finalScript"
finalScriptName = "FinalScript"
finalScriptCRC = "11f6fe6a"
finalScriptMaxTime = "25"
delMmeBackups = "true"
skipEraseOrphanedImageHeaders = "true"
MetafileChecksum = "2c4174d"        ; K0942_6+ only; CRC32 of the whole
                                    ; metainfo2.txt with this line removed
```

`finalScriptCRC` is the CRC32 of the `finalScript` file. If you modify
the finalScript, update this value. `MetafileChecksum` is the CRC32 of
the entire metainfo2.txt with the MetafileChecksum line itself removed —
older firmware (K0942_3, K0942_4, and earlier) does not carry this
field.

## The CRC algorithm

Empirically verified against MU9411 K0942_4 variant 41 `ifs-root.ifs`
(all 10 tested block CRCs match exactly, and the tool's round-trip test
produces byte-identical output):

- **Algorithm:** CRC32, polynomial 0xEDB88320 (reflected), initial
  value 0xFFFFFFFF, final XOR 0xFFFFFFFF
- **Equivalent to:** `zlib.crc32(data)`, `binascii.crc32(data)`,
  Python's standard CRC32 — the IEEE 802.3 CRC32 that ZIP files use
- **NOT** the POSIX `cksum` algorithm (which uses polynomial 0x04C11DB7
  non-reflected and appends the length)
- **Block size:** 512 KB (0x80000 bytes), except the last block which
  is whatever remains
- **Encoding in manifest:** lowercase hex, variable-width, no `0x`
  prefix, no leading zero padding (so `0x00821077` appears as `821077`)

Harman's own `finalScript` uses a different algorithm — `cksum -q` —
to verify smaller tool binaries like `sqlite.xml`, `reboot`, and
`showScreen`. That's POSIX cksum and produces values like `2566838270`
(decimal). The two algorithms are separate and apply to different
files:

| Target | Algorithm | Where recorded |
|---|---|---|
| Firmware partitions (metainfo2) | zlib/IEEE CRC32 | `metainfo2.txt` hex values |
| Small tools in `finalScript` | POSIX cksum | Shell variables inside the script |
| The `finalScript` itself | zlib/IEEE CRC32 | `finalScriptCRC` in metainfo2 |
| Pre/postUpdateScripts | zlib/IEEE CRC32 | `scriptPreCRC` / `scriptPostCRC` |

## Update flow

The MU archive goes on an SD card or DVD. The user initiates an update
through the MMI service menu or a dealer with ODIS issues the command.
Roughly:

```
                            power on / update triggered
                                       │
                                       ▼
                       proc_scriptlauncher detects media
                                       │
                                       ▼
                         SWDL reads update.txt from
                         /HBpersistence/SWDL/update.txt
                         (this is the runtime manifest,
                          distinct from metainfo2.txt)
                                       │
                                       ▼
                         finalScriptMaxTime clock starts
                                       │
                                       ▼
                       /HBpersistence/SWDL/update.txt
                       (marks update in progress; blocks
                        mmi3g-flashctl reclaim)
                                       │
                                       ▼
                         preUpdateScript runs
                         (per-component, from MU9498/
                          preUpdateScript etc)
                                       │
                                       ▼
                         For each component section:
                           1. Read payload from media
                           2. For each 512KB block:
                              - Compute CRC32
                              - Compare to CheckSum{i}
                              - If mismatch: fail OR proceed
                                (depending on skipCrc flag)
                           3. Erase target flash region
                           4. Write bytes to FlashStartAddress
                           5. Read back + CRC32 verify
                           6. On failure: retry or abort
                                       │
                                       ▼
                         postUpdateScript runs
                                       │
                                       ▼
                         finalScript runs (the ./finalScript
                         at the top of the MU archive,
                         not component-specific)
                                       │
                                       ▼
                         Clear /HBpersistence/SWDL/update.txt
                                       │
                                       ▼
                         Reboot into new firmware
```

The CRC verification happens in two places: (1) before write, as a
sanity check on the source data; (2) after write, to confirm the flash
operation succeeded. Both use the same per-512KB CRC32 values.

## Flash partition layout

From the `[MU9498\ImageLayout\...]` sections of metainfo2.txt, the NOR
flash is laid out:

```
offset        size          contains
------        ----          --------
0x00000000    63,264        ipl          (initial program loader)
0x00040000    746,512       fpga         (Xilinx FPGA bitstream)
0x00100000    746,480       fpga-emg     (emergency FPGA bitstream)
0x001C0000    4,904,808     ifs-emg      (emergency QNX IFS)
0x00680000    43,742,840    ifs-root     (main QNX IFS — boot target)
0x03100000    12,582,912    efs-extended (extended config EFS)
0x03D00000    38,797,312    efs-system   (main system EFS)
0x06200000    30,408,704    efs-persist  (persistent data EFS)
```

Total NOR flash: ~135 MB. A custom ifs-root.ifs must fit within the
43.74 MB envelope at offset 0x00680000. Oversized images will be
rejected by the flasher (and in any case won't fit in the flash).

The `ImageLayout` sections are metadata — they describe where each
component lives, not where the update gets SOURCED from. During a flash,
the `FlashStartAddress` field in each component's Application section
overrides this.

## The `skipCrc = true` bypass

The preUpdateScript for MU9498 contains:

```bash
echo 's/^CRC\ \=\ .*/skipCrc\ \=\ true/g' > /tmp/sed_scr
...
sed -f /tmp/sed_scr $UPDATE_TXT > /HBpersistence/SWDL/update_patched.txt
cp -V /HBpersistence/SWDL/update_patched.txt /HBpersistence/SWDL/update.txt
```

This is Harman's own code. It runs during hardware-sample detection
mismatches (e.g. when the MU carries firmware for F-sample hardware but
the unit detects as E-sample). The sed expression rewrites every
`CRC = xxx` line in `update.txt` as `skipCrc = true`.

**The SWDL flasher honors `skipCrc = true` as a designed, first-class
flag.** When present on a section entry, the flasher writes bytes
without CRC verification.

Implication: anyone modifying firmware can use the same pattern to ship
modified content without recomputing CRCs. `tools/mu_crc_patcher.py`
supports this via `--skip-crc` mode:

```
python3 mu_crc_patcher.py --update-txt update.txt --skip-crc \
    --output update_patched.txt
```

### Does this bypass ALL integrity checks?

No. Three layers exist:

1. **SWDL CRC verification (bypassable).** The per-512KB CRC32 checks
   described above. Disabled by `skipCrc = true`.
2. **QNX LZO decompression at boot (not bypassable).** After flash,
   `procnto-instr` at startup decompresses `ifs-root.ifs` in RAM. If
   the LZO stream is malformed, the kernel panics and the unit fails
   to boot. This is an integrity check in the sense that a corrupted
   IFS is fatal, but it's not designed as an attacker defense — any
   valid LZO stream is accepted.
3. **mmi3g-flashctl's write-protection (not a firmware integrity
   check).** The `/tmp/disableReclaim` and
   `/HBpersistence/SWDL/update.txt` flags prevent the F3S garbage
   collector from running during a critical-section write. They don't
   verify anything about the content.

There is no signature verification, no attested boot, no read-only
crypto anchor, no TPM-backed measurement. An attacker with an SD card
that auto-triggers SWDL can flash any bytes to any flash region the
target supports.

## The real signed artifacts

Three types of cryptographically signed data exist on an MMI3G system,
NONE of which protect the firmware itself:

### 1. FSC files (Freischaltcode = "activation code")

Location: `/mnt/efs-persist/FSC/*.fsc`

Audi-signed activation codes that unlock specific features or
navigation database releases. Standard code naming:

```
0004000A.fsc   nav DB activation for release 4.x
00040009.fsc   nav DB activation for release 3.x
```

The signature check is enforced by `vdev-logvolmgr` — it mounts the
nav HDD's logical volume only if a matching FSC file validates. The
community "nav unblocker" tools (Keldo 2014, DrGER2 GitHub, our own
`nav-unblocker` module) do NOT crack the signature; they kill
`vdev-logvolmgr` in a race window just after it creates
`/mnt/lvm/acios_db.ini` and before it enforces the FSC check:

```bash
(waitfor /mnt/lvm/acios_db.ini 180 && sleep 10 && slay vdev-logvolmgr) &
```

If the FSC file has already been marked invalid, the system moves it to
`/mnt/efs-persist/FSC/illegal/signature/`. The preUpdateScript's
`restore_fsc()` function shows how to recover (just move the file back
to its original location) — useful context for field recovery but not
an attack on the crypto.

### 2. TMCConfig.dat.sig

Location: `/mnt/nav/tmc/TMCConfig.dat.sig`, exactly 128 bytes.

128 bytes = 1024 bits, consistent with an RSA-1024 signature over the
TMCConfig.dat file (traffic message channel configuration). The
signature protects only this one file — critically, the SWDL process
that INSTALLS the .sig alongside the .dat doesn't verify the signature
itself, so a modified pair where both files are swapped for alternatives
would install without complaint. Whether the TMC subsystem verifies at
runtime is an open question.

### 3. Dealer/ODIS SVM signatures

When a dealer executes SVM (Software Version Management) actions with
ODIS, Audi's backend issues a signed challenge/response that ODIS
forwards to the MMI. These are session-scoped, not persisted to flash,
and not relevant to firmware modification.

## Implications for the toolkit

1. **Firmware modification is gated on content validity, not
   signatures.** If your modified `ifs-root.ifs` decompresses correctly
   (valid Harman-format LZO stream) and boots correctly (valid
   `/proc/boot/.script`, valid `procnto-instr`, correct QNX
   environment), it will run. The flasher won't reject it for
   cryptographic reasons.

2. **The two-step pass hack is built in.** Using `skipCrc = true` on
   the update.txt doesn't require cracking anything. `tools/mu_crc_patcher.py
   --skip-crc` produces the patched file automatically.

3. **Recomputing CRCs is trivial.** For a cleaner result where the
   metainfo2.txt looks legitimate, `tools/mu_crc_patcher.py` without
   `--skip-crc` recomputes all per-block CRCs and optionally the
   MetafileChecksum.

4. **The real technical challenge is IFS repacking, not signing.**
   Generating a bit-identical-format LZO-compressed ifs-root.ifs that
   the QNX loader accepts requires matching Harman's exact chunk
   sizing and algorithm parameters. `tools/inflate_ifs.py` handles
   the decompression direction; a repacker is future work.

5. **Runtime mods don't need any of this.** The toolkit's 15 modules
   do their work at runtime via SD-script + efs-system edits + OSGi
   bundle replacement. None of them touch the SWDL flash path, so
   none are affected by update verification.

## Tool reference

`tools/mu_crc_patcher.py` — two modes:

**Mode A: recompute CRCs after modifying a firmware image**
```
python3 tools/mu_crc_patcher.py \
    --metainfo path/to/metainfo2.txt \
    --file     path/to/modified/ifs-root.ifs \
    --section  'MU9411\ifs-root\41\default\Application' \
    [--update-metafile-checksum]       # K0942_6+ firmware only
    [--dry-run]                        # show changes without writing
```

**Mode B: generate a skipCrc=true patched update.txt**
```
python3 tools/mu_crc_patcher.py \
    --update-txt path/to/update.txt \
    --skip-crc \
    --output     path/to/update_patched.txt
```

Both modes preserve CRLF line endings, section ordering, and comments.
The tool has been round-trip tested against K0942_4 MU9411 variant 41
`ifs-root.ifs` — patching the unmodified file produces a byte-identical
metainfo2.txt.

## References

- `D:\MMI\MMI 3GP\HN+R_EU_AU_K0942_4_[8R0906961FB]\metainfo2.txt` — reference manifest
- `D:\MMI\MMI 3GP\8R0906961FE\MU9498\preUpdateScript` — source of the `skipCrc` pattern
- `D:\MMI\MMI 3GP\8R0906961FE\finalScript` — `cksum`-based tool verification
- `D:\MMI\MMI 3GP\8R0906961FE\8R0906961FE\metainfo2.txt` — K0942_6 example with `MetafileChecksum`
- `_MMI3G+_ACT.zip` in the same directory — reference FSC-check race
  bypass (nav DB unblocker from 2014-2016 era)
