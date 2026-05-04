from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
PAGES_WORKFLOW = REPO_ROOT / '.github' / 'workflows' / 'pages.yml'


class PagesWorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = PAGES_WORKFLOW.read_text(encoding='utf-8')

    def test_pages_workflow_mirrors_p0824_payload_without_committing_zip(self):
        self.assertIn('build_type=workflow', self.source)
        self.assertIn('actions/deploy-pages@v4', self.source)
        self.assertIn('actions/upload-pages-artifact@v3', self.source)
        self.assertIn('gh release download v1.0-gemmi-p0824', self.source)
        self.assertIn('gemmi_p0824_eu_vw.zip', self.source)
        self.assertIn('9823685', self.source)
        self.assertFalse((REPO_ROOT / 'docs' / 'payloads' / 'gemmi_p0824_eu_vw.zip').exists())


if __name__ == '__main__':
    unittest.main()
