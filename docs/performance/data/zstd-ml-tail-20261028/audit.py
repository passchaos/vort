#!/usr/bin/env python3
"""Verify the frozen tail-stop timing screen and reference decode records."""

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
        return {m.name: archive.extractfile(m).read() for m in archive if m.isfile()}


def audit_large():
    root = ROOT / "large-trained"
    manifest = json.loads((root / "manifest.json").read_text())
    path = root / "evidence.tar.xz"
    assert sha256(path.read_bytes()) == manifest["archive_sha256"]
    files = read_archive(path)
    assert set(files) == set(manifest["archive_member_sha256"])
    for name, digest in manifest["archive_member_sha256"].items():
        assert sha256(files[name]) == digest
    results = json.loads(files["results.json"])
    assert results["rounds"] == 1 and results["affinity"] == "2"
    assert results["summary"] == json.loads((root / "result.json").read_text())
    for index, config in enumerate(json.loads(files["configs.json"])):
        prefix = "runs/{}/".format(index)
        a, b = (json.loads(files[prefix + mode + ".json"]) for mode in ["baseline", "candidate"])
        assert a["profile"] == b["profile"]
        wire = files[prefix + "baseline.zst"]
        assert wire == files[prefix + "candidate.zst"]
        data = files["inputs/" + Path(config["input"]).name]
        assert sha256(data) == config["input_sha256"] == a["input_sha256"] == b["input_sha256"]
        assert sha256(wire) == a["wire_sha256"] == b["wire_sha256"]
        summary = results["summary"][index]
        assert a["ordinary_ns"] == summary["baseline_ns"] and b["ordinary_ns"] == summary["candidate_ns"]
        assert b["ordinary_ns"] / a["ordinary_ns"] == summary["candidate_over_baseline"]
        if config["dictionary"]:
            dictionary = files["inputs/" + Path(config["dictionary"]).name]
            assert sha256(dictionary) == config["dictionary_sha256"]
            assert summary["dictionary_sequences"] == (78 if config["strategy"] == "btopt" else 87)
    reference_bytes = (root / "reference-decode.json").read_bytes()
    assert sha256(reference_bytes) == manifest["reference_decode_sha256"]
    reference = json.loads(reference_bytes)
    assert reference["version_number"] == 10600 and len(reference["rows"]) == 8
    for row in reference["rows"]:
        assert sha256(files[row["wire"]]) == row["wire_sha256"]
    return len(reference["rows"])


def audit_interop():
    manifest = json.loads((ROOT / "interoperability-manifest.json").read_text())
    path = ROOT / "interoperability.tar.xz"
    assert sha256(path.read_bytes()) == manifest["archive_sha256"]
    files = read_archive(path)
    assert set(files) == set(manifest["archive_member_sha256"])
    for name, digest in manifest["archive_member_sha256"].items():
        assert sha256(files[name]) == digest
    for name, entry in manifest["campaigns"].items():
        path = name + ("/report.json" if name == "hq" else "/hq-search-report.json")
        report = json.loads(files[path])
        assert sha256(files[path]) == entry["report_sha256"]
        assert report["status"] == "ok" and len(report["rows"]) == entry["rows"]
        assert report["source_sha256"] == report["source_after_sha256"]
    return sum(entry["rows"] for entry in manifest["campaigns"].values())


def audit_current():
    record = json.loads((ROOT / "current-validation.json").read_text())
    assert len(record["runs"]) == 9
    assert all(run["exit_code"] == 0 for run in record["runs"].values())
    check_bytes = lzma.decompress((ROOT / "check-report.txt.xz").read_bytes())
    assert sha256(check_bytes) == record["check_report_raw_sha256"]
    assert b"Build Summary: 210/210 steps succeeded" in check_bytes
    path = ROOT / "source-contracts.tar.xz"
    assert sha256(path.read_bytes()) == record["source_contracts_archive_sha256"]
    files = read_archive(path)
    assert set(files) == set(record["current_source_sha256"])
    for name, digest in record["current_source_sha256"].items():
        assert sha256(files[name]) == digest
    wasm = lzma.decompress((ROOT / "standalone-wasi.wasm.xz").read_bytes())
    wasm_report = next(json.loads(line) for line in record["runs"]["wasm"]["output"].splitlines() if line.startswith('{"target":'))
    assert sha256(wasm) == wasm_report["wasm_sha256"] and wasm_report["exit_code"] == 0
    assert sha256((ROOT / "standalone-wasi-runner.js").read_bytes()) == record["wasi_runner_sha256"]
    return len(record["runs"])


def main():
    manifest = json.loads((ROOT / "manifest.json").read_text())
    archive = ROOT / "screen.tar.xz"
    assert sha256(archive.read_bytes()) == manifest["screen_archive_sha256"]
    files = read_archive(archive)
    assert set(files) == set(manifest["archive_member_sha256"])
    for name, digest in manifest["archive_member_sha256"].items():
        assert sha256(files[name]) == digest, name
    compressed = (ROOT / "results.json.xz").read_bytes()
    assert sha256(compressed) == manifest["results_compressed_sha256"]
    assert lzma.decompress(compressed) == files["results.json"]
    results = json.loads(files["results.json"])
    assert json.loads(files["compile-terminal.json"])["exit_code"] == 0
    baseline = read_archive(ROOT / manifest["shared_baseline_source"])
    edge_path = "src/zstd/match/hq_parser/search_edges.zig"
    before = baseline[edge_path]
    needle = b"                        const lower: usize = base;\n"
    assert before.count(needle) == 1
    after = before.replace(needle, needle + b"                        if (lower >= maximum) break;\n")
    assert after == files["candidate-source/" + edge_path]
    inputs = read_archive(ROOT / manifest["shared_inputs"])
    pairs = 0
    for summary in results["summary"]:
        ratios = []
        input_bytes = inputs[summary["case"] + "-4096"]
        for rd in range(2):
            prefix = "runs/{}/{}-{}/".format(rd, summary["case"], summary["strategy"])
            a = json.loads(files[prefix + "baseline.json"])
            b = json.loads(files[prefix + "candidate.json"])
            wire = files[prefix + "baseline.zst"]
            assert wire == files[prefix + "candidate.zst"]
            assert a["profile"] == b["profile"]
            assert a["input_sha256"] == b["input_sha256"] == sha256(input_bytes)
            assert a["wire_sha256"] == b["wire_sha256"] == summary["wire_sha256"] == sha256(wire)
            assert len(wire) == summary["wire_bytes"]
            assert a["ordinary_ns"] == summary["baseline_ns"][rd]
            assert b["ordinary_ns"] == summary["candidate_ns"][rd]
            assert a["native_decode_verified"] and b["native_decode_verified"]
            ratios.append(b["ordinary_ns"] / a["ordinary_ns"])
            pairs += 1
        assert ratios == summary["paired_ratios"]
        assert statistics.median(summary["candidate_ns"]) / statistics.median(summary["baseline_ns"]) == summary["median_ratio"]
    reference_bytes = (ROOT / "reference-decode.json").read_bytes()
    assert sha256(reference_bytes) == manifest["reference_decode_sha256"]
    reference = json.loads(reference_bytes)
    assert reference["version_number"] == 10600 and reference["reference_decodes_passed"] == 24
    for row in reference["rows"]:
        assert sha256(files[row["wire"]]) == row["wire_sha256"]
        assert row["decoded_bytes"] == 4096
    assert pairs == 12 and len(reference["rows"]) == 24
    large_reference_records = audit_large()
    interop_groups = audit_interop()
    terminals = audit_current()
    print(json.dumps({"wire_and_profile_pairs_verified": pairs + 4, "reference_decode_records_verified": 24 + large_reference_records, "bidirectional_interop_groups_verified": interop_groups, "current_terminal_records_verified": terminals, "single_line_source_change_verified": True}, indent=2))


if __name__ == "__main__":
    main()
