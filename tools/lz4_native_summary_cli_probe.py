#!/usr/bin/env python3
"""Black-box smoke for the LZ4 native stream summary CLI."""

from __future__ import annotations

import json
import pathlib
import subprocess
import sys
import tempfile

from lz4_native_summary_fixtures import dictionary_id_raw_frame, skippable_frame

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


def require_fields(actual: dict[str, int], expected: dict[str, int], context: str) -> None:
    for key, value in expected.items():
        if actual.get(key) != value:
            raise AssertionError(f"{context}: expected {key}={value}, got {actual.get(key)} in {actual}")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: lz4_native_summary_cli_probe.py <vort-cli>")
    cli = pathlib.Path(sys.argv[1]).resolve()
    cache_dir = ROOT / ".zig-cache"
    cache_dir.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="vort-lz4-summary-cli-", dir=cache_dir) as tmpdir:
        tmp = pathlib.Path(tmpdir)
        first_payload = b"lz4 summary first payload"
        second_payload = b"lz4 summary second payload"
        first_plain = tmp / "first.txt"
        second_plain = tmp / "second.txt"
        first_frame = tmp / "first.lz4"
        second_frame = tmp / "second.lz4"
        stream_path = tmp / "stream.lz4"
        first_plain.write_bytes(first_payload)
        second_plain.write_bytes(second_payload)

        run_cli(cli, "encode-lz4-native-file", str(first_plain), str(first_frame))
        single_summary = parse_fields(run_cli(cli, "summary-lz4-native-file", str(first_frame)))
        require_fields(
            single_summary,
            {
                "frames": 1,
                "skippable_frames": 0,
                "content_size_frames": 1,
                "checksum_frames": 1,
                "block_checksum_frames": 0,
                "dictionary_id_frames": 0,
                "declared_content_bytes": len(first_payload),
                "blocks": 1,
                "raw_blocks": 1,
                "compressed_blocks": 0,
                "payload_bytes": len(first_payload),
                "skippable_payload_bytes": 0,
            },
            "single-frame summary",
        )
        single_json = json.loads(run_cli(cli, "summary-lz4-native-file", str(first_frame), "json"))
        assert single_json["schema"] == "vort.lz4_native_stream_summary"
        assert single_json["schema_version"] == 1
        assert single_json["compressed_bytes"] == single_summary["lz4_native_compressed_bytes"]
        assert single_json["frame_count"] == single_summary["frames"]
        assert single_json["content_size_frame_count"] == 1
        assert single_json["checksum_frame_count"] == 1
        assert single_json["block_checksum_frame_count"] == 0
        assert single_json["dictionary_id_frame_count"] == 0
        assert single_json["declared_content_bytes"] == len(first_payload)
        assert single_json["raw_block_count"] == 1

        run_cli(cli, "encode-lz4-native-file", str(second_plain), str(second_frame))
        skip_a = b"lz4 summary metadata a"
        skip_b = b"lz4 summary metadata bb"
        dict_payload = b"abc"
        stream_path.write_bytes(
            first_frame.read_bytes()
            + skippable_frame(4, skip_a)
            + skippable_frame(13, skip_b)
            + second_frame.read_bytes()
            + dictionary_id_raw_frame(0x1234_ABCD, dict_payload)
        )
        stream_summary = parse_fields(run_cli(cli, "summary-lz4-native-file", str(stream_path)))
        require_fields(
            stream_summary,
            {
                "frames": 3,
                "skippable_frames": 2,
                "content_size_frames": 3,
                "checksum_frames": 2,
                "block_checksum_frames": 0,
                "dictionary_id_frames": 1,
                "declared_content_bytes": len(first_payload) + len(second_payload) + len(dict_payload),
                "blocks": 3,
                "raw_blocks": 3,
                "compressed_blocks": 0,
                "payload_bytes": len(first_payload) + len(second_payload) + len(dict_payload),
                "skippable_payload_bytes": len(skip_a) + len(skip_b),
            },
            "concatenated/skippable summary",
        )
        if stream_summary["lz4_native_compressed_bytes"] != stream_path.stat().st_size:
            raise AssertionError(f"summary compressed size mismatch: {stream_summary}")
        stream_json = json.loads(run_cli(cli, "summary-lz4-native-file", str(stream_path), "json"))
        assert stream_json["schema"] == "vort.lz4_native_stream_summary"
        assert stream_json["compressed_bytes"] == stream_summary["lz4_native_compressed_bytes"]
        assert stream_json["frame_count"] == stream_summary["frames"]
        assert stream_json["skippable_frame_count"] == stream_summary["skippable_frames"]
        assert stream_json["content_size_frame_count"] == stream_summary["content_size_frames"]
        assert stream_json["checksum_frame_count"] == stream_summary["checksum_frames"]
        assert stream_json["block_checksum_frame_count"] == stream_summary["block_checksum_frames"]
        assert stream_json["dictionary_id_frame_count"] == stream_summary["dictionary_id_frames"]
        assert stream_json["declared_content_bytes"] == stream_summary["declared_content_bytes"]
        assert stream_json["skippable_payload_bytes"] == stream_summary["skippable_payload_bytes"]

    print("lz4_native_summary_cli_probe=ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
