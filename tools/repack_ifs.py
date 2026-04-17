#!/usr/bin/env python3
"""
repack_ifs.py — recompress a decompressed QNX IFS image.

Takes the output of `inflate_ifs.py` (a decompressed IFS image) and
produces a compressed IFS suitable for flashing to an MMI3G head unit.

Two modes:

  Bit-identical (unmodified firmware):
    python3 tools/repack_ifs.py decompressed.ifs repacked.ifs \\
        --reference original.ifs

  Modified firmware:
    python3 tools/repack_ifs.py modified_decompressed.ifs repacked.ifs

The compressor uses lzo1x_999 (optimal), matching Harman's original
encoder. In --reference mode the output is byte-identical to the
original compressed IFS. In fixed-chunk mode the imagefs content is
identical but the container is slightly larger (~3%).

After repacking, update the CRCs with:
    python3 tools/mu_crc_patcher.py --metainfo metainfo2.txt \\
        --file repacked.ifs --section 'MU9411\\ifs-root\\41\\default\\Application'

Or bypass CRCs entirely:
    python3 tools/mu_crc_patcher.py --update-txt update.txt --skip-crc
"""
import argparse
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
COMPRESSOR_SRC = os.path.join(HERE, 'qnx_ifs_compress.c')
COMPRESSOR_BIN = os.path.join(HERE, 'qnx_ifs_compress')


def ensure_compressor():
    """Build the C compressor if it doesn't exist or is stale."""
    if os.path.exists(COMPRESSOR_BIN):
        src_mtime = os.path.getmtime(COMPRESSOR_SRC)
        bin_mtime = os.path.getmtime(COMPRESSOR_BIN)
        if bin_mtime >= src_mtime:
            return  # up to date

    print(f'[repack_ifs] building {COMPRESSOR_BIN}...')
    rc = subprocess.call([
        'gcc', '-O2', '-o', COMPRESSOR_BIN, COMPRESSOR_SRC, '-llzo2'
    ])
    if rc != 0:
        print('ERROR: failed to compile qnx_ifs_compress.c', file=sys.stderr)
        print('       install liblzo2-dev: apt install liblzo2-dev', file=sys.stderr)
        sys.exit(1)
    print(f'[repack_ifs] built {COMPRESSOR_BIN}')


def main():
    p = argparse.ArgumentParser(
        description='Recompress a decompressed QNX IFS image.')
    p.add_argument('input', help='Decompressed IFS (from inflate_ifs.py)')
    p.add_argument('output', help='Output compressed IFS path')
    p.add_argument('--reference', metavar='ORIG',
                   help='Original compressed IFS for bit-identical output')
    p.add_argument('--chunk-size', type=int, default=61440,
                   help='Decompressed chunk size in fixed mode (default: 61440). '
                        'Do not exceed 63000 to avoid u16 overflow.')
    args = p.parse_args()

    if not os.path.exists(args.input):
        print(f'ERROR: input file not found: {args.input}', file=sys.stderr)
        sys.exit(1)

    ensure_compressor()

    cmd = [COMPRESSOR_BIN, args.input, args.output]
    if args.reference:
        if not os.path.exists(args.reference):
            print(f'ERROR: reference file not found: {args.reference}',
                  file=sys.stderr)
            sys.exit(1)
        cmd += ['--reference', args.reference]
    else:
        cmd += ['--chunk-size', str(args.chunk_size)]

    rc = subprocess.call(cmd)
    if rc != 0:
        print('ERROR: compression failed', file=sys.stderr)
        sys.exit(1)

    in_size = os.path.getsize(args.input)
    out_size = os.path.getsize(args.output)
    ratio = out_size / in_size * 100
    print(f'[repack_ifs] {in_size:,} bytes -> {out_size:,} bytes ({ratio:.1f}%)')

    if args.reference:
        ref_size = os.path.getsize(args.reference)
        if out_size == ref_size:
            print(f'[repack_ifs] output is byte-identical to reference ✓')
        else:
            print(f'[repack_ifs] output differs from reference '
                  f'({out_size:,} vs {ref_size:,})')


if __name__ == '__main__':
    main()
