#!/usr/bin/env python3
import json
import math
import pathlib
import statistics
import subprocess
import time

ROOT = pathlib.Path("/tmp/vort-br-prepared-optimal-20261030.XBy5BR")
INPUTS = pathlib.Path("/tmp/vort-br-standard-writer-stack-20261030.3C2lxq/inputs")
REFERENCE = pathlib.Path("/tmp/vort-br-standard-writer-stack-20261030.3C2lxq/reference-build")
BINARIES = {
    "head": ROOT / "baseline-src/.zig-cache/o/cdfc72d621654ebd6e7ff569556e0df2/vort-br-planned-encode-bench",
    "layout": ROOT / "layout-src/.zig-cache/o/0af0cb3c2b1079ab928e837aebc4fecd/vort-br-planned-encode-bench",
    "reuse": ROOT / "candidate-src/.zig-cache/o/16b4c3d4dc0e80f334a73696f29624dc/vort-br-planned-encode-bench",
}
NAMES = ("dickens", "mr", "nci")
SIDES = ("head", "layout", "reuse")
ORDERS = (
    ("head", "layout", "reuse"),
    ("reuse", "layout", "head"),
    ("layout", "head", "reuse"),
)


def run(side, quality, limit, sweep):
    output = ROOT / "screen4"
    output.mkdir(exist_ok=True)
    report = output / f"q{quality}-{limit}-{sweep}-{side}.json"
    csv = report.with_suffix(".csv")
    argv = [
        "taskset", "-c", "2", str(BINARIES[side]),
        "--quality", str(quality), f"--planned-quality={quality}",
        "--planned-mode=generic", "--reference-lgwin=16",
        "--reference-mode=generic", "--iterations", "3",
        "--limit", str(limit), "--samples-json", str(report),
        "--csv", str(csv),
        "--libbrotli-encoder", str(REFERENCE / "libbrotlienc.so.1.2.0"),
        "--libbrotli-decoder", str(REFERENCE / "libbrotlidec.so.1.2.0"),
        "--libbrotli-common", str(REFERENCE / "libbrotlicommon.so.1.2.0"),
    ]
    for name in NAMES:
        argv.extend(("--path", str(INPUTS / f"{name}-65536")))
    if report.exists():
        return argv, None, None, json.loads(report.read_text())
    started = time.time_ns()
    subprocess.run(argv, check=True)
    return argv, started, time.time_ns(), json.loads(report.read_text())


raw = []
reports = {}
for quality in (10, 11):
    for limit in (16384, 32768):
        for sweep, order in enumerate(ORDERS):
            for side in order:
                argv, started, finished, report = run(side, quality, limit, sweep)
                raw.append({"quality": quality, "limit": limit, "sweep": sweep,
                            "side": side, "argv": argv,
                            "started_ns": started, "finished_ns": finished})
                reports[quality, limit, sweep, side] = report

rows = []
for quality in (10, 11):
    for limit in (16384, 32768):
        for row_index, name in enumerate(NAMES):
            samples = {side: [] for side in SIDES}
            signatures = set()
            for sweep in range(len(ORDERS)):
                for side in SIDES:
                    row = reports[quality, limit, sweep, side]["rows"][row_index]
                    signatures.add(json.dumps({
                        "input": row["input_sha256"],
                        "wires": row["wires"],
                        "settings": row["settings"],
                    }, sort_keys=True))
                    samples[side].extend(round_["vort_ns"] for round_ in row["rounds"])
            if len(signatures) != 1 or any(len(samples[side]) != 15 for side in SIDES):
                raise RuntimeError("wire, settings, or sample mismatch")
            medians = {side: statistics.median(samples[side]) for side in SIDES}
            rows.append({
                "quality": quality,
                "limit": limit,
                "name": name,
                "samples_per_side": 15,
                "medians_ns": medians,
                "layout_head_ratio": medians["layout"] / medians["head"],
                "reuse_head_ratio": medians["reuse"] / medians["head"],
                "reuse_layout_ratio": medians["reuse"] / medians["layout"],
            })


def geomean(field, selected):
    values = [row[field] for row in selected]
    return math.exp(sum(math.log(value) for value in values) / len(values))


summary = {}
for quality in (10, 11):
    selected = [row for row in rows if row["quality"] == quality]
    summary[f"q{quality}"] = {
        "layout_head_geomean": geomean("layout_head_ratio", selected),
        "reuse_head_geomean": geomean("reuse_head_ratio", selected),
        "reuse_layout_geomean": geomean("reuse_layout_ratio", selected),
        "maximum_reuse_head": max(row["reuse_head_ratio"] for row in selected),
    }
summary["combined"] = {
    "layout_head_geomean": geomean("layout_head_ratio", rows),
    "reuse_head_geomean": geomean("reuse_head_ratio", rows),
    "reuse_layout_geomean": geomean("reuse_layout_ratio", rows),
    "all_wires_settings_equal": True,
}
result = {"summary": summary, "rows": rows, "raw": raw}
(ROOT / "screen4-comparison.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
print(json.dumps(summary, indent=2, sort_keys=True))
