#!/usr/bin/env python3
"""Audit retained DEFLATE adaptive-split timing, size and interop evidence."""
from __future__ import annotations

import json
import hashlib
import math
import statistics
import tarfile
import tempfile
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def geomean(values: list[float]) -> float:
    return math.exp(statistics.mean(map(math.log, values)))


def file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def audit_checksums(path: Path) -> int:
    entries = 0
    for line in path.read_text().splitlines():
        digest, name = line.split("  ", 1)
        assert file_sha256(ROOT / name) == digest
        entries += 1
    assert entries >= 10
    return entries


def audit_sources() -> dict:
    manifest = json.loads((ROOT / "source-manifest.json").read_text())
    assert manifest["baseline_commit"] == "f560b1564724d52e7d151564226bfaac2275aa04"
    with tempfile.TemporaryDirectory(prefix="vort-deflate-adaptive-source-audit-") as temporary:
        source_root = Path(temporary)
        with tarfile.open(ROOT / "source-overlay.tar.xz") as archive:
            archive.extractall(source_root, filter="data")
        for entry in manifest["files"]:
            path = source_root / entry["path"]
            assert path.stat().st_size == entry["bytes"]
            assert file_sha256(path) == entry["sha256"]
    return {"files": len(manifest["files"]), "baseline_commit": manifest["baseline_commit"]}


def read_identities(path: Path) -> dict[str, str]:
    return dict(line.split("=", 1) for line in path.read_text().splitlines() if line)


def audit_ab(
    path: Path,
    expected_cases: int,
    expected_sweeps: int,
    identities: dict[str, str],
) -> dict:
    report = json.loads(path.read_text())
    rows = report["rows"]
    raw = report["raw"]
    assert len(rows) == expected_cases
    assert len(raw) == expected_cases * expected_sweeps * 2
    assert report["input_count"] == expected_cases
    assert report["sweeps"] == expected_sweeps
    assert report["all_sizes_non_regressive"]
    assert report["baseline_sha256"] == identities["baseline_bench_sha256"]
    assert report["candidate_sha256"] == identities["candidate_bench_sha256"]
    assert len(report["input_sha256"]) == expected_cases
    with tempfile.TemporaryDirectory(prefix="vort-deflate-adaptive-input-audit-") as temporary:
        input_root = Path(temporary)
        with tarfile.open(ROOT / "inputs.tar.xz") as archive:
            archive.extractall(input_root, filter="data")
        for name, digest in report["input_sha256"].items():
            assert hashlib.sha256((input_root / name).read_bytes()).hexdigest() == digest
    grouped: dict[tuple[str, str], list[int]] = {}
    sizes: dict[tuple[str, str], set[int]] = {}
    by_sweep: dict[tuple[int, str, str], int] = {}
    for sample in raw:
        side = sample["side"]
        assert side in {"baseline", "final"}
        assert sample["sweep"] in range(expected_sweeps)
        command = sample["command"]
        assert command[0:3] == ["taskset", "-c", "2"]
        assert Path(command[3]).name == f"bench-{side}"
        assert command[-2:] == ["1", "adaptive-default"]
        assert Path(command[-3]).stem.startswith(sample["case"] + "-")
        key = (sample["case"], side)
        grouped.setdefault(key, []).append(sample["elapsed_ns"])
        sizes.setdefault(key, set()).add(sample["frame_bytes"])
        by_sweep[sample["sweep"], sample["case"], side] = sample["elapsed_ns"]
    assert len(grouped) == expected_cases * 2
    assert all(len(values) == expected_sweeps for values in grouped.values())
    assert all(len(values) == 1 for values in sizes.values())
    row_by_case = {row["case"]: row for row in rows}
    assert len(row_by_case) == expected_cases
    for case, row in row_by_case.items():
        baseline = statistics.median(grouped[case, "baseline"])
        candidate = statistics.median(grouped[case, "final"])
        assert baseline == row["baseline_ns"]
        assert candidate == row["candidate_ns"]
        assert abs(candidate / baseline - row["time_ratio"]) < 1e-12
        assert sizes[case, "baseline"] == {row["baseline_bytes"]}
        assert sizes[case, "final"] == {row["candidate_bytes"]}
    assert all(row["candidate_bytes"] <= row["baseline_bytes"] for row in rows)
    assert all(row["time_ratio"] < 0.5 for row in rows)
    reconstructed = geomean([row["time_ratio"] for row in rows])
    assert abs(reconstructed - report["time_geomean"]) < 1e-12
    reconstructed_sweeps = [
        geomean([
            by_sweep[sweep, case, "final"] / by_sweep[sweep, case, "baseline"]
            for case in sorted(row_by_case)
        ])
        for sweep in range(expected_sweeps)
    ]
    assert all(
        abs(actual - expected) < 1e-12
        for actual, expected in zip(reconstructed_sweeps, report["sweep_geomeans"])
    )
    assert report["time_geomean"] < 0.35
    assert all(value < 0.35 for value in report["sweep_geomeans"])
    return {
        "cases": len(rows),
        "sweeps": expected_sweeps,
        "time_geomean": report["time_geomean"],
        "sweep_geomeans": report["sweep_geomeans"],
        "baseline_bytes": sum(row["baseline_bytes"] for row in rows),
        "candidate_bytes": sum(row["candidate_bytes"] for row in rows),
    }


def audit_interop(path: Path) -> dict:
    report = json.loads(path.read_text())
    assert report["cases"] == 36 and report["all_system_zlib_decodes"]
    rows = report["rows"]
    groups: dict[str, set[str]] = {}
    with tempfile.TemporaryDirectory(prefix="vort-deflate-adaptive-audit-") as temporary:
        root = Path(temporary)
        input_root = root / "inputs"
        wire_root = root / "wires"
        input_root.mkdir()
        wire_root.mkdir()
        with tarfile.open(ROOT / "inputs.tar.xz") as archive:
            archive.extractall(input_root, filter="data")
        with tarfile.open(ROOT / "wires.tar.xz") as archive:
            archive.extractall(wire_root, filter="data")
        for row in rows:
            plain = (input_root / row["case"]).read_bytes()
            wire = (wire_root / f'{row["case"]}.{row["format"]}').read_bytes()
            decoded = zlib.decompress(wire, {"raw": -15, "zlib": 15, "gzip": 31}[row["format"]])
            assert decoded == plain
            assert hashlib.sha256(plain).hexdigest() == row["input_sha256"]
            assert hashlib.sha256(wire).hexdigest() == row["wire_sha256"]
            assert hashlib.sha256(decoded).hexdigest() == row["decoded_sha256"]
            assert len(wire) == row["wire_bytes"]
            groups.setdefault(row["case"], set()).add(row["format"])
    assert len(groups) == 12
    assert all(formats == {"raw", "zlib", "gzip"} for formats in groups.values())
    return {"cases": len(rows), "inputs": len(groups), "formats": 3}


def audit_reference(path: Path) -> dict:
    report = json.loads(path.read_text())
    assert report["zlib_version"] == report["runtime_version"] == "1.2.11"
    assert len(report["rows"]) == 12
    assert report["level6_total_bytes"] == 912169
    assert report["level9_total_bytes"] == 905780
    return {
        "inputs": len(report["rows"]),
        "level6_total_bytes": report["level6_total_bytes"],
        "level9_total_bytes": report["level9_total_bytes"],
    }


def audit_replay(path: Path, identities: dict[str, str]) -> dict:
    report = json.loads(path.read_text())
    assert report["baseline_commit"] == identities["baseline_commit"]
    assert report["source_overlay_sha256"] == identities["source_overlay_sha256"]
    assert report["wire_equal"]
    assert report["samba_196608_replayed_zlib_sha256"] == \
        report["samba_196608_retained_zlib_sha256"]
    assert report["samba_196608_candidate_bytes"] < report["samba_196608_baseline_bytes"]
    return {
        "wire_equal": True,
        "baseline_bytes": report["samba_196608_baseline_bytes"],
        "candidate_bytes": report["samba_196608_candidate_bytes"],
    }


def main() -> int:
    identities = read_identities(ROOT / "identities.txt")
    result = {
        "status": "ok",
        "checksum_entries": audit_checksums(ROOT / "SHA256SUMS"),
        "sources": audit_sources(),
        "ab_192k": audit_ab(ROOT / "ab-192k.json", 12, 5, identities),
        "ab_512k": audit_ab(ROOT / "ab-512k.json", 3, 3, identities),
        "interop": audit_interop(ROOT / "interop.json"),
        "reference": audit_reference(ROOT / "reference-sizes.json"),
        "replay": audit_replay(ROOT / "replay-check.json", identities),
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
