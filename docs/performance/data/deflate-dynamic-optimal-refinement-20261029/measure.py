#!/usr/bin/env python3
import argparse
import json
import math
import pathlib
import re
import statistics
import subprocess
import time

PARSER = re.compile(r"elapsed_ns=(\d+) frame_bytes=(\d+) zlib_bytes=(\d+) mix=(\d+)")


def run(binary, path, iterations, mode, extra, cpu):
    argv = ["taskset", "-c", str(cpu), str(binary), str(path), str(iterations), mode, *extra]
    started = time.time_ns()
    process = subprocess.run(argv, check=True, text=True, capture_output=True)
    finished = time.time_ns()
    match = PARSER.fullmatch(process.stdout.strip())
    if match is None:
        raise RuntimeError(f"unexpected output: {process.stdout!r}")
    elapsed_ns, frame_bytes, zlib_bytes, mix = map(int, match.groups())
    return {
        "argv": argv,
        "started_unix_ns": started,
        "finished_unix_ns": finished,
        "elapsed_ns": elapsed_ns,
        "per_iteration_ns": elapsed_ns / iterations,
        "frame_bytes": frame_bytes,
        "zlib_bytes": zlib_bytes,
        "mix": mix,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=pathlib.Path)
    parser.add_argument("inputs", type=pathlib.Path)
    parser.add_argument("output", type=pathlib.Path)
    parser.add_argument("--iterations", type=int, default=3)
    parser.add_argument("--sweeps", type=int, default=3)
    parser.add_argument("--mode", default="raw-best")
    parser.add_argument("--extra", action="append", default=[])
    parser.add_argument("--cpu", type=int, default=2)
    args = parser.parse_args()

    binaries = {
        "baseline": args.root / "bench-baseline",
        "candidate": args.root / "bench-candidate",
    }
    cases = {}
    paths = sorted(args.inputs.iterdir())
    started = time.time_ns()
    for sweep in range(args.sweeps):
        order = ["baseline", "candidate"] if sweep % 2 == 0 else ["candidate", "baseline"]
        for path in paths:
            case = cases.setdefault(path.name, {"path": str(path), "samples": {"baseline": [], "candidate": []}})
            for side in order:
                case["samples"][side].append(run(binaries[side], path, args.iterations, args.mode, args.extra, args.cpu))

    ratios = []
    baseline_total = 0
    candidate_total = 0
    wins = ties = regressions = 0
    for name, case in cases.items():
        baseline_samples = case["samples"]["baseline"]
        candidate_samples = case["samples"]["candidate"]
        baseline_ns = statistics.median(sample["per_iteration_ns"] for sample in baseline_samples)
        candidate_ns = statistics.median(sample["per_iteration_ns"] for sample in candidate_samples)
        baseline_bytes = baseline_samples[0]["frame_bytes"]
        candidate_bytes = candidate_samples[0]["frame_bytes"]
        if any(sample["frame_bytes"] != baseline_bytes for sample in baseline_samples):
            raise RuntimeError(f"unstable baseline size for {name}")
        if any(sample["frame_bytes"] != candidate_bytes for sample in candidate_samples):
            raise RuntimeError(f"unstable candidate size for {name}")
        baseline_total += baseline_bytes
        candidate_total += candidate_bytes
        wins += candidate_bytes < baseline_bytes
        ties += candidate_bytes == baseline_bytes
        regressions += candidate_bytes > baseline_bytes
        ratio = candidate_ns / baseline_ns
        ratios.append(ratio)
        case["summary"] = {
            "baseline_median_ns": baseline_ns,
            "candidate_median_ns": candidate_ns,
            "time_ratio": ratio,
            "baseline_bytes": baseline_bytes,
            "candidate_bytes": candidate_bytes,
            "byte_delta": candidate_bytes - baseline_bytes,
        }

    result = {
        "started_unix_ns": started,
        "finished_unix_ns": time.time_ns(),
        "cpu": args.cpu,
        "mode": args.mode,
        "extra": args.extra,
        "iterations": args.iterations,
        "sweeps": args.sweeps,
        "summary": {
            "case_count": len(cases),
            "time_geomean_ratio": math.exp(sum(math.log(ratio) for ratio in ratios) / len(ratios)),
            "time_worst_ratio": max(ratios),
            "baseline_bytes": baseline_total,
            "candidate_bytes": candidate_total,
            "byte_delta": candidate_total - baseline_total,
            "wins": wins,
            "ties": ties,
            "regressions": regressions,
        },
        "cases": cases,
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps(result["summary"], sort_keys=True))


if __name__ == "__main__":
    main()
