#!/usr/bin/env python3
"""Check the frozen prepared-tag screen, contracts and ordinary CPU samples."""
import hashlib
import json
import math
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
    path = ROOT / "baseline-source.tar.xz"
    assert sha256(path.read_bytes()) == manifest["baseline_source_sha256"]
    baseline = read_archive(path)
    assert set(baseline) == set(manifest["baseline_members"])
    for name, digest in manifest["baseline_members"].items():
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
    results = json.loads(screen["results.json"])
    assert results["summary"] == json.loads((ROOT / "summary.json").read_text())
    assert results["binary_sha256"] == manifest["binary_sha256"]
    pairs = 0
    for summary in results["summary"]:
        ratios = []
        for rd in range(2):
            prefix = "runs/{}/{}-{}/".format(rd, summary["case"], summary["strategy"])
            a, b = (json.loads(screen[prefix + mode + ".json"]) for mode in ["baseline", "candidate"])
            wire = screen[prefix + "baseline.zst"]
            assert wire == screen[prefix + "candidate.zst"]
            assert a["profile"] == b["profile"]
            assert sha256(wire) == summary["wire_sha256"]
            assert a["input_sha256"] == b["input_sha256"] == sha256(inputs[summary["case"] + "-4096"])
            assert a["ordinary_ns"] == summary["baseline_ns"][rd]
            assert b["ordinary_ns"] == summary["candidate_ns"][rd]
            ratios.append(b["ordinary_ns"] / a["ordinary_ns"])
            pairs += 1
        assert ratios == summary["paired_ratios"]
        assert statistics.median(summary["candidate_ns"]) / statistics.median(summary["baseline_ns"]) == summary["median_ratio"]
    contracts = archives["frozen-contracts.tar.xz"]
    validation_bytes = (ROOT / "contract-validation.json").read_bytes()
    assert sha256(validation_bytes) == manifest["contract_validation_sha256"]
    assert validation_bytes == contracts["validation.json"]
    validation = json.loads(validation_bytes)
    assert len(validation["runs"]) == 3
    assert all(run["exit_code"] == 0 and run["passed"] == run["total"] == 9 for run in validation["runs"])
    for name, digest in json.loads(contracts["source_hashes.json"]).items():
        assert sha256(contracts[name]) == digest
    reference_bytes = (ROOT / "reference-decode.json").read_bytes()
    assert sha256(reference_bytes) == manifest["reference_decode_sha256"]
    reference = json.loads(reference_bytes)
    assert reference["wire_count"] == 24 and reference["version_number"] == 10600
    for row in reference["rows"]:
        assert sha256(screen[row["wire"]]) == row["sha256"]
    samples = archives["current-hotspots.tar.xz"]
    sampling_summary = json.loads(samples["sample-summary.json"])
    recordings = json.loads(samples["recordings.json"])
    sample_count = 0
    for summary, recording in zip(sampling_summary, recordings, strict=True):
        label = summary["label"]
        assert label == recording["label"] and recording["exit_code"] == 0
        report = json.loads(samples[label + ".stdout"])
        assert report == recording["report"]
        assert report["diagnostic_profile_calls"] == 0 and report["control_profile_null"]
        rows = [line.split(maxsplit=2) for line in samples[label + ".ip-period.txt"].decode().splitlines()]
        rows = [(int(period), int(ip, 16), symbol) for period, ip, symbol in rows]
        total = sum(period for period, _, _ in rows)
        assert len(rows) == summary["samples"] and total == summary["global_period"]
        sample_count += len(rows)
        for part in ["insert_parts", "extend_parts"]:
            for entry in summary[part].values():
                intervals = [(int(r["begin"], 16), int(r["end_exclusive"], 16)) for r in entry["segments"]]
                selected = [p for p, ip, _ in rows if any(start <= ip < end for start, end in intervals)]
                assert len(selected) == entry["samples"] and sum(selected) == entry["period"]
                assert math.isclose(100 * sum(selected) / total, entry["global_pct"], abs_tol=1e-12)
        for entry in summary["top10"]:
            period = sum(p for p, _, symbol in rows if symbol == entry["symbol"])
            assert math.isclose(100 * period / total, entry["global_pct"], abs_tol=1e-12)
    print(json.dumps({"wire_profile_pairs_verified": pairs, "reference_decodes_verified": 24,
                      "contract_target_terminal_records": 3, "ordinary_samples_verified": sample_count}, indent=2))


if __name__ == "__main__":
    main()
