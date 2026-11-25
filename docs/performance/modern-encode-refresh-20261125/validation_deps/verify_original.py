"""Verify frozen allocating encoder records without executing codecs."""
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path
import random
import statistics
import sys

from collect import summary, require


def median(values):
    ordered = sorted(values)
    mid = len(ordered) // 2
    return ordered[mid] if len(ordered) % 2 else (ordered[mid - 1] + ordered[mid]) // 2


def verify(root, allow_partial=False):
    m = json.loads((root / "manifest.json").read_text())
    require(m["schema"] == "vort.current-encode-presets.v1", "Wrong epoch")
    tasks = m["tasks"]
    require(len(tasks) == 216 and len({t["id"] for t in tasks}) == 216, "Wrong task set")
    dimensions = {(t["codec"], t["size"], t["level"]) for t in tasks}
    expected = {(c, s, level) for c, levels in (("deflate", (6, 9)), ("zstd", (3, 19)), ("brotli", (8, 11))) for s in ("65536", "1048576", "full") for level in levels}
    require(dimensions == expected, "Missing preset or size")
    require(m["completed"] == [t["id"] for t in tasks[:len(m["completed"])]], "Non-prefix completion or discarded row")
    require(allow_partial or m["complete"] and len(m["completed"]) == 216, "Incomplete epoch")
    sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tools/codec_bench"))
    import sample_gate
    observed = []
    for task in tasks[:len(m["completed"])]:
        stem = task["id"]
        require((root / (stem + ".stderr")).read_bytes() == b"", "Unexpected probe stderr")
        report = json.loads((root / (stem + ".json")).read_text())
        require(report["codec"] == task["codec"] and len(report["rows"]) == 1, "Wrong codec/row scope")
        row = report["rows"][0]
        fixture = task["fixture"]
        require(row["input_bytes"] == fixture["input_bytes"] and row["input_sha256"] == fixture["input_sha256"], "Input identity drift")
        require(row["iterations"] == task["iterations"], "Iteration drift")
        p = report["provenance"]
        require(p["executable_sha256"] == m["probes"][task["codec"]]["sha256"], "Wrong executable")
        require(p["optimize"] == "ReleaseFast" and p["zig_version"] == "0.16.0" and p["target_cpu"] == "skylake+pku+sgx", "Wrong build mode")
        require(p["cpu_affinity"] == "15" and p["affinity_cpu_count"] == 1 and p["benchmark_threads"] == 1, "Wrong affinity")
        with (root / (stem + ".csv")).open(newline="") as handle:
            table = list(csv.DictReader(handle))
        require(len(table) == 1 and table[0]["input_sha256"] == fixture["input_sha256"], "Wrong CSV input")
        raw = row["rounds"]
        codec = task["codec"]
        sides = ("vort", "zlib", "libdeflate") if codec == "deflate" else ("vort", "reference")
        require(len(raw) == (5 if codec == "brotli" else 6), "Dropped raw rounds")
        if codec == "deflate":
            require(report["csv_aggregation"] == "median" and report["lifecycle"]["state"] == "cold_per_call", "Wrong Deflate lifecycle")
            require(row["settings"]["vort_level"] == task["level"] and row["settings"]["libdeflate_level"] == task["reference_level"], "Wrong Deflate levels")
            require(report["references"][1]["version"] == m["references"]["deflate"]["version"], "Wrong libdeflate header version")
            require(len(row["warmup_rounds"]) == 6, "Missing Deflate warmups")
        else:
            sample_gate.validate_settings(codec, row["settings"], row["input_bytes"])
            pins = m["references"][codec]
            for item in report["references"]:
                require(item["canonical_file_path"] in pins["file_sha256"] and item["file_sha256"] == pins["file_sha256"][item["canonical_file_path"]], "Reference file drift")
            if codec == "brotli":
                require(row["settings"]["parameters_match"] is True and row["settings"]["planned_quality"] == task["level"], "Wrong Brotli preset")
                require(row["settings"]["vort_command_state_max_input_kib"] == (8 if task["level"] == 11 else 255), "Wrong command state")
            else:
                require(row["settings"]["level"] == task["level"] and report["references"][0]["version"] == pins["version"], "Wrong Zstd preset")
        orders = [["vort", "zlib", "libdeflate"], ["zlib", "libdeflate", "vort"], ["libdeflate", "vort", "zlib"], ["vort", "libdeflate", "zlib"], ["libdeflate", "zlib", "vort"], ["zlib", "vort", "libdeflate"]]
        for series in ([raw, row["warmup_rounds"]] if codec == "deflate" else [raw]):
            for index, record in enumerate(series):
                require(record["index"] == index, "Wrong round index")
                require(record["order"] == orders[index] if codec == "deflate" else record["vort_first"] == (index % 2 == 0), "Wrong round order")
                for side in sides:
                    require(type(record[side + "_ns"]) is int and record[side + "_ns"] > 0, "Invalid raw time")
                    require(record[side + "_mix"] == row["wires"][side + "_bytes"] * task["iterations"] % (1 << 64), "Wire length drift")
        for side in sides:
            durations = [r[side + "_ns"] for r in raw]
            require(row["summary"][side + "_median_ns"] == median(durations), "Wrong median")
            require(row["summary"][side + "_min_ns"] == min(durations), "Wrong legacy minimum")
            require(int(table[0][side + "_ns"]) == (median(durations) if codec == "deflate" else min(durations)), "CSV statistic drift")
        observed.append((task, row))
    require(summary(root, m) == json.loads((root / "summary.json").read_text()), "Original summary does not reproduce")
    return observed


def aggregates(observed):
    groups = {}
    for task, row in observed:
        key = f'{task["codec"]}/{task["size"]}/L{task["level"]}'
        side = "libdeflate" if task["codec"] == "deflate" else "reference"
        strata = ([], [])
        for raw in row["rounds"]:
            first = raw["order"].index("vort") < raw["order"].index(side) if task["codec"] == "deflate" else raw["vort_first"]
            strata[int(first)].append(math.log(raw[side + "_ns"] / raw["vort_ns"]))
        groups.setdefault(key, []).append(strata)
    output = {}
    for index, (key, rows) in enumerate(sorted(groups.items())):
        rng = random.Random(0x20261125 + index)
        samples = []
        for _ in range(2000):
            means = [statistics.mean([rng.choice(a) for _ in a] + [rng.choice(b) for _ in b]) for a, b in rows]
            samples.append(math.exp(statistics.mean(means)))
        samples.sort()
        output[key] = {"rows": len(rows), "paired_throughput_ratio": math.exp(statistics.mean(statistics.mean(a + b) for a, b in rows)), "ci95": [samples[50], samples[1949]],
                       "method": "fixed-row, relative-order-stratified raw-round bootstrap; development host only"}
    return output


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    parser.add_argument("--allow-partial", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    rows = verify(args.capture, args.allow_partial)
    if args.output:
        args.output.write_text(json.dumps(aggregates(rows), indent=2) + "\n")
    print(f"Verified {len(rows)} complete allocating encoder conditions")
