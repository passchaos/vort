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


def verify(primary, resources, registry, declared):
    for name in ("all-src-before.json", "all-src-after.json", "all-src-after-build.json", "frozen-all-src-sha256.json"):
        require(load(resources, name) == registry, "Resource v5 source identity differs: " + name)
    require(load(resources, "candidate-source-sha256.json") == declared, "Resource nine-source identity differs")
    identity, final = load(resources, "identity-before.json"), load(resources, "identity-after.json")
    built, summary, campaign = load(resources, "build/result.json"), load(resources, "summary.json"), load(resources, "campaign.json")
    require(built["success"] and all(stage["exit_code"] == 0 for stage in built["stages"]), "Resource build receipt differs")
    helper = primary["source/src/tests/br_total_memory_helpers.zig"]
    for name, digest in (("bin/v5", built["executable_sha256"]), ("build/v5-record.o", built["record_object_sha256"]),
                         ("probe.zig", identity["common_probe_sha256"]), ("provenance.zig", identity["common_provenance_sha256"]),
                         ("source/resource_codec.zig", identity["common_wrapper_sha256"])):
        require(sha(resources[name]) == digest, "Resource executable/common identity differs: " + name)
    require(sha(helper) == identity["memory_helper_sha256"] == built["memory_helper_sha256"] ==
            final["actual_helper_sha256"], "Existing forced-moving helper differs")
    for name, digest in final["artifacts_after"].items():
        data = helper if name == "source/src/tests/br_total_memory_helpers.zig" else resources[name]
        require(sha(data) == digest, "Resource final artifact differs: " + name)
    baseline_identity = load(resources, "reused/source-baseline-v3-identity.json")
    v4_identity = load(resources, "reused/source-v4-identity.json")
    require(baseline_identity["baseline_revision"] == load(primary, "settings.json")["variants"]["old_exact"],
            "Reused resource baseline CID differs")
    elfs = {"v5": sha(resources["bin/v5"])}
    for variant, build in (("baseline", baseline_identity["builds"]["baseline"]), ("v4", v4_identity["build"])):
        elf = gzip.decompress(resources["reused/bin/" + variant + ".elf.gz"])
        require(build["success"] and sha(elf) == build["executable_sha256"] ==
                final["original_resource_elf_hashes_after"][variant] and
                sha(resources["reused/build/" + variant + "-record.o"]) == build["record_object_sha256"] and
                build["memory_helper_sha256"] == sha(helper), "Reused resource ELF/object/helper differs")
        elfs[variant] = sha(elf)
    v4_files = dict(load(resources, "reused/v4-src-files.json"))
    original_bindings = load(resources, "reused/v4-artifact-bindings.json")["files"]
    for archived, original in (("reused/v4-src-files.json", "compact-src-files.json"),
                               ("reused/v4-source-sha256.json", "compact-source-sha256.json"),
                               ("reused/v4-settings.json", "compact-settings.json"),
                               ("reused/source-v4-identity.json", "compact-source-identity.json"),
                               ("reused/build/v4-record.o", "build/compact-record.o")):
        data = resources[archived]
        require(len(data) == original_bindings[original]["bytes"] and sha(data) == original_bindings[original]["sha256"],
                "Original v4 artifact binding differs: " + original)
    require(len(v4_files) == 2195, "Reused v4 source count differs")
    for name, digest in v4_files.items():
        data = resources.get("reused/v4-source-delta/" + name, primary.get("source/" + name))
        require(data is not None and sha(data) == digest, "Reconstructed v4 source differs: " + name)
    require(sha(resources["reused/v4-source-sha256.json"]) == v4_identity["settings"]["source_manifest_sha256"],
            "Original v4 source manifest differs")
    for name, digest in load(resources, "reused/v4-source-sha256.json").items():
        require(v4_files[name] == digest, "Reused v4 declared source differs")
    fixtures = load(resources, "fixtures.json")
    require(len(fixtures) == len(campaign["rows"]) == len(summary["rows"]) == 14 and campaign["passed"],
            "Resource matrix incomplete")
    measured_rows = []
    for fixture in fixtures:
        case = fixture["case"]
        data = resources["fixtures/" + Path(fixture["path"]).name]
        require(len(data) == fixture["bytes"] == 65536 and sha(data) == fixture["sha256"], "Resource input differs")
        command = load(resources, "runs-v5/" + case + ".command.json")
        argv, _ = command_options(command)
        require(command["exit_code"] == 0 and argv[:3] == ["taskset", "-c", "1"], "Resource argv/exit differs")
        wire = resources["runs-v5/" + case + ".br"]
        row = next(row for row in summary["rows"] if row["case"] == case)
        require(row == next(row for row in campaign["rows"] if row["case"] == case), "Resource campaign/summary row differs")
        all_metrics = {}
        for variant in ("baseline", "v4", "v5"):
            stem = ("runs-v5/" if variant == "v5" else "reused/" + variant + "/") + case
            report = load(resources, stem + ".json")
            recorded_command = load(resources, stem + ".command.json")
            require(recorded_command["exit_code"] == 0 and report["case"] == case and
                    resources[stem + ".br"] == wire and report["input_sha256"] == fixture["sha256"] and
                    report["oracle_wire_sha256"] == sha(wire) and report["oracle_wire_bytes"] == len(wire),
                    "Resource wire/input binding differs")
            info = report["provenance"]
            expected = {"executable_sha256": elfs[variant], "optimize": "ReleaseFast", "target_arch": "x86_64",
                        "target_os": "linux", "target_abi": "gnu", "target_cpu": "skylake+pku+sgx", "cpu_affinity": "1"}
            require(all(info[k] == v for k, v in expected.items()) and
                    (report["quality"], report["mode"], report["window_bits"]) == (8, "generic", 16),
                    "Resource target/public options differ")
            phases(report, wire)
            all_metrics[variant] = metrics(report["unlimited"])
        require(all_metrics == row["resources"] and row["wire_sha256"] == sha(wire) and
                row["wire_bytes"] == len(wire) and row["new_cap_operations"] == 3, "Resource derived row differs")
        measured_rows.append(row)
    groups = {}
    for group, rows in (("silesia12", [row for row in measured_rows if row["case"] not in ("rle", "opaque")]),
                        ("all14", measured_rows)):
        values = {"cases": len(rows)}
        for variant in ("baseline", "v4"):
            for metric in ("requested_peak", "allocated", "alloc_requests", "acquisition_requests", "all_allocator_requests"):
                key = "v5_over_" + variant + "_" + metric
                ratios = [row["resources"]["v5"][metric] / row["resources"][variant][metric] for row in rows]
                require(all(row[key] == ratio for row, ratio in zip(rows, ratios)), "Resource row ratio differs")
                values[key] = math.exp(statistics.mean(math.log(value) for value in ratios))
        groups[group] = values
    require(groups == summary["groups"], "Recomputed resource geometric means differ")
    classification = load(resources, "build/classification.result.json")
    require(classification["exit_code"] == 0 and classification["tests_passed"] == 6 and
            sha(resources["bin/budget-classification-tests"]) == classification["executable_sha256"] and
            sha(resources["build/classification.stderr"]) == classification["stderr_sha256"] and
            b"All 6 tests passed." in resources["build/classification.stderr"], "Budget classification receipt differs")
    return {"verified_new_cases": 14, "verified_new_cap_operations": 42, "verified_reused_cap_operations": 84,
            "verified_v4_source_files": len(v4_files), "basic_budget_tests_recorded": 6, "groups": groups,
            "rows": measured_rows, "elf_sha256": elfs, "all_wire_bytes_equal": True,
            "finite_cap_error": "WorkingMemoryLimitExceeded", "caller_free_live_bytes": 0,
            "scope": "Existing force_moving_growth=true whole-operation requested heap; profile/tracker peaks and free ledgers. Excludes native RSS, stack, physical traffic, input/oracle/decode/report allocations, bookkeeping and remap internal transients. Resource throughput not measured; baseline/v4 reused without rerun."}
