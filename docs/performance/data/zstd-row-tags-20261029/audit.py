#!/usr/bin/env python3
"""Audit frozen exact row-tag insertion measurements and source identities."""
import hashlib
import json
import lzma
import statistics
import sys
import tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.dont_write_bytecode = True


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def read_archive(path):
    with tarfile.open(path) as archive:
        return {m.name: archive.extractfile(m).read() for m in archive if m.isfile()}


def main():
    manifest = json.loads((ROOT / "manifest.json").read_text())
    baseline_path = ROOT / manifest["shared_baseline"]
    assert sha256(baseline_path.read_bytes()) == manifest["shared_baseline_sha256"]
    baseline = read_archive(baseline_path)
    assert set(baseline) == set(manifest["baseline_source_sha256"])
    for name, digest in manifest["baseline_source_sha256"].items():
        assert sha256(baseline[name]) == digest
    archives = {}
    for name, entry in manifest["archives"].items():
        path = ROOT / name
        assert sha256(path.read_bytes()) == entry["sha256"]
        files = read_archive(path)
        assert set(files) == set(entry["member_sha256"])
        for member, digest in entry["member_sha256"].items():
            assert sha256(files[member]) == digest
        archives[name] = files
    screen = archives["ordinary-screen.tar.xz"]
    inputs = archives["inputs.tar.xz"]
    result_bytes = lzma.decompress((ROOT / "results.json.xz").read_bytes())
    assert result_bytes == screen["results.json"]
    result = json.loads(result_bytes)
    assert result["binary_sha256"] == manifest["binary_sha256"]
    for path in manifest["measured_source_changes"]:
        assert screen["candidate/" + path] != baseline[path]
    assert manifest["measured_source_additions"] == ["src/zstd/match/hq_parser/row_tags.zig"]
    pairs = 0
    for summary in result["summary"]:
        ratios = []
        data = inputs[summary["case"] + "-4096"]
        for rd in range(2):
            prefix = "runs/{}/{}-{}/".format(rd, summary["case"], summary["strategy"])
            a, b = (json.loads(screen[prefix + mode + ".json"]) for mode in ["baseline", "candidate"])
            wire = screen[prefix + "baseline.zst"]
            assert wire == screen[prefix + "candidate.zst"]
            assert sha256(wire) == summary["wire_sha256"] and len(wire) == summary["wire_bytes"]
            assert a["input_sha256"] == b["input_sha256"] == sha256(data)
            ap = {k: v for k, v in a["profile"].items() if k != "peak_working_memory"}
            bp = {k: v for k, v in b["profile"].items() if k != "peak_working_memory"}
            assert ap == bp
            assert b["profile"]["peak_working_memory"] - a["profile"]["peak_working_memory"] == 65552
            assert a["ordinary_ns"] == summary["baseline_ns"][rd]
            assert b["ordinary_ns"] == summary["candidate_ns"][rd]
            ratios.append(b["ordinary_ns"] / a["ordinary_ns"])
            pairs += 1
        assert ratios == summary["paired_ratios"]
        assert statistics.median(summary["candidate_ns"]) / statistics.median(summary["baseline_ns"]) == summary["median_ratio"]
    reference_bytes = (ROOT / "reference-decode.json").read_bytes()
    assert sha256(reference_bytes) == manifest["reference_decode_sha256"]
    reference = json.loads(reference_bytes)
    assert reference["version_number"] == 10600 and reference["wire_count"] == 24
    for row in reference["rows"]:
        assert sha256(screen[row["wire"]]) == row["sha256"] and row["decoded_bytes"] == 4096
    from validation_audit import audit
    extra = audit(ROOT)
    print(json.dumps({"baseline_source_files_verified": len(baseline), "wire_profile_pairs_verified": pairs,
                      "reference_decode_records_verified": 24, "exact_peak_delta_bytes": 65552,
                      **extra}, indent=2))


if __name__ == "__main__":
    main()
