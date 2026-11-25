"""Replay saved diagnostics without encoding or making throughput claims."""
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SOURCES = {"baseline": Path("/tmp/vort-q8-history-ab.wd3sak6_/sources/current"),
           "candidate": Path("/tmp/vort-parameter-context.vqtmlets/source")}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def load(name):
    return json.loads((ROOT / name).read_bytes())


def require(condition, message):
    if not condition:
        raise ValueError(message)


def write(name, value):
    (ROOT / name).write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def without_times(value):
    if isinstance(value, dict):
        return {key: without_times(item) for key, item in value.items() if not key.endswith("_ns")}
    if isinstance(value, list):
        return [without_times(item) for item in value]
    return value


def _replay():
    before, builds = load("identity-before.json"), load("build-results.json")
    rows, profiles = [], {}
    for variant, cpu in (("baseline", "3"), ("candidate", "4")):
        document = load("profile/" + variant + ".json")
        command = load("profile/" + variant + ".command.json")
        require(command["exit_code"] == 0 and document["schema"] == "vort.brotli.q8-candidate-profile.v2" and
                (document["quality"], document["mode"], document["window_bits"]) == (8, "generic", 16), "Profile configuration differs")
        info = document["provenance"]
        expected = {"executable_sha256": builds[variant]["executable_sha256"], "target_arch": "x86_64", "target_os": "linux",
                    "target_abi": "gnu", "target_cpu": "skylake+pku+sgx", "optimize": "ReleaseFast", "cpu_affinity": cpu,
                    "affinity_cpu_count": 1, "benchmark_threads": 1}
        require(all(info[key] == value for key, value in expected.items()), "Profile ELF/target differs")
        require(len(document["rows"]) == 2, "Profile row count differs")
        for row in document["rows"]:
            case = Path(row["path"]).name.removesuffix(".65536.plain")
            data = (ROOT / "fixtures" / (case + ".65536.plain")).read_bytes()
            ordinary = load("ordinary/" + case + "-" + variant + ".json")
            ordinary_command = load("ordinary/" + case + "-" + variant + ".command.json")
            wire = (ROOT / "ordinary" / (case + "-" + variant + ".br")).read_bytes()
            saved_wire = (ROOT / "frozen-receipts" / (case + "-" + variant + "-preflight.br")).read_bytes()
            require(ordinary_command["exit_code"] == 0 and ordinary["iterations"] == 0 and ordinary["samples"] == [] and
                    (ordinary["quality"], ordinary["mode"], ordinary["requested_window_bits"]) == (8, "generic", 16),
                    "Ordinary untimed configuration differs")
            require(ordinary["provenance"]["executable_sha256"] == before["ordinary_elf_sha256"][variant] and
                    ordinary["provenance"]["cpu_affinity"] == cpu, "Ordinary ELF/CPU binding differs")
            require(row["input_sha256"] == ordinary["input_sha256"] == sha(data) and row["input_bytes"] == len(data) == 65536,
                    "Diagnostic input differs")
            require(row["roundtrip_verified"] and wire == saved_wire and row["wire_sha256"] == ordinary["warm_wire_sha256"] == sha(wire)
                    and row["wire_bytes"] == ordinary["warm_wire_bytes"] == len(wire), "Diagnostic complete wire/native decode differs")
            require(len(row["rounds"]) == 1 and row["rounds"][0]["index"] == 0 and row["rounds"][0]["normal_first"] and
                    row["rounds"][0]["wire_equal"], "Profile rounds/wire differs")
            recorded = row["rounds"][0]
            profile = recorded["profile"]
            events, details = profile["events"], profile["context_details"]
            require(profile["event_limit"] == 512 and profile["event_count"] == len(events) and len(details) <= 8 and
                    [event["id"] for event in events] == list(range(len(events))), "Event/detail budget or ID prefix differs")
            require(profile["events_total"] == len(events) and not profile["events_truncated"] and profile["timing_complete"] and
                    profile["wire_attempt_coverage_complete"] and profile["error_name"] == "" and profile["returned_wire_bytes"] == len(wire),
                    "Diagnostic coverage or return differs")
            require(sum(profile["exclusive_ns"].values()) + profile["unaccounted_ns"] == profile["outer_elapsed_ns"],
                    "Profile exclusive timing ledger differs")
            contexts = [event for event in events if event["stage"] == "context_proposals"]
            require(all(event["error_name"] == "" for event in contexts), "Proposal build recorded an error")
            detail_ids = []
            for detail in details:
                event = events[detail["event_id"]]
                require(event["stage"] == "context_proposals" and detail["origin"] == event["origin"] and
                        detail["command_count"] == event["command_count"] and detail["profile"]["iterations"] == 1,
                        "Context detail event binding differs")
                detail_ids.append(detail["event_id"])
            require(detail_ids == [event["id"] for event in contexts[:8]] and
                    profile["context_details_truncated"] == (len(contexts) > 8), "Context detail prefix differs")
            timing_keys = [key for key, value in details[0]["profile"].items() if key.endswith("_ns") and isinstance(value, int)]
            context_stage_sum = sum(event["exclusive_ns"] for event in contexts)
            require(context_stage_sum == profile["exclusive_ns"]["context_proposals"], "Context event/aggregate timing differs")
            signature_counts = Counter((event["origin"], event["variant"], event["input_bytes"], event["command_count"]) for event in contexts)
            rows.append({"case": case, "variant": variant, "cpu_affinity": cpu, "wire_bytes": len(wire), "wire_sha256": sha(wire),
                         "native_roundtrip_verified": True, "ordinary_normal_profile_complete_wire_equal": True,
                         "event_count": len(events), "events_total": profile["events_total"], "events_truncated": False,
                         "context_proposals_actual_recorded_builds": len(contexts), "context_proposal_event_ids": [event["id"] for event in contexts],
                         "context_detail_count": len(details), "context_detail_event_ids": detail_ids,
                         "context_details_truncated": profile["context_details_truncated"],
                         "context_detail_total_scope": "First eight actual proposal builds, or all builds when <=8; not a whole-row total when truncated",
                         "context_proposals_stage_exclusive_ns": context_stage_sum,
                         "context_details_scalar_ns_sums": {key: sum(detail["profile"][key] for detail in details) for key in timing_keys},
                         "stage_event_counts": dict(Counter(event["stage"] for event in events)), "exclusive_stage_ns": profile["exclusive_ns"],
                         "normal_ns_diagnostic_only": recorded["normal_ns"], "profile_call_ns_diagnostic_only": recorded["profile_call_ns"],
                         "parameter_pairs": profile["parameter_pairs"],
                         "context_signature_counts": [{"origin": key[0], "variant": key[1], "input_bytes": key[2], "command_count": key[3], "count": count}
                                                      for key, count in sorted(signature_counts.items())]})
            profiles[variant, case] = profile
    for case in ("mozilla", "nci"):
        require((ROOT / "ordinary" / (case + "-baseline.br")).read_bytes() ==
                (ROOT / "ordinary" / (case + "-candidate.br")).read_bytes(), "Baseline/candidate complete wire differs")
    family = {}
    for variant in ("baseline", "candidate"):
        profile = profiles[variant, "mozilla"]
        events = profile["events"]
        branches = []
        for parent_id, preferred_id, params in ((57, 58, [0, 0]), (79, 80, [2, 2])):
            parent, preferred = events[parent_id], events[preferred_id]
            require(parent["stage"] == "other" and preferred["stage"] == "preferred_context" and
                    preferred["parent_id"] == parent_id and preferred["input_bytes"] == 65536 and preferred["command_count"] == 4316,
                    "Observed Mozilla parameter branch slot changed")
            proposals = [event for event in events if event["parent_id"] == preferred_id and event["stage"] == "context_proposals"]
            wire_events = [event for event in events if event["parent_id"] == preferred_id and event["stage"] in ("wire", "evaluate")]
            require(wire_events and all([event["config"]["npostfix"], event["config"]["ndirect_high"]] == params for event in wire_events),
                    "Observed parameter branch wire/evaluation configuration changed")
            branches.append({"other_event": parent, "preferred_context_event": preferred, "distance_parameters": params,
                             "context_proposal_events": proposals,
                             "context_details": [detail for detail in profile["context_details"] if detail["event_id"] in [event["id"] for event in proposals]],
                             "wire_and_evaluation_events": wire_events})
        family[variant] = {"branches": branches, "observed_proposal_builds": sum(len(branch["context_proposal_events"]) for branch in branches),
                           "observed_analysis_details": sum(len(branch["context_details"]) for branch in branches)}
    require(family["baseline"]["observed_proposal_builds"] == family["baseline"]["observed_analysis_details"] == 2 and
            family["candidate"]["observed_proposal_builds"] == family["candidate"]["observed_analysis_details"] == 1,
            "Observed Mozilla parameter-pair two-to-one analysis detail did not reproduce")
    baseline_details = [branch["context_details"][0]["profile"] for branch in family["baseline"]["branches"]]
    candidate_detail = family["candidate"]["branches"][0]["context_details"][0]["profile"]
    family["non_timing_proposal_detail_values_equal"] = without_times(baseline_details[0]) == without_times(baseline_details[1]) == without_times(candidate_detail)
    family["runtime_cache_hit_counter"] = None
    family["runtime_shared_common_hit_counter"] = None
    family["scope"] = ("Mozilla public trace branches (other57/preferred58 parameters0,0; other79/preferred80 parameters2,2), "
                       "both lazy/nonvariant/input65536/command_count4316. Baseline context slots59/82 each have real analysis detail; "
                       "V6 only slot59. Source-bound call sequence shares one immutable commands slice across the parameter pair. "
                       "Trace has no family ID, commands pointer/content fingerprint, or cache-hit counter. Attribution is limited to "
                       "these observed branch slots and source call sequence, not a general runtime family/shared_common-hit claim.")
    write("family-observation.json", family)
    summary = {"schema": "vort.parameter-context.diagnostic.summary.v1", "rows": rows,
               "public_scope": "Actual q8/generic/window16 public pipeline; ordinary raw wires saved; native decoder roundtrip verified by unchanged profile tool",
               "ordinary_processes": 4, "profile_processes": 2, "profile_rows": 4, "rounds_per_row": 1,
               "formal_benchmark_executed": False, "throughput_gate_result": None, "active_own_heavy_count": 0,
               "timing_scope": "Existing normal_ns and profile_call_ns end on encode return before comparison/free; instrumented profile stages are diagnostics. They are not continuous ordinary public encode/mix/free throughput samples or an acceptance A/B.",
               "observed_mozilla_parameter_branch_analysis_builds": {"baseline": 2, "candidate": 1},
               "runtime_cache_hit_count": None, "runtime_shared_common_hit_confirmed": False,
               "family_proof_boundary": family["scope"],
               "detail_coverage": "Mozilla details first8 only (baseline10/candidate9 builds); NCI all8. Event sequences complete for all four rows; detail totals must retain their prefix scope."}
    write("summary.json", summary)
    return summary
