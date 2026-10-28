#!/usr/bin/env python3
"""Check exact cost-first source, clocks, wire/profile and decoder records."""
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
    path = ROOT / "baseline-source.tar.xz"
    assert sha256(path.read_bytes()) == manifest["baseline_source_sha256"]
    baseline = read_archive(path)
    assert set(baseline) == set(manifest["baseline_source_members"])
    for name, digest in manifest["baseline_source_members"].items():
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
    original = baseline["src/zstd/match/hq_parser/row_tags.zig"]
    expected = original.replace(b"if (!state.less(candidate, old)) return false;", b"if (candidate.cost > old.cost or (candidate.cost == old.cost and !state.less(candidate, old))) return false;")
    expected = expected.replace(b"if (!state.less(candidate, row[replace])) return false;", b"if (candidate.cost > row[replace].cost or (candidate.cost == row[replace].cost and !state.less(candidate, row[replace]))) return false;")
    assert expected == screen["candidate/src/zstd/match/hq_parser/row_tags.zig"]
    result = json.loads(screen["results.json"])
    assert result["binary_sha256"] == manifest["binary_sha256"]
    assert result["summary"] == json.loads((ROOT / "summary.json").read_text())
    pairs = 0
    for summary in result["summary"]:
        ratios = []
        for rd in range(2):
            prefix = "runs/{}/{}-{}/".format(rd, summary["case"], summary["strategy"])
            a, b = (json.loads(screen[prefix + mode + ".json"]) for mode in ["baseline", "candidate"])
            wire = screen[prefix + "baseline.zst"]
            assert wire == screen[prefix + "candidate.zst"] and a["profile"] == b["profile"]
            assert sha256(wire) == summary["wire_sha256"]
            assert a["input_sha256"] == b["input_sha256"] == sha256(archives["inputs.tar.xz"][summary["case"] + "-4096"])
            assert a["ordinary_ns"] == summary["baseline_ns"][rd] and b["ordinary_ns"] == summary["candidate_ns"][rd]
            ratios.append(b["ordinary_ns"] / a["ordinary_ns"])
            pairs += 1
        assert ratios == summary["paired_ratios"]
        assert statistics.median(summary["candidate_ns"]) / statistics.median(summary["baseline_ns"]) == summary["median_ratio"]
    large = archives["large-trained.tar.xz"]
    result = json.loads(large["results.json"])
    assert result["rounds"] == 1 and len(result["rows"]) == 12
    assert result["summary"] == json.loads((ROOT / "large-summary.json").read_text())
    for index, summary in enumerate(result["summary"]):
        prefix = "runs/{}/".format(index)
        a, b = (json.loads(large[prefix + mode + ".json"]) for mode in ["baseline", "candidate"])
        wire = large[prefix + "baseline.zst"]
        assert wire == large[prefix + "candidate.zst"] and a["profile"] == b["profile"]
        assert sha256(wire) == summary["wire_sha256"]
        assert a["ordinary_ns"] == summary["baseline_ns"] and b["ordinary_ns"] == summary["candidate_ns"]
        assert b["ordinary_ns"] / a["ordinary_ns"] == summary["candidate_over_baseline"]
        pairs += 1
    reference_bytes = (ROOT / "reference-decode.json").read_bytes()
    assert sha256(reference_bytes) == manifest["reference_decode_sha256"]
    reference = json.loads(reference_bytes)
    assert reference["version_number"] == 10600 and reference["wire_count"] == 36
    for row in reference["rows"]:
        content = screen if row["epoch"] == "small" else large
        assert sha256(content[row["wire"]]) == row["wire_sha256"]
    from validation_audit import audit
    final = audit(ROOT)
    print(json.dumps({"cost_first_wire_profile_pairs": pairs, "reference_wire_records": 36,
                      "exact_candidate_source_verified": True, **final}, indent=2))


if __name__ == "__main__":
    main()
