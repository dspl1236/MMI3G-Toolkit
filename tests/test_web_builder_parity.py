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
            'return Boolean(meta.artifact) && f.path === meta.artifact;',
            self.source,
        )
        self.assertIn(
            'return { path: `modules/${modName}/${f.path}`, bytes };',
            self.source,
        )


if __name__ == "__main__":
    unittest.main()
