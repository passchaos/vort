#!/usr/bin/env python3
"""Exercise file-backed inputs for the Zstd decode shape profiler."""

import csv
import hashlib
import io
from pathlib import Path
import subprocess
import sys
import tempfile

from decode_profile_gate import COLUMNS


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
        raise SystemExit("usage: decode_profile_path_smoke.py <profiler>")
    executable = Path(sys.argv[1]).resolve()
    with tempfile.TemporaryDirectory(prefix="vort-zstd-profile-path-") as directory:
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
        assert reader.fieldnames == COLUMNS, reader.fieldnames
        rows = list(reader)
        assert len(rows) == 1, rows
        row = rows[0]
        assert row["case"] == "external_source", row
        assert row["api_mode"] == "one-shot", row
        assert int(row["reusable_sequence_table_hits"]) == 0, row
        assert int(row["reusable_huffman_tree_hits"]) == 0, row
        assert int(row["input_bytes"]) == source.stat().st_size, row
        assert row["input_sha256"] == hashlib.sha256(source.read_bytes()).hexdigest(), row
        assert int(row["encoded_bytes"]) > 0, row
        assert int(row["literal_bytes"]) + int(row["match_bytes"]) == int(row["input_bytes"]), row
        assert sum(int(row[key]) for key in ("compressed_table_modes", "repeat_table_modes", "rle_table_modes", "predefined_table_modes")) == int(row["sequence_blocks"]) * 3, row
        assert int(row["no_low_probability_tables"]) + int(row["low_probability_tables"]) == int(row["compressed_table_modes"]), row
        assert sum(int(row[key]) for key in ("raw_literal_blocks", "rle_literal_blocks", "compressed_literal_blocks", "treeless_literal_blocks")) == int(row["compressed_blocks"]), row
        assert sum(int(value) for value in row["split_path_blocks"].split(";")) == int(row["sequence_blocks"]), row
        assert sum(int(value) for value in row["split_path_sequences"].split(";")) == int(row["total_sequences"]), row
        assert sum(int(value) for value in row["split_path_match_bytes"].split(";")) == int(row["match_bytes"]), row
        assert int(row["far_batch8_all_far_common"]) <= int(row["far_batch8_all_far"]) <= int(row["far_batch8_windows"]), row
        assert int(row["far_batch8_all_far_same_offset"]) <= int(row["far_batch8_all_far"]), row
        assert "/source%20data.txt" in row["command"], row

        reusable = run(
            executable,
            "--input",
            str(source),
            "--name",
            "reusable_source",
            "--level",
            "3",
            "--iterations",
            "2",
            "--reusable",
        )
        reusable_rows = list(csv.DictReader(io.StringIO(reusable.stdout)))
        assert len(reusable_rows) == 1, reusable_rows
        reusable_row = reusable_rows[0]
        assert reusable_row["api_mode"] == "reusable", reusable_row
        assert int(reusable_row["reusable_sequence_table_hits"]) >= 0, reusable_row
        assert int(reusable_row["reusable_huffman_tree_hits"]) >= 0, reusable_row
        assert reusable_row["input_sha256"] == row["input_sha256"], reusable_row

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
        assert prepared_row["api_mode"] == "one-shot", prepared_row
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
            ("--input", str(source), "--case", "ascii64k"),
        ):
            failed = run(executable, *invalid_args, check=False)
            assert failed.returncode != 0, (invalid_args, failed.stdout, failed.stderr)

    print("zstd_decode_profile_path_smoke=ok rows=3 invalid=7 api_modes=2")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
