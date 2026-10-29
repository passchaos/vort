#!/usr/bin/env python3
import hashlib
import json
import math
import pathlib
import tarfile
import tempfile
import zlib


ROOT = pathlib.Path(__file__).resolve().parent


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def close(actual, expected):
    if not math.isclose(actual, expected, rel_tol=0.0, abs_tol=1e-12):
        raise AssertionError((actual, expected))


def audit_ab(path, expected):
    data = json.loads(path.read_text())
    observed = data["summary"]
    for key in ("case_count", "baseline_bytes", "candidate_bytes", "wins", "ties", "regressions"):
        if observed[key] != expected[key]:
            raise AssertionError((path.name, key, observed[key], expected[key]))
    close(observed["time_geomean_ratio"], expected["candidate_over_baseline_geomean"])
    close(observed["time_worst_ratio"], expected["worst_case_ratio"])
    if len(data["cases"]) != 36:
        raise AssertionError((path.name, len(data["cases"])))
    for case in data["cases"].values():
        if len(case["samples"]["baseline"]) != 3 or len(case["samples"]["candidate"]) != 3:
            raise AssertionError((path.name, case["path"]))
        if case["summary"]["candidate_bytes"] > case["summary"]["baseline_bytes"]:
            raise AssertionError((path.name, case["path"], "size regression"))


def main():
    summary = json.loads((ROOT / "summary.json").read_text())
    audit_ab(ROOT / "raw-best-ab.json", summary["ordinary_ab"]["raw_best"])
    audit_ab(ROOT / "level8-raw-ab.json", summary["ordinary_ab"]["numeric_level_8"])

    with tempfile.TemporaryDirectory(prefix="vort-deflate-dynamic-audit-") as temp:
        temp_path = pathlib.Path(temp)
        with tarfile.open(ROOT / "inputs.tar.xz", "r:xz") as archive:
            archive.extractall(temp_path / "inputs", filter="data")
        with tarfile.open(ROOT / "wires.tar.xz", "r:xz") as archive:
            archive.extractall(temp_path / "wires", filter="data")
        interop = json.loads((ROOT / "interop.json").read_text())
        if interop["checks"] != 216 or len(interop["results"]) != 216:
            raise AssertionError("incomplete interop matrix")
        wbits = {"raw": -15, "zlib": 15, "gzip": 31}
        for record in interop["results"]:
            plain = (temp_path / "inputs" / record["input"]).read_bytes()
            wire = (temp_path / "wires" / record["wire"]).read_bytes()
            decoded = zlib.decompress(wire, wbits=wbits[record["wrapper"]])
            if len(plain) != record["input_bytes"] or sha256(plain) != record["input_sha256"]:
                raise AssertionError((record["input"], "input identity"))
            if len(wire) != record["wire_bytes"] or sha256(wire) != record["wire_sha256"]:
                raise AssertionError((record["wire"], "wire identity"))
            if decoded != plain or sha256(decoded) != record["decoded_sha256"]:
                raise AssertionError((record["wire"], "decode mismatch"))

    manifest = {}
    for line in (ROOT / "SHA256SUMS").read_text().splitlines():
        digest, name = line.split(None, 1)
        manifest[name] = digest
    for name, digest in manifest.items():
        if sha256((ROOT / name).read_bytes()) != digest:
            raise AssertionError((name, "checksum"))

    print(json.dumps({
        "ordinary_cases": 72,
        "interop_wires": 216,
        "size_regressions": 0,
        "system_zlib_runtime": zlib.ZLIB_RUNTIME_VERSION,
        "checksums": len(manifest),
    }, sort_keys=True))


if __name__ == "__main__":
    main()
