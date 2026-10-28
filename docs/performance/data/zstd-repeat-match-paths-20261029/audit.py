#!/usr/bin/env python3
"""Verify separate repeat-match screens and exact actual-work accounting."""
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


def verify_pairs(files, excluded, large=False):
    result = json.loads(files["results.json"])
    assert len(result["rows"]) == (12 if large else 24)
    count = 0
    for index, summary in enumerate(result["summary"]):
        ratios = []
        for rd in range(1 if large else 2):
            prefix = "runs/{}/".format(index) if large else "runs/{}/{}-{}/".format(rd, summary["case"], summary["strategy"])
            a, b = (json.loads(files[prefix + mode + ".json"]) for mode in ["baseline", "candidate"])
            wire = files[prefix + "baseline.zst"]
            assert wire == files[prefix + "candidate.zst"]
            assert sha256(wire) == summary["wire_sha256"] and len(wire) == summary["wire_bytes"]
            assert a["input_sha256"] == b["input_sha256"]
            assert {k: v for k, v in a["profile"].items() if k not in excluded} == {k: v for k, v in b["profile"].items() if k not in excluded}
            if "rep_probes" in excluded:
                assert a["profile"]["rep_probes"] == b["profile"]["rep_probes"] + b["profile"]["rep_match_reuses"]
                assert b["profile"]["byte_comparisons"] <= a["profile"]["byte_comparisons"]
            if large:
                assert a["ordinary_ns"] == summary["baseline_ns"] and b["ordinary_ns"] == summary["candidate_ns"]
                assert b["ordinary_ns"] / a["ordinary_ns"] == summary["candidate_over_baseline"]
            else:
                assert a["ordinary_ns"] == summary["baseline_ns"][rd] and b["ordinary_ns"] == summary["candidate_ns"][rd]
                ratios.append(b["ordinary_ns"] / a["ordinary_ns"])
            count += 1
        if not large:
            assert ratios == summary["paired_ratios"]
            assert statistics.median(summary["candidate_ns"]) / statistics.median(summary["baseline_ns"]) == summary["median_ratio"]
    return count


def main():
    manifest = json.loads((ROOT / "manifest.json").read_text())
    path = ROOT / manifest["shared_baseline_archive"]
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
        assert set(files) == set(entry["members"])
        for member, digest in entry["members"].items():
            assert sha256(files[member]) == digest
        archives[name] = files
    inputs = archives["inputs.tar.xz"]
    pairs = 0
    exclusions = {"vector-mask-small": set(), "prefix-small": {"byte_comparisons"},
                  "assoc-firsttrue": {"byte_comparisons", "rep_probes", "rep_match_reuses"},
                  "assoc-lane-mask": {"byte_comparisons", "rep_probes", "rep_match_reuses"}}
    for name, excluded in exclusions.items():
        files = archives[name + ".tar.xz"]
        pairs += verify_pairs(files, excluded)
        for row in json.loads(files["results.json"])["rows"]:
            assert sha256(inputs[row["case"] + "-4096"]) == row["input_sha256"]
        directory = "candidate-source/" if name.startswith("assoc") else "candidate/"
        for member, digest in manifest["source_scopes"][name]["changed_baseline_files"].items():
            assert sha256(files[directory + member]) == digest and digest != sha256(baseline[member])
        if name.startswith("assoc"):
            member = "src/zstd/match/hq_parser/rep_match_cache.zig"
            assert sha256(files[directory + member]) == manifest["source_scopes"][name]["added_source_files"][member]
    resources = baseline["src/zstd/match/hq_parser/resources.zig"]
    vector = resources.replace(b'const std = @import("std");', b'const std = @import("std");\nconst builtin = @import("builtin");', 1)
    vector = vector.replace(b"            if (std.simd.firstTrue(a != b)) |mismatch| return length + offset + mismatch;", b"""            if (builtin.target.cpu.arch.endian() == .little) {
                const mismatches: u32 = @bitCast(a != b);
                if (mismatches != 0) return length + offset + @as(usize, @ctz(mismatches));
            } else if (std.simd.firstTrue(a != b)) |mismatch| return length + offset + mismatch;""")
    assert vector == archives["vector-mask-small.tar.xz"]["candidate/src/zstd/match/hq_parser/resources.zig"]
    prefix = resources.replace(b"        var offset: usize = 0;\n        while (available - offset >= 32)", b"""        var offset: usize = 0;
        if (available >= 32) {
            const difference = std.mem.readInt(u32, left[0..4], .little) ^
                std.mem.readInt(u32, right[0..4], .little);
            if (profile) |p| p.add("byte_comparisons", 4);
            if (difference != 0) return length + @as(usize, @ctz(difference) / 8);
        }
        while (available - offset >= 32)""")
    assert prefix == archives["prefix-small.tar.xz"]["candidate/src/zstd/match/hq_parser/resources.zig"]
    pairs += verify_pairs(archives["vector-mask-large.tar.xz"], set(), True)
    pairs += verify_pairs(archives["prefix-large.tar.xz"], {"byte_comparisons"}, True)
    for name in ["vector-mask-large", "prefix-large"]:
        data = archives[name + ".tar.xz"]
        configurations = json.loads(data["configs.json"])
        for row in json.loads(data["results.json"])["rows"]:
            config = configurations[row["index"]]
            assert sha256(data["inputs/" + Path(config["input"]).name]) == row["input_sha256"]
            if config["dictionary"]:
                assert sha256(data["inputs/" + Path(config["dictionary"]).name]) == config["dictionary_sha256"]
    before = json.loads(archives["assoc-firsttrue.tar.xz"]["results.json"])["rows"]
    after = json.loads(archives["assoc-lane-mask.tar.xz"]["results.json"])["rows"]
    keyed = lambda rows: {(r["case"], r["strategy"], r["round"], r["mode"]): r["profile"] for r in rows}
    assert keyed(before) == keyed(after)
    from validation_audit import audit
    extra = audit(ROOT, archives)
    print(json.dumps({"wire_profile_pairs_verified": pairs, "baseline_source_files_verified": len(baseline),
                      "actual_reuse_accounting_verified": True, **extra}, indent=2))


if __name__ == "__main__":
    main()
