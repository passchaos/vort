#!/usr/bin/env python3
"""Validate bounded deterministic directory discovery for context reports."""
import csv
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
EXE = Path(sys.argv[1])


def run(output: Path) -> list[dict[str, str]]:
    subprocess.run([
        str(EXE), "--dir", "corpus", "--max-files", "2", "--limit", "128",
        "--csv", str(output),
    ], cwd=ROOT, check=True)
    with output.open(newline="") as file:
        return list(csv.DictReader(file))


with tempfile.TemporaryDirectory() as temp:
    first = run(Path(temp) / "first.csv")
    second = run(Path(temp) / "second.csv")

assert len(first) == 8 and len(second) == 8
directory_rows = [row for row in first if row["case"].startswith("dir-")]
assert [row["case"] for row in directory_rows] == ["dir-0-0", "dir-0-1"]
assert all(0 < int(row["input_bytes"]) <= 128 for row in directory_rows)
stable_columns = [
    "case", "input_bytes", "input_sha256", "encoded_bytes", "size_ratio",
    "literal_context_trees", "context_model",
]
assert [tuple(row[column] for column in stable_columns) for row in first] == [
    tuple(row[column] for column in stable_columns) for row in second
]

failed = subprocess.run([
    str(EXE), "--dir", "corpus", "--max-files", "0", "--limit", "128",
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
assert failed.returncode != 0

print("br_context_tree_report_dir_smoke=ok rows=8 directory_rows=2 negative_cases=1")
