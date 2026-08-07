#!/usr/bin/env python3
"""Validate Brotli static dictionary coverage report artifacts."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REQUIRED = ROOT / "tools" / "br_static_dictionary_required_coverage.json"


def load_json(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text())
    if not isinstance(payload, dict):
        raise AssertionError(f"{path} must contain a JSON object")
    return payload


def load_required(path: Path) -> set[tuple[int, int, int, str]]:
    payload = load_json(path)
    if payload.get("schema") != "vort.br_static_dictionary_required_coverage":
        raise AssertionError("unexpected required coverage schema")
    if payload.get("schema_version") != 1:
        raise AssertionError("unexpected required coverage schema_version")
    entries = payload.get("entries")
    if not isinstance(entries, list) or not entries:
        raise AssertionError("required coverage entries must be non-empty list")
    required: set[tuple[int, int, int, str]] = set()
    for index, entry in enumerate(entries):
        if not isinstance(entry, dict):
            raise AssertionError(f"required.entries[{index}] must be object")
        transform = entry.get("transform")
        copy_len = entry.get("copy_len")
        word_index = entry.get("word_index")
        word = entry.get("word")
        if not isinstance(transform, int) or not isinstance(copy_len, int) or not isinstance(word_index, int) or not isinstance(word, str):
            raise AssertionError(f"required.entries[{index}] fields invalid")
        key = (transform, copy_len, word_index, word)
        if key in required:
            raise AssertionError(f"duplicate required coverage tuple {key}")
        required.add(key)
    return required


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", required=True, type=Path)
    parser.add_argument("--json", required=True, type=Path)
    parser.add_argument("--markdown", required=True, type=Path)
    parser.add_argument("--required", type=Path, default=DEFAULT_REQUIRED)
    args = parser.parse_args()

    report = load_json(args.json)
    if report.get("schema") != "vort.br_static_dictionary_report":
        raise AssertionError("unexpected schema")
    if report.get("schema_version") != 1:
        raise AssertionError("unexpected schema_version")
    entries = report.get("entries")
    if not isinstance(entries, list):
        raise AssertionError("entries must be a list")
    if report.get("entry_count") != len(entries):
        raise AssertionError("entry_count does not match entries length")

    required = load_required(args.required)
    seen: set[tuple[int, int, int, str]] = set()
    keys: set[tuple[int, int, int]] = set()
    transforms: set[int] = set()
    lengths: set[int] = set()
    for index, item in enumerate(entries):
        if not isinstance(item, dict):
            raise AssertionError(f"entries[{index}] must be object")
        transform = item.get("transform")
        copy_len = item.get("copy_len")
        word_index = item.get("word_index")
        word_bytes = item.get("word_bytes")
        word = item.get("word")
        if not isinstance(transform, int) or not isinstance(copy_len, int) or not isinstance(word_index, int):
            raise AssertionError(f"entries[{index}] numeric fields invalid")
        if not isinstance(word_bytes, int) or not isinstance(word, str):
            raise AssertionError(f"entries[{index}] word fields invalid")
        if word_bytes != len(word.encode()):
            raise AssertionError(f"entries[{index}] word_bytes mismatch")
        key = (transform, copy_len, word_index)
        if key in keys:
            raise AssertionError(f"duplicate key {key}")
        keys.add(key)
        transforms.add(transform)
        lengths.add(copy_len)
        seen.add((transform, copy_len, word_index, word))

    if report.get("transform_count") != len(transforms):
        raise AssertionError("transform_count mismatch")
    if report.get("length_count") != len(lengths):
        raise AssertionError("length_count mismatch")
    missing = sorted(required - seen)
    if missing:
        raise AssertionError(f"missing required coverage rows: {missing}")

    with args.csv.open(newline="") as fh:
        rows = list(csv.DictReader(fh))
    if len(rows) != len(entries):
        raise AssertionError("CSV row count mismatch")
    csv_seen = {(int(row["transform"]), int(row["copy_len"]), int(row["word_index"]), row["word"]) for row in rows}
    if csv_seen != seen:
        raise AssertionError("CSV rows differ from JSON entries")

    markdown = args.markdown.read_text()
    if f"- Entries: {len(entries)}" not in markdown:
        raise AssertionError("Markdown entry count missing")
    for transform, copy_len, word_index, word in required:
        row = f"| {transform} | {copy_len} | {word_index} | {len(word.encode())} | `{word}` |"
        if row not in markdown:
            raise AssertionError(f"Markdown missing row {row!r}")

    print(
        f"br_static_dictionary_report_smoke=ok entries={len(entries)} "
        f"transforms={len(transforms)} lengths={len(lengths)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
