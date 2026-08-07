#!/usr/bin/env python3
"""Smoke-test upstream-source mode for Brotli static-dictionary candidates."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

sys.dont_write_bytecode = True

from br_static_dictionary_source_audit import DEFAULT_ANCHORS, load_anchors
from validation_json_docs_check import load_manifest, validate_value_against_manifest

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "tools" / "br_static_dictionary_candidate_report.py"


def write_fixture_common(root: Path) -> Path:
    common = root / "common"
    common.mkdir()
    data = bytearray(4096 + 5 * 8)
    words = [b"able", b"beta", b"card", b"door", b"echo", b"farm", b"gold", b"home"]
    for index, word in enumerate(words):
        data[index * 4 : (index + 1) * 4] = word
    (common / "dictionary_inc.h").write_text(
        "static const unsigned char kBrotliDictionaryData[] = {\n"
        + ",".join(str(byte) for byte in data)
        + "\n};\n"
    )
    # The upstream parser only needs these arrays for transform table parsing;
    # candidate_report applies the minimal transform metadata from source_audit.
    (common / "transform.c").write_text(
        'static const char kPrefixSuffix[1] = "\\0";\n'
        'static const unsigned short kPrefixSuffixMap[1] = {0};\n'
        'static const unsigned char kTransformsData[] = {0, BROTLI_TRANSFORM_IDENTITY, 0};\n'
    )
    return common


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise AssertionError(f"{path} must be a JSON object")
    return value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary", type=Path)
    args = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix="vort-br-upstream-candidates-") as td:
        root = Path(td)
        common = write_fixture_common(root)
        json_path = root / "candidates.json"
        md_path = root / "candidates.md"
        result = subprocess.run(
            [
                "python3",
                str(REPORT),
                "--json",
                str(json_path),
                "--markdown",
                str(md_path),
                "--brotli-common-dir",
                str(common),
                "--source-limit",
                "8",
            ],
            cwd=ROOT,
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        report = load_json(json_path)
        validate_value_against_manifest(report, load_manifest())
        if report["source_mode"] != "upstream":
            raise AssertionError("upstream smoke report must use upstream source_mode")
        anchor_raw_word_count = len({(entry["copy_len"], entry["word_index"]) for entry in load_anchors(DEFAULT_ANCHORS)})
        if report["raw_word_count"] < anchor_raw_word_count + 8:
            raise AssertionError("upstream raw words were not merged into candidate pool")
        expected_candidates = {
            (0, 4, 0, "able"),
            (1, 4, 0, "able "),
            (9, 4, 1, "Beta"),
            (12, 4, 2, "car"),
        }
        actual_candidates = {
            (row["transform"], row["copy_len"], row["word_index"], row["transformed_word"])
            for row in report["candidates"]
        }
        missing = sorted(expected_candidates - actual_candidates)
        if missing:
            raise AssertionError(f"missing expected upstream candidates: {missing}")
        markdown = md_path.read_text()
        if "- Source mode: upstream" not in markdown:
            raise AssertionError("Markdown does not record upstream source mode")

    summary = {
        "schema": "vort.br_static_dictionary_candidate_upstream_smoke",
        "schema_version": 1,
        "ok": True,
        "source_mode": report["source_mode"],
        "source_entry_count": report["source_entry_count"],
        "raw_word_count": report["raw_word_count"],
        "candidate_count": report["candidate_count"],
        "stdout": result.stdout.strip(),
    }
    validate_value_against_manifest(summary, load_manifest())
    if args.summary:
        args.summary.parent.mkdir(parents=True, exist_ok=True)
        args.summary.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(f"br_static_dictionary_candidate_upstream_smoke=ok candidates={summary['candidate_count']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
