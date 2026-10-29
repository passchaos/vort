#!/usr/bin/env python3
import json
import pathlib
import statistics
import subprocess
import time

ROOT = pathlib.Path("/tmp/vort-zstd-cold-reuse-20261030.mQDBSt")
OLD = pathlib.Path("/tmp/vort-zstd-node40-20261029.SzGYUk")
BINS = {
    "baseline": ROOT / "baseline-src/.zig-cache/o/e6e32eaf4ed7e48cbf073f813c08647c/vort-zstd-encode-bench",
    "candidate": ROOT / "candidate-src/.zig-cache/o/b4b81d4fa10c49be4edbe62380f60513/vort-zstd-encode-bench",
}


def run(pair, side):
    out = ROOT / "mozilla-long"
    out.mkdir(exist_ok=True)
    report = out / f"{pair}-{side}.json"
    csv = report.with_suffix(".csv")
    argv = [
        "taskset", "-c", "2", str(BINS[side]), "--match-hq",
        "--strategy", "btultra2", "--window-log", "15",
        "--iterations", "1", "--rounds", "2", "--limit", "4096",
        "--libzstd", str(OLD / "libzstd.so.1.6.0"),
        "--path", str(OLD / "inputs/mozilla-4096"),
        "--csv", str(csv), "--samples-json", str(report),
    ]
    started = time.time_ns()
    subprocess.run(argv, check=True)
    return argv, started, time.time_ns(), json.loads(report.read_text())


raw = []
reports = {}
for pair in range(15):
    order = ("baseline", "candidate") if pair % 2 == 0 else ("candidate", "baseline")
    for side in order:
        argv, started, finished, report = run(pair, side)
        reports[pair, side] = report
        raw.append({"pair": pair, "side": side, "argv": argv,
                    "started_ns": started, "finished_ns": finished})

samples = {side: [] for side in BINS}
process = {side: [] for side in BINS}
signatures = set()
for pair in range(15):
    for side in BINS:
        row = reports[pair, side]["rows"][0]
        signatures.add(json.dumps({"input": row["input_sha256"],
                                   "settings": {k: v for k, v in row["settings"].items() if k != "vort_profile"},
                                   "wires": row["wires"]}, sort_keys=True))
        samples[side].extend(round_["vort_ns"] for round_ in row["rounds"])
        process[side].append(row["summary"]["vort_median_ns"])
if len(signatures) != 1:
    raise RuntimeError("wire/settings mismatch")
baseline = statistics.median(samples["baseline"])
candidate = statistics.median(samples["candidate"])
result = {
    "baseline_ns": baseline, "candidate_ns": candidate,
    "ratio": candidate / baseline,
    "paired_wins": sum(process["candidate"][i] < process["baseline"][i] for i in range(15)),
    "pairs": 15, "samples_per_side": 30, "raw": raw,
}
(ROOT / "mozilla-long-comparison.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
print(json.dumps({k: v for k, v in result.items() if k != "raw"}, indent=2, sort_keys=True))
