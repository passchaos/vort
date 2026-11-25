#!/usr/bin/env python3
"""Self-contained offline replay. No codec, build, test, WASM or Git invocation."""
import argparse
import csv
import io
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
from archive_io import read_archives, require, sha
import controls_replay
import primary_replay
import provenance_replay
import resources_replay
import profile_replay


def json_bytes(value):
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()


def csv_bytes(rows, fields):
    output = io.StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=fields, extrasaction="ignore", lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    return output.getvalue().encode()


def replay(root):
    packages, binding = read_archives(root)
    primary, controls = packages["primary.tar.gz"], packages["controls.tar.gz"]
    sources, registry, declared = primary_replay.verify_sources(primary, controls)
    primary_result = primary_replay.verify(primary)
    controls_result, raw_calls = controls_replay.verify(primary, controls)
    baseline_sources = {name: sha(primary.get("baseline-delta/" + name, primary["source/" + name]))
                        for name in json.loads(primary["baseline-src-blobs.json"])}
    resources_result = resources_replay.verify(primary, packages["resources.tar.gz"], registry, declared, baseline_sources)
    profile_result = profile_replay.verify(primary, packages["profile.tar.gz"], registry, declared, baseline_sources)
    reserved, intervals = provenance_replay.reservation(primary, controls, packages["profile.tar.gz"])
    tests = provenance_replay.code_tests(packages["code-tests.tar.gz"], primary, declared)
    matrix_speed = primary_result["matrix_throughput_ratio"]
    nci_speed = 1 / primary_result["weak_rows"]["nci"]["elapsed_ratio"]
    primary_controls = [{"case": row["case"], "throughput_ratio": 1 / row["paired_geomean_ns_current_over_old"],
                         "elapsed_95pct_ci": row["paired_ratio_bootstrap_95pct_ci"],
                         "passes_0_98_floor": 1 / row["paired_geomean_ns_current_over_old"] >= .98}
                        for row in primary_result["full_summary"]["rows"]]
    gates = {"overall_geomean_throughput_at_least_1_03": matrix_speed >= 1.03,
             "overall_95pct_ci_excludes_parity": primary_result["matrix_throughput_95pct_ci"][0] > 1,
             "nci_throughput_at_least_1_20": nci_speed >= 1.20,
             "all_primary_row_throughput_at_least_0_98": all(row["passes_0_98_floor"] for row in primary_controls),
             "all_public_control_throughput_at_least_0_98": all(row["passes_control_floor"] for row in controls_result["rows"]),
             "initial_wire_bytes_identical": True, "finite_caps_and_original_error_class_preserved": True,
             "recorded_code_test_outputs_and_module_match": True}
    reasons = []
    if not gates["overall_geomean_throughput_at_least_1_03"]:
        reasons.append({"gate": "overall_throughput", "required_minimum": 1.03, "observed": matrix_speed})
    if not gates["nci_throughput_at_least_1_20"]:
        reasons.append({"gate": "nci_throughput", "required_minimum": 1.20, "observed": nci_speed})
    for row in primary_controls:
        if not row["passes_0_98_floor"]:
            reasons.append({"gate": "primary_control_" + row["case"], "required_minimum": .98, "observed": row["throughput_ratio"]})
    for row in controls_result["rows"]:
        if not row["passes_control_floor"]:
            reasons.append({"gate": "public_control_" + row["control"], "required_minimum": .98, "observed": row["throughput_ratio"]})
    require({reason["gate"] for reason in reasons} == {"overall_throughput", "nci_throughput", "primary_control_ooffice", "primary_control_samba"},
            "Preserved rejected V6 gate outcome differs")
    result = {"schema": "vort.parameter-context.offline-summary.v1", "decision": "rejected", "acceptance": "rejected", "merge_allowed": False,
              "candidate_status": "Independent unmerged frozen V6 parameter-context candidate", "rejection_reasons": reasons,
              "gate_thresholds": {"overall_throughput": 1.03, "nci_throughput": 1.20, "control_throughput": .98,
                                  "bootstrap_draws": 20000, "confidence_level": .95},
              "gates": gates, "primary_row_controls": primary_controls, "sources": sources, "primary": primary_result,
              "public_controls": controls_result, "resources": resources_result, "profile": profile_result,
              "code_validation": tests, "reservation": reserved,
              "progress_log_provenance_check": {"receipt_digest_matches_complete_final_log": tests["progress_log_snapshot_binding"]["matches_complete_final_log"],
                  "receipt_digest_matches_verified_prefix": True, "scope": "Old progress snapshot binds27-byte prefix; final complete log separately archive-hashed"},
              "claim_scope": "Reserved c2/V6 comparison on fixed development host; all public controls pass but primary fails. No source causality from independent V4/V5 epochs, profile2->1 or requested-peak1.0, and no leadership claim.",
              "offline_scope": "Only archive/source/ELF/reference/module hashes, raw samples, deterministic math, resource ledgers, recorded outputs and process intervals. Original absolute paths are provenance strings; no codec/test/build/ELF/WASM/Git execution or original directory dependency."}
    receipt = {"schema": "vort.parameter-context.offline-receipt.v1", "verification_passed": True, "decision": "rejected", "merge_allowed": False,
               "executable_artifacts_run": False, "archives": binding["archives"],
               "verified_member_count": sum(len(value) for value in binding["members"].values()),
               "primary_pairs": 90, "primary_timed_calls": 180, "public_control_pairs": 18, "public_control_processes": 36,
               "public_control_timed_calls": 1224, "verified_process_wall_intervals": 216, "new_resource_cap_operations": 42,
               "candidate_source_files": 2193, "baseline_git_blobs_reconstructed": 2189, "candidate_changed_or_new_files": 6,
               "profile_rows": 4, "native_real_tests_with_imports_recorded": 22, "fixture_tests_per_platform_recorded": 10,
               "scope": result["offline_scope"]}
    resource_rows = []
    for row in resources_result["rows"]:
        for variant, metrics in row["resources"].items():
            resource_rows.append({"case": row["case"], "variant": variant, "wire_bytes": row["wire_bytes"],
                                  "wire_sha256": row["wire_sha256"], **metrics})
    derived = {
        "summary.json": json_bytes(result), "offline-receipt.json": json_bytes(receipt),
        "primary-pairs.csv": primary["raw-pairs.csv"],
        "control-calls.csv": csv_bytes(raw_calls, ["control", "round", "order", "variant", "index", "owned_encode_free_ns", "wire_bytes", "mix"]),
        "process-intervals.csv": csv_bytes(intervals, ["phase", "report", "started_unix", "ended_unix"]),
        "resource-rows.csv": csv_bytes(resource_rows, ["case", "variant", "wire_bytes", "wire_sha256", "requested_peak", "allocated", "freed", "alloc_requests", "resize_requests", "remap_requests", "free_requests", "acquisition_requests", "all_allocator_requests"]),
    }
    return result, derived


def inventory(root):
    names = sorted(path.name for path in root.iterdir() if path.is_file() and path.name not in ("inventory.json", "SHA256SUMS"))
    require(all(path.is_file() for path in root.iterdir()), "Unexpected publication subdirectory")
    records = {}
    for name in names:
        data = (root / name).read_bytes()
        records[name] = {"bytes": len(data), "sha256": sha(data)}
    value = {"schema": "vort.parameter-context.publication-inventory.v1", "files": records,
             "scope": "All publication files except inventory.json and SHA256SUMS; SHA256SUMS binds inventory.json and every other file"}
    data = json_bytes(value)
    sums = "".join(record["sha256"] + "  " + name + "\n" for name, record in records.items())
    sums += sha(data) + "  inventory.json\n"
    return data, sums.encode()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent,
                        help="Copied publication directory; defaults to this script's directory")
    parser.add_argument("--write-derived", action="store_true", help="Regenerate derived JSON/CSV and inventories using preserved raw data")
    args = parser.parse_args()
    root = args.root.resolve()
    result, derived = replay(root)
    if args.write_derived:
        for name, data in derived.items():
            (root / name).write_bytes(data)
        inv, sums = inventory(root)
        (root / "inventory.json").write_bytes(inv)
        (root / "SHA256SUMS").write_bytes(sums)
    else:
        for name, data in derived.items():
            require((root / name).read_bytes() == data, "Derived publication differs: " + name)
        inv, sums = inventory(root)
        require((root / "inventory.json").read_bytes() == inv, "Publication inventory differs")
        require((root / "SHA256SUMS").read_bytes() == sums, "Publication SHA256SUMS differs")
    print(json.dumps({"verification": "passed", "acceptance": result["acceptance"], "merge_allowed": result["merge_allowed"],
                      "primary_pairs": 90, "control_pairs": 18, "control_calls": 1224,
                      "process_wall_intervals": 216, "resource_cap_operations": 42,
                      "rejection_reasons": result["rejection_reasons"]}, sort_keys=True))


if __name__ == "__main__":
    main()
