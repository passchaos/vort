#!/usr/bin/env python3
"""Compare standalone full API evidence without deriving performance claims."""
import argparse
import json
from pathlib import Path


def index(document):
    rows = {}
    for row in document["rows"]:
        for api in row["apis"]:
            key = (row["case"], row["quality"], api["api"])
            if key in rows:
                raise ValueError(f"duplicate row: {key}")
            rows[key] = (row, api)
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("variant", type=Path)
    parser.add_argument("--allow-lower-memory", action="store_true")
    args = parser.parse_args()
    baseline = json.loads(args.baseline.read_text())
    variant = json.loads(args.variant.read_text())
    differences = []
    memory_changes = []
    settings = ("schema", "zig_version", "optimize", "window_bits", "mode", "hq",
                "command_state_max_input_kib", "force_moving_growth",
                "append_api", "raw_dictionary_sha256", "row_count")
    for field in settings:
        if baseline[field] != variant[field]:
            differences.append({"field": field, "baseline": baseline[field], "variant": variant[field]})
    left, right = index(baseline), index(variant)
    for key in sorted(left.keys() | right.keys()):
        if key not in left or key not in right:
            differences.append({"key": key, "field": "missing_api_entry"})
            continue
        old_row, old_api = left[key]
        new_row, new_api = right[key]
        for field in ("input_bytes", "input_sha256", "raw_dictionary_bytes"):
            if old_row[field] != new_row[field]:
                differences.append({"key": key, "field": field})
        for field in ("contract_ok", "observed_equal_to_complete_alloc"):
            if old_api[field] != new_api[field]:
                differences.append({"key": key, "field": field})
        for phase in ("ordinary", "profiled", "exact_cap", "cap_minus_one"):
            old, new = old_api[phase], new_api[phase]
            for field in old.keys() | new.keys():
                if args.allow_lower_memory and field == "independent_backing_peak":
                    before, after = old.get(field), new.get(field)
                    if before != after:
                        memory_changes.append({"key": key, "phase": phase, "field": field, "before": before, "after": after})
                    if before is None or after is None:
                        if before != after:
                            differences.append({"key": key, "phase": phase, "field": field})
                    elif phase != "cap_minus_one" and after > before:
                        differences.append({"key": key, "phase": phase, "field": field, "before": before, "after": after})
                    continue
                if args.allow_lower_memory and field == "profile":
                    before, after = old[field], new[field]
                    for item in ("available", "live_requested_bytes"):
                        if before[item] != after[item]:
                            differences.append({"key": key, "phase": phase, "field": "profile." + item})
                    if before != after:
                        memory_changes.append({"key": key, "phase": phase, "field": field, "before": before, "after": after})
                    if phase != "cap_minus_one" and after["peak_requested_bytes"] > before["peak_requested_bytes"]:
                        differences.append({"key": key, "phase": phase, "field": "profile.peak_requested_bytes"})
                    continue
                if old.get(field) != new.get(field):
                    differences.append({"key": key, "phase": phase, "field": field,
                                        "baseline": old.get(field), "variant": new.get(field)})
    contract_failures = {
        "baseline": baseline["contract_failures"],
        "variant": variant["contract_failures"],
    }
    ok = not differences and not any(contract_failures.values())
    print(json.dumps({"schema": "vort.brotli.full-api-comparison.v1", "ok": ok,
                      "api_entries": len(left), "contract_failures": contract_failures,
                      "memory_changes": memory_changes,
                      "memory_policy": "successful peaks may decrease; each own cap/cap-1 contract enforced" if args.allow_lower_memory else "identical",
                      "differences": differences}, indent=2))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
