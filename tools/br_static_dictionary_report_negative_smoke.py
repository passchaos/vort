#!/usr/bin/env python3
"""Negative smoke tests for Brotli static dictionary report validation."""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
import tempfile
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SMOKE = ROOT / "tools" / "br_static_dictionary_report_smoke.py"

BASE_ENTRIES = [
    {"transform": 0, "copy_len": 5, "word_index": 43, "word_bytes": 5, "word": "words"},
    {"transform": 0, "copy_len": 10, "word_index": 205, "word_bytes": 10, "word": "dictionary"},
    {"transform": 1, "copy_len": 10, "word_index": 205, "word_bytes": 11, "word": "dictionary "},
    {"transform": 6, "copy_len": 7, "word_index": 170, "word_bytes": 8, "word": " release"},
    {"transform": 9, "copy_len": 7, "word_index": 37, "word_bytes": 7, "word": "History"},
    {"transform": 12, "copy_len": 5, "word_index": 44, "word_bytes": 4, "word": "game"},
]


def report(entries: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "schema": "vort.br_static_dictionary_report",
        "schema_version": 1,
        "entry_count": len(entries),
        "transform_count": len({entry["transform"] for entry in entries}),
        "length_count": len({entry["copy_len"] for entry in entries}),
        "entries": entries,
    }


def write_artifacts(root: Path, payload: dict[str, Any]) -> tuple[Path, Path, Path]:
    json_path = root / "report.json"
    csv_path = root / "report.csv"
    md_path = root / "report.md"
    entries = payload["entries"]
    json_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    with csv_path.open("w", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=["transform", "copy_len", "word_index", "word_bytes", "word"])
        writer.writeheader()
        writer.writerows(entries)
    lines = [
        "# Brotli static dictionary subset",
        "",
        f"- Entries: {len(entries)}",
        f"- Distinct transforms: {payload['transform_count']}",
        f"- Distinct lengths: {payload['length_count']}",
        "",
        "| Transform | Copy length | Word index | Bytes | Word |",
        "| ---: | ---: | ---: | ---: | --- |",
    ]
    for entry in entries:
        lines.append(f"| {entry['transform']} | {entry['copy_len']} | {entry['word_index']} | {entry['word_bytes']} | `{entry['word']}` |")
    md_path.write_text("\n".join(lines) + "\n")
    return csv_path, json_path, md_path


def run_smoke(csv_path: Path, json_path: Path, md_path: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["python3", str(SMOKE), "--csv", str(csv_path), "--json", str(json_path), "--markdown", str(md_path)],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )


def case(name: str, payload: dict[str, Any], expected: str) -> dict[str, object]:
    with tempfile.TemporaryDirectory(prefix=f"vort-br-dict-neg-{name}-") as td:
        csv_path, json_path, md_path = write_artifacts(Path(td), payload)
        result = run_smoke(csv_path, json_path, md_path)
    matched = result.returncode != 0 and expected in result.stdout
    if not matched:
        raise AssertionError(f"{name} did not fail as expected: rc={result.returncode} output={result.stdout!r}")
    return {"name": name, "expected_output": expected, "returncode": result.returncode, "matched": matched}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary", type=Path)
    args = parser.parse_args()

    rows = []
    rows.append(case("missing_required_tuple", report(BASE_ENTRIES[:-1]), "missing required coverage rows"))

    duplicate_entries = BASE_ENTRIES + [dict(BASE_ENTRIES[0])]
    rows.append(case("duplicate_key", report(duplicate_entries), "duplicate key"))

    bad_word_bytes = [dict(entry) for entry in BASE_ENTRIES]
    bad_word_bytes[0]["word_bytes"] = 999
    rows.append(case("word_bytes_mismatch", report(bad_word_bytes), "word_bytes mismatch"))

    bad_entry_count = report(BASE_ENTRIES)
    bad_entry_count["entry_count"] = 999
    rows.append(case("entry_count_mismatch", bad_entry_count, "entry_count does not match"))

    summary = {
        "schema": "vort.br_static_dictionary_report_negative_smoke",
        "schema_version": 1,
        "ok": True,
        "case_count": len(rows),
        "cases": rows,
    }
    if args.summary:
        args.summary.parent.mkdir(parents=True, exist_ok=True)
        args.summary.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(f"br_static_dictionary_report_negative_smoke=ok cases={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
