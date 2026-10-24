#!/usr/bin/env python3
"""Small public Brotli total-heap checks, independent of HQ workspace limits."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import random
import sys

sys.dont_write_bytecode = True
from hq_controls_diff import ROOT, Reference, digest, probe_call, require

OLD_REVISION = "997fe5e56eb03ca21e7e66885d84f368d94ccc4e"


def samples(directory):
    dictionary = random.Random(0x70a1b0d9).randbytes(256)
    path = directory / "total-raw.dictionary"
    if path.exists():
        require(path.read_bytes() == dictionary, "frozen RAW dictionary changed")
    else:
        path.write_bytes(dictionary)
    common = {"input_chunk": 127, "output_chunk": 31, "block_len": 256}
    hq = {"hq": True, "quality": 11, "window_bits": 18, "npostfix": 1, "ndirect_high": 6,
          "search_depth": 32, "nice_len": 64, "beam_width": 4, "iterations": 1}
    cases = []
    for api in ("one_shot", "chunks", "incremental"):
        for name, payload, settings, dictionaries in (
            ("q0", (b"bounded total heap q0\n" * 30)[:512], {"quality": 0, "window_bits": 16}, []),
            ("q11", b"legacy quality eleven abcabcXabcabcY\n" * 4, {"quality": 11, "window_bits": 16}, []),
            ("hq11", b"Brotli hq ABCabcABCabc_xyz\n" * 6, hq, []),
            ("empty", b"", {"quality": 0, "window_bits": 16}, []),
            ("raw", dictionary[-64:] + b"!", {**hq, "raw_dictionary_paths": [str(path)]}, [(0, dictionary)]),
        ):
            cases.append({"name": api + "-" + name, "payload": payload,
                          "config": {**common, **settings, "api": api}, "dictionaries": dictionaries})
    return cases


def invoke(args, name, payload, config, expected_error=None):
    wire, report = probe_call(args.probe, args.output_dir, name, payload, config, expected_error)
    with (args.output_dir / "events.jsonl").open("a") as events:
        events.write(json.dumps({"name": name, "expected_error": expected_error, "report": report}) + "\n")
    return wire, report


def prepare(args, cases, references):
    rows = []
    for case in cases:
        name = "legacy-" + case["name"]
        config = {**case["config"], "total_profile_enabled": False}
        wire, _ = probe_call(args.legacy_probe, args.output_dir, name, case["payload"], config)
        checks = []
        for label, reference in references.items():
            reason = reference.supports(case["dictionaries"])
            if reason:
                checks.append({"reference": label, "status": "skipped", "reason": reason})
            else:
                reference.verify(wire, case["payload"], case["dictionaries"])
                checks.append({"reference": label, "status": "ok"})
        rows.append({"name": case["name"], "config": config, "input": name + ".input", "wire": name + ".wire",
                     "input_sha256": digest(case["payload"]), "wire_sha256": digest(wire), "reference_results": checks})
    paths = [args.legacy_source / "tools/br/hq_controls_probe.zig", args.legacy_source / "src/root.zig",
             args.legacy_source / "src/br.zig", *sorted((args.legacy_source / "src/br").rglob("*.zig"))]
    manifest = {"schema": "vort-br-total-memory-old-wire-v1", "revision": OLD_REVISION,
                "probe_sha256": digest(args.legacy_probe.read_bytes()),
                "source_sha256": {str(path.relative_to(args.legacy_source)): digest(path.read_bytes()) for path in paths}, "rows": rows}
    (args.output_dir / "total-baseline.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def finished_profile(report, limit):
    profile = report["total_profile"]
    require(profile["available"] and profile["limit"] == limit, "public total profile policy")
    require(profile["live_requested_bytes"] == 0, "encoder-owned requested heap remains after operation")
    if limit is not None:
        require(profile["peak_requested_bytes"] <= limit, "total allocator exceeded its cap")
    return profile


def campaign(args, cases, references, baseline):
    require([row["name"] for row in baseline["rows"]] == [case["name"] for case in cases], "representative baseline shape changed")
    rows = []
    for case, old in zip(cases, baseline["rows"]):
        name, payload, config = case["name"], case["payload"], case["config"]
        if args.case and name not in args.case:
            continue
        expected = (args.output_dir / old["wire"]).read_bytes()
        require(digest(expected) == old["wire_sha256"] and digest(payload) == old["input_sha256"], "original representative baseline hashes")
        null_wire, off = invoke(args, name + "-null", payload, {**config, "total_profile_enabled": False})
        require(null_wire == expected, "null total controls changed the old wire")
        require(not off["total_profile"]["available"], "disabled total profile was populated")
        wire, measured = invoke(args, name + "-measure", payload, {**config, "total_profile_enabled": True})
        total = finished_profile(measured, None)
        peak = total["peak_requested_bytes"]
        require(peak > 0 and wire == expected, "total instrumentation changed wire or measured no heap")
        exact_wire, exact = invoke(args, name + "-exact", payload,
                                   {**config, "total_profile_enabled": True, "max_total_working_memory": peak})
        finished_profile(exact, peak)
        require(exact_wire == wire, "exact total cap changed output")
        _, below = invoke(args, name + "-below", payload,
                          {**config, "total_profile_enabled": True, "max_total_working_memory": peak - 1}, "WorkingMemoryLimitExceeded")
        finished_profile(below, peak - 1)
        _, zero = invoke(args, name + "-zero", payload,
                         {**config, "total_profile_enabled": True, "max_total_working_memory": 0}, "WorkingMemoryLimitExceeded")
        finished_profile(zero, 0)
        checks = []
        for label, reference in references.items():
            reason = reference.supports(case["dictionaries"])
            if reason:
                checks.append({"reference": label, "status": "skipped", "reason": reason})
                continue
            reference.verify(wire, payload, case["dictionaries"])
            reverse_config = {**config, "operation": "decode"}
            reference_config = {**config, "quality": config.get("quality", 11)}
            decoded, _ = invoke(args, name + "-reverse-" + label, reference.encode(payload, reference_config, case["dictionaries"]), reverse_config)
            require(decoded == payload, "public decoder failed versioned reference bytes")
            checks.append({"reference": label, "status": "ok", "direction": "bidirectional", "dictionary_attached": bool(case["dictionaries"])})
        if case["dictionaries"]:
            require(measured["profile"]["emitted_compound_commands"] > 0, "RAW reference fixture was not actually used")
        rows.append({"name": name, "config": config, "input_bytes": len(payload), "wire_bytes": len(wire),
                     "wire_sha256": digest(wire), "total_peak_requested_bytes": peak,
                     "hq_workspace_peak": measured["work_memory"]["hq_requested_peak"],
                     "after_operation_live_requested_bytes": total["live_requested_bytes"],
                     "exact_total_profile": exact["total_profile"], "below_total_profile": below["total_profile"],
                     "zero_total_profile": zero["total_profile"], "reference_results": checks})
    # Both caps use the public error, while their measured domains remain separate.
    if args.case and "one_shot-hq11" not in args.case:
        return rows, None
    hq_case = next(case for case in cases if case["name"] == "one_shot-hq11")
    payload, config = hq_case["payload"], hq_case["config"]
    _, stats = invoke(args, "independent-cap-measure", payload, {**config, "total_profile_enabled": True})
    workspace = stats["profile"]["peak_working_memory"]
    total = stats["total_profile"]["peak_requested_bytes"]
    require(workspace > 0 and total > workspace, "total and workspace profiles did not expose their different domains")
    _, workspace_failed = invoke(args, "independent-workspace-below", payload,
                                 {**config, "total_profile_enabled": True, "max_total_working_memory": total,
                                  "max_working_memory": workspace - 1}, "WorkingMemoryLimitExceeded")
    finished_profile(workspace_failed, total)
    return rows, {"total_peak_requested_bytes": total, "workspace_peak": workspace,
                  "workspace_failure_total_profile": workspace_failed["total_profile"],
                  "scope": "workspace failure with independently sufficient total budget; error name does not identify its cap source"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", type=Path)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--system-reference", type=Path, required=True)
    parser.add_argument("--legacy-probe", type=Path)
    parser.add_argument("--legacy-source", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--case", action="append", help="run a named stage case; omit for all 15 representatives")
    args = parser.parse_args()
    for field in ("probe", "reference", "system_reference", "legacy_probe", "legacy_source", "output_dir"):
        if getattr(args, field): setattr(args, field, getattr(args, field).resolve())
    args.output_dir.mkdir(parents=True, exist_ok=True)
    references = {"modern": Reference(args.reference), "system": Reference(args.system_reference)}
    cases = samples(args.output_dir)
    if args.case:
        require(set(args.case) <= {case["name"] for case in cases}, "unknown representative stage case")
    baseline_path = args.output_dir / "total-baseline.json"
    if baseline_path.exists():
        baseline = json.loads(baseline_path.read_text())
        require(baseline["revision"] == OLD_REVISION, "997fe5e5 representative baseline revision")
    else:
        require(args.legacy_probe and args.legacy_source, "old source and probe required only for initial representative freeze")
        baseline = prepare(args, cases, references)
    require(args.prepare_only or args.probe, "--probe required for total-memory campaign")
    paths = [ROOT / "build.zig", ROOT / "src/root.zig", ROOT / "src/br.zig", *sorted((ROOT / "src/br").rglob("*.zig")),
             ROOT / "tools/br/hq_controls_probe.zig", ROOT / "tools/br/hq_controls_diff.py", Path(__file__).resolve()]
    before = {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in paths if path.is_file()}
    rows, independent = ([], None) if args.prepare_only else campaign(args, cases, references, baseline)
    after = {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in paths if path.is_file()}
    source_stable = before == after
    if not args.case:
        require(source_stable, "production or probe source changed during bounded total-memory run")
    report = {"schema": "vort-br-total-memory-v1", "status": "prepared" if args.prepare_only else "ok",
              "utc": datetime.now(timezone.utc).isoformat(), "rows": rows, "independent_caps": independent,
              "baseline_rows": len(baseline["rows"]), "baseline_manifest_sha256": digest(baseline_path.read_bytes()),
              "references": {name: reference.provenance() for name, reference in references.items()},
              "probe_path": str(args.probe) if args.probe else None,
              "probe_sha256": digest(args.probe.read_bytes()) if args.probe else None,
              "source_sha256": before, "source_after_sha256": after,
              "source_before_after_equal": source_stable, "stage_cases": args.case,
              "scope": "caller-reported total requested heap, separately measured from HQ workspace; no RSS or allocator bookkeeping claim"}
    path = args.output_dir / "total-memory-report.json"
    path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "rows": len(rows), "baseline_rows": report["baseline_rows"], "report": str(path)}))


if __name__ == "__main__":
    main()
