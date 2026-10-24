#!/usr/bin/env python3
"""Small whole-block Brotli parser wire checks through public APIs only."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import random
import sys

sys.dont_write_bytecode = True
from hq_controls_diff import ROOT, Reference, digest, probe_call, require
from large_window_diff import LargeReference, header

OLD_REVISION = "90f21bad720d8e9f6686f7f2c5cecacf28d48c51"


def samples(directory):
    prefix = random.Random(0x90121bad).randbytes(128)
    path = directory / "whole-raw.dictionary"
    if path.exists():require(path.read_bytes() == prefix, "frozen small RAW dictionary changed")
    else:path.write_bytes(prefix)
    base = {"hq": True, "search_depth": 16, "nice_len": 32, "beam_width": 2, "iterations": 1,
            "block_len": 8192, "input_chunk": 127, "output_chunk": 31, "npostfix": 0, "ndirect_high": 0}
    text = (b"whole block ABCabcABCabc_xyz\n" * 3)[:64]
    cases = []
    for api in ("one_shot", "chunks", "incremental"):
        for quality in (10, 11):
            for large, bits in ((False, 16), (True, 25)):
                cases.append({"name": api + "-q" + str(quality) + ("-large" if large else "-standard"), "payload": text,
                              "config": {**base, "api": api, "quality": quality, "large_window": large, "window_bits": bits}, "dictionaries": []})
    for quality in (10, 11):
        for name, data, dictionaries, extra in (
            ("binary", random.Random(64).randbytes(64), [], {}),
            ("raw", prefix[-48:] + b"!", [(0, prefix)], {"raw_dictionary_paths": [str(path)]}),
            ("empty", b"", [], {}),
            ("tail4100", (b"whole parser tail witness ABCabc\n" * 130)[:4100], [], {}),
        ):
            cases.append({"name": "one_shot-q" + str(quality) + "-" + name, "payload": data,
                          "config": {**base, "api": "one_shot", "quality": quality, "window_bits": 16, **extra}, "dictionaries": dictionaries})
    return cases


def invoke(args, name, payload, config, expected_error=None):
    wire, report = probe_call(args.probe, args.output_dir, name, payload, config, expected_error)
    with (args.output_dir / "whole-events.jsonl").open("a") as events:events.write(json.dumps({"name": name, "expected_error": expected_error, "report": report}) + "\n")
    return wire, report


def references_for(case, references):
    return references["large"] if case["config"].get("large_window", False) else references["standard"]


def old_baseline(args, cases, references):
    path = args.output_dir / "whole-block-baseline.json"
    if path.exists():
        data = json.loads(path.read_text());require(data["revision"] == OLD_REVISION, "90f21bad bounded baseline revision");return data
    require(args.legacy_probe and args.legacy_source, "old source/probe needed only for initial independent freeze")
    names = {"one_shot-q10-standard", "one_shot-q11-standard", "one_shot-q10-large", "one_shot-q11-large", "chunks-q11-standard", "incremental-q11-standard"}
    rows = []
    for case in cases:
        if case["name"] not in names:continue
        wire, _ = probe_call(args.legacy_probe, args.output_dir, "legacy-" + case["name"], case["payload"], case["config"])
        for reference in references_for(case, references).values():reference.verify(wire, case["payload"])
        rows.append({"name": case["name"], "input": "legacy-" + case["name"] + ".input", "wire": "legacy-" + case["name"] + ".wire",
                     "input_sha256": digest(case["payload"]), "wire_sha256": digest(wire), "config": case["config"]})
    paths = [args.legacy_source / "src/br.zig", args.legacy_source / "src/root.zig", args.legacy_source / "tools/br/hq_controls_probe.zig",
             *sorted((args.legacy_source / "src/br").rglob("*.zig"))]
    data = {"schema": "vort-br-whole-block-bounded-baseline-v1", "revision": OLD_REVISION, "rows": rows,
            "probe_sha256": digest(args.legacy_probe.read_bytes()), "source_sha256": {str(file.relative_to(args.legacy_source)): digest(file.read_bytes()) for file in paths}}
    path.write_text(json.dumps(data, indent=2) + "\n");return data


def campaign(args, cases, references, baseline):
    rows = []
    originals = {row["name"]: row for row in baseline["rows"]}
    q10_wires = {}
    for case in cases:
        name, payload, config = case["name"], case["payload"], case["config"]
        if args.case and name not in args.case:continue
        bounded, old_stats = invoke(args, name + "-bounded", payload, {**config, "parse_mode": "bounded"})
        if name in originals:
            old = originals[name];expected = (args.output_dir / old["wire"]).read_bytes()
            require(digest(expected) == old["wire_sha256"] and digest(payload) == old["input_sha256"], "independent old bounded wire hashes")
            require(bounded == expected, "new bounded mode changed old output")
        whole, stats = invoke(args, name + "-whole", payload, {**config, "parse_mode": "whole_block"})
        require(stats["resolved"]["parse_mode"] == "whole_block", "requested actual whole-block mode")
        if payload:
            require(stats["profile"]["whole_block_passes"] > 0 and stats["profile"]["max_parse_positions"] > 0,
                    "whole-block mode emitted wire without running the whole parser")
        if name.endswith("-tail4100"):
            require(stats["profile"]["max_parse_positions"] >= len(payload), "whole tail did not expose its complete parse extent")
        if case["dictionaries"]:
            require(stats["profile"]["emitted_compound_commands"] > 0, "whole RAW dictionary case emitted no dictionary reference")
        require(len(whole) <= len(bounded), "whole-block arbitration published larger wire than bounded baseline")
        off, off_stats = invoke(args, name + "-off", payload,
                                {**config, "parse_mode": "whole_block", "profile_enabled": False, "total_profile_enabled": False})
        require(off == whole and off_stats["resolved"] == stats["resolved"], "profiles changed whole-block output or actual resolution")
        require(header(whole)["large_window"] == config.get("large_window", False), "parse mode changed wire format identity")
        checks = []
        for layer, reference in references_for(case, references).items():
            reason = reference.supports(case["dictionaries"])
            if reason:checks.append({"layer": layer, "status": "skipped", "reason": reason});continue
            reference.verify(whole, payload, case["dictionaries"])
            encoded = reference.encode(payload, config, case["dictionaries"])
            decoded, _ = invoke(args, name + "-reverse-" + layer, encoded, {**config, "operation": "decode"})
            require(decoded == payload, "public decode failed independent versioned reference")
            checks.append({"layer": layer, "status": "ok", "direction": "bidirectional"})
        ratio_key = name.replace("-q10-", "-q-").replace("-q11-", "-q-")
        if config["quality"] == 10:q10_wires[ratio_key] = len(whole)
        if config["quality"] == 11 and ratio_key in q10_wires:require(len(whole) <= q10_wires[ratio_key], "q11 whole-block wire exceeded matching q10 wire")
        rows.append({"name": name, "input_bytes": len(payload), "bounded_wire_bytes": len(bounded), "whole_wire_bytes": len(whole), "whole_wire_sha256": digest(whole),
                     "config": config, "probe": stats, "bounded_probe": old_stats, "reference_results": checks})
    if not args.case:
        case = next(case for case in cases if case["name"] == "one_shot-q11-standard")
        config = {**case["config"], "parse_mode": "whole_block"};payload = case["payload"]
        wire, stats = invoke(args, "budget-measure", payload, config)
        peak = stats["total_profile"]["peak_requested_bytes"]
        exact, _ = invoke(args, "budget-exact", payload, {**config, "max_total_working_memory": peak});require(exact == wire, "exact total cap changed whole wire")
        for name, cap in (("budget-below", peak - 1), ("budget-zero", 0)):
            _, report = invoke(args, name, payload, {**config, "max_total_working_memory": cap}, "WorkingMemoryLimitExceeded")
            require(report["total_profile"]["live_requested_bytes"] == 0, "failed whole parser left live heap")
        invoke(args, "invalid-mode", payload, {**config, "parse_mode": "not_a_mode"}, "InvalidBlockPlan")
    return rows


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
    if args.case:require(set(args.case) <= {case["name"] for case in cases}, "unknown named whole-block stage case")
    baseline = old_baseline(args, cases, references)
    require(args.prepare_only or args.probe, "--probe needed for actual whole parser checks")
    paths = [ROOT / "build.zig", *sorted((ROOT / "src").rglob("*")), ROOT / "tools/br/hq_controls_probe.zig", Path(__file__),
             ROOT / "tools/br/hq_controls_diff.py", ROOT / "tools/br/large_window_diff.py"]
    before = {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in paths if path.is_file()}
    rows = [] if args.prepare_only else campaign(args, cases, references, baseline)
    after = {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in paths if path.is_file()}
    if not args.case:require(before == after, "source changed during whole-block final campaign")
    report = {"schema": "vort-br-whole-block-v1", "status": "prepared" if args.prepare_only else "ok", "utc": datetime.now(timezone.utc).isoformat(),
              "rows": rows, "stage_cases": args.case, "source_before_after_equal": before == after, "source_sha256": before, "source_after_sha256": after,
              "baseline_rows": len(baseline["rows"]), "baseline_manifest_sha256": digest((args.output_dir / "whole-block-baseline.json").read_bytes()),
              "probe_path": str(args.probe) if args.probe else None, "probe_sha256": digest(args.probe.read_bytes()) if args.probe else None,
              "references": {format: {layer: reference.provenance() for layer, reference in refs.items()} for format, refs in references.items()},
              "scope": "public whole-block wire/profile semantics; no custom cost-model, throughput or match-quality ranking claim"}
    path = args.output_dir / "whole-block-report.json";path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "rows": len(rows), "baseline_rows": len(baseline["rows"]), "report": str(path)}))


if __name__ == "__main__":main()
