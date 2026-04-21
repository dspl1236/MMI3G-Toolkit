import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock


REPO_ROOT = Path(__file__).resolve().parents[1]
GENERATE_MANIFEST = REPO_ROOT / 'builder' / 'generate_manifest.py'
EXPECTED_CORE_FILES = {
    'copie_scr_plain_sh': 'core/copie_scr_plain.sh',
    'uninstall_sh': 'core/uninstall.sh',
    'platform_sh': 'core/platform.sh',
    'showScreen': 'core/bin/showScreen',
    'lib_running_png': 'core/lib/running.png',
    'lib_done_png': 'core/lib/done.png',
    'lib_gem_enabled_png': 'core/lib/gem_enabled.png',
    'lib_gem_disabled_png': 'core/lib/gem_disabled.png',
}


def load_generator_module():
    spec = importlib.util.spec_from_file_location('mmi3g_generate_manifest', GENERATE_MANIFEST)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class GenerateManifestTests(unittest.TestCase):
    def assert_expected_core_files(self, manifest):
        self.assertEqual(
            {key: manifest['core_files'].get(key) for key in EXPECTED_CORE_FILES},
            EXPECTED_CORE_FILES,
        )

    def test_build_manifest_includes_web_builder_core_assets(self):
        module = load_generator_module()
        with tempfile.TemporaryDirectory() as tmpdir:
            modules_dir = Path(tmpdir) / 'modules'
            modules_dir.mkdir()

            manifest = module.build_manifest(str(modules_dir))

        self.assert_expected_core_files(manifest)

    def test_main_writes_web_builder_core_assets(self):
        module = load_generator_module()
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            modules_dir = tmp_path / 'modules'
            module_dir = modules_dir / 'demo-module'
            output_file = tmp_path / 'docs' / 'app' / 'manifest.json'
            module_dir.mkdir(parents=True)
            (module_dir / 'module.json').write_text(
                json.dumps({'status': 'ready', 'description': 'demo module'}, indent=2),
                encoding='utf-8',
            )

            with mock.patch.object(module, 'MODULES_DIR', str(modules_dir)), mock.patch.object(module, 'OUT_FILE', str(output_file)):
                module.main()

            manifest = json.loads(output_file.read_text(encoding='utf-8'))

        self.assert_expected_core_files(manifest)

    def test_build_manifest_preserves_artifact_metadata(self):
        module = load_generator_module()
        with tempfile.TemporaryDirectory() as tmpdir:
            modules_dir = Path(tmpdir) / 'modules'
            module_dir = modules_dir / 'artifact-module'
            module_dir.mkdir(parents=True)
            (module_dir / 'module.json').write_text(
                json.dumps(
                    {
                        'status': 'ready',
                        'description': 'artifact demo',
                        'artifact': 'demo.jar',
                    },
                    indent=2,
                ),
                encoding='utf-8',
            )

            manifest = module.build_manifest(str(modules_dir))

        self.assertEqual(
            manifest['modules']['artifact-module']['artifact'],
            'demo.jar',
        )

    def test_checked_in_manifest_matches_generated_output(self):
        module = load_generator_module()
        generated = module.build_manifest()
        checked_in = json.loads(
            (REPO_ROOT / 'docs' / 'app' / 'manifest.json').read_text(encoding='utf-8')
        )

        generated.pop('generated', None)
        checked_in.pop('generated', None)

        self.assertEqual(checked_in, generated)


if __name__ == '__main__':
    unittest.main()
