#!/usr/bin/env python3
import argparse
import copy
import hashlib
import json
import math
import statistics
import subprocess
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parent
LIB = Path("/home/passchaos/Work/zstd/lib/libzstd.so.1.6.0")
BINS = {"baseline": ROOT / "bench-baseline", "candidate": ROOT / "bench-candidate"}
CONFIGS = (
    ("4k-btultra2", "btultra2", 15, ("dickens-4096", "mozilla-4096", "mr-4096"), None),
    ("16k-btultra2", "btultra2", 17, ("dickens-16384", "mozilla-16384", "mr-16384"), None),
    ("4k-btopt-control", "btopt", 15, ("dickens-4096", "mozilla-4096", "mr-4096"), None),
    ("trained-control", "btultra2", 17, ("trained-reference",), "trained.dict"),
)


def geomean(values):
    return math.exp(statistics.mean(map(math.log, values)))


def run(config, sweep, side, output):
    name, strategy, window, inputs, dictionary = config
    report = output / f"{sweep}-{name}-{side}.json"
    csv = report.with_suffix(".csv")
    argv = [
        "taskset", "-c", "2", str(BINS[side]), "--match-hq",
        "--strategy", strategy, "--window-log", str(window),
        "--iterations", "1", "--rounds", "2", "--libzstd", str(LIB),
        "--csv", str(csv), "--samples-json", str(report),
    ]
    if dictionary:
        argv.extend(("--dictionary", str(ROOT / "inputs" / dictionary)))
    for path in inputs:
        argv.extend(("--path", str(ROOT / "inputs" / path)))
    started = time.time_ns()
    subprocess.run(argv, check=True, stdout=subprocess.DEVNULL)
    return argv, started, time.time_ns(), json.loads(report.read_text())


def main():
    global ROOT, BINS
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--sweeps", type=int, default=5)
    args = parser.parse_args()
    ROOT = args.root
    BINS = {
        "baseline": ROOT / "bench-baseline",
        "candidate": ROOT / "bench-candidate",
    }
    args.output.mkdir(parents=True, exist_ok=True)
    reports = {}
    raw = []
    for sweep in range(args.sweeps):
        order = ("baseline", "candidate") if sweep % 2 == 0 else ("candidate", "baseline")
        for config in CONFIGS:
            for side in order:
                argv, started, finished, report = run(config, sweep, side, args.output)
                reports[config[0], sweep, side] = report
                raw.append({"config": config[0], "sweep": sweep, "side": side,
                            "argv": argv, "started_ns": started, "finished_ns": finished})

    rows = []
    for config in CONFIGS:
        name, _, _, inputs, _ = config
        for index, input_name in enumerate(inputs):
            samples = {side: [] for side in BINS}
            process = {side: [] for side in BINS}
            profiles = {side: [] for side in BINS}
            signatures = set()
            for sweep in range(args.sweeps):
                for side in BINS:
                    row = reports[name, sweep, side]["rows"][index]
                    settings = copy.deepcopy(row["settings"])
                    profiles[side].append(settings.pop("vort_profile"))
                    signatures.add(json.dumps({"input": row["input_sha256"],
                                               "settings": settings,
                                               "wires": row["wires"]}, sort_keys=True))
                    samples[side].extend(round_["vort_ns"] for round_ in row["rounds"])
                    process[side].append(row["summary"]["vort_median_ns"])
            if len(signatures) != 1:
                raise RuntimeError(f"wire/settings mismatch: {name}/{input_name}")
            baseline = statistics.median(samples["baseline"])
            candidate = statistics.median(samples["candidate"])
            control = "control" in name
            if control:
                if any(profile != profiles["baseline"][0] for profile in profiles["baseline"]):
                    raise RuntimeError(f"baseline profile drift: {name}/{input_name}")
                if any(profile != profiles["baseline"][0] for profile in profiles["candidate"]):
                    raise RuntimeError(f"control profile changed: {name}/{input_name}")
            rows.append({
                "config": name,
                "case": input_name,
                "baseline_ns": baseline,
                "candidate_ns": candidate,
                "ratio": candidate / baseline,
                "paired_wins": sum(process["candidate"][i] < process["baseline"][i]
                                   for i in range(args.sweeps)),
                "samples_per_side": len(samples["baseline"]),
                "baseline_profile": profiles["baseline"][0],
                "candidate_profile": profiles["candidate"][0],
            })

    summary = {}
    for name, *_ in CONFIGS:
        selected = [row for row in rows if row["config"] == name]
        summary[name] = {
            "geomean": geomean([row["ratio"] for row in selected]),
            "maximum": max(row["ratio"] for row in selected),
            "paired_wins": sum(row["paired_wins"] for row in selected),
        }
    result = {
        "baseline_sha256": hashlib.sha256(BINS["baseline"].read_bytes()).hexdigest(),
        "candidate_sha256": hashlib.sha256(BINS["candidate"].read_bytes()).hexdigest(),
        "sweeps": args.sweeps,
        "all_wire_settings_equal": True,
        "summary": summary,
        "rows": rows,
        "raw": raw,
    }
    (args.output / "comparison.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
