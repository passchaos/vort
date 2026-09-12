#!/usr/bin/env python3
"""Exercise file-backed inputs for the native Zstd stage benchmark."""

import csv
import io
from pathlib import Path
import subprocess
import sys
import tempfile


COLUMNS = [
    "case",
    "level",
    "input_bytes",
    "candidate",
    "block_size",
    "block_count",
    "search_budget",
    "stage",
    "available_blocks",
    "sequences",
    "encoded_bytes",
    "literals_bytes",
    "sequence_bytes",
    "iterations",
    "rounds",
    "warmup",
    "median_ns",
    "ns_per_block",
    "checksum",
]


def run(executable: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(executable), *args],
        check=check,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: native_encode_stage_bench_path_smoke.py <benchmark>")
    executable = Path(sys.argv[1]).resolve()
    with tempfile.TemporaryDirectory(prefix="vort-zstd-stage-path-") as directory:
        root = Path(directory)
        first = root / "alpha.json"
        second = root / "beta data.txt"
        empty = root / "empty.txt"
        first.write_bytes(b'{"kind":"event","value":12345}\n' * 8)
        second.write_bytes(b"source-like payload with repeated words and values 0123456789\n" * 8)
        empty.write_bytes(b"")

        result = run(
            executable,
            "--iterations",
            "1",
            "--rounds",
            "1",
            "--warmup",
            "0",
            "--level",
            "1",
            "--candidate",
            "primary",
            "--stage",
            "double_fast",
            "--limit",
            "17",
            "--path",
            str(first),
            "--path",
            str(second),
        )
        reader = csv.DictReader(io.StringIO(result.stdout))
        assert reader.fieldnames == COLUMNS, reader.fieldnames
        rows = list(reader)
        assert [row["case"] for row in rows] == ["file0_alpha_json", "file1_beta_data_txt"], rows
        for row in rows:
            assert int(row["level"]) == 1, row
            assert row["candidate"] == "primary", row
            assert row["stage"] == "double_fast", row
            assert int(row["input_bytes"]) == 17, row
            assert int(row["block_count"]) == 1, row
            assert int(row["iterations"]) == 1, row
            assert int(row["rounds"]) == 1, row
            assert int(row["warmup"]) == 0, row
            assert int(row["median_ns"]) > 0, row

        filtered = run(
            executable,
            "--iterations",
            "1",
            "--rounds",
            "1",
            "--warmup",
            "0",
            "--case",
            "file1_beta_data_txt",
            "--candidate",
            "primary",
            "--stage",
            "greedy",
            "--path",
            str(first),
            "--path",
            str(second),
        )
        filtered_reader = csv.DictReader(io.StringIO(filtered.stdout))
        assert filtered_reader.fieldnames == COLUMNS, filtered_reader.fieldnames
        filtered_rows = list(filtered_reader)
        assert len(filtered_rows) == 1, filtered_rows
        assert filtered_rows[0]["case"] == "file1_beta_data_txt", filtered_rows
        assert filtered_rows[0]["stage"] == "greedy", filtered_rows

        for invalid_args in (
            ("--limit", "0", "--path", str(first)),
            ("--path", str(empty)),
            ("--unknown",),
        ):
            failed = run(executable, *invalid_args, check=False)
            assert failed.returncode != 0, (invalid_args, failed.stdout, failed.stderr)

    print("zstd_native_encode_stage_bench_path_smoke=ok rows=2 filtered=1 invalid=3")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
