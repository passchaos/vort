#!/usr/bin/env python3
"""Retain structured native-summary error diagnostics for dashboard review."""

from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import struct
import tempfile
from collections import Counter

from lz4_native_summary_fixtures import frame_descriptor_checksum, skippable_frame

ROOT = pathlib.Path(__file__).resolve().parents[1]
DEFAULT_JSON = ROOT / "zig-out" / "vort-native-summary-error-dashboard.json"


def run_error(cli: pathlib.Path, command: str, path: pathlib.Path) -> dict[str, object]:
    result = subprocess.run([str(cli), command, str(path), "json"], cwd=ROOT, check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if result.returncode == 0:
        raise AssertionError(f"{command} unexpectedly succeeded for {path}: {result.stdout!r}")
    payload = json.loads(result.stdout)
    if payload.get("ok") is not False:
        raise AssertionError(f"{command} did not emit a failing summary payload: {payload!r}")
    return payload



def lz4_frame(flg: int, block_header: int, payload: bytes, tail: bytes = b"") -> bytes:
    descriptor = bytes([flg, 0x40])
    return (
        struct.pack("<I", 0x184D2204)
        + descriptor
        + bytes([frame_descriptor_checksum(descriptor)])
        + struct.pack("<I", block_header)
        + payload
        + tail
    )


def zstd_frame(descriptor: int, content_size: int, block_header: int, payload: bytes, tail: bytes = b"") -> bytes:
    return b"\x28\xb5\x2f\xfd" + bytes([descriptor, content_size]) + struct.pack("<I", block_header)[:3] + payload + tail


def build_summary(cases: list[dict[str, object]]) -> dict[str, object]:
    error_counts = Counter(str(case["error"]) for case in cases)
    phase_counts = Counter(str(case["phase"]) for case in cases)
    lz4_error_counts = Counter(str(case["error"]) for case in cases if case.get("codec") == "lz4")
    zstd_error_counts = Counter(str(case["error"]) for case in cases if case.get("codec") == "zstd")
    lz4_phase_counts = Counter(str(case["phase"]) for case in cases if case.get("codec") == "lz4")
    zstd_phase_counts = Counter(str(case["phase"]) for case in cases if case.get("codec") == "zstd")
    offsets = [int(case["offset"]) for case in cases]
    lz4_offsets = [int(case["offset"]) for case in cases if case.get("codec") == "lz4"]
    zstd_offsets = [int(case["offset"]) for case in cases if case.get("codec") == "zstd"]
    phase_offset_ranges: dict[str, dict[str, int]] = {}
    for phase in sorted(phase_counts):
        phase_offsets = [int(case["offset"]) for case in cases if str(case["phase"]) == phase]
        phase_offset_ranges[phase] = {"min": min(phase_offsets), "max": max(phase_offsets)}
    return {
        "schema": "vort.native_summary_error_dashboard",
        "schema_version": 1,
        "ok": True,
        "case_count": len(cases),
        "lz4_case_count": sum(1 for case in cases if case["codec"] == "lz4"),
        "zstd_case_count": sum(1 for case in cases if case["codec"] == "zstd"),
        "error_counts": dict(sorted(error_counts.items())),
        "phase_counts": dict(sorted(phase_counts.items())),
        "lz4_error_counts": dict(sorted(lz4_error_counts.items())),
        "zstd_error_counts": dict(sorted(zstd_error_counts.items())),
        "lz4_phase_counts": dict(sorted(lz4_phase_counts.items())),
        "zstd_phase_counts": dict(sorted(zstd_phase_counts.items())),
        "offset_min": min(offsets) if offsets else 0,
        "offset_max": max(offsets) if offsets else 0,
        "lz4_offset_min": min(lz4_offsets) if lz4_offsets else 0,
        "lz4_offset_max": max(lz4_offsets) if lz4_offsets else 0,
        "zstd_offset_min": min(zstd_offsets) if zstd_offsets else 0,
        "zstd_offset_max": max(zstd_offsets) if zstd_offsets else 0,
        "phase_offset_ranges": phase_offset_ranges,
        "cases": cases,
    }


def validate_summary(summary: dict[str, object]) -> None:
    cases = summary.get("cases")
    if not isinstance(cases, list):
        raise AssertionError("cases must be a list")
    expected = build_summary([case for case in cases if isinstance(case, dict)])
    for key in ("case_count", "lz4_case_count", "zstd_case_count", "error_counts", "phase_counts", "lz4_error_counts", "zstd_error_counts", "lz4_phase_counts", "zstd_phase_counts", "offset_min", "offset_max", "lz4_offset_min", "lz4_offset_max", "zstd_offset_min", "zstd_offset_max", "phase_offset_ranges"):
        if summary.get(key) != expected[key]:
            raise AssertionError(f"{key} mismatch: expected {expected[key]!r}, got {summary.get(key)!r}")
    if summary.get("ok") is not True:
        raise AssertionError("summary ok must be true")

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cli", type=pathlib.Path)
    parser.add_argument("--json", default=DEFAULT_JSON, type=pathlib.Path)
    args = parser.parse_args()
    cli = args.cli.resolve()

    cache_dir = ROOT / ".zig-cache"
    cache_dir.mkdir(parents=True, exist_ok=True)
    cases: list[dict[str, object]] = []
    with tempfile.TemporaryDirectory(prefix="vort-native-summary-errors-", dir=cache_dir) as tmpdir:
        tmp = pathlib.Path(tmpdir)
        fixtures = [
            ("lz4_bad_magic", "lz4", "summary-lz4-native-file", b"not-lz4", "CorruptFrame", "magic"),
            ("lz4_truncated_header", "lz4", "summary-lz4-native-file", bytes([0x04, 0x22, 0x4D, 0x18, 0x60]), "TruncatedFrame", "frame_header"),
            ("lz4_truncated_skippable", "lz4", "summary-lz4-native-file", skippable_frame(2, b"metadata")[:-3], "TruncatedFrame", "skippable_payload"),
            ("lz4_header_checksum", "lz4", "summary-lz4-native-file", lz4_frame(0x60, 0, b"")[:6] + bytes([lz4_frame(0x60, 0, b"")[6] ^ 0x01]) + b"\x00\x00\x00\x00", "ChecksumMismatch", "frame_header"),
            ("lz4_truncated_body", "lz4", "summary-lz4-native-file", lz4_frame(0x60, 0x8000_0000 | 4, b"ab"), "TruncatedFrame", "frame_body"),
            ("lz4_truncated_checksum", "lz4", "summary-lz4-native-file", lz4_frame(0x64, 0x8000_0000 | 3, b"abc", b"\x00\x00\x00\x00\x00\x00"), "TruncatedFrame", "frame_checksum"),
            ("lz4_invalid_block_header", "lz4", "summary-lz4-native-file", lz4_frame(0x60, 0x8000_0000 | (64 * 1024 + 1), b""), "CorruptFrame", "frame"),
            ("zstd_bad_magic", "zstd", "summary-zstd-native-file", b"not-zstd", "InvalidMagic", "magic"),
            ("zstd_truncated_header", "zstd", "summary-zstd-native-file", b"\x28\xb5\x2f", "TruncatedFrame", "magic"),
            ("zstd_truncated_skippable", "zstd", "summary-zstd-native-file", skippable_frame(2, b"metadata")[:-3], "TruncatedFrame", "skippable_payload"),
            ("zstd_reserved_descriptor", "zstd", "summary-zstd-native-file", b"\x28\xb5\x2f\xfd\x28", "CorruptFrame", "frame_header"),
            ("zstd_truncated_body", "zstd", "summary-zstd-native-file", zstd_frame(0x20, 4, (4 << 3) | 1, b"ab"), "TruncatedFrame", "frame_body"),
            ("zstd_truncated_checksum", "zstd", "summary-zstd-native-file", zstd_frame(0x24, 3, (3 << 3) | 1, b"abc", b"\x00\x00"), "TruncatedFrame", "frame_checksum"),
            ("zstd_invalid_block_header", "zstd", "summary-zstd-native-file", zstd_frame(0x20, 0, (0 << 3) | (3 << 1) | 1, b""), "CorruptFrame", "frame"),
        ]
        for name, codec, command, data, expected_error, expected_phase in fixtures:
            path = tmp / f"{name}.bin"
            path.write_bytes(data)
            payload = run_error(cli, command, path)
            if payload.get("error") != expected_error or payload.get("phase") != expected_phase:
                raise AssertionError(f"{name}: expected {expected_error}/{expected_phase}, got {payload!r}")
            cases.append({"name": name, "codec": codec, **payload})

    summary = build_summary(cases)
    validate_summary(summary)
    args.json.parent.mkdir(parents=True, exist_ok=True)
    args.json.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("native_summary_error_dashboard=ok", f"cases={summary['case_count']}", f"path={args.json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
