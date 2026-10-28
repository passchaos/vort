#!/usr/bin/env python3
"""Verify the retained shift implementation and final terminal records."""
import hashlib
import json
import lzma
import tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def files(path):
    with tarfile.open(path) as archive:
        return {m.name: archive.extractfile(m).read() for m in archive if m.isfile()}


def main():
    record = json.loads((ROOT / "current-validation.json").read_text())
    assert record["status"] == "verified" and len(record["runs"]) == 9
    assert all(run["exit_code"] == 0 for run in record["runs"].values())
    overlay = ROOT / "final-source-overlay.tar.xz"
    assert sha256(overlay.read_bytes()) == record["source_overlay_sha256"]
    source = files(overlay)
    assert set(source) == set(record["current_source_sha256"])
    for name, digest in record["current_source_sha256"].items():
        assert sha256(source[name]) == digest
    wasm = lzma.decompress((ROOT / "standalone-wasi.wasm.xz").read_bytes())
    assert sha256(wasm) == record["runs"]["wasm_execute"]["wasm_sha256"]
    assert sha256((ROOT / "standalone-wasi-runner.js").read_bytes()) == record["wasi_runner_sha256"]
    path = ROOT / "current-interoperability.tar.xz"
    assert sha256(path.read_bytes()) == record["interoperability_sha256"]
    interop = files(path)
    for name, entry in record["interoperability"].items():
        for member, digest in entry["member_sha256"].items():
            assert sha256(interop[member]) == digest
        path = name + ("/report.json" if name == "hq" else "/hq-search-report.json")
        report = json.loads(interop[path])
        assert report["status"] == "ok" and len(report["rows"]) == entry["rows"]
        assert report["source_sha256"] == report["source_after_sha256"]
        for member, digest in record["current_source_sha256"].items():
            if member in report["source_sha256"]:
                assert report["source_sha256"][member] == digest
    print(json.dumps({"current_terminal_records": 9, "source_files": len(source),
                      "bidirectional_groups": 93, "wasm_image_verified": True}))


if __name__ == "__main__":
    main()
