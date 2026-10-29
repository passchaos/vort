#!/usr/bin/env python3
import copy
import json
import pathlib
import statistics
import subprocess
import time

ROOT = pathlib.Path("/tmp/vort-zstd-node40-natural-20261030.cTK9BU")
INPUT = pathlib.Path("/tmp/vort-zstd-node40-20261029.SzGYUk/inputs/mozilla-4096")
LIB = pathlib.Path("/tmp/vort-zstd-node40-20261029.SzGYUk/libzstd.so.1.6.0")
BINS = {
    "baseline": ROOT / "baseline-src/.zig-cache/o/e56759d3074076e548dd61844bb5284f/vort-zstd-encode-bench",
    "candidate": ROOT / "candidate-src/.zig-cache/o/7dec2ac12bcbc40ba807a923f9c2eaa5/vort-zstd-encode-bench",
}


def run(strategy, sweep, side):
    out = ROOT / "pilot"
    out.mkdir(exist_ok=True)
    report = out / f"{sweep}-{strategy}-{side}.json"
    csv = report.with_suffix(".csv")
    argv = [
        "taskset", "-c", "2", str(BINS[side]), "--match-hq",
        "--strategy", strategy, "--window-log", "15",
        "--iterations", "1", "--rounds", "2", "--limit", "4096",
        "--libzstd", str(LIB), "--path", str(INPUT),
        "--csv", str(csv), "--samples-json", str(report),
    ]
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
                        "argv": argv, "started_ns": started, "finished_ns": finished})


rows = []
for strategy in ("btopt", "btultra2"):
    samples = {side: [] for side in BINS}
    signatures = set()
    peaks = {}
    for sweep in range(8):
        for side in BINS:
            row = reports[strategy, sweep, side]["rows"][0]
            settings = copy.deepcopy(row["settings"])
            profile = settings["vort_profile"]
            peaks[side] = profile.pop("peak_working_memory")
            signatures.add(json.dumps({"input": row["input_sha256"],
                                       "settings": settings,
                                       "wires": row["wires"]}, sort_keys=True))
            samples[side].extend(round_["vort_ns"] for round_ in row["rounds"])
    if len(signatures) != 1 or any(len(samples[side]) != 16 for side in BINS):
        raise RuntimeError("wire/settings/sample mismatch")
    baseline = statistics.median(samples["baseline"])
    candidate = statistics.median(samples["candidate"])
    rows.append({"strategy": strategy, "baseline_ns": baseline,
                 "candidate_ns": candidate, "ratio": candidate / baseline,
                 "samples_per_side": 16, "peak_working_memory": peaks})

result = {"rows": rows, "raw": raw, "all_wires_settings_except_peak_equal": True}
(ROOT / "pilot-comparison.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
print(json.dumps(rows, indent=2, sort_keys=True))
