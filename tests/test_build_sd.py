import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile
from unittest import mock


REPO_ROOT = Path(__file__).resolve().parents[1]
BUILD_SCRIPT = REPO_ROOT / 'builder' / 'build_sd.py'


def load_builder_module():
    spec = importlib.util.spec_from_file_location('mmi3g_build_sd', BUILD_SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class BuildSdCliTests(unittest.TestCase):
    def run_builder(self, *args):
        return subprocess.run(
            [sys.executable, str(BUILD_SCRIPT), *args],
            cwd=str(REPO_ROOT),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
        )

    def test_list_modules(self):
        result = self.run_builder('--list')

        self.assertEqual(result.returncode, 0, msg=result.stdout + result.stderr)
        self.assertIn('Available modules:', result.stdout)
        self.assertIn('system-info', result.stdout)
        self.assertIn('lte-setup', result.stdout)

    def test_build_single_module_smoke(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir) / 'sdcard'
            result = self.run_builder('-m', 'system-info', '-o', str(output_dir))

            self.assertEqual(result.returncode, 0, msg=result.stdout + result.stderr)
            self.assertTrue((output_dir / 'copie_scr.sh').is_file())
            self.assertTrue((output_dir / 'run.sh').is_file())
            self.assertTrue((output_dir / 'uninstall.sh').is_file())
            self.assertTrue((output_dir / 'bin' / 'showScreen').is_file())
            self.assertTrue((output_dir / 'lib' / 'running.png').is_file())
            self.assertTrue((output_dir / 'lib' / 'done.png').is_file())
            self.assertTrue((output_dir / 'scripts' / 'sysinfo_dump.sh').is_file())
            self.assertTrue((output_dir / 'scripts' / 'common' / 'platform.sh').is_file())

    def test_generated_copie_scr_round_trips_to_plaintext_template(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir) / 'sdcard'
            result = self.run_builder('-m', 'system-info', '-o', str(output_dir))

            self.assertEqual(result.returncode, 0, msg=result.stdout + result.stderr)

            builder = load_builder_module()
            encoded = (output_dir / 'copie_scr.sh').read_bytes()
            decoded = builder.MMI3GCipher().process(encoded)
            expected = (REPO_ROOT / 'core' / 'copie_scr_plain.sh').read_bytes()
            self.assertEqual(decoded, expected)

    def test_release_asset_download_skips_complete_existing_file(self):
        builder = load_builder_module()
        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir)
            dest = output_dir / 'gemmi' / 'existing.bin'
            dest.parent.mkdir(parents=True)
            dest.write_bytes(b'abc')

            with mock.patch.object(builder.urllib.request, 'urlopen') as urlopen:
                downloaded, skipped, failed = builder.download_release_assets(
                    {
                        'base_url': 'https://example.invalid/',
                        'files': [
                            {
                                'name': 'existing.bin',
                                'path': 'gemmi/existing.bin',
                                'size': 3,
                            },
                        ],
                    },
                    str(output_dir),
                )

            self.assertEqual((downloaded, skipped, failed), (0, 1, []))
            urlopen.assert_not_called()

    def test_release_asset_download_retries_and_writes_part_file_atomically(self):
        builder = load_builder_module()
        response = mock.Mock()
        response.read.return_value = b'payload'

        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir)
            with mock.patch.dict('os.environ', {'MMI3G_ASSET_RETRIES': '2'}), \
                    mock.patch.object(builder.time, 'sleep'), \
                    mock.patch.object(
                        builder.urllib.request,
                        'urlopen',
                        side_effect=[TimeoutError('timed out'), response],
                    ):
                downloaded, skipped, failed = builder.download_release_assets(
                    {
                        'base_url': 'https://example.invalid/',
                        'files': [
                            {
                                'name': 'payload.bin',
                                'path': 'gemmi/payload.bin',
                                'size': 7,
                            },
                        ],
                    },
                    str(output_dir),
                )

            self.assertEqual((downloaded, skipped, failed), (1, 0, []))
            self.assertEqual((output_dir / 'gemmi' / 'payload.bin').read_bytes(), b'payload')
            self.assertFalse((output_dir / 'gemmi' / 'payload.bin.part').exists())

    def test_release_zip_extracts_into_target_directory(self):
        builder = load_builder_module()
        archive = io.BytesIO()
        with zipfile.ZipFile(archive, 'w') as zf:
            zf.writestr('drivers.ini', 'driver-config')
            zf.writestr('models/cursor.png', b'png')

        response = mock.Mock()
        response.read.return_value = archive.getvalue()

        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir)
            with mock.patch.object(builder.urllib.request, 'urlopen', return_value=response):
                count = builder.extract_release_zip(
                    {
                        'url': 'https://example.invalid/payload.zip',
                        'target': 'gemmi',
                        'size': len(archive.getvalue()),
                    },
                    str(output_dir),
                )

            self.assertEqual(count, 2)
            self.assertEqual((output_dir / 'gemmi' / 'drivers.ini').read_text(), 'driver-config')
            self.assertEqual((output_dir / 'gemmi' / 'models' / 'cursor.png').read_bytes(), b'png')

    def test_prerequisite_module_is_auto_included(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir) / 'sdcard'
            result = self.run_builder('-m', 'can-scanner', '-o', str(output_dir))

            self.assertEqual(result.returncode, 0, msg=result.stdout + result.stderr)
            self.assertIn('Auto-including prerequisite module(s):', result.stdout)
            self.assertIn('gem-activator (required by can-scanner)', result.stdout)
            self.assertTrue((output_dir / 'engdefs' / 'ToolkitMain.esd').is_file())
            self.assertTrue((output_dir / 'engdefs' / 'ScannerPer3Low.esd').is_file())
            self.assertTrue((output_dir / 'lib' / 'gem_enabled.png').is_file())
            self.assertTrue((output_dir / 'lib' / 'gem_disabled.png').is_file())

            run_sh = (output_dir / 'run.sh').read_text(encoding='utf-8')
            self.assertLess(
                run_sh.index('Installing gem-activator'),
                run_sh.index('Installing can-scanner'),
            )

    def test_uninstall_builder_smoke(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir) / 'uninstall'
            result = self.run_builder('--uninstall', '-o', str(output_dir))

            self.assertEqual(result.returncode, 0, msg=result.stdout + result.stderr)
            run_sh = output_dir / 'run.sh'
            uninstall_sh = output_dir / 'uninstall.sh'
            self.assertTrue((output_dir / 'copie_scr.sh').is_file())
            self.assertTrue(run_sh.is_file())
            self.assertTrue(uninstall_sh.is_file())
            self.assertEqual(run_sh.read_text(encoding='utf-8'), uninstall_sh.read_text(encoding='utf-8'))
            self.assertNotIn(b'\r\n', run_sh.read_bytes())

    def test_target_platform_rejects_incompatible_module(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            result = self.run_builder(
                '-m', 'lte-setup',
                '--target-platform', 'MMI3G',
                '-o', str(Path(tmpdir) / 'sdcard'),
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertIn('not compatible with MMI3G', result.stdout)

    def test_all_with_target_platform_excludes_incompatible_ready_modules(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir) / 'sdcard'
            result = self.run_builder(
                '--all',
                '--target-platform', 'MMI3G',
                '-o', str(output_dir),
            )

            self.assertEqual(result.returncode, 0, msg=result.stdout + result.stderr)
            self.assertFalse((output_dir / 'scripts' / 'lte_setup.sh').exists())

    def test_target_platform_list_filters_modules(self):
        result = self.run_builder('--list', '--target-platform', 'MMI3G')

        self.assertEqual(result.returncode, 0, msg=result.stdout + result.stderr)
        self.assertIn('system-info', result.stdout)
        self.assertNotIn('lte-setup', result.stdout)

    def test_standalone_module_build_contains_expected_runner(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir) / 'sdcard'
            result = self.run_builder(
                '-m', 'lte-setup',
                '--target-platform', 'RNS-850',
                '-o', str(output_dir),
            )

            self.assertEqual(result.returncode, 0, msg=result.stdout + result.stderr)
            self.assertTrue((output_dir / 'scripts' / 'lte_setup.sh').is_file())
            self.assertTrue((output_dir / 'scripts' / 'lte_restore.sh').is_file())
            self.assertTrue((output_dir / 'scripts' / 'lte_status.sh').is_file())

            run_sh = (output_dir / 'run.sh').read_text(encoding='utf-8')
            self.assertIn('ksh "${SDPATH}/scripts/lte_setup.sh" "${SDPATH}"', run_sh)
            self.assertIn('scripts/common/platform.sh', run_sh)

    def test_google_earth_p0824_deploy_card_includes_donor_script(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir) / 'sdcard'
            result = self.run_builder(
                '-m', 'google-earth-p0824-deploy',
                '--target-platform', 'RNS-850',
                '-o', str(output_dir),
            )

            self.assertEqual(result.returncode, 0, msg=result.stdout + result.stderr)
            self.assertTrue((output_dir / 'scripts' / 'ge_p0824_deploy.sh').is_file())
            for payload_file in (
                'drivers.cfg',
                'gemmi_final',
                'libembeddedearth.so',
                'libmessaging.so',
                'mapStylesWrite',
                'run_gemmi.sh',
            ):
                self.assertTrue((output_dir / 'gemmi' / payload_file).is_file(), payload_file)

            run_sh = (output_dir / 'run.sh').read_text(encoding='utf-8')
            self.assertIn('ksh "${SDPATH}/scripts/ge_p0824_deploy.sh" "${SDPATH}"', run_sh)
            self.assertIn('SCRIPTDIR="${EFSDIR}/scripts/GoogleEarth"', run_sh)

    def test_dns_refresh_probe_card_includes_netdiag_runner(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir) / 'sdcard'
            result = self.run_builder(
                '-m', 'dns-refresh-probe',
                '--target-platform', 'RNS-850',
                '-o', str(output_dir),
            )

            self.assertEqual(result.returncode, 0, msg=result.stdout + result.stderr)
            self.assertTrue((output_dir / 'scripts' / 'dns_refresh_probe.sh').is_file())

            run_sh = (output_dir / 'run.sh').read_text(encoding='utf-8')
            self.assertIn('ksh "${SDPATH}/scripts/dns_refresh_probe.sh" "${SDPATH}"', run_sh)
            self.assertIn('SD-only module set; efs-system will not be remounted', run_sh)
            self.assertNotIn('SCRIPTDIR="${EFSDIR}/scripts/NetDiag"', run_sh)
            self.assertNotIn('cp -v "${SDPATH}/scripts/dns_refresh_probe.sh"', run_sh)
            self.assertNotIn('mount -uw ${EFSDIR}', run_sh)

    def test_google_earth_gemmi_wrappers_card_includes_legacy_scripts(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir) / 'sdcard'
            result = self.run_builder(
                '-m', 'google-earth-gemmi-wrappers',
                '--target-platform', 'RNS-850',
                '-o', str(output_dir),
            )

            self.assertEqual(result.returncode, 0, msg=result.stdout + result.stderr)
            for script in (
                'activateGEMMI.sh',
                'deactivateGEMMI.sh',
                'deleteCacheGEMMI.sh',
                'gemmi_wrapper_install.sh',
                'getCacheStatus.sh',
                'getInfoGEMMI.sh',
                'restartGEMMI.sh',
                'shutdownGEMMI.sh',
                'startGEMMI.sh',
            ):
                self.assertTrue((output_dir / 'scripts' / script).is_file(), script)

            run_sh = (output_dir / 'run.sh').read_text(encoding='utf-8')
            self.assertIn('ksh "${SDPATH}/scripts/gemmi_wrapper_install.sh" "${SDPATH}"', run_sh)
            self.assertIn('SCRIPTDIR="${EFSDIR}/scripts/GEMMI"', run_sh)

    def test_all_build_for_rns850_writes_expected_fake_sd_tree(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir) / 'sdcard'
            result = self.run_builder(
                '--all',
                '--target-platform', 'RNS-850',
                '-o', str(output_dir),
            )

            self.assertEqual(result.returncode, 0, msg=result.stdout + result.stderr)
            for dirname in ('bin', 'lib', 'var', 'engdefs', 'scripts'):
                self.assertTrue((output_dir / dirname).is_dir(), dirname)

            self.assertTrue((output_dir / 'scripts' / 'lte_setup.sh').is_file())
            self.assertTrue((output_dir / 'engdefs' / 'ToolkitMain.esd').is_file())
            self.assertTrue((output_dir / 'engdefs' / 'ScannerPer3Low.esd').is_file())
            self.assertFalse((output_dir / 'scripts' / 'per3_read.sh').exists())
            self.assertFalse((output_dir / 'modules' / 'per3-reader').exists())


class BuildSdValidationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.builder = load_builder_module()

    def test_resolve_selected_modules_adds_prereq_once(self):
        available = self.builder.find_modules()

        resolved, auto_added = self.builder.resolve_selected_modules(
            ['can-scanner', 'game-loader'],
            available,
        )

        self.assertEqual(resolved[0], 'gem-activator')
        self.assertEqual(resolved.count('gem-activator'), 1)
        self.assertIn(('gem-activator', 'can-scanner'), auto_added)

    def test_find_modules_rejects_invalid_json(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            modules_dir = Path(tmpdir) / 'modules'
            bad_dir = modules_dir / 'broken'
            bad_dir.mkdir(parents=True)
            (bad_dir / 'module.json').write_text('{broken json', encoding='utf-8')

            with mock.patch.object(self.builder, 'MODULES_DIR', str(modules_dir)):
                with self.assertRaises(self.builder.ModuleConfigError):
                    self.builder.find_modules()

    def test_find_modules_rejects_missing_declared_run_script(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            modules_dir = Path(tmpdir) / 'modules'
            bad_dir = modules_dir / 'broken'
            bad_dir.mkdir(parents=True)
            (bad_dir / 'scripts').mkdir()
            manifest = {
                'name': 'broken',
                'version': '1.0.0',
                'description': 'broken module',
                'author': 'test',
                'status': 'ready',
                'compatible': ['MMI3G'],
                'standalone': True,
                'run_script': 'missing.sh',
            }
            (bad_dir / 'module.json').write_text(
                json.dumps(manifest, indent=2),
                encoding='utf-8',
            )

            with mock.patch.object(self.builder, 'MODULES_DIR', str(modules_dir)):
                with self.assertRaises(self.builder.ModuleConfigError) as exc:
                    self.builder.find_modules()

            self.assertIn('run_script', str(exc.exception))

    def test_find_modules_rejects_missing_payload_dir(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            modules_dir = Path(tmpdir) / 'modules'
            bad_dir = modules_dir / 'broken'
            bad_dir.mkdir(parents=True)
            (bad_dir / 'module.json').write_text(
                json.dumps(
                    {
                        'name': 'broken',
                        'version': '1.0.0',
                        'description': 'broken module',
                        'author': 'test',
                        'status': 'ready',
                        'compatible': ['MMI3G+'],
                        'payload_dirs': [{'source': 'missing', 'target': 'gemmi'}],
                    },
                    indent=2,
                ),
                encoding='utf-8',
            )

            with mock.patch.object(self.builder, 'MODULES_DIR', str(modules_dir)):
                with self.assertRaises(self.builder.ModuleConfigError) as exc:
                    self.builder.find_modules()

            self.assertIn('payload_dir', str(exc.exception))


if __name__ == '__main__':
    unittest.main()
