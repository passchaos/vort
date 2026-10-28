"""Audit final source/platform and separate larger-input inline records."""
import hashlib
import json
import lzma
import tarfile


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def read_archive(path):
    with tarfile.open(path) as archive:
        return {m.name: archive.extractfile(m).read() for m in archive if m.isfile()}


def audit(root, expected_prices):
    validation = json.loads((root / "source-validation.json").read_text())
    path = root / "source-contracts.tar.xz"
    assert sha256(path.read_bytes()) == validation["source_archive_sha256"]
    files = read_archive(path)
    assert set(files) == set(validation["source_sha256"])
    for name, digest in validation["source_sha256"].items():
        assert sha256(files[name]) == digest
    assert files["src/zstd/match/hq_parser/prices.zig"] == expected_prices
    wasm = lzma.decompress((root / "standalone-wasi.wasm.xz").read_bytes())
    assert sha256(wasm) == validation["wasm_sha256"]
    assert sha256((root / "standalone-wasi-runner.js").read_bytes()) == validation["wasi_runner_sha256"]
    current = (root / "current-validation.json").read_bytes()
    assert sha256(current) == validation["current_validation_sha256"]
    records = json.loads(current)["runs"]
    assert len(records) == 9 and all(record["exit_code"] == 0 for record in records.values())
    path = root / "interoperability.tar.xz"
    assert sha256(path.read_bytes()) == validation["interop_archive_sha256"]
    interop = read_archive(path)
    for label, entry in validation["interoperability"].items():
        for member, digest in entry["member_sha256"].items():
            assert sha256(interop[member]) == digest
        name = label + ("/report.json" if label == "hq" else "/hq-search-report.json")
        report = json.loads(interop[name])
        assert report["status"] == "ok" and len(report["rows"]) == entry["rows"]
        assert report["source_sha256"] == report["source_after_sha256"]
        assert report["source_sha256"]["src/zstd/match/hq_parser/prices.zig"] == sha256(expected_prices)
    large = root / "large-trained"
    manifest = json.loads((large / "manifest.json").read_text())
    path = large / "evidence.tar.xz"
    assert sha256(path.read_bytes()) == manifest["archive_sha256"]
    files = read_archive(path)
    assert set(files) == set(manifest["member_sha256"])
    for member, digest in manifest["member_sha256"].items():
        assert sha256(files[member]) == digest
    result = json.loads(files["results.json"])
    assert result["summary"] == json.loads((large / "summary.json").read_text())
    assert result["rounds"] == 1 and len(result["rows"]) == 8
    for index, summary in enumerate(result["summary"]):
        prefix = "runs/{}/".format(index)
        a, b = (json.loads(files[prefix + mode + ".json"]) for mode in ["baseline", "candidate"])
        wire = files[prefix + "baseline.zst"]
        assert wire == files[prefix + "candidate.zst"] and a["profile"] == b["profile"]
        assert sha256(wire) == summary["wire_sha256"]
        assert a["ordinary_ns"] == summary["baseline_ns"] and b["ordinary_ns"] == summary["candidate_ns"]
        assert b["ordinary_ns"] / a["ordinary_ns"] == summary["candidate_over_baseline"]
    reference_bytes = (large / "reference-decode.json").read_bytes()
    assert sha256(reference_bytes) == manifest["reference_decode_sha256"]
    reference = json.loads(reference_bytes)
    assert reference["wire_count"] == 8 and reference["version_number"] == 10600
    for row in reference["rows"]:
        assert sha256(files[row["wire"]]) == row["sha256"]
    return {"current_terminal_records": len(records), "bidirectional_reference_groups": 93,
            "large_wire_profile_pairs": 4, "large_reference_decodes": 8}
