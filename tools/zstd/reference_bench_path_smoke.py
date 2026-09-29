#!/usr/bin/env python3
"""Exercise file-backed inputs for the in-process Zstd decode benchmark."""

import csv
import hashlib
import io
from pathlib import Path
import subprocess
import sys
import tempfile

from reference_bench_gate import EXPECTED_COLUMNS, validate_api


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
        validate_api(rows, "one-shot")
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
        validate_api(prepared_rows, "one-shot")
        assert len(prepared_rows) == 1, prepared_rows
        prepared_row = prepared_rows[0]
        assert prepared_row["case"] == "prepared_source", prepared_row
        assert int(prepared_row["input_bytes"]) == len(payload), prepared_row
        assert int(prepared_row["encoded_bytes"]) == frame.stat().st_size, prepared_row
        assert prepared_row["input_sha256"] == hashlib.sha256(payload).hexdigest(), prepared_row
        assert "/source%20data.zst" in prepared_row["command"], prepared_row

        for encoded_args, expected in (((), row), (("--encoded-input", str(frame)), prepared_row)):
            reused = run(
                executable, "--input", str(source), "--level", "3",
                *encoded_args, "--reusable", "--iterations", "3",
            )
            reader = csv.DictReader(io.StringIO(reused.stdout))
            assert reader.fieldnames == EXPECTED_COLUMNS, reader.fieldnames
            reused_rows = list(reader)
            assert len(reused_rows) == 1, reused_rows
            validate_api(reused_rows, "reusable")
            reused_row = reused_rows[0]
            for key in ("input_sha256", "input_bytes", "encoded_bytes", "block_count", "total_sequence_count"):
                assert reused_row[key] == expected[key], (key, reused_row, expected)
            assert int(reused_row["checksum"]) == 3 * int(expected["checksum"]), reused_row

            # Reject both a wrong API and a mixed-mode report; a reusable Vort
            # result must never silently be compared with the one-shot API.
            wrong = dict(reused_row, reference_api="ZSTD_decompress")
            for invalid_rows in ([wrong], [reused_row, row]):
                try:
                    validate_api(invalid_rows, "reusable")
                except AssertionError:
                    pass
                else:
                    raise AssertionError(f"accepted mismatched APIs: {invalid_rows!r}")

        for api_args in ((), ("--reusable",)):
            for input_offset, output_offset in ((0, 0), (3, 15), (17, 31), (127, 127)):
                shifted = run(
                    executable, "--input", str(source), "--encoded-input", str(frame),
                    "--input-offset", str(input_offset), "--output-offset", str(output_offset),
                    *api_args, "--iterations", "1",
                )
                shifted_rows = list(csv.DictReader(io.StringIO(shifted.stdout)))
                assert len(shifted_rows) == 1, shifted_rows
                shifted_row = shifted_rows[0]
                assert shifted_row["input_sha256"] == prepared_row["input_sha256"], shifted_row
                assert shifted_row["checksum"] == prepared_row["checksum"], shifted_row
                assert int(shifted_row["input_mod128"]) == input_offset, shifted_row
                assert int(shifted_row["output_mod128"]) == output_offset, shifted_row
                assert int(shifted_row["reference_output_mod128"]) == output_offset, shifted_row

        for invalid_args in (
            ("--input", str(empty)),
            ("--input", str(source), "--encoded-input", str(empty)),
            ("--encoded-input", str(frame)),
            ("--input", str(source), "--name", "bad,name"),
            ("--name", "orphan"),
            ("--level", "3"),
            ("--input", str(source), "--case", "tiny"),
            ("--input-offset", "128"),
            ("--output-offset", "128"),
            ("--output-offset", "-1"),
        ):
            failed = run(executable, *invalid_args, check=False)
            assert failed.returncode != 0, (invalid_args, failed.stdout, failed.stderr)

    print("zstd_reference_bench_path_smoke=ok rows=12 invalid=10 api_modes=2 address_pairs=4")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
