#!/usr/bin/env python3
"""Read only local packages, replay statistics, and report preserved rejection."""
import argparse
import csv
import io
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
from archive_io import load, read_archives, require, sha
import pilot_replay
import resource_replay
import source_tests
import statistics_replay


def encoded(value):
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()


def replay(root):
    packages, binding = read_archives(root)
    campaign, source, resource, validation = [packages[name] for name in ("campaign.tar.gz", "sources.tar.gz", "resources.tar.gz", "validation.tar.gz")]
    statistics = statistics_replay.replay(campaign)
    sources = source_tests.verify_sources(campaign, source, resource)
    resources = resource_replay.verify(resource)
    tests = source_tests.verify_tests(validation)
    pilots = pilot_replay.verify(campaign, load(source, "source-mapping.json"))
    require(load(campaign, "formal-exit.json")["exit_code"] == load(campaign, "controls-exit.json")["exit_code"] == 0,
            "Producer campaign exit differs")
    controls = statistics["controls"]
    failures = [{"case": row["case"], "throughput_ratio": row["throughput_ratio"], "throughput_ci95": row["throughput_ci95"],
                 "required_minimum": .98, "paired_throughput_ratios": row["paired_throughput_ratios"]}
                for row in controls["rows"] if row["throughput_ratio"] < .98]
    require({row["case"] for row in failures} == {"nci.64k.L8", "mozilla.64k.L2"}, "Preserved rejected control outcomes differ")
    require(all(statistics["formal"]["gate_checks"].values()) and not controls["acceptance_pass"], "Primary/control gate distinction differs")
    result = {"schema": "vort.zstd.controlled-index.archive-summary.v1", "decision": "rejected", "merge_allowed": False,
              "pack_readiness": True, "evidence_integrity_pass": True, "complete_acceptance_pass": False,
              "formal": statistics["formal"], "controls": controls, "failed_controls": failures,
              "secondary_reference_diagnostic": statistics["secondary_reference_diagnostic"], "sources": sources,
              "resources": resources, "tests": tests, "pilots": pilots,
              "reducer": statistics["reducer"], "reducer_expected_exit": {"code": 1, "reason": "expected_gate_failure", "evidence_fault": False},
              "production_state": "Main production remains baseline; experimental candidate unmerged",
              "claim_limits": ["Whole-operation control floor remains effective when CI includes parity or a level has no direct candidate caller.",
                               "No source-causal or layout attribution is inferred for either failed control.",
                               "Reference diagnostic uses different default presets/windows; development-host observational, not matched quality or industry best.",
                               "Raw codec_thread_policy internal-auto preserved; planned codec_threads1 is not all-control runtime thread instrumentation."]}
    receipt = {"schema": "vort.zstd.controlled-index.archive-receipt.v1", "verification_passed": True, "decision": "rejected", "merge_allowed": False,
               "pack_readiness": True, "archives": binding["archives"], "members": sum(len(rows) for rows in binding["members"].values()),
               "formal_pairs": 72, "formal_vort_timed_batches": 144, "control_pairs": 90, "control_vort_timed_batches": 180,
               "control_vort_timed_calls": sum(row["iterations_per_child"] * row["pairs"] * 2 for row in controls["rows"]),
               "resource_artifact_hashes": 828, "resource_core_process_ledgers": 170,
               "scope": "Package byte hashes, source snapshots, original Planck math/draw digests/gates, all raw pairs and core resource ledgers. No codec/build/test/WASM/SO/original-path execution."}
    rows = []
    for phase in ("formal", "controls"):
        for pair in statistics[phase]["recomputed_pairs"]:
            for variant in ("baseline", "candidate"):
                process = pair["processes"][variant]
                rows.append({"phase": phase, "case": pair["case"], "round": pair["round"], "order": pair["order"], "variant": variant,
                             **{key: process[key] for key in ("vort_ns", "reference_ns", "initial_wire_bytes", "initial_wire_sha256", "timed_length_mix", "started_unix", "ended_unix")}})
    fields = list(rows[0])
    stream = io.StringIO(newline="")
    writer = csv.DictWriter(stream, fields, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    return result, {"summary.json": encoded(result), "verification-receipt.json": encoded(receipt), "formal-control-raw.csv": stream.getvalue().encode()}


def inventory(root):
    records = {path.name: {"bytes": path.stat().st_size, "sha256": sha(path.read_bytes())}
               for path in sorted(root.iterdir()) if path.is_file() and path.name not in ("inventory.json", "SHA256SUMS")}
    value = encoded({"schema": "vort.zstd.controlled-index.inventory.v1", "files": records})
    sums = "".join(row["sha256"] + "  " + name + "\n" for name, row in records.items()) + sha(value) + "  inventory.json\n"
    return value, sums.encode()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--write-derived", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    result, derived = replay(root)
    if args.write_derived:
        for name, data in derived.items():
            (root / name).write_bytes(data)
        value, sums = inventory(root)
        (root / "inventory.json").write_bytes(value)
        (root / "SHA256SUMS").write_bytes(sums)
    else:
        for name, data in derived.items():
            require((root / name).read_bytes() == data, "Derived archive artifact differs: " + name)
        value, sums = inventory(root)
        require((root / "inventory.json").read_bytes() == value and (root / "SHA256SUMS").read_bytes() == sums, "Publication inventory differs")
    print(json.dumps({"verification": "passed", "decision": "rejected", "merge_allowed": False, "pack_readiness": True,
                      "formal_throughput_geomean": result["formal"]["throughput_geomean"],
                      "formal_throughput_ci95": result["formal"]["bootstrap"]["throughput_ci95"],
                      "failed_controls": result["failed_controls"]}, sort_keys=True))


if __name__ == "__main__":
    main()
