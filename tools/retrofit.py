#!/usr/bin/env python3
"""
retrofit.py — Apply DrGER2 corrections to module scripts.

Inserts a platform.sh source block at the TOP of each script (right after
the shebang + comment header, before ANY code), then replaces the stale
`$(date +%Y%m%d-%H%M%S)` timestamp pattern with `$(mmi_logstamp)`.

Placement is critical: mmi_logstamp must be defined before any assignment
uses it. That means the block goes after the shebang and contiguous leading
comments, but before the first non-comment line — which is typically the
first variable assignment.

Idempotent: already-retrofitted files are skipped.
"""
import os
import sys

REPO = os.path.dirname(os.path.abspath(__file__))

PLATFORM_SOURCE_BLOCK = r'''
# --- platform.sh (shared variant detection + getTime helper) ---
# Defines MMI_VARIANT / MMI_VARIANT_ID / MMI_TRAIN and mmi_logstamp().
# Must be sourced before any code that calls mmi_logstamp.
_SDPATH_GUESS="${SDPATH:-$(dirname $0)}"
if [ -f "${_SDPATH_GUESS}/scripts/common/platform.sh" ]; then
    . "${_SDPATH_GUESS}/scripts/common/platform.sh"
elif [ -f "/mnt/efs-system/scripts/common/platform.sh" ]; then
    . "/mnt/efs-system/scripts/common/platform.sh"
else
    # Inline minimal fallback (DrGER2 review corrections applied)
    MMI_VARIANT="UNKNOWN"; MMI_VARIANT_ID=""
    for _f in /etc/pci-3g_*.cfg; do
        [ -f "$_f" ] || continue
        MMI_VARIANT_ID="$(echo "$_f" | sed -n 's,^/etc/pci-3g_\([0-9]*\)\.cfg$,\1,p')"
        case "$MMI_VARIANT_ID" in
            9304)           MMI_VARIANT="MMI3G_BASIC" ;;
            9308)           MMI_VARIANT="MMI3G_HIGH" ;;
            9411|9436|9478) MMI_VARIANT="MMI3GP" ;;
        esac
        break
    done
    MMI_TRAIN="$(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
    [ -z "$MMI_TRAIN" ] && MMI_TRAIN="$(sloginfo -m 10000 -s 5 2>/dev/null | sed -n 's/^.* +++ Train //p' | sed -n 1p)"
    [ -z "$MMI_TRAIN" ] && MMI_TRAIN="n/a"
    if [ "$MMI_VARIANT" = "MMI3GP" ] && echo "$MMI_TRAIN" | grep -q "_VW_"; then
        MMI_VARIANT="RNS850"
    fi
    mmi_logstamp() {
        if command -v getTime >/dev/null 2>&1; then
            _T="$(getTime 2>/dev/null)"
            [ -n "$_T" ] && { date -r "$_T" +%Y%m%d-%H%M%S 2>/dev/null || echo "epoch-$_T"; return 0; }
        fi
        date +%Y%m%d-%H%M%S 2>/dev/null
    }
    mmi_getTime() {
        if command -v getTime >/dev/null 2>&1; then getTime 2>/dev/null; else date +%s 2>/dev/null; fi
    }
fi
# --- end platform.sh source ---
'''.strip('\n')


def find_insertion_point(lines):
    """Return the index where the platform.sh block should be inserted.

    Skips the shebang + any contiguous leading comments/blanks. The block
    goes right before the first line that looks like actual code.
    """
    i = 0
    n = len(lines)

    # Skip shebang
    if i < n and lines[i].startswith('#!'):
        i += 1

    # Skip contiguous leading comments and blank lines
    while i < n:
        stripped = lines[i].strip()
        if stripped == '' or stripped.startswith('#'):
            i += 1
        else:
            break

    return i


def already_retrofitted(content):
    return ('platform.sh source' in content) or ('mmi_logstamp' in content)


def retrofit_file(path):
    with open(path, 'r') as f:
        content = f.read()

    if already_retrofitted(content):
        return 'already'

    has_date = '$(date +%Y%m%d-%H%M%S)' in content or '`date +%Y%m%d-%H%M%S`' in content
    if not has_date:
        return 'no-date'

    lines = content.split('\n')
    insert_idx = find_insertion_point(lines)

    # Build the new content: [header] + [platform.sh block] + [blank] + [rest]
    block_lines = PLATFORM_SOURCE_BLOCK.split('\n')
    new_lines = lines[:insert_idx] + block_lines + [''] + lines[insert_idx:]
    new_content = '\n'.join(new_lines)

    # Replace the timestamp pattern
    new_content = new_content.replace(
        '$(date +%Y%m%d-%H%M%S)',
        '$(mmi_logstamp)'
    )
    new_content = new_content.replace(
        '`date +%Y%m%d-%H%M%S`',
        '`mmi_logstamp`'
    )

    with open(path, 'w') as f:
        f.write(new_content)

    return 'retrofitted'


def main():
    modules_dir = os.path.join(REPO, 'modules')
    stats = {'retrofitted': 0, 'already': 0, 'no-date': 0}
    touched = []

    for mod in sorted(os.listdir(modules_dir)):
        scripts = os.path.join(modules_dir, mod, 'scripts')
        if not os.path.isdir(scripts):
            continue
        for fname in sorted(os.listdir(scripts)):
            if not fname.endswith('.sh'):
                continue
            path = os.path.join(scripts, fname)
            result = retrofit_file(path)
            stats[result] = stats.get(result, 0) + 1
            if result == 'retrofitted':
                touched.append(f'{mod}/{fname}')

    print('=== Retrofit results ===')
    for k, v in stats.items():
        print(f'  {k}: {v}')
    print()
    print('Touched files:')
    for t in touched:
        print(f'  {t}')


if __name__ == '__main__':
    main()
