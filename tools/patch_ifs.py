#!/usr/bin/env python3
"""
patch_ifs.py — replace files inside a decompressed QNX IFS image.

Takes a decompressed IFS (output of inflate_ifs.py) and produces a new
decompressed IFS with specified files replaced. Handles any file size
change by rebuilding the file data section.

Usage:
    # Replace a single binary
    python3 tools/patch_ifs.py ifs_decomp.ifs ifs_patched.ifs \\
        --replace /usr/apps/MMI3GApplication=./modified_app

    # Replace multiple files
    python3 tools/patch_ifs.py ifs_decomp.ifs ifs_patched.ifs \\
        --replace /usr/apps/MMI3GApplication=./mod_app \\
        --replace /etc/mmi3g-srv-starter.cfg=./mod_cfg

    # List all files (no modification)
    python3 tools/patch_ifs.py ifs_decomp.ifs --list

After patching, compress with repack_ifs.py and fix CRCs:
    python3 tools/repack_ifs.py ifs_patched.ifs new_ifs-root.ifs
    python3 tools/mu_crc_patcher.py --metainfo metainfo2.txt \\
        --file new_ifs-root.ifs --section '...'
"""
import argparse
import os
import struct
import sys
import zlib

IMAGE_SIG = b'imagefs'

S_IFMT  = 0xf000
S_IFREG = 0x8000
S_IFDIR = 0x4000
S_IFLNK = 0xa000

def u16(b, o): return struct.unpack_from('<H', b, o)[0]
def u32(b, o): return struct.unpack_from('<I', b, o)[0]
def w16(b, o, v): struct.pack_into('<H', b, o, v)
def w32(b, o, v): struct.pack_into('<I', b, o, v)


def align(val, boundary):
    return (val + boundary - 1) & ~(boundary - 1)


def compute_ifs_checksum(data, start, size):
    """Compute the QNX IFS image checksum (ones-complement sum of uint32s)."""
    # The checksum at the trailer position should make the total sum
    # of all uint32 words in the image equal to 0 (mod 2^32).
    # First compute sum without trailer, then trailer = -sum.
    total = 0
    for i in range(start, start + size - 4, 4):
        total += u32(data, i)
        total &= 0xffffffff
    return (~total + 1) & 0xffffffff


def parse_dirents(data, ipos, dir_offset, hdr_dir_size):
    """Walk the dirent chain and return list of entries."""
    dpos = ipos + dir_offset
    end = ipos + hdr_dir_size
    entries = []
    off = dpos

    while off < end:
        if off + 24 > len(data):
            break
        size = u16(data, off)
        if size == 0:
            break

        ent = {
            'abs_off': off,
            'rel_off': off - ipos,
            'rec_size': size,
            'extattr_offset': u16(data, off + 2),
            'ino': u32(data, off + 4),
            'mode': u32(data, off + 8),
            'gid': u32(data, off + 12),
            'uid': u32(data, off + 16),
            'mtime': u32(data, off + 20),
        }
        ftype = ent['mode'] & S_IFMT
        ent['ftype'] = ftype

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
        else:
            ent['dev'] = u32(data, off + 24)
            ent['rdev'] = u32(data, off + 28)
            path_start = off + 32

        path_end = data.find(b'\x00', path_start, off + size)
        if path_end < 0:
            path_end = off + size
        ent['path'] = data[path_start:path_end].decode('utf-8', errors='replace')

        if ftype == S_IFLNK and 'sym_offset' in ent:
            sym_start = off + ent['sym_offset']
            sym_end = data.find(b'\x00', sym_start, sym_start + ent.get('sym_size', 0) + 1)
            if sym_end < 0:
                sym_end = sym_start + ent.get('sym_size', 0)
            ent['sym_target'] = data[sym_start:sym_end].decode('utf-8', errors='replace')

        entries.append(ent)
        off += size

    return entries


def list_files(entries):
    """Print all entries with sizes."""
    for e in entries:
        ftype = e['ftype']
        path = e['path']
        if ftype == S_IFREG:
            print(f"  {e['file_size']:>10,}  {path}")
        elif ftype == S_IFDIR:
            print(f"       <dir>  {path}/")
        elif ftype == S_IFLNK:
            print(f"      <sym>  {path} -> {e.get('sym_target', '?')}")
        else:
            print(f"       <dev>  {path}")


def patch_image(data, entries, replacements, ipos, image_hdr_size):
    """
    Rebuild the IFS imagefs section with replaced files.
    Returns the new imagefs portion (image_header + dirents + data + trailer).
    """
    # Build a map of path -> replacement data
    replace_map = {}
    for spec in replacements:
        if '=' not in spec:
            print(f"ERROR: --replace format is /ifs/path=local/file", file=sys.stderr)
            sys.exit(1)
        ifs_path, local_path = spec.split('=', 1)
        ifs_path = ifs_path.lstrip('/')
        if not os.path.exists(local_path):
            print(f"ERROR: replacement file not found: {local_path}", file=sys.stderr)
            sys.exit(1)
        with open(local_path, 'rb') as f:
            replace_map[ifs_path] = f.read()
        print(f"[patch] will replace /{ifs_path} ({os.path.getsize(local_path):,} bytes)")

    # Copy the image header + dirent section verbatim into a mutable buffer
    ihdr_start = ipos
    # Find the end of dirents (we need the original dirent region)
    dirent_region_end = 0
    for e in entries:
        end = e['abs_off'] + e['rec_size']
        if end > dirent_region_end:
            dirent_region_end = end

    # The dirent section (including image header) 
    dirent_data = bytearray(data[ihdr_start:dirent_region_end + 2])  # +2 for zero terminator

    # Now rebuild the file data section
    # Start file data at an aligned boundary after the dirents
    dirent_rel_end = dirent_region_end + 2 - ipos  # relative to ipos
    file_data_start = align(dirent_rel_end, 4096)  # align to page

    file_data = bytearray()
    current_offset = file_data_start
    replaced_count = 0

    for e in entries:
        if e['ftype'] != S_IFREG:
            continue

        path = e['path']
        orig_offset = e['file_offset']
        orig_size = e['file_size']

        # Check if this file is being replaced
        if path in replace_map:
            content = replace_map[path]
            replaced_count += 1
            old_size = orig_size
            print(f"[patch] /{path}: {old_size:,} -> {len(content):,} bytes "
                  f"({'same' if len(content) == old_size else 'RESIZED'})")
        else:
            # Copy original content
            abs_off = ipos + orig_offset
            content = data[abs_off:abs_off + orig_size]

        # Pad file data to current offset
        pad_needed = current_offset - file_data_start - len(file_data)
        if pad_needed > 0:
            file_data.extend(b'\x00' * pad_needed)

        # Record new offset and size in the dirent
        new_offset = current_offset
        new_size = len(content)

        # Update the dirent record in dirent_data
        dirent_rel_off = e['abs_off'] - ipos
        # file_offset is at dirent_rel_off + 24, file_size at + 28
        struct.pack_into('<I', dirent_data, dirent_rel_off + 24, new_offset)
        struct.pack_into('<I', dirent_data, dirent_rel_off + 28, new_size)

        file_data.extend(content)
        current_offset += len(content)
        # Align each file to 4-byte boundary
        padding = align(current_offset, 4) - current_offset
        if padding:
            file_data.extend(b'\x00' * padding)
            current_offset += padding

    # Check for unreplaced paths
    for path in replace_map:
        found = any(e['path'] == path and e['ftype'] == S_IFREG for e in entries)
        if not found:
            print(f"WARNING: /{path} not found in IFS — replacement ignored",
                  file=sys.stderr)

    # Build the complete imagefs
    # dirent_data covers [0 .. dirent_rel_end] relative to ipos
    # file_data starts at file_data_start relative to ipos
    # Need to pad between dirent_data and file_data

    total_data_end = file_data_start + len(file_data)
    # Align to 4096 for trailer
    total_aligned = align(total_data_end, 4096)
    
    # image_size = from image_header to end of trailer (inclusive)
    image_size = total_aligned + 4  # +4 for trailer

    # Update image_header.image_size
    struct.pack_into('<I', dirent_data, 8, image_size)

    # Assemble
    imagefs = bytearray(image_size)
    # Copy dirent section
    imagefs[:len(dirent_data)] = dirent_data
    # Copy file data
    imagefs[file_data_start:file_data_start + len(file_data)] = file_data

    # Compute and write trailer checksum
    # The checksum covers the entire imagefs from image_header to trailer
    cksum = compute_ifs_checksum(imagefs, 0, image_size)
    struct.pack_into('<I', imagefs, image_size - 4, cksum)

    print(f"[patch] replaced {replaced_count} file(s)")
    print(f"[patch] new imagefs: {image_size:,} bytes "
          f"(was {u32(data, ipos + 8):,})")

    return bytes(imagefs)


def main():
    p = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('input', help='Decompressed IFS image')
    p.add_argument('output', nargs='?', help='Output patched IFS')
    p.add_argument('--list', action='store_true', help='List files only')
    p.add_argument('--replace', action='append', default=[],
                   metavar='IFS_PATH=LOCAL_FILE',
                   help='Replace a file: /usr/apps/MMI3GApplication=./modified')
    args = p.parse_args()

    with open(args.input, 'rb') as f:
        data = f.read()

    # Parse startup header
    startup_size = u32(data, 0x20)
    ipos = startup_size

    if data[ipos:ipos + 7] != IMAGE_SIG:
        print("ERROR: no imagefs signature at startup_size offset", file=sys.stderr)
        sys.exit(1)

    image_size = u32(data, ipos + 8)
    hdr_dir_size = u32(data, ipos + 12)
    dir_offset = u32(data, ipos + 16)

    # Image header size (from start to first dirent)
    image_hdr_size = dir_offset

    entries = parse_dirents(data, ipos, dir_offset, hdr_dir_size)

    if args.list:
        list_files(entries)
        files = sum(1 for e in entries if e['ftype'] == S_IFREG)
        dirs = sum(1 for e in entries if e['ftype'] == S_IFDIR)
        links = sum(1 for e in entries if e['ftype'] == S_IFLNK)
        print(f"\n{files} files, {dirs} dirs, {links} symlinks")
        return

    if not args.output:
        print("ERROR: output path required (or use --list)", file=sys.stderr)
        sys.exit(1)

    if not args.replace:
        print("ERROR: at least one --replace required", file=sys.stderr)
        sys.exit(1)

    # Patch the imagefs
    new_imagefs = patch_image(data, entries, args.replace, ipos, image_hdr_size)

    # Rebuild the complete IFS: startup + new imagefs
    startup = data[:startup_size]
    output = bytearray(startup)

    # Update startup_header fields
    new_stored_size = len(startup) + len(new_imagefs)
    new_imagefs_size = len(new_imagefs)
    struct.pack_into('<I', output, 0x24, new_stored_size)  # stored_size
    struct.pack_into('<I', output, 0x2c, new_imagefs_size)  # imagefs_size
    # Clear compression flag (this is decompressed)
    output[6] = output[6] & ~0x1c  # clear compression bits

    output.extend(new_imagefs)

    with open(args.output, 'wb') as f:
        f.write(output)

    print(f"[patch] wrote {args.output} ({len(output):,} bytes)")


if __name__ == '__main__':
    main()
