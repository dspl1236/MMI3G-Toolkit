#!/usr/bin/env python3
"""
eol_modifier.py — inspect and modify EOL feature flags in lsd.jxe.

EOL (End-of-Line) flags in sysconst.properties control which features
are available on the MMI3G head unit. This tool can both inspect the
variant/range overlay stack inside lsd.jxe and modify base EOL flags.

Usage:
    # List master sysconst EOL flags
    python3 tools/eol_modifier.py /path/to/lsd.jxe --list

    # Show raw variant selector and inferred active variant layers
    python3 tools/eol_modifier.py /path/to/lsd.jxe --show-variant

    # List available variant bundles with region / variant summaries
    python3 tools/eol_modifier.py /path/to/lsd.jxe --list-variants

    # Diff two variant bundles
    python3 tools/eol_modifier.py /path/to/lsd.jxe \
        --diff-variants vw_high_nar high_nav_nar

    # Show RANGE_ locks and effective values for selected flags
    python3 tools/eol_modifier.py /path/to/lsd.jxe \
        --variant vw_high_nar \
        --variant no_online_services \
        --show-range-locks \
        --show-effective GOOGLE_EARTH \
        --show-effective INNOVATIONFEATURES

    # Enable Google Earth in the base sysconst.properties
    python3 tools/eol_modifier.py /path/to/lsd.jxe --output modified_lsd.jxe \
        --enable EOLFLAG_GOOGLE_EARTH

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
import sys
import zipfile
from collections import OrderedDict


SYSCONST_PATH = "resources/sysconst/sysconst.properties"
VARIANT_SELECTOR_PATH = "resources/sysconst/variant.properties"
VARIANTS_DIR = "resources/sysconst/variants/"

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


def parse_properties(text):
    """Parse a Java .properties file into an ordered dict."""
    props = OrderedDict()
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith('#') or line.startswith('!'):
            continue
        if '=' in line:
            key, value = line.split('=', 1)
        elif ':' in line:
            key, value = line.split(':', 1)
        else:
            continue
        props[key.strip()] = value.strip()
    return props


def read_zip_text(zf, path):
    try:
        return zf.read(path).decode('utf-8')
    except KeyError:
        return None


def load_jxe_config(jxe_path):
    """Load sysconst, variant selector, and variant bundles from lsd.jxe."""
    with zipfile.ZipFile(jxe_path, 'r') as zf:
        sysconst_text = zf.read(SYSCONST_PATH).decode('utf-8')
        selector_text = read_zip_text(zf, VARIANT_SELECTOR_PATH)

        variants = OrderedDict()
        for name in sorted(zf.namelist()):
            if not name.startswith(VARIANTS_DIR) or not name.endswith('.properties'):
                continue
            variant_name = os.path.basename(name)[:-len('.properties')]
            variants[variant_name] = {
                'path': name,
                'text': zf.read(name).decode('utf-8'),
            }

    base_props = parse_properties(sysconst_text)
    selector_props = parse_properties(selector_text or '')
    for variant_name, variant_data in variants.items():
        variant_data['props'] = parse_properties(variant_data['text'])

    return {
        'sysconst_text': sysconst_text,
        'base_props': base_props,
        'selector_text': selector_text or '',
        'selector_props': selector_props,
        'variants': variants,
    }


def read_flags(jxe_path):
    """Read base EOL flags from sysconst.properties."""
    cfg = load_jxe_config(jxe_path)
    flags = OrderedDict()
    for name, value in cfg['base_props'].items():
        if name.startswith('EOLFLAG_'):
            flags[name] = value
    return flags, cfg['sysconst_text']


def normalize_flag_name(name):
    if name.startswith('EOLFLAG_') or name.startswith('RANGE_'):
        return name
    return 'EOLFLAG_' + name


def feature_description(flag_name):
    return SAFE_FEATURES.get(flag_name, HARDWARE_FEATURES.get(flag_name, ''))


def summarize_flags(flags):
    disabled = {k: v for k, v in flags.items() if v == '0'}
    enabled = {k: v for k, v in flags.items() if v != '0'}

    print("=== Enabled ({}) ===".format(len(enabled)))
    for key in sorted(enabled):
        desc = feature_description(key)
        suffix = '  — {}'.format(desc) if desc else ''
        print("  {} = {}{}".format(key, enabled[key], suffix))

    print("\n=== Disabled ({}) — can be enabled ===".format(len(disabled)))
    for key in sorted(disabled):
        desc = feature_description(key)
        safe = '✓' if key in SAFE_FEATURES else '⚠' if key in HARDWARE_FEATURES else ' '
        suffix = '  — {}'.format(desc) if desc else ''
        print("  {} {} = 0{}".format(safe, key, suffix))

    print("\n✓ = safe to enable  ⚠ = requires specific hardware")


def infer_active_variants(selector_props, available_variants):
    """Best-effort inference of active variant layers from variant.properties."""
    available = set(available_variants)
    inferred = []

    def add_variant(name):
        if name in available and name not in inferred:
            inferred.append(name)

    truthy = {'1', 'true', 'yes', 'on', 'active', 'enabled'}
    splitter = re.compile(r'[,\s;|]+')

    for key, value in selector_props.items():
        if key in available and value.lower() in truthy:
            add_variant(key)

        for token in splitter.split(value):
            token = token.strip()
            if not token:
                continue
            if token.endswith('.properties'):
                token = token[:-len('.properties')]
            add_variant(token)

    return inferred


def get_variant_layers(config, explicit_variants):
    """Return the ordered variant layers to inspect."""
    if explicit_variants:
        missing = [name for name in explicit_variants if name not in config['variants']]
        if missing:
            available = ', '.join(sorted(config['variants']))
            raise KeyError(
                "Unknown variant(s): {}. Available: {}".format(', '.join(missing), available)
            )
        return explicit_variants
    return infer_active_variants(config['selector_props'], config['variants'].keys())


def variant_summary(variant_name, variant_props):
    eol_count = 0
    range_count = 0
    hu_variant = None
    hu_region = None
    for key, value in variant_props.items():
        if key.startswith('EOLFLAG_'):
            eol_count += 1
        if key.startswith('RANGE_'):
            range_count += 1
        if key == 'EOLFLAG_HU_VARIANT':
            hu_variant = value
        elif key == 'EOLFLAG_HU_REGION':
            hu_region = value
    return {
        'name': variant_name,
        'eol_count': eol_count,
        'range_count': range_count,
        'hu_variant': hu_variant,
        'hu_region': hu_region,
    }


def compose_effective_values(config, layer_names):
    """Overlay base props with variant props and track source/range constraints."""
    raw = {}
    ranges = {}

    for key, value in config['base_props'].items():
        if key.startswith('EOLFLAG_'):
            raw[key] = {'value': value, 'source': 'sysconst.properties'}
        elif key.startswith('RANGE_'):
            target = key[len('RANGE_'):]
            ranges[target] = {'value': value, 'source': 'sysconst.properties'}

    for layer_name in layer_names:
        source = layer_name + '.properties'
        for key, value in config['variants'][layer_name]['props'].items():
            if key.startswith('EOLFLAG_'):
                raw[key] = {'value': value, 'source': source}
            elif key.startswith('RANGE_'):
                target = key[len('RANGE_'):]
                ranges[target] = {'value': value, 'source': source}

    return raw, ranges


def print_variant_selector(config):
    print("=== Variant Selector ===")
    if config['selector_text'].strip():
        for key, value in config['selector_props'].items():
            print("  {} = {}".format(key, value))
    else:
        print("  variant.properties not present in this lsd.jxe")

    inferred = infer_active_variants(config['selector_props'], config['variants'].keys())
    print("\n=== Inferred Active Variant Layers ===")
    if inferred:
        for index, name in enumerate(inferred, 1):
            print("  {}. {}".format(index, name))
    else:
        print("  No variant layers inferred from variant.properties")


def print_available_variants(config):
    print("=== Available Variants ({}) ===".format(len(config['variants'])))
    for name in sorted(config['variants']):
        summary = variant_summary(name, config['variants'][name]['props'])
        print(
            "  {name:<28} EOL={eol_count:<4} RANGE={range_count:<3} "
            "HU_VARIANT={hu_variant:<4} HU_REGION={hu_region}".format(
                name=name,
                eol_count=summary['eol_count'],
                range_count=summary['range_count'],
                hu_variant=summary['hu_variant'] if summary['hu_variant'] is not None else '-',
                hu_region=summary['hu_region'] if summary['hu_region'] is not None else '-',
            )
        )


def print_variant_diff(config, left_name, right_name):
    left = config['variants'][left_name]['props']
    right = config['variants'][right_name]['props']
    keys = sorted(set(left) | set(right))

    print("=== Variant Diff: {} vs {} ===".format(left_name, right_name))
    changes = 0
    for key in keys:
        left_value = left.get(key)
        right_value = right.get(key)
        if left_value == right_value:
            continue
        changes += 1
        print(
            "  {}: {} -> {}".format(
                key,
                left_value if left_value is not None else '<unset>',
                right_value if right_value is not None else '<unset>',
            )
        )
    if changes == 0:
        print("  No differences")


def print_range_locks(config, layer_names):
    if not layer_names:
        print("=== RANGE Locks ===")
        print("  No active or requested variant layers to inspect")
        return

    print("=== RANGE Locks ({}) ===".format(', '.join(layer_names)))
    printed = 0
    for layer_name in layer_names:
        entries = []
        for key, value in config['variants'][layer_name]['props'].items():
            if key.startswith('RANGE_'):
                entries.append((key, value))
        if not entries:
            continue
        print("  [{}]".format(layer_name))
        for key, value in entries:
            target = key[len('RANGE_'):] if key.startswith('RANGE_') else key
            print("    {} = {}  -> constrains {}".format(key, value, target))
            printed += 1
    if printed == 0:
        print("  No RANGE_ constraints in the requested layers")


def print_effective_flags(config, layer_names, requested_flags):
    raw, ranges = compose_effective_values(config, layer_names)

    print("=== Effective Flags ({}) ===".format(', '.join(layer_names) if layer_names else 'base only'))
    for flag in requested_flags:
        name = normalize_flag_name(flag)
        raw_info = raw.get(name)
        range_info = ranges.get(name)

        raw_value = raw_info['value'] if raw_info else '<unset>'
        raw_source = raw_info['source'] if raw_info else '-'
        effective_value = range_info['value'] if range_info else raw_value
        effective_source = range_info['source'] if range_info else raw_source
        desc = feature_description(name)

        print("  {}".format(name))
        if desc:
            print("    description : {}".format(desc))
        print("    raw         : {} ({})".format(raw_value, raw_source))
        if range_info:
            print("    range lock  : {} ({})".format(range_info['value'], range_info['source']))
            print("    effective   : {} (range-constrained)".format(effective_value))
        else:
            print("    effective   : {} ({})".format(effective_value, effective_source))


def modify_jxe(jxe_path, output_path, changes):
    """Create a modified lsd.jxe with changed base EOL flags."""
    flags, sysconst_text = read_flags(jxe_path)

    modified_text = sysconst_text
    for name, new_value in changes.items():
        pattern = r'^({}\s*=\s*)\S+(.*)'.format(re.escape(name))
        replacement = r'\g<1>{}\2'.format(new_value)
        modified_text, count = re.subn(pattern, replacement, modified_text, flags=re.MULTILINE)
        if count == 0:
            print("WARNING: {} not found in sysconst.properties".format(name), file=sys.stderr)
        else:
            old_value = flags.get(name, '?')
            print("  {}: {} -> {}".format(name, old_value, new_value))

    with zipfile.ZipFile(jxe_path, 'r') as zin:
        with zipfile.ZipFile(output_path, 'w', compression=zipfile.ZIP_STORED) as zout:
            for item in zin.infolist():
                if item.filename == SYSCONST_PATH:
                    zout.writestr(item, modified_text.encode('utf-8'))
                else:
                    zout.writestr(item, zin.read(item.filename))

    print("\nWrote {} ({:,} bytes)".format(output_path, os.path.getsize(output_path)))


def build_changes(args):
    changes = OrderedDict()

    for flag in args.enable:
        normalized = normalize_flag_name(flag)
        if normalized in HARDWARE_FEATURES:
            print("WARNING: {} — {}".format(normalized, HARDWARE_FEATURES[normalized]))
        changes[normalized] = '1'

    for flag in args.disable:
        changes[normalize_flag_name(flag)] = '0'

    for flag, value in args.set:
        changes[normalize_flag_name(flag)] = value

    return changes


def main():
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument('jxe', help='Path to lsd.jxe')
    parser.add_argument('--output', '-o', help='Output path for modified lsd.jxe')
    parser.add_argument('--list', action='store_true', help='List base sysconst EOL flags')
    parser.add_argument('--show-variant', action='store_true',
                        help='Show raw variant selector properties and inferred active layers')
    parser.add_argument('--list-variants', action='store_true',
                        help='List available variant bundles with summary metadata')
    parser.add_argument('--variant', action='append', default=[],
                        metavar='NAME',
                        help='Variant layer to inspect (can be specified multiple times)')
    parser.add_argument('--diff-variants', nargs=2, metavar=('LEFT', 'RIGHT'),
                        help='Show property differences between two variant bundles')
    parser.add_argument('--show-range-locks', action='store_true',
                        help='Show RANGE_ constraints for the resolved variant layers')
    parser.add_argument('--show-effective', action='append', default=[],
                        metavar='FLAG',
                        help='Show effective value for an EOL flag after variant/range overlays')
    parser.add_argument('--enable', action='append', default=[],
                        metavar='FLAG', help='Enable a base sysconst feature flag (set to 1)')
    parser.add_argument('--disable', action='append', default=[],
                        metavar='FLAG', help='Disable a base sysconst feature flag (set to 0)')
    parser.add_argument('--set', action='append', default=[], nargs=2,
                        metavar=('FLAG', 'VALUE'),
                        help='Set a base sysconst flag to a specific value')
    args = parser.parse_args()

    config = load_jxe_config(args.jxe)
    flags = OrderedDict(
        (name, value) for name, value in config['base_props'].items() if name.startswith('EOLFLAG_')
    )

    if args.list:
        summarize_flags(flags)

    if args.show_variant:
        if args.list:
            print()
        print_variant_selector(config)

    if args.list_variants:
        if args.list or args.show_variant:
            print()
        print_available_variants(config)

    if args.diff_variants:
        left_name, right_name = args.diff_variants
        if left_name not in config['variants'] or right_name not in config['variants']:
            available = ', '.join(sorted(config['variants']))
            parser.error(
                "--diff-variants requires valid variant names. Available: {}".format(available)
            )
        if args.list or args.show_variant or args.list_variants:
            print()
        print_variant_diff(config, left_name, right_name)

    layers = []
    if args.show_range_locks or args.show_effective:
        try:
            layers = get_variant_layers(config, args.variant)
        except KeyError as exc:
            parser.error(str(exc))

    if args.show_range_locks:
        if args.list or args.show_variant or args.list_variants or args.diff_variants:
            print()
        print_range_locks(config, layers)

    if args.show_effective:
        if args.list or args.show_variant or args.list_variants or args.diff_variants or args.show_range_locks:
            print()
        print_effective_flags(config, layers, args.show_effective)

    changes = build_changes(args)
    if not changes:
        if any((
            args.list,
            args.show_variant,
            args.list_variants,
            args.diff_variants,
            args.show_range_locks,
            args.show_effective,
        )):
            return
        print("No changes specified. Use --enable, --disable, --set, or one of the inspection flags.")
        print("Use --list to see base EOL flags.")
        return

    if not args.output:
        print("ERROR: --output required for modifications.", file=sys.stderr)
        return

    print("Modifying {} base EOL flag(s):".format(len(changes)))
    modify_jxe(args.jxe, args.output, changes)


if __name__ == '__main__':
    main()
