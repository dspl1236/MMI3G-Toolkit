#!/usr/bin/env python3
"""
inflate_ifs.py — decompress a compressed QNX IFS (and optionally extract).

The QNX Image File System (IFS) used for MMI3G's ifs-root.ifs is
compressed with LZO1X or UCL NRV2B at the container level. Standard
`dumpifs` cannot decompress Harman's streams because lzo1x_decompress_safe
is too strict; we use the permissive lzo1x_decompress instead (matching
the approach unbe pioneered in github.com/unbe/mmi-ifs).

This tool:
  1. Parses the startup_header to find compression type + startup_size
  2. Copies the startup section verbatim to a temp file
  3. Walks the LZO/UCL chunk stream (u16 BE length + payload) after
     startup_size, decompressing each chunk
  4. Optionally runs extract_qnx_ifs.py on the decompressed result

The decompressor is a tiny C program (`qnx_ifs_decompress.c`, ~140 lines)
built automatically on first run. Requires liblzo2-dev + libucl-dev +
minilzo.c (auto-fetched from oberhumer.com).

Usage:

    # decompress only
    python3 tools/inflate_ifs.py ifs-root.ifs -o ifs-root.decomp

    # decompress and extract to a directory
    python3 tools/inflate_ifs.py ifs-root.ifs --extract outdir/
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import tarfile

HERE = os.path.dirname(os.path.abspath(__file__))
DECOMPRESSOR_SRC = os.path.join(HERE, 'qnx_ifs_decompress.c')
DECOMPRESSOR_BIN = os.path.join(HERE, 'qnx_ifs_decompress')


def ensure_minilzo():
    """Ensure minilzo sources are in the tools dir (fetches if missing)."""
    mc = os.path.join(HERE, 'minilzo.c')
    mh = os.path.join(HERE, 'minilzo.h')
    if os.path.exists(mc) and os.path.exists(mh):
        return
    print('[inflate_ifs] fetching minilzo from oberhumer.com ...', file=sys.stderr)
    url = 'https://www.oberhumer.com/opensource/lzo/download/minilzo-2.10.tar.gz'
    tgz = os.path.join(HERE, 'minilzo-2.10.tar.gz')
    urllib.request.urlretrieve(url, tgz)
    with tarfile.open(tgz) as t:
        for n in ('minilzo-2.10/minilzo.c', 'minilzo-2.10/minilzo.h',
                  'minilzo-2.10/lzoconf.h', 'minilzo-2.10/lzodefs.h'):
            m = t.getmember(n)
            m.name = os.path.basename(n)
            t.extract(m, HERE)
    os.remove(tgz)


def ensure_built():
    """Build qnx_ifs_decompress if missing or out-of-date."""
    if (os.path.exists(DECOMPRESSOR_BIN)
            and os.path.getmtime(DECOMPRESSOR_BIN) >= os.path.getmtime(DECOMPRESSOR_SRC)):
        return DECOMPRESSOR_BIN

    ensure_minilzo()

    # minilzo.c expects #include <lzo/minilzo.h>; provide that path
    lzo_dir = os.path.join(HERE, 'lzo')
    os.makedirs(lzo_dir, exist_ok=True)
    src = os.path.join(HERE, 'minilzo.h')
    dst = os.path.join(lzo_dir, 'minilzo.h')
    if not os.path.exists(dst):
        shutil.copy(src, dst)

    print(f'[inflate_ifs] compiling {DECOMPRESSOR_SRC} -> {DECOMPRESSOR_BIN}',
          file=sys.stderr)
    subprocess.check_call([
        'gcc', '-Wall', '-O2',
        '-I', HERE,
        '-o', DECOMPRESSOR_BIN,
        DECOMPRESSOR_SRC,
        os.path.join(HERE, 'minilzo.c'),
        '-lucl',
    ])
    return DECOMPRESSOR_BIN


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('ifs', help='Input compressed .ifs image')
    ap.add_argument('-o', '--output',
                    help='Output decompressed IFS path (default: <input>.decomp)')
    ap.add_argument('--extract', metavar='DIR',
                    help='After decompressing, extract files to DIR using extract_qnx_ifs.py')
    ap.add_argument('--keep-decomp', action='store_true',
                    help='Keep the decompressed intermediate file even when using --extract')
    args = ap.parse_args()

    binary = ensure_built()

    if args.output:
        decomp_path = args.output
        owns_decomp = False
    elif args.extract and not args.keep_decomp:
        decomp_path = tempfile.mktemp(suffix='.ifs.decomp')
        owns_decomp = True
    else:
        decomp_path = args.ifs + '.decomp'
        owns_decomp = False

    print(f'[inflate_ifs] decompressing {args.ifs}', file=sys.stderr)
    r = subprocess.run([binary, args.ifs, decomp_path])
    if r.returncode != 0:
        sys.exit(f'[inflate_ifs] decompressor failed')

    print(f'[inflate_ifs] wrote {decomp_path} ({os.path.getsize(decomp_path):,} bytes)',
          file=sys.stderr)

    if args.extract:
        extractor = os.path.join(HERE, 'extract_qnx_ifs.py')
        r = subprocess.run(['python3', extractor, decomp_path, args.extract])
        if r.returncode != 0:
            sys.exit('[inflate_ifs] extractor failed')
        if owns_decomp:
            os.unlink(decomp_path)


if __name__ == '__main__':
    main()
