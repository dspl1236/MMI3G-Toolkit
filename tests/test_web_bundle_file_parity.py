import importlib.util
from pathlib import Path
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
BUILD_SCRIPT = REPO_ROOT / 'builder' / 'build_sd.py'
MANIFEST_SCRIPT = REPO_ROOT / 'builder' / 'generate_manifest.py'


def load_module(module_name: str, path: Path):
    spec = importlib.util.spec_from_file_location(module_name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class WebBundleFileParityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.builder = load_module('mmi3g_build_sd_parity', BUILD_SCRIPT)
        cls.manifest_generator = load_module('mmi3g_generate_manifest_parity', MANIFEST_SCRIPT)
        cls.modules = cls.builder.find_modules()
        cls.manifest = cls.manifest_generator.build_manifest()

    def expected_web_bundle_files(self, selected):
        files = {
            'copie_scr.sh',
            'run.sh',
            'uninstall.sh',
            'scripts/common/platform.sh',
            'bin/showScreen',
            'lib/running.png',
            'lib/done.png',
        }

        if 'gem-activator' in selected:
            files.add('lib/gem_enabled.png')
            files.add('lib/gem_disabled.png')

        for mod_name in selected:
            meta = self.manifest['modules'][mod_name]
            artifact = meta.get('artifact')
            payload_dirs = meta.get('payload_dirs', [])
            for entry in meta['files']:
                path = entry['path']
                if path == 'module.json':
                    continue
                if path.startswith('engdefs/') or path.startswith('scripts/'):
                    files.add(path)
                elif artifact and path == artifact:
                    files.add(f'modules/{mod_name}/{path}')
                else:
                    for payload in payload_dirs:
                        source = payload['source'].rstrip('/')
                        target = payload.get('target', source).rstrip('/')
                        if path.startswith(f'{source}/'):
                            files.add(f'{target}/{path[len(source) + 1:]}')
                            break

        return files

    def build_python_sd_files(self, selected):
        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir) / 'sdcard'
            self.builder.build_sd(selected, self.modules, str(output_dir))
            return {
                path.relative_to(output_dir).as_posix()
                for path in output_dir.rglob('*')
                if path.is_file()
            }

    def test_material_bundle_files_match_builder_for_representative_modules(self):
        representative_sets = (
            ['system-info'],
            ['gem-activator', 'can-scanner'],
            ['diag-tool'],
            ['per3-reader'],
            ['google-earth-p0824-deploy'],
        )

        for selected in representative_sets:
            with self.subTest(selected=selected):
                self.assertEqual(
                    self.build_python_sd_files(selected),
                    self.expected_web_bundle_files(selected),
                )


if __name__ == '__main__':
    unittest.main()
