#!/usr/bin/env python3
"""Audit ranked-Huffman ordinary/profile evidence and frozen identities."""
from __future__ import annotations

import hashlib
import json
import math
import statistics
import tarfile
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent
NAMES = ("dickens", "mozilla", "mr", "nci", "ooffice", "osdb", "reymont", "samba", "sao", "webster", "x-ray", "xml")
PILOT_NAMES = ("mozilla", "dickens", "mr")
SIZES = (4096, 16384, 65536)
SIDES = ("baseline", "candidate")


def close(actual: float, expected: float) -> None:
    assert math.isclose(actual, expected, rel_tol=0.0, abs_tol=1e-12), (actual, expected)


def geomean(values: list[float]) -> float:
    return math.exp(sum(map(math.log, values)) / len(values))


def load_campaign(archive_path: Path, pilot: bool) -> dict:
    with tempfile.TemporaryDirectory(prefix="vort-br-ranked-audit-") as temporary:
        with tarfile.open(archive_path, "r:xz") as archive:
            archive.extractall(temporary, filter="data")
        root = Path(temporary)
        names = PILOT_NAMES if pilot else NAMES
        sizes = (65536,) if pilot else SIZES
        expected_json = 18 if pilot else 216
        assert len(list(root.glob("*.json"))) == expected_json
        assert len(list(root.glob("*.csv"))) == expected_json

        samples: dict[tuple[str, str], list[int]] = {}
        process: dict[tuple[str, str, int], int] = {}
        signatures: dict[str, set[str]] = {}
        references: dict[str, list[int]] = {}
        size_ratios: dict[str, float] = {}
        for sweep in range(3):
            for size in sizes:
                for name in names:
                    key = f"{name}-{size}"
                    for side in SIDES:
                        path = root / f"{sweep}-{name}-{side}.json" if pilot else root / f"{sweep}-{name}-{size}-{side}.json"
                        report = json.loads(path.read_text())
                        assert report["reference_version"] == 0x1002000
                        assert len(report["rows"]) == 1
                        row = report["rows"][0]
                        settings = row["settings"]
                        assert settings["parameters_match"]
                        assert settings["vort_wire_window_bits"] == settings["reference_wire_window_bits"] == 16
                        signatures.setdefault(key, set()).add(json.dumps({
                            "input_bytes": row["input_bytes"],
                            "input_sha256": row["input_sha256"],
                            "wires": row["wires"],
                            "settings": settings,
                        }, sort_keys=True))
                        samples.setdefault((key, side), []).extend(round_["vort_ns"] for round_ in row["rounds"])
                        process[key, side, sweep] = row["summary"]["vort_median_ns"]
                        if side == "candidate":
                            references.setdefault(key, []).extend(round_["reference_ns"] for round_ in row["rounds"])
                            size_ratios[key] = row["wires"]["vort_bytes"] / row["wires"]["reference_bytes"]
        assert all(len(signature) == 1 for signature in signatures.values())

        rows = []
        buckets: dict[int, list[float]] = {}
        for size in sizes:
            for name in names:
                key = f"{name}-{size}"
                baseline = samples[key, "baseline"]
                candidate = samples[key, "candidate"]
                assert len(baseline) == len(candidate) == 15
                ratio = statistics.median(candidate) / statistics.median(baseline)
                buckets.setdefault(size, []).append(ratio)
                rows.append({
                    "case": key,
                    "ratio": ratio,
                    "candidate_over_reference": statistics.median(candidate) / statistics.median(references[key]),
                })
        sweeps = [
            geomean([
                process[row["case"], "candidate", sweep] / process[row["case"], "baseline", sweep]
                for row in rows
            ])
            for sweep in range(3)
        ]
        return {
            "geomean": geomean([row["ratio"] for row in rows]),
            "maximum": max(row["ratio"] for row in rows),
            "not_regressed": sum(row["ratio"] <= 1 for row in rows),
            "sweeps": sweeps,
            "buckets": {str(size): geomean(values) for size, values in buckets.items()},
            "candidate_over_reference": geomean([row["candidate_over_reference"] for row in rows]),
            "size_geomean": geomean(list(size_ratios.values())),
            "cases": len(rows),
        }


def clean_profile(value):
    if isinstance(value, dict):
        return {
            key: clean_profile(child)
            for key, child in value.items()
            if key != "provenance" and key != "normal_first" and not key.endswith("_ns")
        }
    if isinstance(value, list):
        return [clean_profile(child) for child in value]
    return value


def profile_totals(value, totals: dict[str, int]) -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            if (key.startswith("small_huffman_") or key == "tree_lengths_ns") and isinstance(child, int):
                totals[key] = totals.get(key, 0) + child
            profile_totals(child, totals)
    elif isinstance(value, list):
        for child in value:
            profile_totals(child, totals)


def main() -> int:
    summary = json.loads((ROOT / "summary.json").read_text())
    formal = load_campaign(ROOT / "formal-ab.tar.xz", False)
    pilot = load_campaign(ROOT / "pilot-ab.tar.xz", True)
    for key in ("geomean", "maximum", "candidate_over_reference", "size_geomean"):
        close(formal[key], summary["formal"][key])
    assert formal["cases"] == formal["not_regressed"] == 36
    assert formal["geomean"] <= 0.990
    assert formal["maximum"] <= 1.030
    assert formal["buckets"]["4096"] <= 1.005
    assert formal["buckets"]["16384"] <= 1.005
    assert formal["buckets"]["65536"] <= 0.990
    assert all(ratio < 1 for ratio in formal["sweeps"])
    close(pilot["geomean"], summary["pilot"]["geomean"])
    assert pilot["cases"] == pilot["not_regressed"] == 3
    assert pilot["geomean"] <= 0.990
    assert pilot["maximum"] <= 1.020
    assert all(ratio < 1 for ratio in pilot["sweeps"])

    baseline = json.loads((ROOT / "profile-baseline.json").read_text())
    candidate = json.loads((ROOT / "profile-candidate.json").read_text())
    assert clean_profile(baseline) == clean_profile(candidate)
    baseline_totals: dict[str, int] = {}
    candidate_totals: dict[str, int] = {}
    profile_totals(baseline["rows"], baseline_totals)
    profile_totals(candidate["rows"], candidate_totals)
    assert baseline_totals["small_huffman_calls"] == candidate_totals["small_huffman_calls"] == 4739
    assert baseline_totals["small_huffman_failures"] == candidate_totals["small_huffman_failures"] == 0
    tree_ratio = candidate_totals["tree_lengths_ns"] / baseline_totals["tree_lengths_ns"]
    close(tree_ratio, summary["profile"]["tree_lengths_ratio"])
    assert tree_ratio <= 0.85

    manifest = {}
    for line in (ROOT / "SHA256SUMS").read_text().splitlines():
        digest, name = line.split(None, 1)
        manifest[name] = digest
    for name, digest in manifest.items():
        assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest, name

    print(json.dumps({
        "status": "ok",
        "formal_cases": formal["cases"],
        "formal_geomean": formal["geomean"],
        "formal_sweeps": formal["sweeps"],
        "pilot_geomean": pilot["geomean"],
        "profile_non_time_equal": True,
        "tree_lengths_ratio": tree_ratio,
        "checksums": len(manifest),
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
