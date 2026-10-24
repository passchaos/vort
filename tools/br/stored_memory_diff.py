#!/usr/bin/env python3
"""Bounded public stored Brotli heap contracts and frozen old-wire regression."""
import argparse
from collections import Counter
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import sys

sys.dont_write_bytecode = True
from hq_controls_diff import ROOT, digest, require
from large_window_diff import LargeReference, header

OLD_REVISION = "3703184975920d44ed3e781f0e562f45cfe31fa5"
APIS = ("alloc", "chunks_alloc", "into", "chunks_into", "append", "chunks_append",
        "scratch", "chunks_scratch", "reuse_alloc", "reuse_chunks_alloc", "reuse_append",
        "reuse_chunks_append", "reuse_into", "reuse_chunks_into", "incremental")


def cases():
    payload = b"stored resource caller-owned input ABCabc_xyz\n" * 2
    common = {"window_bits": 16, "large_window": False, "metadata": "initial metadata",
              "input_chunk": 11, "output_chunk": 17, "block_len": 64}
    rows = [{"name": api, "payload": payload, "config": {**common, "api": api}} for api in APIS]
    for bits in (10, 16, 25, 30):
        rows.append({"name": "large-" + str(bits), "payload": payload,
                     "config": {**common, "api": "alloc", "large_window": True, "window_bits": bits}})
    rows += [{"name": "standard-10", "payload": payload, "config": {**common, "api": "alloc", "window_bits": 10}},
             {"name": "empty", "payload": b"", "config": {**common, "api": "alloc", "metadata": ""}}]
    for bits in range(11, 17):
        rows.append({"name": "incremental-standard-" + str(bits), "payload": payload,
                     "config": {**common, "api": "incremental", "window_bits": bits, "flush_at": 33,
                                "stream_metadata": "middle metadata" if bits % 2 else "",
                                "cycle": "reset" if bits == 15 else "next" if bits == 16 else "none"}})
    rows.append({"name": "scratch-repeat", "payload": payload,
                 "config": {**common, "api": "scratch", "cycle": "repeat"}})
    require(len(rows) == 28, "locked bounded stored matrix")
    return rows


def call(probe, directory, name, payload, config, expected_error=None):
    source, output, settings = [directory / (name + suffix) for suffix in (".input", ".wire", ".json")]
    source.write_bytes(payload)
    output.write_bytes(b"existing output sentinel")
    settings.write_text(json.dumps(config) + "\n")
    result = subprocess.run([str(probe), str(source), str(output), str(settings)], cwd=ROOT,
                            capture_output=True, timeout=120)
    require(result.returncode == 0, (name, result.stderr.decode(errors="replace")))
    report = json.loads(result.stdout)
    require(report["error"] == expected_error, (name, config, report))
    if expected_error:
        require(output.read_bytes() == b"existing output sentinel", "failed stored operation replaced output")
    with (directory / "stored-events.jsonl").open("a") as log:
        log.write(json.dumps({"name": name, "expected_error": expected_error, "config": config, "report": report}) + "\n")
    return output.read_bytes(), report


def prepare(args, references):
    path = args.output_dir / "stored-baseline.json"
    require(not path.exists(), "old baseline is frozen once, never regenerated")
    require(args.legacy_probe and args.legacy_source, "independent archived source and probe required")
    rows = []
    for case in cases():
        name, config = "legacy-" + case["name"], {**case["config"], "profile_enabled": False}
        wire, stats = call(args.legacy_probe, args.output_dir, name, case["payload"], config)
        for reference in references.values():
            result = reference.decode_result(wire, case["payload"], allow=config["large_window"])
            require(result["status"] == 0, (name, result))
        rows.append({"name": case["name"], "config": config, "input": name + ".input", "wire": name + ".wire",
                     "input_sha256": digest(case["payload"]), "wire_sha256": digest(wire), "header": header(wire),
                     "steps": stats["steps"], "reference_results": {label: "ok" for label in references}})
    archive = Path(str(args.legacy_source) + ".tar")
    paths = [args.legacy_source / "src/root.zig", args.legacy_source / "src/br.zig",
             *sorted((args.legacy_source / "src/br").rglob("*")),
             args.legacy_source / "tools/br/stored_memory_probe.zig", args.legacy_source / "tools/br/stored_memory_ledger.zig"]
    baseline = {"schema": "vort-br-stored-memory-old-wire-v1", "revision": OLD_REVISION,
                "archive_sha256": digest(archive.read_bytes()), "probe_sha256": digest(args.legacy_probe.read_bytes()),
                "source_sha256": {str(p.relative_to(args.legacy_source)): digest(p.read_bytes()) for p in paths if p.is_file()},
                "rows": rows, "scope": "all codec source from independent git archive; only probe harness added; no current codec outputs used"}
    path.write_text(json.dumps(baseline, indent=2) + "\n")
    return baseline


def checked(report, config, error=None):
    require(report["independent_live_after_deinit"] == 0, "backing ledger has a leaked requested allocation")
    profile = report["total_profile"]
    if config.get("profile_enabled", True):
        require(profile["available"] or (error is not None and report["independent_peak_requested_bytes"] == 0), "enabled real profile absent")
        if error is None:
            require(profile["peak_requested_bytes"] == report["independent_peak_requested_bytes"],
                    ("public profile versus independent backing peak", report))
        limit = config.get("max_total_working_memory")
        if limit is not None and config.get("scenario") != "retained":
            require(profile["peak_requested_bytes"] <= limit, "new requested heap exceeded finite cap")
        if config["api"] == "incremental":
            require(profile["live_requested_bytes"] == 0, "persistent incremental profile did not finish at zero")
    else:
        require(not profile["available"], "null profile was populated")
    return profile


def campaign(args, references):
    baseline = json.loads((args.output_dir / "stored-baseline.json").read_text())
    require(baseline["revision"] == OLD_REVISION and len(baseline["rows"]) == 28, "independent old baseline shape")
    rows, measured = [], {}
    for case, old in zip(cases(), baseline["rows"]):
        name, payload, config = case["name"], case["payload"], case["config"]
        require(old["name"] == name and digest(payload) == old["input_sha256"], "frozen case mapping changed")
        expected = (args.output_dir / old["wire"]).read_bytes()
        require(digest(expected) == old["wire_sha256"], "archived old wire changed")
        null_config = {**config, "profile_enabled": False}
        null_wire, null = call(args.probe, args.output_dir, name + "-null", payload, null_config)
        checked(null, null_config)
        wire, stats = call(args.probe, args.output_dir, name + "-profile", payload, config)
        profile = checked(stats, config)
        require(null_wire == expected == wire, "default or resource instrumentation changed old stored wire")
        envelope = header(wire)
        require(envelope["window_bits"] == config["window_bits"] and envelope["large_window"] == config["large_window"], "actual public window identity")
        reference_rows = {}
        for label, reference in references.items():
            result = reference.decode_result(wire, payload, allow=config["large_window"])
            require(result["status"] == 0, (name, label, result))
            if config["large_window"]:
                refused = reference.decode_result(wire, payload, allow=False)
                require(refused["status"] != 0, "large window decoder opt-in not exercised")
            reference_rows[label] = result
        if config.get("cycle", "none") != "none":require(stats["cycle_verified"], "actual reset/next/repeat cycle absent")
        measured[name] = {"case": case, "wire": wire, "profile": profile}
        rows.append({"name": name, "wire_bytes": len(wire), "wire_sha256": digest(wire), "header": envelope,
                     "config": config, "probe": stats, "reference_results": reference_rows})
    budget = []
    for name in ("alloc", "chunks_alloc", "scratch", "incremental"):
        item = measured[name];case = item["case"];peak = item["profile"]["peak_requested_bytes"]
        require(peak > 1, "allocating API measured no actual requested heap")
        for suffix, cap, error in (("exact", peak, None), ("below", peak - 1, "WorkingMemoryLimitExceeded"), ("zero", 0, "WorkingMemoryLimitExceeded")):
            config = {**case["config"], "max_total_working_memory": cap}
            wire, stats = call(args.probe, args.output_dir, "budget-" + name + "-" + suffix, case["payload"], config, error)
            checked(stats, config, error)
            if error is None:require(wire == item["wire"], "exact measured total cap changed old wire")
            budget.append({"api": name, "limit": cap, "error": error, "profile": stats["total_profile"]})
    auxiliary = []
    common = measured["alloc"]["case"]
    for api in ("into", "chunks_into", "reuse_into", "reuse_chunks_into"):
        config = {**common["config"], "api": api, "max_total_working_memory": 0}
        wire, stats = call(args.probe, args.output_dir, "zero-heap-" + api, common["payload"], config)
        checked(stats, config)
        require(stats["total_profile"]["peak_requested_bytes"] == 0 and stats["allocation_calls"] == 0,
                "nonalias direct Into allocated hidden control or payload")
        auxiliary.append({"name": "zero-heap-" + api, "report": stats})
    for api in ("append", "reuse_append"):
        config = {**common["config"], "api": api, "max_total_working_memory": 0, "caller_capacity": 256}
        wire, stats = call(args.probe, args.output_dir, "zero-heap-" + api, common["payload"], config)
        checked(stats, config)
        require(stats["total_profile"]["peak_requested_bytes"] == 0 and stats["independent_peak_requested_bytes"] == 0,
                "spare caller capacity append allocated hidden encoder heap")
        require(stats["encoder_allocation_calls"] == 0, "spare caller append made a hidden backing allocation")
        require(wire == measured["append"]["wire"], "spare caller append changed stored wire")
        auxiliary.append({"name": "zero-heap-" + api, "report": stats})
    for scenario, api in (("alias_source", "reuse_into"), ("alias_metadata", "reuse_into"),
                          ("alias_chunks", "reuse_chunks_into"), ("alias_chunks", "chunks_append")):
        config = {**common["config"], "api": api, "scenario": scenario, "input_chunk": 64,
                  "caller_capacity": 256}
        name = scenario + "-" + api
        wire, stats = call(args.probe, args.output_dir, name + "-measure", common["payload"], config)
        profile = checked(stats, config)
        for reference in references.values():reference.verify(wire, common["payload"])
        peak = profile["peak_requested_bytes"]
        require(peak > 0, "alias fixture did not require actual snapshot heap")
        for suffix, cap, error in (("exact", peak, None), ("below", peak - 1, "WorkingMemoryLimitExceeded")):
            limited = {**config, "max_total_working_memory": cap}
            actual, report = call(args.probe, args.output_dir, name + "-" + suffix, common["payload"], limited, error)
            checked(report, limited, error)
            if error is None:require(actual == wire, "exact alias budget changed compatible wire")
            else:require(report["caller_state_preserved_on_error"], "alias failure did not check caller bytes/state")
        auxiliary.append({"name": name, "report": stats})
        if scenario == "alias_source":
            zero_config = {**config, "max_total_working_memory": 0}
            _, zero = call(args.probe, args.output_dir, name + "-zero", common["payload"], zero_config, "WorkingMemoryLimitExceeded")
            checked(zero, zero_config, "WorkingMemoryLimitExceeded")
            require(zero["caller_state_preserved_on_error"], "zero alias budget did not preserve caller bytes")
    retained = {**common["config"], "api": "scratch", "scenario": "retained", "cycle": "repeat"}
    wire, stats = call(args.probe, args.output_dir, "retained-capacity-measure", common["payload"], retained)
    checked(stats, retained)
    require(stats["retained_capacity"] > stats["logical_retained_bytes"] and stats["cycle_verified"],
            "retained full capacity and repeated borrowed output were not exercised")
    peak = stats["total_profile"]["peak_requested_bytes"]
    limited = {**retained, "max_total_working_memory": peak}
    actual, exact = call(args.probe, args.output_dir, "retained-capacity-exact", common["payload"], limited)
    checked(exact, limited)
    require(actual == wire, "exact retained-capacity policy changed output")
    below_config = {**retained, "max_total_working_memory": peak - 1}
    _, below = call(args.probe, args.output_dir, "retained-capacity-below", common["payload"], below_config, "WorkingMemoryLimitExceeded")
    checked(below, below_config, "WorkingMemoryLimitExceeded")
    require(below["caller_state_preserved_on_error"], "failed retained adoption changed scratch state")
    auxiliary.append({"name": "retained-capacity", "report": stats})
    for scenario in ("retry_oom", "retry_cap"):
        config = {**common["config"], "api": "incremental", "scenario": scenario, "block_len": 512}
        retry_payload = common["payload"] * 3
        frozen = json.loads((args.output_dir / "stored-retry-baseline.json").read_text())
        old_wire = (args.output_dir / frozen["wire"]).read_bytes()
        require(digest(old_wire) == frozen["wire_sha256"] and digest(retry_payload) == frozen["input_sha256"], "old retry fixture byte binding")
        wire, stats = call(args.probe, args.output_dir, scenario, retry_payload, config)
        checked(stats, config)
        require(stats["retry_verified"], "injected final-resource failure did not actually occur")
        require(wire == old_wire, "resource retry did not match independent old incremental wire")
        for reference in references.values():reference.verify(wire, retry_payload)
        auxiliary.append({"name": scenario, "report": stats})
    config = {**common["config"], "api": "scratch", "scenario": "owner_handoff"}
    wire, stats = call(args.probe, args.output_dir, "owner-handoff", common["payload"], config)
    checked(stats, config)
    require(stats["ownership_handoff_verified"], "owner base mutation did not run")
    require(wire == measured["scratch"]["wire"], "ownership handoff changed output")
    auxiliary.append({"name": "owner-handoff", "report": stats})
    for name, config, error in (
            ("invalid-window", {**common["config"], "window_bits": 9}, "InvalidBlockPlan"),
            ("invalid-incremental-block", {**common["config"], "api": "incremental", "block_len": 0}, "InvalidBlockPlan"),
            ("backing-oom", {**common["config"], "failure_after": 0}, "OutOfMemory"),
            ("short-into", {**common["config"], "api": "into", "caller_capacity": 0}, "OutOfMemory"),
            ("nested-profile", {**common["config"], "scenario": "nested_profile"}, "InvalidBlockPlan"),
            ("nested-cap", {**common["config"], "scenario": "nested_cap"}, "InvalidBlockPlan"),
            ("nested-invalid", {**common["config"], "scenario": "nested_invalid"}, "InvalidBlockPlan")):
        _, stats = call(args.probe, args.output_dir, name, common["payload"], config, error)
        checked(stats, config, error)
        if name.startswith("invalid-"):require(stats["allocation_calls"] == 0, "invalid options allocated before validation")
        if name.startswith("nested-"):require(stats["nested_call_verified"], "nested validation did not execute")
        auxiliary.append({"name": name, "report": stats})
    events = [json.loads(line) for line in (args.output_dir / "stored-events.jsonl").read_text().splitlines()]
    require(len(rows) <= 30 and len(events) <= 100, "bounded stored campaign exceeded its authorized matrix")
    return baseline, rows, budget, auxiliary, events


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--probe", type=Path);p.add_argument("--legacy-probe", type=Path);p.add_argument("--legacy-source", type=Path)
    p.add_argument("--modern-reference", type=Path, required=True);p.add_argument("--system-reference", type=Path, required=True)
    p.add_argument("--output-dir", type=Path, required=True);p.add_argument("--prepare-only", action="store_true")
    args = p.parse_args()
    for name in ("probe", "legacy_probe", "legacy_source", "modern_reference", "system_reference", "output_dir"):
        if getattr(args, name):setattr(args, name, getattr(args, name).resolve())
    args.output_dir.mkdir(parents=True, exist_ok=True)
    refs = {"modern": LargeReference(args.modern_reference), "system": LargeReference(args.system_reference)}
    source_paths = [ROOT / "build.zig", ROOT / "build.zig.zon", *sorted((ROOT / "src").rglob("*")),
                    *sorted((ROOT / "tools/br").glob("stored_memory*"))]
    source = {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in source_paths if path.is_file()}
    if args.prepare_only:
        baseline = prepare(args, refs);rows, budget, auxiliary, events = [], [], [], []
    else:
        require(args.probe, "public current Probe is required")
        baseline, rows, budget, auxiliary, events = campaign(args, refs)
    after = {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in source_paths if path.is_file()}
    if not args.prepare_only:require(source == after, "source changed during final stored campaign")
    report = {"schema": "vort-br-stored-memory-v1", "status": "prepared" if args.prepare_only else "ok",
              "utc": datetime.now(timezone.utc).isoformat(), "rows": rows, "budgets": budget, "auxiliary": auxiliary,
              "actual_probe_calls": len(events), "actual_error_counts": dict(Counter(e["report"]["error"] for e in events if e["report"]["error"])),
              "baseline_rows": len(baseline["rows"]), "baseline_manifest_sha256": digest((args.output_dir / "stored-baseline.json").read_bytes()),
              "references": {label: ref.provenance() for label, ref in refs.items()},
              "source_before": source, "source_after": after, "source_before_after_equal": source == after,
              "probe_path": str(args.probe) if args.probe else None, "probe_sha256": digest(args.probe.read_bytes()) if args.probe else None,
              "profile_lifetimes": "incremental owns persistent profile and deinit reports zero; reusable call-scoped profiles detach at call end and retain last real snapshot; independent backing ledger must be zero after all owners deinit",
              "scope": "bounded functional resource contracts and old compatible wire equality; no throughput, ratio or large-address-space inference"}
    out = args.output_dir / "stored-memory-report.json";out.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "rows": len(rows), "baseline_rows": len(baseline["rows"]), "actual_probe_calls": len(events), "report": str(out)}))


if __name__ == "__main__":main()
