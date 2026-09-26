#!/usr/bin/env python3
"""Exercise file-backed inputs for the in-process Zstd decode benchmark."""

import csv
import hashlib
import io
from pathlib import Path
import subprocess
import sys
import tempfile

from reference_bench_gate import EXPECTED_COLUMNS


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
        raise SystemExit("usage: reference_bench_path_smoke.py <benchmark>")
    executable = Path(sys.argv[1]).resolve()
    with tempfile.TemporaryDirectory(prefix="vort-zstd-reference-path-") as directory:
        root = Path(directory)
        source = root / "source data.txt"
        empty = root / "empty.txt"
        source.write_bytes(b"source-like payload with repeated words 0123456789\n" * 32)
        empty.write_bytes(b"")
        payload = source.read_bytes()
        assert 256 <= len(payload) <= 65535 + 256
        frame = root / "source data.zst"
        frame_header = bytes.fromhex("28b52ffd") + bytes([0x60]) + (len(payload) - 256).to_bytes(2, "little")
        block_header = ((len(payload) << 3) | 1).to_bytes(3, "little")
        frame.write_bytes(frame_header + block_header + payload)

        result = run(
            executable,
            "--input",
            str(source),
            "--name",
            "external_source",
            "--level",
            "3",
            "--iterations",
            "1",
        )
        reader = csv.DictReader(io.StringIO(result.stdout))
        assert reader.fieldnames == EXPECTED_COLUMNS, reader.fieldnames
        rows = list(reader)
        assert len(rows) == 1, rows
        row = rows[0]
        assert row["case"] == "external_source", row
        assert int(row["input_bytes"]) == source.stat().st_size, row
        assert row["input_sha256"] == hashlib.sha256(source.read_bytes()).hexdigest(), row
        assert int(row["encoded_bytes"]) > 0, row
        assert float(row["vort_mib_s"]) > 0.0, row
        assert float(row["reference_mib_s"]) > 0.0, row
        assert int(row["total_literal_bytes"]) + int(row["total_match_bytes"]) == int(row["input_bytes"]), row
        assert "/source%20data.txt" in row["command"], row

        prepared = run(
            executable,
            "--input",
            str(source),
            "--encoded-input",
            str(frame),
            "--name",
            "prepared_source",
            "--iterations",
            "1",
        )
        prepared_rows = list(csv.DictReader(io.StringIO(prepared.stdout)))
        assert len(prepared_rows) == 1, prepared_rows
        prepared_row = prepared_rows[0]
        assert prepared_row["case"] == "prepared_source", prepared_row
        assert int(prepared_row["input_bytes"]) == len(payload), prepared_row
        assert int(prepared_row["encoded_bytes"]) == frame.stat().st_size, prepared_row
        assert prepared_row["input_sha256"] == hashlib.sha256(payload).hexdigest(), prepared_row
        assert "/source%20data.zst" in prepared_row["command"], prepared_row

        for invalid_args in (
            ("--input", str(empty)),
            ("--input", str(source), "--encoded-input", str(empty)),
            ("--encoded-input", str(frame)),
            ("--input", str(source), "--name", "bad,name"),
            ("--name", "orphan"),
            ("--level", "3"),
            ("--input", str(source), "--case", "tiny"),
        ):
            failed = run(executable, *invalid_args, check=False)
            assert failed.returncode != 0, (invalid_args, failed.stdout, failed.stderr)

    print("zstd_reference_bench_path_smoke=ok rows=2 invalid=7")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
