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
    args = parser.parse_args()
    baseline = json.loads(args.baseline.read_text())
    variant = json.loads(args.variant.read_text())
    differences = []
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
                      "differences": differences}, indent=2))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
