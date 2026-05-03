from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
WEB_BUILDER = REPO_ROOT / "docs" / "app" / "index.html"


class WebBuilderParityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = WEB_BUILDER.read_text(encoding="utf-8")

    def test_generate_run_sh_sources_platform_helper(self):
        for snippet in (
            "scripts/common/platform.sh",
            "platform.sh installed to ${EFSDIR}/scripts/common/",
        ):
            self.assertIn(snippet, self.source)

    def test_generate_run_sh_shows_running_and_done_status(self):
        for snippet in (
            "/tmp/showScreen",
            "SHOWSCREEN_PID=$!",
            "lib/running.png",
            "lib/done.png",
            "kill ${SHOWSCREEN_PID} 2>/dev/null",
        ):
            self.assertIn(snippet, self.source)

    def test_bundle_includes_platform_helper_and_module_artifacts(self):
        self.assertIn(
            'files.push({ path: "scripts/common/platform.sh", bytes: platformSh });',
            self.source,
        )
        self.assertIn(
            'if (meta.artifact && f.path === meta.artifact) return `modules/${modName}/${f.path}`;',
            self.source,
        )
        self.assertIn(
            'for (const payload of (meta.payload_dirs || [])) {',
            self.source,
        )
        self.assertIn(
            'return { path: moduleOutputPath(modName, meta, f), bytes };',
            self.source,
        )

    def test_web_release_zip_prefers_pages_url(self):
        self.assertIn('if (rz && rz.web_url) return rz.web_url;', self.source)
        self.assertIn('const zipFiles = await fetchReleaseZipFiles(rz);', self.source)

    def test_p0824_card_is_web_buildable_with_pages_payload_link(self):
        p0824_start = self.source.index('{ id: "google-earth-p0824-deploy"')
        p0824_end = self.source.index('{ id: "google-earth-p0824-restore"', p0824_start)
        p0824_card = self.source[p0824_start:p0824_end]

        self.assertNotIn('cliOnly: true', p0824_card)
        self.assertIn(
            'payloadUrl: "https://dspl1236.github.io/MMI3G-Toolkit/payloads/gemmi_p0824_eu_vw.zip"',
            p0824_card,
        )


if __name__ == "__main__":
    unittest.main()
