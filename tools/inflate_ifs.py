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
built automatically on first run. Requires gcc + libucl headers/libs.

If those native dependencies are missing, the script can either be run
explicitly in a disposable container with `--container`, or it will
auto-fallback to podman/docker if available unless
`--no-container-fallback` is set.

Usage:

    # decompress only
    python3 tools/inflate_ifs.py ifs-root.ifs -o ifs-root.decomp

    # decompress and extract to a directory
    python3 tools/inflate_ifs.py ifs-root.ifs --extract outdir/

    # force a disposable container run
    python3 tools/inflate_ifs.py ifs-root.ifs --extract outdir/ --container
"""
import argparse
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import tarfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(HERE)
DECOMPRESSOR_SRC = os.path.join(HERE, 'qnx_ifs_decompress.c')
DECOMPRESSOR_BIN = os.path.join(HERE, 'qnx_ifs_decompress')
CONTAINER_REEXEC_ENV = 'MMI3G_INFLATE_IFS_IN_CONTAINER'
DEFAULT_CONTAINER_IMAGE = 'debian:bookworm-slim'


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
    with tarfile.open(tgz) as archive:
        for name in (
            'minilzo-2.10/minilzo.c',
            'minilzo-2.10/minilzo.h',
            'minilzo-2.10/lzoconf.h',
            'minilzo-2.10/lzodefs.h',
        ):
            member = archive.getmember(name)
            member.name = os.path.basename(name)
            archive.extract(member, HERE)
    os.remove(tgz)


def ensure_built():
    """Build qnx_ifs_decompress if missing or out-of-date."""
    if (os.path.exists(DECOMPRESSOR_BIN)
            and os.path.getmtime(DECOMPRESSOR_BIN) >= os.path.getmtime(DECOMPRESSOR_SRC)):
        return DECOMPRESSOR_BIN

    ensure_minilzo()

    lzo_dir = os.path.join(HERE, 'lzo')
    os.makedirs(lzo_dir, exist_ok=True)
    src = os.path.join(HERE, 'minilzo.h')
    dst = os.path.join(lzo_dir, 'minilzo.h')
    if not os.path.exists(dst):
        shutil.copy(src, dst)

    print('[inflate_ifs] compiling {} -> {}'.format(DECOMPRESSOR_SRC, DECOMPRESSOR_BIN),
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


def resolve_container_tool(preferred=None):
    if preferred:
        return preferred if shutil.which(preferred) else None
    for candidate in ('podman', 'docker'):
        if shutil.which(candidate):
            return candidate
    return None


def existing_mount_root(path):
    candidate = os.path.abspath(path)
    if not os.path.isdir(candidate):
        candidate = os.path.dirname(candidate)
    while not os.path.exists(candidate):
        parent = os.path.dirname(candidate)
        if parent == candidate:
            break
        candidate = parent
    return candidate


def translate_host_path(host_path, repo_root, extra_roots):
    repo_root = os.path.abspath(repo_root)
    host_path = os.path.abspath(host_path)

    if host_path == repo_root:
        return '/workspace'
    if host_path.startswith(repo_root + os.sep):
        return '/workspace' + host_path[len(repo_root):]

    for root, target in extra_roots:
        if host_path == root:
            return target
        if root == '/':
            return target + host_path
        if host_path.startswith(root + os.sep):
            return target + host_path[len(root):]

    raise ValueError('path {} was not covered by container mounts'.format(host_path))


def build_container_command(container_tool, image, ifs_path, output_path=None, extract_path=None,
                            keep_decomp=False, repo_root=None):
    repo_root = os.path.abspath(repo_root or REPO_ROOT)

    mounts = [(repo_root, '/workspace')]
    extra_roots = []
    seen_roots = {repo_root}

    relevant_paths = [os.path.abspath(ifs_path)]
    if output_path:
        relevant_paths.append(os.path.abspath(output_path))
    if extract_path:
        relevant_paths.append(os.path.abspath(extract_path))

    for path in relevant_paths:
        if path == repo_root or path.startswith(repo_root + os.sep):
            continue
        root = existing_mount_root(path)
        if root in seen_roots:
            continue
        target = '/mnt/host{}'.format(len(extra_roots))
        extra_roots.append((root, target))
        mounts.append((root, target))
        seen_roots.add(root)

    translated_ifs = translate_host_path(ifs_path, repo_root, extra_roots)
    translated_output = translate_host_path(output_path, repo_root, extra_roots) if output_path else None
    translated_extract = translate_host_path(extract_path, repo_root, extra_roots) if extract_path else None

    inner_args = [
        'python3',
        '/workspace/tools/inflate_ifs.py',
        translated_ifs,
        '--no-container-fallback',
    ]
    if translated_output:
        inner_args.extend(['-o', translated_output])
    if translated_extract:
        inner_args.extend(['--extract', translated_extract])
    if keep_decomp:
        inner_args.append('--keep-decomp')

    inner_command = (
        'apt-get update && '
        'apt-get install -y --no-install-recommends gcc libucl-dev python3 ca-certificates && '
        '{}'.format(' '.join(shlex.quote(arg) for arg in inner_args))
    )

    command = [container_tool, 'run', '--rm', '-e', '{}=1'.format(CONTAINER_REEXEC_ENV), '-w', '/workspace']
    for host_path, target_path in mounts:
        command.extend(['-v', '{}:{}'.format(host_path, target_path)])
    command.extend([image, 'sh', '-lc', inner_command])
    return command


def run_in_container(args, decomp_path):
    tool = resolve_container_tool(args.container_tool)
    if not tool:
        requested = args.container_tool or 'podman/docker'
        print('[inflate_ifs] no usable container runtime found ({})'.format(requested), file=sys.stderr)
        return 1

    command = build_container_command(
        container_tool=tool,
        image=args.container_image,
        ifs_path=os.path.abspath(args.ifs),
        output_path=os.path.abspath(decomp_path),
        extract_path=os.path.abspath(args.extract) if args.extract else None,
        keep_decomp=args.keep_decomp,
        repo_root=REPO_ROOT,
    )
    print('[inflate_ifs] running in {} using {}'.format(tool, args.container_image), file=sys.stderr)
    return subprocess.call(command)


def should_try_container(args):
    if os.environ.get(CONTAINER_REEXEC_ENV):
        return False
    if args.no_container_fallback:
        return False
    return resolve_container_tool(args.container_tool) is not None


def compute_decomp_path(args):
    if args.output:
        return args.output, False
    if args.extract and not args.keep_decomp:
        return tempfile.mktemp(suffix='.ifs.decomp'), True
    return args.ifs + '.decomp', False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ifs', help='Input compressed .ifs image')
    parser.add_argument('-o', '--output',
                        help='Output decompressed IFS path (default: <input>.decomp)')
    parser.add_argument('--extract', metavar='DIR',
                        help='After decompressing, extract files to DIR using extract_qnx_ifs.py')
    parser.add_argument('--keep-decomp', action='store_true',
                        help='Keep the decompressed intermediate file even when using --extract')
    parser.add_argument('--container', action='store_true',
                        help='Run inside a disposable podman/docker container')
    parser.add_argument('--container-tool', choices=['podman', 'docker'],
                        help='Container runtime to use for --container or auto-fallback')
    parser.add_argument('--container-image', default=DEFAULT_CONTAINER_IMAGE,
                        help='Container image for --container / auto-fallback '
                             '(default: {})'.format(DEFAULT_CONTAINER_IMAGE))
    parser.add_argument('--no-container-fallback', action='store_true',
                        help='Disable automatic podman/docker fallback when local deps are missing')
    args = parser.parse_args()

    decomp_path, owns_decomp = compute_decomp_path(args)

    if args.container and not os.environ.get(CONTAINER_REEXEC_ENV):
        sys.exit(run_in_container(args, decomp_path))

    try:
        binary = ensure_built()
    except (FileNotFoundError, OSError, subprocess.CalledProcessError) as exc:
        if should_try_container(args):
            print('[inflate_ifs] local build failed ({}); retrying in container'.format(exc),
                  file=sys.stderr)
            sys.exit(run_in_container(args, decomp_path))
        raise

    print('[inflate_ifs] decompressing {}'.format(args.ifs), file=sys.stderr)
    result = subprocess.run([binary, args.ifs, decomp_path])
    if result.returncode != 0:
        sys.exit('[inflate_ifs] decompressor failed')

    print('[inflate_ifs] wrote {} ({:,} bytes)'.format(
        decomp_path, os.path.getsize(decomp_path)), file=sys.stderr)

    if args.extract:
        extractor = os.path.join(HERE, 'extract_qnx_ifs.py')
        result = subprocess.run(['python3', extractor, decomp_path, args.extract])
        if result.returncode != 0:
            sys.exit('[inflate_ifs] extractor failed')
        if owns_decomp:
            os.unlink(decomp_path)


if __name__ == '__main__':
    main()
