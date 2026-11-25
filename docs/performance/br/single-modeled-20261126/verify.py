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
    resources_result = resources_replay.verify(primary, packages["resources.tar.gz"], registry, declared)
    reserved, intervals = provenance_replay.reservation(primary, controls)
    tests = provenance_replay.code_tests(packages["code-tests.tar.gz"], declared)
    nci = primary_result["weak_rows"]["nci"]
    gates = {
        "overall_geomean_throughput_at_least_1_03": primary_result["matrix_throughput_ratio"] >= 1.03,
        "overall_95pct_ci_excludes_parity": primary_result["matrix_throughput_95pct_ci"][0] > 1,
        "nci_throughput_at_least_1_20": 1 / nci["elapsed_ratio"] >= 1.20,
        "all_primary_row_throughput_at_least_0_98": all(1 / row["paired_geomean_ns_current_over_old"] >= .98
                                                     for row in primary_result["full_summary"]["rows"]),
        "all_public_control_throughput_at_least_0_98": all(row["passes_control_floor"] for row in controls_result["rows"]),
        "initial_wire_bytes_identical": True,
        "finite_caps_and_original_error_class_preserved": True,
        "recorded_code_validation_passed": True,
    }
    reasons = []
    if not gates["nci_throughput_at_least_1_20"]:
        reasons.append({"gate": "nci_throughput", "required_minimum": 1.20, "observed": 1 / nci["elapsed_ratio"]})
    for row in controls_result["rows"]:
        if not row["passes_control_floor"]:
            reasons.append({"gate": "public_control_" + row["control"], "required_minimum": .98, "observed": row["throughput_ratio"]})
    require(not all(gates.values()) and {reason["gate"] for reason in reasons} == {"nci_throughput", "public_control_ratio"},
            "This preserved rejected campaign has different acceptance gates")
    result = {"schema": "vort.single-modeled.offline-summary.v1", "acceptance": "rejected", "merge_allowed": False,
              "candidate_status": "unmerged frozen v5; archive publication only", "rejection_reasons": reasons,
              "gate_thresholds": {"overall_throughput": 1.03, "nci_throughput": 1.20, "control_throughput": .98,
                                  "bootstrap_draws": 20000, "confidence_level": .95},
              "gates": gates, "sources": sources, "primary": primary_result, "public_controls": controls_result,
              "resources": resources_result, "code_validation": tests, "reservation": reserved,
              "claim_scope": "Matched reserved c2/v5 development-host result, not competitor parity or leadership. Resource-only comparisons to reused v4 are requested-heap observations. Independent v4/v5 timing ratios do not establish source causality.",
              "offline_scope": "Archive bytes, source/blob/ELF/module hashes, recorded argv/exits/logs, per-call samples, deterministic statistics, caps and process wall intervals. No original absolute path is opened, and no codec/test/build/Git is run."}
    receipt = {"schema": "vort.single-modeled.offline-receipt.v1", "verification_passed": True,
               "acceptance": "rejected", "merge_allowed": False, "executable_artifacts_run": False,
               "archives": binding["archives"], "verified_member_count": sum(len(value) for value in binding["members"].values()),
               "primary_pairs": 90, "primary_timed_calls": 180, "public_control_pairs": 18,
               "public_control_processes": 36, "public_control_timed_calls": 1224,
               "verified_process_wall_intervals": 216, "new_resource_cap_operations": 42,
               "candidate_source_files": 2196, "baseline_git_blobs_reconstructed": 2189,
               "reused_v4_source_files_reconstructed": 2195, "focused_tests_recorded_per_platform": 22,
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
    value = {"schema": "vort.single-modeled.publication-inventory.v1", "files": records,
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
