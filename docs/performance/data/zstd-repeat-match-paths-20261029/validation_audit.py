"""Check archived target checks and independent decode records."""
import hashlib
import json


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def audit(root, archives):
    target_records = 0
    for name, total in [("assoc-firsttrue-contracts", 24), ("vector-mask-contracts", 5), ("prefix-contracts", 5)]:
        files = archives[name + ".tar.xz"]
        record = json.loads(files["validation.json"])
        assert len(record["runs"]) == 3
        for run in record["runs"]:
            assert run["exit_code"] == 0 and run["passed"] == run["total"] == total
            target_records += 1
        for member, digest in json.loads(files["source_hashes.json"]).items():
            assert sha256(files[member]) == digest
        if name == "vector-mask-contracts":
            assert record["big_endian_compile"]["exit_code"] == 0
    records = json.loads(archives["assoc-lane-mask.tar.xz"]["compile-terminal.json"])
    relevant = [r for r in records if r["label"] in ["candidate-Debug-contracts", "candidate-ReleaseFast-contracts", "candidate-x86-Debug-contracts"]]
    assert len(relevant) == 3 and all(r["exit_code"] == 0 and "All 25 tests passed." in r["stderr"] for r in relevant)
    target_records += len(relevant)
    raw = (root / "reference-decode.json").read_bytes()
    manifest = json.loads((root / "manifest.json").read_text())
    assert sha256(raw) == manifest["reference_decode_sha256"]
    reference = json.loads(raw)
    assert reference["version_number"] == 10600 and reference["wire_count"] == len(reference["rows"]) == 120
    for row in reference["rows"]:
        files = archives[row["epoch"] + ".tar.xz"]
        assert sha256(files[row["wire"]]) == row["wire_sha256"]
        assert row["decoded_bytes"] in (4096, 8192, 16384)
    return {"contract_target_terminal_records": target_records, "reference_wire_records_verified": 120}
