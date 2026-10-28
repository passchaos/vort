"""Additional frozen platform, resource and reference records for row tags."""
import hashlib
import json
import lzma
import tarfile


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def read_archive(path):
    with tarfile.open(path) as archive:
        return {m.name: archive.extractfile(m).read() for m in archive if m.isfile()}


def audit(root):
    source = json.loads((root / "source-validation.json").read_text())
    path = root / "final-source-contracts.tar.xz"
    assert sha256(path.read_bytes()) == source["final_source_archive_sha256"]
    files = read_archive(path)
    assert set(files) == set(source["final_source_sha256"])
    for name, digest in source["final_source_sha256"].items():
        assert sha256(files[name]) == digest
    snapshot = (root / "snapshot-contract-validation.json").read_bytes()
    assert sha256(snapshot) == source["snapshot_validation_sha256"]
    wasm = lzma.decompress((root / "standalone-wasi.wasm.xz").read_bytes())
    assert sha256(wasm) == source["wasm_sha256"]
    assert sha256((root / "standalone-wasi-runner.js").read_bytes()) == source["wasi_runner_sha256"]
    current = (root / "current-validation.json").read_bytes()
    assert sha256(current) == source["current_validation_sha256"]
    runs = json.loads(current)["runs"]
    assert len(runs) == 10 and all(r["exit_code"] == 0 for r in runs.values())
    path = root / "interoperability.tar.xz"
    assert sha256(path.read_bytes()) == source["interoperability_sha256"]
    interop = read_archive(path)
    for name, record in source["interoperability"].items():
        for member, digest in record["member_sha256"].items():
            assert sha256(interop[member]) == digest
        path = name + ("/report.json" if name == "hq" else "/hq-search-report.json")
        report = json.loads(interop[path])
        assert report["status"] == "ok" and len(report["rows"]) == record["rows"]
        assert report["source_sha256"] == report["source_after_sha256"]
    large = root / "large-trained"
    metadata = json.loads((large / "manifest.json").read_text())
    path = large / "evidence.tar.xz"
    assert sha256(path.read_bytes()) == metadata["archive_sha256"]
    data = read_archive(path)
    assert set(data) == set(metadata["member_sha256"])
    for name, digest in metadata["member_sha256"].items():
        assert sha256(data[name]) == digest
    result = json.loads(data["results.json"])
    assert result["rounds"] == 1 and len(result["rows"]) == 8
    assert result["summary"] == json.loads((large / "summary.json").read_text())
    for index, row in enumerate(result["summary"]):
        prefix = "runs/{}/".format(index)
        a, b = (json.loads(data[prefix + mode + ".json"]) for mode in ["baseline", "candidate"])
        assert data[prefix + "baseline.zst"] == data[prefix + "candidate.zst"]
        assert {k: v for k, v in a["profile"].items() if k != "peak_working_memory"} == {k: v for k, v in b["profile"].items() if k != "peak_working_memory"}
        assert b["profile"]["peak_working_memory"] - a["profile"]["peak_working_memory"] == 65552
        assert a["ordinary_ns"] == row["baseline_ns"] and b["ordinary_ns"] == row["candidate_ns"]
        assert row["candidate_over_baseline"] == b["ordinary_ns"] / a["ordinary_ns"]
    reference = (large / "reference-decode.json").read_bytes()
    assert sha256(reference) == metadata["reference_decode_sha256"]
    decoded = json.loads(reference)
    assert decoded["wire_count"] == 8 and decoded["version_number"] == 10600
    for row in decoded["rows"]:
        assert sha256(data[row["wire"]]) == row["wire_sha256"]
    deferred = root / "deferred-sorted-sentinel"
    meta = json.loads((deferred / "manifest.json").read_text())
    for name, field, entries in [("screen.tar.xz", "screen_sha256", "screen_member_sha256"), ("contracts.tar.xz", "contracts_sha256", "contracts")]:
        path = deferred / name
        assert sha256(path.read_bytes()) == meta[field]
        archive = read_archive(path)
        assert set(archive) == set(meta[entries])
        for member, digest in meta[entries].items():
            assert sha256(archive[member]) == digest
    return {"current_terminal_records": len(runs), "bidirectional_reference_groups": 93,
            "large_trained_wire_pairs": 4, "large_reference_decodes": 8,
            "deferred_alternative_verified": True}
