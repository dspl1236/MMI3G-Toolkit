import importlib.util
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
import zipfile


REPO_ROOT = Path(__file__).resolve().parents[1]
EOL_MODIFIER = REPO_ROOT / 'tools' / 'eol_modifier.py'
INFLATE_IFS = REPO_ROOT / 'tools' / 'inflate_ifs.py'


def load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class EolModifierTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.module = load_module(EOL_MODIFIER, 'mmi3g_eol_modifier_test')

    def make_sample_jxe(self):
        tmpdir = tempfile.TemporaryDirectory()
        jxe_path = Path(tmpdir.name) / 'sample_lsd.jxe'

        with zipfile.ZipFile(jxe_path, 'w', compression=zipfile.ZIP_STORED) as zf:
            zf.writestr(
                'resources/sysconst/sysconst.properties',
                '\n'.join([
                    'EOLFLAG_GOOGLE_EARTH=0',
                    'EOLFLAG_INNOVATIONFEATURES=0',
                    'EOLFLAG_HU_REGION=0',
                    '',
                ]),
            )
            zf.writestr(
                'resources/sysconst/variant.properties',
                '\n'.join([
                    'variant=vw_high_nar no_online_services',
                    'market=nar',
                    '',
                ]),
            )
            zf.writestr(
                'resources/sysconst/variants/vw_high_nar.properties',
                '\n'.join([
                    'EOLFLAG_HU_VARIANT=15',
                    'EOLFLAG_HU_REGION=1',
                    '',
                ]),
            )
            zf.writestr(
                'resources/sysconst/variants/no_online_services.properties',
                '\n'.join([
                    'RANGE_EOLFLAG_GOOGLE_EARTH=0',
                    '',
                ]),
            )
            zf.writestr(
                'resources/sysconst/variants/high_nav_nar.properties',
                '\n'.join([
                    'EOLFLAG_INNOVATIONFEATURES=1',
                    'EOLFLAG_HU_VARIANT=6',
                    '',
                ]),
            )

        return tmpdir, jxe_path

    def test_infer_active_variants_from_variant_selector(self):
        tmpdir, jxe_path = self.make_sample_jxe()
        self.addCleanup(tmpdir.cleanup)

        config = self.module.load_jxe_config(str(jxe_path))
        inferred = self.module.infer_active_variants(
            config['selector_props'],
            config['variants'].keys(),
        )

        self.assertEqual(inferred, ['vw_high_nar', 'no_online_services'])

    def test_compose_effective_values_applies_range_lock(self):
        tmpdir, jxe_path = self.make_sample_jxe()
        self.addCleanup(tmpdir.cleanup)

        config = self.module.load_jxe_config(str(jxe_path))
        raw, ranges = self.module.compose_effective_values(
            config,
            ['vw_high_nar', 'no_online_services'],
        )

        self.assertEqual(raw['EOLFLAG_HU_REGION']['value'], '1')
        self.assertEqual(raw['EOLFLAG_HU_REGION']['source'], 'vw_high_nar.properties')
        self.assertEqual(ranges['EOLFLAG_GOOGLE_EARTH']['value'], '0')
        self.assertEqual(ranges['EOLFLAG_GOOGLE_EARTH']['source'], 'no_online_services.properties')

    def test_variant_summary_counts_range_entries(self):
        tmpdir, jxe_path = self.make_sample_jxe()
        self.addCleanup(tmpdir.cleanup)

        config = self.module.load_jxe_config(str(jxe_path))
        summary = self.module.variant_summary(
            'no_online_services',
            config['variants']['no_online_services']['props'],
        )

        self.assertEqual(summary['eol_count'], 0)
        self.assertEqual(summary['range_count'], 1)
        self.assertIsNone(summary['hu_variant'])

    def test_modify_jxe_keeps_google_earth_enable_flow(self):
        tmpdir, jxe_path = self.make_sample_jxe()
        self.addCleanup(tmpdir.cleanup)

        output_path = Path(tmpdir.name) / 'modified_lsd.jxe'
        self.module.modify_jxe(
            str(jxe_path),
            str(output_path),
            {'EOLFLAG_GOOGLE_EARTH': '1'},
        )

        flags, _ = self.module.read_flags(str(output_path))
        self.assertEqual(flags['EOLFLAG_GOOGLE_EARTH'], '1')
        self.assertEqual(flags['EOLFLAG_INNOVATIONFEATURES'], '0')

        with zipfile.ZipFile(output_path, 'r') as zf:
            self.assertIn('resources/sysconst/variant.properties', zf.namelist())

    def test_build_changes_accepts_google_earth_shorthand(self):
        args = SimpleNamespace(
            enable=['GOOGLE_EARTH'],
            disable=[],
            set=[],
        )

        changes = self.module.build_changes(args)
        self.assertEqual(changes['EOLFLAG_GOOGLE_EARTH'], '1')


class InflateIfsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.module = load_module(INFLATE_IFS, 'mmi3g_inflate_ifs_test')

    def test_build_container_command_mounts_repo_and_external_paths(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            repo_root = tmp_path / 'repo' / 'MMI3G-Toolkit'
            firmware_root = tmp_path / 'firmware'
            output_root = tmp_path / 'out'

            repo_root.mkdir(parents=True)
            firmware_root.mkdir()
            output_root.mkdir()

            ifs_path = firmware_root / 'ifs-root.ifs'
            ifs_path.write_bytes(b'fake')
            output_path = output_root / 'ifs-root.decomp'
            extract_path = output_root / 'extracted'

            command = self.module.build_container_command(
                container_tool='podman',
                image='debian:bookworm-slim',
                ifs_path=str(ifs_path),
                output_path=str(output_path),
                extract_path=str(extract_path),
                keep_decomp=False,
                repo_root=str(repo_root),
            )

        command_text = ' '.join(command)
        self.assertIn('podman run --rm', command_text)
        self.assertIn('--security-opt label=disable', command_text)
        self.assertIn('{}:/workspace'.format(repo_root), command_text)
        self.assertIn('{}:/mnt/host0'.format(firmware_root), command_text)
        self.assertIn('{}:/mnt/host1'.format(output_root), command_text)
        self.assertIn('/workspace/tools/inflate_ifs.py', command_text)
        self.assertIn('/mnt/host0/ifs-root.ifs', command_text)
        self.assertIn('/mnt/host1/ifs-root.decomp', command_text)
        self.assertIn('/mnt/host1/extracted', command_text)
        self.assertIn('--no-container-fallback', command_text)

    def test_build_container_command_adds_selinux_compat_for_docker(self):
        command = self.module.build_container_command(
            container_tool='docker',
            image='debian:bookworm-slim',
            ifs_path='/tmp/ifs-root.ifs',
            output_path='/tmp/ifs-root.decomp',
            repo_root='/repo/MMI3G-Toolkit',
        )

        command_text = ' '.join(command)
        self.assertIn('docker run --rm', command_text)
        self.assertIn('--security-opt label=disable', command_text)

    def test_translate_host_path_prefers_workspace_for_repo_files(self):
        repo_root = '/repo/MMI3G-Toolkit'
        translated = self.module.translate_host_path(
            '/repo/MMI3G-Toolkit/tools/inflate_ifs.py',
            repo_root,
            [],
        )
        self.assertEqual(translated, '/workspace/tools/inflate_ifs.py')


if __name__ == '__main__':
    unittest.main()
