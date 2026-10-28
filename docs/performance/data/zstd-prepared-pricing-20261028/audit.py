#!/usr/bin/env python3
"""Verify the frozen prepared-pricing evidence without running benchmarks."""

import hashlib
import json
import lzma
import statistics
import tarfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def read_archive(path):
    with tarfile.open(path) as archive:
        return {
            member.name: archive.extractfile(member).read()
            for member in archive
            if member.isfile()
        }


def audit_experiment(name, entry, baseline, inputs):
    members = read_archive(ROOT / (name + "-experiment.tar.xz"))
    expected = entry["archive_file_sha256"]
    assert set(members) == set(expected), name
    for path, digest in expected.items():
        assert sha256(members[path]) == digest, (name, path)

    changed = entry["changed_baseline_files"]
    added = entry["added_experiment_files"]
    assert changed == ["src/zstd/match/hq_parser/search_edges.zig"]
    assert added == [
        "src/prepared_price_contracts.zig",
        "src/zstd/match/hq_parser/prepared_sequence_price.zig",
    ]
    for path in changed:
        assert members["candidate/" + path] != baseline[path]

    for filename in [
        "source-provenance.json",
        "price-contracts-result.json", "hq-search-tests-result.json",
    ]:
        assert (ROOT / (name + "-" + filename)).read_bytes() == members[filename]
    compressed_results = (ROOT / (name + "-results.json.xz")).read_bytes()
    assert lzma.decompress(compressed_results) == members["results.json"]
    for filename in ["price-contracts-result.json", "hq-search-tests-result.json"]:
        assert json.loads(members[filename])["exit_code"] == 0

    results = json.loads(members["results.json"])
    assert results["source_commit"] == "bdae5ce7128e30fee20e20e16612844a818cf1ff"
    assert results["rounds"] == 2 and results["affinity"] == "2"
    assert results["binary_sha256"] == entry["binary_sha256"]
    assert len(results["rows"]) == 24 and len(results["summary"]) == 6
    pairs = 0
    for summary in results["summary"]:
        ratios = []
        input_bytes = inputs[summary["case"] + "-4096"]
        for rd in range(2):
            prefix = "runs/{}/{}-{}/".format(rd, summary["case"], summary["strategy"])
            a = json.loads(members[prefix + "baseline.json"])
            b = json.loads(members[prefix + "candidate.json"])
            assert a["profile"] == b["profile"]
            assert a["input_sha256"] == b["input_sha256"] == sha256(input_bytes)
            wire = members[prefix + "baseline.zst"]
            assert wire == members[prefix + "candidate.zst"]
            assert len(wire) == summary["wire_bytes"]
            assert sha256(wire) == summary["wire_sha256"]
            assert a["wire_sha256"] == b["wire_sha256"] == sha256(wire)
            assert a["ordinary_ns"] == summary["baseline_ns"][rd]
            assert b["ordinary_ns"] == summary["candidate_ns"][rd]
            for row in [a, b]:
                assert row["native_decode_verified"] and row["profiled_wire_equal"]
                assert row["optimize"] == "ReleaseFast"
                assert row["window_log"] == 15 and row["block_size_max"] == 32768
            ratios.append(b["ordinary_ns"] / a["ordinary_ns"])
            pairs += 1
        assert ratios == summary["paired_ratios"]
        median_ratio = (
            statistics.median(summary["candidate_ns"])
            / statistics.median(summary["baseline_ns"])
        )
        assert median_ratio == summary["median_ratio"]
    assert pairs == 12
    assert results["validation"] == entry["validation"]
    return pairs


def main():
    manifest = json.loads((ROOT / "manifest.json").read_text())
    for path, digest in manifest["archive_sha256"].items():
        assert sha256((ROOT / path).read_bytes()) == digest, path
    baseline = read_archive(ROOT / "baseline-source.tar.xz")
    expected = manifest["baseline_source_sha256"]
    assert set(baseline) == set(expected)
    for path, digest in expected.items():
        assert sha256(baseline[path]) == digest, path
    inputs = read_archive(ROOT / "inputs.tar.xz")
    for entry in json.loads((ROOT / "input-manifest.json").read_text()):
        data = inputs[Path(entry["path"]).name]
        assert len(data) == entry["input_bytes"] == 4096
        assert sha256(data) == entry["sha256"]
    pairs = sum(
        audit_experiment(name, entry, baseline, inputs)
        for name, entry in manifest["experiments"].items()
    )
    print(json.dumps({
        "archives_verified": len(manifest["archive_sha256"]),
        "baseline_files_verified": len(baseline),
        "complete_wire_and_profile_pairs_verified": pairs,
        "prototype_test_terminal_records_verified": 4,
    }, indent=2))


if __name__ == "__main__":
    main()
