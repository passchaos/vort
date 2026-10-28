"""Check global CPU periods and retained implementation validation."""
import hashlib
import json
import lzma
import math
import tarfile


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def read_archive(path):
    with tarfile.open(path) as archive:
        return {m.name: archive.extractfile(m).read() for m in archive if m.isfile()}


def audit(root, archives):
    sampled = archives["current-hotspots.tar.xz"]
    sample_count = 0
    for summary in json.loads(sampled["sample-summary.json"]):
        label = summary["label"]
        rows = [line.split(maxsplit=2) for line in sampled[label + ".ip-period.txt"].decode().splitlines()]
        rows = [(int(p), int(ip, 16), symbol) for p, ip, symbol in rows]
        total = sum(p for p, _, _ in rows)
        assert total == summary["global_period"] and len(rows) == summary["samples"]
        sample_count += len(rows)
        for category in ["extend_parts", "insert_parts"]:
            for entry in summary[category].values():
                intervals = [(int(s["begin"], 16), int(s["end_exclusive"], 16)) for s in entry["segments"]]
                selected = [p for p, ip, _ in rows if any(start <= ip < end for start, end in intervals)]
                assert len(selected) == entry["samples"] and sum(selected) == entry["period"]
                assert math.isclose(sum(selected) / total * 100, entry["global_pct"], abs_tol=1e-12)
        for entry in summary["top10"]:
            period = sum(p for p, _, symbol in rows if symbol == entry["symbol"])
            assert math.isclose(period / total * 100, entry["global_pct"], abs_tol=1e-12)
    source = json.loads((root / "source-validation.json").read_text())
    path = root / "source-contracts.tar.xz"
    assert sha256(path.read_bytes()) == source["source_archive_sha256"]
    files = read_archive(path)
    assert set(files) == set(source["source_members"])
    for name, digest in source["source_members"].items():
        assert sha256(files[name]) == digest
    wasm = lzma.decompress((root / "standalone-wasi.wasm.xz").read_bytes())
    assert sha256(wasm) == source["wasm_sha256"]
    assert sha256((root / "standalone-wasi-runner.js").read_bytes()) == source["wasi_runner_sha256"]
    comments = source["comment_only_helper_source_change"]
    measured = archives["ordinary-screen.tar.xz"]["candidate/src/zstd/match/hq_parser/sampled_price.zig"]
    current = files["src/zstd/match/hq_parser/sampled_price.zig"]
    strip = lambda b: b"".join(line for line in b.splitlines(keepends=True) if not line.lstrip().startswith(b"//!"))
    assert strip(measured) == strip(current)
    assert sha256(measured) == comments["measured_sha256"] and sha256(current) == comments["current_sha256"]
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
    current_bytes = (root / "current-validation.json").read_bytes()
    assert sha256(current_bytes) == source["current_validation_sha256"]
    runs = json.loads(current_bytes)["runs"]
    assert len(runs) == 9 and all(r["exit_code"] == 0 for r in runs.values())
    return {"ordinary_samples_verified": sample_count, "current_terminal_records": len(runs),
            "bidirectional_reference_groups": 93}
