#!/usr/bin/env python3
"""Validate Brotli static dictionary coverage report artifacts."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path
from typing import Any

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REQUIRED = ROOT / "tools" / "br_static_dictionary_required_coverage.json"
DEFAULT_CASE_SOURCE = ROOT / "tools" / "br_literal_cli_diff.py"


def load_json(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text())
    if not isinstance(payload, dict):
        raise AssertionError(f"{path} must contain a JSON object")
    return payload


def load_case_names(path: Path) -> set[str]:
    text = path.read_text()
    return set(re.findall(r'"([^"\\]+)": \(', text))


def markdown_code(value: str) -> str:
    """Mirror the report's byte-oriented Markdown table escaping."""
    escaped: list[str] = []
    for byte in value.encode():
        if byte in (ord("`"), ord("\\"), ord("|")):
            escaped.append("\\" + chr(byte))
        elif byte == ord("\n"):
            escaped.append("\\n")
        elif byte == ord("\r"):
            escaped.append("\\r")
        elif byte == ord("\t"):
            escaped.append("\\t")
        elif byte < 0x20 or byte == 0x7F:
            escaped.append(f"\\x{byte:02x}")
        else:
            escaped.append(bytes([byte]).decode("latin-1"))
    # The per-byte Latin-1 bridge preserves the original UTF-8 bytes while
    # returning normal Python text for direct comparison with read_text().
    return "".join(escaped).encode("latin-1").decode("utf-8")


def load_required(path: Path, case_source: Path) -> set[tuple[int, int, int, str]]:
    payload = load_json(path)
    if payload.get("schema") != "vort.br_static_dictionary_required_coverage":
        raise AssertionError("unexpected required coverage schema")
    if payload.get("schema_version") != 1:
        raise AssertionError("unexpected required coverage schema_version")
    entries = payload.get("entries")
    if not isinstance(entries, list) or not entries:
        raise AssertionError("required coverage entries must be non-empty list")
    case_names = load_case_names(case_source)
    required: set[tuple[int, int, int, str]] = set()
    for index, entry in enumerate(entries):
        if not isinstance(entry, dict):
            raise AssertionError(f"required.entries[{index}] must be object")
        transform = entry.get("transform")
        copy_len = entry.get("copy_len")
        word_index = entry.get("word_index")
        word = entry.get("word")
        reason = entry.get("reason")
        source_case = entry.get("source_case")
        category = entry.get("category")
        if not isinstance(transform, int) or not isinstance(copy_len, int) or not isinstance(word_index, int) or not isinstance(word, str):
            raise AssertionError(f"required.entries[{index}] fields invalid")
        if not isinstance(reason, str) or not reason or not isinstance(source_case, str) or not source_case:
            raise AssertionError(f"required.entries[{index}] metadata fields invalid")
        if category not in {"identity", "transform", "phrase"}:
            raise AssertionError(f"required.entries[{index}] category invalid")
        if source_case not in case_names:
            raise AssertionError(f"required.entries[{index}] source_case {source_case!r} is not present in {case_source}")
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
    parser.add_argument("--case-source", type=Path, default=DEFAULT_CASE_SOURCE)
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

    required = load_required(args.required, args.case_source)
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
    category_counts = report.get("category_counts")
    if not isinstance(category_counts, dict):
        raise AssertionError("category_counts must be an object")
    identity_count = 0
    transform_count = 0
    phrase_count = 0
    for transform, _, _, word in seen:
        if " " in word:
            phrase_count += 1
        elif transform == 0:
            identity_count += 1
        else:
            transform_count += 1
    if category_counts.get("identity") != identity_count or category_counts.get("transform") != transform_count or category_counts.get("phrase") != phrase_count:
        raise AssertionError("category_counts mismatch")
    matrix_rows = report.get("matrix_rows")
    if not isinstance(matrix_rows, list):
        raise AssertionError("matrix_rows must be a list")
    matrix_total = 0
    matrix_transforms: set[int] = set()
    for index, row in enumerate(matrix_rows):
        if not isinstance(row, dict):
            raise AssertionError(f"matrix_rows[{index}] must be object")
        transform = row.get("transform")
        identity = row.get("identity")
        transform_entries = row.get("transform_entries")
        phrase = row.get("phrase")
        total = row.get("total")
        if not all(isinstance(value, int) for value in (transform, identity, transform_entries, phrase, total)):
            raise AssertionError(f"matrix_rows[{index}] fields invalid")
        if identity + transform_entries + phrase != total:
            raise AssertionError(f"matrix_rows[{index}] total mismatch")
        matrix_total += total
        matrix_transforms.add(transform)
    if matrix_total != len(entries):
        raise AssertionError("matrix row totals do not match entry count")
    if matrix_transforms != transforms:
        raise AssertionError("matrix transforms differ from entry transforms")
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
    for label, count in (("Identity entries", identity_count), ("Transform entries", transform_count), ("Phrase entries", phrase_count)):
        if f"- {label}: {count}" not in markdown:
            raise AssertionError(f"Markdown {label} count missing")
    for row in matrix_rows:
        markdown_row = f"| {row['transform']} | {row['identity']} | {row['transform_entries']} | {row['phrase']} | {row['total']} |"
        if markdown_row not in markdown:
            raise AssertionError(f"Markdown missing matrix row {markdown_row!r}")
    for transform, copy_len, word_index, word in required:
        row = f"| {transform} | {copy_len} | {word_index} | {len(word.encode())} | `{markdown_code(word)}` |"
        if row not in markdown:
            raise AssertionError(f"Markdown missing row {row!r}")

    print(
        f"br_static_dictionary_report_smoke=ok entries={len(entries)} "
        f"transforms={len(transforms)} lengths={len(lengths)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
