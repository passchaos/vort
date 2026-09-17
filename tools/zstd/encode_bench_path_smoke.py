#!/usr/bin/env python3
"""Exercise file-backed inputs for the Zstd encode benchmark."""

import csv
import hashlib
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile

PROVENANCE_COLUMNS = ["provenance_version", "optimize", "zig_version", "target_arch", "target_os", "target_abi", "target_cpu", "cpu_model", "cpu_affinity", "affinity_cpu_count", "benchmark_threads", "codec_thread_policy", "executable_sha256", "command"]
COLUMNS = [
    "case",
    "reference_version",
    "level",
    "input_bytes",
    "input_sha256",
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
] + PROVENANCE_COLUMNS


def run(executable: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(executable), *args],
        check=check,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def reference_library() -> Path | None:
    candidates = (
        Path("/opt/homebrew/opt/zstd/lib/libzstd.dylib"),
        Path("/usr/local/opt/zstd/lib/libzstd.dylib"),
        Path("/lib/x86_64-linux-gnu/libzstd.so.1"),
        Path("/usr/lib/x86_64-linux-gnu/libzstd.so.1"),
        Path("/lib/aarch64-linux-gnu/libzstd.so.1"),
        Path("/usr/lib/aarch64-linux-gnu/libzstd.so.1"),
    )
    return next((path.resolve() for path in candidates if path.is_file()), None)


def affinity_text(cpus: set[int]) -> str:
    ranges: list[str] = []
    ordered = sorted(cpus)
    index = 0
    while index < len(ordered):
        start = end = ordered[index]
        while index + 1 < len(ordered) and ordered[index + 1] == end + 1:
            index += 1
            end = ordered[index]
        ranges.append(str(start) if start == end else f"{start}-{end}")
        index += 1
    return ";".join(ranges) if ranges else "unavailable"


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: encode_bench_path_smoke.py <benchmark>")
    executable = Path(sys.argv[1]).resolve()
    executable_sha256 = hashlib.sha256(executable.read_bytes()).hexdigest()
    explicit_library = reference_library()
    reference_args = ("--libzstd", str(explicit_library)) if explicit_library else ()
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
            *reference_args,
        )
        reader = csv.DictReader(io.StringIO(result.stdout))
        assert reader.fieldnames == COLUMNS, reader.fieldnames
        rows = list(reader)
        assert [row["case"] for row in rows] == ["file0_alpha_json", "file1_beta_data_txt"], rows
        for row in rows:
            assert int(row["level"]) == 1, row
            assert int(row["input_bytes"]) == 17, row
            assert row["input_sha256"] == hashlib.sha256((first if row["case"].startswith("file0_") else second).read_bytes()[:17]).hexdigest(), row
            assert int(row["vort_bytes"]) > 0, row
            assert int(row["reference_bytes"]) > 0, row
            assert int(row["checksum"]) == int(row["vort_bytes"]) + int(row["reference_bytes"]), row
            assert row["optimize"] == "ReleaseFast", row
            assert row["provenance_version"] == "1", row
            assert all(row[key] for key in PROVENANCE_COLUMNS), row
            if hasattr(os, "sched_getaffinity"):
                assert row["cpu_affinity"] == affinity_text(os.sched_getaffinity(0)), row
                assert row["cpu_model"] != "unavailable", row
                assert int(row["affinity_cpu_count"]) == len(os.sched_getaffinity(0)), row
            assert "--limit 17" in row["command"], row
            assert "%20" in row["command"], row
            assert int(row["benchmark_threads"]) == 1, row
            assert row["codec_thread_policy"] == "internal-auto", row
            assert row["executable_sha256"] == executable_sha256, row
            if explicit_library is not None:
                assert f"--libzstd {explicit_library}" in row["command"], row

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
            *reference_args,
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
            ("--libzstd",),
            ("--libzstd", str(root / "missing-libzstd")),
            ("--unknown",),
        ):
            failed = run(executable, *invalid_args, check=False)
            assert failed.returncode != 0, (invalid_args, failed.stdout, failed.stderr)

    print(f"zstd_encode_bench_path_smoke=ok rows=2 filtered=1 invalid=5 explicit_libzstd={explicit_library is not None}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
