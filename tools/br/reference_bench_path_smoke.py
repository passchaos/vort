#!/usr/bin/env python3
"""Exercise raw and pre-encoded file inputs for the Brotli benchmark."""

import csv
import hashlib
import io
from pathlib import Path
import subprocess
import sys
import tempfile

from reference_bench_gate import COLUMNS


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
    with tempfile.TemporaryDirectory(prefix="vort-br-reference-path-") as directory:
        root = Path(directory)
        source = root / "source data.txt"
        frame = root / "source data.br"
        empty = root / "empty.bin"
        source.write_bytes(b"source-like payload with repeated words 0123456789\n" * 32)
        empty.write_bytes(b"")

        generated = run(
            executable,
            "--input",
            str(source),
            "--name",
            "external_source",
            "--quality",
            "3",
            "--iterations",
            "1",
            "--print-encoded-hex",
        )
        encoded_hex = generated.stderr.strip().splitlines()[-1]
        frame.write_bytes(bytes.fromhex(encoded_hex))

        reader = csv.DictReader(io.StringIO(generated.stdout))
        assert reader.fieldnames == COLUMNS, reader.fieldnames
        rows = list(reader)
        assert len(rows) == 1, rows
        row = rows[0]
        assert row["case"] == "external_source", row
        assert int(row["input_bytes"]) == source.stat().st_size, row
        assert row["input_sha256"] == hashlib.sha256(source.read_bytes()).hexdigest(), row
        assert int(row["encoded_bytes"]) == frame.stat().st_size, row
        assert float(row["vort_mib_s"]) > 0.0, row
        assert float(row["reference_mib_s"]) > 0.0, row

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
        assert int(prepared_row["input_bytes"]) == source.stat().st_size, prepared_row
        assert int(prepared_row["encoded_bytes"]) == frame.stat().st_size, prepared_row
        assert prepared_row["input_sha256"] == hashlib.sha256(source.read_bytes()).hexdigest(), prepared_row
        assert "/source%20data.zst" not in prepared_row["command"], prepared_row
        assert "/source%20data.br" in prepared_row["command"], prepared_row

        for invalid_args in (
            ("--input", str(empty)),
            ("--input", str(source), "--encoded-input", str(empty)),
            ("--encoded-input", str(frame)),
            ("--input", str(source), "--name", "bad,name"),
            ("--input", str(source), "--case", "tiny"),
        ):
            failed = run(executable, *invalid_args, check=False)
            assert failed.returncode != 0, (invalid_args, failed.stdout, failed.stderr)

    print("br_reference_bench_path_smoke=ok rows=2 invalid=5")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
