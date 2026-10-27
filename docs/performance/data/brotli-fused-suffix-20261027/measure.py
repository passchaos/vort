#!/usr/bin/env python3
"""Retain interleaved component timings and require complete proposal equality."""
import argparse
import csv
import json
import lzma
import math
import statistics
import subprocess
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--executable", action="append", required=True, help="label=path; first label is baseline")
    parser.add_argument("--corpus", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--cpu", type=int, default=2)
    parser.add_argument("--blocks", type=int, default=5)
    parser.add_argument("--rounds", type=int, default=9)
    options = parser.parse_args()
    executables = dict(value.split("=", 1) for value in options.executable)
    if len(executables) != len(options.executable) or len(executables) < 2 or options.blocks < 1:
        parser.error("provide at least two distinct labels and positive blocks")
    paths = sorted(path for path in options.corpus.iterdir() if path.is_file())
    if len(paths) != 12:
        parser.error("expected exactly 12 Silesia files")
    records = []
    shapes = {}
    samples = {}
    for block in range(options.blocks):
        labels = list(executables)
        if block % 2:
            labels.reverse()
        for limit in (4096, 16384, 65536):
            for label in labels:
                command = ["taskset", "-c", str(options.cpu), executables[label], "--limit", str(limit), "--rounds", str(options.rounds)]
                for path in paths:
                    command.extend(("--path", str(path)))
                result = json.loads(subprocess.check_output(command))
                if result["schema"] != "vort.brotli.literal-context-search.v1" or len(result["rows"]) != 12:
                    raise RuntimeError("unexpected benchmark result")
                for row in result["rows"]:
                    if not row["reference_equal"] or not row["profile_equal"]:
                        raise RuntimeError("proposal oracle mismatch")
                    key = (row["path"], limit)
                    shape = (row["input_bytes"], row["input_sha256"], row["proposals"])
                    if key in shapes and shapes[key] != shape:
                        raise RuntimeError(f"input or proposal mismatch: {key}")
                    shapes[key] = shape
                    times = row["normal_ns"]
                    if len(times) != options.rounds or any(type(ns) is not int or ns <= 0 for ns in times):
                        raise RuntimeError("invalid raw timing samples")
                    samples.setdefault((key, label), []).append(min(times))
                records.append({"block": block, "limit": limit, "label": label, "command": command, "result": result})
    baseline = next(iter(executables))
    rows = []
    ratios = {label: [] for label in executables if label != baseline}
    for key, shape in sorted(shapes.items()):
        base_ns = statistics.median(samples[key, baseline])
        row = {"case": Path(key[0]).name, "input_bytes": shape[0], "input_sha256": shape[1]}
        for label in executables:
            ns = statistics.median(samples[key, label])
            row[label + "_ns"] = ns
            if label != baseline:
                row[label + "_over_baseline"] = ns / base_ns
                ratios[label].append(ns / base_ns)
        rows.append(row)
    summary = {
        "schema": "vort.brotli.literal-context-comparison.v1",
        "baseline": baseline,
        "executables": executables,
        "blocks": options.blocks,
        "rounds_per_block": options.rounds,
        "aggregation": "median across blocks of minimum ordinary search time per block",
        "cases": len(rows),
        "all_proposals_equal": True,
        "geometric_ratios": {label: math.exp(statistics.mean(math.log(value) for value in values)) for label, values in ratios.items()},
        "rows": rows,
    }
    options.output.mkdir(parents=True, exist_ok=True)
    (options.output / "raw.json.xz").write_bytes(lzma.compress(json.dumps(records, separators=(",", ":")).encode()))
    (options.output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    with (options.output / "rows.csv").open("w", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    print(json.dumps({key: summary[key] for key in ("cases", "all_proposals_equal", "geometric_ratios")}))


if __name__ == "__main__":
    main()
