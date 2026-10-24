#!/usr/bin/env python3
"""Bounded public Brotli complete-copy-length wire and search-budget checks."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import random
import sys

sys.dont_write_bytecode = True
from hq_controls_diff import ROOT, Reference, digest, probe_call, require
from large_window_diff import LargeReference, header

OLD_REVISION = "34dbe96ae7b57f4eb9d36b0821be1ff700d26508"


def samples(directory):
    prefix = random.Random(0x34dbe96a).randbytes(128)
    dictionary_path = directory / "lengths-raw.dictionary"
    if dictionary_path.exists():require(dictionary_path.read_bytes() == prefix, "frozen tiny dictionary changed")
    else:dictionary_path.write_bytes(prefix)
    base = {"hq": True, "search_depth": 16, "nice_len": 64, "beam_width": 2, "iterations": 1,
            "block_len": 64, "input_chunk": 17, "output_chunk": 13, "npostfix": 0, "ndirect_high": 0}
    payload = b"abc" * 16
    cases = []
    for api in ("one_shot", "chunks", "incremental"):
        for parse_mode in ("bounded", "whole_block"):
            for large, window in ((False, 16), (True, 25)):
                for quality in (10, 11):
                    cases.append({"name": api + "-" + parse_mode + "-" + ("large" if large else "standard") + "-q" + str(quality),
                                  "payload": payload, "dictionaries": [],
                                  "config": {**base, "api": api, "parse_mode": parse_mode, "quality": quality, "large_window": large, "window_bits": window}})
    for quality in (10, 11):
        cases.append({"name": "raw-q" + str(quality), "payload": prefix[-48:], "dictionaries": [(0, prefix)],
                      "config": {**base, "api": "one_shot", "parse_mode": "whole_block", "quality": quality,
                                 "window_bits": 16, "raw_dictionary_paths": [str(dictionary_path)]}})
        cases.append({"name": "empty-q" + str(quality), "payload": b"", "dictionaries": [],
                      "config": {**base, "api": "one_shot", "parse_mode": "whole_block", "quality": quality, "window_bits": 16}})
    return cases


def references_for(case, references):
    return references["large"] if case["config"].get("large_window", False) else references["standard"]


def invoke(args, name, payload, config, expected_error=None):
    wire, stats = probe_call(args.probe, args.output_dir, name, payload, config, expected_error)
    with (args.output_dir / "lengths-events.jsonl").open("a") as events:
        events.write(json.dumps({"name": name, "expected_error": expected_error, "report": stats}) + "\n")
    return wire, stats


def old_baseline(args, cases, references):
    path = args.output_dir / "complete-lengths-baseline.json"
    if path.exists():
        data = json.loads(path.read_text());require(data["revision"] == OLD_REVISION, "independent sampled baseline revision");return data
    require(args.legacy_probe and args.legacy_source, "legacy probe/source required only for initial sampled freeze")
    names = {"one_shot-bounded-standard-q10", "one_shot-bounded-standard-q11", "one_shot-whole_block-large-q10",
             "one_shot-whole_block-large-q11", "chunks-bounded-standard-q11", "incremental-bounded-standard-q11"}
    rows = []
    for case in cases:
        if case["name"] not in names:continue
        name = "legacy-" + case["name"]
        wire, _ = probe_call(args.legacy_probe, args.output_dir, name, case["payload"], case["config"])
        for reference in references_for(case, references).values():reference.verify(wire, case["payload"])
        rows.append({"name": case["name"], "input": name + ".input", "wire": name + ".wire",
                     "input_sha256": digest(case["payload"]), "wire_sha256": digest(wire), "config": case["config"]})
    paths = [args.legacy_source / "src/root.zig", args.legacy_source / "src/br.zig", args.legacy_source / "tools/br/hq_controls_probe.zig",
             *sorted((args.legacy_source / "src/br").rglob("*.zig"))]
    data = {"schema": "vort-br-complete-lengths-sampled-baseline-v1", "revision": OLD_REVISION, "rows": rows,
            "probe_sha256": digest(args.legacy_probe.read_bytes()),
            "source_sha256": {str(file.relative_to(args.legacy_source)): digest(file.read_bytes()) for file in paths}}
    path.write_text(json.dumps(data, indent=2) + "\n");return data


def campaign(args, cases, references, baseline):
    rows, price_budget = [], None
    original = {row["name"]: row for row in baseline["rows"]}
    paired_q10 = {}
    for case in cases:
        name, payload, config = case["name"], case["payload"], case["config"]
        if args.case and name not in args.case:continue
        sampled, sampled_stats = invoke(args, name + "-sampled", payload, {**config, "copy_lengths": "sampled"})
        if name in original:
            old = original[name];expected = (args.output_dir / old["wire"]).read_bytes()
            require(digest(payload) == old["input_sha256"] and digest(expected) == old["wire_sha256"], "old sampled baseline bytes")
            require(sampled == expected, "new sampled output differs from independent old default wire")
        complete, stats = invoke(args, name + "-complete", payload, {**config, "copy_lengths": "complete"})
        require(stats["resolved"]["copy_lengths"] == "complete" and stats["resolved"]["max_price_evaluations"] is None,
                "actual complete policy resolution")
        if payload:
            require(stats["profile"]["complete_length_passes"] > 0 and stats["profile"]["max_plan_price_evaluations"] > 0,
                    "complete policy did not execute length choices")
        if case["dictionaries"]:
            require(stats["profile"]["emitted_compound_commands"] > 0 and stats["profile"]["max_copy_length_considered"] >= 40,
                    "tiny RAW fixture did not actually consider a long copy")
        require(len(complete) <= len(sampled), "complete length arbitration published a larger sampled counterpart")
        off, off_stats = invoke(args, name + "-off", payload,
                                {**config, "copy_lengths": "complete", "profile_enabled": False, "total_profile_enabled": False})
        require(off == complete and off_stats["resolved"] == stats["resolved"], "profile changed complete wire or actual policy")
        require(header(complete)["large_window"] == config.get("large_window", False), "copy policy changed standard/large header identity")
        key = name.rsplit("-q", 1)[0]
        if config["quality"] == 10:paired_q10[key] = len(complete)
        elif key in paired_q10:require(len(complete) <= paired_q10[key], "complete q11 wire exceeds matching q10")
        results = []
        for layer, reference in references_for(case, references).items():
            reason = reference.supports(case["dictionaries"])
            if reason:results.append({"layer": layer, "status": "skipped", "reason": reason});continue
            reference.verify(complete, payload, case["dictionaries"])
            independent = reference.encode(payload, config, case["dictionaries"])
            decoded, _ = invoke(args, name + "-reverse-" + layer, independent, {**config, "operation": "decode"})
            require(decoded == payload, "public decode of independent versioned reference")
            results.append({"layer": layer, "status": "ok", "direction": "bidirectional"})
        rows.append({"name": name, "input_bytes": len(payload), "sampled_wire_bytes": len(sampled), "complete_wire_bytes": len(complete),
                     "complete_wire_sha256": digest(complete), "config": config, "sampled_probe": sampled_stats, "complete_probe": stats,
                     "reference_results": results})
    if not args.case:
        case = next(case for case in cases if case["name"] == "one_shot-whole_block-standard-q11")
        config, payload = {**case["config"], "copy_lengths": "complete"}, case["payload"]
        wire, stats = invoke(args, "price-measure", payload, config)
        peak = stats["profile"]["max_plan_price_evaluations"]
        require(peak > 1, "per-plan price budget fixture has no counted choices")
        exact, exact_stats = invoke(args, "price-exact", payload, {**config, "max_price_evaluations": peak})
        require(exact == wire and exact_stats["profile"]["max_plan_price_evaluations"] <= peak, "exact per-plan budget changed wire or exceeded cap")
        require(exact_stats["profile"]["price_evaluations"] > peak,
                "fixture failed to demonstrate aggregate evaluations across independently capped plans")
        failures = []
        for name, limit in (("price-below", peak - 1), ("price-low1", 1), ("price-zero", 0)):
            _, failed = invoke(args, name, payload, {**config, "max_price_evaluations": limit}, "SearchLimitExceeded")
            require(failed["profile"]["max_plan_price_evaluations"] <= limit and failed["total_profile"]["live_requested_bytes"] == 0,
                    "price-limit failure leaked heap or admitted more than one plan's cap")
            failures.append({"limit": limit, "max_plan_price_evaluations": failed["profile"]["max_plan_price_evaluations"]})
        invoke(args, "invalid-policy", payload, {**config, "copy_lengths": "not_a_policy"}, "InvalidBlockPlan")
        price_budget = {"limit": peak, "max_plan_price_evaluations": exact_stats["profile"]["max_plan_price_evaluations"],
                        "aggregate_price_evaluations": exact_stats["profile"]["price_evaluations"], "failures": failures,
                        "scope": "each parser plan independently admits edge choices; accumulated work across guard/candidate plans may exceed this cap"}
    return rows, price_budget


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for field in ("reference", "system-reference", "large-reference", "large-system-reference", "output-dir"):parser.add_argument("--" + field, type=Path, required=True)
    for field in ("probe", "legacy-probe", "legacy-source"):parser.add_argument("--" + field, type=Path)
    parser.add_argument("--prepare-only", action="store_true");parser.add_argument("--case", action="append")
    args = parser.parse_args()
    for field in ("reference", "system_reference", "large_reference", "large_system_reference", "output_dir", "probe", "legacy_probe", "legacy_source"):
        if getattr(args, field):setattr(args, field, getattr(args, field).resolve())
    args.output_dir.mkdir(parents=True, exist_ok=True)
    references = {"standard": {"modern": Reference(args.reference), "system": Reference(args.system_reference)},
                  "large": {"modern": LargeReference(args.large_reference), "system": LargeReference(args.large_system_reference)}}
    cases = samples(args.output_dir)
    if args.case:require(set(args.case) <= {case["name"] for case in cases}, "unknown complete-length stage case")
    baseline = old_baseline(args, cases, references)
    require(args.prepare_only or args.probe, "--probe required for actual complete policy")
    paths = [ROOT / "build.zig", *sorted((ROOT / "src").rglob("*")), ROOT / "tools/br/hq_controls_probe.zig", Path(__file__),
             ROOT / "tools/br/hq_controls_diff.py", ROOT / "tools/br/large_window_diff.py"]
    before = {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in paths if path.is_file()}
    rows, budget = ([], None) if args.prepare_only else campaign(args, cases, references, baseline)
    after = {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in paths if path.is_file()}
    if not args.case:require(before == after, "source changed during complete-length final campaign")
    report = {"schema": "vort-br-complete-lengths-v1", "status": "prepared" if args.prepare_only else "ok", "utc": datetime.now(timezone.utc).isoformat(),
              "rows": rows, "price_budget": budget, "stage_cases": args.case, "source_before_after_equal": before == after,
              "source_sha256": before, "source_after_sha256": after, "baseline_rows": len(baseline["rows"]),
              "baseline_manifest_sha256": digest((args.output_dir / "complete-lengths-baseline.json").read_bytes()),
              "probe_path": str(args.probe) if args.probe else None, "probe_sha256": digest(args.probe.read_bytes()) if args.probe else None,
              "references": {format: {layer: reference.provenance() for layer, reference in refs.items()} for format, refs in references.items()},
              "scope": "public complete copy-length wire and per-plan search work; no hidden cost-model proxy or performance conclusion"}
    path = args.output_dir / "complete-lengths-report.json";path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "rows": len(rows), "baseline_rows": len(baseline["rows"]), "report": str(path)}))


if __name__ == "__main__":main()
