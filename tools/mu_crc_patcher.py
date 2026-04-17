#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
mu_crc_patcher.py — recompute metainfo2.txt checksums for a modified MMI3G/MMI3G+
firmware image (ifs-root.ifs, efs-system.efs, etc.).

Harman's SWDL (SoftWare DownLoader) update system verifies firmware files with
plain zlib/IEEE CRC32 (poly 0xedb88320) per 512 KB block. There are NO
cryptographic signatures on firmware images. This tool makes modified images
pass verification by recomputing the per-block CRCs and patching the
metainfo2.txt manifest.

See research/FIRMWARE_UPDATE_FORMAT.md for the full format specification.

Usage:

    # Patch CRCs for a modified ifs-root.ifs (default: variant 41 entry)
    python3 mu_crc_patcher.py \\
        --metainfo /path/to/metainfo2.txt \\
        --file     /path/to/modified/ifs-root.ifs \\
        --section  'MU9411\\ifs-root\\41\\default\\Application'

    # Patch and also update MetafileChecksum (K0942_6+ firmware)
    python3 mu_crc_patcher.py \\
        --metainfo /path/to/metainfo2.txt \\
        --file     /path/to/modified/ifs-root.ifs \\
        --section  'MU9498\\ifs-root\\61\\default\\Application' \\
        --update-metafile-checksum

    # Dry run (show what would change, don't write)
    python3 mu_crc_patcher.py \\
        --metainfo /path/to/metainfo2.txt \\
        --file     /path/to/modified/ifs-root.ifs \\
        --section  '...' \\
        --dry-run

    # Generate a skipCrc=true update.txt instead of recomputing
    # (alternative to --section; patches ALL CRC= entries in update.txt)
    python3 mu_crc_patcher.py \\
        --update-txt /path/to/update.txt \\
        --skip-crc \\
        --output    /path/to/update_patched.txt

Safety notes:

  * This tool only patches CHECKSUMS — it does NOT modify the firmware image
    itself. You are responsible for producing a valid modified image.
  * The flasher also performs a boot-time signature verification through
    procnto-instr loading an LZO-compressed ifs-root.ifs. If your modified
    IFS doesn't decompress correctly, the MMI will not boot.
  * Always keep a pristine copy of the original metainfo2.txt before patching.
  * Field testing should start with trivial modifications (e.g. change a
    single byte of a log string in a non-critical binary) before attempting
    substantive changes.
"""

import argparse
import os
import re
import sys
import zlib

BLOCK_SIZE = 524288  # 512 KB — the fixed block size used by Harman's SWDL


# ---------------------------------------------------------------------------
# CRC computation
# ---------------------------------------------------------------------------

def crc32_block(data: bytes) -> int:
    """zlib/IEEE CRC32 — same as the algorithm used by Harman's SWDL for
    per-block and file-wide checksums in metainfo2.txt.

    Empirically verified: first 10 blocks of K0942_4 MU9411 variant 41
    ifs-root.ifs produce CRCs matching the metainfo2.txt entries exactly.
    """
    return zlib.crc32(data) & 0xFFFFFFFF


def compute_file_crcs(path: str) -> tuple[int, list[int]]:
    """Return (file_size, [block_crcs]) for the given file, where block_crcs
    is a list of CRC32 values over consecutive 512 KB chunks (last chunk
    may be shorter than 512 KB)."""
    size = os.path.getsize(path)
    crcs = []
    with open(path, 'rb') as f:
        while True:
            chunk = f.read(BLOCK_SIZE)
            if not chunk:
                break
            crcs.append(crc32_block(chunk))
    return size, crcs


# ---------------------------------------------------------------------------
# metainfo2.txt parsing and patching
# ---------------------------------------------------------------------------

# Section header is [backslash-separated-name] on its own line.
SECTION_RE = re.compile(rb'^\[([^\]]+)\]\s*$')
# Keys in metainfo2 are KEY = "VALUE" with CRLF line endings.
KEY_RE = re.compile(rb'^([A-Za-z][A-Za-z0-9_]*)\s*=\s*"([^"]*)"\s*$')


def find_section_block(metainfo: bytes, section_name: str) -> tuple[int, int]:
    """Locate the byte range in `metainfo` that covers the given section.

    Returns (start_byte, end_byte) — start is the first byte after the
    section header line, end is the byte before the next section header
    (or end of file). Raises ValueError if the section is not found.

    Section names use literal backslashes, e.g.
    "MU9411\\ifs-root\\41\\default\\Application".
    """
    target = b'[' + section_name.encode('utf-8') + b']'
    lines = metainfo.split(b'\n')
    offset = 0
    section_start = None
    for line in lines:
        stripped = line.rstrip(b'\r')
        if stripped == target:
            section_start = offset + len(line) + 1
            # continue scanning for the next header
        elif section_start is not None:
            m = SECTION_RE.match(stripped)
            if m:
                return section_start, offset
        offset += len(line) + 1  # +1 for the '\n' we split on
    if section_start is None:
        raise ValueError(f"Section [{section_name}] not found in metainfo2")
    return section_start, offset


def patch_section_crcs(
    metainfo: bytes,
    section_name: str,
    file_size: int,
    block_crcs: list[int],
    *,
    keep_trailing_blank_lines: bool = True,
) -> bytes:
    """Return a new metainfo bytes object with the named section's FileSize,
    CheckSum, and CheckSum1..CheckSumN keys replaced with the given values.

    All other keys in the section are preserved verbatim, as are comments
    and line endings. If there are existing CheckSum{k} keys past len(crcs)-1
    they are removed. If there are fewer than we need, new ones are appended.
    """
    start, end = find_section_block(metainfo, section_name)
    body = metainfo[start:end]

    # Parse the section into an ordered list of (key, value, raw_line) entries.
    # Non-key lines (comments, blanks, continuations) are preserved as-is.
    out_lines = []
    key_positions = {}  # key -> index into out_lines
    for line in body.split(b'\n'):
        stripped = line.rstrip(b'\r')
        m = KEY_RE.match(stripped)
        if m:
            key = m.group(1).decode('ascii')
            key_positions[key] = len(out_lines)
            out_lines.append((key, m.group(2).decode('ascii', errors='replace'), line))
        else:
            out_lines.append((None, None, line))

    def set_key(key: str, new_value: str):
        new_line = f'{key} = "{new_value}"\r'.encode('ascii')
        if key in key_positions:
            idx = key_positions[key]
            out_lines[idx] = (key, new_value, new_line)
        else:
            # Insert before any blank trailing lines, or at end
            # For simplicity, append before the last run of empty lines
            insert_at = len(out_lines)
            while insert_at > 0 and out_lines[insert_at - 1][2].rstrip(b'\r\n') == b'':
                insert_at -= 1
            out_lines.insert(insert_at, (key, new_value, new_line))
            # Rebuild key_positions since we shifted things
            for k, v in list(key_positions.items()):
                if v >= insert_at:
                    key_positions[k] = v + 1
            key_positions[key] = insert_at

    def remove_key(key: str):
        if key in key_positions:
            idx = key_positions[key]
            del out_lines[idx]
            del key_positions[key]
            for k, v in list(key_positions.items()):
                if v > idx:
                    key_positions[k] = v - 1

    set_key('FileSize', str(file_size))
    set_key('CheckSum', f'{block_crcs[0]:x}')  # lowercase hex, no leading zero strip
    for i, crc in enumerate(block_crcs[1:], start=1):
        set_key(f'CheckSum{i}', f'{crc:x}')
    # Remove any leftover CheckSum{k} keys past the end of our list
    max_idx = len(block_crcs) - 1
    for k in list(key_positions.keys()):
        if k.startswith('CheckSum') and k != 'CheckSum':
            try:
                idx = int(k[len('CheckSum'):])
            except ValueError:
                continue
            if idx > max_idx:
                remove_key(k)

    # Rebuild the section body
    new_body = b'\n'.join(line for _, _, line in out_lines)
    return metainfo[:start] + new_body + metainfo[end:]


def compute_metafile_checksum(metainfo: bytes) -> int:
    """Compute MetafileChecksum: the CRC32 of the metainfo2.txt contents
    with the MetafileChecksum line itself removed.

    Only present in K0942_6 and later firmware; older MUs (K0942_3, K0942_4)
    do not carry this field.
    """
    # Remove the MetafileChecksum = "xxx" line entirely (any case)
    stripped = re.sub(
        rb'^MetafileChecksum\s*=\s*"[0-9a-fA-F]*"\s*\r?\n?',
        b'',
        metainfo,
        flags=re.MULTILINE,
    )
    return crc32_block(stripped)


def patch_metafile_checksum(metainfo: bytes) -> bytes:
    """Update (or insert) the MetafileChecksum line to match the file's
    current content."""
    new_crc = compute_metafile_checksum(metainfo)
    new_line_bytes = f'MetafileChecksum = "{new_crc:x}"\r\n'.encode('ascii')
    if re.search(rb'^MetafileChecksum\s*=', metainfo, flags=re.MULTILINE):
        return re.sub(
            rb'^MetafileChecksum\s*=\s*"[0-9a-fA-F]*"\s*\r?\n?',
            new_line_bytes,
            metainfo,
            flags=re.MULTILINE,
        )
    else:
        # Insert after the [common] section's first line
        m = re.search(rb'^\[common\]\s*\r?\n', metainfo, flags=re.MULTILINE)
        if not m:
            raise ValueError("Cannot find [common] section to insert MetafileChecksum")
        pos = m.end()
        return metainfo[:pos] + new_line_bytes + metainfo[pos:]


# ---------------------------------------------------------------------------
# update.txt skipCrc mode
# ---------------------------------------------------------------------------

def apply_skip_crc(update_txt: bytes) -> bytes:
    """Replace all 'CRC = xxx' lines in update.txt with 'skipCrc = true'.

    This mirrors the pattern Harman themselves use in
    MU9498/preUpdateScript when hardware-sample detection disagrees with
    the update manifest:

        echo 's/^CRC\\ \\=\\ .*/skipCrc\\ \\=\\ true/g' > /tmp/sed_scr
        sed -f /tmp/sed_scr $UPDATE_TXT > /HBpersistence/SWDL/update_patched.txt

    The flasher honors skipCrc=true as a first-class flag and will write
    the file data without CRC verification.
    """
    return re.sub(
        rb'^CRC\s*=\s*.*$',
        b'skipCrc = true',
        update_txt,
        flags=re.MULTILINE,
    )


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main(argv=None):
    p = argparse.ArgumentParser(
        description='Recompute MMI3G firmware update CRCs',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )

    # metainfo2 mode (recompute CRCs)
    p.add_argument('--metainfo', help='Path to metainfo2.txt (for CRC patching)')
    p.add_argument('--file', help='Path to modified firmware image')
    p.add_argument('--section', help='Section name in metainfo2 to patch, e.g. '
                   r'"MU9411\ifs-root\41\default\Application"')
    p.add_argument('--update-metafile-checksum', action='store_true',
                   help='Also update MetafileChecksum (K0942_6+ firmware)')

    # update.txt mode (skip-CRC)
    p.add_argument('--update-txt', help='Path to update.txt (for skipCrc mode)')
    p.add_argument('--skip-crc', action='store_true',
                   help='Replace all CRC= entries with skipCrc=true')

    # Common
    p.add_argument('--output', help='Output path (default: overwrite input)')
    p.add_argument('--dry-run', action='store_true',
                   help="Show what would change, don't write")

    args = p.parse_args(argv)

    # Mode selection
    if args.skip_crc:
        return _main_skip_crc(args)
    elif args.metainfo and args.file and args.section:
        return _main_patch_crcs(args)
    else:
        p.print_help()
        return 1


def _main_patch_crcs(args):
    print(f"[1/4] Reading firmware image: {args.file}")
    size, crcs = compute_file_crcs(args.file)
    print(f"      size={size} bytes, blocks={len(crcs)} (last block {size - (len(crcs)-1)*BLOCK_SIZE} bytes)")

    print(f"[2/4] Reading metainfo: {args.metainfo}")
    with open(args.metainfo, 'rb') as f:
        metainfo = f.read()

    print(f"[3/4] Patching section: [{args.section}]")
    # Show before/after for the first few CRCs
    try:
        start, end = find_section_block(metainfo, args.section)
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2
    body_before = metainfo[start:end].decode('ascii', errors='replace')
    old_size_m = re.search(r'FileSize\s*=\s*"(\d+)"', body_before)
    old_crc_m = re.search(r'CheckSum\s*=\s*"([0-9a-fA-F]+)"', body_before)
    print(f"      OLD: FileSize={old_size_m.group(1) if old_size_m else '?'}, "
          f"CheckSum=0x{old_crc_m.group(1).lower() if old_crc_m else '?'}")
    print(f"      NEW: FileSize={size}, CheckSum=0x{crcs[0]:08x}")

    new_metainfo = patch_section_crcs(metainfo, args.section, size, crcs)

    if args.update_metafile_checksum:
        print(f"[4/4] Updating MetafileChecksum")
        new_metainfo = patch_metafile_checksum(new_metainfo)
        new_mfc = compute_metafile_checksum(new_metainfo)
        print(f"      MetafileChecksum = {new_mfc:x}")
    else:
        print(f"[4/4] (skipping MetafileChecksum update — not requested)")

    if args.dry_run:
        print("\n[DRY RUN] No files written. Changed bytes:", len(new_metainfo) - len(metainfo))
        return 0

    output = args.output or args.metainfo
    with open(output, 'wb') as f:
        f.write(new_metainfo)
    print(f"\n[DONE] Wrote {output} ({len(new_metainfo)} bytes)")
    return 0


def _main_skip_crc(args):
    if not args.update_txt:
        print("ERROR: --skip-crc requires --update-txt", file=sys.stderr)
        return 1
    print(f"[1/2] Reading update.txt: {args.update_txt}")
    with open(args.update_txt, 'rb') as f:
        update_txt = f.read()

    count_before = len(re.findall(rb'^CRC\s*=\s*', update_txt, flags=re.MULTILINE))
    print(f"      found {count_before} CRC= entries")

    new_update_txt = apply_skip_crc(update_txt)
    count_after = len(re.findall(rb'^skipCrc\s*=\s*true', new_update_txt, flags=re.MULTILINE))
    print(f"[2/2] Replaced with {count_after} skipCrc=true entries")

    if args.dry_run:
        print("\n[DRY RUN] No files written.")
        return 0

    output = args.output or args.update_txt
    with open(output, 'wb') as f:
        f.write(new_update_txt)
    print(f"\n[DONE] Wrote {output}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
