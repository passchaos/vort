#!/usr/bin/env python3
"""Validate Vort/libzstd Zstandard encode evidence."""
import argparse
import csv
from pathlib import Path

COLUMNS = ["case", "reference_version", "level", "input_bytes", "vort_bytes", "reference_bytes", "size_over_reference", "iterations", "rounds", "vort_ns", "reference_ns", "vort_mib_s", "reference_mib_s", "vort_over_reference", "checksum"]
CASES = {"text", "json", "binary", "level3_tradeoff", "multiblock"}
LEVELS = {1, 3, 9, 22}

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    args = parser.parse_args()
    with args.csv.open(newline="") as file:
        reader = csv.DictReader(file)
        assert reader.fieldnames == COLUMNS, reader.fieldnames
        rows = list(reader)
    assert {(row["case"], int(row["level"])) for row in rows} == {(case, level) for case in CASES for level in LEVELS}
    assert len(rows) == len(CASES) * len(LEVELS)
    assert len({row["reference_version"] for row in rows}) == 1
    for row in rows:
        for key in ("input_bytes", "vort_bytes", "reference_bytes", "iterations", "rounds", "vort_ns", "reference_ns", "checksum"):
            assert int(row[key]) > 0, row
        for key in ("size_over_reference", "vort_mib_s", "reference_mib_s", "vort_over_reference"):
            assert float(row[key]) > 0, row
        assert int(row["vort_bytes"]) < int(row["input_bytes"]), row
        # Level support must be real rather than silently ignored: require at
        # least two distinct reference sizes, while recording Vort's current
        # size behavior explicitly for the next planner work.
    # At least one corpus must expose a real reference level tradeoff. Some
    # highly repetitive inputs legitimately converge to the same wire size.
    assert any(
        len({int(row["reference_bytes"]) for row in rows if row["case"] == case}) >= 2
        for case in CASES
    ), rows
    # Keep wall-clock assertions to broad regression ceilings. Level 9 may now
    # legitimately finish before level 3 because its primary/8 KiB screen can
    # avoid the 4 KiB candidate; the dedicated stage gate validates the exact
    # per-level search budgets without relying on noisy cross-level timing.
    json_rows = {int(row["level"]): row for row in rows if row["case"] == "json"}
    # Levels 1-3 are latency-oriented and must not accidentally re-enable the
    # recursive mixed-family planner. This benchmark target is always compiled
    # in ReleaseFast, so the generous ceilings still distinguish the old
    # 11-15 second JSON cliff from normal same-machine variance.
    assert int(json_rows[1]["vort_ns"]) <= 2_000_000_000, json_rows
    # Level 3 still runs lazy and the legacy ratio candidates; leave enough
    # headroom for shared-machine variance while keeping the former 15-second
    # recursive-planner cliff impossible to reintroduce.
    assert int(json_rows[3]["vort_ns"]) <= 8_000_000_000, json_rows
    # The expanded planner must retain the measured JSON improvement over the
    # old 32-sequence 16,893-byte baseline on every level.
    assert int(json_rows[1]["vort_bytes"]) <= 13_688, json_rows
    assert int(json_rows[3]["vort_bytes"]) <= 13_688, json_rows
    assert int(json_rows[9]["vort_bytes"]) <= 13_506, json_rows
    # Levels 1 and 3 use bounded speed-oriented single-state repeat-beam
    # policies. Their audited three-byte JSON tradeoffs remain substantially
    # smaller than the corresponding libzstd frames; levels 9+ retain the
    # two-state 640-byte result.
    assert int(json_rows[1]["vort_bytes"]) <= 643, json_rows
    assert int(json_rows[1]["vort_bytes"]) < int(json_rows[1]["reference_bytes"]), json_rows
    assert int(json_rows[3]["vort_bytes"]) <= 643, json_rows
    # The level-9 repeat-aware beam closes the structured JSON gap to one byte
    # over libzstd 1.5.5 on this locked corpus. Keep lower-level ceilings
    # independent because they intentionally omit that ratio-oriented parser.
    assert int(json_rows[9]["vort_bytes"]) <= 640, json_rows
    assert int(json_rows[22]["vort_bytes"]) <= 640, json_rows
    # A one-block result below 1/32 of this low-alphabet corpus is decisive at
    # levels 3 and 9. Keep both early returns visible rather than allowing them
    # to regress to the former full adaptive split search. Level 1 is the
    # stable low-latency reference; a 4x ceiling leaves scheduler headroom while
    # still rejecting the previous roughly 4.4x level-3 cliff.
    assert int(json_rows[3]["vort_ns"]) < int(json_rows[1]["vort_ns"]) * 4, json_rows
    assert int(json_rows[9]["vort_ns"]) < int(json_rows[1]["vort_ns"]) * 4, json_rows
    text_rows = {int(row["level"]): row for row in rows if row["case"] == "text"}
    # Selecting compressed Huffman weights for low-byte alphabets closes all
    # but one byte of the repetitive-text gap to the locked libzstd row.
    assert int(text_rows[9]["vort_bytes"]) <= 80, text_rows
    assert int(text_rows[22]["vort_bytes"]) <= 80, text_rows
    binary_rows = {int(row["level"]): row for row in rows if row["case"] == "binary"}
    assert int(binary_rows[1]["vort_bytes"]) <= 8_607, binary_rows
    assert int(binary_rows[3]["vort_bytes"]) <= 8_607, binary_rows
    assert int(binary_rows[9]["vort_bytes"]) <= 8_607, binary_rows
    assert int(binary_rows[22]["vort_bytes"]) <= 8_607, binary_rows
    # Wide-alphabet level 3 returns its already-computed primary frame instead
    # of evaluating the adaptive split ladder. Keep the former roughly 5.8x
    # level-1 latency cliff from returning while leaving ample CI headroom.
    assert int(binary_rows[3]["vort_ns"]) < int(binary_rows[1]["vort_ns"]) * 4, binary_rows
    # Ratio levels accept a wide primary only after it reaches the audited 3:1
    # decisive threshold. Inside that primary, matching double-fast and
    # At level 1, a 4:15 double-fast result can return before repeat-beam as an
    # explicit fastest-level tradeoff. Level 3 has a stricter 1:16 shortcut;
    # level 9 retains independent repeat-beam consensus. The
    # benchmark uses three iterations and rounds so these relations do not
    # depend on a single scheduler sample. Keep level 1 at least 1.5x faster
    # than level 3, and keep the two consensus levels within 25% of each other.
    assert int(binary_rows[1]["vort_ns"]) * 3 < int(binary_rows[3]["vort_ns"]) * 2, binary_rows
    consensus_times = [int(binary_rows[level]["vort_ns"]) for level in (3, 9)]
    assert max(consensus_times) * 4 < min(consensus_times) * 5, binary_rows
    tradeoff_rows = {int(row["level"]): row for row in rows if row["case"] == "level3_tradeoff"}
    # Level 3 accepts the audited one-byte ratio tradeoff at a 1:16 block
    # ratio, while level 9 retains exhaustive arbitration and its smaller wire.
    assert int(tradeoff_rows[3]["vort_bytes"]) == 2_038, tradeoff_rows
    assert int(tradeoff_rows[9]["vort_bytes"]) == 2_037, tradeoff_rows
    assert int(tradeoff_rows[22]["vort_bytes"]) == 2_037, tradeoff_rows
    assert int(tradeoff_rows[3]["vort_ns"]) * 3 < int(tradeoff_rows[9]["vort_ns"]), tradeoff_rows
    multiblock_rows = {int(row["level"]): row for row in rows if row["case"] == "multiblock"}
    # Cross-block sequence-table reuse removes repeated FSE descriptions while
    # preserving exact candidate arbitration at every level.
    assert int(multiblock_rows[1]["vort_bytes"]) == 27_363, multiblock_rows
    assert int(multiblock_rows[3]["vort_bytes"]) == 27_517, multiblock_rows
    assert int(multiblock_rows[9]["vort_bytes"]) == 27_363, multiblock_rows
    assert int(multiblock_rows[22]["vort_bytes"]) == 26_679, multiblock_rows
    assert int(multiblock_rows[22]["vort_bytes"]) < int(multiblock_rows[9]["vort_bytes"]), multiblock_rows
    print(f"zstd_encode_bench_gate=ok rows={len(rows)} reference_version={rows[0]['reference_version']}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
