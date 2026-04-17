# QNX IFS (Image File System) format — MMI3G notes

## What IFS is

IFS is QNX's **bootable** filesystem-in-a-file container — a single image
that contains the kernel (`procnto-instr`), the C library, boot-time
executables, config files, and the filesystem tree. At boot the MMI3G
bootloader jumps into the image's startup code, which sets up the kernel
and starts processes from `proc/boot/.script`.

Key files in MMI3G firmware that use this format:
- `ifs-root.ifs` — the actual root filesystem. This is where
  `MMI3GApplication`, `MMI3GMedia`, `MMI3GNavigation`, `MMI3GMisc`,
  `MMI3GTelephone`, `NavCore`, `lsd.jxe`, `j9` JVM, and the whole
  Java HMI framework live.
- `ifs-emg.ifs` — emergency/recovery boot image. Smaller; used when
  normal boot fails.

IFS is **completely different** from the F3S EFS used for
`efs-system.efs`. F3S is a rewritable flash filesystem with partitions,
units, dirents, and extent chains; IFS is a compressed ROM image with a
flat directory table and raw file data.

Authoritative sources:
- `openqnx/trunk/services/system/public/sys/image.h` — struct defs
- `openqnx/trunk/utils/m/mkxfs/dumpifs/dumpifs.c` — reference reader
- `openqnx/trunk/utils/m/mkxfs/mkxfs/mk_image_fsys.c` — writer

## File layout

```
┌───────────────────────────────────────────────────┐  offset 0
│  startup_header  (fixed 256 bytes)                │
├───────────────────────────────────────────────────┤
│  startup code  (MMI3G: SH4 ELF chunks + strings)  │
├───────────────────────────────────────────────────┤
│  startup_trailer  (4 bytes, cksum)                │
├───────────────────────────────────────────────────┤  offset startup_size
│  compressed payload                               │
│    ┌─────────────────────────────────────────────┐│
│    │  u16 BE length + LZO/UCL compressed chunk   ││
│    │  u16 BE length + LZO/UCL compressed chunk   ││
│    │  ...                                        ││
│    │  u16 = 0  (end-of-stream marker)            ││
│    └─────────────────────────────────────────────┘│
└───────────────────────────────────────────────────┘  offset stored_size
```

Each compressed chunk decompresses to exactly 65,536 bytes (except the
last, which may be smaller). A typical MMI3G `ifs-root.ifs`:
- `stored_size` ≈ 43 MB compressed
- `imagefs_size` ≈ 104 MB uncompressed
- ≈ 671 LZO chunks

After decompression, the stream is a plain IFS starting with an
`imagefs` signature.

## startup_header

```c
struct startup_header {
    uint32_t signature;        // 0x00ff7eeb (jump instruction)
    uint16_t version;          // 1
    uint8_t  flags1;           // see flag bits below
    uint8_t  flags2;           // 0
    uint16_t header_size;      // 256
    uint16_t machine;          // 0x2a = EM_SH (Hitachi SH) on MMI3G
    uint32_t startup_vaddr;    // 0x88013d80 typical
    uint32_t paddr_bias;
    uint32_t image_paddr;
    uint32_t ram_paddr;
    uint32_t ram_size;
    uint32_t startup_size;     // offset where compressed payload begins
    uint32_t stored_size;      // total on-disk size (startup + compressed)
    uint32_t imagefs_paddr;
    uint32_t imagefs_size;     // uncompressed payload size
    uint16_t preboot_size;
    // ... + 14 bytes of zeros
};
```

**flags1 bit layout** (MSB-first, per unbe/mmi-ifs BitStruct):

| Bit | Meaning |
|-----|---------|
| 7 | STARTUP_HDR_FLAGS1_VIRTUAL |
| 6 | STARTUP_HDR_FLAGS1_BIGENDIAN |
| 5..2 | Compression type: 0=none, 1=zlib, 2=LZO1X, 3=UCL NRV2B |
| 1..0 | Padding |

MMI3G firmware: `flags1 = 0x09` on `ifs-root.ifs`. That decodes as
VIRTUAL=0, BIGENDIAN=0, Compression=2 (LZO1X). `ifs-emg.ifs` uses UCL.

## image_header (after decompression)

Layout defined in `sys/image.h`:

```c
struct image_header {
    char     signature[7];     // "imagefs"
    uint8_t  flags;            // bit 0: BIGENDIAN, bit 1: READONLY, bit 2: INO_BITS
    uint32_t image_size;       // header to end of trailer
    uint32_t hdr_dir_size;     // header to last dirent
    uint32_t dir_offset;       // to first dirent
    uint32_t boot_ino[4];
    uint32_t script_ino;
    uint32_t chain_paddr;
    uint32_t spare[10];
    uint32_t mountflags;
    char     mountpoint[];     // null-terminated, "/" on MMI3G
};
```

## Dirents

Each dirent starts with a 24-byte `image_attr` prefix, then has
type-specific fields based on the `mode` field's file-type nibble
(`mode & 0xf000`):

```
image_attr (24 bytes):
  size:u16  extattr_offset:u16  ino:u32  mode:u32
  gid:u32   uid:u32             mtime:u32

S_IFREG (0x8000):   offset:u32  size:u32   path[]
S_IFDIR (0x4000):                          path[]
S_IFLNK (0xa000):   sym_offset:u16  sym_size:u16   path[]  sym_target[]
device  (various):  dev:u32  rdev:u32      path[]
```

Paths are null-terminated within the dirent. Total dirent is padded to
`size` bytes. Walk stops when a dirent has `size == 0` OR the walker
has consumed `hdr_dir_size - dir_offset` bytes.

File content lives at `ipos + offset` where `ipos` is the image_header
position and `offset` comes from the S_IFREG dirent.

## Why stock dumpifs fails on MMI3G ifs-root

The stock QNX `dumpifs` calls `lzo1x_decompress_safe` on each chunk.
The `_safe` variant performs bounds-checking that Harman's LZO streams
fail — probably because they were produced by an older/different LZO
encoder than what modern liblzo2 expects. Switching to the permissive
`lzo1x_decompress` makes everything work.

This matches the approach taken by `unbe/mmi-ifs`'s `lzod.c` helper
(which uses plain `lzo1x_decompress`) and explains DrGER2's audizine
thread noting that only that workaround successfully extracted HN+
`ifs-root.ifs` files.

`ifs-emg.ifs` uses UCL compression which has no analogous issue — the
`ucl_nrv2b_decompress_8` function works on Harman's streams directly.

## Tools in this repo

- `tools/qnx_ifs_decompress.c` — C decompressor (LZO + UCL)
- `tools/inflate_ifs.py` — Python wrapper with auto-build + `--extract` mode
- `tools/extract_qnx_ifs.py` — dirent walker for decompressed IFS images

Full extraction of K0942_4 variant 41 `ifs-root.ifs` yields 345 files
including `/usr/apps/MMI3GApplication` (10.7 MB SH4 ELF), the complete
Java HMI stack (`/lsd/lsd.jxe`, `/j9/bin/libj9jit23.so`), system
libraries, `etc/mmi3g-srv-starter.cfg` (101-process startup config), and
the QNX kernel itself.
