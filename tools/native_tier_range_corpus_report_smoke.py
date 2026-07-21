#!/usr/bin/env python3
"""Smoke-test the native tier range corpus report wrapper.

The real corpus benchmark shells out to the Zig benchmark and can be relatively
slow.  This smoke keeps the wrapper-only invariants cheap and deterministic:
source corpus labels must be persisted into the CSV that dashboard gates read,
and a no-input run must not leave behind stale CSV data for later gates.
"""

from __future__ import annotations

import csv
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "native_tier_range_corpus_report.py"
HEADER = "fixture,tier,block_len,input_bytes,stream_bytes,index_entries,range_offset,range_len,iterations,repeat,elapsed_ns,range_mib_s,full_input_mib_s,checksum"
TIERS = {
    "seek_fast": 8 * 1024,
    "balanced": 32 * 1024,
    "ratio": 64 * 1024,
}


def write_fake_bench(path: Path) -> None:
    path.write_text(
        """#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import sys

TIERS = {
    "seek_fast": 8192,
    "balanced": 32768,
    "ratio": 65536,
}
HEADER = "fixture,tier,block_len,input_bytes,stream_bytes,index_entries,range_offset,range_len,iterations,repeat,elapsed_ns,range_mib_s,full_input_mib_s,checksum"

def main() -> int:
    args = sys.argv[1:]
    csv_path = pathlib.Path(args[args.index("--csv") + 1])
    paths = args[args.index("--paths") + 1:]
    rows = [HEADER]
    for sample in paths:
        name = pathlib.Path(sample).name
        input_bytes = max(1, pathlib.Path(sample).stat().st_size)
        for tier, block_len in TIERS.items():
            # The numbers are intentionally simple but internally consistent
            # enough for the wrapper smoke; the real gate validates benchmark
            # math and throughput.
            rows.append(f"{name},{tier},{block_len},{input_bytes},{input_bytes + block_len // 1024},1,0,1,1,1,1000,1.0,1.0,{block_len}")
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    csv_path.write_text("\\n".join(rows) + "\\n")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
""",
    )
    path.chmod(0o755)


def run(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=ROOT, check=True, text=True, capture_output=True)


def read_fixtures(path: Path) -> list[str]:
    with path.open(newline="") as source:
        return [row["fixture"] for row in csv.DictReader(source)]


def main() -> int:
    cases: list[dict[str, object]] = []
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        fake_bench = root / "fake-native-tier-range-bench.py"
        write_fake_bench(fake_bench)

        corpus = root / "corpus"
        nested = corpus / "nested"
        nested.mkdir(parents=True)
        (corpus / "alpha.txt").write_text("alpha\n" * 3)
        (nested / "beta.bin").write_bytes(b"beta" * 5)

        label_csv = root / "labels.csv"
        label_result = run(
            [
                sys.executable,
                str(SCRIPT),
                str(fake_bench),
                "--paths",
                str(corpus),
                "--limit",
                "2",
                "--csv",
                str(label_csv),
            ]
        )
        fixtures = read_fixtures(label_csv)
        unique_fixtures = sorted(set(fixtures))
        expected_fixtures = ["corpus/alpha.txt-128k", "corpus/nested/beta.bin-128k"]
        label_matched = (
            unique_fixtures == expected_fixtures
            and all(not (fixture[:3].isdigit() and fixture[3:4] == "-") for fixture in unique_fixtures)
            and label_result.stdout.splitlines()[0] == HEADER
            and sorted(set(read_fixtures(label_csv))) == sorted(set(line.split(",", 1)[0] for line in label_result.stdout.splitlines()[1:]))
        )
        cases.append(
            {
                "name": "persist_source_labels",
                "matched": label_matched,
                "fixtures": unique_fixtures,
                "expected_fixtures": expected_fixtures,
            }
        )

        stale_dir = root / "empty"
        stale_dir.mkdir()
        stale_csv = root / "stale.csv"
        stale_csv.write_text("stale\n")
        stale_result = run(
            [
                sys.executable,
                str(SCRIPT),
                str(fake_bench),
                "--paths",
                str(stale_dir),
                "--csv",
                str(stale_csv),
            ]
        )
        stale_matched = (not stale_csv.exists()) and "no standard corpora discovered" in stale_result.stdout
        cases.append({"name": "remove_stale_csv_without_cases", "matched": stale_matched})

    failed = [case for case in cases if not case["matched"]]
    if failed:
        for case in failed:
            print(f"native_tier_range_corpus_report_smoke failed: {case}")
        return 1
    print(f"native_tier_range_corpus_report_smoke=ok cases={len(cases)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
