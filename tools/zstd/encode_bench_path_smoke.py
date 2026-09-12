#!/usr/bin/env python3
"""Exercise file-backed inputs for the Zstd encode benchmark."""

import csv
import io
from pathlib import Path
import subprocess
import sys
import tempfile

COLUMNS = [
    "case",
    "reference_version",
    "level",
    "input_bytes",
    "vort_bytes",
    "reference_bytes",
    "size_over_reference",
    "iterations",
    "rounds",
    "vort_ns",
    "reference_ns",
    "vort_mib_s",
    "reference_mib_s",
    "vort_over_reference",
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
        raise SystemExit("usage: encode_bench_path_smoke.py <benchmark>")
    executable = Path(sys.argv[1]).resolve()
    with tempfile.TemporaryDirectory(prefix="vort-zstd-encode-path-") as directory:
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
            "--level",
            "1",
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
            assert int(row["input_bytes"]) == 17, row
            assert int(row["vort_bytes"]) > 0, row
            assert int(row["reference_bytes"]) > 0, row
            assert int(row["checksum"]) == int(row["vort_bytes"]) + int(row["reference_bytes"]), row

        filtered = run(
            executable,
            "--iterations",
            "1",
            "--rounds",
            "1",
            "--level",
            "3",
            "--case",
            "file1_beta_data_txt",
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
        assert int(filtered_rows[0]["level"]) == 3, filtered_rows

        for invalid_args in (
            ("--limit", "0", "--path", str(first)),
            ("--path", str(empty)),
            ("--unknown",),
        ):
            failed = run(executable, *invalid_args, check=False)
            assert failed.returncode != 0, (invalid_args, failed.stdout, failed.stderr)

    print("zstd_encode_bench_path_smoke=ok rows=2 filtered=1 invalid=3")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
