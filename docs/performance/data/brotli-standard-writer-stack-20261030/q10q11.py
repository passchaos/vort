#!/usr/bin/env python3
import json
import math
import pathlib
import statistics
import subprocess
import time

ROOT = pathlib.Path(__file__).resolve().parent
REFERENCE = ROOT / "reference-build"
INPUT = ROOT / "source32k.bin"
SIDES = ("baseline", "candidate")


def run(side, quality, sweep):
    output = ROOT / "q10q11"
    output.mkdir(exist_ok=True)
    report = output / f"q{quality}-{sweep}-{side}.json"
    csv = report.with_suffix(".csv")
    argv = [
        "taskset", "-c", "2", str(ROOT / f"bench-{side}"),
        "--quality", str(quality), f"--planned-quality={quality}",
        "--planned-mode=generic", "--reference-lgwin=16",
        "--reference-mode=generic", "--iterations", "3", "--limit", "32768",
        "--samples-json", str(report), "--csv", str(csv),
        "--libbrotli-encoder", str(REFERENCE / "libbrotlienc.so.1.2.0"),
        "--libbrotli-decoder", str(REFERENCE / "libbrotlidec.so.1.2.0"),
        "--libbrotli-common", str(REFERENCE / "libbrotlicommon.so.1.2.0"),
        "--path", str(INPUT),
    ]
    started = time.time_ns()
    subprocess.run(argv, check=True)
    return argv, started, time.time_ns(), report


raw = []
reports = {}
for quality in (10, 11):
    for sweep in range(3):
        order = SIDES if sweep != 1 else tuple(reversed(SIDES))
        for side in order:
            argv, started, finished, report = run(side, quality, sweep)
            raw.append({"quality": quality, "sweep": sweep, "side": side,
                        "argv": argv, "started_ns": started, "finished_ns": finished})
            reports[quality, sweep, side] = json.loads(report.read_text())

rows = []
for quality in (10, 11):
    samples = {side: [] for side in SIDES}
    signatures = set()
    process = {side: [] for side in SIDES}
    for sweep in range(3):
        for side in SIDES:
            row = reports[quality, sweep, side]["rows"][0]
            signatures.add(json.dumps({"input": row["input_sha256"],
                                       "wires": row["wires"],
                                       "settings": row["settings"]}, sort_keys=True))
            samples[side].extend(round_["vort_ns"] for round_ in row["rounds"])
            process[side].append(row["summary"]["vort_median_ns"])
    if len(signatures) != 1 or any(len(samples[side]) != 15 for side in SIDES):
        raise RuntimeError("wire, settings, or sample mismatch")
    baseline = statistics.median(samples["baseline"])
    candidate = statistics.median(samples["candidate"])
    rows.append({
        "quality": quality,
        "baseline_ns": baseline,
        "candidate_ns": candidate,
        "ratio": candidate / baseline,
        "sweep_ratios": [process["candidate"][i] / process["baseline"][i] for i in range(3)],
        "sample_count_per_side": 15,
    })

result = {
    "summary": {
        "geomean": math.exp(sum(math.log(row["ratio"]) for row in rows) / len(rows)),
        "maximum": max(row["ratio"] for row in rows),
        "all_wires_settings_equal": True,
    },
    "rows": rows,
    "raw": raw,
}
(ROOT / "q10q11-comparison.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
print(json.dumps(result["summary"], sort_keys=True))
for row in rows:
    print(json.dumps(row, sort_keys=True))
