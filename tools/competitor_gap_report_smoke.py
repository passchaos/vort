#!/usr/bin/env python3
"""Exercise competitor_gap_report positive and negative paths with tiny CSVs."""

from __future__ import annotations

import csv
import json
import math
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "tools" / "competitor_gap_report.py"
PROVENANCE = {
    "provenance_version": "1",
    "optimize": "ReleaseFast",
    "zig_version": "0.16.0",
    "target_arch": "x86_64",
    "target_os": "linux",
    "target_abi": "gnu",
    "target_cpu": "raptorlake",
    "cpu_model": "smoke-cpu",
    "cpu_affinity": "8",
    "affinity_cpu_count": "1",
    "benchmark_threads": "1",
    "codec_thread_policy": "single",
    "executable_sha256": "a" * 64,
    "command": "vort-bench%20--iterations%20100",
}


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    if not rows:
        raise AssertionError(f"fixture must have rows: {path}")
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def run_report(
    input_dir: Path,
    markdown_path: Path,
    json_path: Path,
    *extra: str,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            sys.executable,
            str(REPORT),
            "--input-dir",
            str(input_dir),
            "--markdown",
            str(markdown_path),
            "--json",
            str(json_path),
            *extra,
        ],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )


def expect_failure(result: subprocess.CompletedProcess[str], message: str) -> None:
    if result.returncode == 0 or message not in result.stderr:
        raise AssertionError(
            f"expected failure containing {message!r}; "
            f"rc={result.returncode} stdout={result.stdout!r} stderr={result.stderr!r}"
        )


def write_core_fixtures(root: Path) -> None:
    write_csv(
        root / "vort-rust-deflate-encode-bench-repeat3.csv",
        [
            {"engine": "vort-default", "format": "zlib", "case": "alpha", "input_bytes": 1000, "frame_bytes": 90, "throughput_mib_s": 200},
            {"engine": "alpha-ref", "format": "zlib", "case": "alpha", "input_bytes": 1000, "frame_bytes": 100, "throughput_mib_s": 100},
            {"engine": "vort-default", "format": "zlib", "case": "beta", "input_bytes": 1000, "frame_bytes": 105, "throughput_mib_s": 80},
            {"engine": "beta-ref", "format": "zlib", "case": "beta", "input_bytes": 1000, "frame_bytes": 100, "throughput_mib_s": 100},
        ],
    )
    write_csv(
        root / "vort-rust-deflate-decode-bench-repeat3.csv",
        [
            {"engine": engine, "format": "zlib", "case": "alpha", "input_bytes": 1000, "throughput_mib_s": speed}
            for engine, speed in (("vort", 100), ("vort-exact", 110), ("vort-into", 150), ("rust-ref", 100))
        ],
    )
    write_csv(
        root / "vort-zstd-encode-bench.csv",
        [
            {"case": "alpha", "level": 1, "input_bytes": 1000, "input_sha256": "1" * 64, "reference_version": "10505", "vort_bytes": 90, "reference_bytes": 100, "vort_mib_s": 200, "reference_mib_s": 100} | PROVENANCE,
            {"case": "beta", "level": 1, "input_bytes": 1000, "input_sha256": "2" * 64, "reference_version": "10505", "vort_bytes": 90, "reference_bytes": 100, "vort_mib_s": 80, "reference_mib_s": 100} | PROVENANCE,
        ],
    )
    write_csv(
        root / "vort-zstd-reference-bench.csv",
        [{"case": "alpha", "input_bytes": 1000, "input_sha256": "1" * 64, "reference_version": "10505", "vort_mib_s": 120, "reference_mib_s": 100} | PROVENANCE],
    )
    write_csv(
        root / "vort-lz4-reference-bench.csv",
        [{"case": "alpha", "input_bytes": 1000, "reference_version": "10904", "encoded_bytes": 100, "vort_encoded_bytes": 100, "vort_mib_s": 140, "reference_mib_s": 100}],
    )
    write_csv(
        root / "vort-snappy-reference-bench.csv",
        [{"case": "alpha", "input_bytes": 1000, "encoded_bytes": 100, "vort_mib_s": 130, "reference_mib_s": 100}],
    )
    write_csv(
        root / "vort-br-planned-encode-bench.csv",
        [{"case": "alpha", "quality": 3, "input_bytes": 1000, "reference_version": 1001000, "vort_bytes": 110, "lazy_bytes": 100, "ratio_bytes": 90, "reference_bytes": 100, "vort_mib_s": 200, "lazy_mib_s": 120, "ratio_mib_s": 80, "reference_mib_s": 100}],
    )
    write_csv(
        root / "vort-br-reference-bench.csv",
        [{"case": "alpha", "input_bytes": 1000, "reference_version": 1001000, "vort_mib_s": 150, "reference_mib_s": 100}],
    )


def add_provenance(path: Path) -> None:
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    write_csv(path, [row | {"input_sha256": "f" * 64} | PROVENANCE for row in rows])


def summary(payload: dict[str, object], codec: str, operation: str, profile: str) -> dict[str, object]:
    rows = payload["summaries"]
    assert isinstance(rows, list)
    return next(
        row for row in rows
        if isinstance(row, dict)
        and (row["codec"], row["operation"], row["profile"]) == (codec, operation, profile)
    )


def main() -> int:
    checks = 0
    with tempfile.TemporaryDirectory(prefix="vort-gap-smoke-") as temp_name:
        root = Path(temp_name)
        write_core_fixtures(root)
        markdown_path = root / "report.md"
        json_path = root / "report.json"

        result = run_report(root, markdown_path, json_path, "--strict")
        if result.returncode != 0:
            raise AssertionError(f"valid strict report failed: {result.stderr}")
        payload = json.loads(json_path.read_text(encoding="utf-8"))
        rendered = markdown_path.read_text(encoding="utf-8")
        assert payload["schema"] == "vort.competitor_gap_report"
        assert payload["schema_version"] == 2
        assert payload["coverage"]["loaded_sources"] == 8
        assert payload["coverage"]["missing_sources"] == 2
        assert payload["coverage"]["empty_sources"] == 0
        assert payload["coverage"]["real_corpus"] is False
        assert payload["coverage"]["benchmark_environment_recorded"] is False
        assert payload["coverage"]["benchmark_environment_source_count"] == 2
        assert payload["coverage"]["benchmark_environment_total_sources"] == 8
        zstd_input = next(item for item in payload["inputs"] if item["name"] == "zstd_encode")
        assert zstd_input["benchmark_provenance"] == PROVENANCE
        assert len(payload["inputs"][0]["sha256"]) == 64
        checks += 11

        deflate = summary(payload, "deflate", "encode", "zlib-best-speed")
        assert deflate["reference"] == "alpha-ref/beta-ref"
        assert deflate["priority_eligible"] is False
        assert deflate["status"] == "mixed"
        checks += 3

        zstd = summary(payload, "zstd", "encode", "level-1")
        assert math.isclose(float(zstd["speed_geomean_x"]), math.sqrt(1.6))
        assert math.isclose(float(zstd["weakest_speed_x"]), 0.8)
        assert zstd["weakest_speed_case"] == "beta"
        assert zstd["status"] == "mixed"
        assert math.isclose(float(zstd["priority_score"]), 1.25)
        checks += 5

        assert summary(payload, "zstd", "decode", "caller-buffer")["status"] == "ahead"
        assert summary(payload, "lz4", "decode", "block")["status"] == "ahead"
        assert summary(payload, "brotli", "encode", "q3-fast")["status"] == "mixed"
        assert summary(payload, "brotli", "encode", "q3-ratio")["status"] == "mixed"
        assert summary(payload, "brotli", "decode", "caller-buffer")["reference_version"] == "1.1.0"
        assert summary(payload, "zstd", "encode", "level-1")["reference_version"] == "1.5.5"
        assert summary(payload, "lz4", "decode", "block")["reference_version"] == "1.9.4"
        checks += 7

        assert "| zstd | encode | level-1 |" in rendered
        assert "Benchmark provenance: `2/8`" in rendered
        assert "ReleaseFast; zig 0.16.0; x86_64-linux-gnu" in rendered
        assert "`111111111111`" in rendered
        assert f"{float(zstd['speed_geomean_x']):.3f}x" in rendered
        assert len(payload["metrics"]) == payload["coverage"]["metric_count"]
        assert {row["input_sha256"] for row in payload["metrics"] if row["source"] == "zstd_encode"} == {"1" * 64, "2" * 64}
        ranking = rendered.split("## Highest-priority gaps", 1)[1].split("## Current weakest cases", 1)[0]
        assert "zlib-best-speed" not in ranking
        checks += 7

        for path in root.glob("*.csv"):
            add_provenance(path)
        result = run_report(root, markdown_path, json_path, "--strict")
        if result.returncode != 0:
            raise AssertionError(f"complete-provenance report failed: {result.stderr}")
        payload = json.loads(json_path.read_text(encoding="utf-8"))
        assert payload["coverage"]["benchmark_environment_recorded"] is True
        assert payload["coverage"]["benchmark_environment_source_count"] == 8
        assert payload["coverage"]["benchmark_environment_total_sources"] == 8
        checks += 3

        standard_path = root / "standard.csv"
        write_csv(
            standard_path,
            [{
                "corpus": "real-a", "input_bytes": 1000,
                "vort_zlib_fastest_bytes": 90, "vort_ms": 1, "vort_decode_ms": 1,
                "vort_zlib_default_bytes": 85, "vort_default_ms": 2, "vort_default_decode_ms": 2,
                "vort_zlib_best_bytes": 80, "vort_best_ms": 3, "vort_best_decode_ms": 3,
                "gzip_bytes": 100, "gzip_ms": 0, "gzip_decode_ms": 0,
                "zlib_ng_gzip_bytes": 0, "zlib_ng_ms": 2, "zlib_ng_decode_ms": 1,
                "zlib_rs_zlib_bytes": 0, "zlib_rs_ms": 0, "zlib_rs_decode_ms": 0,
                "zstd_bytes": 70, "zstd_ms": 1, "zstd_decode_ms": 1,
            }],
        )
        result = run_report(
            root, markdown_path, json_path, "--strict",
            "--standard-corpus", str(standard_path),
        )
        if result.returncode != 0:
            raise AssertionError(f"standard-corpus report failed: {result.stderr}")
        payload = json.loads(json_path.read_text(encoding="utf-8"))
        assert payload["coverage"]["real_corpus"] is True
        standard_metrics = [row for row in payload["metrics"] if row["source"] == "standard_corpus"]
        assert len(standard_metrics) == 18
        assert {row["reference"] for row in standard_metrics if row["metric"] == "compressed_size"} == {"gzip", "zstd"}
        assert {row["reference"] for row in standard_metrics if row["metric"] == "throughput"} == {"zlib-ng", "zstd"}
        assert {row["codec"] for row in standard_metrics} == {"deflate-family"}
        assert {row["profile"] for row in standard_metrics if row["metric"] == "compressed_size"} == {
            "zlib-fastest-vs-gzip-gzip",
            "zlib-default-vs-gzip-gzip",
            "zlib-best-vs-gzip-gzip",
            "zlib-fastest-vs-zstd-zstd",
            "zlib-default-vs-zstd-zstd",
            "zlib-best-vs-zstd-zstd",
        }
        assert {row["profile"] for row in standard_metrics if row["metric"] == "throughput"} == {
            "zlib-fastest-vs-zlib-ng-gzip",
            "zlib-default-vs-zlib-ng-gzip",
            "zlib-best-vs-zlib-ng-gzip",
            "zlib-fastest-vs-zstd-zstd",
            "zlib-default-vs-zstd-zstd",
            "zlib-best-vs-zstd-zstd",
        }
        checks += 7

        missing_core = root / "vort-snappy-reference-bench.csv"
        missing_core.unlink()
        result = run_report(root, markdown_path, json_path, "--strict")
        expect_failure(result, "missing required benchmark inputs: snappy")
        checks += 1
        write_core_fixtures(root)

        result = run_report(
            root, markdown_path, json_path,
            "--standard-corpus", str(root / "missing-standard.csv"),
        )
        expect_failure(result, "explicit benchmark inputs do not exist: standard_corpus")
        checks += 1

        invalid_dir = root / "invalid"
        invalid_dir.mkdir()
        invalid_path = invalid_dir / "zstd.csv"
        invalid_cases = [
            (
                [{"case": "alpha", "input_bytes": 1000}],
                "missing columns",
            ),
            (
                [
                    {"case": "alpha", "input_bytes": 1000, "input_sha256": "1" * 64, "reference_version": "1.5.5", "vort_mib_s": 1, "reference_mib_s": 1},
                    {"case": "alpha", "input_bytes": 1000, "input_sha256": "1" * 64, "reference_version": "1.5.5", "vort_mib_s": 2, "reference_mib_s": 1},
                ],
                "duplicate row",
            ),
            (
                [{"case": "alpha", "input_bytes": 1000, "input_sha256": "1" * 64, "reference_version": "1.5.5", "vort_mib_s": "nan", "reference_mib_s": 1}],
                "non-positive or non-finite",
            ),
            (
                [{"case": "alpha", "input_bytes": 1000, "input_sha256": "1" * 64, "reference_version": "1.5.5", "vort_mib_s": 0, "reference_mib_s": 1}],
                "non-positive or non-finite",
            ),
        ]
        for rows, expected in invalid_cases:
            write_csv(invalid_path, rows)
            result = run_report(
                invalid_dir, invalid_dir / "bad.md", invalid_dir / "bad.json",
                "--zstd-decode", str(invalid_path),
            )
            expect_failure(result, expected)
            checks += 1

        mismatch_path = invalid_dir / "deflate.csv"
        write_csv(
            mismatch_path,
            [
                {"engine": "vort-default", "format": "zlib", "case": "alpha", "input_bytes": 1000, "frame_bytes": 90, "throughput_mib_s": 100},
                {"engine": "reference", "format": "zlib", "case": "alpha", "input_bytes": 999, "frame_bytes": 100, "throughput_mib_s": 100},
            ],
        )
        result = run_report(
            invalid_dir, invalid_dir / "bad.md", invalid_dir / "bad.json",
            "--deflate-encode", str(mismatch_path),
        )
        expect_failure(result, "inconsistent input_bytes")
        checks += 1

        incomplete_provenance = invalid_dir / "incomplete-provenance.csv"
        write_csv(
            incomplete_provenance,
            [{"case": "alpha", "input_bytes": 1000, "input_sha256": "1" * 64, "reference_version": "1.5.5", "vort_mib_s": 1, "reference_mib_s": 1, "optimize": "ReleaseFast"}],
        )
        result = run_report(
            invalid_dir, invalid_dir / "bad.md", invalid_dir / "bad.json",
            "--zstd-decode", str(incomplete_provenance),
        )
        expect_failure(result, "incomplete benchmark provenance columns")
        checks += 1

        inconsistent_provenance = invalid_dir / "inconsistent-provenance.csv"
        write_csv(
            inconsistent_provenance,
            [
                {"case": "alpha", "input_bytes": 1000, "input_sha256": "1" * 64, "reference_version": "1.5.5", "vort_mib_s": 1, "reference_mib_s": 1} | PROVENANCE,
                {"case": "beta", "input_bytes": 1000, "input_sha256": "2" * 64, "reference_version": "1.5.5", "vort_mib_s": 1, "reference_mib_s": 1} | (PROVENANCE | {"cpu_affinity": "9"}),
            ],
        )
        result = run_report(
            invalid_dir, invalid_dir / "bad.md", invalid_dir / "bad.json",
            "--zstd-decode", str(inconsistent_provenance),
        )
        expect_failure(result, "inconsistent benchmark provenance across rows")
        checks += 1

        malformed_provenance = invalid_dir / "malformed-provenance.csv"
        write_csv(
            malformed_provenance,
            [{"case": "alpha", "input_bytes": 1000, "input_sha256": "1" * 64, "reference_version": "1.5.5", "vort_mib_s": 1, "reference_mib_s": 1} | (PROVENANCE | {"executable_sha256": "not-a-digest"})],
        )
        result = run_report(
            invalid_dir, invalid_dir / "bad.md", invalid_dir / "bad.json",
            "--zstd-decode", str(malformed_provenance),
        )
        expect_failure(result, "invalid executable_sha256")
        checks += 1

        invalid_input_hash = invalid_dir / "invalid-input-hash.csv"
        write_csv(
            invalid_input_hash,
            [{"case": "alpha", "input_bytes": 1000, "input_sha256": "bad", "reference_version": "1.5.5", "vort_mib_s": 1, "reference_mib_s": 1} | PROVENANCE],
        )
        result = run_report(
            invalid_dir, invalid_dir / "bad.md", invalid_dir / "bad.json",
            "--zstd-decode", str(invalid_input_hash),
        )
        expect_failure(result, "invalid input_sha256")
        checks += 1

        malformed_provenance_cases = (
            ({"provenance_version": "2"}, "unsupported benchmark provenance version"),
            ({"optimize": "Debug"}, "benchmark provenance is not ReleaseFast"),
            ({"affinity_cpu_count": "0"}, "affinity_cpu_count does not match cpu_affinity"),
            ({"affinity_cpu_count": "2"}, "affinity_cpu_count does not match cpu_affinity"),
            ({"cpu_affinity": "8-7"}, "invalid cpu_affinity"),
            ({"benchmark_threads": "0"}, "invalid benchmark_threads"),
            ({"command": "benchmark,--bad"}, "command is not CSV-safe"),
        )
        for override, expected in malformed_provenance_cases:
            path = invalid_dir / f"bad-{next(iter(override))}.csv"
            write_csv(
                path,
                [{"case": "alpha", "input_bytes": 1000, "input_sha256": "1" * 64, "reference_version": "1.5.5", "vort_mib_s": 1, "reference_mib_s": 1} | (PROVENANCE | override)],
            )
            result = run_report(
                invalid_dir, invalid_dir / "bad.md", invalid_dir / "bad.json",
                "--zstd-decode", str(path),
            )
            expect_failure(result, expected)
            checks += 1

        no_comparison_dir = root / "no-comparison"
        no_comparison_dir.mkdir()
        write_core_fixtures(no_comparison_dir)
        write_csv(
            no_comparison_dir / "vort-rust-deflate-encode-bench-repeat3.csv",
            [{"engine": "vort-default", "format": "zlib", "case": "alpha", "input_bytes": 1000, "frame_bytes": 90, "throughput_mib_s": 100}],
        )
        result = run_report(
            no_comparison_dir, no_comparison_dir / "bad.md",
            no_comparison_dir / "bad.json", "--strict",
        )
        expect_failure(result, "required benchmark inputs have no comparable rows: deflate_encode")
        checks += 1

        invalid_output_parent = root / "not-a-directory"
        invalid_output_parent.write_text("fixture", encoding="utf-8")
        result = run_report(
            root, invalid_output_parent / "report.md", root / "unused.json",
        )
        expect_failure(result, "competitor gap report failed:")
        assert "Traceback" not in result.stderr
        checks += 1

    print(f"competitor_gap_report_smoke=ok checks={checks}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
