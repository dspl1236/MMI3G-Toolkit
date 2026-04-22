# Internal development tools

These scripts are used by maintainers during audits. They are not
user-facing and not shipped in the built SD card.

## retrofit.py

Applies the platform.sh source block + `$(mmi_logstamp)` substitution to
module scripts. Used during the DrGER2-review audit pass (see commit
history). Idempotent — running it against an already-retrofitted script
is a no-op.

Usage:
```
python3 tools/retrofit.py
```

## walk_f3s_efs.py

Scans an MMI3G `efs-system.efs` image and lists the filesystem contents.
Works on uncompressed variants (variant 41 / 51 — MMI 3G non-Plus and the
Basic/High tiers of MMI 3G+). Does **not** handle compressed variant 61.

Usage:
```
python3 tools/walk_f3s_efs.py /path/to/efs-system.efs
python3 tools/walk_f3s_efs.py efs-system.efs --filter dsi
python3 tools/walk_f3s_efs.py efs-system.efs --format detailed
```

Verified against MU9308 (K0133), MU9411 (K0942_3 and K0942_4), MU9498
(K0942_6).

## extract_f3s_efs.py

Extracts all regular files from an uncompressed MMI3G EFS image into a
flat output directory. Directory structure is discarded (we recover
names but not the full tree yet). Use `--list` to preview, `--only
<substr>` to filter.

```
python3 tools/extract_f3s_efs.py efs-system.efs ./extracted/
python3 tools/extract_f3s_efs.py efs-system.efs ./out --only .jar
python3 tools/extract_f3s_efs.py efs-system.efs --list | head -30
```

**Caveat:** content-boundary detection is heuristic. JARs in the EFS
extract with good central directories but some internal entries
produce CRC errors because our heuristic grabs slightly off byte
ranges. Small binaries come out wrapped in the `iwlyfmbp` container;
pass them through `tools/inflate_qnx.py` to recover real ELF content.

## extract_jars_from_efs.py

Older single-purpose tool. Scans an EFS for `PK\x05\x06` markers and
extracts embedded ZIP archives using their own central directory
offsets. Useful when `extract_f3s_efs.py`'s boundary heuristic
produces damaged JARs.

## verify_stubs_vs_dsi.py

Compares our hand-written DSI interface stubs in `modules/per3-reader/src/stubs/`
against method signatures extracted via `javap` from a real `dsi.jar` or
`DSITracer.jar`. Run after extracting a JAR to verify that the stubs we
compiled against match the ground-truth interfaces.

## inflate_qnx.py  +  qnx_inflator.c

Decompresses files wrapped in the QNX `deflate` utility format (8-byte
magic `iwlyfmbp`). QNX's `deflate` is a separate tool from zlib's deflate
— it packages data as a chain of LZO1X or UCL NRV2B compressed blocks
with an `iwlyfmbp` file header. Harman-Becker uses this to compress
binaries stored in MMI3G firmware.

The Python wrapper shells out to a tiny C program because UCL NRV2B has
no reliable Python binding. The C source (`qnx_inflator.c`, ~60 lines)
is built automatically on first run — requires `liblzo2-dev` and
`libucl-dev` plus `minilzo.c` (auto-fetched from oberhumer.com on first
run, ~63 KB). After that the binary is cached.

```
# Single file
python3 tools/inflate_qnx.py file.bin file.inflated

# Walk a directory, inflate every iwlyfmbp-wrapped file next to the
# original with a .inflated suffix
python3 tools/inflate_qnx.py --recurse /path/to/extracted/

# As above but replace in-place
python3 tools/inflate_qnx.py --recurse --inplace /path/to/extracted/
```

Verified against MU9411 K0942_4 variant 41: 14/17 wrapped binaries
inflate cleanly (the three failures are upstream `extract_f3s_efs.py`
boundary issues, not inflator issues).

## extract_qnx_ifs.py

Walks the dirent chain of a (already-decompressed) QNX IFS image
and extracts files to a directory with their full path preserved.
Supports regular files, directories, symlinks, and device nodes.

For **compressed** IFS images (the common case for MMI3G), pipe
through `inflate_ifs.py` first — or just use `inflate_ifs.py`'s
built-in `--extract` mode which does both steps.

## inflate_ifs.py  +  qnx_ifs_decompress.c

Decompresses QNX IFS images that are LZO1X- or UCL-NRV2B-compressed
at the container level. MMI3G's `ifs-root.ifs` uses LZO; `ifs-emg.ifs`
uses UCL. Standard `dumpifs` crashes on Harman's LZO streams because
`lzo1x_decompress_safe` is too strict — we use the permissive
`lzo1x_decompress` variant (approach pioneered by unbe/mmi-ifs).

Format:
- Startup section (startup_header + code + trailer) covers bytes 0
  through `startup_size` — copied through verbatim
- From `startup_size` onwards: chain of `(u16 BE length, payload)`
  compressed chunks, each decompressing to ~64 KB
- Chunk length 0 marks end of stream
- Compression type is in `startup_header.flags1` bits 2-5 (2=LZO, 3=UCL)

The C decompressor (`qnx_ifs_decompress.c`, ~140 lines) is built
automatically on first use.

If local native deps are missing (`gcc`, `libucl-dev` / `libucl-devel`),
the script can re-run itself inside a disposable `podman` or `docker`
container. This is useful on fresh Fedora/macOS/Linux hosts where the
toolchain is not installed yet.

```
# Decompress only
python3 tools/inflate_ifs.py ifs-root.ifs -o ifs-root.decomp

# Decompress and extract to a directory (chains through extract_qnx_ifs.py)
python3 tools/inflate_ifs.py ifs-root.ifs --extract outdir/

# Force the disposable container path
python3 tools/inflate_ifs.py ifs-root.ifs --extract outdir/ --container
```

Container notes:
- `--container` forces the disposable runtime path even if local native deps exist
- without `--container`, the script auto-falls back to `podman` / `docker`
  when the local native build fails
- `--container-tool podman` or `--container-tool docker` pins the runtime
- `--container-image` overrides the default image (`debian:bookworm-slim`)
- on Fedora/SELinux hosts, the podman path disables label confinement for the
  disposable container so it can read the repo and temp bind mounts without
  relabeling host files

Verified on MU9411 K0942_4 variant 41:
- `ifs-root.ifs`: LZO, 671 chunks → 104 MB uncompressed, 345 files
  including `MMI3GApplication` (10.7 MB SH4 ELF), `MMI3GMedia`,
  `MMI3GNavigation`, `MMI3GMisc`, `MMI3GTelephone`, and `NavCore`
- `ifs-emg.ifs`: UCL, 161 files (emergency boot image)

## repack_ifs.py  +  qnx_ifs_compress.c

Recompresses a decompressed QNX IFS image back into the Harman
LZO-compressed format. This is the inverse of `inflate_ifs.py` and the
key tool that enables custom firmware: decompress, modify files, repack.

The compressor uses `lzo1x_999` (the optimal LZO compressor), which
produces **byte-identical output** to Harman's original encoder —
verified across all 671 chunks of MU9411 K0942_4 variant 41.

Two modes:

```
# Bit-identical recompression (for unmodified images or verification)
python3 tools/repack_ifs.py decompressed.ifs repacked.ifs \
    --reference original.ifs

# Modified-image recompression (fixed 60KB chunks, ~3% larger)
python3 tools/repack_ifs.py modified.ifs repacked.ifs
```

The `--reference` flag reads chunk boundaries from the original
compressed IFS and applies them to the new data, producing output
that is byte-for-byte identical when the content hasn't changed.
Without `--reference`, the tool splits the imagefs payload into
61,440-byte chunks (adjustable with `--chunk-size`).

After repacking, update the firmware manifest CRCs:

```
# Recompute CRCs for the modified image
python3 tools/mu_crc_patcher.py \
    --metainfo path/to/metainfo2.txt \
    --file repacked.ifs \
    --section 'MU9411\ifs-root\41\default\Application'

# Or bypass CRC checks entirely
python3 tools/mu_crc_patcher.py \
    --update-txt path/to/update.txt --skip-crc
```

The C source (`qnx_ifs_compress.c`, ~305 lines) is built automatically
on first run — requires `liblzo2-dev`.

### Full custom firmware pipeline

```
# 1. Decompress
python3 tools/inflate_ifs.py ifs-root.ifs --extract working/

# 2. Modify files in working/ (replace binaries, configs, scripts)

# 3. (Future: rebuild IFS directory structure from modified tree)

# 4. Recompress
python3 tools/repack_ifs.py modified_decompressed.ifs new_ifs-root.ifs

# 5. Fix CRCs
python3 tools/mu_crc_patcher.py --metainfo metainfo2.txt \
    --file new_ifs-root.ifs \
    --section 'MU9411\ifs-root\41\default\Application'

# 6. Flash via SD card SWDL or ODIS
```

Step 3 (rebuilding the IFS directory from a modified file tree) is
future work — currently you must edit the decompressed blob directly
or use binary patching. The QNX `mkxfs` source in OpenQNX provides
the reference implementation for IFS directory construction.

Verified: full decompress → recompress → decompress → extract
round-trip on MU9411 K0942_4 variant 41. All 345 files including
MMI3GApplication (10.7 MB), lsd.jxe (28 MB), and NavCore (6.8 MB)
survive bit-identical.

## rns850_fsc_patcher.py

**BouncyCastle FSC signature bypass for VW RNS 850 (Touareg / Phaeton)**

The RNS 850 uses Java BouncyCastle (de.audi.crypto.*) for FSC verification
instead of the native EscRsa used by Audi MMI3G. This tool patches the
`SignatureBlockProcessor.class` bytecode to skip hash verification.

**The Patch**: A single byte change at offset 0x1FE8 in the class file:
- `0xBB` (new — creates StringBuffer for error message)
- → `0xB1` (return void — skip verification entirely)

```bash
# Analyze (find patch point, no modification)
python3 tools/rns850_fsc_patcher.py efs-system.efs --analyze

# Extract and patch the class file
python3 tools/rns850_fsc_patcher.py efs-system.efs --extract-class -o /tmp/patch/
```

**Platform**: VW Touareg (7P), VW Phaeton — RNS 850 (HN+/HN+R)

**Key findings**:
- RSA-1024 key, public exponent = 17 (unusual)
- Verification: RSA→AES-CBC decrypt→SHA1/MD5 hash compare
- Only 2 FSC features: Navigation (SWID 0004) + ISO Language CD (SWID 0006)

## rns850_efs_patcher.py

**Full end-to-end EFS binary patch for FSC bypass** — the production-ready
version of `rns850_fsc_patcher.py`.

Applies the 1-byte BouncyCastle bypass DIRECTLY to an `efs-system.efs` file
as an in-place binary patch. No JAR extraction or repacking needed — just three
binary writes to the EFS:

1. Overwrite compressed class data (recompressed with patch applied)
2. Update CRC32 in ZIP local file header
3. Update CRC32 in ZIP central directory

The patched class (`verifyManifestAndSignatureFile` → immediate `return void`)
recompresses to the EXACT SAME SIZE as the original, enabling true in-place
patching with no structural changes to the EFS.

```bash
# Analyze (find patch points, no modification)
python3 tools/rns850_efs_patcher.py efs-system.efs --analyze

# Patch in-place (MODIFIES THE FILE — back up first!)
python3 tools/rns850_efs_patcher.py efs-system.efs --patch

# Patch to new file (safe)
python3 tools/rns850_efs_patcher.py efs-system.efs --patch --output efs-system-patched.efs

# Verify a previously patched EFS
python3 tools/rns850_efs_patcher.py efs-system.efs --verify
```

**Patch detail**: Byte 0x1FE8 in `SignatureBlockProcessor.class`:
`0xBB` (new — begins error path) → `0xB1` (return void — skip verification).

**Platform**: Audi MMI3G (MU9411) AND VW RNS 850 (MU9478) — same RSA key, same class.

## prepare_fsc_deploy.py

**Generate deployment files for car-side FSC bypass.**

Takes an `efs-system.efs` file and produces everything needed for
runtime deployment via SD card or USB:

1. `patch_offsets.txt` — Shell-sourceable offset file for `deploy_fsc_bypass.sh`
2. `patched_comp.bin` — Recompressed patched class data (ready to `dd` to flash)
3. `copie_scr.sh` — XOR-encoded autorun script (triggers on SD insert)
4. `deploy_fsc_bypass.sh` — Human-readable deployment script copy

```bash
python3 tools/prepare_fsc_deploy.py efs-system.efs --output /path/to/usb/
```

The output directory can be an SD card or USB drive root. Insert into the car,
and the patch deploys automatically via the MMI3G autorun mechanism.

## deploy_fsc_bypass.sh

**Car-side QNX deployment script for FSC bypass.**

Runs on the MMI3G/RNS-850 QNX system via `copie_scr.sh` autorun. Two modes:

- **Method A** (pre-computed): If `patch_offsets.txt` and `patched_comp.bin` are
  present (generated by `prepare_fsc_deploy.py`), applies three binary writes
  directly to the EFS flash partition. Creates backup of original bytes first.

- **Method B** (dump): If no offset files are found, dumps the EFS partition to
  the SD card for offline patching on a PC. Also collects system info (flash
  devices, mount points, interfaces) for debugging.

The script auto-detects the platform (Audi MMI3G vs VW RNS 850) and searches
for the correct flash device.

### FSC bypass deployment pipeline

```bash
# 1. Dump EFS from car (Method B — first run without offset files)
#    Insert SD card → script dumps /dev/fs0pN → efs-system-dump.efs on SD

# 2. Generate deployment files on PC
python3 tools/prepare_fsc_deploy.py efs-system-dump.efs --output /path/to/sd/

# 3. Deploy to car (Method A — second run with offset files)
#    Insert SD card → script applies patch → reboot
```

## build_ifs.py

**Construct a QNX IFS image from a directory tree.**

Takes an extracted file tree (output of `inflate_ifs.py --extract`) and builds
a new decompressed IFS image. Requires a reference IFS for the startup section
(architecture-specific SH4 boot code that can't be generated from scratch).

```bash
# Rebuild from extracted/modified tree
python3 tools/build_ifs.py \
    --reference ifs_decomp.ifs \
    --tree ./ifs_extracted/ \
    --output new_ifs_decomp.ifs

# Then compress and fix CRCs
python3 tools/repack_ifs.py new_ifs_decomp.ifs new_ifs-root.ifs
python3 tools/mu_crc_patcher.py ...
```

The reference IFS provides the startup section, `image_header` template,
and original dirent metadata. Files in the tree override originals; new files
are added; missing files are omitted. This enables adding, removing, and
replacing files in the firmware.

## patch_ifs.py

**Replace files inside a decompressed QNX IFS image.**

A simpler alternative to `build_ifs.py` when you only need to swap specific
files. Takes a decompressed IFS and produces a new one with specified files
replaced. Handles any file size change by rebuilding the file data section.

```bash
# Replace a single binary
python3 tools/patch_ifs.py ifs_decomp.ifs ifs_patched.ifs \
    --replace /usr/apps/MMI3GApplication=./modified_app

# Replace multiple files
python3 tools/patch_ifs.py ifs_decomp.ifs ifs_patched.ifs \
    --replace /usr/apps/MMI3GApplication=./mod_app \
    --replace /etc/mmi3g-srv-starter.cfg=./mod_cfg

# List all files (no modification)
python3 tools/patch_ifs.py ifs_decomp.ifs --list
```

After patching, compress with `repack_ifs.py` and fix CRCs with
`mu_crc_patcher.py`.

## mu_repack.py

**End-to-end firmware modification pipeline.**

Wraps the full workflow: extract MU archive → decompress IFS → let user modify
files → patch IFS → recompress → fix CRCs. Orchestrates `inflate_ifs.py`,
`patch_ifs.py`, `repack_ifs.py`, and `mu_crc_patcher.py` in sequence.

```bash
# Interactive: opens a working directory for editing
python3 tools/mu_repack.py \
    --mu-archive /path/to/8R0906961FB.tar \
    --variant 41 \
    --workdir ./work

# Non-interactive: apply patches directly
python3 tools/mu_repack.py \
    --mu-archive /path/to/8R0906961FB.tar \
    --variant 41 \
    --replace /usr/apps/MMI3GApplication=./modified_app \
    --output ./patched_MU/

# From pre-extracted firmware directory
python3 tools/mu_repack.py \
    --mu-dir /path/to/extracted/MU9411/ \
    --variant 41 \
    --replace /etc/mmi3g-srv-starter.cfg=./mod_cfg \
    --output ./patched_MU/
```

## eol_modifier.py

**Inspect variant/range overlays and modify EOL (End-of-Line) feature flags in `lsd.jxe`.**

EOL flags in `sysconst.properties` inside the `lsd.jxe` JAR control which
features are available on the MMI3G head unit. This tool can now:

- list base `sysconst.properties` EOL flags
- show the raw `variant.properties` selector and infer active variant layers
- list available `variants/*.properties` bundles with region / variant summaries
- diff two variant bundles
- show `RANGE_` constraints and effective values after overlaying variant bundles
- modify base `sysconst.properties` flags for patching workflows

This is particularly useful for Google Earth, market-gating, and other
cases where the same binary contains the feature code but variant overlays
or `RANGE_` constraints hide the UI.

```bash
# List all flags and their current state
python3 tools/eol_modifier.py /path/to/lsd.jxe --list

# Show variant selector + inferred active layers
python3 tools/eol_modifier.py /path/to/lsd.jxe --show-variant

# List available variant bundles
python3 tools/eol_modifier.py /path/to/lsd.jxe --list-variants

# Compare Audi NAR vs VW NAR overlays
python3 tools/eol_modifier.py /path/to/lsd.jxe \
    --diff-variants high_nav_nar vw_high_nar

# Inspect range locks / effective values for a chosen overlay stack
python3 tools/eol_modifier.py /path/to/lsd.jxe \
    --variant vw_high_nar \
    --variant no_online_services \
    --show-range-locks \
    --show-effective GOOGLE_EARTH \
    --show-effective INNOVATIONFEATURES

# Enable Google Earth
python3 tools/eol_modifier.py /path/to/lsd.jxe --output modified_lsd.jxe \
    --enable EOLFLAG_GOOGLE_EARTH

# Enable multiple features
python3 tools/eol_modifier.py /path/to/lsd.jxe --output modified_lsd.jxe \
    --enable EOLFLAG_GOOGLE_EARTH \
    --enable EOLFLAG_ONLINE_SERVICES \
    --enable EOLFLAG_INNOVATIONFEATURES

# Disable a feature
python3 tools/eol_modifier.py /path/to/lsd.jxe --output modified_lsd.jxe \
    --disable EOLFLAG_DEVICES_TV
```

After modifying `lsd.jxe`, deploy it via `patch_ifs.py`:
```bash
python3 tools/patch_ifs.py ifs_decomp.ifs ifs_patched.ifs \
    --replace lsd/lsd.jxe=modified_lsd.jxe
```

**Relevance to GEMMI/Google Earth restoration**: DrGER identified that NAR
RNS-850 units lack the Google Earth UI in `lsd.jxe`. The inspection mode
helps answer whether a feature is blocked by:

- base `sysconst.properties` defaults,
- the selected market / brand variant bundle,
- or a hard `RANGE_` constraint such as `RANGE_EOLFLAG_GOOGLE_EARTH=0`.

That makes `eol_modifier.py` useful as a read-only research tool even when
you are not ready to patch `lsd.jxe` yet.
