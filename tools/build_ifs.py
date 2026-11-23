#!/usr/bin/env python3
"""
build_ifs.py — rebuild a decompressed QNX IFS from an extracted file tree.

Takes the tree that `inflate_ifs.py --extract` wrote (edited or not) and
the decompressed reference IFS it came from, and writes a new decompressed
IFS. It starts from the reference image and applies the differences:

  * a file whose bytes changed is replaced (in place if it fits its slot,
    otherwise moved to the end with its ELF load addresses relocated)
  * a file missing from the tree is removed
  * a file only in the tree is added; new directories get entries too
  * everything else (unchanged files, duplicates, directory entries,
    symlinks, permissions, inode numbers) stays exactly as in the reference

An unchanged tree therefore gives back the reference imagefs byte for
byte (the startup header is rewritten for an uncompressed image, and
repack_ifs.py restores the original: the compressed result is then
byte-identical to the original ifs-root.ifs).
Keeping the layout matters: mkifs links every executable to run in place
from its offset in the image (see ifs_image.py), so packing the files
afresh, as older versions of this script did, breaks procnto and every
program even when no file was edited.

Usage:
    python3 tools/build_ifs.py \\
        --reference ifs_decomp.ifs \\
        --tree ./ifs_extracted/ \\
        --output new_ifs_decomp.ifs

Then compress, check, and fix the update CRCs:
    python3 tools/repack_ifs.py new_ifs_decomp.ifs new_ifs-root.ifs
    python3 tools/verify_ifs.py new_ifs-root.ifs --decompressed new_ifs_decomp.ifs
    python3 tools/mu_crc_patcher.py ...
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ifs_image as ifs  # noqa: E402


def scan_tree(root):
    """{relative path: full path} of regular files, and the set of dirs."""
    files, dirs = {}, set()
    for cur, dirnames, filenames in os.walk(root):
        rel = os.path.relpath(cur, root).replace(os.sep, '/')
        rel = '' if rel == '.' else rel
        for d in dirnames:
            dirs.add(f"{rel}/{d}" if rel else d)
        for name in filenames:
            full = os.path.join(cur, name)
            if os.path.islink(full):
                continue          # links come from the reference image
            files[f"{rel}/{name}" if rel else name] = full
    return files, dirs


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--reference', required=True,
                   help='Decompressed reference IFS (the one the tree was extracted from)')
    p.add_argument('--tree', required=True, help='Extracted (and edited) file tree')
    p.add_argument('--output', required=True, help='Output decompressed IFS path')
    p.add_argument('--keep-missing', action='store_true',
                   help='Keep files that are missing from the tree instead of removing them')
    args = p.parse_args()

    try:
        img = ifs.load(args.reference)
    except ValueError as exc:
        sys.exit(f"ERROR: {exc}")
    tree_files, tree_dirs = scan_tree(args.tree)
    print(f"[build] reference: {len(img.entries)} entries; tree: "
          f"{len(tree_files)} files, {len(tree_dirs)} dirs")

    ref_files = {}
    for e in img.files():
        ref_files.setdefault(e.path, e)        # duplicates share one tree file
    ref_dirs = {e.path for e in img.entries if e.ftype == ifs.S_IFDIR}
    ref_links = {e.path for e in img.entries if e.ftype == ifs.S_IFLNK}

    changed = added = removed = 0
    try:
        for path, e in ref_files.items():
            if path not in tree_files:
                if not args.keep_missing:
                    img.remove(path)
                    removed += 1
                    print(f"[build] removed {path}")
                continue
            with open(tree_files[path], 'rb') as f:
                content = f.read()
            if img.differs(path, content):
                where = img.replace(path, content)
                changed += 1
                print(f"[build] replaced {path} ({len(content):,} bytes, {where})")
        for d in sorted(tree_dirs - ref_dirs - ref_links):
            if not img.has_dir(d):
                img.add_dir(d)
                print(f"[build] added dir {d}")
        for path in sorted(set(tree_files) - set(ref_files) - ref_links):
            with open(tree_files[path], 'rb') as f:
                img.add_file(path, f.read())
            added += 1
            print(f"[build] added {path}")
        out = img.build()
    except (KeyError, ValueError) as exc:
        sys.exit(f"ERROR: {exc.args[0] if exc.args else exc}")

    with open(args.output, 'wb') as f:
        f.write(out)
    print(f"[build] {changed} replaced, {added} added, {removed} removed")
    print(f"[build] wrote {args.output} ({len(out):,} bytes)")


if __name__ == '__main__':
    main()
