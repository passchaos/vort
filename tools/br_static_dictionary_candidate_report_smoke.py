#!/usr/bin/env python3
"""Validate Brotli static-dictionary candidate report artifacts."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

sys.dont_write_bytecode = True

from br_static_dictionary_source_audit import DEFAULT_ANCHORS, entry_key, load_anchors
from validation_json_docs_check import load_manifest, validate_value_against_manifest

REQUIRED_CANDIDATES = {
    (1, 5, 0, "first "),
    (1, 7, 94, "through "),
    (6, 5, 35, " about"),
    (9, 5, 35, "About"),
    (12, 10, 205, "dictionar"),
}


def load_json(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text())
    if not isinstance(payload, dict):
        raise AssertionError(f"{path} must contain a JSON object")
    return payload


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", required=True, type=Path)
    parser.add_argument("--markdown", required=True, type=Path)
    parser.add_argument("--anchors", type=Path, default=DEFAULT_ANCHORS)
    args = parser.parse_args()

    anchors = load_anchors(args.anchors)
    report = load_json(args.json)
    if report.get("schema") != "vort.br_static_dictionary_candidate_report":
        raise AssertionError("unexpected candidate report schema")
    if report.get("schema_version") != 1:
        raise AssertionError("unexpected candidate report schema_version")
    if report.get("source_mode") != "anchors":
        raise AssertionError("default candidate report must use anchors source_mode")
    if report.get("source_limit") != 0 or report.get("upstream_raw_word_count") != 0:
        raise AssertionError("default candidate report must not include upstream raw words")
    validate_value_against_manifest(report, load_manifest())

    candidates = report.get("candidates")
    if not isinstance(candidates, list) or not candidates:
        raise AssertionError("candidate report must include candidates")
    if report.get("source_entry_count") != len(anchors):
        raise AssertionError("source_entry_count mismatch")
    if report.get("anchor_raw_word_count") != len({(entry["copy_len"], entry["word_index"]) for entry in anchors}):
        raise AssertionError("anchor_raw_word_count mismatch")
    if report.get("candidate_count") != len(candidates):
        raise AssertionError("candidate_count mismatch")
    if sum(row["candidate_count"] for row in report.get("kind_rows", [])) != len(candidates):
        raise AssertionError("kind row candidate counts do not sum to candidate_count")
    if sum(row["candidate_count"] for row in report.get("length_rows", [])) != len(candidates):
        raise AssertionError("length row candidate counts do not sum to candidate_count")
    existing = {entry_key(entry) for entry in anchors}
    seen: set[tuple[int, int, int]] = set()
    candidate_words: set[tuple[int, int, int, str]] = set()
    for index, row in enumerate(candidates):
        if not isinstance(row, dict):
            raise AssertionError(f"candidates[{index}] must be object")
        key = (row["transform"], row["copy_len"], row["word_index"])
        if key in existing:
            raise AssertionError(f"candidate duplicates existing anchor {key}")
        if key in seen:
            raise AssertionError(f"duplicate candidate key {key}")
        seen.add(key)
        candidate_words.add((row["transform"], row["copy_len"], row["word_index"], row["transformed_word"]))
    missing = sorted(REQUIRED_CANDIDATES - candidate_words)
    if missing:
        raise AssertionError(f"missing required candidates: {missing}")

    markdown = args.markdown.read_text()
    for text in ("# Brotli static dictionary candidate report", "## Transform-kind summary", "## Copy-length summary", f"- Candidate entries: {len(candidates)}"):
        if text not in markdown:
            raise AssertionError(f"Markdown missing {text!r}")
    print(f"br_static_dictionary_candidate_report_smoke=ok candidates={len(candidates)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
