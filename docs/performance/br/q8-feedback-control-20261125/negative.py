#!/usr/bin/env python3
"""Reduce retained negative diagnostics; never execute their profiled ELF."""
import gzip
import hashlib
import json
import re

RAW_FIELDS = (
    "input", "index_bytes", "positions", "nodes", "match_calls",
    "valid_matches", "length_choices", "prefix_rejections",
    "bound_rejections", "budget_stops",
)
PASSES = ("fixed_seed", "modeled_seed", "modeled_second", "repcode_bonus")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def stderr_events(data, prefix, numeric=False):
    result = []
    for line in data.decode().splitlines():
        if not line.startswith(prefix + " "):
            continue
        event = dict(token.split("=", 1) for token in line.split()[1:])
        if numeric:
            event = {key: value if key == "pass" else int(value) for key, value in event.items()}
        result.append(event)
    return result


def derive(control, diagnostic):
    ctl = json.loads(control["summary.json"])
    equality = json.loads(diagnostic["equality-diagnostic/summary.json"])
    search = json.loads(diagnostic["search-profile/summary.json"])
    eq_by_case = {row["case"]: row for row in equality["rows"]}
    search_by_case = {row["case"]: row for row in search["rows"]}
    expected_cases = {row["case"] for row in ctl["rows"]}
    require(len(eq_by_case) == len(search_by_case) == 12 and eq_by_case.keys() == search_by_case.keys() == expected_cases, "Negative corpus coverage differs")
    equality_elf = gzip.decompress(diagnostic["probes/diagnostic-probe.elf.gz"])
    search_elf = gzip.decompress(diagnostic["probes/search-diagnostic-probe.elf.gz"])
    frozen_search = gzip.decompress(diagnostic["search-profile/source.zig.gz"])
    source_receipt = json.loads(diagnostic["search-profile/source-sha256.json"])
    require(sha(frozen_search) == source_receipt["source_sha256"] and sha(search_elf) == source_receipt["probe_sha256"], "Frozen search source/ELF binding differs")
    require(b"global_single_threaded.io()" in frozen_search and b"optimalPlanAllocWithCostModelProfiled" in frozen_search, "Search overlay scope differs")
    frozen_equality = gzip.decompress(diagnostic["equality-diagnostic/br-equality-source.zig.gz"])
    require(b"std.meta.eql(left, right)" in frozen_equality and b"std.mem.eql(u16, &a.literal" in frozen_equality, "Exact comparison source missing")
    context_source = diagnostic["constraints/quality_profile.zig"]
    require(b"pub const context_detail_capacity = 8" in context_source
            and b"context_details_truncated" in context_source and b"events_truncated" in context_source,
            "Independent auxiliary context coverage constraint missing")
    context_scope = json.loads(diagnostic["constraints/context-detail-scope.json"])
    rows = []
    for case in sorted(expected_cases):
        baseline = next(row for row in ctl["rows"] if row["case"] == case)
        e = stderr_events(diagnostic["equality-diagnostic/" + case + ".stderr"], "FEEDBACK_EVIDENCE")
        p = stderr_events(diagnostic["search-profile/" + case + ".stderr"], "SEARCH_PROFILE", True)
        require(len(e) >= 4 and len(e) == 5 and e == eq_by_case[case]["events"], "Equality stderr/summary coverage differs")
        require(len(p) >= 4 and tuple(event["pass"] for event in p) == PASSES and p == search_by_case[case]["events"], "Search stderr/summary pass coverage differs")
        command_checks = [value for event in e for key, value in event.items() if key.startswith("commands_equal_")]
        price_checks = [value for event in e for key, value in event.items() if key.startswith("model_equal_")]
        fingerprint_checks = [value for event in e for key, value in event.items() if key.startswith("fingerprint_matches_")]
        require(len(command_checks) == 5 and len(price_checks) == 3 and len(fingerprint_checks) == 1, "Equality check set incomplete")
        require(all(value == "false" for value in command_checks + price_checks + fingerprint_checks), "Unexpected exact/routing reuse hit")
        # The second/bonus comparison has different fingerprints, which reject
        # reuse. A matching fingerprint alone would still require exact equality.
        fingerprints = [event["fingerprint"] for event in e if "fingerprint" in event]
        require(len(fingerprints) == 3 and len(set(fingerprints)) == 3, "Fingerprint rejection differs")
        for folder, elf in (("equality-diagnostic", equality_elf), ("search-profile", search_elf)):
            process = json.loads(diagnostic[folder + "/" + case + ".json"])
            wire = diagnostic[folder + "/" + case + ".br"]
            baseline_wire = control["preflight/explicit16-" + case + "-feedback_on.br"]
            require(wire == baseline_wire and sha(wire) == process["warm_wire_sha256"] == baseline["on_wire_sha256"], "Diagnostic/current complete wire differs")
            require(len(wire) == process["warm_wire_bytes"] == baseline["on_encoded_bytes"], "Diagnostic wire size differs")
            require(process["input_sha256"] == baseline["input_sha256"] and process["input_bytes"] == 65536, "Diagnostic input differs")
            require(process["provenance"]["executable_sha256"] == sha(elf), "Diagnostic ELF hash differs")
            require(process["source_revision"].startswith("e41aa51c+untimed-") and process["iterations"] == 0 and process["samples"] == [], "Diagnostic incorrectly classified as ordinary timing")
            require(process["quality"] == 8 and process["mode"] == "generic" and process["requested_window_bits"] == 16, "Diagnostic options differ")
        modeled = p[1:]
        require(all(tuple(event[key] for key in RAW_FIELDS) == tuple(modeled[0][key] for key in RAW_FIELDS) for event in modeled), "Three modeled raw counter vectors differ")
        for event in p:
            require(all(isinstance(event[key], int) and event[key] >= 0 for key in event if key != "pass"), "Invalid profile counter")
            require(event["index_ns"] + event["search_ns"] + event["reconstruct_ns"] <= event["total_ns"], "Profile timer accounting differs")
        modeled_index = sum(event["index_ns"] for event in modeled)
        modeled_total = sum(event["total_ns"] for event in modeled)
        all_index = sum(event["index_ns"] for event in p)
        all_total = sum(event["total_ns"] for event in p)
        rows.append({
            "case": case, "wire_sha256": baseline["on_wire_sha256"],
            "input_sha256": baseline["input_sha256"], "wire_bytes": baseline["on_encoded_bytes"],
            "equality_records": len(e), "search_passes": len(p),
            "exact_command_checks": len(command_checks), "exact_command_hits": 0,
            "exact_price_checks": len(price_checks), "exact_price_hits": 0,
            "fingerprint_routing_checks": len(fingerprint_checks), "fingerprint_routing_matches": 0,
            "modeled_raw_vectors_equal": True, "modeled_raw_vector": {key: modeled[0][key] for key in RAW_FIELDS},
            "modeled_match_calls_sum": sum(event["match_calls"] for event in modeled),
            "modeled_index_ns_sum": modeled_index, "modeled_total_ns_sum": modeled_total,
            "modeled_index_share": modeled_index / modeled_total,
            "all_four_index_ns_sum": all_index, "all_four_total_ns_sum": all_total,
            "all_four_index_share": all_index / all_total,
        })
    nci = next(row for row in rows if row["case"] == "nci")
    require(nci["modeled_match_calls_sum"] == 9754161, "NCI three-pass match count differs")
    helper = json.loads(diagnostic["equality-diagnostic/helper-validation.json"])
    require(helper["exit_code"] == 0 and helper["passed_tests"] == 12 and helper["named_behaviors"] == 7, "Original helper test receipt differs")
    for path, expected in helper["source_sha256"].items():
        require(sha(diagnostic["helper/" + path]) == expected, "Helper source identity differs")
    named = re.findall(rb'^test "', diagnostic["helper/src/br/encoder/feedback_reuse_tests.zig"], re.M)
    require(len(named) == 7, "Helper named behavior count differs")
    index_sum = sum(row["all_four_index_ns_sum"] for row in rows)
    total_sum = sum(row["all_four_total_ns_sum"] for row in rows)
    return {
        "schema": "vort.q8-feedback-negative.summary.v1", "rows": rows,
        "exact_price_checks": sum(row["exact_price_checks"] for row in rows), "exact_price_hits": 0,
        "exact_command_checks": sum(row["exact_command_checks"] for row in rows), "exact_command_hits": 0,
        "fingerprint_routing_checks": 12, "fingerprint_routing_matches": 0,
        "modeled_match_calls_all_rows": sum(row["modeled_match_calls_sum"] for row in rows),
        "nci_modeled_three_passes": {key: nci[key] for key in ("modeled_match_calls_sum", "modeled_index_ns_sum", "modeled_total_ns_sum", "modeled_index_share")},
        "all_rows_four_pass_index_ns": index_sum, "all_rows_four_pass_total_ns": total_sum,
        "all_rows_four_pass_index_share": index_sum / total_sum,
        "helper_tests": {"passed": 12, "named_behaviors": 7, "scope": helper["scope"]},
        "auxiliary_context_scope": context_scope,
        "equality_source_sha256": sha(frozen_equality), "search_source_sha256": sha(frozen_search),
        "source_snapshot_scope": "Saved diagnostic source snapshots; search snapshot saved after diagnostics and before br reset. No claim of a fresh or byte-reproducible compiler-input reconstruction.",
        "interpretation": "No exact price/command reuse opportunity in these rows. Different fingerprints reject a candidate; a matching fingerprint is not equality. Identical aggregate modeled work counters do not prove equal models, commands or every candidate coordinate. Profile timers are diagnostic, not ordinary encoder measurements; global IO remains tmp-only.",
    }
