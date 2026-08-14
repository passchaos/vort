#!/usr/bin/env python3
"""Retain a JSON artifact for the LZ4 native stream summary CLI."""

from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import tempfile

from lz4_native_summary_fixtures import dictionary_id_raw_frame, skippable_frame

ROOT = pathlib.Path(__file__).resolve().parents[1]
DEFAULT_JSON = ROOT / "zig-out" / "vort-lz4-native-stream-summary.json"


def run_cli(cli: pathlib.Path, *args: str) -> str:
    return subprocess.run([str(cli), *args], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE).stdout.strip()


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
            "block_checksum_frame_count": 1,
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
