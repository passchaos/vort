#!/usr/bin/env python3
"""Verify final histogram evidence without executing any recorded command.

Exit 0 writes a stable JSON summary; invalid/missing evidence or an exact
expected-summary mismatch exits 1. Duplicate metrics refer to each record's
earliest byte-identical prior within its row, never to all pair combinations.
Timing sums are observer-perturbed diagnostic observations, not throughput.
"""

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import sys


DOMAIN = b"vort.brotli.context-histogram.snapshot\x00v1\x00"
CANONICAL_BYTES = 263176
HEX64 = re.compile(r"[0-9a-f]{64}\Z")
STAGES = ("analysis_ns", "baseline_ns", "suffix_ns", "sparse_ns", "cluster_ns",
          "tree_score_calls", "cluster_trials", "assignment_comparisons")
REPEATED_STAGES = ("baseline_ns", "suffix_ns", "sparse_ns", "cluster_ns")
STAT_KEYS = ("captures", "truncated", "null_analysis", "exact_histograms",
             "hash_collisions", "proposal_matches", "proposal_mismatches",
             "proposal_unavailable", "failures")
SOURCE_KEYS = ("src/br.zig", "src/br/encoder/literal_context_split.zig",
               "src/br/encoder/literal_context_profile.zig",
               "src/br/encoder/context_histogram_snapshot.zig",
               "src/br/encoder/context_histogram_snapshot_tests.zig",
               "tools/br/quality_stage_profile.zig")


class InvalidEvidence(Exception):
    pass


def require(condition, message):
    if not condition:
        raise InvalidEvidence(message)


def integer(value, label, maximum=None):
    require(type(value) is int and value >= 0, f"{label}: expected nonnegative integer")
    require(maximum is None or value <= maximum, f"{label}: out of range")
    return value


def digest(value, label):
    require(isinstance(value, str) and HEX64.fullmatch(value), f"{label}: expected lowercase 64-hex SHA256")
    return value


def canonical_json(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True, allow_nan=False)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, f"duplicate JSON key: {key}")
        result[key] = value
    return result


def read_json(path):
    def reject_constant(value):
        raise InvalidEvidence(f"nonfinite JSON value: {value}")
    return json.loads(path.read_text(), object_pairs_hook=unique_object,
                      parse_constant=reject_constant)


def identity(data, label):
    require(isinstance(data, dict) and set(data) == {"bytes", "sha256"}, f"{label}: invalid identity")
    integer(data["bytes"], label + ".bytes")
    digest(data["sha256"], label + ".sha256")


def verify_file(path, expected, label):
    content = path.read_bytes()
    require(len(content) == expected["bytes"], f"{label}: byte length mismatch")
    require(hashlib.sha256(content).hexdigest() == expected["sha256"], f"{label}: SHA256 mismatch")


def verify_sources(root):
    require((root / "source").is_dir(), "complete frozen source directory is required")
    before = read_json(root / "source-identity-before.json")
    after = read_json(root / "source-identity-after.json")
    require(isinstance(before, dict) and before, "source identity manifest must be a nonempty map")
    require(canonical_json(before) == canonical_json(after), "complete source identity manifests differ")
    require(set(SOURCE_KEYS) <= set(before), "source identity manifest lacks diagnostic sources")
    for name, item in before.items():
        path = Path(name)
        require(not path.is_absolute() and ".." not in path.parts, "source identity key must be relative")
        identity(item, "source " + name)
        verify_file(root / "source" / path, item, "source " + name)
    return {
        "files": len(before),
        "manifest_sha256": hashlib.sha256(canonical_json(before).encode()).hexdigest(),
        "before_after_equal": True,
    }


def verify_command(path, label):
    command = read_json(path)
    require(command.get("exit_code") == 0 and type(command["exit_code"]) is int, f"{label}: no completed exit 0")
    argv = command.get("argv")
    require(isinstance(argv, list) and argv and all(isinstance(arg, str) for arg in argv), f"{label}: invalid argv metadata")
    for field in ("started_unix", "ended_unix"):
        value = command.get(field)
        require(type(value) in (int, float) and math.isfinite(value), f"{label}: missing completed timestamp")
    require(command["ended_unix"] >= command["started_unix"], f"{label}: reversed completion timestamps")
    return argv


def argument_values(argv, flag):
    values = []
    for index, arg in enumerate(argv):
        if arg == flag:
            require(index + 1 < len(argv), "command metadata: incomplete " + flag)
            values.append(argv[index + 1])
    return values


def verify_tests(root):
    text = (root / "snapshot-tests.stderr").read_text()
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    require(lines and lines[-1] == "All 12 tests passed.", "snapshot tests: final 12/12 success missing")
    statuses = [re.fullmatch(r"(\d+)/12 .+\.\.\.OK", line) for line in lines[:-1]]
    require(len(statuses) == 12 and all(statuses), "snapshot tests: expected exactly twelve successful statuses")
    require([int(match.group(1)) for match in statuses] == list(range(1, 13)), "snapshot tests: ordinal sequence mismatch")


def proposal_set(value, label):
    require(isinstance(value, dict) and set(value) == {"suffix", "up_to_16", "full"}, f"{label}: incomplete proposals")
    result = {}
    for slot, proposal in value.items():
        if proposal is None:
            result[slot] = None
            continue
        require(isinstance(proposal, dict) and set(proposal) == {"mode", "tree_count", "context_map", "savings_bits"}, f"{label}.{slot}: incomplete semantic fields")
        mode = integer(proposal["mode"], label + ".mode", 3)
        trees = integer(proposal["tree_count"], label + ".tree_count", 64)
        require(trees >= 2 and (slot != "suffix" or trees == 2) and (slot != "up_to_16" or trees <= 16), f"{label}.{slot}: invalid tree count")
        savings = integer(proposal["savings_bits"], label + ".savings_bits", (1 << 64) - 1)
        raw_map = proposal["context_map"]
        if isinstance(raw_map, str):
            map_values = [ord(char) for char in raw_map]
        else:
            require(isinstance(raw_map, list), f"{label}.{slot}: invalid context map")
            map_values = raw_map
        require(len(map_values) == 64 and all(type(v) is int and 0 <= v < trees for v in map_values), f"{label}.{slot}: invalid map entries")
        result[slot] = {"mode": mode, "tree_count": trees, "context_map": map_values, "savings_bits": savings}
    return result


def verify_canonical(content, record, label):
    require(len(content) == CANONICAL_BYTES, f"{label}: canonical length mismatch")
    actual_digest = hashlib.sha256(DOMAIN + content).hexdigest()
    require(actual_digest == digest(record["canonical_domain_sha256"], label + ".canonical SHA256"), f"{label}: canonical domain SHA256 mismatch")
    count = integer(record["literal_count"], label + ".literal_count", (1 << 64) - 1)
    require(struct.unpack_from("<Q", content)[0] == count, f"{label}: literal_count LE mismatch")
    total = struct.unpack_from("<256I", content, 8)
    require(sum(total) == count, f"{label}: total histogram does not sum to literal_count")
    for mode in range(4):
        values = struct.unpack_from("<16384I", content, 8 + 1024 + mode * 65536)
        require(all(sum(values[symbol::256]) == total[symbol] for symbol in range(256)), f"{label}: mode histogram differs from total")
    return actual_digest


def verify_round(root, row, round_, row_index, used_bins):
    name = Path(row["path"]).name
    label = "row " + name
    integer(round_["index"], label + ".round index")
    integer(round_["normal_ns"], label + ".normal_ns")
    integer(round_["profile_call_ns"], label + ".profile_call_ns")
    require(round_["index"] == 0 and round_["wire_equal"] is True, label + ": invalid round or unequal wire")
    require(round_["normal_first"] is True, label + ": round-zero pass ordering differs")
    profile = round_["profile"]
    require(profile["events_truncated"] is False, label + ": context events truncated")
    for flag in ("wire_attempt_coverage_complete", "timing_complete"):
        require(profile[flag] is True, f"{label}: incomplete {flag}")
    require(profile["error_name"] in (None, ""), label + ": codec error")
    require(profile["returned_wire_bytes"] == row["wire_bytes"], label + ": returned wire byte mismatch")
    events = profile["events"]
    integer(profile["event_count"], label + ".event_count")
    integer(profile["events_total"], label + ".events_total")
    require(profile["event_count"] == profile["events_total"] == len(events), label + ": incomplete events")
    for ordinal, event in enumerate(events):
        for field in ("id", "input_bytes", "command_count"):
            integer(event[field], label + ".event." + field)
        require(type(event["variant"]) is bool and event["origin"] in ("other", "lazy", "optimal"), label + ": event origin/variant schema mismatch")
        require(event["id"] == ordinal, label + ": event IDs are not a complete prefix")
        require(event["error_name"] in (None, ""), label + ": event error")
    context_events = [event for event in events if event["stage"] == "context_proposals"]
    details = profile["context_details"]
    require(len(details) == min(8, len(context_events)), label + ": invalid existing context-detail capacity prefix")
    require(profile["context_details_truncated"] is (len(details) < len(context_events)), label + ": inconsistent context-detail truncation flag")
    require([detail["event_id"] for detail in details] == [event["id"] for event in context_events[:len(details)]], label + ": context details are not the actual event prefix")
    detail_by_id = {detail["event_id"]: detail for detail in details}
    require(len(detail_by_id) == len(details), label + ": duplicate context detail event IDs")
    histograms = round_["histograms"]
    require(histograms["capacity"] == 16 and histograms["canonical_bytes_per_slot"] == CANONICAL_BYTES, label + ": fixed snapshot geometry mismatch")
    require(histograms["event_order_matched"] is True and histograms["codec_requests_skipped"] == 0, label + ": snapshot policy mismatch")
    heap = integer(histograms["diagnostic_heap_bytes"], label + ".diagnostic_heap_bytes")
    require(heap > 16 * CANONICAL_BYTES and (heap - 16 * CANONICAL_BYTES) % 16 == 0, label + ": invalid fixed diagnostic heap geometry")
    records = histograms["records"]
    require(0 < len(records) <= 16 and len(records) == len(context_events), label + ": missing or truncated records")
    expected_stats = dict.fromkeys(STAT_KEYS, 0)
    expected_stats["captures"] = len(records)
    summary = {
        "name": name, "input_bytes": row["input_bytes"], "input_sha256": row["input_sha256"],
        "wire_bytes": row["wire_bytes"], "wire_sha256": row["wire_sha256"],
        "captures": len(records), "exact_histograms": 0,
        "different_command_digest_duplicates": 0, "same_command_digest_duplicates": 0,
        "duplicate_tree_score_calls": 0, "duplicate_stage_ns": dict.fromkeys(REPEATED_STAGES, 0),
        "duplicate_scorer_diagnostic_ns": 0, "diagnostic_heap_bytes": heap,
        "context_detail_records_verified": len(details),
        "context_detail_records_unavailable": len(records) - len(details),
    }
    previous = []
    for ordinal, (record, event) in enumerate(zip(records, context_events)):
        current_label = f"{label} record {ordinal}"
        for field, expected in (("ordinal", ordinal), ("context_event_id", event["id"]),
                                ("input_bytes", event["input_bytes"]), ("command_count", event["command_count"]),
                                ("origin", event["origin"]), ("variant", event["variant"])):
            require(record[field] == expected and type(record[field]) is type(expected), f"{current_label}: {field} mismatch")
        require(record["input_bytes"] == row["input_bytes"] and record["prune"] is True, current_label + ": input/prune policy mismatch")
        require(record["failure"] is None, current_label + ": capture failure")
        command_digest = digest(record["command_semantic_sha256"], current_label + ".command_semantic_sha256")
        filename = f"case-{row_index}-round-0-record-{ordinal}.bin"
        require(record["canonical_file"] == filename and filename not in used_bins, current_label + ": canonical file mapping mismatch")
        used_bins.add(filename)
        content = (root / "profile" / "snapshots" / filename).read_bytes()
        canonical_digest = verify_canonical(content, record, current_label)
        proposals = proposal_set(record["proposals"], current_label)
        stages = record["stages"]
        require(isinstance(stages, dict) and set(stages) == set(STAGES), current_label + ": missing stages")
        detail = detail_by_id.get(event["id"])
        for field in STAGES:
            integer(stages[field], current_label + ".stages." + field)
        if detail is not None:
            for field in ("origin", "variant", "command_count"):
                require(detail[field] == record[field], current_label + ": detail identity mismatch")
            detail_profile = detail["profile"]
            require(detail_profile["iterations"] == 1 and detail_profile["input_bytes"] == record["input_bytes"] and detail_profile["literal_count"] == record["literal_count"], current_label + ": detail analysis shape mismatch")
            for field in STAGES:
                integer(detail_profile[field], current_label + ".detail." + field)
                require(stages[field] == detail_profile[field], current_label + ": stage/detail mismatch: " + field)
            for slot, proposal in proposals.items():
                require(detail_profile[slot + "_tree_count"] == (0 if proposal is None else proposal["tree_count"]), current_label + ": proposal/detail tree count mismatch")
                require(detail_profile[slot + "_savings_bits"] == (0 if proposal is None else proposal["savings_bits"]), current_label + ": proposal/detail savings mismatch")
                if proposal is not None:
                    require(detail_profile[slot + "_mode"] == proposal["mode"], current_label + ": proposal/detail mode mismatch")
        prior = next((index for index, value in enumerate(previous) if value["content"] == content), None)
        require(record["exact_prior"] == prior and (prior is None or type(record["exact_prior"]) is int), current_label + ": exact_prior is not earliest full-byte equal record")
        collisions = sum(value["digest"] == canonical_digest and value["content"] != content for value in previous)
        require(integer(record["hash_collisions"], current_label + ".hash_collisions") == collisions, current_label + ": collision count mismatch")
        expected_stats["hash_collisions"] += collisions
        require(record["comparison"] == ("none" if prior is None else "match"), current_label + ": incomplete or mismatched proposal comparison")
        if prior is not None:
            require(proposals == previous[prior]["proposals"], current_label + ": equal histograms produced different complete proposals")
            expected_stats["exact_histograms"] += 1
            expected_stats["proposal_matches"] += 1
            summary["exact_histograms"] += 1
            same = command_digest == previous[prior]["command_digest"]
            summary["same_command_digest_duplicates" if same else "different_command_digest_duplicates"] += 1
            summary["duplicate_tree_score_calls"] += stages["tree_score_calls"]
            for stage in REPEATED_STAGES:
                summary["duplicate_stage_ns"][stage] += stages[stage]
                summary["duplicate_scorer_diagnostic_ns"] += stages[stage]
        previous.append({"content": content, "digest": canonical_digest, "command_digest": command_digest, "proposals": proposals})
    recorded_stats = histograms["stats"]
    require(isinstance(recorded_stats, dict) and set(recorded_stats) == set(STAT_KEYS), label + ": incomplete Stats")
    for field in STAT_KEYS:
        require(integer(recorded_stats[field], label + ".stats." + field) == expected_stats[field], label + ": recomputed Stats mismatch: " + field)
    return summary


def verify(root):
    sources = verify_sources(root)
    verify_tests(root)
    run_argv = verify_command(root / "profile" / "run.command.json", "profile run")
    verify_command(root / "build" / "profile.command.json", "profile build")
    require(argument_values(run_argv, "--rounds") == ["1"], "run metadata: expected one round")
    require(len(argument_values(run_argv, "--json")) == 1 and Path(argument_values(run_argv, "--json")[0]).name == "histograms.json", "run metadata: profile JSON output mismatch")
    require(len(argument_values(run_argv, "--snapshot-dir")) == 1 and Path(argument_values(run_argv, "--snapshot-dir")[0]).name == "snapshots", "run metadata: snapshot directory mismatch")
    fixtures = read_json(root / "fixture-identity.json")
    require(isinstance(fixtures, list) and len(fixtures) == 12, "expected twelve fixture identities")
    by_path = {}
    names = set()
    for fixture in fixtures:
        name = fixture["name"]
        require(isinstance(name, str) and name == Path(name).name and name not in names, "fixture names must be unique portable basenames")
        names.add(name)
        require(Path(fixture["path"]).name == name and fixture["path"] not in by_path, "fixture path identity mismatch")
        expected = {"bytes": fixture["bytes"], "sha256": fixture["sha256"]}
        identity(expected, "fixture " + name)
        path = root / "fixtures" / name
        verify_file(path, expected, "fixture " + name)
        by_path[fixture["path"]] = fixture
    document = read_json(root / "profile" / "histograms.json")
    require(document["schema"] == "vort.brotli.q8-context-histograms.v1", "final profile schema mismatch")
    integer(document["quality"], "profile quality")
    integer(document["window_bits"], "profile window_bits")
    require(document["quality"] == 8 and document["mode"] == "generic" and document["window_bits"] == 16 and document["diagnostic_only"] is True, "expected diagnostic q8/generic/window16")
    policy = document["snapshot_policy"]
    expected_policy = {"canonical_version": 1, "source_epoch": "7bb7ee116c93be1850133be8727bbce9856519ad", "chooser": "complete-chooseProposalsCore", "prune": True, "mode_order": [0, 1, 2, 3], "include_clusters": True, "max_tree_count": 64, "cost_policy": "frozen-source-savings-and-suffix-map-v1", "hash_is_prefilter": True, "exact_bytes_required": True}
    for key, value in expected_policy.items():
        require(canonical_json(policy[key]) == canonical_json(value), "snapshot policy mismatch: " + key)
    rows = document["rows"]
    require(isinstance(rows, list) and len(rows) == 12, "expected twelve profile rows")
    require([row["path"] for row in rows] == argument_values(run_argv, "--path"), "run metadata: input row order mismatch")
    require(set(row["path"] for row in rows) == set(by_path), "profile rows do not cover fixture identities exactly")
    summaries = []
    used_bins = set()
    for index, row in enumerate(rows):
        fixture = by_path[row["path"]]
        integer(row["input_bytes"], "row input_bytes")
        require(row["input_bytes"] == fixture["bytes"] and row["input_sha256"] == fixture["sha256"], "row fixture content identity mismatch: " + fixture["name"])
        require(row["roundtrip_verified"] is True, "row roundtrip missing: " + fixture["name"])
        integer(row["wire_bytes"], "row wire_bytes")
        digest(row["wire_sha256"], "row wire_sha256")
        require(len(row["rounds"]) == 1, "expected one round: " + fixture["name"])
        summaries.append(verify_round(root, row, row["rounds"][0], index, used_bins))
    actual_bins = {path.name for path in (root / "profile" / "snapshots").glob("*.bin")}
    require(actual_bins == used_bins, "snapshot files contain missing or unreferenced canonical records")
    require(len({row["diagnostic_heap_bytes"] for row in summaries}) == 1, "fixed diagnostic heap differs across rows")
    counters = ("captures", "exact_histograms", "different_command_digest_duplicates", "same_command_digest_duplicates", "duplicate_tree_score_calls", "duplicate_scorer_diagnostic_ns", "context_detail_records_verified", "context_detail_records_unavailable")
    totals = {key: sum(row[key] for row in summaries) for key in counters}
    totals["duplicate_stage_ns"] = {key: sum(row["duplicate_stage_ns"][key] for row in summaries) for key in REPEATED_STAGES}
    return {
        "schema": "vort.brotli.q8-context-histograms-verification.v1", "verified": True,
        "source_identity": sources, "snapshot_tests_passed": 12,
        "profile_build_exit_code": 0, "profile_run_exit_code": 0,
        "quality": 8, "mode": "generic", "window_bits": 16, "row_count": 12,
        "rounds_per_row": 1, "canonical_bytes": CANONICAL_BYTES,
        "duplicate_scope": "earliest byte-identical prior within each row",
        "command_identity_scope": "Different semantic digests prove different command fields; equal digests do not prove exact command-list equality. Original command bytes are not retained for independent digest reconstruction.",
        "timing_scope": "Duplicate baseline/suffix/sparse/cluster nanoseconds are observer-perturbed diagnostic observations, not throughput or a speedup estimate.",
        "heap_scope": "diagnostic_heap_bytes is fixed collector requested storage; codec requested heap and RSS were not independently measured by this verifier.",
        "source_scope": "Complete pre/post source manifests must match; original source contents are rehashed when root/source is present.",
        "context_detail_scope": "All context events and snapshot records are checked. The existing context_details capacity is eight; only its actual event prefix can independently cross-check snapshot stages.",
        "rows": sorted(summaries, key=lambda row: row["name"]), "totals": totals,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, type=Path, help="Final evidence directory")
    parser.add_argument("--expected-summary", type=Path, help="Require exact normalized JSON equality")
    args = parser.parse_args()
    try:
        summary = verify(args.root)
        if args.expected_summary is not None:
            require(canonical_json(summary) == canonical_json(read_json(args.expected_summary)), "expected summary differs")
        print(json.dumps(summary, indent=2, sort_keys=True, ensure_ascii=True, allow_nan=False))
    except (InvalidEvidence, OSError, ValueError, KeyError, TypeError, IndexError, struct.error) as error:
        print("verification failed: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
