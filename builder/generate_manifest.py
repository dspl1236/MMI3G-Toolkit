"""
Generate docs/app/manifest.json from the local modules/ directory tree.

This manifest is consumed by docs/app/index.html so the in-browser SD card
builder can fetch all module files at runtime from raw.githubusercontent.com.

Re-run this whenever modules are added, removed, or files change:
    python builder/generate_manifest.py

Output: docs/app/manifest.json
"""
import json
import os
import sys
from datetime import date
from typing import Optional

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
MODULES_DIR = os.path.join(REPO_ROOT, 'modules')
CORE_DIR = os.path.join(REPO_ROOT, 'core')
OUT_FILE = os.path.join(REPO_ROOT, 'docs', 'app', 'manifest.json')

RAW_BASE = 'https://raw.githubusercontent.com/dspl1236/MMI3G-Toolkit/main/'
CORE_FILES = {
    'copie_scr_plain_sh': 'core/copie_scr_plain.sh',
    'uninstall_sh': 'core/uninstall.sh',
    'platform_sh': 'core/platform.sh',
    'showScreen': 'core/bin/showScreen',
    'lib_running_png': 'core/lib/running.png',
    'lib_done_png': 'core/lib/done.png',
    'lib_gem_enabled_png': 'core/lib/gem_enabled.png',
    'lib_gem_disabled_png': 'core/lib/gem_disabled.png',
}


def walk_module(mod_dir: str) -> list:
    """Return a list of {path, size} for every file in a module directory."""
    files = []
    for root, _, fnames in os.walk(mod_dir):
        for fname in sorted(fnames):
            full = os.path.join(root, fname)
            rel = os.path.relpath(full, mod_dir).replace(os.sep, '/')
            size = os.path.getsize(full)
            files.append({'path': rel, 'size': size})
    return sorted(files, key=lambda f: f['path'])


def build_manifest(modules_dir: Optional[str] = None) -> dict:
    modules_dir = modules_dir or MODULES_DIR
    if not os.path.isdir(modules_dir):
        print(f"error: {modules_dir} not found", file=sys.stderr)
        sys.exit(1)

    manifest = {
        'generated': date.today().isoformat(),
        'branch': 'main',
        'raw_url_base': RAW_BASE,
        'core_files': dict(CORE_FILES),
        'modules': {}
    }

    for name in sorted(os.listdir(modules_dir)):
        mod_path = os.path.join(modules_dir, name)
        if not os.path.isdir(mod_path):
            continue
        meta_file = os.path.join(mod_path, 'module.json')
        if not os.path.isfile(meta_file):
            continue

        files = walk_module(mod_path)
        # Load module.json so the manifest embeds key metadata
        # (lets the UI show status/description without a second fetch)
        with open(meta_file) as f:
            meta = json.load(f)
        manifest['modules'][name] = {
            'status': meta.get('status', 'unknown'),
            'description': meta.get('description', ''),
            'standalone': meta.get('standalone', False),
            'run_script': meta.get('run_script'),
            'artifact': meta.get('artifact'),
            'payload_dirs': meta.get('payload_dirs', []),
            'release_zip': meta.get('release_zip'),
            'release_assets': meta.get('release_assets'),
            'web_build': meta.get('web_build', True),
            'prebuilt_zip': meta.get('prebuilt_zip'),
            'script_dir': meta.get('script_dir', f'/scripts/{name}'),
            'installs_to_flash': meta.get('installs_to_flash', True),
            'compatible': meta.get('compatible', ['MMI3G+']),
            'files': files,
        }

    # GEMMI release assets (hosted as GitHub Release, not in git repo)
    manifest['gemmi_assets'] = {
        'base_url': 'https://hausofdub.com/gemmi/',
        'files': [
            # Large binaries hosted on hausofdub.com (too big for git)
            # Small files (drivers.ini, dbRoot, auth, scripts) stay in repo payload/
            {'name': 'gemmi_final', 'path': 'gemmi/gemmi_final', 'size': 1965004},
            {'name': 'libembeddedearth.so', 'path': 'gemmi/libembeddedearth.so', 'size': 20839388},
            {'name': 'libembeddedearth_dream.so', 'path': 'gemmi/libembeddedearth_dream.so', 'size': 20839388},
            {'name': 'libmessaging.so', 'path': 'gemmi/libmessaging.so', 'size': 826149},
            {'name': 'libthirdparty_icu_3_5.so', 'path': 'gemmi/libthirdparty_icu_3_5.so', 'size': 1524205},
            {'name': 'mapStylesWrite', 'path': 'gemmi/mapStylesWrite', 'size': 507383},
            {'name': 'gemmi_models_res.zip', 'path': 'gemmi/gemmi_models_res.zip', 'size': 801183},
            {'name': 'drivers.cfg', 'path': 'gemmi/drivers.cfg', 'size': 1119},
            {'name': 'dbRoot_custom.bin', 'path': 'gemmi/dbRoot_custom.bin', 'size': 16892},
            {'name': 'auth_resp1.bin', 'path': 'gemmi/auth_resp1.bin', 'size': 16},
            {'name': 'auth_resp2.bin', 'path': 'gemmi/auth_resp2.bin', 'size': 136},
            {'name': 'run_gemmi.sh', 'path': 'gemmi/run_gemmi.sh', 'size': 4140},
        ],
        'total_size_mb': 24.8,
        'note': 'Downloaded from GitHub Release assets (not in git repo). Only fetched when google-earth module is selected.',
    }

    return manifest


def main():
    manifest = build_manifest()

    os.makedirs(os.path.dirname(OUT_FILE), exist_ok=True)
    with open(OUT_FILE, 'w') as f:
        json.dump(manifest, f, indent=4)

    total_files = sum(len(m['files']) for m in manifest['modules'].values())
    total_size = sum(sum(f['size'] for f in m['files']) for m in manifest['modules'].values())
    print(f"Wrote {OUT_FILE}")
    print(f"  {len(manifest['modules'])} modules, {total_files} files, {total_size:,} bytes total")


if __name__ == '__main__':
    main()
