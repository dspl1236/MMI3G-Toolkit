"""The uninstaller removes everything the modules install, and keeps removing
what earlier versions installed (builder/retired_modules.json)."""
import fnmatch
import glob
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
GENERATOR = REPO_ROOT / 'builder' / 'generate_uninstall.py'
UNINSTALL = REPO_ROOT / 'core' / 'uninstall.sh'
RETIRED = REPO_ROOT / 'builder' / 'retired_modules.json'
WEB_APP = REPO_ROOT / 'docs' / 'app' / 'index.html'


def load_generator():
    spec = importlib.util.spec_from_file_location('mmi3g_generate_uninstall', GENERATOR)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def shell_list(text, start):
    """The quoted or bare words of the `for ... in \\ ... do` list after `start`."""
    block = text[text.index(start):]
    block = block[:block.index('\ndo\n')]
    return [w.strip('"') for w in re.findall(r'^\s+("[^"]+"|\S+)\s*\\?$', block, re.M)]


class UninstallCoverage(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = UNINSTALL.read_text(encoding='utf-8').replace('\r\n', '\n')
        cls.esd_patterns = shell_list(cls.text, 'for pattern in')
        cls.dirs = shell_list(cls.text, 'for d in')

    def test_core_uninstall_is_generated_and_up_to_date(self):
        gen = load_generator()
        self.assertEqual(self.text, gen.render(*gen.collect()),
                         'run: python builder/generate_uninstall.py')
        out = subprocess.run([sys.executable, str(GENERATOR), '--check'], cwd=str(REPO_ROOT),
                             capture_output=True, text=True)
        self.assertEqual(out.returncode, 0, out.stdout + out.stderr)

    def test_every_gem_screen_in_any_module_folder_is_removed(self):
        # Every module folder, with or without module.json, except one that
        # manages its own removal.
        own = set()
        for meta_file in glob.glob(str(REPO_ROOT / 'modules' / '*' / 'module.json')):
            meta = json.loads(Path(meta_file).read_text(encoding='utf-8'))
            un = meta.get('uninstall', {})
            if isinstance(un, dict) and un.get('own_removal'):
                own.add(Path(meta_file).parent.name)
        missing = []
        for esd in glob.glob(str(REPO_ROOT / 'modules' / '*' / 'engdefs' / '*.esd')):
            if Path(esd).parent.parent.name in own:
                continue
            name = os.path.basename(esd)
            if not any(fnmatch.fnmatchcase(name, p) for p in self.esd_patterns):
                missing.append(name)
        self.assertEqual(missing, [])

    def test_every_flash_module_script_folder_is_removed(self):
        missing = []
        for meta_file in glob.glob(str(REPO_ROOT / 'modules' / '*' / 'module.json')):
            meta = json.loads(Path(meta_file).read_text(encoding='utf-8'))
            un = meta.get('uninstall', {})
            if isinstance(un, dict) and un.get('own_removal'):
                continue
            if not meta.get('installs_to_flash', True):
                continue
            name = meta['name']
            folder = meta.get('script_dir', f'/scripts/{name}').strip('/').split('/', 1)[-1]
            if folder not in self.dirs:
                missing.append(f'{name}: {folder}')
        self.assertEqual(missing, [])

    def test_retired_entries_stay_covered(self):
        retired = json.loads(RETIRED.read_text(encoding='utf-8'))['retired']
        for entry in retired:
            for pattern in entry.get('engdefs', []):
                self.assertIn(pattern, self.esd_patterns, entry['name'])
            for folder in entry.get('script_dirs', []):
                self.assertIn(folder, self.dirs, entry['name'])

    def test_every_web_app_module_has_a_module_json(self):
        ids = re.findall(r'\{ id: "([a-z0-9-]+)", name:', WEB_APP.read_text(encoding='utf-8'))
        self.assertTrue(ids)
        missing = [i for i in ids if not (REPO_ROOT / 'modules' / i / 'module.json').is_file()]
        self.assertEqual(missing, [])


if __name__ == '__main__':
    unittest.main()
