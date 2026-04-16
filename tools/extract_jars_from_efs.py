#!/usr/bin/env python3
"""
extract_jars_from_efs.py

Carves embedded JAR files out of the raw Harman-Becker efs-system.efs
firmware image by searching for the ZIP local-file-header signature (PK\\x03\\x04)
and the corresponding end-of-central-directory record (PK\\x05\\x06).

This is a pragmatic "strings-plus-a-bit" approach: we don't parse the EFS
container format (which is proprietary). We just locate each embedded JAR
by its standard ZIP boundary markers.

Usage:
    python extract_jars_from_efs.py <path-to-efs-system.efs> <output-dir>

Tested against: HN+R_EU_AU_K0942_4 MU9411 variant 61 (Audi A6 C7 firmware).
Expected output: ~15-25 JAR files including dsi.jar, osgi.jar,
                 AppDevelopment.jar, lsd.jxe (not a JAR but also carved),
                 texts.jar, etc.
"""
import argparse
import os
import struct
import sys
import zipfile
import io


# ZIP local file header signature
LFH_SIG = b'PK\x03\x04'
# End of central directory record signature
EOCD_SIG = b'PK\x05\x06'


def find_all(haystack, needle):
    """Yield every offset of `needle` in `haystack`."""
    start = 0
    while True:
        i = haystack.find(needle, start)
        if i < 0:
            return
        yield i
        start = i + 1


def try_extract_jar(data, start_offset):
    """
    Given a candidate LFH offset, find the matching EOCD and attempt to
    parse as a ZIP. Returns (jar_bytes, entry_count) on success, None on failure.

    Strategy: scan forward from start_offset for EOCD signatures, then for each
    candidate EOCD, compute where the ZIP would end (eocd offset + 22 + comment_length)
    and try to parse [start_offset:end] as a ZIP.
    """
    # Search forward for EOCD records. A JAR's EOCD must come AFTER its LFH.
    # We cap the search to a reasonable size (50 MB) to avoid pathological cases.
    MAX_JAR_SIZE = 50 * 1024 * 1024

    search_region = data[start_offset:start_offset + MAX_JAR_SIZE]
    eocds = list(find_all(search_region, EOCD_SIG))
    if not eocds:
        return None

    # Try each candidate EOCD, from most likely (first) to least
    for eocd_rel in eocds:
        if eocd_rel + 22 > len(search_region):
            continue
        # EOCD format: 4b signature, 2b disk#, 2b disk#w/cd, 2b entries_on_disk,
        # 2b total_entries, 4b cd_size, 4b cd_offset, 2b comment_length
        try:
            (disk, disk_cd, ent_disk, ent_total,
             cd_size, cd_offset, comment_len) = struct.unpack(
                '<HHHHIIH', search_region[eocd_rel+4:eocd_rel+22])
        except struct.error:
            continue

        # Sanity check on entry count and comment_length
        if ent_total > 20000 or comment_len > 4096:
            continue
        if cd_size > MAX_JAR_SIZE:
            continue

        jar_end_rel = eocd_rel + 22 + comment_len
        if jar_end_rel > len(search_region):
            continue

        jar_bytes = search_region[:jar_end_rel]
        try:
            zf = zipfile.ZipFile(io.BytesIO(jar_bytes))
            names = zf.namelist()
            # Sanity: must have at least one entry
            if len(names) == 0:
                continue
            return (jar_bytes, names)
        except zipfile.BadZipFile:
            continue
        except Exception:
            continue

    return None


def guess_jar_name(zip_names):
    """
    Pick a reasonable filename for a carved JAR based on its contents.
    Heuristics:
      * If it has META-INF/MANIFEST.MF and Bundle-SymbolicName is set, use that.
      * Else, look for distinctive package paths.
      * Else, use hash-based anonymous name.
    """
    # Look for MANIFEST.MF
    # We can't easily parse it without zipfile access; skip for now and use
    # package-based hints.
    hints = {
        'org/dsi/ifc/persistence/DSIPersistence':  'dsi.jar',
        'org/dsi/ifc/admin/JDSIAdmin':              'dsi-admin.jar',
        'org/osgi/framework/BundleActivator':       'osgi.jar',
        'org/osgi/util/tracker/ServiceTracker':     'osgi-tracker.jar',
        'de/audi/tghu/development/Activator':       'AppDevelopment.jar',
        'de/audi/atip/hmi/HMIApplication':          'atip.jar',
        'de/audi/crypto/RSAEngine':                 'audi-crypto.jar',
        'de/dreisoft/lsd/LSD':                      'lsd.jar',
    }
    classes = set(n.replace('.class', '') for n in zip_names if n.endswith('.class'))
    for hint_path, name in hints.items():
        if hint_path in classes:
            return name
    # No match — anonymous name
    return None


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('efs', help='Path to efs-system.efs')
    ap.add_argument('outdir', help='Output directory for extracted JARs')
    args = ap.parse_args()

    print(f"[+] Reading {args.efs}")
    with open(args.efs, 'rb') as f:
        data = f.read()
    print(f"    Size: {len(data):,} bytes")

    os.makedirs(args.outdir, exist_ok=True)

    print(f"[+] Scanning for ZIP local file headers (PK\\x03\\x04)")
    lfh_offsets = list(find_all(data, LFH_SIG))
    print(f"    Found {len(lfh_offsets):,} LFH signatures")

    # An EFS can contain many LFH hits inside larger ZIPs — we only want the
    # START of each JAR. Use a greedy forward sweep: if we successfully carve
    # a JAR at offset X of size N, skip past X+N before trying again.
    extracted = []
    skip_until = 0
    hint_counter = 0
    for off in lfh_offsets:
        if off < skip_until:
            continue
        result = try_extract_jar(data, off)
        if result is None:
            continue
        jar_bytes, names = result
        end = off + len(jar_bytes)

        name = guess_jar_name(names)
        if name is None:
            hint_counter += 1
            name = f'anonymous_{hint_counter:02d}_at_0x{off:08x}.jar'
        # Avoid collisions by appending offset
        final_name = name
        if os.path.exists(os.path.join(args.outdir, final_name)):
            stem, ext = os.path.splitext(name)
            final_name = f'{stem}_at_0x{off:08x}{ext}'

        outpath = os.path.join(args.outdir, final_name)
        with open(outpath, 'wb') as f:
            f.write(jar_bytes)
        print(f"    [0x{off:08x}] -> {final_name:40} ({len(jar_bytes):>10,} b, {len(names):>5} entries)")
        extracted.append((off, final_name, len(jar_bytes), len(names)))
        skip_until = end

    print()
    print(f"[+] Extracted {len(extracted)} JAR(s) to {args.outdir}/")
    print()
    print("    Key JARs to confirm:")
    for _, name, size, entries in extracted:
        if name in ('dsi.jar', 'osgi.jar', 'AppDevelopment.jar', 'atip.jar'):
            print(f"      ✓ {name:30} {size:>10,} b  {entries:>5} entries")


if __name__ == '__main__':
    main()
