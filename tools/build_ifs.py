#!/usr/bin/env python3
"""
build_ifs.py — construct a QNX IFS image from a directory tree.

Takes an extracted file tree (output of inflate_ifs.py --extract) and
builds a new decompressed IFS image. Requires a reference IFS for the
startup section (architecture-specific boot code that can't be
generated from scratch).

Usage:
    # Rebuild from extracted tree
    python3 tools/build_ifs.py \\
        --reference ifs_decomp.ifs \\
        --tree ./ifs_extracted/ \\
        --output new_ifs_decomp.ifs

    # Then compress and fix CRCs
    python3 tools/repack_ifs.py new_ifs_decomp.ifs new_ifs-root.ifs
    python3 tools/mu_crc_patcher.py ...

The reference IFS provides:
  - Startup section (SH4 boot code, copied verbatim)
  - image_header template (flags, boot_ino, script_ino)
  - Original dirent metadata (permissions, timestamps, ino numbers)

Files in the tree override originals; new files are added; missing
files are omitted. This enables adding, removing, and replacing files.
"""
import argparse
import os
import struct
import sys

IMAGE_SIG = b'imagefs'
S_IFMT  = 0xf000
S_IFREG = 0x8000
S_IFDIR = 0x4000
S_IFLNK = 0xa000


def u16(b, o): return struct.unpack_from('<H', b, o)[0]
def u32(b, o): return struct.unpack_from('<I', b, o)[0]


def align4(n):
    return (n + 3) & ~3


def parse_reference(data):
    """Parse reference IFS to extract startup, image_header, and original dirents."""
    startup_size = u32(data, 0x20)
    ipos = startup_size

    if data[ipos:ipos+7] != IMAGE_SIG:
        raise ValueError("No imagefs signature in reference")

    ihdr = {
        'flags': data[ipos+7],
        'image_size': u32(data, ipos+8),
        'hdr_dir_size': u32(data, ipos+12),
        'dir_offset': u32(data, ipos+16),
        'boot_ino': [u32(data, ipos+20+i*4) for i in range(4)],
        'script_ino': u32(data, ipos+36),
        'chain_paddr': u32(data, ipos+40),
    }

    # Parse mountpoint
    mp_off = ipos + 88
    mp_end = data.find(b'\x00', mp_off)
    ihdr['mountpoint'] = data[mp_off:mp_end].decode()

    # Parse original dirents for metadata
    orig_entries = {}
    off = ipos + ihdr['dir_offset']
    while off < ipos + ihdr['hdr_dir_size']:
        rec_size = u16(data, off)
        if rec_size == 0:
            break

        ino = u32(data, off+4)
        mode = u32(data, off+8)
        gid = u32(data, off+12)
        uid = u32(data, off+16)
        mtime = u32(data, off+20)
        ftype = mode & S_IFMT

        entry = {'ino': ino, 'mode': mode, 'gid': gid, 'uid': uid,
                 'mtime': mtime, 'ftype': ftype, 'rec_size': rec_size,
                 'extattr': u16(data, off+2)}

        if ftype == S_IFREG:
            entry['file_offset'] = u32(data, off+24)
            entry['file_size'] = u32(data, off+28)
            pend = data.find(b'\x00', off+32, off+rec_size)
            entry['path'] = data[off+32:pend].decode('ascii', errors='replace')
        elif ftype == S_IFDIR:
            pend = data.find(b'\x00', off+24, off+rec_size)
            entry['path'] = data[off+24:pend].decode('ascii', errors='replace')
        elif ftype == S_IFLNK:
            entry['sym_offset_val'] = u16(data, off+24)
            entry['sym_size'] = u16(data, off+26)
            pend = data.find(b'\x00', off+28, off+rec_size)
            entry['path'] = data[off+28:pend].decode('ascii', errors='replace')
            sym_start = off + entry['sym_offset_val']
            sym_end = data.find(b'\x00', sym_start, sym_start + entry['sym_size'] + 1)
            if sym_end < 0:
                sym_end = sym_start + entry['sym_size']
            entry['target'] = data[sym_start:sym_end].decode('ascii', errors='replace')
        else:
            entry['dev'] = u32(data, off+24)
            entry['rdev'] = u32(data, off+28)
            pend = data.find(b'\x00', off+32, off+rec_size)
            entry['path'] = data[off+32:pend].decode('ascii', errors='replace') if pend > off+32 else ''

        orig_entries[entry['path']] = entry
        off += rec_size

    return data[:startup_size], ihdr, orig_entries


def build_dirent_reg(path, ino, mode, gid, uid, mtime, file_offset, file_size, extattr=0):
    """Build a regular file dirent record."""
    path_bytes = path.encode('ascii') + b'\x00'
    raw_size = 24 + 8 + len(path_bytes)  # attr + offset/size + path
    rec_size = align4(raw_size)
    buf = bytearray(rec_size)
    struct.pack_into('<H', buf, 0, rec_size)
    struct.pack_into('<H', buf, 2, extattr)
    struct.pack_into('<I', buf, 4, ino)
    struct.pack_into('<I', buf, 8, mode)
    struct.pack_into('<I', buf, 12, gid)
    struct.pack_into('<I', buf, 16, uid)
    struct.pack_into('<I', buf, 20, mtime)
    struct.pack_into('<I', buf, 24, file_offset)
    struct.pack_into('<I', buf, 28, file_size)
    buf[32:32+len(path_bytes)] = path_bytes
    return bytes(buf)


def build_dirent_dir(path, ino, mode, gid, uid, mtime, extattr=0):
    """Build a directory dirent record."""
    path_bytes = path.encode('ascii') + b'\x00'
    raw_size = 24 + len(path_bytes)
    rec_size = align4(raw_size)
    buf = bytearray(rec_size)
    struct.pack_into('<H', buf, 0, rec_size)
    struct.pack_into('<H', buf, 2, extattr)
    struct.pack_into('<I', buf, 4, ino)
    struct.pack_into('<I', buf, 8, mode)
    struct.pack_into('<I', buf, 12, gid)
    struct.pack_into('<I', buf, 16, uid)
    struct.pack_into('<I', buf, 20, mtime)
    buf[24:24+len(path_bytes)] = path_bytes
    return bytes(buf)


def build_dirent_link(path, target, ino, mode, gid, uid, mtime, extattr=0):
    """Build a symlink dirent record."""
    path_bytes = path.encode('ascii') + b'\x00'
    target_bytes = target.encode('ascii') + b'\x00'
    # sym_offset is relative to record start, points to target string
    sym_offset = 28 + len(path_bytes)
    sym_offset = align4(sym_offset)  # align target placement
    raw_size = sym_offset + len(target_bytes)
    rec_size = align4(raw_size)
    buf = bytearray(rec_size)
    struct.pack_into('<H', buf, 0, rec_size)
    struct.pack_into('<H', buf, 2, extattr)
    struct.pack_into('<I', buf, 4, ino)
    struct.pack_into('<I', buf, 8, mode)
    struct.pack_into('<I', buf, 12, gid)
    struct.pack_into('<I', buf, 16, uid)
    struct.pack_into('<I', buf, 20, mtime)
    struct.pack_into('<H', buf, 24, sym_offset)
    struct.pack_into('<H', buf, 26, len(target_bytes) - 1)  # size excludes null
    buf[28:28+len(path_bytes)] = path_bytes
    buf[sym_offset:sym_offset+len(target_bytes)] = target_bytes
    return bytes(buf)


def scan_tree(tree_root):
    """Scan the file tree and return (dirs, files, links) with relative paths."""
    dirs = []
    files = []
    links = []

    for root, dirnames, filenames in os.walk(tree_root):
        rel_root = os.path.relpath(root, tree_root)
        if rel_root == '.':
            rel_root = ''

        for d in sorted(dirnames):
            rel = os.path.join(rel_root, d) if rel_root else d
            dirs.append(rel)

        for fname in sorted(filenames):
            full = os.path.join(root, fname)
            rel = os.path.join(rel_root, fname) if rel_root else fname

            if os.path.islink(full):
                target = os.readlink(full)
                links.append((rel, target))
            else:
                links_check = full  # not a link
                files.append((rel, full))

    return dirs, files, links


def build_image_header(flags, image_size, hdr_dir_size, dir_offset,
                       boot_ino, script_ino, chain_paddr, mountpoint):
    """Build the image_header structure."""
    mp_bytes = mountpoint.encode('ascii') + b'\x00'
    # Header: 7 sig + 1 flags + 4 image_size + 4 hdr_dir_size + 4 dir_offset
    #        + 16 boot_ino + 4 script_ino + 4 chain_paddr + 40 spare + 4 mountflags
    #        + mountpoint
    header_size = 88 + len(mp_bytes)
    header_size = align4(header_size)

    buf = bytearray(header_size)
    buf[0:7] = IMAGE_SIG
    buf[7] = flags
    struct.pack_into('<I', buf, 8, image_size)      # placeholder, patched later
    struct.pack_into('<I', buf, 12, hdr_dir_size)    # placeholder, patched later
    struct.pack_into('<I', buf, 16, header_size)     # dir_offset = header size
    for i in range(4):
        struct.pack_into('<I', buf, 20 + i*4, boot_ino[i])
    struct.pack_into('<I', buf, 36, script_ino)
    struct.pack_into('<I', buf, 40, chain_paddr)
    # spare[10] = zeros (already zero)
    # mountflags = 0
    buf[88:88+len(mp_bytes)] = mp_bytes

    return bytes(buf)


def compute_checksum(data):
    """Compute IFS image trailer checksum."""
    total = 0
    for i in range(0, len(data) - 4, 4):
        total += struct.unpack_from('<I', data, i)[0]
        total &= 0xffffffff
    return (~total + 1) & 0xffffffff


def main():
    p = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--reference', required=True,
                   help='Decompressed reference IFS (for startup section + metadata)')
    p.add_argument('--tree', required=True,
                   help='Directory tree to pack into the IFS')
    p.add_argument('--output', required=True,
                   help='Output decompressed IFS path')
    args = p.parse_args()

    # Parse reference
    with open(args.reference, 'rb') as f:
        ref_data = f.read()

    startup, ihdr, orig_entries = parse_reference(ref_data)
    startup_size = len(startup)

    print(f"[build] reference: {len(ref_data):,} bytes, {len(orig_entries)} entries")
    print(f"[build] startup: {startup_size:,} bytes")

    # Scan tree
    dirs, files, links = scan_tree(args.tree)
    print(f"[build] tree: {len(dirs)} dirs, {len(files)} files, {len(links)} links")

    # Also collect symlinks from the reference that aren't in the tree
    # (os.walk doesn't follow symlinks, and extracted trees may not preserve them)
    ref_links = {p: e for p, e in orig_entries.items() if e['ftype'] == S_IFLNK}
    tree_link_paths = set(l[0] for l in links)
    for path, entry in ref_links.items():
        if path not in tree_link_paths:
            links.append((path, entry['target']))

    print(f"[build] total links (tree + reference): {len(links)}")

    # Build dirents
    # Strategy: use original metadata if available, else defaults
    next_ino = max((e['ino'] for e in orig_entries.values()
                    if e['ino'] < 0x80000000), default=0) + 1

    def get_meta(path, ftype):
        """Get metadata from reference or use defaults."""
        if path in orig_entries and orig_entries[path]['ftype'] == ftype:
            e = orig_entries[path]
            return e['ino'], e['mode'], e['gid'], e['uid'], e['mtime'], e['extattr']
        nonlocal next_ino
        ino = next_ino
        next_ino += 1
        if ftype == S_IFDIR:
            mode = S_IFDIR | 0o755
        elif ftype == S_IFLNK:
            mode = S_IFLNK | 0o777
        else:
            mode = S_IFREG | 0o755
        return ino, mode, 0, 0, 0, 0

    # Phase 1: Build dirent records (file_offset placeholder = 0)
    dirent_records = []

    # Directories first
    for d in dirs:
        ino, mode, gid, uid, mtime, extattr = get_meta(d, S_IFDIR)
        rec = build_dirent_dir(d, ino, mode, gid, uid, mtime, extattr)
        dirent_records.append(('dir', d, rec))

    # Files
    file_data_list = []
    for rel_path, full_path in files:
        with open(full_path, 'rb') as f:
            content = f.read()
        ino, mode, gid, uid, mtime, extattr = get_meta(rel_path, S_IFREG)
        # file_offset is placeholder 0, will be patched in phase 2
        rec = build_dirent_reg(rel_path, ino, mode, gid, uid, mtime, 0, len(content), extattr)
        dirent_records.append(('file', rel_path, rec))
        file_data_list.append(content)

    # Symlinks
    for rel_path, target in links:
        ino, mode, gid, uid, mtime, extattr = get_meta(rel_path, S_IFLNK)
        rec = build_dirent_link(rel_path, target, ino, mode, gid, uid, mtime, extattr)
        dirent_records.append(('link', rel_path, rec))

    # Build image_header
    header = build_image_header(
        ihdr['flags'], 0, 0,  # image_size and hdr_dir_size are placeholders
        0,  # dir_offset placeholder
        ihdr['boot_ino'], ihdr['script_ino'],
        ihdr['chain_paddr'], ihdr['mountpoint'])

    dir_offset = len(header)

    # Calculate dirent region size
    dirent_blob = b''.join(rec for _, _, rec in dirent_records)
    dirent_blob += b'\x00\x00'  # zero terminator
    hdr_dir_size = dir_offset + len(dirent_blob)

    # File data starts at aligned boundary after dirents
    file_data_start = align4(hdr_dir_size)
    file_data_start = (file_data_start + 4095) & ~4095  # page-align

    # Phase 2: Patch file_offset in dirent records
    current_offset = file_data_start
    file_idx = 0
    patched_dirents = bytearray()

    for entry_type, path, rec in dirent_records:
        if entry_type == 'file':
            # Patch offset at byte 24 and size at byte 28
            rec_mut = bytearray(rec)
            struct.pack_into('<I', rec_mut, 24, current_offset)
            content = file_data_list[file_idx]
            struct.pack_into('<I', rec_mut, 28, len(content))
            current_offset += len(content)
            current_offset = align4(current_offset)
            file_idx += 1
            patched_dirents.extend(rec_mut)
        else:
            patched_dirents.extend(rec)

    patched_dirents.extend(b'\x00\x00')  # zero terminator

    # Build file data blob
    file_blob = bytearray()
    for content in file_data_list:
        pad = file_data_start + len(file_blob)  # absolute offset
        # Just append, alignment was handled in offset calculation
        file_blob.extend(content)
        # Pad to 4-byte alignment
        remainder = len(file_blob) % 4
        if remainder:
            file_blob.extend(b'\x00' * (4 - remainder))

    # Calculate total image size
    total_data = file_data_start + len(file_blob)
    total_aligned = (total_data + 4095) & ~4095
    image_size = total_aligned + 4  # +4 for trailer checksum

    # Patch image_header
    header_mut = bytearray(header)
    struct.pack_into('<I', header_mut, 8, image_size)
    struct.pack_into('<I', header_mut, 12, hdr_dir_size)
    struct.pack_into('<I', header_mut, 16, dir_offset)

    # Assemble imagefs
    imagefs = bytearray(image_size)
    imagefs[:len(header_mut)] = header_mut
    imagefs[dir_offset:dir_offset+len(patched_dirents)] = patched_dirents
    imagefs[file_data_start:file_data_start+len(file_blob)] = file_blob

    # Compute and write trailer checksum
    cksum = compute_checksum(imagefs)
    struct.pack_into('<I', imagefs, image_size - 4, cksum)

    # Build complete IFS: startup + imagefs
    output = bytearray(startup)
    # Patch startup_header
    new_stored = len(startup) + len(imagefs)
    struct.pack_into('<I', output, 0x24, new_stored)  # stored_size
    struct.pack_into('<I', output, 0x2c, len(imagefs))  # imagefs_size
    output[6] = output[6] & ~0x1c  # clear compression bits (decompressed)

    output.extend(imagefs)

    with open(args.output, 'wb') as f:
        f.write(output)

    print(f"[build] dirents: {len(dirent_records)} entries, {len(patched_dirents)} bytes")
    print(f"[build] file data: {len(file_data_list)} files, {len(file_blob):,} bytes")
    print(f"[build] imagefs: {image_size:,} bytes")
    print(f"[build] total: {len(output):,} bytes")
    print(f"[build] wrote {args.output}")


if __name__ == '__main__':
    main()
