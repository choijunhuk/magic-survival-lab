import importlib.util
import io
import json
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image


spec = importlib.util.spec_from_file_location("collector", Path(__file__).with_name("collect-reference-assets.py"))
collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)


class CollectionContract(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.dest = self.root / "assets/references"
        self.dest.mkdir(parents=True)
        self.paths = patch.multiple(collector, ROOT=self.root, DEST=self.dest)
        self.paths.start()
        self.addCleanup(self.paths.stop)

    def test_failure_preserves_complete_catalog_and_reports_nonzero(self):
        previous = '{"files": [], "previous_success": true}\n'
        (self.dest / "catalog.json").write_text(previous)
        (self.dest / "candidates.json").write_text(json.dumps({"sources": [
            {"source": "https://example.invalid/not-allowed.png", "category": "maps"}
        ]}))
        (self.root / "assets/catalog.json").write_text('{"files": []}')
        with patch("sys.stdout", new_callable=io.StringIO):
            status = collector.main()
        self.assertEqual(status, 1)
        self.assertEqual((self.dest / "catalog.json").read_text(), previous)
        report = self.root / ".omx/artifacts/asset-expansion/collection-failures.json"
        self.assertEqual(len(json.loads(report.read_text())["failures"]), 1)

    def test_truncated_jpeg_is_not_accepted_as_an_image(self):
        output = io.BytesIO()
        Image.new("RGB", (32, 32), "olive").save(output, format="JPEG")
        truncated = output.getvalue()[:-2]

        def download(command, **_options):
            Path(command[command.index("--output") + 1]).write_bytes(truncated)
            return SimpleNamespace(returncode=0, stderr="", stdout="image/jpeg")

        with patch.object(collector.subprocess, "run", side_effect=download):
            record, failure = collector.fetch({
                "source": "https://img.atwiki.jp/magicsurvival/truncated.jpg",
                "category": "maps", "name": "truncated test",
            })
        self.assertIsNone(record)
        self.assertIsNotNone(failure)
        self.assertEqual(list(self.dest.rglob("*.jpg")), [])


if __name__ == "__main__":
    unittest.main()
