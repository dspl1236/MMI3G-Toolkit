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

Regular files in the EFS are wrapped in a Harman-Becker container starting with
the 8-byte magic `"iwlyfmbp"`. Header format appears to be:

```
+0   magic[8]        "iwlyfmbp"
+8   size:uint32     payload size (varies per file)
+12  flags:uint32    always 0x00012000 in our samples
+16  field3:uint32   varies
+20  field4:uint32   varies
+24+ payload (encoded/compressed — format unknown)
```

The payload does **not** match LZO, UCL, zlib, gzip, LZ4, LZMA, bzip2, or xz.
Entropy ~7.6 bits/byte suggests compression rather than encryption. ELF
binaries show their magic `7f 45 4c 46` embedded in the wrapper but the
following fields are completely garbled, which rules out a simple header strip.

**17 instances** of this magic were found inside a single 38 MB variant-41 EFS.

### Embedded JARs in plaintext

JARs (`DSITracer.jar`, `AppDevelopment.jar`, HMI resource bundles, etc.) are
stored in the EFS as normal PKZIP archives — the 5 JARs we located via
`PK\x05\x06` end-of-central-directory scanning all validate as real ZIPs with
proper central directories. However, bytes inside individual entries do NOT
decompress cleanly, which suggests the Harman wrapper also intrudes on JAR
content somehow. This needs more investigation.

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
