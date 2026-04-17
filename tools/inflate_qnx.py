#!/usr/bin/env python3
"""
inflate_qnx.py — inflate QNX "iwlyfmbp" deflate-format files.

The QNX Neutrino SDK ships a `deflate` utility (separate from zlib's deflate)
that compresses files with LZO1X or UCL NRV2B in a custom container. Harman
Becker uses this same format to compress binaries stored in the MMI3G EFS.

Files carved from `efs-system.efs` by `extract_f3s_efs.py` that start with
the 8-byte magic `iwlyfmbp` need this tool to become usable ELF binaries.

The container format is documented in
openqnx/trunk/utils/d/deflate/deflate.c. See also research/F3S_FORMAT.md.

Because UCL NRV2B does not have a reliable Python binding, this wrapper
shells out to a tiny C program (`qnx_inflator`). On first run the C program
is built automatically if missing. Requires system libraries:

    apt install liblzo2-dev libucl-dev

plus `minilzo.c` + `minilzo.h` (auto-downloaded from oberhumer.com on first
build — ~63 KB).

Usage:

    python3 tools/inflate_qnx.py <input.bin> <output.bin>
    python3 tools/inflate_qnx.py --recurse /dir/with/carved/files/
"""
import argparse
import os
import shutil
import struct
import subprocess
import sys
import urllib.request
import tarfile

HERE = os.path.dirname(os.path.abspath(__file__))
INFLATOR_SRC = os.path.join(HERE, 'qnx_inflator.c')
INFLATOR_BIN = os.path.join(HERE, 'qnx_inflator')
MAGIC = b'iwlyfmbp'


def ensure_built():
    """Build qnx_inflator if missing. Returns path to binary."""
    if os.path.exists(INFLATOR_BIN) and os.path.getmtime(INFLATOR_BIN) >= os.path.getmtime(INFLATOR_SRC):
        return INFLATOR_BIN

    # Need minilzo.c + minilzo.h. Check if the user has them in a standard location;
    # otherwise auto-fetch.
    minilzo_c = os.path.join(HERE, 'minilzo.c')
    minilzo_h = os.path.join(HERE, 'minilzo.h')
    if not (os.path.exists(minilzo_c) and os.path.exists(minilzo_h)):
        print(f"[inflate_qnx] fetching minilzo from oberhumer.com ...", file=sys.stderr)
        url = 'https://www.oberhumer.com/opensource/lzo/download/minilzo-2.10.tar.gz'
        tgz = os.path.join(HERE, 'minilzo-2.10.tar.gz')
        try:
            urllib.request.urlretrieve(url, tgz)
            with tarfile.open(tgz) as t:
                for n in ('minilzo-2.10/minilzo.c', 'minilzo-2.10/minilzo.h',
                          'minilzo-2.10/lzoconf.h', 'minilzo-2.10/lzodefs.h'):
                    m = t.getmember(n)
                    m.name = os.path.basename(n)
                    t.extract(m, HERE)
            os.remove(tgz)
        except Exception as e:
            sys.exit(f"[inflate_qnx] failed to fetch minilzo: {e}\n"
                     f"                  manually place minilzo.c / minilzo.h / lzoconf.h / lzodefs.h in {HERE}")

    # minilzo.c expects #include <lzo/minilzo.h>; point it at our local copy
    lzo_dir = os.path.join(HERE, 'lzo')
    os.makedirs(lzo_dir, exist_ok=True)
    for f in ('minilzo.h',):
        src = os.path.join(HERE, f)
        dst = os.path.join(lzo_dir, f)
        if not os.path.exists(dst):
            shutil.copy(src, dst)

    print(f"[inflate_qnx] compiling {INFLATOR_SRC} -> {INFLATOR_BIN}", file=sys.stderr)
    subprocess.check_call([
        'gcc', '-Wall', '-O2',
        '-I', HERE,
        '-o', INFLATOR_BIN,
        INFLATOR_SRC,
        os.path.join(HERE, 'minilzo.c'),
        '-lucl',
    ])
    return INFLATOR_BIN


def is_wrapped(path):
    try:
        with open(path, 'rb') as f:
            return f.read(8) == MAGIC
    except Exception:
        return False


def inflate_one(inp, outp, binary=None):
    binary = binary or ensure_built()
    r = subprocess.run([binary, inp, outp], capture_output=True)
    if r.returncode != 0:
        sys.stderr.write(r.stderr.decode('utf-8', errors='replace'))
        return False
    return True


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('input', help='Input file or (with --recurse) directory')
    ap.add_argument('output', nargs='?',
                    help='Output file (for single-file mode). If omitted and '
                         '--recurse is set, files are inflated in place with '
                         '.inflated suffix.')
    ap.add_argument('--recurse', action='store_true',
                    help='Treat input as a directory; inflate every iwlyfmbp-wrapped file')
    ap.add_argument('--inplace', action='store_true',
                    help='(with --recurse) replace files in place')
    args = ap.parse_args()

    binary = ensure_built()

    if args.recurse:
        if not os.path.isdir(args.input):
            sys.exit(f'{args.input}: not a directory')
        total = 0
        ok = 0
        for root, _dirs, files in os.walk(args.input):
            for name in files:
                path = os.path.join(root, name)
                if not is_wrapped(path):
                    continue
                total += 1
                tmp = path + '.inflated'
                if inflate_one(path, tmp, binary=binary):
                    if args.inplace:
                        os.replace(tmp, path)
                    ok += 1
                    print(f'  OK  {path}')
                else:
                    print(f'  FAIL {path}')
                    try:
                        os.remove(tmp)
                    except Exception:
                        pass
        print(f'\n[+] inflated {ok}/{total} files')
    else:
        if not args.output:
            sys.exit('need OUTPUT for single-file mode (or use --recurse)')
        if not is_wrapped(args.input):
            sys.exit(f'{args.input}: no iwlyfmbp magic')
        ok = inflate_one(args.input, args.output, binary=binary)
        sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
