#!/usr/bin/env python3
"""Retain a JSON artifact for the Zstd native stream summary CLI."""

from __future__ import annotations

import argparse
import json
import pathlib
import struct
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
DEFAULT_JSON = ROOT / "zig-out" / "vort-zstd-native-stream-summary.json"


def run_cli(cli: pathlib.Path, *args: str) -> str:
    return subprocess.run([str(cli), *args], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE).stdout.strip()


def skippable_frame(skippable_id: int, payload: bytes) -> bytes:
    if not 0 <= skippable_id <= 15:
        raise ValueError(skippable_id)
    return struct.pack("<II", 0x184D2A50 + skippable_id, len(payload)) + payload


def dictionary_id_raw_frame(dictionary_id: int, payload: bytes) -> bytes:
    if not 0 < dictionary_id <= 0xFF:
        raise ValueError(dictionary_id)
    if len(payload) > 0xFF:
        raise ValueError("fixture keeps a one-byte content-size field")
    block_header = (len(payload) << 3) | 1
    return (
        b"\x28\xb5\x2f\xfd"
        + bytes([0x21, dictionary_id, len(payload)])
        + struct.pack("<I", block_header)[:3]
        + payload
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cli", type=pathlib.Path)
    parser.add_argument("--json", default=DEFAULT_JSON, type=pathlib.Path)
    args = parser.parse_args()
    cli = args.cli.resolve()

    cache_dir = ROOT / ".zig-cache"
    cache_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="vort-zstd-summary-dashboard-", dir=cache_dir) as tmpdir:
        tmp = pathlib.Path(tmpdir)
        first_payload = b"dashboard zstd summary first"
        second_payload = b"dashboard zstd summary second"
        first_plain = tmp / "first.txt"
        second_plain = tmp / "second.txt"
        first_frame = tmp / "first.zst"
        second_frame = tmp / "second.zst"
        stream_path = tmp / "stream.zst"
        first_plain.write_bytes(first_payload)
        second_plain.write_bytes(second_payload)
        run_cli(cli, "encode-zstd-native-file", str(first_plain), str(first_frame), "raw_or_rle", "false", "true")
        run_cli(cli, "encode-zstd-native-file", str(second_plain), str(second_frame), "raw_or_rle", "true", "true")
        skip_payload = b"dashboard-zstd-summary"
        dict_payload = b"abc"
        stream_path.write_bytes(
            first_frame.read_bytes()
            + skippable_frame(6, skip_payload)
            + second_frame.read_bytes()
            + dictionary_id_raw_frame(7, dict_payload)
        )

        summary = json.loads(run_cli(cli, "summary-zstd-native-file", str(stream_path), "json"))
        if summary.get("schema") != "vort.zstd_native_stream_summary":
            raise AssertionError(f"unexpected summary schema: {summary!r}")
        expected = {
            "frame_count": 3,
            "skippable_frame_count": 1,
            "checksum_frame_count": 1,
            "dictionary_id_frame_count": 1,
            "content_size_frame_count": 3,
            "declared_content_bytes": len(first_payload) + len(second_payload) + len(dict_payload),
            "block_count": 3,
            "raw_block_count": 3,
            "rle_block_count": 0,
            "compressed_block_count": 0,
            "payload_bytes": len(first_payload) + len(second_payload) + len(dict_payload),
            "skippable_payload_bytes": len(skip_payload),
            "compressed_bytes": stream_path.stat().st_size,
        }
        for key, value in expected.items():
            if summary.get(key) != value:
                raise AssertionError(f"expected {key}={value}, got {summary.get(key)} in {summary!r}")

    args.json.parent.mkdir(parents=True, exist_ok=True)
    args.json.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "zstd_native_summary_dashboard=ok",
        f"frames={summary['frame_count']}",
        f"skippable_frames={summary['skippable_frame_count']}",
        f"path={args.json}",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
