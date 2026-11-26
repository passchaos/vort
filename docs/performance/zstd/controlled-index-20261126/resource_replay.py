"""Recompute the core requested-heap contracts from all 170 saved processes."""
import json
import posixpath

from archive_io import load, require, sha


def verify(data):
    hashes = load(data, "artifact-hashes.json")
    require(len(hashes) == 828, "Resource artifact count differs")
    for name, expected in hashes.items():
        require(name in data and sha(data[name]) == expected, "Resource original artifact differs: " + name)
    manifest, summary, cases = load(data, "manifest.json"), load(data, "summary.json"), load(data, "fixtures.json")
    require(manifest["complete"] and len(cases) == 14 and len(manifest["runs"]) == 170 and
            {key: value for key, value in manifest.items() if key != "runs"} == summary, "Resource terminal summary differs")
    identities = load(data, "probe-identities-after.json")["artifacts"]
    for name, identity in identities.items():
        require(sha(data[name]) == identity["sha256"] and len(data[name]) == identity["bytes"], "Resource probe/ELF differs")
    by_name = {case["case"]: case for case in cases}
    for case in cases:
        content = data["fixtures/" + posixpath.basename(case["path"])]
        require(len(content) == case["bytes"] and sha(content) == case["sha256"], "Resource input differs")
    groups, reports = {}, {}
    for record in manifest["runs"]:
        name = "runs/" + posixpath.basename(record["report"])
        report, command = load(data, name), load(data, "runs/" + posixpath.basename(record["command"]))
        require(command["exit_code"] == 0 and command["argv"][:3] == ["taskset", "-c", "9"], "Resource command failed or affinity differs")
        raw_stdout = data[name.removesuffix(".json") + ".stdout"]
        require(json.loads(raw_stdout) == report, "Resource original stdout/report differ")
        case_name = next(case for case in by_name if name.startswith("runs/" + case + "-"))
        tail = name[len("runs/" + case_name + "-"):].removesuffix(".json")
        variant, label = tail.split("-", 1)
        require(variant in ("baseline", "candidate"), "Resource variant differs")
        case = by_name[case_name]
        if case["dictionary_path"]:
            dictionary = data["fixtures/" + posixpath.basename(case["dictionary_path"])]
            api = "encodeFrameWithLevelAndOptionsAndDictionaryAlloc"
        else:
            dictionary = b""
            api = "encodeFrameWithLevelAlloc" if report["mode"] == "plain" else "encodeFrameWithLevelAndOptionsAlloc"
        require(report["input_bytes"] == case["bytes"] and report["input_sha256"] == case["sha256"] and
                report["level"] == 3 and report["api"] == api and report["dictionary_bytes"] == len(dictionary) and
                report["resolved_strategy"] == "greedy" and report["resolved_match_search_budget"] == 24 and
                report["resolved_rep_beam_search"] is False and report["strategy_override"] == "auto" and
                report["control_profile_enabled"] is False, "Resource public settings differ")
        heap, profile = report["requested_heap"], report["memory_profile"]
        require(heap["allocated_bytes"] == heap["freed_bytes"] and heap["live_after_caller_free"] ==
                heap["active_allocations_after_caller_free"] == heap["ownership_errors"] == heap["physical_backing_oom"] == 0,
                "Resource caller-free/backing ledger differs")
        if report["mode"] == "observed":
            require(profile["available"] and profile["live_requested_bytes"] == 0 and
                    profile["peak_requested_bytes"] == heap["peak_bytes"] and profile["limit"] == report["cap"],
                    "Resource observed profile/tracker differs")
        wire = None
        if report["error_name"] is None:
            require(record["wire"] is not None, "Successful resource wire is missing")
            wire = data["runs/" + posixpath.basename(record["wire"])]
            require(sha(wire) == report["wire_sha256"] and len(wire) == report["output_bytes"] == heap["live_before_caller_free"],
                    "Resource successful wire/handoff differs")
        else:
            require(record["wire"] is None and heap["live_before_caller_free"] == 0, "Resource failure handoff differs")
        groups.setdefault((case_name, variant), {})[label] = (report, wire)
        reports[name] = report
    for case in cases:
        baseline_wire = groups[case["case"], "baseline"]["plain"][1]
        for variant in ("baseline", "candidate"):
            group = groups[case["case"], variant]
            peak = group["unlimited"][0]["requested_heap"]["peak_bytes"]
            require(peak > 0, "Resource observed peak is invalid")
            for label in ("plain", "unlimited", "exactpeak"):
                report, wire = group[label]
                require(report["error_name"] is None and wire == baseline_wire, "Resource complete wire equality differs")
            require(group["exactpeak"][0]["cap"] == peak, "Exact-peak cap differs")
            minus = group["peakminus1"][0]
            require(minus["cap"] == peak - 1 and minus["error_name"] == "WorkingMemoryLimitExceeded" and
                    minus["requested_heap"]["injected_backing_oom"] == 0 and minus["requested_heap"]["peak_bytes"] <= peak - 1,
                    "Resource finite-cap refusal class differs")
            for label, fail_after in (("backingoom0", 0), ("backingoom1", 1)):
                oom = group[label][0]
                require(oom["error_name"] == "OutOfMemory" and oom["fail_after"] == fail_after and
                        oom["requested_heap"]["injected_backing_oom"] > 0, "Injected backing OOM class differs")
        row = next(row for row in summary["cases"] if row["case"] == case["case"])
        require(row["wire_bytes"] == len(baseline_wire) and row["wire_sha256"] == sha(baseline_wire), "Resource summary wire differs")
        for variant in ("baseline", "candidate"):
            unlimited = groups[case["case"], variant]["unlimited"][0]
            metrics = {"peak_requested_bytes": unlimited["memory_profile"]["peak_requested_bytes"],
                       **{key: unlimited["requested_heap"][key] for key in ("allocated_bytes", "alloc_attempts", "alloc_successes", "forced_growth_refusals")}}
            require(metrics == row["metrics"][variant], "Resource summary requested metrics differ")
    for variant in ("baseline", "candidate"):
        report = groups[cases[-1]["case"], variant]["quota0beforebacking"][0]
        require(report["cap"] == 0 and report["error_name"] == "WorkingMemoryLimitExceeded" and
                report["requested_heap"]["alloc_attempts"] == 0, "Quota0 does not precede backing allocation")
    require(summary["counts"] == {"cases": 14, "processes": 170, "successful_default_plain": 28,
            "successful_observed_unlimited": 28, "successful_exactpeak": 28, "quota_peakminus1": 28,
            "injected_backing_oom": 56, "quota0_precedes_backing": 2, "zero_live_and_balanced": 170}, "Resource counts differ")
    require(load(data, "build/allocator-tests.command.json")["exit_code"] == 0 and b"All 2 tests passed." in data["build/allocator-tests.stderr"],
            "Recorded allocator two-test result differs")
    return {"original_artifacts_hashed": 828, "core_process_ledgers_verified": 170, "allocator_tests_recorded": 2,
            "counts": summary["counts"], "cases": summary["cases"],
            "scope": "Core saved default/observed/exactpeak/quota/backing-OOM/wire/ownership ledgers replayed. Requested heap includes supplied-allocator moving growth; excludes input/dictionary I/O, bookkeeping, stack and native RSS. No new stage instrumentation or allocation-event replay."}
