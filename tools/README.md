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

```
# Decompress only
python3 tools/inflate_ifs.py ifs-root.ifs -o ifs-root.decomp

# Decompress and extract to a directory (chains through extract_qnx_ifs.py)
python3 tools/inflate_ifs.py ifs-root.ifs --extract outdir/
```

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
