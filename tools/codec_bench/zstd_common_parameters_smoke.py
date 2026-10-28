#!/usr/bin/env python3
"""Reject malformed common-HQ claims through the shared evidence validator."""

from __future__ import annotations

import argparse
import copy
import csv
import json
from pathlib import Path
import tempfile

from sample_gate import EvidenceError, validate


def negative_contracts(report: dict, manifest: dict, csv_rows: list[dict]) -> int:
    validate(report, manifest, csv_rows=csv_rows, require_explicit_references=True)
    mutations = [
        ("preset claim", ("comparison_mode",), "level_preset"),
        ("primary API", ("api",), "level_policy"),
        ("reference API", ("reference", "api"), "ZSTD_compress"),
        ("reference preset", ("reference", "internal_parameters"), "library_default_level_preset"),
        ("reference called effective", ("reference", "internal_parameters"), "effective_parameters"),
        ("accepted controls", ("requested_controls_match",), False),
        ("exact search claim", ("search_budget_scope",), "identical actual tree/state visits"),
        ("missing search scope", ("search_budget_scope",), None),
        ("reference strategy", ("reference", "requested_parameters", "strategy"), 1),
        ("reference window", ("reference", "requested_parameters", "window_log"), 10),
        ("reference search", ("reference", "requested_parameters", "search_log"), 1),
        ("reference minimum", ("reference", "requested_parameters", "min_match"), 5),
        ("reference nice", ("reference", "requested_parameters", "target_length"), 17),
        ("reference checksum", ("reference", "requested_parameters", "checksum"), 2),
        ("reference FCS", ("reference", "requested_parameters", "content_size"), 2),
        ("reference worker", ("reference", "requested_parameters", "workers"), 1),
        ("reference dictionary flag", ("reference", "requested_parameters", "dict_id"), 0),
        ("reference LDM", ("reference", "requested_parameters", "long_distance_matching"), 1),
        ("reference boolean integer", ("reference", "requested_parameters", "search_log"), True),
        ("requested strategy", ("requested_strategy",), "fast"),
        ("requested acceleration", ("requested_fast_acceleration",), 1),
        ("requested selection", ("requested_native_selection",), "fast_compressed"),
        ("primary acceleration", ("resolved_primary", "fast_acceleration"), 1),
        ("primary selection", ("resolved_primary", "selection"), "auto"),
        ("nonnatural block", ("reference_block_ceiling",), 4096),
        ("native budget", ("resolved_primary", "hq", "search_depth"), 65),
        ("native policy", ("resolved_primary", "hq", "match_lengths"), "complete"),
        ("missing profile", ("vort_profile",), None),
        ("unavailable profile", ("vort_profile", "available"), False),
        ("profile strategy", ("vort_profile", "resolved_strategy"), "fast"),
        ("profile depth", ("vort_profile", "effective_hq_search_depth"), 65),
        ("dictionary scope", ("dictionary_preparation_timed",), not report["rows"][0]["settings"]["dictionary_preparation_timed"]),
    ]
    for label, path, value in mutations:
        changed = copy.deepcopy(report)
        target = changed["rows"][0]["settings"]
        for key in path[:-1]:
            target = target[key]
        target[path[-1]] = value
        expect_rejected(changed, manifest, csv_rows, label)
    extra = 0
    for implementation in (None, "reference"):
        changed = copy.deepcopy(report)
        settings = changed["rows"][0]["settings"]
        header = settings["wire_header"] if implementation is None else settings[implementation]["wire_header"]
        header["content_checksum"] = not header["content_checksum"]
        expect_rejected(changed, manifest, csv_rows, "actual checksum")
        changed = copy.deepcopy(report)
        settings = changed["rows"][0]["settings"]
        header = settings["wire_header"] if implementation is None else settings[implementation]["wire_header"]
        header["content_size"] = None if header["content_size"] is not None else changed["rows"][0]["input_bytes"]
        expect_rejected(changed, manifest, csv_rows, "actual FCS")
        extra += 2
    changed = copy.deepcopy(report)
    del changed["rows"][0]["settings"]["reference"]["requested_parameters"]["workers"]
    expect_rejected(changed, manifest, csv_rows, "missing requested parameter")
    return len(mutations) + extra + 1


def dictionary_negative_contracts(report: dict, manifest: dict, csv_rows: list[dict]) -> int:
    validate(report, manifest, csv_rows=csv_rows, require_explicit_references=True)
    changed = copy.deepcopy(report)
    settings = changed["rows"][0]["settings"]
    sha = settings["dictionary_sha256"]
    settings["dictionary_sha256"] = ("1" if sha[0] == "0" else "0") + sha[1:]
    expect_rejected(changed, manifest, csv_rows, "forged dictionary SHA")
    missing = copy.deepcopy(manifest)
    del missing["dictionary_sets"]
    expect_rejected(report, missing, csv_rows, "missing frozen dictionary collection")
    forged = copy.deepcopy(manifest)
    forged["dictionary_sets"][0]["dictionary_sha256"] = settings["dictionary_sha256"]
    expect_rejected(report, forged, csv_rows, "forged manifest dictionary SHA")
    with tempfile.TemporaryDirectory(prefix="vort-common-hq-dictionary-negative-") as temporary:
        modified = copy.deepcopy(manifest)
        original = Path(modified["dictionary_sets"][0]["frozen_path"]).read_bytes()
        path = Path(temporary) / "changed.dict"
        path.write_bytes(bytes([original[0] ^ 1]) + original[1:] if original else b"changed")
        modified["dictionary_sets"][0]["frozen_path"] = str(path)
        expect_rejected(report, modified, csv_rows, "changed frozen dictionary file")
    return 4


def level_zero_negative_contracts(report: dict, manifest: dict, csv_rows: list[dict]) -> int:
    validate(report, manifest, csv_rows=csv_rows, require_explicit_references=True)
    assert report["rows"][0]["settings"]["level"] == 0, "level-zero fixture required"
    for field in ("requested_parameters", None):
        changed = copy.deepcopy(report)
        reference = changed["rows"][0]["settings"]["reference"]
        target = reference[field] if field else reference
        target["level"] = 0
        expect_rejected(changed, manifest, csv_rows, "level-zero reference omitted public default normalization")
    return 2


def expect_rejected(report: dict, manifest: dict, csv_rows: list[dict], label: str) -> None:
    try:
        validate(report, manifest, csv_rows=csv_rows, require_explicit_references=True)
    except EvidenceError:
        return
    raise AssertionError(f"common HQ validator accepted {label}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--samples-json", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--csv", type=Path, required=True)
    args = parser.parse_args()
    with args.csv.open(newline="") as handle:
        rows = list(csv.DictReader(handle))
    report, manifest = json.loads(args.samples_json.read_text()), json.loads(args.manifest.read_text())
    count = negative_contracts(report, manifest, rows)
    if report["rows"][0]["settings"]["dictionary_kind"] is not None:
        count += dictionary_negative_contracts(report, manifest, rows)
    if report["rows"][0]["settings"]["level"] == 0:
        count += level_zero_negative_contracts(report, manifest, rows)
    print(f"zstd_common_parameters_smoke=ok invalid={count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
