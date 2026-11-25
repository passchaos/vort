"""Verify recorded forced-moving requested-heap accounting and finite caps."""
import gzip
import math
from pathlib import Path
import statistics

from archive_io import command_options, load, require, sha


def metrics(measured):
    return {"requested_peak": measured["tracked_peak"], "allocated": measured["tracked_allocated"],
            "alloc_requests": measured["alloc_requests"], "resize_requests": measured["resize_requests"],
            "remap_requests": measured["remap_requests"], "free_requests": measured["free_requests"],
            "acquisition_requests": measured["alloc_requests"] + measured["resize_requests"] + measured["remap_requests"],
            "all_allocator_requests": measured["alloc_requests"] + measured["resize_requests"] + measured["remap_requests"] + measured["free_requests"],
            "freed": measured["tracked_freed_after_caller_free"]}


def phases(report, wire):
    peak = report["unlimited"]["tracked_peak"]
    require(peak > 0 and report["force_moving_growth"] and report["passed"] and
            report["oracle_roundtrip_verified"], "Resource policy/oracle receipt differs")
    for name, cap in (("unlimited", None), ("exact_peak", peak), ("one_below_peak", peak - 1)):
        measured = report[name]
        profile = measured["profile"]
        require(measured["limit"] == profile["limit"] == cap, "Resource cap differs")
        require(profile["available"] and profile["peak_requested_bytes"] == measured["tracked_peak"] ==
                measured["tracked_owned_peak"] and measured["profile_matches_tracked_peak"], "Resource profile/peak differs")
        require(measured["tracked_allocated"] == measured["tracked_freed_after_caller_free"] and
                measured["tracked_live_after_caller_free"] == profile["live_requested_bytes"] == 0 and
                measured["balanced_after_caller_free"], "Resource free ledger differs")
        require(measured["tracked_allocated"] - measured["tracked_freed_after_encode"] ==
                measured["tracked_live_after_encode"], "Resource handoff ledger differs")
        if name == "one_below_peak":
            require(measured["error_name"] == "WorkingMemoryLimitExceeded" and measured["wire_bytes"] is None and
                    measured["wire_sha256"] is None and not measured["wire_equal"] and
                    measured["tracked_live_after_encode"] == 0 and measured["tracked_peak"] <= cap,
                    "Finite cap refusal/error class differs")
        else:
            require(measured["error_name"] == "" and measured["wire_equal"] and
                    measured["wire_bytes"] == measured["tracked_live_after_encode"] == len(wire) and
                    measured["wire_sha256"] == sha(wire) and measured["tracked_peak"] == peak,
                    "Resource successful wire/accounting differs")


def verify(primary, resources, registry, declared, baseline_sources):
    for name in ("all-src-before.json", "all-src-after.json", "all-src-after-build.json", "frozen-all-src-sha256.json"):
        require(load(resources, name) == registry, "V6 resource source registry differs")
    require(load(resources, "candidate-source-sha256.json") == declared, "V6 resource source6 differs")
    require(load(resources, "baseline-src-before.json") == load(resources, "baseline-src-after.json") == baseline_sources,
            "Resource baseline source identity differs")
    identity, final = load(resources, "identity-before.json"), load(resources, "identity-after.json")
    built, summary, campaign = load(resources, "build/result.json"), load(resources, "summary.json"), load(resources, "campaign.json")
    require(built["success"] and all(stage["exit_code"] == 0 for stage in built["stages"]), "Resource build incomplete")
    require(sha(primary["all-src-sha256.json"]) == identity["source_manifest_sha256"] and
            sha(primary["candidate-source-sha256.json"]) == identity["candidate_manifest_sha256"], "Original V6 manifest byte binding differs")
    helper = primary["source/src/tests/br_total_memory_helpers.zig"]
    require(sha(helper) == identity["memory_helper_sha256"] == built["memory_helper_sha256"] == final["memory_helper_sha256"],
            "Resource helper differs")
    for name, digest in (("bin/v6", built["executable_sha256"]), ("build/v6-record.o", built["record_object_sha256"]),
                         ("probe.zig", identity["common_probe_sha256"]), ("provenance.zig", identity["common_provenance_sha256"]),
                         ("source/resource_codec.zig", identity["common_wrapper_sha256"])):
        require(sha(resources[name]) == digest, "V6 resource compiled/common artifact differs")
    baseline_identity = load(resources, "reused/baseline-source-identity.json")
    baseline_build = baseline_identity["builds"]["baseline"]
    require(baseline_identity["baseline_revision"] == load(primary, "settings.json")["variants"]["old_exact"] and
            baseline_build["success"] and sha(resources["reused/bin/baseline"]) == baseline_build["executable_sha256"] ==
            identity["baseline_resource_elf_sha256"] == final["baseline_resource_elf_sha256"] and
            sha(resources["reused/build/baseline-record.o"]) == baseline_build["record_object_sha256"] and
            baseline_build["memory_helper_sha256"] == sha(helper), "Resource c2 ELF/object/helper differs")
    for name, record in load(resources, "reused-baseline-before.json").items():
        require(sha(resources[name]) == record["sha256"], "Reused baseline raw byte binding differs")
    fixtures = load(resources, "fixtures.json")
    require(len(fixtures) == len(campaign["rows"]) == len(summary["rows"]) == 14 and campaign["passed"], "Resource matrix incomplete")
    elfs = {"baseline": baseline_build["executable_sha256"], "v6": built["executable_sha256"]}
    rows = []
    for fixture in fixtures:
        case = fixture["case"]
        data = resources["fixtures/" + Path(fixture["path"]).name]
        require(len(data) == fixture["bytes"] == 65536 and sha(data) == fixture["sha256"], "Resource input differs")
        wire = resources["runs-v6/" + case + ".br"]
        row = next(row for row in summary["rows"] if row["case"] == case)
        require(row == next(row for row in campaign["rows"] if row["case"] == case), "Resource campaign row differs")
        resources_actual = {}
        for variant in ("baseline", "v6"):
            stem = ("runs-v6/" if variant == "v6" else "reused/baseline/") + case
            report, command = load(resources, stem + ".json"), load(resources, stem + ".command.json")
            argv, _ = command_options(command)
            require(command["exit_code"] == 0 and argv[:3] == ["taskset", "-c", "1"] and
                    report["case"] == case and resources[stem + ".br"] == wire and report["input_sha256"] == fixture["sha256"] and
                    report["oracle_wire_sha256"] == sha(wire) and report["oracle_wire_bytes"] == len(wire), "Resource raw/wire/argv differs")
            info = report["provenance"]
            expected = {"executable_sha256": elfs[variant], "optimize": "ReleaseFast", "target_arch": "x86_64", "target_os": "linux",
                        "target_abi": "gnu", "target_cpu": "skylake+pku+sgx", "cpu_affinity": "1"}
            require(all(info[key] == value for key, value in expected.items()) and
                    (report["quality"], report["mode"], report["window_bits"]) == (8, "generic", 16), "Resource target/options differ")
            phases(report, wire)
            resources_actual[variant] = metrics(report["unlimited"])
        require(resources_actual == row["resources"] and row["new_cap_operations"] == 3 and row["wire_bytes"] == len(wire) and
                row["wire_sha256"] == sha(wire), "Resource derived row differs")
        rows.append(row)
    groups = {}
    for group, selected in (("silesia12", [row for row in rows if row["case"] not in ("rle", "opaque")]), ("all14", rows)):
        computed = {"cases": len(selected)}
        for metric in ("requested_peak", "allocated", "alloc_requests", "acquisition_requests", "all_allocator_requests"):
            key = "v6_over_baseline_" + metric
            ratios = [row["resources"]["v6"][metric] / row["resources"]["baseline"][metric] for row in selected]
            require(all(row[key] == ratio for row, ratio in zip(selected, ratios)), "Resource row ratio differs")
            computed[key] = math.exp(statistics.mean(math.log(value) for value in ratios))
        groups[group] = computed
    require(groups == summary["groups"], "Resource geometric statistics differ")
    classification = load(resources, "build/classification.result.json")
    require(classification["exit_code"] == 0 and classification["tests_passed"] == 6 and
            sha(resources["bin/budget-classification-tests"]) == classification["executable_sha256"] and
            sha(resources["build/classification.stderr"]) == classification["stderr_sha256"] and
            b"All 6 tests passed." in resources["build/classification.stderr"], "Resource six-test receipt differs")
    return {"verified_new_cases": 14, "verified_new_cap_operations": 42, "verified_reused_cap_operations": 42,
            "basic_budget_tests_recorded": 6, "groups": groups, "rows": rows, "elf_sha256": elfs,
            "all_wire_bytes_equal": True, "finite_cap_error": "WorkingMemoryLimitExceeded", "caller_free_live_bytes": 0,
            "scope": "Forced-moving whole-operation requested heap, not RSS/stack/physical traffic. Input/oracle/decode/report, bookkeeping and remap internal transients excluded. Peak ratio1.0 is no reduction. Reused c2 reports not rerun; no resource throughput measured."}
