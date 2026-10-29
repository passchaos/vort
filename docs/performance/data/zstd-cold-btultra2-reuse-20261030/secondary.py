#!/usr/bin/env python3
import copy
import json
import math
import pathlib
import statistics
import subprocess
import time

ROOT = pathlib.Path("/tmp/vort-zstd-cold-reuse-20261030.mQDBSt")
OLD = pathlib.Path("/tmp/vort-zstd-node40-20261029.SzGYUk")
LIB = OLD / "libzstd.so.1.6.0"
BINS = {
    "baseline": ROOT / "baseline-src/.zig-cache/o/e6e32eaf4ed7e48cbf073f813c08647c/vort-zstd-encode-bench",
    "candidate": ROOT / "candidate-src/.zig-cache/o/b4b81d4fa10c49be4edbe62380f60513/vort-zstd-encode-bench",
}
NEW_PROFILE = (
    "rep_length_cache_hits", "match_frontier_cache_entries",
    "match_frontier_replay_positions", "match_frontier_cache_fallbacks",
)
CONFIGS = {
    "16k": {
        "paths": [OLD / f"inputs/{name}-16384" for name in ("dickens", "mozilla", "mr")],
        "dictionary": None,
    },
    "trained": {
        "paths": [OLD / "inputs/trained-reference"],
        "dictionary": OLD / "inputs/trained.dict",
    },
}


def run(config, sweep, side):
    out = ROOT / "secondary"
    out.mkdir(exist_ok=True)
    report = out / f"{sweep}-{config}-{side}.json"
    csv = report.with_suffix(".csv")
    argv = [
        "taskset", "-c", "2", str(BINS[side]), "--match-hq",
        "--strategy", "btultra2", "--window-log", "17",
        "--iterations", "1", "--rounds", "2", "--limit", "16384",
        "--libzstd", str(LIB), "--csv", str(csv),
        "--samples-json", str(report),
    ]
    for path in CONFIGS[config]["paths"]:
        argv.extend(("--path", str(path)))
    if CONFIGS[config]["dictionary"] is not None:
        argv.extend(("--dictionary", str(CONFIGS[config]["dictionary"])))
    started = time.time_ns()
    subprocess.run(argv, check=True)
    return argv, started, time.time_ns(), json.loads(report.read_text())


reports = {}
raw = []
for sweep in range(8):
    order = ("baseline", "candidate") if sweep % 2 == 0 else ("candidate", "baseline")
    for config in CONFIGS:
        for side in order:
            argv, started, finished, report = run(config, sweep, side)
            reports[config, sweep, side] = report
            raw.append({"config": config, "sweep": sweep, "side": side,
                        "argv": argv, "started_ns": started,
                        "finished_ns": finished})


rows = []
for config, definition in CONFIGS.items():
    for index, path in enumerate(definition["paths"]):
        samples = {side: [] for side in BINS}
        process = {side: [] for side in BINS}
        signatures = set()
        profiles = {side: [] for side in BINS}
        for sweep in range(8):
            for side in BINS:
                row = reports[config, sweep, side]["rows"][index]
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
        if config == "trained":
            for candidate_profile in profiles["candidate"]:
                for field in NEW_PROFILE:
                    if candidate_profile.pop(field) != 0:
                        raise RuntimeError("dictionary control entered cache path")
            if any(profile != profiles["baseline"][0] for profile in profiles["baseline"]):
                raise RuntimeError("baseline profile drift")
            if any(profile != profiles["baseline"][0] for profile in profiles["candidate"]):
                raise RuntimeError("dictionary control profile changed")
        baseline = statistics.median(samples["baseline"])
        candidate = statistics.median(samples["candidate"])
        rows.append({
            "config": config, "case": path.name,
            "baseline_ns": baseline, "candidate_ns": candidate,
            "ratio": candidate / baseline,
            "paired_wins": sum(process["candidate"][i] < process["baseline"][i] for i in range(8)),
            "samples_per_side": 16,
            "baseline_peak": profiles["baseline"][0]["peak_working_memory"],
            "candidate_peak": profiles["candidate"][0]["peak_working_memory"],
            "candidate_cache": {field: profiles["candidate"][0].get(field, 0) for field in NEW_PROFILE},
        })


active = [row for row in rows if row["config"] == "16k"]
summary = {
    "active_geomean": math.exp(sum(math.log(row["ratio"]) for row in active) / len(active)),
    "active_maximum": max(row["ratio"] for row in active),
    "active_paired_wins": sum(row["paired_wins"] for row in active),
    "trained_ratio": next(row["ratio"] for row in rows if row["config"] == "trained"),
}
result = {"summary": summary, "rows": rows, "raw": raw,
          "all_input_wire_settings_equal": True}
(ROOT / "secondary-comparison.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
print(json.dumps(summary, indent=2, sort_keys=True))
for row in rows:
    print(json.dumps(row, sort_keys=True))
