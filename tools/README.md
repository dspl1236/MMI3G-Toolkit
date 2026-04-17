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

