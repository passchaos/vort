#!/usr/bin/env python3
import hashlib
import json
import math
import pathlib
import statistics
import subprocess
import time

ROOT = pathlib.Path(__file__).resolve().parent
REFERENCE = ROOT / "reference-build"
NAMES = ("mozilla", "dickens", "mr")
SIDES = ("baseline", "candidate")


def run(side, sweep, name):
    output = ROOT / "pilot"
    output.mkdir(exist_ok=True)
    json_path = output / f"{sweep}-{name}-{side}.json"
    csv_path = json_path.with_suffix(".csv")
    argv = [
        "taskset", "-c", "2", str(ROOT / f"bench-{side}"),
        "--quality", "8", "--planned-quality=8", "--planned-mode=generic",
        "--reference-lgwin=16", "--reference-mode=generic",
        "--iterations", "3", "--limit", "65536",
        "--samples-json", str(json_path), "--csv", str(csv_path),
        "--libbrotli-encoder", str(REFERENCE / "libbrotlienc.so.1.2.0"),
        "--libbrotli-decoder", str(REFERENCE / "libbrotlidec.so.1.2.0"),
        "--libbrotli-common", str(REFERENCE / "libbrotlicommon.so.1.2.0"),
        "--path", str(ROOT / "inputs" / f"{name}-65536"),
    ]
    started = time.time_ns()
    subprocess.run(argv, check=True)
    return {"argv": argv, "started_ns": started, "finished_ns": time.time_ns()}


raw = []
for sweep in range(3):
    order = SIDES if sweep != 1 else tuple(reversed(SIDES))
    for name in NAMES:
        for side in order:
            raw.append(run(side, sweep, name))

samples = {}
process = {}
signatures = {}
for sweep in range(3):
    for name in NAMES:
        for side in SIDES:
            report = json.loads((ROOT / "pilot" / f"{sweep}-{name}-{side}.json").read_text())
            if len(report["rows"]) != 1:
                raise RuntimeError("unexpected row count")
            row = report["rows"][0]
            signature = json.dumps({
                "input_sha256": row["input_sha256"],
                "wires": row["wires"],
                "settings": row["settings"],
            }, sort_keys=True)
            signatures.setdefault(name, set()).add(signature)
            samples.setdefault((name, side), []).extend(round_["vort_ns"] for round_ in row["rounds"])
            process[name, side, sweep] = row["summary"]["vort_median_ns"]

if any(len(values) != 1 for values in signatures.values()):
    raise RuntimeError("wire/settings mismatch")

rows = []
for name in NAMES:
    baseline = statistics.median(samples[name, "baseline"])
    candidate = statistics.median(samples[name, "candidate"])
    rows.append({"case": name, "baseline_ns": baseline, "candidate_ns": candidate, "ratio": candidate / baseline})
sweeps = []
for sweep in range(3):
    ratios = [process[name, "candidate", sweep] / process[name, "baseline", sweep] for name in NAMES]
    sweeps.append(math.exp(sum(map(math.log, ratios)) / len(ratios)))
summary = {
    "geomean": math.exp(sum(math.log(row["ratio"]) for row in rows) / len(rows)),
    "maximum": max(row["ratio"] for row in rows),
    "improved": sum(row["ratio"] < 1 for row in rows),
    "sweep_geomeans": sweeps,
    "all_wires_settings_equal": True,
}
result = {"summary": summary, "rows": rows, "raw": raw}
(ROOT / "pilot-comparison.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
print(json.dumps(summary, sort_keys=True))
