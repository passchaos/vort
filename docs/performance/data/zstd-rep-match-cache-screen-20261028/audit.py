#!/usr/bin/env python3
"""Recompute frozen cache measurements and actual-work accounting."""

import hashlib
import json
import statistics
import tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
WORK_FIELDS = {"rep_probes", "byte_comparisons", "rep_match_reuses"}


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def files(path):
    with tarfile.open(path) as archive:
        return {m.name: archive.extractfile(m).read() for m in archive if m.isfile()}


def main():
    manifest = json.loads((ROOT / "manifest.json").read_text())
    baseline_path = ROOT / manifest["baseline_source_archive"]
    assert sha256(baseline_path.read_bytes()) == manifest["baseline_source_sha256"]
    baseline = files(baseline_path)
    assert set(baseline) == set(manifest["baseline_source_member_sha256"])
    for name, digest in manifest["baseline_source_member_sha256"].items():
        assert sha256(baseline[name]) == digest
    archives = {}
    for name, entry in manifest["archives"].items():
        path = ROOT / name
        assert sha256(path.read_bytes()) == entry["sha256"]
        content = files(path)
        assert set(content) == set(entry["member_sha256"])
        for member, digest in entry["member_sha256"].items():
            assert sha256(content[member]) == digest
        archives[name] = content
    inputs = archives["inputs.tar.xz"]
    ordinary_pairs = 0
    for shape in ["outlined", "inline"]:
        content = archives[shape + "-screen.tar.xz"]
        result = json.loads(content["results.json"])
        assert result["source_commit"] == manifest["revision"]
        assert len(result["rows"]) == 24 and len(result["summary"]) == 6
        assert result["binary_sha256"] == manifest["experiments"][shape]["binary_sha256"]
        original = baseline["src/zstd/match/hq_parser/dp.zig"].decode()
        expected = original.replace("const PriceBudget =", 'const RepeatMatchCache = @import("repeat_match_cache.zig").Cache;\nconst PriceBudget =', 1)
        expected = expected.replace("    const width = beamWidth(parameters.strategy);\n    const layout", "    const width = beamWidth(parameters.strategy);\n    var repeat_cache = RepeatMatchCache.init(source);\n    const layout", 1)
        expected = expected.replace('                    if (parameters.profile) |profile| profile.add("rep_probes", 1);\n                    const length = resources.matchLength(source, global, distance, maximum, parameters.profile);', "                    const length = repeat_cache.matchLength(global, distance, maximum, parameters.profile);")
        assert expected.encode() == content["candidate/src/zstd/match/hq_parser/dp.zig"]
        cache = content["candidate/src/zstd/match/hq_parser/repeat_match_cache.zig"]
        other = archives[("inline" if shape == "outlined" else "outlined") + "-screen.tar.xz"]["candidate/src/zstd/match/hq_parser/repeat_match_cache.zig"]
        assert cache.replace(b"pub inline fn", b"pub fn") == other.replace(b"pub inline fn", b"pub fn")
        for summary in result["summary"]:
            data = inputs[summary["case"] + "-4096"]
            ratios = []
            for rd in range(2):
                prefix = "runs/{}/{}-{}/".format(rd, summary["case"], summary["strategy"])
                a, b = (json.loads(content[prefix + mode + ".json"]) for mode in ["baseline", "candidate"])
                wire = content[prefix + "baseline.zst"]
                assert wire == content[prefix + "candidate.zst"]
                assert sha256(wire) == summary["wire_sha256"] and len(wire) == summary["wire_bytes"]
                assert a["input_sha256"] == b["input_sha256"] == sha256(data)
                ap = {k: v for k, v in a["profile"].items() if k not in WORK_FIELDS}
                bp = {k: v for k, v in b["profile"].items() if k not in WORK_FIELDS}
                assert ap == bp
                assert a["profile"]["rep_probes"] == b["profile"]["rep_probes"] + b["profile"]["rep_match_reuses"]
                assert b["profile"]["byte_comparisons"] <= a["profile"]["byte_comparisons"]
                assert a["ordinary_ns"] == summary["baseline_ns"][rd]
                assert b["ordinary_ns"] == summary["candidate_ns"][rd]
                ratios.append(b["ordinary_ns"] / a["ordinary_ns"])
                ordinary_pairs += 1
            assert ratios == summary["paired_ratios"]
            assert statistics.median(summary["candidate_ns"]) / statistics.median(summary["baseline_ns"]) == summary["median_ratio"]
    diagnostic = json.loads(archives["reuse-diagnostic.tar.xz"]["summary.json"])
    for case in diagnostic["cases"]:
        assert case["baseline_wire_equal"] and case["baseline_profile_equal"] and case["known_output_hash_equal"]
        assert case["logical_rep_probes"] == case["potential_cachemiss_probes"] + case["potential_cachehit_probes"]
        assert case["hit_fraction"] == case["potential_cachehit_probes"] / case["logical_rep_probes"]
        assert case["potential_avoided_share_of_actual_profile_bytes"] == case["potential_avoided_rep_comparison_bytes"] / case["actual_profile_comparison_bytes"]
    raw_reference = (ROOT / "reference-decode.json").read_bytes()
    assert sha256(raw_reference) == manifest["reference_decode_sha256"]
    reference = json.loads(raw_reference)
    assert reference["reference_decodes_passed"] == 48 and reference["version_number"] == 10600
    for row in reference["rows"]:
        assert sha256(archives[row["shape"] + "-screen.tar.xz"][row["wire"]]) == row["wire_sha256"]
        assert row["decoded_bytes"] == 4096
    contracts = archives["frozen-contracts.tar.xz"]
    raw_contracts = (ROOT / "contract-validation.json").read_bytes()
    assert sha256(raw_contracts) == manifest["contract_validation_sha256"]
    assert raw_contracts == contracts["validation.json"]
    contract_record = json.loads(raw_contracts)
    assert len(contract_record["runs"]) == 3
    assert all(r["exit_code"] == 0 and r["tests_passed"] == 22 for r in contract_record["runs"])
    for member, digest in json.loads(contracts["source_hashes.json"]).items():
        assert sha256(contracts[member]) == digest
    assert sha256(contracts["src/zstd/match/hq_parser/dp_reference.zig"]) == contract_record["frozen_dp_sha256"]
    assert sha256(contracts["src/zstd/match/hq_parser/resources_reference.zig"]) == contract_record["frozen_resources_sha256"]
    print(json.dumps({"ordinary_wire_and_non_work_profile_pairs": ordinary_pairs,
                      "reuse_diagnostic_cases": len(diagnostic["cases"]),
                      "actual_rep_probe_accounting_verified": True, "source_scope_verified": True,
                      "reference_decode_records_verified": len(reference["rows"]),
                      "contract_target_terminal_records": len(contract_record["runs"])}, indent=2))


if __name__ == "__main__":
    main()
