#!/usr/bin/env python3
"""Retain a JSON artifact for the LZ4 native stream summary CLI."""

from __future__ import annotations

import argparse
import json
import pathlib
import struct
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
DEFAULT_JSON = ROOT / "zig-out" / "vort-lz4-native-stream-summary.json"


def run_cli(cli: pathlib.Path, *args: str) -> str:
    return subprocess.run([str(cli), *args], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE).stdout.strip()


def skippable_frame(skippable_id: int, payload: bytes) -> bytes:
    if not 0 <= skippable_id <= 15:
        raise ValueError(skippable_id)
    return struct.pack("<II", 0x184D2A50 + skippable_id, len(payload)) + payload


def descriptor_checksum(descriptor: bytes) -> int:
    # LZ4 frame header checksums use the second byte of XXH32(seed=0).  Python's
    # stdlib has no XXH32, so this fixture keeps the checksum literal local and
    # verifies below that Vort accepts it.  For descriptor bytes:
    #   FLG=0x69 (independent, content-size, Dictionary_ID)
    #   BD=0x40  (64 KiB max block)
    #   content size=3
    #   dictionary ID=0x1234abcd
    # the checksum is 0x19.
    expected_descriptor = b"\x69\x40\x03\x00\x00\x00\x00\x00\x00\x00\xcd\xab\x34\x12"
    if descriptor != expected_descriptor:
        raise ValueError(f"unexpected LZ4 dictionary fixture descriptor: {descriptor.hex()}")
    return 0x19


def dictionary_id_raw_frame(dictionary_id: int, payload: bytes) -> bytes:
    if not 0 < dictionary_id <= 0xFFFF_FFFF:
        raise ValueError(dictionary_id)
    if len(payload) > 0xFFFF_FFFF:
        raise ValueError("fixture payload too large")
    descriptor = (
        b"\x69\x40"
        + struct.pack("<Q", len(payload))
        + struct.pack("<I", dictionary_id)
    )
    return (
        struct.pack("<I", 0x184D2204)
        + descriptor
        + bytes([descriptor_checksum(descriptor)])
        + struct.pack("<I", 0x8000_0000 | len(payload))
        + payload
        + b"\x00\x00\x00\x00"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cli", type=pathlib.Path)
    parser.add_argument("--json", default=DEFAULT_JSON, type=pathlib.Path)
    args = parser.parse_args()
    cli = args.cli.resolve()

    cache_dir = ROOT / ".zig-cache"
    cache_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="vort-lz4-summary-dashboard-", dir=cache_dir) as tmpdir:
        tmp = pathlib.Path(tmpdir)
        first_payload = b"dashboard lz4 summary first"
        second_payload = b"dashboard lz4 summary second"
        first_plain = tmp / "first.txt"
        second_plain = tmp / "second.txt"
        first_frame = tmp / "first.lz4"
        second_frame = tmp / "second.lz4"
        stream_path = tmp / "stream.lz4"
        first_plain.write_bytes(first_payload)
        second_plain.write_bytes(second_payload)
        run_cli(cli, "encode-lz4-native-file", str(first_plain), str(first_frame))
        run_cli(cli, "encode-lz4-native-file", str(second_plain), str(second_frame))
        skip_payload = b"dashboard-lz4-summary"
        dict_payload = b"abc"
        stream_path.write_bytes(
            first_frame.read_bytes()
            + skippable_frame(6, skip_payload)
            + second_frame.read_bytes()
            + dictionary_id_raw_frame(0x1234_ABCD, dict_payload)
        )

        summary = json.loads(run_cli(cli, "summary-lz4-native-file", str(stream_path), "json"))
        if summary.get("schema") != "vort.lz4_native_stream_summary":
            raise AssertionError(f"unexpected summary schema: {summary!r}")
        expected = {
            "frame_count": 3,
            "skippable_frame_count": 1,
            "content_size_frame_count": 3,
            "checksum_frame_count": 2,
            "block_checksum_frame_count": 0,
            "dictionary_id_frame_count": 1,
            "declared_content_bytes": len(first_payload) + len(second_payload) + len(dict_payload),
            "block_count": 3,
            "raw_block_count": 3,
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
        "lz4_native_summary_dashboard=ok",
        f"frames={summary['frame_count']}",
        f"skippable_frames={summary['skippable_frame_count']}",
        f"path={args.json}",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
