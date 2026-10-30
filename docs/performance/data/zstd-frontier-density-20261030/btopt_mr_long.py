#!/usr/bin/env python3
import json
import pathlib
import statistics
import subprocess

ROOT = pathlib.Path("/tmp/vort-zstd-frontier2-20261030.vVmijM")
OLD = pathlib.Path("/tmp/vort-zstd-node40-20261029.SzGYUk")
BINS = {
    "baseline": ROOT / "baseline-src/.zig-cache/o/981634e7f8d9acf06c73c74d01e74ef6/vort-zstd-encode-bench",
    "candidate": ROOT / "candidate-src/.zig-cache/o/c76d92dc43e8433f014664ef1bcefcaa/vort-zstd-encode-bench",
}
reports = {}
raw = []
out = ROOT / "btopt-mr-long"
out.mkdir(exist_ok=True)
for pair in range(15):
    order = ("baseline", "candidate") if pair % 2 == 0 else ("candidate", "baseline")
    for side in order:
        report = out / f"{pair}-{side}.json"
        csv = report.with_suffix(".csv")
        argv = ["taskset", "-c", "2", str(BINS[side]), "--match-hq",
                "--strategy", "btopt", "--window-log", "15",
                "--iterations", "1", "--rounds", "2", "--limit", "4096",
                "--libzstd", str(OLD / "libzstd.so.1.6.0"),
                "--path", str(OLD / "inputs/mr-4096"),
                "--csv", str(csv), "--samples-json", str(report)]
        subprocess.run(argv, check=True)
        reports[pair, side] = json.loads(report.read_text())
        raw.append({"pair": pair, "side": side, "argv": argv})
samples = {side: [] for side in BINS}
process = {side: [] for side in BINS}
signatures = set()
for pair in range(15):
    for side in BINS:
        row = reports[pair, side]["rows"][0]
        profile = row["settings"]["vort_profile"]
        for field in ("rep_length_cache_hits", "match_frontier_cache_entries", "match_frontier_replay_positions", "match_frontier_cache_fallbacks"):
            if profile[field] != 0: raise RuntimeError("control entered cache path")
        signatures.add(json.dumps({"input": row["input_sha256"], "wires": row["wires"]}, sort_keys=True))
        samples[side].extend(r["vort_ns"] for r in row["rounds"])
        process[side].append(row["summary"]["vort_median_ns"])
if len(signatures) != 1: raise RuntimeError("wire mismatch")
baseline = statistics.median(samples["baseline"])
candidate = statistics.median(samples["candidate"])
result = {"baseline_ns": baseline, "candidate_ns": candidate,
          "ratio": candidate / baseline, "pairs": 15,
          "paired_wins": sum(process["candidate"][i] < process["baseline"][i] for i in range(15)),
          "samples_per_side": 30, "raw": raw}
(ROOT / "btopt-mr-long-comparison.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
print(json.dumps({k:v for k,v in result.items() if k != "raw"}, indent=2, sort_keys=True))
