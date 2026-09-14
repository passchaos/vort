#!/usr/bin/env python3
import csv, sys

COLUMNS = ["plan", "wire_bytes", "tokens", "literals", "matches", "matched_bytes", "fixed_bits", "commands", "recent", "last", "explicit", "insert_codes", "copy_codes", "recent_symbols", "top_distances", "top_distance_counts"]

def hist(row, key, length):
    values = [int(value) for value in row[key].split(";")]
    assert len(values) == length and all(value >= 0 for value in values), (key, row)
    return values

def main():
    rows = list(csv.DictReader(sys.stdin))
    assert rows and list(rows[0]) == COLUMNS, rows
    by = {row["plan"]: row for row in rows}
    assert set(by) == {"lazy", "optimal", "record"} and len(rows) == 3, rows
    for row in rows:
        ints = {key: int(row[key]) for key in COLUMNS[1:11]}
        assert all(value > 0 for value in ints.values()), row
        assert ints["tokens"] == ints["literals"] + ints["matches"], row
        assert ints["literals"] + ints["matched_bytes"] == 32 * 1024, row
        assert ints["commands"] == sum(hist(row, "insert_codes", 24)), row
        assert ints["commands"] == sum(hist(row, "copy_codes", 24)), row
        assert ints["recent"] == sum(hist(row, "recent_symbols", 16)), row
        assert ints["recent"] + ints["explicit"] == ints["matches"], row
        assert ints["last"] == hist(row, "recent_symbols", 16)[0], row
        distances = hist(row, "top_distances", 8)
        counts = hist(row, "top_distance_counts", 8)
        assert all(distance > 0 for distance in distances), row
        assert len(set(distances)) == len(distances), row
        assert counts == sorted(counts, reverse=True), row
        assert all(count > 0 for count in counts) and sum(counts) <= ints["matches"], row
    lazy, optimal, record = by["lazy"], by["optimal"], by["record"]
    assert int(record["wire_bytes"]) < int(lazy["wire_bytes"]) < int(optimal["wire_bytes"]), rows
    assert int(record["recent"]) > int(optimal["recent"]) > int(lazy["recent"]), rows
    assert int(record["last"]) > int(optimal["last"]) > int(lazy["last"]), rows
    assert all(hist(row, "top_distances", 8)[0] == 128 for row in rows), rows
    assert int(record["top_distance_counts"].split(";")[0]) > int(optimal["top_distance_counts"].split(";")[0]) > int(lazy["top_distance_counts"].split(";")[0]), rows
    print("br_record_optimal_shape_gate=ok rows=3")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
