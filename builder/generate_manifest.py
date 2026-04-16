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

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
MODULES_DIR = os.path.join(REPO_ROOT, 'modules')
CORE_DIR = os.path.join(REPO_ROOT, 'core')
OUT_FILE = os.path.join(REPO_ROOT, 'docs', 'app', 'manifest.json')

RAW_BASE = 'https://raw.githubusercontent.com/dspl1236/MMI3G-Toolkit/main/'


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


def main():
    if not os.path.isdir(MODULES_DIR):
        print(f"error: {MODULES_DIR} not found", file=sys.stderr)
        sys.exit(1)

    manifest = {
        'generated': date.today().isoformat(),
        'branch': 'main',
        'raw_url_base': RAW_BASE,
        'core_files': {
            'copie_scr_plain_sh': 'core/copie_scr_plain.sh',
            'uninstall_sh': 'core/uninstall.sh',
        },
        'modules': {}
    }

    for name in sorted(os.listdir(MODULES_DIR)):
        mod_path = os.path.join(MODULES_DIR, name)
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
            'script_dir': meta.get('script_dir', f'/scripts/{name}'),
            'installs_to_flash': meta.get('installs_to_flash', True),
            'compatible': meta.get('compatible', ['MMI3G+']),
            'files': files,
        }

    os.makedirs(os.path.dirname(OUT_FILE), exist_ok=True)
    with open(OUT_FILE, 'w') as f:
        json.dump(manifest, f, indent=2)

    total_files = sum(len(m['files']) for m in manifest['modules'].values())
    total_size = sum(sum(f['size'] for f in m['files']) for m in manifest['modules'].values())
    print(f"Wrote {OUT_FILE}")
    print(f"  {len(manifest['modules'])} modules, {total_files} files, {total_size:,} bytes total")


if __name__ == '__main__':
    main()
