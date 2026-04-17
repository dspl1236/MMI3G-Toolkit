#!/usr/bin/env python3
"""
eol_modifier.py — modify EOL feature flags in lsd.jxe.

EOL (End-of-Line) flags in sysconst.properties control which features
are available on the MMI3G head unit. This tool modifies flags inside
the lsd.jxe JAR archive to enable/disable features.

Usage:
    # List all flags and their current state
    python3 tools/eol_modifier.py /path/to/lsd.jxe --list

    # Enable Google Earth
    python3 tools/eol_modifier.py /path/to/lsd.jxe --output modified_lsd.jxe \
        --enable EOLFLAG_GOOGLE_EARTH

    # Enable multiple features
    python3 tools/eol_modifier.py /path/to/lsd.jxe --output modified_lsd.jxe \
        --enable EOLFLAG_GOOGLE_EARTH \
        --enable EOLFLAG_ONLINE_SERVICES \
        --enable EOLFLAG_INNOVATIONFEATURES

    # Disable a feature
    python3 tools/eol_modifier.py /path/to/lsd.jxe --output modified_lsd.jxe \
        --disable EOLFLAG_DEVICES_TV

After modifying lsd.jxe, deploy it with:
    python3 tools/patch_ifs.py ifs_decomp.ifs ifs_patched.ifs \
        --replace lsd/lsd.jxe=modified_lsd.jxe

WARNING: Enabling features that require missing hardware (RSE, TV tuner,
phone cradle, etc.) may cause error messages or instability. Only enable
features your vehicle supports.
"""
import argparse
import os
import re
import shutil
import sys
import zipfile


SYSCONST_PATH = "resources/sysconst/sysconst.properties"

# Features known to be safe to toggle
SAFE_FEATURES = {
    'EOLFLAG_GOOGLE_EARTH': 'Google Earth integration',
    'EOLFLAG_ONLINE_SERVICES': 'Audi Connect online services',
    'EOLFLAG_ONLINE_SEARCH': 'Online search in navigation',
    'EOLFLAG_ONLINE_SEARCH_SDS': 'Voice-activated online search',
    'EOLFLAG_INNOVATIONFEATURES': 'Innovation features package',
    'EOLFLAG_DEVICES_OFFROAD_NAVIGATION': 'Offroad navigation mode',
    'EOLFLAG_ENGINEERINGMENU_TV': 'TV engineering menu',
    'EOLFLAG_CLUSTER_VARIANT': 'Instrument cluster integration',
    'EOLFLAG_CLUSTER_VARIANT_TAB_AUDIO': 'Audio tab in cluster',
    'EOLFLAG_CLUSTER_VARIANT_TAB_NAVI': 'Navigation tab in cluster',
    'EOLFLAG_CLUSTER_VARIANT_TAB_PHONE': 'Phone tab in cluster',
    'EOLFLAG_MECCA_FEATURE': 'Mecca compass direction feature',
    'EOLFLAG_TUNER_PRESET_LASTMODE_ACTIVE': 'Tuner preset last-mode memory',
}

# Features that require specific hardware
HARDWARE_FEATURES = {
    'EOLFLAG_RSE': 'Rear Seat Entertainment (requires RSE hardware)',
    'EOLFLAG_OPERATOR_SERVICE': 'Operator services (requires active SIM)',
    'EOLFLAG_PHONE': 'Phone module (requires phone cradle)',
    'EOLFLAG_ADR': 'ADR (requires specific hardware)',
    'EOLFLAG_BREAKDOWN_CALL': 'Breakdown call (requires active SIM + service)',
}


def read_flags(jxe_path):
    """Read EOL flags from lsd.jxe."""
    z = zipfile.ZipFile(jxe_path, 'r')
    sc = z.read(SYSCONST_PATH).decode('utf-8')
    z.close()

    flags = {}
    for line in sc.split('\n'):
        line = line.strip()
        if line.startswith('EOLFLAG_') and '=' in line:
            name, val = line.split('=', 1)
            flags[name.strip()] = val.strip()

    return flags, sc


def modify_jxe(jxe_path, output_path, changes):
    """Create a modified lsd.jxe with changed EOL flags."""
    flags, sc = read_flags(jxe_path)

    # Apply changes
    modified_sc = sc
    for name, new_val in changes.items():
        # Use regex to replace the value
        pattern = rf'^({re.escape(name)}\s*=\s*)\S+(.*)'
        replacement = rf'\g<1>{new_val}\2'
        modified_sc, count = re.subn(pattern, replacement, modified_sc, flags=re.MULTILINE)
        if count == 0:
            print(f"WARNING: {name} not found in sysconst.properties", file=sys.stderr)
        else:
            old_val = flags.get(name, '?')
            print(f"  {name}: {old_val} → {new_val}")

    # Create new JAR with modified sysconst.properties
    # Copy all entries except the one we're modifying
    with zipfile.ZipFile(jxe_path, 'r') as zin:
        with zipfile.ZipFile(output_path, 'w', compression=zipfile.ZIP_STORED) as zout:
            for item in zin.infolist():
                if item.filename == SYSCONST_PATH:
                    # Write modified version
                    zout.writestr(item, modified_sc.encode('utf-8'))
                else:
                    # Copy original
                    data = zin.read(item.filename)
                    zout.writestr(item, data)

    print(f"\nWrote {output_path} ({os.path.getsize(output_path):,} bytes)")


def main():
    p = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('jxe', help='Path to lsd.jxe')
    p.add_argument('--output', '-o', help='Output path for modified lsd.jxe')
    p.add_argument('--list', action='store_true', help='List all flags')
    p.add_argument('--enable', action='append', default=[],
                   metavar='FLAG', help='Enable a feature flag (set to 1)')
    p.add_argument('--disable', action='append', default=[],
                   metavar='FLAG', help='Disable a feature flag (set to 0)')
    p.add_argument('--set', action='append', default=[], nargs=2,
                   metavar=('FLAG', 'VALUE'),
                   help='Set a flag to a specific value')
    args = p.parse_args()

    flags, _ = read_flags(args.jxe)

    if args.list:
        disabled = {k: v for k, v in flags.items() if v == '0'}
        enabled = {k: v for k, v in flags.items() if v != '0'}

        print(f"=== Enabled ({len(enabled)}) ===")
        for k in sorted(enabled):
            desc = SAFE_FEATURES.get(k, HARDWARE_FEATURES.get(k, ''))
            suffix = f'  — {desc}' if desc else ''
            print(f"  {k} = {enabled[k]}{suffix}")

        print(f"\n=== Disabled ({len(disabled)}) — can be enabled ===")
        for k in sorted(disabled):
            desc = SAFE_FEATURES.get(k, HARDWARE_FEATURES.get(k, ''))
            safe = '✓' if k in SAFE_FEATURES else '⚠' if k in HARDWARE_FEATURES else ' '
            suffix = f'  — {desc}' if desc else ''
            print(f"  {safe} {k} = 0{suffix}")

        print(f"\n✓ = safe to enable  ⚠ = requires specific hardware")
        return

    # Build changes dict
    changes = {}
    for flag in args.enable:
        if not flag.startswith('EOLFLAG_'):
            flag = 'EOLFLAG_' + flag
        if flag in HARDWARE_FEATURES:
            print(f"WARNING: {flag} — {HARDWARE_FEATURES[flag]}")
        changes[flag] = '1'

    for flag in args.disable:
        if not flag.startswith('EOLFLAG_'):
            flag = 'EOLFLAG_' + flag
        changes[flag] = '0'

    for flag, val in args.set:
        if not flag.startswith('EOLFLAG_'):
            flag = 'EOLFLAG_' + flag
        changes[flag] = val

    if not changes:
        print("No changes specified. Use --enable, --disable, or --set.")
        print("Use --list to see available flags.")
        return

    if not args.output:
        print("ERROR: --output required for modifications.", file=sys.stderr)
        return

    print(f"Modifying {len(changes)} EOL flag(s):")
    modify_jxe(args.jxe, args.output, changes)


if __name__ == '__main__':
    main()
