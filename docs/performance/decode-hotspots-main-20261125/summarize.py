"""Validate and reduce raw decode hotspot evidence, without executing codecs."""
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import re
import statistics

from evidence import require, validate_report


SAMPLE = re.compile(r"^\s*(\d+)\s+([0-9a-f]+)\s+(.*?)\s+\((.+)\)\s*$")


def summarize(root):
    manifest = json.loads((root / "manifest.json").read_text())
    source = manifest["source"]
    require(hashlib.sha256(json.dumps(source["sha256"], sort_keys=True).encode()).hexdigest() == source["digest"], "Wrong source registry digest")
    require(len(manifest["rows"]) == 6, "Incomplete capture")
    summary = {}
    for name, entry in manifest["rows"].items():
        task = entry["task"]
        fixture = task["fixture"]
        reports = {}
        for mode, group in (("wall", None), ("branches", "branches"), ("branch-misses", "branch-misses"), ("profile", None)):
            config = {**manifest["config"], "perf_group": group}
            observed_task = task
            if mode == "profile":
                config.update(warmup=0, rounds=2)
                observed_task = {**task, "iterations": entry["profile_iterations"]}
            report = json.loads((root / (name + "." + mode + ".json")).read_text())
            validate_report(report, observed_task, {**manifest, "config": config}, verify_files=False)
            reports[mode] = report

        wall = reports["wall"]
        byte_count = wall["iterations"] * wall["input_bytes"]
        normalized = lambda group, field, scale=1: statistics.median(x["vort_counters"][field] * scale / byte_count for x in reports[group]["pairs"])
        symbols = Counter()
        dsos = Counter()
        periods = []
        for line in (root / (name + ".samples.txt")).read_text().splitlines():
            if not line.strip():
                continue
            match = SAMPLE.fullmatch(line)
            require(match is not None, "Unparseable perf sample")
            period, _, symbol, path = match.groups()
            dso = Path(path).name
            weight = int(period)
            periods.append(weight)
            symbols[dso, symbol] += weight
            dsos[dso] += weight
        require(periods == [int(x) for x in (root / (name + ".periods.txt")).read_text().split()], "Symbolization changed sample periods")
        total = sum(periods)
        require(len(periods) >= 500 and total > 0, "Incomplete sample capture")
        result = {
            "vort_over_reference_wall_throughput": math.exp(statistics.mean(math.log(x["reference_ns"] / x["vort_ns"]) for x in wall["pairs"])),
            "vort_wall_median_ns": wall["summary"]["vort_median_ns"],
            "reference_wall_median_ns": wall["summary"]["reference_median_ns"],
            "vort_cycles_per_output_byte": normalized("branches", "cycles"),
            "vort_instructions_per_output_byte": normalized("branches", "instructions"),
            "vort_branches_per_output_byte": normalized("branches", "third_event"),
            "vort_branch_misses_per_output_kib": normalized("branch-misses", "third_event", 1024),
            "profile_samples": len(periods),
            "profile_total_period": total,
            "whole_child_dso_percent": {d: 100*v/total for d,v in dsos.most_common()},
            "top_self_symbols": [
                {"dso": d, "symbol": s, "period": v, "whole_child_percent": 100*v/total}
                for (d,s),v in symbols.most_common(15)
            ],
        }
        if fixture["codec"] == "brotli":
            payload = json.loads((root / (name + ".payload.json")).read_text())
            require(payload["wire_sha256"] == fixture["encoded_sha256"] and payload["plain_sha256"] == fixture["input_sha256"], "Payload counts came from a different fixture")
            require(payload["executable_sha256"] == manifest["payload_probe_sha256"], "Wrong payload diagnostic executable")
            s = payload["summary"]
            require(s["decoded_bytes"] == fixture["input_bytes"], "Wrong logical decoded length")
            result["brotli_payload_counts"] = {k: s[k] for k in ("command_count", "distance_prepared_hit_count", "distance_long_fallback_count", "distance_prepared_build_count", "max_distance_postfix_bits")}
            result["brotli_commands_per_kib"] = s["command_count"] * 1024 / s["decoded_bytes"]
        summary[name] = result
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    parser.add_argument("--verify", type=Path)
    args = parser.parse_args()
    result = summarize(args.capture)
    if args.verify is None:
        print(json.dumps(result, indent=2))
    else:
        require(json.loads(args.verify.read_text()) == result, "Diagnostic summary does not reproduce")
        print("Verified all six timing/counter/sample rows and three logical payload reports")


if __name__ == "__main__":
    main()
