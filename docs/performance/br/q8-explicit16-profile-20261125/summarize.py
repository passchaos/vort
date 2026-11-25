#!/usr/bin/env python3
"""Reduce retained q8 events; never run an encoder or treat times as speedups."""
from collections import Counter
import hashlib
import json


SPLIT_FLAGS = (
    "literal_split", "command_split", "distance_split",
    "adaptive_literal_split", "adaptive_command_split",
    "adaptive_distance_split", "joint_literal_contexts",
)
PARAMETER_FIELDS = (
    "parameter_pairs", "parameter_counted_candidates",
    "parameter_physical_emits", "parameter_skipped_pair_emits",
)


def completed_wires(events):
    return [e for e in events if e["stage"] == "wire"
            and e["error_name"] == "" and e["wire_bytes"] is not None]


def shape_hash(events):
    shape = [{k: v for k, v in e.items()
              if k not in ("inclusive_ns", "exclusive_ns")} for e in events]
    return hashlib.sha256(json.dumps(shape, sort_keys=True).encode()).hexdigest()


def derive(report):
    cases = []
    for row in report["rows"]:
        runs = []
        for run in row["rounds"]:
            profile = run["profile"]
            events = profile["events"]
            returned = profile["returned_wire_event_id"]
            wires = completed_wires(events)
            lost = [e for e in wires if e["id"] != returned]
            winner = next(e for e in wires if e["id"] == returned)
            origins = {}
            for origin in sorted({e["origin"] for e in events}):
                selected = [e for e in events
                            if e["origin"] == origin and e["stage"] != "outer"]
                materialized = [e for e in wires if e["origin"] == origin]
                discarded = [e for e in lost if e["origin"] == origin]
                origins[origin] = {
                    "physical_wires": len(materialized),
                    "lost_wires": len(discarded),
                    "materialized_wire_bytes": sum(e["wire_bytes"] for e in materialized),
                    "lost_wire_bytes": sum(e["wire_bytes"] for e in discarded),
                    "exclusive_ns": sum(e["exclusive_ns"] for e in selected),
                    "wire_exclusive_ns": sum(e["exclusive_ns"] for e in materialized),
                    "lost_wire_exclusive_ns": sum(e["exclusive_ns"] for e in discarded),
                    "stage_counts": dict(Counter(e["stage"] for e in selected)),
                }
            families = {}
            for flag in SPLIT_FLAGS:
                selected = [e for e in events if e["stage"] in ("wire", "evaluate")
                            and e["config"][flag]]
                families[flag] = {
                    "evaluation_events": sum(e["stage"] == "evaluate" for e in selected),
                    "physical_wire_events": sum(e in wires for e in selected),
                    "lost_wire_events": sum(e in lost for e in selected),
                    "wire_exclusive_ns": sum(e["exclusive_ns"] for e in selected if e["stage"] == "wire"),
                    "evaluate_exclusive_ns": sum(e["exclusive_ns"] for e in selected if e["stage"] == "evaluate"),
                    "events_by_origin_and_stage": dict(Counter(e["origin"] + "/" + e["stage"] for e in selected)),
                }
            runs.append({
                "index": run["index"],
                "normal_ns": run["normal_ns"],
                "profile_call_ns": run["profile_call_ns"],
                "outer_ns": profile["outer_elapsed_ns"],
                "unaccounted_ns": profile["unaccounted_ns"],
                "events": profile["event_count"],
                "event_shape_sha256": shape_hash(events),
                "physical_wires": len(wires),
                "lost_wires": len(lost),
                "evaluations": profile["evaluation_attempts"],
                "materialized_wire_bytes": sum(e["wire_bytes"] for e in wires),
                "lost_wire_bytes": sum(e["wire_bytes"] for e in lost),
                "returned_event_id": returned,
                "returned_origin": winner["origin"],
                "returned_config": winner["config"],
                "wire_events_complete": profile["wire_attempt_coverage_complete"] and not profile["events_truncated"],
                "context_proposal_events": sum(e["stage"] == "context_proposals" for e in events),
                "context_details_retained": len(profile["context_details"]),
                "context_details_truncated": profile["context_details_truncated"],
                "parameter_counts": {k: profile[k] for k in PARAMETER_FIELDS},
                "origins": origins,
                "split_families": families,
                "exclusive_ns": profile["exclusive_ns"],
            })
        outer_sum = sum(r["outer_ns"] for r in runs)
        stages = {}
        for stage in runs[0]["exclusive_ns"]:
            ns = sum(r["exclusive_ns"][stage] for r in runs)
            shares = [r["exclusive_ns"][stage] / r["outer_ns"] for r in runs]
            stages[stage] = {
                "exclusive_ns_sum": ns,
                "exclusive_ns_mean": ns / len(runs),
                "share_of_pooled_outer": ns / outer_sum,
                "share_min": min(shares), "share_max": max(shares),
            }
        origins = {}
        for origin in runs[0]["origins"]:
            values = [r["origins"][origin] for r in runs]
            keys = [k for k in values[0] if k != "stage_counts"]
            origins[origin] = {k: sum(v[k] for v in values) for k in keys}
            origins[origin]["share_of_pooled_outer"] = origins[origin]["exclusive_ns"] / outer_sum
        cases.append({
            "case": row["path"].rsplit("/", 1)[-1].split(".")[0],
            "input_bytes": row["input_bytes"], "input_sha256": row["input_sha256"],
            "wire_bytes": row["wire_bytes"], "wire_sha256": row["wire_sha256"],
            "rounds": len(runs), "events_deterministic_except_timing": len({r["event_shape_sha256"] for r in runs}) == 1,
            "pooled_outer_ns": outer_sum,
            "physical_wires_total": sum(r["physical_wires"] for r in runs),
            "lost_wires_total": sum(r["lost_wires"] for r in runs),
            "materialized_wire_bytes_total": sum(r["materialized_wire_bytes"] for r in runs),
            "lost_wire_bytes_total": sum(r["lost_wire_bytes"] for r in runs),
            "origins_pooled": origins, "stages_pooled": stages, "runs": runs,
        })
    return {
        "schema": "vort.q8-explicit16-profile.analysis.v1",
        "timing_scope": "Three instrumented rounds per row. Stage shares divide summed exclusive nanoseconds by summed traced outer nanoseconds; no throughput or optimization-gain claim.",
        "wire_byte_scope": "Sum of successful complete encoded output lengths, not heap peak or memory traffic. Lost means every successful wire except the final returned event, including earlier selection winners.",
        "split_scope": "Config flags classify wire/evaluate events. Shared split_planning exclusive time has no per-family subdivision; zero fixed-family candidates does not prove zero planner cost.",
        "context_scope": "Context proposal stage timing is in the complete event log. Per-context details may be an independently truncated prefix.",
        "cases": cases,
        "totals": {k: sum(c[k] for c in cases) for k in
                   ("physical_wires_total", "lost_wires_total", "materialized_wire_bytes_total", "lost_wire_bytes_total")},
    }
