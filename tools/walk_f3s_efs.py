#!/usr/bin/env python3
"""
walk_f3s_efs.py — Walk and extract MMI3G QNX F3S (uncompressed) EFS images.

Target: /efs-system/{41,51}/default/efs-system.efs from K0942_3 / K0942_4 / K0942_6
        (MMI 3G+ non-Plus variants — variant 61 is compressed and NOT supported here).

Format (little-endian throughout):

  Unit 0 header:
    +0x00  unit_info_s  (16 bytes)  struct_size=16, endian='L' (0x4c), unit_pow2=18 → 256 KB units
    +0x10  unit_logi_s  (24 bytes)  struct_size=24, md5[16]
    +0x28  boot_info_s  (24 bytes)  "QSSL_F3S", unit_total, root extptr
    +0x40  dirent chain starts here

  dirent layout (variable size):
    +0  struct_size:H   (size of dirent HEADER only, usually 8)
    +2  moves:B
    +3  namelen:B
    +4  first:extptr    (unit:H, index:H)    — extent pointer (not currently followed)
    +8  name[namelen+pad]                    — 4-byte aligned
    +?  stat_s (20 bytes)
          struct_size:H=20
          mode:H          (high nibble = file type: 0x4=DIR 0x8=FILE 0xa=LINK)
          uid:I, gid:I, mtime:I, ctime:I
  Total dirent = 8 + aligned(namelen) + 20

  Directory entries are laid out sequentially. File data follows in subsequent
  dirents — when we hit a FILE dirent, its first extptr points to where the data
  lives. In uncompressed variant 41/51, file content appears to be inlined right
  after the stat.

This walker extracts the flat list of file names + first-extent pointers, which
is enough to tell us what's in the image. File content extraction is a follow-up.
"""
import argparse
import os
import struct
import sys


def u16(data, off): return struct.unpack_from('<H', data, off)[0]
def u32(data, off): return struct.unpack_from('<I', data, off)[0]


# ---- Parsers for the fixed structures ----

def parse_unit_info(data, off):
    return {
        'struct_size': u16(data, off),
        'endian': chr(data[off + 2]),
        'pad': data[off + 3],
        'unit_pow2': u16(data, off + 4),
        'reserve': u16(data, off + 6),
        'erase_count': u32(data, off + 8),
        'boot_unit': u16(data, off + 12),
        'boot_index': u16(data, off + 14),
    }


def parse_boot_info(data, off):
    return {
        'struct_size': u16(data, off),
        'rev_major': data[off + 2],
        'rev_minor': data[off + 3],
        'sig': data[off + 4:off + 12].decode('ascii', errors='replace'),
        'unit_index': u16(data, off + 12),
        'unit_total': u16(data, off + 14),
        'unit_spare': u16(data, off + 16),
        'align_pow2': u16(data, off + 18),
        'root_unit': u16(data, off + 20),
        'root_index': u16(data, off + 22),
    }


# ---- Dirent parser ----

FILE_TYPE_NAMES = {
    0x1: 'FIFO',
    0x2: 'CHR',
    0x4: 'DIR',
    0x6: 'BLK',
    0x8: 'FILE',
    0xa: 'LINK',
    0xc: 'SOCK',
}


def parse_dirent(data, off):
    """Return a dict with dirent fields and total size, or None if invalid."""
    if off + 8 > len(data):
        return None
    struct_size = u16(data, off)
    moves = data[off + 2]
    namelen = data[off + 3]
    first_unit = u16(data, off + 4)
    first_index = u16(data, off + 6)

    # Sanity
    if struct_size != 8:
        return None
    if namelen == 0 or namelen > 128:
        return None

    # Name: padded to 4-byte alignment (typical alignment in this format)
    name_start = off + 8
    name_end = data.find(b'\x00', name_start, name_start + namelen)
    if name_end < 0:
        name_end = name_start + namelen
    name = data[name_start:name_end].decode('utf-8', errors='replace')

    # Name space includes padding to 4-byte boundary
    name_space = (namelen + 3) & ~3
    stat_off = off + 8 + name_space

    # Stat should be 20 bytes
    if stat_off + 20 > len(data):
        return None
    stat_size = u16(data, stat_off)
    if stat_size != 20:
        return None
    mode = u16(data, stat_off + 2)
    uid = u32(data, stat_off + 4)
    gid = u32(data, stat_off + 8)
    mtime = u32(data, stat_off + 12)
    ctime = u32(data, stat_off + 16)

    ftype = (mode >> 12) & 0xf
    ftype_name = FILE_TYPE_NAMES.get(ftype, f'?{ftype:x}')

    total_size = 8 + name_space + 20

    return {
        'offset': off,
        'total_size': total_size,
        'struct_size': struct_size,
        'moves': moves,
        'namelen': namelen,
        'first_unit': first_unit,
        'first_index': first_index,
        'name': name,
        'mode': mode,
        'ftype': ftype,
        'ftype_name': ftype_name,
        'uid': uid, 'gid': gid,
        'mtime': mtime, 'ctime': ctime,
    }


def walk_dirents(data, start_off, max_count=100000):
    """Walk dirent chain starting at start_off until an invalid record."""
    results = []
    off = start_off
    while len(results) < max_count:
        d = parse_dirent(data, off)
        if d is None:
            # Skip forward a bit in case of padding
            # Check if we're at 0xFF padding
            if data[off] == 0xff:
                # Skip past padding to next 4-byte boundary plus
                off = (off + 4) & ~3
                if off >= len(data):
                    break
                continue
            break
        results.append(d)
        off += d['total_size']
        # Round up to 4-byte boundary
        off = (off + 3) & ~3
    return results


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('image', help='Path to efs-system.efs')
    ap.add_argument('--show', type=int, default=50, help='Max entries to show (default 50)')
    ap.add_argument('--filter', help='Only show names containing this substring')
    ap.add_argument('--format', choices=['simple', 'detailed'], default='simple')
    args = ap.parse_args()

    with open(args.image, 'rb') as f:
        data = f.read()

    print(f"[+] {args.image}  ({len(data):,} bytes)")

    # Parse headers
    ui = parse_unit_info(data, 0)
    print(f"[+] unit_info: size={ui['struct_size']} endian={ui['endian']!r} unit_pow2={ui['unit_pow2']} "
          f"→ unit_size={1 << ui['unit_pow2']:,} bytes")

    # Find QSSL_F3S
    f3s_off = data.find(b'QSSL_F3S')
    if f3s_off < 0:
        print("[-] No QSSL_F3S signature!")
        return 1
    bi_off = f3s_off - 4
    bi = parse_boot_info(data, bi_off)
    print(f"[+] boot_info @0x{bi_off:x}: rev={bi['rev_major']}.{bi['rev_minor']} "
          f"total_units={bi['unit_total']} align=2^{bi['align_pow2']} "
          f"root=({bi['root_unit']}:{bi['root_index']})")

    # Walk dirents starting right after boot_info
    dirent_start = bi_off + 24  # boot_info_s is 24 bytes
    print(f"[+] Walking dirents from 0x{dirent_start:x}...")
    dirents = walk_dirents(data, dirent_start)
    print(f"[+] Found {len(dirents)} dirents")

    # Count by type
    types = {}
    for d in dirents:
        types[d['ftype_name']] = types.get(d['ftype_name'], 0) + 1
    print(f"    by type: {types}")
    print()

    # Filter and display
    if args.filter:
        filtered = [d for d in dirents if args.filter.lower() in d['name'].lower()]
        print(f"[+] {len(filtered)} entries matching '{args.filter}':")
    else:
        filtered = dirents

    print()
    for d in filtered[:args.show]:
        if args.format == 'detailed':
            print(f"  @0x{d['offset']:06x}  {d['ftype_name']:<4} mode=0x{d['mode']:04x} "
                  f"first=({d['first_unit']}:{d['first_index']}) "
                  f"sz={d['total_size']:<3}  {d['name']!r}")
        else:
            print(f"  {d['ftype_name']:<4} {d['name']}")

    if len(filtered) > args.show:
        print(f"  ... and {len(filtered) - args.show} more")

    return 0


if __name__ == '__main__':
    sys.exit(main())
