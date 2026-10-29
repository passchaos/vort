#!/usr/bin/env python3
import json
import math
import pathlib
import statistics
import subprocess
import time

ROOT = pathlib.Path(__file__).resolve().parent
REFERENCE = ROOT / "reference-build"
NAMES = ("dickens", "mozilla", "mr", "nci", "ooffice", "osdb", "reymont", "samba", "sao", "webster", "x-ray", "xml")
SIZES = (4096, 16384, 65536)
SIDES = ("baseline", "candidate")


def run(side, sweep, name, size):
    output = ROOT / "formal"
    output.mkdir(exist_ok=True)
    json_path = output / f"{sweep}-{name}-{size}-{side}.json"
    csv_path = json_path.with_suffix(".csv")
    argv = [
        "taskset", "-c", "2", str(ROOT / f"bench-{side}"),
        "--quality", "8", "--planned-quality=8", "--planned-mode=generic",
        "--reference-lgwin=16", "--reference-mode=generic",
        "--iterations", "3", "--limit", str(size),
        "--samples-json", str(json_path), "--csv", str(csv_path),
        "--libbrotli-encoder", str(REFERENCE / "libbrotlienc.so.1.2.0"),
        "--libbrotli-decoder", str(REFERENCE / "libbrotlidec.so.1.2.0"),
        "--libbrotli-common", str(REFERENCE / "libbrotlicommon.so.1.2.0"),
        "--path", str(ROOT / "inputs" / f"{name}-{size}"),
    ]
    started = time.time_ns()
    subprocess.run(argv, check=True)
    return {"argv": argv, "started_ns": started, "finished_ns": time.time_ns()}


raw = []
for sweep in range(3):
    order = SIDES if sweep != 1 else tuple(reversed(SIDES))
    for size in SIZES:
        for name in NAMES:
            for side in order:
                raw.append(run(side, sweep, name, size))

samples = {}
process = {}
signatures = {}
reference = {}
for sweep in range(3):
    for size in SIZES:
        for name in NAMES:
            key = f"{name}-{size}"
            for side in SIDES:
                report = json.loads((ROOT / "formal" / f"{sweep}-{name}-{size}-{side}.json").read_text())
                if len(report["rows"]) != 1:
                    raise RuntimeError("unexpected row count")
                row = report["rows"][0]
                signature = json.dumps({
                    "input_sha256": row["input_sha256"],
                    "wires": row["wires"],
                    "settings": row["settings"],
                }, sort_keys=True)
                signatures.setdefault(key, set()).add(signature)
                samples.setdefault((key, side), []).extend(round_["vort_ns"] for round_ in row["rounds"])
                process[key, side, sweep] = row["summary"]["vort_median_ns"]
                if side == "candidate":
                    reference.setdefault(key, []).extend(round_["reference_ns"] for round_ in row["rounds"])

if any(len(values) != 1 for values in signatures.values()):
    raise RuntimeError("wire/settings mismatch")

rows = []
buckets = {size: [] for size in SIZES}
for size in SIZES:
    for name in NAMES:
        key = f"{name}-{size}"
        if len(samples[key, "baseline"]) != 15 or len(samples[key, "candidate"]) != 15:
            raise RuntimeError("sample count")
        baseline = statistics.median(samples[key, "baseline"])
        candidate = statistics.median(samples[key, "candidate"])
        ratio = candidate / baseline
        buckets[size].append(ratio)
        rows.append({
            "case": key,
            "input_bytes": size,
            "baseline_ns": baseline,
            "candidate_ns": candidate,
            "ratio": ratio,
            "candidate_over_reference": candidate / statistics.median(reference[key]),
        })
sweeps = []
for sweep in range(3):
    ratios = [process[row["case"], "candidate", sweep] / process[row["case"], "baseline", sweep] for row in rows]
    sweeps.append(math.exp(sum(map(math.log, ratios)) / len(ratios)))
summary = {
    "geomean": math.exp(sum(math.log(row["ratio"]) for row in rows) / len(rows)),
    "maximum": max(row["ratio"] for row in rows),
    "not_regressed": sum(row["ratio"] <= 1 for row in rows),
    "sweep_geomeans": sweeps,
    "buckets": {
        str(size): {
            "geomean": math.exp(sum(map(math.log, values)) / len(values)),
            "maximum": max(values),
        }
        for size, values in buckets.items()
    },
    "candidate_over_reference": math.exp(sum(math.log(row["candidate_over_reference"]) for row in rows) / len(rows)),
    "all_wires_settings_equal": True,
}
result = {"summary": summary, "rows": rows, "raw": raw}
(ROOT / "formal-comparison.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
print(json.dumps(summary, sort_keys=True))
