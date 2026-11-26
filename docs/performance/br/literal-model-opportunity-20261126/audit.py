#!/usr/bin/env python3
"""Pure-data audit of the sealed q8 profile; no producer or codec execution."""

import argparse
import collections
import hashlib
import json
from pathlib import Path
import tarfile

PROFILE_MEMBER = "profile.json"
PACKAGE_RELATIVE = "docs/performance/br/q8-main-history-20261126/diagnostic.tar.gz"
SHAPE_FIELDS = (
    "literal_split", "adaptive_literal_split", "command_split",
    "adaptive_command_split", "distance_split", "adaptive_distance_split",
)
NON_TEMPORAL_EXCLUSIONS = (
    "literal_split", "adaptive_literal_split", "joint_literal_contexts",
)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def file_sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_profile(package):
    with tarfile.open(package, "r:gz") as archive:
        matches = [member for member in archive.getmembers()
                   if member.name == PROFILE_MEMBER]
        require(len(matches) == 1, "expected exactly one profile.json member")
        member = matches[0]
        require(member.isfile(), "profile.json must be a regular file")
        stream = archive.extractfile(member)
        require(stream is not None, "cannot read profile.json")
        with stream:
            data = stream.read()
        require(len(data) == member.size, "profile.json size mismatch")
    return json.loads(data), len(data), hashlib.sha256(data).hexdigest()


def event_index(events):
    indexed = {event["id"]: event for event in events}
    require(len(indexed) == len(events), "duplicate event IDs")
    for event in events:
        parent = event.get("parent_id")
        require(parent is None or parent in indexed, "event parent is missing")
    return indexed


def ancestor_id(event, indexed, stage):
    parent = event.get("parent_id")
    visited = set()
    while parent is not None:
        require(parent not in visited, "cycle in event parents")
        visited.add(parent)
        current = indexed[parent]
        if current["stage"] == stage:
            return parent
        parent = current.get("parent_id")
    return None


def is_descendant(event, ancestor, indexed):
    parent = event.get("parent_id")
    visited = set()
    while parent is not None:
        if parent == ancestor:
            return True
        require(parent not in visited, "cycle in event parents")
        visited.add(parent)
        parent = indexed[parent].get("parent_id")
    return False


def is_model_build_slot(event):
    # Metadata filter from the original static opportunity queries.
    # An emission linked to an evaluation reuses a prepared literal model.
    return (
        event["stage"] in ("wire", "evaluate")
        and not event.get("error_name")
        and not (event["stage"] == "wire"
                 and event.get("evaluation_event_id") is not None)
    )


def literal_metadata_key(event, include_command_count):
    config = event["config"]
    key = (config["context_mode"], config["context_trees"], config["context_map"])
    if include_command_count:
        return (event["command_count"],) + key
    return key


def nonrecent_category(event):
    config = event["config"]
    shape = tuple(field for field in SHAPE_FIELDS if config[field])
    has_context = bool(config["context_trees"])
    if not shape:
        return "ordinary_context" if has_context else "ordinary_plain"
    if shape == ("adaptive_literal_split",) and not has_context:
        return "adaptive_literal_plain"
    if shape == ("adaptive_distance_split",) and has_context:
        return "adaptive_distance_context"
    return "other:" + ",".join(shape) + (":context" if has_context else ":plain")


def first_round_opportunities(events):
    indexed = event_index(events)
    scope_pairs = collections.defaultdict(dict)
    for event in events:
        if event["stage"] in ("preferred_context", "split_planning"):
            scope_pairs[event["parent_id"]][event["stage"]] = event["id"]
    pairs = []
    matched_total = 0
    eligible_total = 0
    for parent_id, scopes in scope_pairs.items():
        if not {"preferred_context", "split_planning"} <= scopes.keys():
            continue
        preferred_id = scopes["preferred_context"]
        split_id = scopes["split_planning"]
        preferred_keys = {
            literal_metadata_key(event, True) for event in events
            if is_model_build_slot(event)
            and is_descendant(event, preferred_id, indexed)
        }
        eligible_ids = []
        matched_ids = []
        for event in events:
            if not is_model_build_slot(event):
                continue
            if not is_descendant(event, split_id, indexed):
                continue
            config = event["config"]
            if any(config[field] for field in NON_TEMPORAL_EXCLUSIONS):
                continue
            eligible_ids.append(event["id"])
            if literal_metadata_key(event, True) in preferred_keys:
                matched_ids.append(event["id"])
        eligible_total += len(eligible_ids)
        matched_total += len(matched_ids)
        pairs.append({
            "parent_event_id": parent_id,
            "preferred_event_id": preferred_id,
            "split_planning_event_id": split_id,
            "non_temporal_build_slots": len(eligible_ids),
            "matching_opportunity_slots": len(matched_ids),
            "eligible_consumer_event_ids": eligible_ids,
            "matching_consumer_event_ids": matched_ids,
        })
    return matched_total, eligible_total, pairs


def first_round_slot_table(events):
    indexed = event_index(events)
    groups = collections.defaultdict(dict)
    for event in events:
        if not is_model_build_slot(event):
            continue
        preferred_id = ancestor_id(event, indexed, "preferred_context")
        if preferred_id is None:
            continue
        key = literal_metadata_key(event, False)
        groups[preferred_id][key] = max(1, event["config"]["context_trees"])
    scopes = [{
        "preferred_event_id": preferred_id,
        "distinct_literal_metadata_slots": len(models),
        "sum_effective_trees": sum(models.values()),
    } for preferred_id, models in sorted(groups.items())]
    return (
        max((len(models) for models in groups.values()), default=0),
        max((sum(models.values()) for models in groups.values()), default=0),
        scopes,
    )


def audit(report):
    rows = report["rows"]
    nonrecent = collections.Counter()
    physical_wires = 0
    trace_runs = 0
    truncated_runs = 0
    recorded_details = 0
    context_events = 0
    observed_reuses = 0
    opportunity_rows = []
    first_round_total = 0
    first_round_eligible_total = 0
    for row in rows:
        case = Path(row["path"]).name.split(".")[0]
        rounds = row["rounds"]
        require(rounds, "row has no rounds")
        require(rounds[0]["index"] == 0, "first stored round is not round zero")
        for round_record in rounds:
            profile = round_record["profile"]
            events = profile["events"]
            require(not profile["events_truncated"], "event log is truncated")
            require(len(events) == profile["event_count"] == profile["events_total"],
                    "event counts do not establish complete coverage")
            require(profile["wire_attempt_coverage_complete"],
                    "physical wire coverage is incomplete")
            event_index(events)
            trace_runs += 1
            truncated_runs += int(profile["context_details_truncated"])
            details = profile["context_details"]
            recorded_details += len(details)
            observed_reuses += sum(detail["profile"]["proposal_reuses"]
                                  for detail in details)
            context_events += sum(event["stage"] == "context_proposals"
                                  for event in events)
            for event in events:
                if (event["stage"] == "wire"
                        and event.get("wire_bytes") is not None
                        and not event.get("error_name")):
                    physical_wires += 1
                    if not event["config"]["use_recent_distances"]:
                        nonrecent[nonrecent_category(event)] += 1
        events = rounds[0]["profile"]["events"]
        matched, eligible, pairs = first_round_opportunities(events)
        slots, tree_sum, preferred_scopes = first_round_slot_table(events)
        first_round_total += matched
        first_round_eligible_total += eligible
        opportunity_rows.append({
            "case": case,
            "stored_round_position": 0,
            "round_index": rounds[0]["index"],
            "matching_opportunity_slots": matched,
            "non_temporal_build_slots": eligible,
            "max_slots_in_one_preferred_scope": slots,
            "max_tree_sum_in_one_preferred_scope": tree_sum,
            "scope_pairs": pairs,
            "preferred_scope_slot_counts": preferred_scopes,
        })
    return {
        "profile_schema": report.get("schema"),
        "profile_policy": {
            "quality": report.get("quality"), "mode": report.get("mode"),
            "window_bits": report.get("window_bits"),
        },
        "complete_event_scope": {
            "input_rows": len(rows), "trace_runs": trace_runs,
            "all_event_logs_complete": True,
            "successful_physical_wires": physical_wires,
            "nonrecent_successful_physical_wires": sum(nonrecent.values()),
            "nonrecent_categories": dict(sorted(nonrecent.items())),
            "context_proposal_events": context_events,
        },
        "context_detail_scope": {
            "truncated_runs": truncated_runs, "recorded_details": recorded_details,
            "observed_reuses_in_recorded_details": observed_reuses,
            "full_reuses_in_truncated_runs": None,
            "limitation": (
                "Truncated runs retain only context-detail prefixes. Do not infer "
                "their complete reuse or scorer totals. Physical classification "
                "and opportunity joins use complete events, not the truncated "
                "context-detail arrays."
            ),
        },
        "first_round_opportunity_scope": {
            "input_rows": len(opportunity_rows), "stored_round_position": 0,
            "matching_opportunity_slots": first_round_total,
            "non_temporal_build_slots": first_round_eligible_total,
            "max_slots_in_one_preferred_scope": max(
                (row["max_slots_in_one_preferred_scope"] for row in opportunity_rows),
                default=0),
            "max_tree_sum_in_one_preferred_scope": max(
                (row["max_tree_sum_in_one_preferred_scope"] for row in opportunity_rows),
                default=0),
            "match_fields": ["command_count", "context_mode", "context_trees",
                             "complete_serialized_context_map"],
            "rows": opportunity_rows, "identity_verified": False,
            "limitation": (
                "These are metadata-matching opportunity slots, not cache hits "
                "or proof of command/input/histogram identity. Command count "
                "does not establish command-list equality."
            ),
        },
        "execution_scope": {
            "pure_data_reduction": True, "new_measurement": False,
            "producer_imported_or_executed": False, "codec_executed": False,
            "build_or_timing_executed": False,
            "wire_identity_verified_by_this_script": False,
        },
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path,
                        help="sealed diagnostic.tar.gz; overrides default")
    args = parser.parse_args()
    if args.package is None:
        package = (Path(__file__).resolve().parent.parent
                   / "q8-main-history-20261126" / "diagnostic.tar.gz")
        package_argument = PACKAGE_RELATIVE
    else:
        package = args.package
        package_argument = str(args.package)
    try:
        report, profile_bytes, profile_sha = read_profile(package)
        result = audit(report)
        result["schema"] = "vort.brotli.literal-model-opportunity.v1"
        result["input"] = {
            "package_argument": package_argument,
            "package_bytes": package.stat().st_size,
            "package_sha256": file_sha256(package),
            "profile_member": PROFILE_MEMBER, "profile_bytes": profile_bytes,
            "profile_sha256": profile_sha,
        }
        print(json.dumps(result, indent=2, sort_keys=True, ensure_ascii=False,
                         allow_nan=False))
    except (OSError, ValueError, KeyError, TypeError, tarfile.TarError) as exc:
        parser.exit(1, "static profile audit failed: " + str(exc) + "\n")


if __name__ == "__main__":
    main()
