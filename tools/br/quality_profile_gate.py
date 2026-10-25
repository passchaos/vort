#!/usr/bin/env python3
"""Validate native q8 stage timing, wire identity and event relationships."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def integer(value, name: str) -> int:
    require(type(value) is int and value >= 0, f"invalid integer: {name}")
    return value


def validate(report: dict, executable: Path | None = None) -> dict:
    require(report.get("schema") == "vort.brotli.q8-candidate-profile.v1", "wrong schema")
    require(report.get("quality") == 8 and report.get("mode") == "generic", "wrong policy")
    require(report.get("window_bits") == 16, "wrong window")
    if executable is not None:
        require(digest(executable) == report["provenance"]["executable_sha256"], "executable changed")
    summaries = []
    for row in report["rows"]:
        path = Path(row["path"])
        require(path.stat().st_size == row["input_bytes"] and digest(path) == row["input_sha256"], "input changed")
        require(row["input_bytes"] <= 65536 and row["roundtrip_verified"], "invalid input/roundtrip")
        wire_bytes = integer(row["wire_bytes"], "wire bytes")
        require(wire_bytes > 0 and len(row["wire_sha256"]) == 64, "wire identity missing")
        for index, run in enumerate(row["rounds"]):
            require(run["index"] == index and run["normal_first"] == (index % 2 == 0), "round order")
            require(run["wire_equal"], "profile changed wire")
            integer(run["normal_ns"], "normal duration")
            integer(run["profile_call_ns"], "profile call duration")
            profile = run["profile"]
            require(profile["error_name"] == "" and profile["returned_wire_bytes"] == wire_bytes, "failed profile")
            events = profile["events"]
            require(len(events) == profile["event_count"] <= 512, "event count")
            require(profile["events_total"] >= len(events), "attempt count")
            require(profile["timing_complete"], "profile timing incomplete")
            require(not profile["events_truncated"], "event report truncated")
            require(profile["events_total"] == len(events), "missing event")
            exclusive = profile["exclusive_ns"]
            total = sum(integer(n, "exclusive duration") for n in exclusive.values())
            outer = integer(profile["outer_elapsed_ns"], "outer duration")
            require(total <= outer and profile["unaccounted_ns"] == outer - total, "exclusive accounting")
            by_id = {}
            by_stage = {stage: 0 for stage in exclusive}
            children = {}
            wires = []
            outer_events = []
            for event in events:
                identifier = integer(event["id"], "event id")
                require(identifier not in by_id, "duplicate event")
                parent = event["parent_id"]
                if parent is not None:
                    require(parent in by_id, "parent missing or later")
                    require(event["inclusive_ns"] <= by_id[parent]["inclusive_ns"], "child larger than parent")
                    children.setdefault(parent, []).append(event)
                inclusive_ns = integer(event["inclusive_ns"], "event duration")
                exclusive_ns = integer(event["exclusive_ns"], "event exclusive")
                require(exclusive_ns <= inclusive_ns, "event accounting")
                by_id[identifier] = event
                stage = event["stage"]
                if stage == "outer":
                    outer_events.append(event)
                else:
                    require(stage in by_stage, "unknown stage")
                    by_stage[stage] += exclusive_ns
                if stage == "wire":
                    wires.append(event)
                    require(event["config"]["window_bits"] == 16 and not event["config"]["large_window"], "wire format")
                if event["accepted"] is not None:
                    require(stage == "selection" and event["incumbent_bytes"] is not None and event["wire_bytes"] is not None, "invalid selection")
                    accepted = event["wire_bytes"] < event["incumbent_bytes"]
                    require(accepted == event["accepted"], "changed strict selection")
                    require(event["gain_bytes"] == (event["incumbent_bytes"] - event["wire_bytes"] if accepted else 0), "wrong gain")
                    for key, length in [("candidate_event_id", event["wire_bytes"]), ("incumbent_event_id", event["incumbent_bytes"])]:
                        if event[key] is not None:
                            referenced = by_id.get(event[key])
                            require(referenced is not None and referenced["stage"] == "wire" and referenced["wire_bytes"] == length, "wrong wire reference")
            require(len(outer_events) == 1 and outer_events[0]["inclusive_ns"] == outer, "outer event")
            require(by_stage == exclusive, "stage totals differ from events")
            require(len(wires) == profile["wire_attempts"], "wire attempt count")
            for identifier, descendants in children.items():
                # Instant selection records have zero duration. Only direct
                # children's inclusive time is subtracted by the parent.
                duration = sum(child["inclusive_ns"] for child in descendants)
                require(duration <= by_id[identifier]["inclusive_ns"], "overlapping child attribution")
                require(by_id[identifier]["exclusive_ns"] == by_id[identifier]["inclusive_ns"] - duration, "parent subtraction")
            returned = profile["returned_wire_event_id"]
            if returned is not None:
                require(returned in by_id and by_id[returned]["stage"] == "wire" and by_id[returned]["wire_bytes"] == wire_bytes, "returned winner link")
            if row["input_bytes"] > 4096:
                require(profile["wire_attempt_coverage_complete"], "unexpected incomplete large-input wire coverage")
                require(returned is not None, "large-input winner missing")
            summaries.append({"path": str(path), "round": index, "outer_ns": outer, "wire_attempts": len(wires),
                              "exclusive_ns": exclusive, "unaccounted_ns": profile["unaccounted_ns"],
                              "classified_fraction": (total - exclusive["other"]) / outer if outer else None,
                              "wire_coverage_complete": profile["wire_attempt_coverage_complete"]})
    require(bool(summaries), "empty report")
    return {"validated_runs": len(summaries), "rows": summaries,
            "scope": "Exact wire equality/roundtrip asserted by producer; local input and optional executable identity, event topology and non-overlapping timing independently checked. No competitor throughput claim."}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", type=Path, required=True)
    parser.add_argument("--executable", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = validate(json.loads(args.json.read_text()), args.executable)
    text = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.write_text(text)
    else:
        print(text, end="")


if __name__ == "__main__":
    main()
