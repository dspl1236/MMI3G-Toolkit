#!/usr/bin/env python3
"""
extract_qnx_ifs.py — extract files from a QNX Image File System (.ifs).

IFS is QNX's bootable-kernel-plus-rootfs container, distinct from F3S
(used for efs-system.efs). Format defined in:
  openqnx/trunk/services/system/public/sys/image.h
  openqnx/trunk/utils/m/mkxfs/dumpifs/dumpifs.c

Layout:
  offset 0         startup_header (256 bytes typical)
  offset startup_size  image_header (signature "imagefs", then flags,
                       sizes, dir_offset, boot/script inodes, mountpoint)
  offset ipos + dir_offset   chain of image_dirent records
  offset ipos + {dirent.offset}  file data for each regular file
  offset ipos + image_size - 4   image_trailer (cksum)

All IFS dirents share a common image_attr prefix (24 bytes):
  size:H extattr_offset:H ino:I mode:I gid:I uid:I mtime:I
Then type-specific:
  S_IFREG:  offset:I size:I path[]
  S_IFDIR:  path[]
  S_IFLNK:  sym_offset:H sym_size:H path[]
  device:   dev:I rdev:I path[]
Path is null-terminated, total dirent padded to `size`.

This tool walks the dirent chain, extracts regular files to outdir with
their full path structure preserved, and reports counts.

Target: MMI3G ifs-root.ifs from K0942_3 / K0942_4 / K0942_6.
"""
import argparse
import os
import struct
import sys


IMAGE_SIG = b'imagefs'


def u16(b, o): return struct.unpack_from('<H', b, o)[0]
def u32(b, o): return struct.unpack_from('<I', b, o)[0]


def parse_startup_header(data, off=0):
    """Parse the startup header at given offset. Returns a dict."""
    return {
        'signature': data[off:off + 4].hex(),
        'version': u16(data, off + 4),
        'flags1': data[off + 6],
        'flags2': data[off + 7],
        'header_size': u16(data, off + 8),
        'machine': u16(data, off + 10),
        'startup_vaddr': u32(data, off + 12),
        'paddr_bias': u32(data, off + 16),
        'image_paddr': u32(data, off + 20),
        'ram_paddr': u32(data, off + 24),
        'ram_size': u32(data, off + 28),
        'startup_size': u32(data, off + 32),
        'stored_size': u32(data, off + 36),
    }


def parse_image_header(data, ipos):
    """Parse image_header starting at ipos. Signature 'imagefs' must be there."""
    if data[ipos:ipos + 7] != IMAGE_SIG:
        return None
    flags = data[ipos + 7]
    # image_size starts at offset +8 (after sig[7] + flags[1])
    image_size = u32(data, ipos + 8)
    hdr_dir_size = u32(data, ipos + 12)
    dir_offset = u32(data, ipos + 16)
    # boot_ino[4], script_ino, chain_paddr, spare[10], mountflags
    # mountpoint starts at offset 8 + 4*4 + 4*4 + 4 + 4 + 40 + 4 = 80
    boot_ino = [u32(data, ipos + 20 + i * 4) for i in range(4)]
    script_ino = u32(data, ipos + 36)
    chain_paddr = u32(data, ipos + 40)
    # spare[10] = 40 bytes
    mountflags = u32(data, ipos + 84)
    # mountpoint from offset +88
    mp_end = data.find(b'\x00', ipos + 88)
    mountpoint = data[ipos + 88:mp_end].decode('utf-8', errors='replace')
    return {
        'ipos': ipos,
        'flags': flags,
        'image_size': image_size,
        'hdr_dir_size': hdr_dir_size,
        'dir_offset': dir_offset,
        'boot_ino': boot_ino,
        'script_ino': script_ino,
        'chain_paddr': chain_paddr,
        'mountflags': mountflags,
        'mountpoint': mountpoint,
    }


# POSIX file-type nibbles
S_IFMT = 0xf000
S_IFREG = 0x8000
S_IFDIR = 0x4000
S_IFLNK = 0xa000
S_IFCHR = 0x2000
S_IFBLK = 0x6000
S_IFIFO = 0x1000
S_IFSOCK = 0xc000


def walk_dirents(data, ihdr, image_start_offset):
    """
    Walk the dirent chain. image_start_offset = where image_header lives
    in the file (so dirent offsets are absolute file offsets via ipos +
    dir_offset and ipos + dirent.offset).
    """
    dpos = image_start_offset + ihdr['dir_offset']
    end = image_start_offset + ihdr['hdr_dir_size']  # wait — hdr_dir_size is
    # size from header to END of last dirent. So the dirent region is
    # (image_start_offset + dir_offset) .. (image_start_offset + hdr_dir_size).

    entries = []
    off = dpos
    while off < end:
        # image_attr header is 24 bytes
        if off + 24 > len(data):
            break
        size = u16(data, off)
        if size == 0:
            # End of directory list
            break
        extattr_offset = u16(data, off + 2)
        ino = u32(data, off + 4)
        mode = u32(data, off + 8)
        gid = u32(data, off + 12)
        uid = u32(data, off + 16)
        mtime = u32(data, off + 20)

        ftype = mode & S_IFMT

        ent = {
            'rec_off': off,
            'size': size,
            'extattr_offset': extattr_offset,
            'ino': ino,
            'mode': mode,
            'gid': gid, 'uid': uid, 'mtime': mtime,
            'ftype': ftype,
        }

        # Type-specific fields
        if ftype == S_IFREG:
            ent['file_offset'] = u32(data, off + 24)
            ent['file_size'] = u32(data, off + 28)
            path_start = off + 32
        elif ftype == S_IFDIR:
            path_start = off + 24
        elif ftype == S_IFLNK:
            ent['sym_offset'] = u16(data, off + 24)
            ent['sym_size'] = u16(data, off + 26)
            path_start = off + 28
        elif ftype in (S_IFCHR, S_IFBLK, S_IFIFO, S_IFSOCK):
            ent['dev'] = u32(data, off + 24)
            ent['rdev'] = u32(data, off + 28)
            path_start = off + 32
        else:
            path_start = off + 24

        # Path is null-terminated within the dirent record
        path_end = data.find(b'\x00', path_start, off + size)
        if path_end < 0:
            path_end = off + size
        try:
            ent['path'] = data[path_start:path_end].decode('utf-8', errors='replace')
        except Exception:
            ent['path'] = '<bad-path>'

        # Symlink target follows fixed fields (at sym_offset bytes past record start)
        if ftype == S_IFLNK and 'sym_offset' in ent:
            sym_start = off + ent['sym_offset']
            sym_end = data.find(b'\x00', sym_start, sym_start + ent['sym_size'] + 1)
            if sym_end < 0:
                sym_end = sym_start + ent['sym_size']
            ent['sym_target'] = data[sym_start:sym_end].decode('utf-8', errors='replace')

        entries.append(ent)
        off += size

    return entries


FTYPE_NAMES = {
    S_IFREG: 'FILE',
    S_IFDIR: 'DIR',
    S_IFLNK: 'LINK',
    S_IFCHR: 'CHR',
    S_IFBLK: 'BLK',
    S_IFIFO: 'FIFO',
    S_IFSOCK: 'SOCK',
}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('image', help='Path to ifs-root.ifs')
    ap.add_argument('outdir', help='Output directory for extracted files')
    ap.add_argument('--list', action='store_true', help='List files without extracting')
    ap.add_argument('--only', help='Only extract/list files whose path contains this substring')
    args = ap.parse_args()

    with open(args.image, 'rb') as f:
        data = f.read()
    print(f"[+] {args.image}  ({len(data):,} bytes)")

    # Parse startup header
    sh = parse_startup_header(data, 0)
    print(f"[+] startup_header:")
    print(f"    sig={sh['signature']}  version={sh['version']}  "
          f"flags1=0x{sh['flags1']:02x}  flags2=0x{sh['flags2']:02x}")
    print(f"    header_size={sh['header_size']}  machine=0x{sh['machine']:04x} "
          f"({'SH' if sh['machine']==0x2a else 'ARM' if sh['machine']==0x28 else '?'})")
    print(f"    startup_size=0x{sh['startup_size']:x}  stored_size=0x{sh['stored_size']:x}")

    # image_header lives at offset startup_size
    ipos = sh['startup_size']
    if data[ipos:ipos + 7] != IMAGE_SIG:
        # Search forward up to 64 KB for the signature
        found = data.find(IMAGE_SIG, ipos, ipos + 65536)
        if found < 0:
            # Try whole file
            found = data.find(IMAGE_SIG)
        if found < 0:
            sys.exit('[-] No imagefs signature found')
        ipos = found
        print(f"    (imagefs signature found at 0x{ipos:x})")

    ihdr = parse_image_header(data, ipos)
    if ihdr is None:
        sys.exit('[-] parse_image_header failed')
    print(f"[+] image_header at 0x{ipos:x}:")
    print(f"    flags=0x{ihdr['flags']:02x}  image_size=0x{ihdr['image_size']:x}")
    print(f"    dir_offset=0x{ihdr['dir_offset']:x}  hdr_dir_size=0x{ihdr['hdr_dir_size']:x}")
    print(f"    mountpoint={ihdr['mountpoint']!r}")

    entries = walk_dirents(data, ihdr, ipos)
    print(f"[+] Walked {len(entries)} dirents")

    # Summary by type
    types = {}
    for e in entries:
        t = FTYPE_NAMES.get(e['ftype'], f"0x{e['ftype']:x}")
        types[t] = types.get(t, 0) + 1
    print(f"    by type: {types}")

    # Filter
    if args.only:
        filtered = [e for e in entries if args.only.lower() in e.get('path', '').lower()]
    else:
        filtered = entries

    if args.list:
        for e in filtered[:100]:
            t = FTYPE_NAMES.get(e['ftype'], '?')
            extra = ''
            if t == 'FILE':
                extra = f"  offset=0x{e.get('file_offset', 0):x} size={e.get('file_size', 0):,}"
            elif t == 'LINK':
                extra = f"  -> {e.get('sym_target', '?')}"
            print(f"  {t:<4} {e['path']}{extra}")
        if len(filtered) > 100:
            print(f"  ... and {len(filtered) - 100} more")
        return 0

    # Extract
    os.makedirs(args.outdir, exist_ok=True)
    extracted = 0
    for e in filtered:
        if e['ftype'] != S_IFREG:
            continue
        path = e.get('path', '').lstrip('/')
        if not path or '..' in path.split('/'):
            continue
        file_offset = e.get('file_offset', 0)
        file_size = e.get('file_size', 0)
        if file_size <= 0 or file_size > 100 * 1024 * 1024:
            continue
        # Absolute offset = ipos + file_offset
        abs_off = ipos + file_offset
        if abs_off + file_size > len(data):
            print(f"    [skip] {path}: offset out of range")
            continue
        target = os.path.join(args.outdir, path)
        os.makedirs(os.path.dirname(target) or '.', exist_ok=True)
        with open(target, 'wb') as f:
            f.write(data[abs_off:abs_off + file_size])
        extracted += 1

    print(f"\n[+] Extracted {extracted} files to {args.outdir}/")
    return 0


if __name__ == '__main__':
    sys.exit(main())
