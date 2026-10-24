#!/usr/bin/env python3
"""Verify ordinary public output against independently authored fdeflate bits."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zlib


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--producer", required=True, type=Path)
    parser.add_argument("--fixtures", type=Path, default=Path("/nav_env/Temp/vort-png-incremental-ultrafast-reference/stream-fixtures.jsonl"))
    parser.add_argument("--output-dir", type=Path, default=Path("/nav_env/Temp/vort-png-ultrafast-proof/reference"))
    args = parser.parse_args()
    output = args.output_dir.resolve()
    if not output.is_relative_to(Path("/nav_env/Temp").resolve()):
        raise ValueError("verification artifacts must remain in Temp")
    output.mkdir(parents=True, exist_ok=True)
    fixture_bytes = args.fixtures.read_bytes()
    rows = [json.loads(line) for line in fixture_bytes.splitlines()]
    if len(rows) != 544:
        raise ValueError("reference corpus drift")
    results = []
    for index, row in enumerate(rows):
        source = bytes.fromhex(row["source_hex"])
        expected = bytes.fromhex(row["stream_expected_hex"])
        input_path = output / "input.bin"
        input_path.write_bytes(source)
        modes = [(max(1, len(source)), 4096, None)]
        if row["group"] != "nonzero_single_literal":
            modes += [(1, 1, None), (7, 2, None), (257, 7, None), (4096, 128, None)]
        if index < 12 or row["group"] == "cross_input_boundary":
            if source:
                modes += [(1, 1, max(1, len(source) // 2))]
        for partition, capacity, flush_at in modes:
            path = output / "actual.zlib"
            command = [str(args.producer.resolve()), str(input_path), str(path), str(partition), str(capacity)]
            if flush_at is not None:
                command.append(str(flush_at))
            process = subprocess.run(command, text=True, capture_output=True)
            if process.returncode:
                raise ValueError(f"producer failed: {command}\n{process.stdout}\n{process.stderr}")
            actual = path.read_bytes()
            decoder = zlib.decompressobj()
            decoded = decoder.decompress(actual) + decoder.flush()
            if decoded != source or not decoder.eof or decoder.unused_data or decoder.unconsumed_tail:
                raise ValueError(f"independent zlib mismatch: {row['id']}")
            if flush_at is None:
                if actual != expected:
                    raise ValueError(f"independent fdeflate EOB-framing byte mismatch: {row['id']} {partition}/{capacity}")
            else:
                prefix = path.with_suffix(path.suffix + ".flush").read_bytes()
                accepted = int(path.with_suffix(path.suffix + ".accepted").read_text())
                decoder = zlib.decompressobj()
                if decoder.decompress(prefix) != source[:accepted] or decoder.eof or decoder.unused_data:
                    raise ValueError(f"sync flush publication mismatch: {row['id']}")
            results.append({"case": row["id"], "partition": partition, "capacity": capacity, "flush_at": flush_at,
                            "output_sha256": digest(actual), "independent_zlib": True,
                            "independent_fdeflate_framing_exact": flush_at is None})
    report = {"schema": "vort.png_incremental_ultrafast_differential.v1", "cases": len(rows), "checks": len(results),
              "fixture_sha256": digest(fixture_bytes), "producer_sha256": digest(args.producer.read_bytes()),
              "zlib_runtime_version": zlib.ZLIB_RUNTIME_VERSION, "zlib_compile_version": zlib.ZLIB_VERSION,
              "expected_model": "single-full-write pinned fdeflate with RFC1951 EOB-bit framing conversion",
              "native_expected_generated": False, "results": results}
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"png_incremental_ultrafast_reference=pass cases={len(rows)} checks={len(results)} fixture_sha256={digest(fixture_bytes)}")


if __name__ == "__main__":
    main()
