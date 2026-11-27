"""The web builder's write-to-SD path: what counts as an empty card, and the
read-back check after writing. Runs the page's own functions under node with
stand-in File System Access handles (the browser API is not in node)."""
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import textwrap
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
WEB_APP = REPO_ROOT / 'docs' / 'app' / 'index.html'


def extract_function(source, name):
    spec = importlib.util.spec_from_file_location(
        'mmi3g_web_run_sh_parity_helpers', REPO_ROOT / 'tests' / 'test_web_run_sh_parity.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.extract_function(source, name)


# Stand-in directory/file handles: a nested dict of name -> bytes length (int) or dict.
FAKE_FS = r'''
function fakeDir(tree, name) {
  return {
    name: name || "SDCARD",
    async *entries() { for (const k of Object.keys(tree)) yield [k, null]; },
    async getDirectoryHandle(n) {
      if (typeof tree[n] !== "object") throw new Error("NotFoundError");
      return fakeDir(tree[n], n);
    },
    async getFileHandle(n) {
      if (typeof tree[n] !== "number") throw new Error("NotFoundError");
      return { async getFile() { return { size: tree[n] }; } };
    },
  };
}
'''


class WebSdWrite(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.node = shutil.which('node')
        if cls.node is None:
            raise unittest.SkipTest('node is not installed')
        src = WEB_APP.read_text(encoding='utf-8')
        const = re.search(r'^const CARD_SYSTEM_ENTRIES = new Set\(\[.*?\]\);', src, re.M | re.S)
        assert const, 'CARD_SYSTEM_ENTRIES not found'
        cls.code = (const.group(0) + '\n' + extract_function(src, 'cardContents') + '\n' +
                    extract_function(src, 'verifyBundleInDirectory') + '\n' + FAKE_FS)

    def run_js(self, body):
        script = self.code + '\n(async () => {\n' + body + '\n})().catch(e => { console.error(e); process.exit(1); });\n'
        with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False, encoding='utf-8') as f:
            f.write(script)
            path = f.name
        out = subprocess.run([self.node, path], capture_output=True, text=True, timeout=30)
        Path(path).unlink()
        self.assertEqual(out.returncode, 0, out.stderr)
        return json.loads(out.stdout)

    def test_a_card_with_only_system_entries_counts_as_empty(self):
        got = self.run_js(textwrap.dedent('''
            const fresh = fakeDir({"System Volume Information": {}, ".Spotlight-V100": {}, ".fseventsd": {}});
            const used = fakeDir({"run.sh": 10, "copie_scr.sh": 5, "System Volume Information": {}, "music": {}});
            console.log(JSON.stringify([await cardContents(fresh), await cardContents(used)]));
        '''))
        self.assertEqual(got, [[], ['copie_scr.sh', 'music', 'run.sh']])

    def test_the_read_back_finds_missing_and_short_files(self):
        got = self.run_js(textwrap.dedent('''
            const bundle = { files: [
              { path: "run.sh", bytes: new Uint8Array(10) },
              { path: "lib/done.bin", bytes: new Uint8Array(1536) },
              { path: "lib/failed.bin", bytes: new Uint8Array(1536) },
              { path: "wifi-sta/options", bytes: new Uint8Array(40) },
              { path: "var/.keep", bytes: new Uint8Array(0) },
            ] };
            const good = fakeDir({"run.sh": 10, lib: {"done.bin": 1536, "failed.bin": 1536}, "wifi-sta": {options: 40}});
            const bad = fakeDir({"run.sh": 10, lib: {"done.bin": 1000}});
            console.log(JSON.stringify([await verifyBundleInDirectory(bundle, good),
                                        await verifyBundleInDirectory(bundle, bad)]));
        '''))
        self.assertEqual(got, [[], ['lib/done.bin', 'lib/failed.bin', 'wifi-sta/options']])

    def test_write_to_card_is_the_main_action_where_the_browser_can(self):
        src = WEB_APP.read_text(encoding='utf-8')
        self.assertIn('onClick: () => runBuild(chromium ? "folder" : "zip")', src)
        self.assertIn('"Write to SD card"', src)
        self.assertIn('"Download a ZIP instead"', src)
        self.assertIn('id: "mmi3g-sd-card"', src)


if __name__ == '__main__':
    unittest.main()
