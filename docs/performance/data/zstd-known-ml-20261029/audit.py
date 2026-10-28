#!/usr/bin/env python3
"""Verify frozen known-ML pricing source, timing and correctness evidence."""
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


def pairs(files, summaries, rounds, large=False):
    count = 0
    for index, summary in enumerate(summaries):
        ratios = []
        for rd in range(rounds):
            if large:
                prefix = "runs/{}/".format(index) if rounds == 1 else "runs/{}/{}/".format(rd, index)
            else:
                prefix = "runs/{}/{}-{}/".format(rd, summary["case"], summary["strategy"])
            a, b = (json.loads(files[prefix + mode + ".json"]) for mode in ["baseline", "candidate"])
            wire = files[prefix + "baseline.zst"]
            assert wire == files[prefix + "candidate.zst"]
            assert a["profile"] == b["profile"]
            assert sha256(wire) == summary["wire_sha256"] and len(wire) == summary["wire_bytes"]
            ratio = b["ordinary_ns"] / a["ordinary_ns"]
            if rounds == 1:
                assert a["ordinary_ns"] == summary["baseline_ns"] and b["ordinary_ns"] == summary["candidate_ns"]
                assert ratio == summary["candidate_over_baseline"]
            else:
                assert a["ordinary_ns"] == summary["baseline_ns"][rd] and b["ordinary_ns"] == summary["candidate_ns"][rd]
                ratios.append(ratio)
            count += 1
        if rounds != 1:
            assert ratios == summary["paired_ratios"]
            assert statistics.median(summary["candidate_ns"]) / statistics.median(summary["baseline_ns"]) == summary["median_ratio"]
    return count


def main():
    manifest = json.loads((ROOT / "manifest.json").read_text())
    path = ROOT / "baseline-source.tar.xz"
    assert sha256(path.read_bytes()) == manifest["baseline_archive_sha256"]
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
    result = json.loads(screen["results.json"])
    assert result["binary_sha256"] == manifest["binary_sha256"]
    assert result["summary"] == json.loads((ROOT / "summary.json").read_text())
    count = pairs(screen, result["summary"], 2)
    for row in result["rows"]:
        data = archives["inputs.tar.xz"][row["case"] + "-4096"]
        assert len(data) == row["input_bytes"] and sha256(data) == row["input_sha256"]
    overlap = archives["large-overlap.tar.xz"]
    result = json.loads(overlap["results.json"])
    assert len(result["rows"]) == 12
    count += pairs(overlap, result["summary"], 1, True)
    followup = archives["large-followup.tar.xz"]
    result = json.loads(followup["results.json"])
    assert len(result["rows"]) == 24 and all(c["exit_code"] == 0 for c in result["commands"])
    count += pairs(followup, result["summary"], 2, True)
    configs = json.loads(overlap["configs.json"])
    for files in [overlap, followup]:
        rows = json.loads(files["results.json"])["rows"]
        for row in rows:
            config = configs[row["index"]]
            data = overlap["inputs/" + Path(config["input"]).name]
            assert len(data) == row["input_bytes"] and sha256(data) == row["input_sha256"] == config["input_sha256"]
            if config["dictionary"]:
                dictionary = overlap["inputs/" + Path(config["dictionary"]).name]
                assert sha256(dictionary) == config["dictionary_sha256"]
    correction = json.loads(followup["affinity-scope-correction.json"])
    assert not correction["high_cpu_processor2_observations"]
    assert any(cpu not in (4, 6) for cpu in correction["reported_zig_processors"])
    small_reference = (ROOT / "reference-decode.json").read_bytes()
    assert sha256(small_reference) == manifest["reference_decode_sha256"]
    small = json.loads(small_reference)
    assert small["wire_count"] == 24 and small["version_number"] == 10600
    for row in small["rows"]:
        assert sha256(screen[row["wire"]]) == row["wire_sha256"]
    large_reference = (ROOT / "large-reference-decode.json").read_bytes()
    assert sha256(large_reference) == manifest["large_reference_decode_sha256"]
    large = json.loads(large_reference)
    assert large["wire_count"] == 36 and large["version_number"] == 10600
    for row in large["rows"]:
        assert sha256(archives[row["epoch"] + ".tar.xz"][row["wire"]]) == row["wire_sha256"]
    contracts = archives["snapshot-contracts.tar.xz"]
    raw = (ROOT / "snapshot-validation.json").read_bytes()
    assert sha256(raw) == manifest["snapshot_validation_sha256"] and raw == contracts["validation.json"]
    snapshot = json.loads(raw)
    assert all(run["exit_code"] == 0 and run["passed"] == run["total"] == 7 for run in snapshot["runs"])
    for member, digest in json.loads(contracts["source_hashes.json"]).items():
        assert sha256(contracts[member]) == digest
    from validation_audit import audit
    extra = audit(ROOT, archives)
    print(json.dumps({"wire_profile_pairs": count, "independent_reference_decodes": 60,
                      "snapshot_contract_targets": 3, **extra}, indent=2))


if __name__ == "__main__":
    main()
