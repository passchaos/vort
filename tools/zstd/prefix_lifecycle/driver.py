#!/usr/bin/env python3
"""Bounded public prefix lifecycle gate with independent libzstd receipts.

Run --preflight first. The full matrix adds magicless, unknown-size, policy,
initializer, provider-recovery and caller-output cases. Probe executables accept
only a config JSON path; each stage writes its own physical output artifact.
"""
from __future__ import annotations
import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
from driver_helpers.common import HERE, artifact, module, require, sources, write_json
from driver_helpers.execute import equivalence_checks, run_case
from driver_helpers.matrix import build_matrix


def adaptation_notes(receipt):
    notes = []
    for case in receipt["cases"]:
        name = case["name"]
        if case.get("reference_fact_only"):
            reason = "Invalid FULL byte inputs are C ABI facts; Vort takes an already parsed valid NativeDictionary"
        elif "encoder-bad-pledge" in name:
            reason = "C per-stage setPledgedSrcSize has no equivalent stage; Zig expected_input_len is fixed at typed initialization"
        elif "-magicless-" in name and name.endswith(("-skip", "-skip_empty")):
            reason = "Standard skippable bytes in C magicless mode are data parsing facts; only standard skip lifecycle is compared"
        else:
            continue
        notes.append({"reference_recipe": name, "typed_boundary": reason})
    return {"audit_and_vort_case_counts_are_independent": True,
            "snapshots": "C receipts retain actual getters/progress; public Vort prefix and stream snapshots retain raw JSON strings and parsed values",
            "parameters": "Vort resets clear bindings while keeping Zig policy; C format/checksum parameter restoration is not mirrored",
            "stream_completion": "Vort explicit reset_session or next_stream adapts the automatic C frame boundary",
            "standalone_calls": "Each standalone call explicitly supplies dictionary_usage=prefix and its own immutable borrowed dictionary",
            "error_names": "Vort semantic errors are declared exactly; integer C errors and chunk progress are not required to match bit-for-bit",
            "retained_c_boundaries": notes}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe-native", type=Path, required=True)
    parser.add_argument("--probe-x86", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--reference-zstd", type=Path)
    parser.add_argument("--preflight", action="store_true")
    args = parser.parse_args()
    root = args.output_dir.expanduser().resolve()
    root.mkdir(parents=True, exist_ok=True)
    reference = module("_prefix_driver_reference", HERE / "reference.py")
    fixtures = module("_prefix_driver_fixtures", HERE / "fixtures.py")
    library = reference.Library(args.reference_zstd)
    receipt = fixtures.generate(root / "reference", library)
    cases = build_matrix(receipt, root, preflight=args.preflight, library=library)
    targets = [("native", args.probe_native.expanduser().resolve(strict=True))]
    if args.probe_x86:
        targets.append(("x86", args.probe_x86.expanduser().resolve(strict=True)))
    executables = {label: artifact(path) for label, path in targets}
    source_before = sources()
    plan = {"mode": "preflight" if args.preflight else "full", "cases_per_target": len(cases),
            "targets": executables, "api_counts": dict(sorted(Counter(case["config"]["api"] for case in cases).items())),
            "cases": cases, "adaptations": adaptation_notes(receipt)}
    plan_artifact = write_json(root / "matrix-plan.json", plan)
    print(json.dumps({"status": "reference_ready", "mode": plan["mode"], "cases_per_target": len(cases),
                      "api_counts": plan["api_counts"], "reference_receipt": receipt["receipt_path"]}), flush=True)
    results = []
    with ThreadPoolExecutor(max_workers=4) as executor:
        pending = [executor.submit(run_case, root, label, path, case, library, receipt, executables[label])
                   for label, path in targets for case in cases]
        for future in as_completed(pending):
            result = future.result()
            results.append(result)
            if not result["passed"] or len(results) % 10 == 0:
                print(json.dumps({"status": "case_passed" if result["passed"] else "case_failed",
                                  "completed": len(results), "case": result["name"], "target": result["target"],
                                  "failure": result.get("failure")}), flush=True)
    order = {case["name"]: index for index, case in enumerate(cases)}
    results.sort(key=lambda value: (value["target"], order[value["name"]]))
    equality = equivalence_checks(results)
    final_executables = {label: artifact(path) for label, path in targets}
    unchanged_executables = executables == final_executables
    source_after = sources()
    changed_sources = [name for name in sorted(set(source_before) | set(source_after)) if source_before.get(name) != source_after.get(name)]
    failed = [value for value in results if not value["passed"]]
    routed = all(value.get("command_manifest_matches") is True
                 and value["command"][0] == executables[value["target"]]["path"] for value in results)
    passed = not failed and all(check["passed"] for check in equality) and unchanged_executables and not changed_sources and routed
    report = {"schema": "vort.zstd.prefix_lifecycle.driver.v1", "mode": plan["mode"], "passed": passed,
              "actual_command": [sys.executable, *sys.argv], "working_directory": str(Path.cwd().resolve()),
              "timestamp_utc": datetime.now(timezone.utc).isoformat(), "reference": library.provenance(),
              "reference_fixture_receipt": artifact(receipt["receipt_path"]), "reference_audit": receipt["audit"],
              "reference_recipe_names": [case["name"] for case in receipt["cases"]],
              "matrix_plan": plan_artifact, "adaptations": plan["adaptations"],
              "source_before": source_before, "source_after": source_after, "changed_sources": changed_sources,
              "executables_before": executables, "executables_after": final_executables,
              "executables_unchanged": unchanged_executables, "results": results, "persistent_byte_compatibility": equality,
              "commands_match_target_manifests": routed,
              "counters": {"reference_audit_observations": receipt["audit"]["observations"],
                           "reference_recipes": len(receipt["cases"]), "cases_per_target": len(cases),
                           "executed_cases": len(results), "passed_cases": len(results) - len(failed), "failed_cases": len(failed),
                           "persistent_byte_compatibility_groups": len(equality)}}
    report_artifact = write_json(root / "report.json", report)
    print(json.dumps({"status": "passed" if passed else "failed", "report": report_artifact, "counters": report["counters"]}), flush=True)
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
