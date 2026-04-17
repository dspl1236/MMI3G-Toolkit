# MMI3G EFS Format Notes (QNX F3S)

Research notes on the MMI 3G / 3G+ `efs-system.efs` filesystem format. These notes
are what we needed to write `tools/walk_f3s_efs.py` and `tools/extract_f3s_efs.py`.

## Scope

Targets: `efs-system.efs` from Audi MMI 3G+ firmware MU9411 (K0942_3 / K0942_4),
MU9498 (K0942_6), and MU9308 (K0133 MMI 3G non-Plus).

Tested against four firmware releases:

- **MU9308** / 8R0906961CP (MMI 3G non-Plus, variant 41 only, 20 MB)
- **MU9411** / 8R0906961ES / K0942_3 (MMI 3G+, variants 41/51/61, 38 MB each)
- **MU9411** / 8R0906961FB / K0942_4 (MMI 3G+, variants 41/51/61, 38 MB each)
- **MU9498** / 8R0906961FE / K0942_6 (MMI 3G+, variants 41/51/61, 38 MB each)

## Container at a glance

Every `efs-system.efs` is a QNX F3S (Flash File System version 3) image with a
thin pre-header. There are two structural classes:

| Variant | QSSL_F3S offset | align_pow2 | Notes |
|---------|----------------|------------|-------|
| 41, 51 (Basic / High)  | 0x2c | 2 | **Uncompressed F3S**. Walkable. |
| 61 (Plus tier)         | 0xc4 | 6 | **Compressed F3S**. Not covered here. |

The tools in this repo handle the uncompressed variants. Variant 61 uses
per-block LZO/UCL compression managed by the F3S filesystem driver; use QNX's
own `inflator` and `dumpifs` (shipped with QNX 6.5 SP1 SDK) for those.

## Layout of the uncompressed variant

Little-endian throughout.

```
+0x00  unit_info_s   (16 bytes)   struct_size=16, endian='L' (0x4c), unit_pow2=18
                                  → logical units are 256 KB
+0x10  unit_logi_s   (24 bytes)   struct_size=24, md5[16]
+0x28  boot_info_s   (24 bytes)   "QSSL_F3S", unit_total, root extptr
+0x40  dirent stream starts here
```

### Fixed structures

```c
struct unit_info_s {           /* 16 bytes */
    uint16_t struct_size;      /* 16 */
    char     endian;           /* 'L' = 0x4c on MMI3G */
    uint8_t  pad;              /* 0xff */
    uint16_t unit_pow2;        /* 18 → 256 KB units */
    uint16_t reserve;
    uint32_t erase_count;
    struct { uint16_t logi_unit, index; } boot;
};

struct unit_logi_s {           /* 24 bytes */
    uint16_t struct_size;      /* 24 */
    uint16_t logi;
    uint32_t age;
    uint32_t md5[4];
};

struct boot_info_s {           /* 24 bytes */
    uint16_t struct_size;      /* 24 */
    uint8_t  rev_major;        /* 3 */
    uint8_t  rev_minor;        /* 0 */
    char     sig[8];           /* "QSSL_F3S" */
    uint16_t unit_index;
    uint16_t unit_total;       /* 80 for 3G non-Plus, 148 for 3G+ */
    uint16_t unit_spare;
    uint16_t align_pow2;       /* 2 for uncompressed, 6 for compressed */
    struct { uint16_t logi_unit, index; } root;   /* (1, 3) */
};
```

### Variable dirent records

Each directory entry lives in the image at a variable location, serialized as:

```
+0  struct_size:H     (always 8 for MMI3G - header size only)
+2  moves:B           (move counter, always 0 on fresh images)
+3  namelen:B         (1..128)
+4  first_unit:H      extent pointer → unit
+6  first_index:H     extent pointer → index within unit
+8  name[namelen]     padded to 4-byte alignment with 0x00 or 0xff
+?  stat_s (20 bytes) (placed immediately after padded name)
```

```c
struct stat_s {                /* 20 bytes, follows padded name */
    uint16_t struct_size;      /* 20 */
    uint16_t mode;             /* POSIX mode bits; high nibble = file type */
    uint32_t uid;
    uint32_t gid;
    uint32_t mtime;
    uint32_t ctime;
};
```

File types are determined by `(mode >> 12) & 0xf`:

| nibble | meaning |
|--------|---------|
| 0x4    | directory |
| 0x8    | regular file |
| 0xa    | symlink   |
| 0x1,2,6,c | fifo/chr/blk/sock (rare on MMI3G) |

Total dirent length = `8 + ((namelen + 3) & ~3) + 20` bytes.

### Scanning strategy

The dirent stream is not always contiguous — file content is interleaved between
dirents. The reliable approach is:

1. Scan the whole image for `14 00 XX YZ` patterns where `YZ & 0xf0 ∈ {0x40,
   0x80, 0xa0}` (candidate `stat_s` headers).
2. For each hit, walk back up to 140 bytes looking for `08 00 00 NL` where `NL`
   is a plausible namelen and the `(header + 8 + aligned_name) == stat_off`.
3. Validate the name is printable ASCII.

This is what `tools/walk_f3s_efs.py` and `tools/extract_f3s_efs.py` implement.

## Content encoding (the `iwlyfmbp` wrapper)

Regular binary files in the EFS are wrapped in the QNX **`deflate`
utility** container format. QNX's `deflate` is a file-level compression
tool (separate from zlib's deflate) that ships with the QNX Neutrino
SDK. Source: `openqnx/trunk/utils/d/deflate/deflate.c` in the leaked
QNX 6.4.1 tree.

```c
struct filehdr {                 /* 16 bytes, little-endian */
    char     signature[8];       /* "iwlyfmbp" */
    uint32_t usize;              /* total uncompressed size */
    uint16_t blksize;            /* 4/8/16/32 KB */
    uint8_t  cmptype;            /* 0 = LZO1X, 1 = UCL NRV2B */
    uint8_t  flags;              /* 0 in our samples */
};

struct cmphdr {                  /* 8 bytes per compressed block */
    uint16_t prev;               /* offset to previous hdr */
    uint16_t next;               /* offset to next hdr (0 = EOF) */
    uint16_t pusize;             /* uncompressed size of prev block */
    uint16_t usize;              /* uncompressed size of this block */
};
```

File layout: `filehdr` at offset 0, then a chain of `(cmphdr,
compressed_payload)` pairs. The `next` field points to the following
cmphdr by byte offset. A cmphdr with `next == 0` marks end of file.

Decompression per block uses:
- `lzo1x_decompress` (minilzo / liblzo2) for `cmptype == 0`
- `ucl_nrv2b_decompress_8` (libucl) for `cmptype == 1`

We observed `cmptype=1` (UCL NRV2B) on all 17 wrapped files in a
typical K0942_4 variant 41 EFS with blocks of 8 KB uncompressed.

`tools/qnx_inflator.c` implements the decompressor in ~60 lines of C;
`tools/inflate_qnx.py` wraps it for Python callers and auto-builds on
first use. Both are verified against real firmware output (14/17 of
our carved wrapped files inflate to valid SH4 ELF executables).

## Runtime mechanism: the `inflator` resource manager

On a running MMI3G, iwlyfmbp files are decompressed **transparently on
demand** by a QNX resource manager called `inflator`. It's one of the
earliest processes to start — typically PID 12292, right after
`procnto` (1) and `devf-generic`. The standard invocation from
`/proc/boot/.script`:

```
inflator /mnt/efs-system/bin /mnt/efs-extended
```

This publishes a decompressed overlay at `/mnt/efs-extended/` that
mirrors the compressed tree at `/mnt/efs-system/bin/`. When any
process opens `/mnt/efs-extended/chat`, the resource manager:

1. Intercepts the `open()` via `resmgr_attach` / `iofunc_open_default`
2. Reads the compressed `/mnt/efs-system/bin/chat` (iwlyfmbp wrapped)
3. Inflates on demand using the same LZO/UCL decoders we use offline
4. Returns a normal file descriptor to the decompressed stream

Key strings in the binary (`/mnt/ifs-root/sbin/inflator`, 22 KB):

```
NAME=inflator
DESCRIPTION=Compressed filesystem resource manager
DATE=2009/10/05-09:01:06-EDT
VERSION=630SP2-1640
STATE=experimental

Check for compressed file on %s
Opened compressed file %s
iwlyfmbp
```

This is why Harman can store binaries compressed (saving scarce flash
space on the NOR array) without any runtime code needing to know —
every shell script, every service binary, every library link just
opens `/mnt/efs-extended/<name>` and gets a normal file back.

**For toolkit work this means:**

- Shell scripts that need to read an iwlyfmbp-wrapped binary on a
  running system should use `/mnt/efs-extended/<name>` (decompressed
  view), not `/mnt/efs-system/bin/<name>` (raw compressed).
- Our `tools/qnx_inflator.c` implements the exact same algorithm this
  runtime resource manager uses — same openqnx source lineage.
- The inflator is standard QNX 6.3 (`VERSION=630SP2-1640`), not
  Harman-specific. Other QNX 6.3 products that ship a `deflate`d
  filesystem would have the same runtime setup.

## Write safety: the `/tmp/disableReclaim` interlock

The F3S flash filesystem periodically runs a **reclaim** (garbage
collection) pass that copies live blocks out of mostly-stale erase
blocks, erases those blocks, and frees the space. On MMI3G this is
driven by `mmi3g-flashctl` — a small ~9.7 KB utility that runs as
process #40 with args `-f /HBpersistence -r 4096 -t 2048 -p 100 -c 16 -s 300`
(loop every 5 min; reclaim 4 MB if free drops below 2 MB).

`mmi3g-flashctl` refuses to run a reclaim if either of these files
exists:

```
/HBpersistence/SWDL/update.txt     ← set during firmware update
/tmp/disableReclaim                ← user-settable lock
```

The error messages are literally `"disabled reclaim because a SWDL is
started"` and `"disabled reclaim, because persistence shutdown is
active"`.

**Toolkit convention:** any script that does multi-write operations
against `/HBpersistence` (or wants a stable snapshot for dumping)
should touch `/tmp/disableReclaim` first, do its work, then remove
the flag. This prevents `mmi3g-flashctl` from erase-cycling blocks
out from under you mid-operation:

```sh
touch /tmp/disableReclaim
# ... write adaptation files, install OSGi bundle, etc. ...
rm -f /tmp/disableReclaim
```

The flag also survives for as long as the script holds it — if the
script crashes mid-run, a reclaim could kick in before cleanup. Wrap
in a trap:

```sh
touch /tmp/disableReclaim
trap 'rm -f /tmp/disableReclaim' EXIT INT TERM
# ... critical-section work ...
```

Interaction with DCMD ioctls: `mmi3g-flashctl` uses
`DCMD_F3S_ARRAYINFO` and `DCMD_F3S_PARTINFO` against `/HBpersistence`
to query usage. Custom tools that want flash-health telemetry can
issue the same ioctls through `devctl()` on any F3S mount point.

### Embedded JARs in plaintext

JARs (`DSITracer.jar`, `AppDevelopment.jar`, HMI resource bundles, etc.)
are stored in the EFS as **raw PKZIP archives** — no `iwlyfmbp`
wrapper. The 5 JARs located via `PK\x05\x06` end-of-central-directory
scanning all validate as real ZIPs with proper central directories.
Individual entry CRC failures during extraction are artifacts of our
own `extract_f3s_efs.py` content-boundary heuristic, not the JAR
format itself.

## Upstream `jtang613/qnx_dumpers` corrections

If you're modifying `jtang613/qnx_dumpers` to work with MMI3G EFS files, the
following patches are required. We've verified them on our test data; they
should be filed as an upstream PR.

### 1. Off-by-one heap overflow in `read_dirent()`

```c
/* efsdump.c — read_dirent() */
- dir->name = malloc(name_size);
+ dir->name = malloc(name_size + 1);
  fread(dir->name, name_size, 1, fp);
  dir->name[dir->namelen] = '\0';   /* can write at index == name_size when
                                       namelen is a multiple of 4          */
```

This is a real bug in upstream; `F3S_NAME_ALIGN(namelen)` returns exactly
`namelen` when `namelen` is a multiple of 4, so the null terminator writes
one byte past the allocation.

### 2. `status_b` struct field order is wrong

Upstream declares:

```c
typedef struct {
    uint16_t padding1;
    uint8_t  flags2;    /* Contains exttype(2), BASIC(1), padding(5) */
    uint8_t  flags1;    /* Contains remaining status bits            */
} status_b;
```

On our MMI3G firmware, the actual on-disk layout is:

```c
typedef struct {
    uint8_t  flags1;    /* first byte  */
    uint8_t  flags2;    /* second byte */
    uint16_t padding1;  /* last two bytes */
} status_b;
```

Symptom without the fix: every head record reads as `exttype=XIP
extstat=BAD` when in reality they are `SYS`/`DIR`/`FILE` extents with
status `ALLOC`.

### 3. Endianness

Upstream assumes big-endian. MMI3G EFS images are little-endian.

```c
/* efsdump.c */
uint16_t swap16(uint16_t val) {
-   return ntohs(val);
+   return val;
}
uint32_t swap32(uint32_t val) {
-   return ntohl(val);
+   return val;
}
```

### 4. Pre-wrapper size

Upstream hardcodes `0x2C` bytes of wrapper before the `QSSL_F3S` signature.
MMI3G uncompressed variants have only 4 bytes (struct_size + rev fields).
Compressed variant 61 has 0xC0 bytes of different wrapping entirely.

## Further reading

- QNX docs: `http://www.qnx.com/developers/docs/6.5.0SP1/...` — FFS3 filesystem
  description, `f3s_spec.h`, `inflator(1)` reference
- `github.com/jtang613/qnx_dumpers` — starting point for the format reverse
  engineering, with patches documented above
- Gary E. Rafe's QNX 6.5 SP1 VM image (hosted on his vagresources Google site)
  contains the official QNX tools and source headers
