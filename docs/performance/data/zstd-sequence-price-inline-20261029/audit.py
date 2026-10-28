#!/usr/bin/env python3
"""Verify exact inline pricing source and ordinary measurements."""
import hashlib
import json
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
    path = ROOT / manifest["shared_baseline"]
    assert sha256(path.read_bytes()) == manifest["baseline_sha256"]
    baseline = read_archive(path)
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
    price_path = "src/zstd/match/hq_parser/prices.zig"
    original = baseline[price_path]
    expected = original.replace(b"pub fn sequencePrice(", b"pub inline fn sequencePrice(")
    assert original.count(b"pub fn sequencePrice(") == 1
    assert sha256(original) == manifest["baseline_prices_sha256"]
    assert sha256(expected) == manifest["candidate_prices_sha256"]
    assert screen["candidate-source/" + price_path] == expected
    result = json.loads(screen["results.json"])
    assert result["summary"] == json.loads((ROOT / "summary.json").read_text())
    assert result["binary_sha256"] == manifest["binary_sha256"]
    pairs = 0
    for summary in result["summary"]:
        ratios = []
        for rd in range(2):
            prefix = "runs/{}/{}-{}/".format(rd, summary["case"], summary["strategy"])
            a, b = (json.loads(screen[prefix + mode + ".json"]) for mode in ["baseline", "candidate"])
            wire = screen[prefix + "baseline.zst"]
            assert wire == screen[prefix + "candidate.zst"] and a["profile"] == b["profile"]
            assert sha256(wire) == summary["wire_sha256"] and len(wire) == summary["wire_bytes"]
            assert a["input_sha256"] == b["input_sha256"] == sha256(inputs[summary["case"] + "-4096"])
            assert a["ordinary_ns"] == summary["baseline_ns"][rd]
            assert b["ordinary_ns"] == summary["candidate_ns"][rd]
            ratios.append(b["ordinary_ns"] / a["ordinary_ns"])
            pairs += 1
        assert ratios == summary["paired_ratios"]
        assert statistics.median(summary["candidate_ns"]) / statistics.median(summary["baseline_ns"]) == summary["median_ratio"]
    reference_bytes = (ROOT / "reference-decode.json").read_bytes()
    assert sha256(reference_bytes) == manifest["reference_decode_sha256"]
    reference = json.loads(reference_bytes)
    assert reference["wire_count"] == 24 and reference["version_number"] == 10600
    for row in reference["rows"]:
        assert sha256(screen[row["wire"]]) == row["wire_sha256"]
    from validation_audit import audit
    details = audit(ROOT, expected)
    print(json.dumps({"ordinary_wire_profile_pairs": pairs, "reference_wire_records": 24,
                      "price_body_unchanged": True, **details}, indent=2))


if __name__ == "__main__":
    main()
