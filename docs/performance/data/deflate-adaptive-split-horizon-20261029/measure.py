#!/usr/bin/env python3
"""Run case-paired ordinary adaptive-default A/B sweeps."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import statistics
import subprocess
import time
from pathlib import Path


def geomean(values: list[float]) -> float:
    return math.exp(statistics.mean(map(math.log, values)))


def fields(output: str) -> dict[str, int]:
    return {key: int(value) for key, value in (item.split("=", 1) for item in output.split())}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path, help="directory containing bench-baseline and bench-final")
    parser.add_argument("inputs", type=Path, help="directory containing exact input files")
    parser.add_argument("output", type=Path)
    parser.add_argument("--suffix", required=True)
    parser.add_argument("--sweeps", type=int, required=True)
    args = parser.parse_args()
    paths = sorted(args.inputs.glob(f"*-{args.suffix}"))
    assert paths and args.sweeps > 0
    records = []
    for sweep in range(args.sweeps):
        for index, path in enumerate(paths):
            order = ("baseline", "final") if (sweep + index) % 2 == 0 else ("final", "baseline")
            for side in order:
                command = [
                    "taskset", "-c", "2", str(args.root / f"bench-{side}"),
                    str(path), "1", "adaptive-default",
                ]
                start = time.time_ns()
                run = subprocess.run(command, check=True, text=True, stdout=subprocess.PIPE)
                end = time.time_ns()
                records.append({
                    "sweep": sweep,
                    "case": path.stem.removesuffix("-" + args.suffix),
                    "side": side,
                    "command": command,
                    "process_start_ns": start,
                    "process_end_ns": end,
                    **fields(run.stdout),
                })
    values: dict[tuple[str, str], list[int]] = {}
    sizes: dict[tuple[str, str], set[int]] = {}
    sweep_values: dict[tuple[int, str, str], int] = {}
    for row in records:
        values.setdefault((row["case"], row["side"]), []).append(row["elapsed_ns"])
        sizes.setdefault((row["case"], row["side"]), set()).add(row["frame_bytes"])
        sweep_values[row["sweep"], row["case"], row["side"]] = row["elapsed_ns"]
    rows = []
    for case in sorted({row["case"] for row in records}):
        baseline = statistics.median(values[case, "baseline"])
        candidate = statistics.median(values[case, "final"])
        baseline_size = next(iter(sizes[case, "baseline"]))
        candidate_size = next(iter(sizes[case, "final"]))
        assert len(sizes[case, "baseline"]) == len(sizes[case, "final"]) == 1
        assert candidate_size <= baseline_size
        rows.append({
            "case": case,
            "baseline_ns": baseline,
            "candidate_ns": candidate,
            "time_ratio": candidate / baseline,
            "baseline_bytes": baseline_size,
            "candidate_bytes": candidate_size,
            "size_delta": candidate_size - baseline_size,
        })
    result = {
        "baseline_commit": "f560b1564724d52e7d151564226bfaac2275aa04",
        "baseline_sha256": hashlib.sha256((args.root / "bench-baseline").read_bytes()).hexdigest(),
        "candidate_sha256": hashlib.sha256((args.root / "bench-final").read_bytes()).hexdigest(),
        "input_count": len(paths),
        "input_sha256": {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in paths},
        "sweeps": args.sweeps,
        "iterations": 1,
        "time_geomean": geomean([row["time_ratio"] for row in rows]),
        "sweep_geomeans": [
            geomean([
                sweep_values[sweep, row["case"], "final"] /
                sweep_values[sweep, row["case"], "baseline"]
                for row in rows
            ])
            for sweep in range(args.sweeps)
        ],
        "all_sizes_non_regressive": True,
        "total_baseline_bytes": sum(row["baseline_bytes"] for row in rows),
        "total_candidate_bytes": sum(row["candidate_bytes"] for row in rows),
        "rows": rows,
        "raw": records,
    }
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({key: value for key, value in result.items() if key not in {"raw", "rows"}}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
