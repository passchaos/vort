#!/usr/bin/env python3
"""Negative smoke tests for the native tier range benchmark gate.

The production gate is intentionally strict because dashboard health and
ReleaseFast seekability-tier evidence both rely on its summary.  These cheap
fixtures exercise malformed CSVs and throughput-floor failures directly, so a
future relaxation of the validator has to be intentional rather than an
accidental green dashboard.
"""

from __future__ import annotations

import csv
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Callable

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[1]
GATE = ROOT / "tools" / "native_tier_range_bench_gate.py"
COLUMNS = [
    "fixture",
    "tier",
    "block_len",
    "input_bytes",
    "stream_bytes",
    "index_entries",
    "range_offset",
    "range_len",
    "iterations",
    "repeat",
    "elapsed_ns",
    "range_mib_s",
    "full_input_mib_s",
    "checksum",
]
TIERS = {
    "seek_fast": 8 * 1024,
    "balanced": 32 * 1024,
    "ratio": 64 * 1024,
}


def throughput(input_bytes: int, range_len: int, iterations: int, elapsed_ns: int) -> tuple[float, float]:
    seconds = elapsed_ns / 1_000_000_000.0
    range_mib_s = ((range_len * iterations) / (1024.0 * 1024.0)) / seconds
    full_mib_s = ((input_bytes * iterations) / (1024.0 * 1024.0)) / seconds
    return range_mib_s, full_mib_s


def row(fixture: str, tier: str, *, elapsed_ns: int = 1_000_000) -> dict[str, str]:
    input_bytes = 128 * 1024
    range_len = 4096
    iterations = 400
    range_mib_s, full_mib_s = throughput(input_bytes, range_len, iterations, elapsed_ns)
    block_len = TIERS[tier]
    return {
        "fixture": fixture,
        "tier": tier,
        "block_len": str(block_len),
        "input_bytes": str(input_bytes),
        "stream_bytes": str(20_000 + block_len // 1024),
        "index_entries": str((input_bytes + block_len - 1) // block_len),
        "range_offset": str((input_bytes - range_len) // 2),
        "range_len": str(range_len),
        "iterations": str(iterations),
        "repeat": "3",
        "elapsed_ns": str(elapsed_ns),
        "range_mib_s": f"{range_mib_s:.6f}",
        "full_input_mib_s": f"{full_mib_s:.6f}",
        "checksum": str(1_000_000 + block_len),
    }


def valid_rows(fixture: str = "sample") -> list[dict[str, str]]:
    return [row(fixture, tier) for tier in ("seek_fast", "balanced", "ratio")]


def write_csv(path: Path, rows: list[dict[str, str]], *, columns: list[str] = COLUMNS) -> None:
    with path.open("w", newline="") as dest:
        writer = csv.DictWriter(dest, fieldnames=columns, extrasaction="ignore", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def run_gate(path: Path, *extra: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(GATE), "--csv", str(path), "--expect-fixtures", "sample", *extra],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )


def expect_success(name: str, csv_path: Path, *extra: str, validate: Callable[[subprocess.CompletedProcess[str]], bool]) -> dict[str, object]:
    result = run_gate(csv_path, *extra)
    matched = result.returncode == 0 and validate(result)
    return {
        "name": name,
        "expected_failure": False,
        "matched": matched,
        "returncode": result.returncode,
    }


def expect_failure(name: str, csv_path: Path, expected_text: str, *extra: str) -> dict[str, object]:
    result = run_gate(csv_path, *extra)
    combined = result.stdout + result.stderr
    return {
        "name": name,
        "expected_failure": True,
        "matched": result.returncode != 0 and expected_text in combined,
        "returncode": result.returncode,
    }


def main() -> int:
    cases: list[dict[str, object]] = []
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)

        valid_csv = root / "valid.csv"
        summary_path = root / "summary.json"
        write_csv(valid_csv, valid_rows())
        cases.append(
            expect_success(
                "valid_summary_written",
                valid_csv,
                "--summary",
                str(summary_path),
                validate=lambda result: (
                    "native_tier_range_bench_gate=ok" in result.stdout
                    and summary_path.exists()
                    and json.loads(summary_path.read_text()).get("rows") == 3
                ),
            )
        )

        empty_csv = root / "empty.csv"
        write_csv(empty_csv, [])
        cases.append(expect_failure("empty_csv_rejected", empty_csv, "has no rows"))

        missing_tier_csv = root / "missing-tier.csv"
        write_csv(missing_tier_csv, valid_rows()[:2])
        cases.append(expect_failure("missing_tier_rejected", missing_tier_csv, "bad fixture/tier matrix"))

        duplicate_row_csv = root / "duplicate-row.csv"
        duplicate_rows = valid_rows()
        duplicate_rows.append(dict(duplicate_rows[0]))
        write_csv(duplicate_row_csv, duplicate_rows)
        cases.append(expect_failure("duplicate_row_rejected", duplicate_row_csv, "bad fixture/tier matrix"))

        bad_block_csv = root / "bad-block.csv"
        bad_block_rows = valid_rows()
        bad_block_rows[0]["block_len"] = str(16 * 1024)
        write_csv(bad_block_csv, bad_block_rows)
        cases.append(expect_failure("bad_block_len_rejected", bad_block_csv, "block_len=16384"))

        bad_math_csv = root / "bad-math.csv"
        bad_math_rows = valid_rows()
        bad_math_rows[0]["range_mib_s"] = "1.000000"
        write_csv(bad_math_csv, bad_math_rows)
        cases.append(expect_failure("throughput_math_rejected", bad_math_csv, "range_mib_s"))

        bad_range_csv = root / "bad-range.csv"
        bad_range_rows = valid_rows()
        bad_range_rows[0]["range_offset"] = str(128 * 1024)
        write_csv(bad_range_csv, bad_range_rows)
        cases.append(expect_failure("range_bounds_rejected", bad_range_csv, "range exceeds input"))

        slow_csv = root / "slow.csv"
        slow_rows = valid_rows()
        # Keep the reported throughput mathematically consistent, but below the
        # ReleaseFast floor so the floor check itself is what fails.
        slow_rows[0] = row("sample", "seek_fast", elapsed_ns=1_562_500_000)
        write_csv(slow_csv, slow_rows)
        cases.append(expect_failure("releasefast_floor_rejected", slow_csv, "below ReleaseFast floor", "--enforce-throughput"))

    failed = [case for case in cases if not case["matched"]]
    if failed:
        for case in failed:
            print(f"native_tier_range_bench_gate_negative_smoke failed: {case}")
        return 1
    print(f"native_tier_range_bench_gate_negative_smoke=ok cases={len(cases)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
