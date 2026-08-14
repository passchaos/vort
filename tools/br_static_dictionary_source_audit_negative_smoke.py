#!/usr/bin/env python3
"""Negative smoke tests for Brotli static-dictionary source-anchor audit."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

sys.dont_write_bytecode = True

from validation_json_docs_check import load_manifest, validate_value_against_manifest


ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / "tools" / "br_static_dictionary_source_audit.py"
ANCHORS = ROOT / "tools" / "br_static_dictionary_source_anchors.json"
SOURCE = ROOT / "src" / "br.zig"


def load_anchor_payload() -> dict[str, Any]:
    payload = json.loads(ANCHORS.read_text())
    if not isinstance(payload, dict):
        raise AssertionError("anchor payload must be object")
    return payload


def clone_payload(payload: dict[str, Any]) -> dict[str, Any]:
    return json.loads(json.dumps(payload))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def run_audit(root: Path, payload: dict[str, Any], *, source_text: str | None = None, brotli_common_dir: Path | None = None) -> subprocess.CompletedProcess[str]:
    anchors_path = root / "anchors.json"
    write_json(anchors_path, payload)
    command = ["python3", str(AUDIT), "--anchors", str(anchors_path), "--summary", str(root / "summary.json")]
    if source_text is not None:
        source_path = root / "br.zig"
        source_path.write_text(source_text)
        command.extend(["--source", str(source_path)])
    if brotli_common_dir is not None:
        command.extend(["--brotli-common-dir", str(brotli_common_dir)])
    return subprocess.run(command, check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def case(name: str, payload: dict[str, Any], expected: str, *, source_text: str | None = None, brotli_common_dir: Path | None = None) -> dict[str, object]:
    with tempfile.TemporaryDirectory(prefix=f"vort-br-source-neg-{name}-") as td:
        root = Path(td)
        result = run_audit(root, payload, source_text=source_text, brotli_common_dir=brotli_common_dir)
    matched = result.returncode != 0 and expected in result.stdout
    if not matched:
        raise AssertionError(f"{name} did not fail as expected: rc={result.returncode} output={result.stdout!r}")
    return {"name": name, "expected_output": expected, "returncode": result.returncode, "matched": matched}


def with_count(payload: dict[str, Any]) -> dict[str, Any]:
    payload["entry_count"] = len(payload["entries"])
    return payload


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary", type=Path)
    args = parser.parse_args()

    base = load_anchor_payload()
    rows: list[dict[str, object]] = []

    missing_anchor = clone_payload(base)
    missing_anchor["entries"] = missing_anchor["entries"][:-1]
    rows.append(case("missing_anchor_tuple", with_count(missing_anchor), "anchor/table key mismatch"))

    duplicate_anchor = clone_payload(base)
    duplicate_anchor["entries"].append(dict(duplicate_anchor["entries"][0]))
    rows.append(case("duplicate_anchor_key", with_count(duplicate_anchor), "duplicate anchor key"))

    bad_count = clone_payload(base)
    bad_count["entry_count"] += 1
    rows.append(case("entry_count_mismatch", bad_count, "source anchors entry_count mismatch"))

    bad_raw_len = clone_payload(base)
    bad_raw_len["entries"][0]["raw_word"] += "x"
    rows.append(case("raw_word_length_mismatch", bad_raw_len, "raw_word byte length mismatch"))

    bad_transform = clone_payload(base)
    bad_transform["entries"][0]["transformed_word"] += "x"
    rows.append(case("transformed_word_mismatch", bad_transform, "transform output mismatch"))

    bad_kind = clone_payload(base)
    bad_kind["entries"][0]["transform_kind"] = "uppercase_first"
    rows.append(case("transform_kind_mismatch", bad_kind, "transform_kind mismatch"))

    reordered = clone_payload(base)
    reordered["entries"][0], reordered["entries"][1] = reordered["entries"][1], reordered["entries"][0]
    rows.append(case("generated_order_mismatch", reordered, "generated Zig table order/content differs"))

    bad_source = SOURCE.read_text().replace('.{ .transform = 0, .copy_len = 5, .word_index = 35, .word = "about" },', '.{ .transform = 0, .copy_len = 5, .word_index = 35, .word = "aboutx" },', 1)
    rows.append(case("source_word_mismatch", clone_payload(base), "table word differs from source anchor", source_text=bad_source))

    with tempfile.TemporaryDirectory(prefix="vort-br-source-neg-common-") as td:
        rows.append(case("missing_brotli_common", clone_payload(base), "is not a Brotli common directory", brotli_common_dir=Path(td)))

    summary = {
        "schema": "vort.br_static_dictionary_source_audit_negative_smoke",
        "schema_version": 1,
        "ok": True,
        "case_count": len(rows),
        "cases": rows,
    }
    schemas_def = load_manifest()
    expected_case_names = set(schemas_def["vort.br_static_dictionary_source_audit_negative_smoke"]["item_enums"]["name"])
    actual_case_names = {str(row["name"]) for row in rows}
    missing_cases = sorted(expected_case_names - actual_case_names)
    extra_cases = sorted(actual_case_names - expected_case_names)
    if missing_cases or extra_cases:
        raise AssertionError(f"source-audit negative case coverage mismatch: missing={missing_cases!r} extra={extra_cases!r}")
    validate_value_against_manifest(summary, schemas_def)
    if args.summary:
        args.summary.parent.mkdir(parents=True, exist_ok=True)
        write_json(args.summary, summary)
    print(f"br_static_dictionary_source_audit_negative_smoke=ok cases={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
