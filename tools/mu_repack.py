#!/usr/bin/env python3
"""
mu_repack.py — end-to-end firmware modification pipeline.

Wraps the full workflow: extract MU archive → decompress IFS →
let user modify files → patch IFS → recompress → fix CRCs.

Usage:
    # Interactive: opens a working directory for editing
    python3 tools/mu_repack.py \\
        --mu-archive /path/to/8R0906961FB.tar \\
        --variant 41 \\
        --workdir ./work

    # Non-interactive: apply patches directly
    python3 tools/mu_repack.py \\
        --mu-archive /path/to/8R0906961FB.tar \\
        --variant 41 \\
        --replace /usr/apps/MMI3GApplication=./modified_app \\
        --output ./patched_MU/

    # From pre-extracted firmware directory
    python3 tools/mu_repack.py \\
        --mu-dir /path/to/extracted/MU9411/ \\
        --variant 41 \\
        --replace /etc/mmi3g-srv-starter.cfg=./mod_cfg \\
        --output ./patched_MU/
"""
import argparse
import glob
import os
import shutil
import subprocess
import sys
import tarfile

HERE = os.path.dirname(os.path.abspath(__file__))


def find_ifs_root(mu_dir, variant):
    """Locate ifs-root.ifs for the given variant inside an MU directory."""
    # Try standard path: MU*/ifs-root/<variant>/default/ifs-root.ifs
    patterns = [
        os.path.join(mu_dir, '**', 'ifs-root', str(variant), 'default', 'ifs-root.ifs'),
        os.path.join(mu_dir, 'ifs-root', str(variant), 'default', 'ifs-root.ifs'),
    ]
    for pat in patterns:
        hits = glob.glob(pat, recursive=True)
        if hits:
            return hits[0]
    return None


def find_metainfo(mu_dir):
    """Locate metainfo2.txt in or above the MU directory."""
    # Check parent directory (metainfo2 is at the top level of the release)
    for d in [mu_dir, os.path.dirname(mu_dir), os.path.dirname(os.path.dirname(mu_dir))]:
        p = os.path.join(d, 'metainfo2.txt')
        if os.path.exists(p):
            return p
    return None


def run_tool(name, args, desc=None):
    """Run a toolkit tool and check for errors."""
    script = os.path.join(HERE, name)
    cmd = [sys.executable, script] + args
    if desc:
        print(f"\n{'='*60}")
        print(f"  {desc}")
        print(f"{'='*60}")
    rc = subprocess.call(cmd)
    if rc != 0:
        print(f"ERROR: {name} failed (exit {rc})", file=sys.stderr)
        sys.exit(1)
    return rc


def main():
    p = argparse.ArgumentParser(
        description='End-to-end firmware modification pipeline.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__)

    src = p.add_mutually_exclusive_group(required=True)
    src.add_argument('--mu-archive', metavar='FILE',
                     help='.tar or .rar MU archive')
    src.add_argument('--mu-dir', metavar='DIR',
                     help='Pre-extracted MU directory')

    p.add_argument('--variant', type=int, required=True,
                   help='Hardware variant (41, 51, 61, etc.)')
    p.add_argument('--workdir', metavar='DIR',
                   help='Working directory (created if needed). '
                        'In interactive mode, edit files here then re-run.')
    p.add_argument('--replace', action='append', default=[],
                   metavar='IFS_PATH=LOCAL_FILE',
                   help='Replace a file in the IFS (repeatable)')
    p.add_argument('--output', metavar='DIR',
                   help='Output directory for patched firmware')
    p.add_argument('--skip-crc', action='store_true',
                   help='Use skipCrc=true instead of recomputing CRCs')
    p.add_argument('--reference', action='store_true',
                   help='Use reference mode for bit-identical compression '
                        'when files haven\'t changed size')

    args = p.parse_args()

    workdir = args.workdir or os.path.join(os.getcwd(), 'mu_work')
    os.makedirs(workdir, exist_ok=True)

    # --- Step 1: Locate or extract MU directory ---
    if args.mu_archive:
        print(f"[mu_repack] extracting {args.mu_archive}...")
        extract_dir = os.path.join(workdir, 'mu_extracted')
        os.makedirs(extract_dir, exist_ok=True)

        if args.mu_archive.endswith('.tar'):
            with tarfile.open(args.mu_archive) as tf:
                tf.extractall(extract_dir)
        elif args.mu_archive.endswith('.rar'):
            rc = subprocess.call(['unrar', 'x', '-o+', args.mu_archive, extract_dir + '/'])
            if rc != 0:
                print("ERROR: unrar failed. Install unrar.", file=sys.stderr)
                sys.exit(1)
        else:
            print(f"ERROR: unsupported archive format: {args.mu_archive}", file=sys.stderr)
            sys.exit(1)

        mu_dir = extract_dir
        # Find the actual MU subdirectory
        subdirs = [d for d in glob.glob(os.path.join(extract_dir, '**', 'MU*'), recursive=True)
                   if os.path.isdir(d)]
        if subdirs:
            mu_dir = subdirs[0]
    else:
        mu_dir = args.mu_dir

    print(f"[mu_repack] MU directory: {mu_dir}")

    # --- Step 2: Find IFS ---
    ifs_path = find_ifs_root(mu_dir, args.variant)
    if not ifs_path:
        print(f"ERROR: ifs-root.ifs not found for variant {args.variant} in {mu_dir}",
              file=sys.stderr)
        print("Available variants:", file=sys.stderr)
        for f in glob.glob(os.path.join(mu_dir, '**', 'ifs-root', '*'), recursive=True):
            if os.path.isdir(f):
                print(f"  {os.path.basename(f)}", file=sys.stderr)
        sys.exit(1)

    print(f"[mu_repack] IFS: {ifs_path}")

    # --- Step 3: Decompress IFS ---
    decomp_path = os.path.join(workdir, 'ifs_decompressed.ifs')
    extract_dir_path = os.path.join(workdir, 'ifs_files')

    if not os.path.exists(decomp_path):
        run_tool('inflate_ifs.py',
                 [ifs_path, '-o', decomp_path],
                 'Step 1/4: Decompress IFS')
    else:
        print(f"[mu_repack] using cached decompressed IFS: {decomp_path}")

    # --- Step 4: Extract for browsing (optional) ---
    if not os.path.exists(extract_dir_path) and not args.replace:
        run_tool('inflate_ifs.py',
                 [ifs_path, '--extract', extract_dir_path],
                 'Extracting files for browsing')
        print(f"\n[mu_repack] Files extracted to: {extract_dir_path}")
        print(f"[mu_repack] Edit files there, then re-run with --replace flags.")
        print(f"[mu_repack] Example:")
        print(f"  python3 tools/mu_repack.py --mu-dir {mu_dir} --variant {args.variant} \\")
        print(f"      --replace /usr/apps/MMI3GApplication=./your_modified_app \\")
        print(f"      --output ./patched/")
        return

    if not args.replace:
        print("[mu_repack] No --replace specified. Nothing to do.")
        print(f"[mu_repack] Browse: {extract_dir_path}")
        return

    # --- Step 5: Patch IFS ---
    patched_path = os.path.join(workdir, 'ifs_patched.ifs')
    patch_args = [decomp_path, patched_path]
    for r in args.replace:
        patch_args += ['--replace', r]

    run_tool('patch_ifs.py', patch_args, 'Step 2/4: Patch IFS')

    # --- Step 6: Recompress ---
    recompressed_path = os.path.join(workdir, 'ifs-root.ifs')
    repack_args = [patched_path, recompressed_path]
    if args.reference:
        repack_args += ['--reference', ifs_path]

    run_tool('repack_ifs.py', repack_args, 'Step 3/4: Recompress IFS')

    # --- Step 7: Fix CRCs ---
    metainfo = find_metainfo(mu_dir)
    if metainfo and not args.skip_crc:
        # Determine the section name from the path
        # e.g., MU9411\ifs-root\41\default\Application
        rel = os.path.relpath(ifs_path, os.path.dirname(mu_dir))
        parts = rel.replace('/', '\\').split('\\')
        # Construct section: MU9411\ifs-root\41\default\Application
        if len(parts) >= 4:
            section = '\\'.join(parts[:4]) + '\\Application'
            print(f"\n[mu_repack] CRC section: {section}")
            run_tool('mu_crc_patcher.py',
                     ['--metainfo', metainfo,
                      '--file', recompressed_path,
                      '--section', section],
                     'Step 4/4: Update CRCs')
        else:
            print("[mu_repack] WARNING: could not determine metainfo section, skipping CRC update")
    elif args.skip_crc:
        print("\n[mu_repack] skipCrc mode — CRCs not recomputed")
    else:
        print("\n[mu_repack] WARNING: metainfo2.txt not found, skipping CRC update")

    # --- Step 8: Copy to output ---
    if args.output:
        os.makedirs(args.output, exist_ok=True)
        out_ifs = os.path.join(args.output, 'ifs-root.ifs')
        shutil.copy2(recompressed_path, out_ifs)
        print(f"\n[mu_repack] Output: {out_ifs}")
        print(f"[mu_repack] Size: {os.path.getsize(out_ifs):,} bytes")
    else:
        print(f"\n[mu_repack] Patched IFS at: {recompressed_path}")

    print(f"\n{'='*60}")
    print(f"  Done! Custom firmware ready.")
    print(f"{'='*60}")


if __name__ == '__main__':
    main()
