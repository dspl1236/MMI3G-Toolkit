#!/usr/bin/env python3
"""
extract_f3s_efs.py — Extract files from MMI3G uncompressed EFS images.

Target: efs-system.efs variants 41 and 51 from K0942_3 / K0942_4 / K0942_6
(i.e. MMI 3G+ non-Plus and non-High-Plus variants). Does NOT support the
compressed variant 61 — use QNX's inflator for that.

Strategy: scan-based dirent discovery. The image is mostly sequential with
dirent metadata interleaved with file content. We find every stat_s record
(signature 14 00 ?? [48A]) and walk back to locate its dirent header. Then
we extract file data by finding the next dirent after it (file content lives
between the stat and the next dirent).

Output: filesystem tree dumped into the output directory, preserving
modes (best-effort) and paths.
"""
import argparse
import os
import re
import struct
import sys


FILE_TYPE_NAMES = {
    0x1: 'FIFO',
    0x2: 'CHR',
    0x4: 'DIR',
    0x6: 'BLK',
    0x8: 'FILE',
    0xa: 'LINK',
    0xc: 'SOCK',
}


def u16(data, off): return struct.unpack_from('<H', data, off)[0]
def u32(data, off): return struct.unpack_from('<I', data, off)[0]


def scan_dirents(data):
    """Scan the entire image for dirent records. Returns list of dicts."""
    entries = []
    i = 0
    while i < len(data) - 24:
        # stat_s signature: struct_size=20 (14 00), then mode where high nibble is file type
        if data[i] == 0x14 and data[i + 1] == 0x00:
            mode = u16(data, i + 2)
            ftype = (mode >> 12) & 0xf
            if ftype in FILE_TYPE_NAMES:
                # Look back for dirent header (08 00 mv nl)
                for back in range(4, 140, 4):
                    hdr_off = i - 8 - back
                    if hdr_off < 0:
                        break
                    if data[hdr_off] == 0x08 and data[hdr_off + 1] == 0x00:
                        namelen = data[hdr_off + 3]
                        if namelen == 0 or namelen > 128:
                            continue
                        name_space = (namelen + 3) & ~3
                        if hdr_off + 8 + name_space != i:
                            continue
                        # Valid dirent
                        raw_name = data[hdr_off + 8:hdr_off + 8 + namelen]
                        name = raw_name.rstrip(b'\x00').decode('utf-8', errors='replace')
                        if not name or '\x00' in name[:-1]:
                            continue
                        entries.append({
                            'hdr_off': hdr_off,
                            'stat_off': i,
                            'name': name,
                            'ftype': FILE_TYPE_NAMES[ftype],
                            'mode': mode,
                            'uid': u32(data, i + 4),
                            'gid': u32(data, i + 8),
                            'mtime': u32(data, i + 12),
                            'ctime': u32(data, i + 16),
                            'first_unit': u16(data, hdr_off + 4),
                            'first_index': u16(data, hdr_off + 6),
                        })
                        break
        i += 1
    return entries


def walk_iwlyfmbp_end(data, content_start, image_len):
    """If the given offset has an iwlyfmbp filehdr, walk the block chain
    and return the offset past the EOF cmphdr. Returns None if not wrapped
    or if the walk fails.

    We sanity-check each cmphdr against the file's declared blksize —
    if usize/pusize exceed blksize, the chain has gone off the rails
    (probably followed a bad 'next' pointer into subsequent-file data).
    In that case we bail rather than blindly following pointers until we
    coincidentally hit next==0 somewhere in garbage.
    """
    if content_start + 16 > image_len:
        return None
    if data[content_start:content_start + 8] != b'iwlyfmbp':
        return None

    filehdr_usize = struct.unpack_from('<I', data, content_start + 8)[0]
    blksize = struct.unpack_from('<H', data, content_start + 12)[0]
    if blksize not in (4096, 8192, 16384, 32768):
        return None  # invalid blksize

    off = content_start + 16  # past filehdr
    blocks = 0
    total_usize = 0
    while off + 8 <= image_len:
        prev = struct.unpack_from('<H', data, off)[0]
        next_field = struct.unpack_from('<H', data, off + 2)[0]
        pusize = struct.unpack_from('<H', data, off + 4)[0]
        usize = struct.unpack_from('<H', data, off + 6)[0]

        if next_field == 0:
            # EOF marker — file ends right after this cmphdr
            return off + 8

        # Sanity: per-block uncompressed sizes cannot exceed blksize
        if usize > blksize or pusize > blksize:
            return None
        # Sanity: 'next' points to next cmphdr and must be at least 9
        # (cmphdr=8 + at least 1 compressed byte) and at most blksize+8
        if next_field < 9 or next_field > blksize + 256:
            return None

        total_usize += usize
        # Sanity: running total shouldn't exceed filehdr's declared usize
        # (give a little slack — up to +1 blksize)
        if total_usize > filehdr_usize + blksize:
            return None

        off += next_field
        blocks += 1
        if blocks > 8192:
            return None
    return None


def drop_entries_inside_wrapped_blobs(entries, data):
    """Some of our 'entries' are false positives: byte patterns inside
    large QNX-deflate-wrapped binaries that happen to match the
    08 00 00 NL ... 14 00 XX 8Y dirent signature. A huge file like
    'dspwatch' (740 KB uncompressed, ~440 KB compressed) can contain
    hundreds of these coincidences.

    Strategy: sort by stat_off, walk forward; when a FILE entry's content
    is iwlyfmbp-wrapped, compute its true end via the block chain. Any
    subsequent entry that starts before that end is spurious — discard it.
    The end-of-blob offset becomes the content_end for the wrapper file.
    """
    sorted_entries = sorted(entries, key=lambda e: e['stat_off'])
    kept = []
    skip_until = 0  # offset inside wrapped blob; entries before this are spurious
    wrapped_end_of = {}  # stat_off -> true content_end

    for e in sorted_entries:
        if e['hdr_off'] < skip_until:
            continue  # inside a previously-identified wrapped blob
        kept.append(e)
        if e['ftype'] == 'FILE':
            content_start = e['stat_off'] + 20
            true_end = walk_iwlyfmbp_end(data, content_start, len(data))
            if true_end is not None:
                wrapped_end_of[e['stat_off']] = true_end
                skip_until = true_end
    return kept, wrapped_end_of


def compute_file_content_range(entries, data):
    """For each FILE entry, compute where its content begins and ends.

    Content starts right after the stat_s (stat_off + 20) and extends to
    right before the next dirent header. If the file is a QNX-deflate
    wrapped binary, use the block-chain end (which may be past the next
    apparent dirent — those are false positives already filtered out).
    """
    entries, wrapped_end_of = drop_entries_inside_wrapped_blobs(entries, data)
    for idx, e in enumerate(entries):
        content_start = e['stat_off'] + 20
        if idx + 1 < len(entries):
            content_end = entries[idx + 1]['hdr_off']
        else:
            content_end = len(data)
        # If wrapped, trust the block-chain end over the next-dirent heuristic
        if e['stat_off'] in wrapped_end_of:
            content_end = wrapped_end_of[e['stat_off']]
        e['content_start'] = content_start
        e['content_end'] = content_end
        e['content_size'] = content_end - content_start
    return entries


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('image', help='Path to efs-system.efs')
    ap.add_argument('outdir', help='Output directory for extracted files')
    ap.add_argument('--only', help='Only extract files matching this substring')
    ap.add_argument('--list', action='store_true', help='Just list, do not extract')
    ap.add_argument('--dirs-only', action='store_true', help='Show directories only')
    args = ap.parse_args()

    with open(args.image, 'rb') as f:
        data = f.read()
    print(f"[+] {args.image}  ({len(data):,} bytes)")

    print("[+] Scanning for dirent records...")
    entries = scan_dirents(data)
    print(f"[+] Found {len(entries)} entries")

    # Compute content ranges
    entries = compute_file_content_range(entries, data)

    # Stats
    types = {}
    for e in entries:
        types[e['ftype']] = types.get(e['ftype'], 0) + 1
    print(f"    by type: {types}")

    if args.dirs_only:
        print()
        for e in entries:
            if e['ftype'] == 'DIR':
                print(f"  DIR  {e['name']}")
        return 0

    if args.list:
        print()
        for e in entries:
            if args.only and args.only.lower() not in e['name'].lower():
                continue
            if e['ftype'] == 'FILE':
                print(f"  {e['ftype']:<4} {e['name']!r:<40} "
                      f"content=0x{e['content_start']:x}..0x{e['content_end']:x} "
                      f"size={e['content_size']:,}")
            else:
                print(f"  {e['ftype']:<4} {e['name']}")
        return 0

    # Extract files
    os.makedirs(args.outdir, exist_ok=True)
    extracted = 0
    skipped = 0
    for e in entries:
        if e['ftype'] != 'FILE':
            continue
        if args.only and args.only.lower() not in e['name'].lower():
            continue
        # Clean name - no path traversal
        name = os.path.basename(e['name'])
        if not name or name.startswith('.'):
            continue
        # Deduplicate
        target = os.path.join(args.outdir, name)
        if os.path.exists(target):
            base, ext = os.path.splitext(name)
            target = os.path.join(args.outdir, f"{base}_0x{e['hdr_off']:x}{ext}")
        sz = e['content_size']
        if sz <= 0 or sz > 100 * 1024 * 1024:
            skipped += 1
            continue
        with open(target, 'wb') as f:
            f.write(data[e['content_start']:e['content_end']])
        extracted += 1

    print(f"\n[+] Extracted {extracted} files to {args.outdir}/")
    if skipped:
        print(f"    Skipped {skipped} files (zero-size or too big)")

    return 0


if __name__ == '__main__':
    sys.exit(main())
