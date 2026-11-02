#!/usr/bin/env python3
"""Compare guarded raw incremental decoders on a pinned Silesia manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import pathlib
import re
import statistics
import subprocess


def sha(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=pathlib.Path, required=True)
    parser.add_argument("--baseline", type=pathlib.Path, required=True)
    parser.add_argument("--candidate", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--cpu", type=int, default=2)
    parser.add_argument("--sweeps", type=int, default=5)
    parser.add_argument("--iterations", type=int, default=128)
    args = parser.parse_args()
    if args.sweeps < 2 or args.iterations <= 0 or args.cpu < 0:
        parser.error("require at least two sweeps, positive iterations and a valid CPU")

    manifest = json.loads(args.manifest.read_text())
    cases = [
        row for row in manifest["rows"]
        if row["family"] == "rawdeflate"
        and row["scope"] in ("64k", "1m") and row["level"] in (6, 9)
    ]
    keys = {(row["source"], row["scope"], row["level"]) for row in cases}
    sources = {row["source"] for row in cases}
    expected = {(source, scope, level) for source in sources
                for scope in ("64k", "1m") for level in (6, 9)}
    if not sources or keys != expected or len(cases) != len(expected):
        raise SystemExit("manifest lacks unique source/scope/level coverage")
    for case in cases:
        for kind in ("input", "wire"):
            path = pathlib.Path(case[kind + "_path"])
            size = case["input_bytes" if kind == "input" else "wire_bytes"]
            if size <= 0 or path.stat().st_size != size or sha(path) != case[kind + "_sha256"]:
                raise SystemExit(f"{case['id']}: {kind} binding changed")

    binaries = {"baseline": args.baseline.resolve(), "candidate": args.candidate.resolve()}
    binary_hashes = {side: sha(path) for side, path in binaries.items()}
    samples: dict[tuple[str, str, str], list[float]] = {}
    raw = []
    for sweep in range(args.sweeps):
        sides = ("baseline", "candidate") if sweep % 2 == 0 else ("candidate", "baseline")
        for case in cases:
            for mode, input_chunk in (("whole", case["wire_bytes"]), ("input-4k", 4096)):
                for side in sides:
                    argv = ["taskset", "-c", str(args.cpu), str(binaries[side]),
                            case["wire_path"], case["input_path"], str(input_chunk),
                            "4096", str(args.iterations), "semantic"]
                    result = subprocess.run(argv, capture_output=True, text=True, check=True)
                    values = dict(re.findall(r"(\w+)=([a-z0-9]+)", result.stdout))
                    if (values.get("plain_sha") != case["input_sha256"] or values.get("guards") != "1"
                            or int(values["input"]) != case["wire_bytes"]
                            or int(values["output"]) != case["input_bytes"]
                            or int(values["iterations"]) != args.iterations
                            or int(values["checksum"]) != (args.iterations + 1) * case["input_bytes"]
                            or int(values["ns"]) <= 0):
                        raise SystemExit(f"{case['id']}/{mode}/{side}: invalid decoder evidence")
                    ns = int(values["ns"]) / args.iterations
                    samples.setdefault((case["id"], mode, side), []).append(ns)
                    raw.append({"id": case["id"], "mode": mode, "side": side,
                                "sweep": sweep, "argv": argv, "stdout": result.stdout,
                                "ns_per_decode": ns})
        print(f"sweep {sweep + 1}/{args.sweeps}: {len(raw)} verified processes", flush=True)

    rows = []
    for case in cases:
        for mode in ("whole", "input-4k"):
            baseline = samples[case["id"], mode, "baseline"]
            candidate = samples[case["id"], mode, "candidate"]
            rows.append({"id": case["id"], "scope": case["scope"], "level": case["level"],
                         "mode": mode, "baseline_ns": statistics.median(baseline),
                         "candidate_ns": statistics.median(candidate),
                         "paired_time_ratio": statistics.median([a / b for a, b in zip(candidate, baseline)]),
                         "wins": sum(a < b for a, b in zip(candidate, baseline))})
    summary = {}
    for mode in ("whole", "input-4k"):
        for scope in ("64k", "1m"):
            for level in (6, 9):
                ratios = [row["paired_time_ratio"] for row in rows
                          if row["mode"] == mode and row["scope"] == scope and row["level"] == level]
                summary[f"{mode}/{scope}/l{level}"] = {
                    "geomean_time_ratio": math.exp(statistics.mean(map(math.log, ratios))),
                    "max_time_ratio": max(ratios), "rows": len(ratios),
                }
    if binary_hashes != {side: sha(path) for side, path in binaries.items()}:
        raise SystemExit("benchmark binary changed during measurement")
    report = {"status": "passed", "cpu": args.cpu, "sweeps": args.sweeps,
              "iterations": args.iterations, "manifest_sha256": sha(args.manifest),
              "binary_sha256": binary_hashes, "summary": summary, "rows": rows, "raw": raw}
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
