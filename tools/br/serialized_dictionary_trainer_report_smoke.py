#!/usr/bin/env python3
"""Self-contained validation for the serialized trainer report gate."""

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
SPEC = importlib.util.spec_from_file_location(
    "serialized_dictionary_trainer_report",
    HERE / "serialized_dictionary_trainer_report.py",
)
assert SPEC and SPEC.loader
report = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(report)


def manifest() -> object:
    cases = (
        report.real_corpus_diff.CorpusCase("source", "source", Path("source.zig"), 32768),
        report.real_corpus_diff.CorpusCase("binary", "binary", Path("dict.bin"), 32768),
    )
    return report.real_corpus_diff.Manifest(32768, 4, ("source", "binary"), cases)


def row(label: str, category: str, winner: int = 1, shadow_winner: int = 1) -> dict[str, object]:
    baseline = 1000
    total = 800 if winner else baseline
    return {
        "label": label,
        "category": category,
        "input_bytes": 32768,
        "training_samples": 48,
        "validation_samples": 16,
        "baseline_frames": baseline,
        "trained_frames": 700 if winner else baseline,
        "dictionary_bytes": 100 if winner else 0,
        "total_bytes": total,
        "savings": baseline - total,
        "ratio_ppm": total * 1_000_000 // baseline,
        "winner": winner,
        "word_profile": "cover" if winner else "none",
        "word_min": 4 if winner else 0,
        "word_max": 16 if winner else 0,
        "max_words_per_length": 8 if winner else 0,
        "word_bucket_candidates": 1 if winner else 0,
        "cover_d": 6 if winner else None,
        "cover_hash_log": 12 if winner else None,
        "context_profile": "global" if winner else "none",
        "context_mode": None,
        "context_cutoff": None,
        "context_clusters": 1 if winner else 0,
        "transform_profile": "identity" if winner else "none",
        "transform_lists": 1 if winner else 0,
        "shift_parameters": 0,
        "shadow_winner": shadow_winner,
        "shadow_frames": 750 if shadow_winner else baseline,
        "shadow_dictionary_bytes": 100 if shadow_winner else 0,
        "shadow_frame_savings": 250 if shadow_winner else 0,
        "break_even_batches": 1 if shadow_winner else 0,
        "break_even_frames": 7 if shadow_winner else 0,
        "shadow_word_profile": "cover" if shadow_winner else "none",
        "shadow_word_min": 4 if shadow_winner else 0,
        "shadow_word_max": 10 if shadow_winner else 0,
        "shadow_max_words_per_length": 4 if shadow_winner else 0,
        "shadow_word_bucket_candidates": 3 if shadow_winner else 0,
        "shadow_cover_d": 6 if shadow_winner else None,
        "shadow_cover_hash_log": 12 if shadow_winner else None,
        "train_ns": 1_000_000,
        "shadow_train_ns": 900_000,
        "peak_bytes": 4 * 1024 * 1024,
        "worst_sample_delta": 2 if winner else 0,
        "shadow_worst_sample_delta": 3 if shadow_winner else 0,
    }


class ReportSmoke(unittest.TestCase):
    def test_complete_rows_and_artifacts(self) -> None:
        rows = [row("source", "source"), row("binary", "binary", 0, 0)]
        summary = report.validate_rows(rows, manifest(), 32768)
        self.assertEqual(1, summary["winners"])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            json_path = root / "report.json"
            markdown_path = root / "report.md"
            report.write_json(json_path, rows, summary, 32768, 512)
            report.write_markdown(markdown_path, rows, summary)
            document = json.loads(json_path.read_text(encoding="utf-8"))
            self.assertEqual(report.SCHEMA, document["schema"])
            self.assertIn("| source | source |", markdown_path.read_text(encoding="utf-8"))

    def test_rejects_complete_total_regression(self) -> None:
        rows = [row("source", "source"), row("binary", "binary", 0, 0)]
        rows[0]["total_bytes"] = 1001
        with self.assertRaisesRegex(RuntimeError, "complete-total"):
            report.validate_rows(rows, manifest(), 32768)

    def test_rejects_missing_case(self) -> None:
        with self.assertRaisesRegex(RuntimeError, "expected 2"):
            report.validate_rows([row("source", "source")], manifest(), 32768)

    def test_accepts_honest_no_winner_report(self) -> None:
        rows = [row("source", "source", 0, 0), row("binary", "binary", 0, 0)]
        summary = report.validate_rows(rows, manifest(), 32768)
        self.assertEqual(0, summary["winners"])

    def test_rejects_bad_break_even(self) -> None:
        rows = [row("source", "source"), row("binary", "binary", 0, 0)]
        rows[0]["break_even_frames"] = 8
        with self.assertRaisesRegex(RuntimeError, "break-even"):
            report.validate_rows(rows, manifest(), 32768)

    def test_parser_rejects_bad_header(self) -> None:
        with self.assertRaisesRegex(RuntimeError, "unexpected header"):
            report.parse_rows("bad\theader\n")


if __name__ == "__main__":
    unittest.main()
