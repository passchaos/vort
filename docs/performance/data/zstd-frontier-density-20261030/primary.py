#!/usr/bin/env python3
import copy
import json
import math
import pathlib
import statistics
import subprocess
import time

ROOT = pathlib.Path("/tmp/vort-zstd-frontier2-20261030.vVmijM")
OLD = pathlib.Path("/tmp/vort-zstd-node40-20261029.SzGYUk")
LIB = OLD / "libzstd.so.1.6.0"
BINS = {
    "baseline": ROOT / "baseline-src/.zig-cache/o/981634e7f8d9acf06c73c74d01e74ef6/vort-zstd-encode-bench",
    "candidate": ROOT / "candidate-src/.zig-cache/o/c76d92dc43e8433f014664ef1bcefcaa/vort-zstd-encode-bench",
}
CASES = ("dickens", "mozilla", "mr")
NEW_PROFILE = (
    "rep_length_cache_hits", "match_frontier_cache_entries",
    "match_frontier_replay_positions", "match_frontier_cache_fallbacks",
)


def run(strategy, sweep, side):
    out = ROOT / "primary"
    out.mkdir(exist_ok=True)
    report = out / f"{sweep}-{strategy}-{side}.json"
    csv = report.with_suffix(".csv")
    argv = [
        "taskset", "-c", "2", str(BINS[side]), "--match-hq",
        "--strategy", strategy, "--window-log", "15",
        "--iterations", "1", "--rounds", "2", "--limit", "4096",
        "--libzstd", str(LIB), "--csv", str(csv),
        "--samples-json", str(report),
    ]
    for name in CASES:
        argv.extend(("--path", str(OLD / f"inputs/{name}-4096")))
    if report.exists():
        return argv, None, None, json.loads(report.read_text())
    started = time.time_ns()
    subprocess.run(argv, check=True)
    return argv, started, time.time_ns(), json.loads(report.read_text())


reports = {}
raw = []
for sweep in range(8):
    order = ("baseline", "candidate") if sweep % 2 == 0 else ("candidate", "baseline")
    for strategy in ("btopt", "btultra2"):
        for side in order:
            argv, started, finished, report = run(strategy, sweep, side)
            reports[strategy, sweep, side] = report
            raw.append({"strategy": strategy, "sweep": sweep, "side": side,
                        "argv": argv, "started_ns": started,
                        "finished_ns": finished})


rows = []
for strategy in ("btopt", "btultra2"):
    for index, name in enumerate(CASES):
        samples = {side: [] for side in BINS}
        process = {side: [] for side in BINS}
        signatures = set()
        profiles = {side: [] for side in BINS}
        for sweep in range(8):
            for side in BINS:
                row = reports[strategy, sweep, side]["rows"][index]
                settings = copy.deepcopy(row["settings"])
                profile = settings.pop("vort_profile")
                profiles[side].append(profile)
                signatures.add(json.dumps({"input": row["input_sha256"],
                                           "settings": settings,
                                           "wires": row["wires"]}, sort_keys=True))
                samples[side].extend(round_["vort_ns"] for round_ in row["rounds"])
                process[side].append(row["summary"]["vort_median_ns"])
        if len(signatures) != 1 or any(len(samples[side]) != 16 for side in BINS):
            raise RuntimeError("wire/settings/sample mismatch")
        if strategy == "btopt":
            for side in BINS:
                for candidate_profile in profiles[side]:
                    for field in NEW_PROFILE:
                        if candidate_profile[field] != 0:
                            raise RuntimeError("btopt entered cache path")
            if any(profile != profiles["baseline"][0] for profile in profiles["baseline"]):
                raise RuntimeError("baseline profile drift")
            if any(profile != profiles["baseline"][0] for profile in profiles["candidate"]):
                raise RuntimeError("btopt profile changed")
        baseline = statistics.median(samples["baseline"])
        candidate = statistics.median(samples["candidate"])
        rows.append({
            "strategy": strategy, "case": name,
            "baseline_ns": baseline, "candidate_ns": candidate,
            "ratio": candidate / baseline,
            "paired_wins": sum(process["candidate"][i] < process["baseline"][i] for i in range(8)),
            "samples_per_side": 16,
            "baseline_peak": profiles["baseline"][0]["peak_working_memory"],
            "candidate_peak": profiles["candidate"][0]["peak_working_memory"],
            "candidate_cache": {field: profiles["candidate"][0].get(field, 0) for field in NEW_PROFILE},
        })


summary = {}
for strategy in ("btopt", "btultra2"):
    selected = [row for row in rows if row["strategy"] == strategy]
    summary[strategy] = {
        "geomean": math.exp(sum(math.log(row["ratio"]) for row in selected) / len(selected)),
        "maximum": max(row["ratio"] for row in selected),
        "paired_wins": sum(row["paired_wins"] for row in selected),
    }
result = {"summary": summary, "rows": rows, "raw": raw,
          "all_input_wire_settings_equal": True}
(ROOT / "primary-comparison.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
print(json.dumps(summary, indent=2, sort_keys=True))
for row in rows:
    print(json.dumps(row, sort_keys=True))
