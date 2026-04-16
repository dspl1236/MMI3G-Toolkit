#!/usr/bin/env python3
"""
verify_stubs_vs_dsi.py

Compares our offline DSIPersistence / DSIPersistenceListener stubs against
the real interface definitions in an extracted dsi.jar.

This answers the #1 on-device risk: "does our Per3Reader implement
exactly the interface the real dsi.jar expects?" If the real interface
has methods we didn't stub, Per3Reader won't satisfy it and the bundle
will fail to load with AbstractMethodError.

Usage:
    python3 verify_stubs_vs_dsi.py <path-to-dsi.jar>

Prints a diff: methods in our stubs but not the real interface (harmless),
and methods in the real interface but not our stubs (THESE MATTER).

Requires: `javap` on PATH (comes with any JDK install).
"""
import argparse
import subprocess
import re
import sys
import os
import zipfile
import tempfile


REAL_INTERFACES = [
    'org.dsi.ifc.persistence.DSIPersistence',
    'org.dsi.ifc.persistence.DSIPersistenceListener',
    'org.dsi.ifc.base.DSIBase',
    'org.dsi.ifc.base.DSIListener',
]

STUB_ROOT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    '..', 'modules', 'per3-reader', 'src', 'stubs'
)


def javap_methods(jar_path, classname):
    """Run `javap -p <classname>` against the jar, return list of method
    signatures as 'name(arg-types)'."""
    try:
        result = subprocess.run(
            ['javap', '-p', '-classpath', jar_path, classname],
            capture_output=True, text=True, timeout=30
        )
    except FileNotFoundError:
        print("[ERROR] javap not found on PATH — install any JDK.")
        sys.exit(1)

    if result.returncode != 0:
        if 'not found' in result.stderr.lower() or 'not found' in result.stdout.lower():
            return None  # Class not present in this jar
        print(f"[WARN] javap failed for {classname}:")
        print(result.stderr)
        return None

    methods = []
    for line in result.stdout.splitlines():
        line = line.strip()
        if not line or line.startswith('Compiled from') or line.startswith('public ') and '{' in line:
            continue
        # Strip semicolon + modifiers; normalize
        line = line.rstrip(';').strip()
        # Keep only lines that look like method signatures (have parens)
        if '(' in line and ')' in line:
            methods.append(normalize_sig(line))
    return methods


def normalize_sig(sig):
    """Reduce a javap line like
       'public abstract void readInt(int, long, boolean) throws X, Y'
       to 'readInt(int,long,boolean)' for comparison.
    """
    # Strip throws clause
    sig = re.sub(r'\s+throws\s+.*$', '', sig)
    # Strip modifiers
    sig = re.sub(r'^\s*(public|private|protected|abstract|static|final|native|synchronized)\s+', '', sig)
    while re.match(r'^\s*(public|private|protected|abstract|static|final|native|synchronized)\s+', sig):
        sig = re.sub(r'^\s*(public|private|protected|abstract|static|final|native|synchronized)\s+', '', sig)
    # Strip return type (first token before the method name)
    m = re.match(r'\S+\s+(\w+\s*\(.*\))\s*$', sig)
    if m:
        sig = m.group(1)
    # Remove whitespace inside parentheses
    sig = re.sub(r'\s+', '', sig)
    return sig


def stub_methods(stub_java_path):
    """Extract method signatures from our stub .java file by simple regex."""
    if not os.path.isfile(stub_java_path):
        return None
    with open(stub_java_path) as f:
        src = f.read()
    # Strip block comments
    src = re.sub(r'/\*.*?\*/', '', src, flags=re.DOTALL)
    # Strip line comments
    src = re.sub(r'//[^\n]*', '', src)
    methods = []
    for m in re.finditer(r'(?:public\s+)?(?:abstract\s+)?(?:static\s+)?'
                          r'(\w+(?:\[\])?)\s+(\w+)\s*\(([^)]*)\)\s*(?:throws[^;{]*)?\s*[;{]',
                          src):
        ret_type, name, args = m.groups()
        if name in ('if', 'while', 'for', 'switch', 'catch', 'synchronized'):
            continue
        # Skip class declarations masquerading as methods
        if ret_type in ('class', 'interface', 'enum'):
            continue
        # Clean args: "int namespace, long address" -> "int,long"
        arg_types = []
        if args.strip():
            for a in args.split(','):
                a = a.strip()
                # Drop the param name, keep the type
                parts = a.split()
                if len(parts) >= 2:
                    arg_types.append(parts[-2] if parts[-1] != ']' else parts[-2] + '[]')
                elif len(parts) == 1:
                    arg_types.append(parts[0])
        sig = f'{name}({",".join(arg_types)})'
        methods.append(sig)
    return sorted(set(methods))


def compare(real, stub, classname):
    real_set = set(real) if real else set()
    stub_set = set(stub) if stub else set()

    missing_from_stub = real_set - stub_set
    extra_in_stub = stub_set - real_set

    print(f"\n=== {classname} ===")
    if real is None:
        print(f"  Class not found in jar — stub has {len(stub_set)} methods")
        return
    if stub is None:
        print(f"  No stub file — real interface has {len(real_set)} methods")
        return

    print(f"  Real:  {len(real_set)} methods")
    print(f"  Stub:  {len(stub_set)} methods")

    if not missing_from_stub and not extra_in_stub:
        print(f"  ✓ MATCH — stub covers the real interface exactly")
        return

    if missing_from_stub:
        print(f"\n  ⚠ REAL INTERFACE HAS METHODS WE DIDN'T STUB ({len(missing_from_stub)}):")
        print(f"    (these cause AbstractMethodError if Per3Reader implements this interface)")
        for m in sorted(missing_from_stub):
            print(f"      + {m}")

    if extra_in_stub:
        print(f"\n  ℹ OUR STUB HAS EXTRAS (harmless — they just don't exist on the real interface):")
        for m in sorted(extra_in_stub):
            print(f"      - {m}")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('jar', help='Path to extracted dsi.jar')
    args = ap.parse_args()

    if not os.path.isfile(args.jar):
        print(f"[ERROR] {args.jar} not found")
        sys.exit(1)

    # Verify jar is readable
    try:
        zf = zipfile.ZipFile(args.jar)
        classes = [n.replace('/', '.').replace('.class', '')
                   for n in zf.namelist() if n.endswith('.class')]
        zf.close()
    except zipfile.BadZipFile:
        print(f"[ERROR] {args.jar} is not a valid JAR/ZIP")
        sys.exit(1)

    print(f"[+] {args.jar} contains {len(classes)} classes")

    # Print all DSI classes present, in case there are additional ones we should know about
    dsi_classes = sorted([c for c in classes if 'dsi' in c.lower()])
    if dsi_classes:
        print(f"\n[+] DSI classes in this jar:")
        for c in dsi_classes:
            print(f"      {c}")

    for iface in REAL_INTERFACES:
        real = javap_methods(args.jar, iface)
        # Map to our stub path
        stub_rel = iface.replace('.', '/') + '.java'
        stub_path = os.path.join(STUB_ROOT, stub_rel)
        stub = stub_methods(stub_path)
        compare(real, stub, iface)


if __name__ == '__main__':
    main()
