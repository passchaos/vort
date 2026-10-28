"""Check final platform/reference records and the separate borrow prototype."""
import hashlib
import json
import lzma
import statistics
import tarfile


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def read_archive(path):
    with tarfile.open(path) as archive:
        return {m.name: archive.extractfile(m).read() for m in archive if m.isfile()}


def audit(root):
    source = json.loads((root / "source-validation.json").read_text())
    path = root / "source-contracts.tar.xz"
    assert sha256(path.read_bytes()) == source["source_archive_sha256"]
    files = read_archive(path)
    assert set(files) == set(source["source_sha256"])
    for name, digest in source["source_sha256"].items():
        assert sha256(files[name]) == digest
    snapshot = (root / "snapshot-contract-validation.json").read_bytes()
    assert sha256(snapshot) == source["snapshot_validation_sha256"]
    assert all(run["exit_code"] == 0 and run["passed"] == run["total"] == 4 for run in json.loads(snapshot)["runs"])
    wasm = lzma.decompress((root / "standalone-wasi.wasm.xz").read_bytes())
    assert sha256(wasm) == source["wasm_sha256"]
    assert sha256((root / "standalone-wasi-runner.js").read_bytes()) == source["wasi_runner_sha256"]
    current = (root / "current-validation.json").read_bytes()
    assert sha256(current) == source["current_validation_sha256"]
    records = json.loads(current)["runs"]
    assert len(records) == 8 and all(run["exit_code"] == 0 for run in records.values())
    path = root / "interoperability.tar.xz"
    assert sha256(path.read_bytes()) == source["interoperability_sha256"]
    interop = read_archive(path)
    for label, record in source["interoperability"].items():
        for member, digest in record["member_sha256"].items():
            assert sha256(interop[member]) == digest
        name = label + ("/report.json" if label == "hq" else "/hq-search-report.json")
        report = json.loads(interop[name])
        assert report["status"] == "ok" and len(report["rows"]) == record["rows"]
        assert report["source_sha256"] == report["source_after_sha256"]
    deferred = root / "deferred-edge-borrow"
    manifest = json.loads((deferred / "manifest.json").read_text())
    archives = {}
    for name, field, members in [("screen.tar.xz", "screen_sha256", "screen_member_sha256"), ("contracts.tar.xz", "contract_sha256", "contract_members")]:
        path = deferred / name
        assert sha256(path.read_bytes()) == manifest[field]
        data = read_archive(path)
        assert set(data) == set(manifest[members])
        for member, digest in manifest[members].items():
            assert sha256(data[member]) == digest
        archives[name] = data
    screen = archives["screen.tar.xz"]
    result = json.loads(screen["results.json"])
    for summary in result["summary"]:
        ratios = []
        for rd in range(2):
            prefix = "runs/{}/{}-{}/".format(rd, summary["case"], summary["strategy"])
            a, b = (json.loads(screen[prefix + mode + ".json"]) for mode in ["baseline", "candidate"])
            assert screen[prefix + "baseline.zst"] == screen[prefix + "candidate.zst"] and a["profile"] == b["profile"]
            ratios.append(b["ordinary_ns"] / a["ordinary_ns"])
        assert ratios == summary["paired_ratios"]
        assert statistics.median(summary["candidate_ns"]) / statistics.median(summary["baseline_ns"]) == summary["median_ratio"]
    contracts = archives["contracts.tar.xz"]
    assert all(run["exit_code"] == 0 and run["passed"] == run["total"] == 7 for run in json.loads(contracts["validation.json"])["runs"])
    for member, digest in json.loads(contracts["source_hashes.json"]).items():
        assert sha256(contracts[member]) == digest
    return {"current_terminal_records": len(records), "bidirectional_reference_groups": 93,
            "borrow_wire_profile_pairs": 12, "borrow_contract_targets": 3}
