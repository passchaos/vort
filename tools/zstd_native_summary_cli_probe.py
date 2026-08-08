#!/usr/bin/env python3
"""Black-box smoke for the Zstd native stream summary CLI."""

from __future__ import annotations

import pathlib
import json
import struct
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]


def run_cli(cli: pathlib.Path, *args: str) -> str:
    return subprocess.run([str(cli), *args], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE).stdout.strip()


def parse_fields(output: str) -> dict[str, int]:
    fields: dict[str, int] = {}
    for token in output.split():
        if "=" not in token:
            continue
        key, value = token.split("=", 1)
        fields[key] = int(value)
    return fields


def skippable_frame(skippable_id: int, payload: bytes) -> bytes:
    if not 0 <= skippable_id <= 15:
        raise ValueError(skippable_id)
    return struct.pack("<II", 0x184D2A50 + skippable_id, len(payload)) + payload


def require_fields(actual: dict[str, int], expected: dict[str, int], context: str) -> None:
    for key, value in expected.items():
        if actual.get(key) != value:
            raise AssertionError(f"{context}: expected {key}={value}, got {actual.get(key)} in {actual}")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: zstd_native_summary_cli_probe.py <vort-cli>")
    cli = pathlib.Path(sys.argv[1]).resolve()
    cache_dir = ROOT / ".zig-cache"
    cache_dir.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="vort-zstd-summary-cli-", dir=cache_dir) as tmpdir:
        tmp = pathlib.Path(tmpdir)
        first_payload = b"zstd summary first payload"
        second_payload = b"zstd summary second payload"
        first_plain = tmp / "first.txt"
        second_plain = tmp / "second.txt"
        first_frame = tmp / "first.zst"
        second_frame = tmp / "second.zst"
        stream_path = tmp / "stream.zst"
        first_plain.write_bytes(first_payload)
        second_plain.write_bytes(second_payload)

        run_cli(cli, "encode-zstd-native-file", str(first_plain), str(first_frame), "raw_or_rle", "false", "true")
        single_summary = parse_fields(run_cli(cli, "summary-zstd-native-file", str(first_frame)))
        require_fields(
            single_summary,
            {
                "frames": 1,
                "skippable_frames": 0,
                "blocks": 1,
                "raw_blocks": 1,
                "rle_blocks": 0,
                "compressed_blocks": 0,
                "payload_bytes": len(first_payload),
                "skippable_payload_bytes": 0,
            },
            "single-frame summary",
        )
        single_json = json.loads(run_cli(cli, "summary-zstd-native-file", str(first_frame), "json"))
        assert single_json["schema"] == "vort.zstd_native_stream_summary"
        assert single_json["schema_version"] == 1
        assert single_json["compressed_bytes"] == single_summary["zstd_native_compressed_bytes"]
        assert single_json["frame_count"] == single_summary["frames"]
        assert single_json["skippable_frame_count"] == 0
        assert single_json["raw_block_count"] == 1

        run_cli(cli, "encode-zstd-native-file", str(second_plain), str(second_frame), "raw_or_rle", "false", "true")
        skip_a = b"summary metadata a"
        skip_b = b"summary metadata bb"
        stream_path.write_bytes(
            first_frame.read_bytes()
            + skippable_frame(3, skip_a)
            + skippable_frame(12, skip_b)
            + second_frame.read_bytes()
        )
        stream_summary = parse_fields(run_cli(cli, "summary-zstd-native-file", str(stream_path)))
        require_fields(
            stream_summary,
            {
                "frames": 2,
                "skippable_frames": 2,
                "blocks": 2,
                "raw_blocks": 2,
                "rle_blocks": 0,
                "compressed_blocks": 0,
                "payload_bytes": len(first_payload) + len(second_payload),
                "skippable_payload_bytes": len(skip_a) + len(skip_b),
            },
            "concatenated/skippable summary",
        )
        if stream_summary["zstd_native_compressed_bytes"] != stream_path.stat().st_size:
            raise AssertionError(f"summary compressed size mismatch: {stream_summary}")
        stream_json = json.loads(run_cli(cli, "summary-zstd-native-file", str(stream_path), "json"))
        assert stream_json["schema"] == "vort.zstd_native_stream_summary"
        assert stream_json["compressed_bytes"] == stream_summary["zstd_native_compressed_bytes"]
        assert stream_json["frame_count"] == stream_summary["frames"]
        assert stream_json["skippable_frame_count"] == stream_summary["skippable_frames"]
        assert stream_json["skippable_payload_bytes"] == stream_summary["skippable_payload_bytes"]

    print("zstd_native_summary_cli_probe=ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
