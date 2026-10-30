#!/usr/bin/env python3
"""Audit retained DEFLATE drift-proposal timing, size, source, and wires."""
from __future__ import annotations

import hashlib
import json
import math
import statistics
import tarfile
import tempfile
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parent
INPUT_ARCHIVE = ROOT.parent / "deflate-adaptive-split-horizon-20261029" / "inputs.tar.xz"
BASELINE = "790ea6a37c9fa1eec11a28ae7698d41e97f619a9"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def geomean(values: list[float]) -> float:
    return math.exp(statistics.mean(map(math.log, values)))


def audit_checksums() -> int:
    entries = 0
    for line in (ROOT / "SHA256SUMS").read_text().splitlines():
        digest, name = line.split("  ", 1)
        assert sha256(ROOT / name) == digest
        entries += 1
    assert entries >= 15
    return entries


def audit_sources() -> dict:
    manifest = json.loads((ROOT / "source-manifest.json").read_text())
    assert manifest["baseline_commit"] == BASELINE
    assert sha256(INPUT_ARCHIVE) == manifest["input_archive_sha256"]
    assert sha256(ROOT / "source-overlay.tar.xz") == manifest["source_overlay_sha256"]
    assert sha256(ROOT / "wires.tar.xz") == manifest["wires_sha256"]
    with tempfile.TemporaryDirectory(prefix="vort-deflate-drift-source-") as temp:
        source_root = Path(temp)
        with tarfile.open(ROOT / "source-overlay.tar.xz") as archive:
            archive.extractall(source_root, filter="data")
        for name, digest in manifest["sources"].items():
            assert sha256(source_root / name) == digest
    return {"baseline_commit": BASELINE, "source_files": len(manifest["sources"])}


def audit_ab(path: Path, case_count: int, sweeps: int) -> dict:
    report = json.loads(path.read_text())
    assert report["baseline_commit"] == BASELINE
    assert report["input_count"] == case_count
    assert report["sweeps"] == sweeps
    assert report["all_sizes_non_regressive"]
    assert len(report["rows"]) == case_count
    assert len(report["raw"]) == case_count * sweeps * 2

    with tempfile.TemporaryDirectory(prefix="vort-deflate-drift-input-") as temp:
        input_root = Path(temp)
        with tarfile.open(INPUT_ARCHIVE) as archive:
            archive.extractall(input_root, filter="data")
        for name, digest in report["input_sha256"].items():
            assert sha256(input_root / name) == digest

    grouped: dict[tuple[str, str], list[int]] = {}
    sizes: dict[tuple[str, str], set[int]] = {}
    by_sweep: dict[tuple[int, str, str], int] = {}
    for sample in report["raw"]:
        side = sample["side"]
        assert side in {"baseline", "final"}
        assert sample["sweep"] in range(sweeps)
        assert sample["command"][0:3] == ["taskset", "-c", "2"]
        assert Path(sample["command"][3]).name == f"bench-{side}"
        key = sample["case"], side
        grouped.setdefault(key, []).append(sample["elapsed_ns"])
        sizes.setdefault(key, set()).add(sample["frame_bytes"])
        by_sweep[sample["sweep"], sample["case"], side] = sample["elapsed_ns"]

    row_by_case = {row["case"]: row for row in report["rows"]}
    assert len(row_by_case) == case_count
    for case, row in row_by_case.items():
        baseline = statistics.median(grouped[case, "baseline"])
        candidate = statistics.median(grouped[case, "final"])
        assert baseline == row["baseline_ns"]
        assert candidate == row["candidate_ns"]
        assert abs(candidate / baseline - row["time_ratio"]) < 1e-12
        assert sizes[case, "baseline"] == {row["baseline_bytes"]}
        assert sizes[case, "final"] == {row["candidate_bytes"]}
        assert row["candidate_bytes"] <= row["baseline_bytes"]
        assert row["time_ratio"] <= 0.8

    reconstructed = geomean([row["time_ratio"] for row in report["rows"]])
    assert abs(reconstructed - report["time_geomean"]) < 1e-12
    reconstructed_sweeps = [
        geomean([
            by_sweep[sweep, case, "final"] / by_sweep[sweep, case, "baseline"]
            for case in sorted(row_by_case)
        ])
        for sweep in range(sweeps)
    ]
    assert all(abs(a - b) < 1e-12 for a, b in zip(
        reconstructed_sweeps, report["sweep_geomeans"]
    ))
    assert report["time_geomean"] <= 0.5
    assert all(value <= 0.5 for value in report["sweep_geomeans"])
    assert sum(row["baseline_bytes"] for row in report["rows"]) == report["total_baseline_bytes"]
    assert sum(row["candidate_bytes"] for row in report["rows"]) == report["total_candidate_bytes"]
    return {
        "cases": case_count,
        "sweeps": sweeps,
        "time_geomean": report["time_geomean"],
        "baseline_bytes": report["total_baseline_bytes"],
        "candidate_bytes": report["total_candidate_bytes"],
    }


def audit_interop() -> dict:
    report = json.loads((ROOT / "interop.json").read_text())
    assert report["cases"] == 36 and report["all_system_zlib_decodes"]
    groups: dict[str, set[str]] = {}
    with tempfile.TemporaryDirectory(prefix="vort-deflate-drift-wire-") as temp:
        temp_root = Path(temp)
        input_root = temp_root / "inputs"
        wire_root = temp_root / "wires"
        input_root.mkdir()
        wire_root.mkdir()
        with tarfile.open(INPUT_ARCHIVE) as archive:
            archive.extractall(input_root, filter="data")
        with tarfile.open(ROOT / "wires.tar.xz") as archive:
            archive.extractall(wire_root, filter="data")
        for row in report["rows"]:
            plain = (input_root / row["case"]).read_bytes()
            wire = (wire_root / f'{row["case"]}.{row["format"]}').read_bytes()
            decoded = zlib.decompress(wire, {"raw": -15, "zlib": 15, "gzip": 31}[row["format"]])
            assert decoded == plain
            assert sha256(wire_root / f'{row["case"]}.{row["format"]}') == row["wire_sha256"]
            assert hashlib.sha256(decoded).hexdigest() == row["decoded_sha256"]
            assert len(wire) == row["wire_bytes"]
            groups.setdefault(row["case"], set()).add(row["format"])
    assert len(groups) == 12
    assert all(formats == {"raw", "zlib", "gzip"} for formats in groups.values())
    return {"wires": 36, "inputs": 12, "formats": 3}


def audit_selection() -> dict:
    report = json.loads((ROOT / "k-selection.json").read_text())
    decisions = {row["k"]: row["decision"] for row in report["policies"]}
    assert decisions == {1: "reject", 2: "retain", 3: "reject", 4: "reject"}
    assert report["final_k2_revalidated"]["bytes_192k"] == 910041
    assert report["final_k2_revalidated"]["bytes_512k"] == 801621
    return {"retained_k": 2}


def main() -> int:
    result = {
        "status": "ok",
        "checksum_entries": audit_checksums(),
        "sources": audit_sources(),
        "ab_192k": audit_ab(ROOT / "ab-192k.json", 12, 5),
        "ab_512k": audit_ab(ROOT / "ab-512k.json", 3, 3),
        "interop": audit_interop(),
        "selection": audit_selection(),
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
