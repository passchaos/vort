#!/usr/bin/env python3
"""Audit independent ML-loop source/clock/ordered-trace evidence."""
import hashlib
import json
import statistics
import subprocess
import sys
import tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.dont_write_bytecode = True


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def archive_files(path):
    with tarfile.open(path) as archive:
        return {m.name: archive.extractfile(m).read() for m in archive if m.isfile()}


def verify_pairs(files, inputs):
    result = json.loads(files["results.json"])
    assert len(result["rows"]) == 24 and len(result["summary"]) == 6
    count = 0
    for summary in result["summary"]:
        ratios = []
        for rd in range(2):
            prefix = "runs/{}/{}-{}/".format(rd, summary["case"], summary["strategy"])
            a, b = (json.loads(files[prefix + mode + ".json"]) for mode in ["baseline", "candidate"])
            wire = files[prefix + "baseline.zst"]
            assert wire == files[prefix + "candidate.zst"] and a["profile"] == b["profile"]
            assert sha256(wire) == summary["wire_sha256"] and len(wire) == summary["wire_bytes"]
            data = inputs[summary["case"] + "-4096"]
            assert sha256(data) == a["input_sha256"] == b["input_sha256"]
            assert a["ordinary_ns"] == summary["baseline_ns"][rd] and b["ordinary_ns"] == summary["candidate_ns"][rd]
            ratios.append(b["ordinary_ns"] / a["ordinary_ns"])
            count += 1
        assert ratios == summary["paired_ratios"]
        assert statistics.median(summary["candidate_ns"]) / statistics.median(summary["baseline_ns"]) == summary["median_ratio"]
    return count


def main():
    manifest = json.loads((ROOT / "manifest.json").read_text())
    path = ROOT / "baseline-source.tar.xz"
    assert sha256(path.read_bytes()) == manifest["baseline_source_sha256"]
    baseline = archive_files(path)
    assert set(baseline) == set(manifest["baseline_members"])
    for name, digest in manifest["baseline_members"].items():
        assert sha256(baseline[name]) == digest
    archives = {}
    for name, entry in manifest["archives"].items():
        path = ROOT / name
        assert sha256(path.read_bytes()) == entry["sha256"]
        files = archive_files(path)
        assert set(files) == set(entry["member_sha256"])
        for member, digest in entry["member_sha256"].items():
            assert sha256(files[member]) == digest
        archives[name] = files
    original = baseline["src/zstd/match/hq_parser/search_edges.zig"]
    expected = original.replace(b"for (prices.ml_bases, prices.ml_bits, 0..)",
        b"const start: usize = if (self.parameters.strategy == .btopt) 14 else 39;\n                    for (prices.ml_bases[start..], prices.ml_bits[start..], start..)")
    prefix = archives["prefix-start.tar.xz"]
    # The exact source body is preserved; compare prefix selection and all
    # other bytes after ignoring only its added explanatory comments.
    actual = prefix["candidate-source/src/zstd/match/hq_parser/search_edges.zig"]
    strip = lambda b: b"".join(line for line in b.splitlines(keepends=True) if not line.lstrip().startswith(b"//"))
    assert strip(actual) == strip(expected)
    inputs = archives["inputs.tar.xz"]
    count = verify_pairs(prefix, inputs)
    strategy = archives["strategy-specialization.tar.xz"]
    text = original.decode()
    start = text.index("                    for (prices.ml_bases, prices.ml_bits, 0..)")
    end = text.index("\n                }\n            }\n        }", start)
    loop = text[start:end].replace("                    ", "            ")
    loop = loop.replace("if (self.parameters.strategy != .btopt and upper > exhaustive and upper < maximum)",
                        "if (upper_enabled and upper > exhaustive and upper < maximum)")
    replacement = """                    if (self.parameters.strategy == .btopt)
                        try self.sampleRanges(false, position, slot, node, maximum, choice)
                    else
                        try self.sampleRanges(true, position, slot, node, maximum, choice);"""
    expected = text[:start] + replacement + text[end:]
    helper = """
        inline fn sampleRanges(self: *Self, comptime upper_enabled: bool, position: usize, slot: usize, node: Node, maximum: usize, choice: rep.Choice) !void {
            const exhaustive: usize = if (upper_enabled) 64 else 16;
""" + loop + "\n        }\n"
    at = expected.index("\n        fn extend(")
    expected = expected[:at] + helper + expected[at:]
    assert expected.encode() == strategy["candidate/src/zstd/match/hq_parser/search_edges.zig"]
    count += verify_pairs(strategy, inputs)
    contracts = archives["prefix-contracts.tar.xz"]
    validation = json.loads(contracts["validation.json"])
    assert all(r["exit_code"] == 0 and r["passed"] == r["total"] == 7 for r in validation["runs"])
    for member, digest in json.loads(contracts["source_hashes.json"]).items():
        assert sha256(contracts[member]) == digest
    reference_bytes = (ROOT / "reference-decode.json").read_bytes()
    assert sha256(reference_bytes) == manifest["reference_decode_sha256"]
    reference = json.loads(reference_bytes)
    assert reference["wire_count"] == 48 and reference["version_number"] == 10600
    for row in reference["rows"]:
        assert sha256(archives[row["shape"] + ".tar.xz"][row["wire"]]) == row["wire_sha256"]
        assert row["decoded_bytes"] == 4096
    guard = subprocess.run([sys.executable, str(ROOT / "guard_validation_audit.py")],
                           capture_output=True, text=True)
    assert guard.returncode == 0, guard.stdout + guard.stderr
    print(json.dumps({"wire_profile_pairs_verified": count + 12, "reference_decodes_verified": 72,
                      "prefix_contract_target_records": len(validation["runs"]),
                      "guard_contract_target_records": 3,
                      "baseline_source_members_verified": len(baseline)}, indent=2))


if __name__ == "__main__":
    main()
