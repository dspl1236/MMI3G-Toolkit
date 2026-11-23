#!/usr/bin/env python3
"""
patch_ifs.py — replace, add or remove files inside a decompressed QNX IFS.

Takes a decompressed IFS (output of inflate_ifs.py) and writes a new
decompressed IFS. The layout of the original image is kept: every file
stays at its original offset, because mkifs links the image's executables
to run in place from exactly there (see ifs_image.py). A replacement that
fits its file's slot is written in place; a bigger one moves to the end of
the image (page-aligned, ELF load addresses relocated). Headers and all
checksums are redone.

Usage:
    # Replace a single file (paths as --list prints them)
    python3 tools/patch_ifs.py ifs_decomp.ifs ifs_patched.ifs \\
        --replace mnt/ifs-root/lsd/lsd.jxe=./lsd.jxe

    # Several edits at once
    python3 tools/patch_ifs.py ifs_decomp.ifs ifs_patched.ifs \\
        --replace mnt/ifs-root/etc/foo.cfg=./foo.cfg \\
        --add mnt/ifs-root/usr/bin/mytool=./mytool \\
        --remove mnt/ifs-root/usr/bin/unused

    # List all entries (no modification)
    python3 tools/patch_ifs.py ifs_decomp.ifs --list

Then compress, check, and fix the update CRCs:
    python3 tools/repack_ifs.py ifs_patched.ifs new_ifs-root.ifs
    python3 tools/verify_ifs.py new_ifs-root.ifs --decompressed ifs_patched.ifs
    python3 tools/mu_crc_patcher.py --metainfo metainfo2.txt \\
        --file new_ifs-root.ifs --section '...'
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ifs_image as ifs  # noqa: E402


def list_entries(img):
    for e in img.entries:
        if e.ftype == ifs.S_IFREG:
            print(f"  {e.fsize:>10,}  {e.path}")
        elif e.ftype == ifs.S_IFDIR:
            print(f"       <dir>  {e.path}/")
        elif e.ftype == ifs.S_IFLNK:
            print(f"       <sym>  {e.path} -> {e.target}")
        else:
            print(f"       <dev>  {e.path}")
    kinds = [e.ftype for e in img.entries]
    print(f"\n{kinds.count(ifs.S_IFREG)} files, {kinds.count(ifs.S_IFDIR)} dirs, "
          f"{kinds.count(ifs.S_IFLNK)} symlinks")


def split_spec(spec, flag):
    if '=' not in spec:
        sys.exit(f"ERROR: {flag} needs IFS_PATH=LOCAL_FILE, got: {spec}")
    path, local = spec.split('=', 1)
    if not os.path.isfile(local):
        sys.exit(f"ERROR: local file not found: {local}")
    with open(local, 'rb') as f:
        return ifs.norm_path(path), f.read()


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('input', help='Decompressed IFS image')
    p.add_argument('output', nargs='?', help='Output patched IFS')
    p.add_argument('--list', action='store_true', help='List entries only')
    p.add_argument('--replace', action='append', default=[], metavar='IFS_PATH=LOCAL_FILE',
                   help='Replace a file, e.g. mnt/ifs-root/lsd/lsd.jxe=./lsd.jxe')
    p.add_argument('--add', action='append', default=[], metavar='IFS_PATH=LOCAL_FILE',
                   help='Add a new file (mode 0755, root:root)')
    p.add_argument('--remove', action='append', default=[], metavar='IFS_PATH',
                   help='Remove a file, link or directory entry')
    args = p.parse_args()

    try:
        img = ifs.load(args.input)
    except ValueError as exc:
        sys.exit(f"ERROR: {exc}")

    if args.list:
        list_entries(img)
        return
    if not args.output:
        sys.exit("ERROR: output path required (or use --list)")
    if not (args.replace or args.add or args.remove):
        sys.exit("ERROR: nothing to do (use --replace, --add or --remove)")

    try:
        for spec in args.replace:
            path, content = split_spec(spec, '--replace')
            where = img.replace(path, content)
            print(f"[patch] {path}: {len(content):,} bytes, {where}")
            if path.startswith('proc/boot/'):
                print("[patch] note: proc/boot holds the kernel and boot-time files; "
                      "a bad one here stops the unit before any shell is up")
        for spec in args.add:
            path, content = split_spec(spec, '--add')
            img.add_file(path, content)
            print(f"[patch] {path}: added ({len(content):,} bytes)")
        for path in args.remove:
            img.remove(path)
            print(f"[patch] {ifs.norm_path(path)}: removed")
        out = img.build()
    except (KeyError, ValueError) as exc:
        sys.exit(f"ERROR: {exc.args[0] if exc.args else exc}")

    with open(args.output, 'wb') as f:
        f.write(out)
    print(f"[patch] wrote {args.output} ({len(out):,} bytes)")


if __name__ == '__main__':
    main()
