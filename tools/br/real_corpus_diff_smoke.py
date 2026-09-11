#!/usr/bin/env python3
"""Self-contained validation for the Brotli real-corpus gate driver."""

from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
SCRIPT = Path(__file__).with_name("real_corpus_diff.py")
SPEC = importlib.util.spec_from_file_location("real_corpus_diff", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
gate = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = gate
SPEC.loader.exec_module(gate)


def write_manifest(path: Path, cases: list[dict[str, object]], categories: list[str]) -> None:
    path.write_text(json.dumps({
        "schema": "vort.br_real_corpus_manifest",
        "schema_version": 1,
        "real_limit": 1024,
        "options_per_file": 4,
        "required_categories": categories,
        "cases": cases,
    }), encoding="utf-8")


class RealCorpusDiffTests(unittest.TestCase):
    def test_manifest_and_summary_accept_complete_coverage(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (root / "source.zig").write_bytes(b"source")
            (root / "data.bin").write_bytes(b"binary")
            manifest_path = root / "manifest.json"
            write_manifest(manifest_path, [
                {"label": "source", "category": "source", "path": "source.zig", "min_bytes": 6},
                {"label": "binary", "category": "binary", "path": "data.bin", "min_bytes": 6},
            ], ["source", "binary"])
            manifest = gate.load_manifest(manifest_path, root)
            fields = gate.parse_summary(
                "noise\nbr_upstream_multiblock_diff=ok real_file_cases=8 "
                "real_progressive_cases=8 real_options_per_file=4 "
                "real_quality_mask=0x911 real_mode_mask=0x7 real_window_mask=0x1110400 "
                "summaries_unsupported=0 reference_version=1001000\n"
            )
            self.assertEqual((8, 8, "1001000"), gate.validate_summary(fields, manifest, 0))

    def test_manifest_rejects_missing_category(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (root / "source.zig").write_bytes(b"source")
            manifest_path = root / "manifest.json"
            write_manifest(manifest_path, [
                {"label": "source", "category": "source", "path": "source.zig", "min_bytes": 1},
            ], ["source", "binary"])
            with self.assertRaisesRegex(RuntimeError, "misses required categories: binary"):
                gate.load_manifest(manifest_path, root)

    def test_manifest_rejects_missing_file(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            manifest_path = root / "manifest.json"
            write_manifest(manifest_path, [
                {"label": "missing", "category": "source", "path": "missing.zig", "min_bytes": 1},
            ], ["source"])
            with self.assertRaisesRegex(RuntimeError, "case missing is missing"):
                gate.load_manifest(manifest_path, root)

    def test_manifest_rejects_option_matrix_drift(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (root / "source.zig").write_bytes(b"source")
            manifest_path = root / "manifest.json"
            write_manifest(manifest_path, [
                {"label": "source", "category": "source", "path": "source.zig", "min_bytes": 1},
            ], ["source"])
            document = json.loads(manifest_path.read_text(encoding="utf-8"))
            document["options_per_file"] = 3
            manifest_path.write_text(json.dumps(document), encoding="utf-8")
            with self.assertRaisesRegex(RuntimeError, "four-option matrix"):
                gate.load_manifest(manifest_path, root)

    def test_summary_rejects_missing_progressive_cases(self) -> None:
        manifest = gate.Manifest(1024, 4, ("source",), (gate.CorpusCase("source", "source", Path("source.zig"), 6),))
        fields = {
            "real_file_cases": "4",
            "real_progressive_cases": "3",
            "real_options_per_file": "4",
            "real_quality_mask": "0x911",
            "real_mode_mask": "0x7",
            "real_window_mask": "0x1110400",
            "summaries_unsupported": "0",
            "reference_version": "1001000",
        }
        with self.assertRaisesRegex(RuntimeError, "progressively decoded 3.*expected 4"):
            gate.validate_summary(fields, manifest, 0)

    def test_summary_rejects_quality_matrix_drift(self) -> None:
        manifest = gate.Manifest(1024, 4, ("source",), (gate.CorpusCase("source", "source", Path("source.zig"), 6),))
        fields = {
            "real_file_cases": "4",
            "real_progressive_cases": "4",
            "real_options_per_file": "4",
            "real_quality_mask": "0x111",
            "real_mode_mask": "0x7",
            "real_window_mask": "0x1110400",
            "summaries_unsupported": "0",
            "reference_version": "1001000",
        }
        with self.assertRaisesRegex(RuntimeError, "quality mask"):
            gate.validate_summary(fields, manifest, 0)

    def test_driver_forwards_manifest_and_extra_files(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            for name in ("source.zig", "data.bin", "extra.txt"):
                (root / name).write_bytes(name.encode())
            manifest_path = root / "manifest.json"
            write_manifest(manifest_path, [
                {"label": "source", "category": "source", "path": "source.zig", "min_bytes": 1},
                {"label": "binary", "category": "binary", "path": "data.bin", "min_bytes": 1},
            ], ["source", "binary"])
            probe = root / "probe.py"
            probe.write_text(
                "#!/usr/bin/env python3\n"
                "import sys\n"
                "files=sum(a == '--real-file' for a in sys.argv)\n"
                "cases=files*4\n"
                "print(f'br_upstream_multiblock_diff=ok real_file_cases={cases} real_progressive_cases={cases} real_options_per_file=4 real_quality_mask=0x911 real_mode_mask=0x7 real_window_mask=0x1110400 summaries_unsupported=0 reference_version=1001000')\n",
                encoding="utf-8",
            )
            probe.chmod(0o755)
            result = subprocess.run([
                sys.executable, str(SCRIPT), str(probe), "--manifest", str(manifest_path),
                "--root", str(root),
                "--extra-file", str(root / "extra.txt"),
            ], cwd=root, text=True, capture_output=True, check=True)
            self.assertIn("br_real_corpus_diff=ok files=3 required_categories=2 real_file_cases=12 real_progressive_cases=12", result.stdout)


if __name__ == "__main__":
    unittest.main()
