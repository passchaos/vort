#!/usr/bin/env python3
"""Audit the frozen three-sweep Brotli adaptive-distance A/B archive."""
from __future__ import annotations

import argparse
import json
import math
import statistics
import tarfile
import tempfile
from pathlib import Path


def load(root: Path) -> list[tuple[int, str, dict]]:
    rows = []
    for cycle in range(3):
        for side in ("baseline", "candidate"):
            paths = sorted(root.glob(f"{cycle}-*-{side}.json"))
            if not paths:
                paths = [root / f"{cycle}-{side}.json"]
            for path in paths:
                report = json.loads(path.read_text())
                for row in report["rows"]:
                    rows.append((cycle, side, row))
    return rows


def audit(root: Path) -> dict:
    rows = load(root)
    assert len(rows) == 216
    groups: dict[str, dict[str, list[int]]] = {}
    signatures: dict[str, set[str]] = {}
    process: dict[tuple[int, str, str], int] = {}
    references: dict[str, list[int]] = {}
    size_ratios: dict[str, float] = {}
    sizes: dict[str, int] = {}
    for cycle, side, row in rows:
        case = row["case"]
        sizes[case] = row["input_bytes"]
        groups.setdefault(case, {}).setdefault(side, []).extend(
            sample["vort_ns"] for sample in row["rounds"]
        )
        if side == "candidate":
            references.setdefault(case, []).extend(
                sample["reference_ns"] for sample in row["rounds"]
            )
            size_ratios[case] = row["wires"]["vort_bytes"] / row["wires"]["reference_bytes"]
        process[cycle, side, case] = row["summary"]["vort_median_ns"]
        signatures.setdefault(case, set()).add(json.dumps({
            "input_bytes": row["input_bytes"],
            "input_sha256": row["input_sha256"],
            "wire": row["wires"],
            "settings": row["settings"],
        }, sort_keys=True))
    assert len(groups) == 36 and all(len(value) == 1 for value in signatures.values())
    cases = []
    buckets: dict[int, list[float]] = {}
    for case in sorted(groups):
        baseline = groups[case]["baseline"]
        candidate = groups[case]["candidate"]
        assert len(baseline) == len(candidate) == 15
        ratio = statistics.median(candidate) / statistics.median(baseline)
        buckets.setdefault(sizes[case], []).append(ratio)
        cases.append({"case": case, "input_bytes": sizes[case], "ratio": ratio})
    sweeps = []
    for cycle in range(3):
        ratios = [
            process[cycle, "candidate", case] / process[cycle, "baseline", case]
            for case in groups
        ]
        sweeps.append(math.exp(sum(map(math.log, ratios)) / len(ratios)))
    result = {
        "status": "ok",
        "rows": len(rows),
        "cases": cases,
        "all_wires_settings_equal": True,
        "geomean": math.exp(sum(math.log(row["ratio"]) for row in cases) / len(cases)),
        "buckets": {
            str(size): {
                "count": len(ratios),
                "geomean": math.exp(sum(map(math.log, ratios)) / len(ratios)),
                "maximum": max(ratios),
            }
            for size, ratios in sorted(buckets.items())
        },
        "sweep_geomeans": sweeps,
        "candidate_over_reference_size_geomean": math.exp(
            sum(map(math.log, size_ratios.values())) / len(size_ratios)
        ),
        "candidate_over_reference_time_geomean": math.exp(sum(
            math.log(statistics.median(groups[case]["candidate"]) / statistics.median(references[case]))
            for case in groups
        ) / len(groups)),
    }
    assert result["geomean"] <= 0.990
    assert result["buckets"]["65536"]["geomean"] <= 0.980
    assert result["buckets"]["4096"]["geomean"] <= 1.005
    assert result["buckets"]["16384"]["geomean"] <= 1.005
    assert all(ratio < 1 for ratio in sweeps)
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="vort-br-adaptive-audit-") as temporary:
        with tarfile.open(args.archive) as archive:
            archive.extractall(temporary, filter="data")
        print(json.dumps(audit(Path(temporary)), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
