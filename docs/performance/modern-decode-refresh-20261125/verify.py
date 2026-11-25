"""Verify the archived epoch without running the measured executable.

Use PYTHONPATH=tools/decode from the measured revision.
"""
import argparse
from collections import defaultdict
import gzip
import hashlib
import json
import math
from pathlib import Path
import statistics
import tarfile

from evidence import bootstrap_log_mean, require, summarize, validate_manifest, validate_report
from matrix import task_id


SEED = 0x20261125
RESAMPLES = 2000


def validate(folder):
    with gzip.open(folder / "manifest.json.gz", "rt") as handle:
        manifest = validate_manifest(json.load(handle))
    source = manifest["source"]
    require(hashlib.sha256(json.dumps(source["sha256"], sort_keys=True).encode()).hexdigest() == source["digest"], "Wrong source registry digest")
    summary = json.loads((folder / "summary.json").read_text())
    require(summary["complete"] and summary["completed_rows"] == summary["expected_rows"] == len(manifest["tasks"]) == 360,
            "Incomplete campaign")
    with gzip.open(folder / "probe.gz", "rb") as handle:
        require(hashlib.sha256(handle.read()).hexdigest() == manifest["probe_sha256"], "Wrong probe")

    rows = []
    with tarfile.open(folder / "raw-rows.tar.gz", "r:gz") as archive:
        names = {member.name for member in archive.getmembers() if member.isfile()}
        expected = set()
        for task in manifest["tasks"]:
            key = "rows/" + task_id(task)
            paths = [key + suffix for suffix in (".json", ".rss.txt", ".stderr.txt")]
            expected.update(paths)
            report = json.load(archive.extractfile(paths[0]))
            require(report["task"] == task, "Row bound to the wrong task")
            validate_report(report["probe"], task, manifest, verify_files=False)
            require(report["rss_kib"] == int(archive.extractfile(paths[1]).read()) > 0, "Missing or inconsistent RSS sidecar")
            require(not archive.extractfile(paths[2]).read(), f"Unexpected stderr in {key}")
            rows.append(report)
        require(names == expected, "Raw row archive member set differs from the manifest")
    require(summarize(rows, resamples=RESAMPLES) == summary["groups"], "Recorded size-group statistics do not reproduce")

    groups = defaultdict(list)
    for row in rows:
        groups[row["task"]["fixture"]["codec"], row["task"]["lifecycle"]].append(row)
    aggregate = {}
    for i, ((codec, lifecycle), group) in enumerate(sorted(groups.items())):
        stats = bootstrap_log_mean([r["probe"] for r in group], SEED + i, RESAMPLES)
        rate = lambda row, side, pair: row["task"]["fixture"]["input_bytes"] * row["task"]["iterations"] * 1e9 / (pair[side + "_ns"] * (1 << 20))
        weakest = max(group, key=lambda r: statistics.mean(math.log(p["vort_ns"] / p["reference_ns"]) for p in r["probe"]["pairs"]))
        rs = [r["rss_kib"] for r in group]
        aggregate[f"{codec}/{lifecycle}"] = {
            "rows": len(group),
            **stats,
            "vort_mib_per_second_geomean": math.exp(statistics.mean(math.log(rate(r, "vort", p)) for r in group for p in r["probe"]["pairs"])),
            "reference_mib_per_second_geomean": math.exp(statistics.mean(math.log(rate(r, "reference", p)) for r in group for p in r["probe"]["pairs"])),
            "paired_child_rss_kib": {"min": min(rs), "median": statistics.median(rs), "max": max(rs)},
            "weakest_task": task_id(weakest["task"]),
            "weakest_throughput_ratio": math.exp(statistics.mean(math.log(p["reference_ns"] / p["vort_ns"]) for p in weakest["probe"]["pairs"])),
        }
    return aggregate


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", type=Path)
    parser.add_argument("--emit-aggregate", action="store_true")
    args = parser.parse_args()
    result = validate(args.folder)
    if args.emit_aggregate:
        print(json.dumps(result, indent=2))
    else:
        require(json.loads((args.folder / "aggregate.json").read_text()) == result, "Aggregate result does not reproduce")
        print("Validated 360 rows, 2160 measured pairs, 720 warmup pairs, and all paired-child RSS sidecars")


if __name__ == "__main__":
    main()
