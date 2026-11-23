#!/usr/bin/env python3
"""
verify_ifs.py — check a QNX IFS before you flash it.

Runs the checks the MMI's boot chain runs, plus the layout rules mkifs
follows, on a compressed ifs-root.ifs (as flashed) and/or a decompressed
one (from inflate_ifs.py / patch_ifs.py / build_ifs.py). Exit code 0 means
every check passed; 1 means at least one ERROR.

Compressed image (what the IPL checks before it starts the IFS):
  * startup signature, and the startup checksum: uint32 sum of
    [0, startup_size) == 0
  * stored_size == file length, a multiple of 4
  * data checksum: uint32 sum of [startup_size, stored_size) == 0
    (the chunk stream, its end marker, padding and the 4-byte trailer)
  * the LZO chunk stream ends inside stored_size

Decompressed image (what startup / procnto rely on):
  * startup checksum, imagefs checksum (sum of the imagefs == 0)
  * header sizes agree: imagefs_size == image_size, ram_size big enough
  * every directory entry and file lies inside the image; files don't overlap
  * every file starts on a 4 KiB physical page (mkifs's layout)
  * every executable is linked for where it sits: each PT_LOAD p_paddr is 0
    or image_paddr + startup_size + file_offset + p_offset (XIP)
  * the boot (procnto) and script inodes exist

Usage:
    python3 tools/verify_ifs.py new_ifs-root.ifs
    python3 tools/verify_ifs.py new_ifs-root.ifs --decompressed new_decomp.ifs
    python3 tools/verify_ifs.py new_decomp.ifs
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ifs_image as ifs  # noqa: E402


class Report:
    def __init__(self, name):
        self.name, self.errors, self.warnings = name, 0, 0
        print(f"== {name}")

    def ok(self, msg):
        print(f"  ok    {msg}")

    def warn(self, msg):
        self.warnings += 1
        print(f"  WARN  {msg}")

    def err(self, msg):
        self.errors += 1
        print(f"  ERROR {msg}")

    def check(self, cond, good, bad):
        (self.ok if cond else self.err)(good if cond else bad)
        return cond


def startup_info(d, r):
    if len(d) < 0x40 or ifs.u32(d, 0) != ifs.STARTUP_SIG:
        r.err('no QNX startup signature (0x00ff7eeb)')
        return None
    ss = ifs.u32(d, ifs.SH_STARTUP_SIZE)
    if ss % 4 or ss > len(d):
        r.err(f'startup_size 0x{ss:x} is not usable')
        return None
    r.check(ifs.sum32(d, 0, ss) == 0, f'startup checksum (0x{ss:x} bytes)',
            'startup checksum is wrong: the startup header was edited without '
            'redoing the last word of the startup section')
    return ss


def verify_compressed(d, r):
    ss = startup_info(d, r)
    if ss is None:
        return
    stored = ifs.u32(d, ifs.SH_STORED_SIZE)
    r.check(stored == len(d), f'stored_size == file length ({stored:,})',
            f'stored_size {stored:,} != file length {len(d):,}')
    if not r.check(stored % 4 == 0, 'stored_size is a multiple of 4',
                   f'stored_size {stored} is not a multiple of 4 (the IPL sums words)'):
        return
    end = min(stored, len(d))
    r.check(ifs.sum32(d, ss, end - ss) == 0, 'data checksum (chunk stream + trailer)',
            'data checksum is wrong: the 4-byte trailer after the chunk stream is '
            'missing or stale (the IPL reports "DATA CHECKSUM ERROR")')
    p, chunks = ss, 0
    while p + 2 <= end:
        n = (d[p] << 8) | d[p + 1]
        p += 2
        if n == 0:
            break
        p += n
        chunks += 1
    else:
        r.err('LZO chunk stream runs past stored_size')
        return
    r.check(p <= end, f'chunk stream: {chunks} chunks, ends at 0x{p:x}',
            'LZO chunk stream runs past stored_size')
    tail = end - p
    if tail not in range(4, 8):
        r.warn(f'{tail} bytes between the end marker and stored_size (mkifs: pad to 4 + 4-byte trailer)')
    print(f"  info  imagefs_size {ifs.u32(d, ifs.SH_IMAGEFS_SIZE):,} once decompressed")


def verify_decompressed(d, r):
    ss = startup_info(d, r)
    if ss is None:
        return None
    try:
        img = ifs.IfsImage(d)
    except ValueError as exc:
        r.err(str(exc))
        return None
    isz = img.image_size
    r.check(ifs.sum32(d, ss, isz) == 0, f'imagefs checksum ({isz:,} bytes)',
            'imagefs checksum (last word of the imagefs) is wrong')
    r.check(ifs.u32(d, ifs.SH_IMAGEFS_SIZE) == isz, 'startup imagefs_size == image_size',
            f'startup imagefs_size {ifs.u32(d, ifs.SH_IMAGEFS_SIZE):,} != image_size {isz:,}')
    ram = ifs.u32(d, ifs.SH_RAM_SIZE)
    r.check(ram >= ss + isz, f'ram_size 0x{ram:x} covers startup + imagefs',
            f'ram_size 0x{ram:x} < startup + imagefs 0x{ss + isz:x}')
    r.check(img.dir_end <= img.hdr_dir_size <= img.data_start,
            f'{len(img.entries)} directory entries end before the first file',
            'directory runs into the file data')

    files = sorted(img.files(), key=lambda e: e.foff)
    bad = [e.path for e in files if e.foff + e.fsize > isz - 4]
    r.check(not bad, f'{len(files)} files inside the image', f'files past the image end: {bad[:5]}')
    overl = [(a.path, b.path) for a, b in zip(files, files[1:])
             if b.foff != a.foff and a.foff + a.fsize > b.foff]
    r.check(not overl, 'no files overlap', f'overlapping files: {overl[:3]}')
    unaligned = [e.path for e in files if (ss + e.foff) % ifs.PAGE]
    if unaligned:
        r.warn(f'{len(unaligned)} files not on a 4 KiB physical page, e.g. {unaligned[:3]} '
               '(mkifs aligns every file)')
    else:
        r.ok('every file starts on a 4 KiB physical page')

    xip_bad, elfs = [], 0
    for e in files:
        b = img.file_data(e)
        segs = img._load_segments(b)
        if not segs:
            continue
        elfs += 1
        for (_ph, off, paddr, _fl) in segs:
            if paddr not in (0, img.phys(e.foff) + off):
                xip_bad.append(f'{e.path} (p_paddr 0x{paddr:x}, expected '
                               f'0x{img.phys(e.foff) + off:x} or 0)')
                break
    r.check(not xip_bad, f'{elfs} ELFs linked for where they sit (XIP p_paddr)',
            f'{len(xip_bad)} ELFs have load addresses for another position; they will '
            f'crash when started: {xip_bad[:3]}')

    inos = {e.ino for e in img.entries}
    boot = [i for i in (ifs.u32(img.imagefs, 20 + 4 * k) for k in range(4)) if i]
    script = ifs.u32(img.imagefs, 36)
    r.check(all(i in inos for i in boot), 'boot inode (procnto) present',
            f'boot inode(s) {[hex(i) for i in boot]} missing')
    if script:
        r.check(script in inos, 'boot script inode present', f'script inode 0x{script:x} missing')
    return img


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('image', help='Compressed or decompressed IFS')
    p.add_argument('--decompressed', metavar='DECOMP',
                   help='The decompressed image it was made from, checked too')
    args = p.parse_args()

    total = 0
    paths = [args.image] + ([args.decompressed] if args.decompressed else [])
    sizes = {}
    for path in paths:
        with open(path, 'rb') as f:
            d = f.read()
        r = Report(path)
        compressed = len(d) > 7 and (d[ifs.SH_FLAGS1] & ifs.FLAGS1_COMPRESS_MASK) and \
            d[ifs.u32(d, ifs.SH_STARTUP_SIZE):][:7] != ifs.IMAGE_SIG
        if compressed:
            verify_compressed(d, r)
            sizes['compressed'] = ifs.u32(d, ifs.SH_IMAGEFS_SIZE)
        else:
            img = verify_decompressed(d, r)
            if img:
                sizes['decompressed'] = img.image_size
        total += r.errors
    if len(sizes) == 2:
        same = sizes['compressed'] == sizes['decompressed']
        print('== pair')
        print(('  ok    ' if same else '  ERROR ') +
              f"imagefs_size {sizes['compressed']:,} vs decompressed {sizes['decompressed']:,}")
        total += 0 if same else 1
    print('\nRESULT: ' + ('PASS' if total == 0 else f'FAIL ({total} error(s))'))
    sys.exit(0 if total == 0 else 1)


if __name__ == '__main__':
    main()
