"""
MMI3G-Toolkit SD Card Builder

Assembles selected modules into a complete, ready-to-use SD card package
for Audi/VW MMI3G, MMI3G+, and RNS-850 infotainment systems.

Usage:
    python build_sd.py --list                              List available modules
    python build_sd.py --all -o ./sdcard                  Build with all ready modules
    python build_sd.py --all --target-platform RNS-850    Build only RNS-850-safe modules
    python build_sd.py -m gauges-dashboard -m system-info -o ./sdcard
    python build_sd.py -m gauges-dashboard -o F:          Build directly to SD card

The builder:
  1. Validates module manifests before doing any work
  2. Copies core files (encoded copie_scr.sh, run.sh)
  3. Copies selected module files (engdefs, scripts, artifacts, payload dirs)
  4. Generates a combined run.sh that installs all selected modules
  5. Creates the required directory structure (bin, lib, var)
"""

import argparse
from collections import OrderedDict
import json
import os
import shutil
import sys

# Resolve paths relative to this script
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
MODULES_DIR = os.path.join(REPO_ROOT, 'modules')
CORE_DIR = os.path.join(REPO_ROOT, 'core')

if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from encoder import MMI3GCipher


SUPPORTED_PLATFORMS = ('MMI3G', 'MMI3G+', 'RNS-850')
REQUIRED_MANIFEST_FIELDS = (
    'name',
    'version',
    'description',
    'author',
    'status',
    'compatible',
)


class ModuleConfigError(Exception):
    """Raised when module metadata is invalid."""


def module_is_compatible(meta: dict, target_platform: str = None) -> bool:
    """Return True if the module supports the requested target platform."""
    return target_platform is None or target_platform in meta.get('compatible', [])


def parse_manifest_asset(entry, expected_ext: str) -> str:
    """Extract a filename from a manifest asset declaration."""
    if not isinstance(entry, str) or not entry.strip():
        raise ModuleConfigError(
            f"Manifest asset entries must be non-empty strings, got {entry!r}"
        )

    filename = entry.split(' - ', 1)[0].strip()
    if not filename.endswith(expected_ext):
        raise ModuleConfigError(
            f"Manifest asset '{entry}' does not reference a {expected_ext} file"
        )
    return filename


def validate_declared_assets(
    mod_name: str,
    mod_dir: str,
    meta: dict,
    manifest_key: str,
    subdir: str,
    expected_ext: str,
) -> list:
    """Validate that manifest-declared files exist on disk."""
    errors = []
    declarations = meta.get(manifest_key)
    if declarations is None:
        return errors

    if not isinstance(declarations, list):
        errors.append(f"'{manifest_key}' must be a list")
        return errors

    for entry in declarations:
        try:
            filename = parse_manifest_asset(entry, expected_ext)
        except ModuleConfigError as exc:
            errors.append(str(exc))
            continue

        asset_path = os.path.join(mod_dir, subdir, filename)
        if not os.path.isfile(asset_path):
            errors.append(
                f"declares {manifest_key[:-1]} '{filename}' but file is missing at "
                f"{asset_path}"
            )

    return errors


def is_safe_relative_path(path: str) -> bool:
    """Return True for manifest paths that stay within the module/output tree."""
    if not isinstance(path, str) or not path.strip():
        return False

    if '\\' in path:
        return False

    normalized = os.path.normpath(path.strip())
    return (
        normalized not in ('.', '..')
        and not os.path.isabs(normalized)
        and not normalized.startswith(f'..{os.sep}')
    )


def validate_payload_dirs(mod_dir: str, meta: dict) -> list:
    """Validate module payload directories copied verbatim to SD card output."""
    errors = []
    payload_dirs = meta.get('payload_dirs')
    if payload_dirs is None:
        return errors

    if not isinstance(payload_dirs, list):
        return ["'payload_dirs' must be a list"]

    for entry in payload_dirs:
        if not isinstance(entry, dict):
            errors.append("'payload_dirs' entries must be objects")
            continue

        source = entry.get('source')
        target = entry.get('target')
        if not is_safe_relative_path(source):
            errors.append("'payload_dirs[].source' must be a safe relative path")
            continue
        if target is not None and not is_safe_relative_path(target):
            errors.append("'payload_dirs[].target' must be a safe relative path")
            continue

        source_path = os.path.join(mod_dir, os.path.normpath(source))
        if not os.path.isdir(source_path):
            errors.append(
                f"declares payload_dir '{source}' but directory is missing at "
                f"{source_path}"
            )

    return errors


def validate_module_metadata(mod_name: str, mod_dir: str, meta: dict):
    """Validate a single module manifest."""
    errors = []

    missing = [field for field in REQUIRED_MANIFEST_FIELDS if field not in meta]
    if missing:
        errors.append(f"missing required field(s): {', '.join(missing)}")

    if meta.get('name') != mod_name:
        errors.append(
            f"'name' must match the module directory ('{mod_name}'), "
            f"got {meta.get('name')!r}"
        )

    compatible = meta.get('compatible')
    if compatible is not None:
        if not isinstance(compatible, list) or not compatible:
            errors.append("'compatible' must be a non-empty list")
        else:
            invalid = [
                platform
                for platform in compatible
                if platform not in SUPPORTED_PLATFORMS
            ]
            if invalid:
                errors.append(
                    f"unsupported platform(s) in 'compatible': {', '.join(invalid)}"
                )

    for field in ('version', 'description', 'author', 'status'):
        value = meta.get(field)
        if value is not None and (not isinstance(value, str) or not value.strip()):
            errors.append(f"'{field}' must be a non-empty string")

    prereq = meta.get('prereq')
    if prereq is not None:
        if not isinstance(prereq, str) or not prereq.strip():
            errors.append("'prereq' must be a non-empty string when present")
        elif prereq == mod_name:
            errors.append("'prereq' cannot point to the module itself")

    script_dir = meta.get('script_dir')
    if script_dir is not None:
        if not isinstance(script_dir, str) or not script_dir.startswith('/'):
            errors.append("'script_dir' must be an absolute flash path when present")

    standalone = bool(meta.get('standalone'))
    run_script = meta.get('run_script')
    if standalone and not run_script:
        errors.append("'standalone' modules must declare 'run_script'")
    if run_script is not None:
        if not isinstance(run_script, str) or not run_script.endswith('.sh'):
            errors.append("'run_script' must name a .sh file")
        else:
            run_script_path = os.path.join(mod_dir, 'scripts', run_script)
            if not os.path.isfile(run_script_path):
                errors.append(
                    f"declares run_script '{run_script}' but file is missing at "
                    f"{run_script_path}"
                )

    artifact = meta.get('artifact')
    if artifact is not None:
        if not isinstance(artifact, str) or not artifact.strip():
            errors.append("'artifact' must be a non-empty filename when present")
        else:
            artifact_path = os.path.join(mod_dir, artifact)
            if not os.path.isfile(artifact_path):
                errors.append(
                    f"declares artifact '{artifact}' but file is missing at "
                    f"{artifact_path}"
                )

    errors.extend(
        validate_declared_assets(mod_name, mod_dir, meta, 'screens', 'engdefs', '.esd')
    )
    errors.extend(
        validate_declared_assets(mod_name, mod_dir, meta, 'scripts', 'scripts', '.sh')
    )
    errors.extend(validate_payload_dirs(mod_dir, meta))

    if errors:
        raise ModuleConfigError(f"module '{mod_name}': " + '; '.join(errors))


def load_module_metadata(mod_name: str, mod_dir: str) -> dict:
    """Load and validate one module manifest."""
    meta_file = os.path.join(mod_dir, 'module.json')
    try:
        with open(meta_file, 'r', encoding='utf-8') as f:
            meta = json.load(f)
    except json.JSONDecodeError as exc:
        raise ModuleConfigError(
            f"module '{mod_name}': invalid JSON in {meta_file}: {exc}"
        )

    validate_module_metadata(mod_name, mod_dir, meta)
    meta['_dir'] = mod_dir
    meta['_name'] = mod_name
    return meta


def validate_module_relationships(modules: dict):
    """Validate cross-module references such as prerequisites."""
    for mod_name, meta in modules.items():
        prereq = meta.get('prereq')
        if not prereq:
            continue

        if prereq not in modules:
            raise ModuleConfigError(
                f"module '{mod_name}' requires unknown prerequisite '{prereq}'"
            )

        prereq_compat = set(modules[prereq].get('compatible', []))
        missing_platforms = [
            platform for platform in meta.get('compatible', [])
            if platform not in prereq_compat
        ]
        if missing_platforms:
            raise ModuleConfigError(
                f"module '{mod_name}' requires '{prereq}', but '{prereq}' is not "
                f"compatible with: {', '.join(missing_platforms)}"
            )


def find_modules(modules_dir: str = None) -> dict:
    """Discover all available modules and validate their manifests."""
    modules = {}
    modules_dir = modules_dir or MODULES_DIR
    if not os.path.isdir(modules_dir):
        return modules

    for name in sorted(os.listdir(modules_dir)):
        mod_dir = os.path.join(modules_dir, name)
        meta_file = os.path.join(mod_dir, 'module.json')
        if os.path.isdir(mod_dir) and os.path.isfile(meta_file):
            modules[name] = load_module_metadata(name, mod_dir)

    validate_module_relationships(modules)
    return modules


def list_modules(modules: dict, target_platform: str = None):
    """Print available modules."""
    print("Available modules:")
    print("=" * 60)

    found = False
    for name, meta in modules.items():
        if not module_is_compatible(meta, target_platform):
            continue

        found = True
        status = meta.get('status', 'unknown')
        compat = ', '.join(meta.get('compatible', ['MMI3G+']))
        print(f"  {name}")
        print(f"    {meta.get('description', 'No description')}")
        print(f"    Status: {status} | Compatible: {compat}")
        print()

    if not found and target_platform:
        print(f"  No modules compatible with {target_platform}.")


def resolve_selected_modules(
    selected_modules: list,
    modules: dict,
    target_platform: str = None,
) -> tuple:
    """Resolve prerequisites and platform compatibility for a selection."""
    requested = list(OrderedDict.fromkeys(selected_modules))
    requested_set = set(requested)
    incompatible = [
        name
        for name in requested
        if not module_is_compatible(modules[name], target_platform)
    ]
    if incompatible:
        raise ModuleConfigError(
            f"selected module(s) not compatible with {target_platform}: "
            f"{', '.join(incompatible)}"
        )

    resolved = []
    visiting = []
    auto_added_by = {}

    def visit(mod_name: str):
        if mod_name in resolved:
            return
        if mod_name in visiting:
            cycle = visiting[visiting.index(mod_name):] + [mod_name]
            raise ModuleConfigError(
                f"circular prerequisite chain detected: {' -> '.join(cycle)}"
            )

        visiting.append(mod_name)
        prereq = modules[mod_name].get('prereq')
        if prereq:
            if prereq not in modules:
                raise ModuleConfigError(
                    f"module '{mod_name}' requires unknown prerequisite '{prereq}'"
                )
            if prereq not in requested_set and prereq not in auto_added_by:
                auto_added_by[prereq] = mod_name
            visit(prereq)
        visiting.pop()

        if mod_name not in resolved:
            resolved.append(mod_name)

    for mod_name in requested:
        visit(mod_name)

    auto_added = [
        (mod_name, auto_added_by[mod_name])
        for mod_name in resolved
        if mod_name in auto_added_by
    ]
    return resolved, auto_added


def generate_run_sh(selected_modules: list, modules: dict) -> str:
    """Generate the combined run.sh for selected modules."""
    needs_flash_install = any(
        modules[name].get('installs_to_flash', True)
        for name in selected_modules
    )

    lines = [
        '#!/bin/ksh',
        '# ============================================================',
        '# MMI3G-Toolkit - Combined Installer',
        '# Auto-generated by build_sd.py',
        '# ============================================================',
        '',
        'SDPATH="${1:-$(dirname $0)}"',
        'export SDPATH',
        '',
        '# Source platform.sh for QNX compatibility shims (head, basename,',
        '# wc, printf, awk, sync, mkdir -p all shimmed for QNX)',
        'if [ -f "${SDPATH}/scripts/common/platform.sh" ]; then',
        '    . "${SDPATH}/scripts/common/platform.sh"',
        'fi',
        '',
        '# Show "running" status on MMI display',
        'if [ -f "${SDPATH}/bin/showScreen" ] && [ -f "${SDPATH}/lib/running.png" ]; then',
        '    cp "${SDPATH}/bin/showScreen" /tmp/showScreen 2>/dev/null',
        '    chmod +x /tmp/showScreen 2>/dev/null',
        '    /tmp/showScreen "${SDPATH}/lib/running.png" &',
        '    SHOWSCREEN_PID=$!',
        'fi',
        '',
        'LOGFILE="${SDPATH}/var/install-$(date +%Y%m%d-%H%M%S).log"',
        'EFSDIR="/mnt/efs-system"',
        'ENGDEFS="${EFSDIR}/engdefs"',
        '',
        'exec > ${LOGFILE} 2>&1',
        '',
        'echo "============================================"',
        'echo " MMI3G-Toolkit Installer"',
        'echo " $(date)"',
        'echo " Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"',
        'echo "============================================"',
        'echo ""',
        '',
    ]

    if needs_flash_install:
        lines.extend([
            '# Safety checks',
            'if [ ! -d "${EFSDIR}" ]; then',
            '    echo "[ERROR] /mnt/efs-system not found!"',
            '    exit 1',
            'fi',
            '',
            '# Create engdefs if needed (gem-activator will populate it)',
            'mkdir -p "${ENGDEFS}" 2>/dev/null',
            '',
            '# Remount read-write',
            'mount -uw ${EFSDIR} 2>/dev/null',
            'if [ $? -ne 0 ]; then',
            '    echo "[ERROR] Failed to remount efs-system"',
            '    exit 1',
            'fi',
            'echo "[OK] efs-system remounted rw"',
            'echo ""',
            '',
            '# Install shared platform.sh helper (sourced by module scripts)',
            'if [ -f "${SDPATH}/scripts/common/platform.sh" ]; then',
            '    mkdir -p "${EFSDIR}/scripts/common"',
            '    cp -v "${SDPATH}/scripts/common/platform.sh" "${EFSDIR}/scripts/common/platform.sh"',
            '    chmod 0644 "${EFSDIR}/scripts/common/platform.sh"',
            '    echo "[OK] platform.sh installed to ${EFSDIR}/scripts/common/"',
            'fi',
            'echo ""',
            '',
        ])
    else:
        lines.extend([
            '# Selected modules are SD-only; do not remount or write efs-system.',
            'echo "[INFO] SD-only module set; efs-system will not be remounted"',
            'echo ""',
            '',
        ])

    # Add install section for each module
    for mod_name in selected_modules:
        meta = modules[mod_name]
        installs_to_flash = meta.get('installs_to_flash', True)
        lines.append(f'# --- Module: {mod_name} ---')
        lines.append(f'echo "[MODULE] Installing {mod_name}..."')
        if installs_to_flash:
            # Re-mount EFS rw (standalone modules may trigger F3S reclaim)
            lines.append('mount -uw ${EFSDIR} 2>/dev/null')
        else:
            lines.append('# SD-only module: run from card and skip flash install')

        # Check if module has a standalone run script
        # (e.g. gem-activator runs its own install logic)
        if meta.get('standalone') and meta.get('run_script'):
            run_script = meta['run_script']
            lines.append(f'if [ -f "${{SDPATH}}/scripts/{run_script}" ]; then')
            lines.append(f'    ksh "${{SDPATH}}/scripts/{run_script}" "${{SDPATH}}"')
            lines.append(f'    echo "[OK] {mod_name} standalone script executed"')
            lines.append(f'else')
            lines.append(f'    echo "[WARN] {run_script} not found for {mod_name}"')
            lines.append(f'fi')

            if installs_to_flash:
                # Also install scripts to flash for future use from GEM
                scripts_dir = os.path.join(meta['_dir'], 'scripts')
            else:
                scripts_dir = None
            if scripts_dir and os.path.isdir(scripts_dir):
                script_dest = meta.get('script_dir', f'/scripts/{mod_name}')
                lines.append(f'SCRIPTDIR="${{EFSDIR}}{script_dest}"')
                lines.append(f'mkdir -p ${{SCRIPTDIR}}')
                for script in sorted(os.listdir(scripts_dir)):
                    if script.endswith('.sh'):
                        lines.append(f'if [ -f "${{SDPATH}}/scripts/{script}" ]; then')
                        lines.append(
                            f'    cp -v "${{SDPATH}}/scripts/{script}" '
                            f'"${{SCRIPTDIR}}/{script}"'
                        )
                        lines.append(f'    chmod +x "${{SCRIPTDIR}}/{script}"')
                        lines.append(f'fi')
        elif installs_to_flash:
            # Standard module — install engdefs and scripts

            # Install engdefs
            lines.append(f'if [ -d "${{SDPATH}}/engdefs" ]; then')

            mod_dir = modules[mod_name]['_dir']
            engdefs_dir = os.path.join(mod_dir, 'engdefs')
            if os.path.isdir(engdefs_dir):
                for esd in sorted(os.listdir(engdefs_dir)):
                    if esd.endswith('.esd'):
                        lines.append(f'    if [ -f "${{SDPATH}}/engdefs/{esd}" ]; then')
                        lines.append(
                            f'        cp -v "${{SDPATH}}/engdefs/{esd}" '
                            f'"${{ENGDEFS}}/{esd}"'
                        )
                        lines.append(f'        echo "[INST] {esd}"')
                        lines.append(f'    fi')

            lines.append('fi')

            # Install scripts
            scripts_dir = os.path.join(mod_dir, 'scripts')
            if os.path.isdir(scripts_dir):
                script_dest = meta.get('script_dir', f'/scripts/{mod_name}')
                lines.append(f'SCRIPTDIR="${{EFSDIR}}{script_dest}"')
                lines.append(f'mkdir -p ${{SCRIPTDIR}}')
                lines.append(f'if [ -d "${{SDPATH}}/scripts" ]; then')

                for script in sorted(os.listdir(scripts_dir)):
                    if script.endswith('.sh'):
                        lines.append(f'    if [ -f "${{SDPATH}}/scripts/{script}" ]; then')
                        lines.append(
                            f'        cp -v "${{SDPATH}}/scripts/{script}" '
                            f'"${{SCRIPTDIR}}/{script}"'
                        )
                        lines.append(f'        chmod +x "${{SCRIPTDIR}}/{script}"')
                        lines.append(f'        echo "[INST] {script}"')
                        lines.append(f'    fi')

                lines.append('fi')
        else:
            lines.append(f'echo "[INFO] {mod_name} is SD-only; no flash files installed"')

        lines.append(f'echo "[OK] {mod_name} installed"')
        lines.append('echo ""')
        lines.append('')

    # Summary
    lines.extend([
        '# --- Complete ---',
        'echo "============================================"',
        'echo " Installation Complete"',
        f'echo " Modules installed: {len(selected_modules)}"',
        'echo " Log: ${LOGFILE}"',
        'echo ""',
        'echo " Open GEM (CAR + BACK) to access new screens"',
        'echo "============================================"',
        '',
        '# Show "done" status on MMI display',
        'if [ -x /tmp/showScreen ] && [ -f "${SDPATH}/lib/done.png" ]; then',
        '    kill ${SHOWSCREEN_PID} 2>/dev/null',
        '    sleep 1',
        '    /tmp/showScreen "${SDPATH}/lib/done.png" &',
        'fi',
    ])

    return '\n'.join(lines) + '\n'


def build_sd(selected_modules: list, modules: dict, output_dir: str):
    """Build the SD card contents."""

    print(f"Building SD card -> {output_dir}")
    print(f"Modules: {', '.join(selected_modules)}")
    print()

    # ---- Collision detection pass ----
    # Detect .sh and .esd filename collisions across modules BEFORE we copy
    # anything. The SD card uses a flat engdefs/ and scripts/ directory, so
    # two modules shipping a file with the same name will silently overwrite.
    seen_files = {}  # filename -> module_name that claimed it first
    collisions = []
    for mod_name in selected_modules:
        mod_dir = modules[mod_name]['_dir']
        for subdir, ext in (('engdefs', '.esd'), ('scripts', '.sh')):
            src = os.path.join(mod_dir, subdir)
            if not os.path.isdir(src):
                continue
            for fname in os.listdir(src):
                if not fname.endswith(ext):
                    continue
                key = (subdir, fname)
                if key in seen_files:
                    collisions.append((subdir, fname, seen_files[key], mod_name))
                else:
                    seen_files[key] = mod_name

    if collisions:
        print("[ERROR] Filename collisions detected across selected modules:")
        for subdir, fname, first, second in collisions:
            print(f"  {subdir}/{fname}  (both '{first}' and '{second}' ship this)")
        print()
        print("  Rename one of the files or deselect one module.")
        sys.exit(1)

    # Create directory structure
    for d in ['bin', 'lib', 'var', 'engdefs', 'scripts']:
        os.makedirs(os.path.join(output_dir, d), exist_ok=True)

    # Encode and copy copie_scr.sh
    template_path = os.path.join(CORE_DIR, 'copie_scr_plain.sh')
    if os.path.isfile(template_path):
        with open(template_path, 'rb') as f:
            plaintext = f.read()

        cipher = MMI3GCipher()
        encoded = cipher.process(plaintext)

        copie_out = os.path.join(output_dir, 'copie_scr.sh')
        with open(copie_out, 'wb') as f:
            f.write(encoded)
        print(f"  [OK] copie_scr.sh encoded ({len(encoded)} bytes)")
    else:
        print(f"  [WARN] {template_path} not found - you'll need to add copie_scr.sh manually")

    # Ship the platform.sh helper to scripts/common/ so modules can source it
    platform_src = os.path.join(CORE_DIR, 'platform.sh')
    if os.path.isfile(platform_src):
        common_dir = os.path.join(output_dir, 'scripts', 'common')
        os.makedirs(common_dir, exist_ok=True)
        with open(platform_src, 'rb') as src, open(os.path.join(common_dir, 'platform.sh'), 'wb') as dst:
            # Force LF line endings
            dst.write(src.read().replace(b'\r\n', b'\n'))
        print(f"  [OK] scripts/common/platform.sh")

    # Ship the showScreen helper and status PNGs used by run.sh
    status_assets = [
        ('core/bin/showScreen', 'bin/showScreen'),
        ('core/lib/running.png', 'lib/running.png'),
        ('core/lib/done.png', 'lib/done.png'),
    ]
    if 'gem-activator' in selected_modules:
        status_assets.extend([
            ('core/lib/gem_enabled.png', 'lib/gem_enabled.png'),
            ('core/lib/gem_disabled.png', 'lib/gem_disabled.png'),
        ])

    for src_rel, dest_rel in status_assets:
        src_path = os.path.join(REPO_ROOT, src_rel)
        if not os.path.isfile(src_path):
            continue
        dest_path = os.path.join(output_dir, *dest_rel.split('/'))
        shutil.copy2(src_path, dest_path)
        print(f"  [OK] {dest_rel}")

    # Copy module files
    for mod_name in selected_modules:
        meta = modules[mod_name]
        mod_dir = meta['_dir']

        # Copy engdefs
        engdefs_src = os.path.join(mod_dir, 'engdefs')
        if os.path.isdir(engdefs_src):
            for f in os.listdir(engdefs_src):
                if f.endswith('.esd'):
                    shutil.copy2(
                        os.path.join(engdefs_src, f),
                        os.path.join(output_dir, 'engdefs', f)
                    )
                    print(f"  [OK] engdefs/{f}")

        # Copy scripts
        scripts_src = os.path.join(mod_dir, 'scripts')
        if os.path.isdir(scripts_src):
            for f in os.listdir(scripts_src):
                if f.endswith('.sh'):
                    shutil.copy2(
                        os.path.join(scripts_src, f),
                        os.path.join(output_dir, 'scripts', f)
                    )
                    print(f"  [OK] scripts/{f}")

        # Copy pre-built artifact if the manifest declares one (e.g. a JAR that
        # the module installs into flash rather than a .sh/.esd).
        artifact = meta.get('artifact')
        if artifact:
            artifact_src = os.path.join(mod_dir, artifact)
            art_dest_dir = os.path.join(output_dir, 'modules', mod_name)
            os.makedirs(art_dest_dir, exist_ok=True)
            shutil.copy2(artifact_src, os.path.join(art_dest_dir, artifact))
            print(f"  [OK] modules/{mod_name}/{artifact}")

        for payload in meta.get('payload_dirs', []):
            source = os.path.normpath(payload['source'])
            target = os.path.normpath(payload.get('target') or source)
            payload_src = os.path.join(mod_dir, source)
            payload_dest = os.path.join(output_dir, target)
            shutil.copytree(payload_src, payload_dest, dirs_exist_ok=True)
            print(f"  [OK] {target}/ payload")

    # Generate combined run.sh
    run_sh = generate_run_sh(selected_modules, modules)
    run_path = os.path.join(output_dir, 'run.sh')
    with open(run_path, 'w', newline='\n') as f:
        f.write(run_sh)
    print(f"  [OK] run.sh generated")

    # Copy uninstall script
    uninstall_src = os.path.join(CORE_DIR, 'uninstall.sh')
    if os.path.isfile(uninstall_src):
        shutil.copy2(uninstall_src, os.path.join(output_dir, 'uninstall.sh'))
        print(f"  [OK] uninstall.sh")

    print()
    print("=" * 50)
    print("SD card build complete!")
    print()
    print("To use:")
    print("  1. Format 32GB SDHC as FAT32")
    print(f"  2. Copy contents of {output_dir}/ to card root")
    print("  3. Boot MMI fully, then insert SD card")
    print("  4. Wait 30s, remove card")
    print("  5. Open GEM (CAR + BACK) to see new screens")


def build_uninstall_sd(output_dir: str):
    """Build an SD card that runs the toolkit uninstaller when inserted.

    The SD contains an encoded copie_scr.sh (proc_scriptlauncher finds this
    automatically on insert) whose chained run.sh is the uninstaller.
    """
    print(f"Building UNINSTALL SD card -> {output_dir}")
    print()

    for d in ['bin', 'lib', 'var']:
        os.makedirs(os.path.join(output_dir, d), exist_ok=True)

    # Encode copie_scr.sh from the standard template
    template_path = os.path.join(CORE_DIR, 'copie_scr_plain.sh')
    if not os.path.isfile(template_path):
        print(f"[ERROR] {template_path} not found")
        sys.exit(1)

    with open(template_path, 'rb') as f:
        plaintext = f.read()
    encoded = MMI3GCipher().process(plaintext)
    with open(os.path.join(output_dir, 'copie_scr.sh'), 'wb') as f:
        f.write(encoded)
    print(f"  [OK] copie_scr.sh encoded ({len(encoded)} bytes)")

    # Copy uninstall.sh in as the run.sh (proc_scriptlauncher chains to run.sh)
    uninstall_src = os.path.join(CORE_DIR, 'uninstall.sh')
    if not os.path.isfile(uninstall_src):
        print(f"[ERROR] {uninstall_src} not found")
        sys.exit(1)

    run_path = os.path.join(output_dir, 'run.sh')
    with open(uninstall_src, 'rb') as src, open(run_path, 'wb') as dst:
        # Force LF line endings — CRLF breaks ksh on QNX
        dst.write(src.read().replace(b'\r\n', b'\n'))
    print(f"  [OK] run.sh (uninstaller) written with LF line endings")

    # Also drop a copy as uninstall.sh so users can re-run manually if needed
    shutil.copy2(uninstall_src, os.path.join(output_dir, 'uninstall.sh'))

    print()
    print("=" * 50)
    print("Uninstall SD card ready.")
    print()
    print("To use:")
    print(f"  1. Copy contents of {output_dir}/ to FAT32 SD card")
    print("  2. Boot MMI fully, then insert SD")
    print("  3. Wait 30–60s")
    print("  4. Remove SD, reboot MMI (MENU + knob + upper-right)")
    print()
    print("Modules that install outside engdefs/scripts")
    print("(splash-screen, lte-setup, nav-unblocker) need their own")
    print("restore scripts — see uninstall.sh output for details.")


def main():
    parser = argparse.ArgumentParser(
        description='MMI3G-Toolkit SD Card Builder',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --list                                      List available modules
  %(prog)s --all -o ./sdcard                           Build with everything
  %(prog)s --all --target-platform RNS-850 -o ./sdcard Build RNS-850-safe modules
  %(prog)s -m gauges-dashboard -o F:\\                  Build to SD card drive
  %(prog)s -m gauges-dashboard -m system-info -o ./sdcard
        """
    )

    parser.add_argument('--list', action='store_true',
                        help='List available modules')
    parser.add_argument('-m', '--module', action='append', dest='modules',
                        help='Module to include (can specify multiple)')
    parser.add_argument('--all', action='store_true',
                        help='Include all ready modules')
    parser.add_argument('--target-platform', choices=SUPPORTED_PLATFORMS,
                        help='Only include modules compatible with the specified platform')
    parser.add_argument('--uninstall', action='store_true',
                        help='Build an SD card that removes all toolkit modules from the MMI')
    parser.add_argument('-o', '--output', default='./sdcard',
                        help='Output directory (default: ./sdcard)')

    args = parser.parse_args()

    try:
        available = find_modules()
    except ModuleConfigError as exc:
        print(f"[ERROR] {exc}")
        sys.exit(1)

    if not available:
        print("No modules found! Check that the modules/ directory exists.")
        sys.exit(1)

    if args.list:
        list_modules(available, args.target_platform)
        return

    # Handle --uninstall: build an SD whose run.sh just calls uninstall.sh
    if args.uninstall:
        build_uninstall_sd(args.output)
        return

    # Determine which modules to build
    if args.all:
        selected = [
            n for n, m in available.items()
            if m.get('status') == 'ready' and module_is_compatible(m, args.target_platform)
        ]
    elif args.modules:
        selected = []
        for mod_name in args.modules:
            if mod_name not in available:
                print(f"Unknown module: {mod_name}")
                print(f"Available: {', '.join(available.keys())}")
                sys.exit(1)
            selected.append(mod_name)
    else:
        parser.print_help()
        sys.exit(1)

    try:
        selected, auto_added = resolve_selected_modules(
            selected,
            available,
            target_platform=args.target_platform,
        )
    except ModuleConfigError as exc:
        print(f"[ERROR] {exc}")
        sys.exit(1)

    if not selected:
        if args.target_platform:
            print(f"No modules selected for target platform {args.target_platform}!")
        else:
            print("No modules selected!")
        sys.exit(1)

    if auto_added:
        print("Auto-including prerequisite module(s):")
        for prereq, dependent in auto_added:
            print(f"  {prereq} (required by {dependent})")
        print()

    build_sd(selected, available, args.output)


if __name__ == '__main__':
    main()
