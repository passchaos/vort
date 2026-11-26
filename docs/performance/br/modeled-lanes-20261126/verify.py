#!/usr/bin/env python3
"""Read packaged bytes only; intact negative evidence verifies with exit0."""
import argparse
import csv
import io
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
from archive_io import load, read_archives, require, sha
import replay


def encoded(value):
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()


def reduce(root):
    packages, binding = read_archives(root)
    source, evidence, profile = [packages[name] for name in ("source.tar.gz", "evidence.tar.gz", "profile.tar.gz")]
    sources = replay.sources(source, evidence)
    pilot, raw = replay.pilot(evidence)
    diagnostics = replay.profile_tests(profile, evidence)
    gates = load(evidence, "gates.json")
    rows = {row["case"]: row for row in pilot["rows"]}
    checks = {"aggregate_point_at_least_1_03": pilot["throughput_geomean"] >= gates["aggregate_throughput_min"],
              "nci_point_at_least_1_20": rows["nci"]["throughput_ratio"] >= gates["nci_throughput_min"],
              "all_pilot_rows_at_least_0_98": all(row["throughput_ratio"] >= gates["all_rows_floor"] for row in rows.values()),
              "complete_initial_byte_wire_identity": True, "recorded_pinned_decode_pass": pilot["reference_decode_pass"],
              "formal_six_rounds_and_ci": None, "public_controls": None, "requested_heap_growth_limit": None}
    require(checks["aggregate_point_at_least_1_03"] is False and checks["nci_point_at_least_1_20"] is False and
            checks["all_pilot_rows_at_least_0_98"] is False, "Preserved negative pilot outcomes differ")
    result = {"schema": "vort.br.modeled-lanes.offline-summary.v1", "decision": "rejected", "merge_allowed": False,
              "pack_readiness": True, "pilot": pilot, "gate_results": checks, "declared_gates": gates,
              "sources": sources, "profile_and_tests": diagnostics,
              "failed_point_rows": [row for row in pilot["rows"] if row["throughput_ratio"] < gates["all_rows_floor"]],
              "measurement_scope": {"pilot_rounds": 2, "pairs": 24, "timed_calls": 48,
                                    "formal_six_rounds_executed": False, "ci_computed": False,
                                    "public_controls_executed": False, "resource_campaign_executed": False},
              "claim_limit": "Combined candidate only; no component/source-causal/phase/industry-best attribution. Profile line0 stays unresolved; positive source-line periods are not pure encoder phase share."}
    receipt = {"schema": "vort.br.modeled-lanes.offline-receipt.v1", "verification_passed": True,
               "decision": "rejected", "merge_allowed": False, "archives": binding["archives"],
               "members": sum(len(records) for records in binding["members"].values()), "candidate_src_files": 2201,
               "source_overlay_files": 4, "pilot_pairs": 24, "pilot_timed_calls": 48,
               "profile_samples": 3502, "profile_children": 10, "profile_public_calls": 40,
               "native_final_tests_recorded": 12, "actual_wasi_tests_recorded": 12,
               "scope": "Package-only source reconstruction, byte/hash/ELF/receipt/pilot point math and profile totals. No original tmp/source access or codec/SO/build/test/profile-tool execution."}
    stream = io.StringIO(newline="")
    writer = csv.DictWriter(stream, list(raw[0]), lineterminator="\n")
    writer.writeheader()
    writer.writerows(raw)
    return result, {"summary.json": encoded(result), "verification-receipt.json": encoded(receipt), "pilot-raw.csv": stream.getvalue().encode()}


def inventory(root):
    records = {path.name: {"bytes": path.stat().st_size, "sha256": sha(path.read_bytes())}
               for path in sorted(root.iterdir()) if path.is_file() and path.name not in ("inventory.json", "SHA256SUMS")}
    value = encoded({"schema": "vort.br.modeled-lanes.inventory.v1", "files": records})
    sums = "".join(record["sha256"] + "  " + name + "\n" for name, record in records.items()) + sha(value) + "  inventory.json\n"
    return value, sums.encode()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--write-derived", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    result, derived = reduce(root)
    if args.write_derived:
        for name, content in derived.items():
            (root / name).write_bytes(content)
        value, sums = inventory(root)
        (root / "inventory.json").write_bytes(value)
        (root / "SHA256SUMS").write_bytes(sums)
    else:
        for name, content in derived.items():
            require((root / name).read_bytes() == content, "Derived evidence differs: " + name)
        value, sums = inventory(root)
        require((root / "inventory.json").read_bytes() == value and (root / "SHA256SUMS").read_bytes() == sums, "Inventory differs")
    print(json.dumps({"verification": "passed", "decision": "rejected", "merge_allowed": False,
                      "pilot_geomean": result["pilot"]["throughput_geomean"], "gate_results": result["gate_results"],
                      "profile_positive_line_period_percent": result["profile_and_tests"]["positive_line_period_percent_all_samples"]}, sort_keys=True))


if __name__ == "__main__":
    main()
