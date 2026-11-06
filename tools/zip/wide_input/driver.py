#!/usr/bin/env python3
"""Independently validate real ZIP64 wide input with bounded decompression.

--long generates and checks 4294967313 actual 'R' bytes per member. Only the
compressed ZIP, probe logs and JSON evidence are retained; no plaintext file or
seeded counter substitutes for the generated and independently decoded bytes.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import struct
import subprocess
import sys
import time
import zlib

sys.dont_write_bytecode = True
from codec_oracle import CHUNK, decode_deflate, decode_zstd
from zip_structure import inspect_zip, require

DEFAULT_COUNT = 65553
LONG_COUNT = (1 << 32) + 17
RECEIPT_SCHEMA = "vort.zip.wide-input.v1"


def sha_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(CHUNK):
            digest.update(chunk)
    return digest.hexdigest()


def write_json(path: Path, value: dict) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")
    temporary.replace(path)


def cpu_model() -> str:
    cpuinfo = Path("/proc/cpuinfo")
    if cpuinfo.exists():
        for line in cpuinfo.read_text().splitlines():
            if line.startswith("model name") or line.startswith("Hardware"):
                return line.partition(":")[2].strip()
    return platform.processor() or platform.machine()


def integer(receipt: dict, key: str, upper: int = (1 << 64) - 1) -> int:
    value = receipt.get(key)
    require(type(value) is int and 0 <= value <= upper, f"probe {key} must be an unsigned integer")
    return value


def parse_receipt(path: Path) -> dict:
    # Probe stdout is one JSON line; accepting the last line also permits a
    # small diagnostic preamble without retaining arbitrary stdout in memory.
    with path.open("rb") as source:
        size = path.stat().st_size
        source.seek(max(0, size - CHUNK))
        lines = source.read(CHUNK).splitlines()
    require(bool(lines), "probe omitted its stdout receipt")
    receipt = json.loads(lines[-1])
    require(isinstance(receipt, dict), "probe receipt is not a JSON object")
    return receipt


def validate_receipt(receipt: dict, format_name: str, bits: int, count: int,
                     archive_size: int) -> None:
    require(receipt.get("schema") == RECEIPT_SCHEMA, "probe receipt schema mismatch")
    require(receipt.get("format") == format_name, "probe receipt format mismatch")
    require(integer(receipt, "pointer_bits", 64) == bits, "probe pointer width mismatch")
    require(receipt.get("completed") is True, "probe did not complete")
    for key in ("count", "input_read", "uncompressed_size"):
        require(integer(receipt, key) == count, f"probe {key} differs from requested actual bytes")
    require(integer(receipt, "output_written") == archive_size, "probe archive byte receipt mismatch")
    require(integer(receipt, "compressed_size") > 0, "probe compressed size is zero")
    integer(receipt, "crc32", (1 << 32) - 1)
    require(integer(receipt, "input_chunk_bytes") == CHUNK and
            integer(receipt, "output_chunk_bytes") == CHUNK, "probe chunk bounds mismatch")
    require(integer(receipt, "calls") > 0, "probe performed no incremental calls")


def invoke(args, label: str, probe: Path, bits: int, format_name: str, count: int) -> dict:
    name = f"{label}-{format_name}"
    archive_path = args.output_dir / f"{name}.zip"
    stdout_path = args.output_dir / f"{name}.stdout.log"
    stderr_path = args.output_dir / f"{name}.stderr.log"
    partial_path = args.output_dir / f"{name}.partial.json"
    result_path = args.output_dir / f"{name}.result.json"
    command = [str(probe), "--format", format_name, "--count", str(count),
               "--output", str(archive_path)]
    archive_path.unlink(missing_ok=True)
    result_path.unlink(missing_ok=True)
    started = time.monotonic()
    base = dict(name=name, command=command, count=count, pointer_bits=bits,
                archive_path=str(archive_path), stdout_log=str(stdout_path),
                stderr_log=str(stderr_path))
    write_json(partial_path, dict(base, status="generating"))
    print(json.dumps(dict(case=name, status="generating", count=count)), flush=True)
    with stdout_path.open("wb") as stdout, stderr_path.open("wb") as stderr:
        process = subprocess.run(command, stdout=stdout, stderr=stderr, check=False)
    require(process.returncode == 0,
            f"probe {name} exited {process.returncode}; see {stderr_path}")
    require(archive_path.is_file(), f"probe {name} omitted its archive")
    probe_seconds = time.monotonic() - started
    receipt = parse_receipt(stdout_path)
    validate_receipt(receipt, format_name, bits, count, archive_path.stat().st_size)
    metadata = inspect_zip(archive_path, format_name, count)
    require(receipt["compressed_size"] == metadata.compressed_size and
            receipt["crc32"] == metadata.crc32, "probe/ZIP compressed size or CRC mismatch")

    def progress(oracle_receipt):
        event = dict(base, status="decoding", probe_receipt=receipt,
                     oracle_receipt=oracle_receipt)
        write_json(partial_path, event)
        print(json.dumps(dict(case=name, status="decoding", **oracle_receipt)), flush=True)

    progress(dict(output_written=0, crc32=0, calls=0))
    decode_started = time.monotonic()
    decoder = decode_deflate if format_name == "deflate" else decode_zstd
    oracle = decoder(archive_path, metadata, progress)
    require(oracle["input_read"] == receipt["compressed_size"] and
            oracle["output_written"] == receipt["input_read"] and
            oracle["crc32"] == receipt["crc32"], "independent oracle/probe receipts differ")
    actual_long = receipt["input_read"] > 1 << 32 and oracle["output_written"] > 1 << 32
    if args.long:
        require(actual_long, "--long did not generate and decode more than 4 GiB")
    event = dict(base, status="ok", exit_code=process.returncode,
                 format=format_name, probe_receipt=receipt, metadata=metadata.report(),
                 oracle=oracle, probe_sha256=sha_file(probe),
                 archive_sha256=sha_file(archive_path),
                 probe_seconds=probe_seconds, oracle_seconds=time.monotonic() - decode_started,
                 actual_input_exceeds_4g=receipt["input_read"] > 1 << 32,
                 actual_decoded_output_exceeds_4g=oracle["output_written"] > 1 << 32,
                 long_proof=args.long and actual_long)
    write_json(result_path, event)
    with (args.output_dir / "events.jsonl").open("a") as log:
        log.write(json.dumps(event) + "\n")
    partial_path.unlink(missing_ok=True)
    print(json.dumps(dict(case=name, status="ok", pointer_bits=bits,
                          input_read=receipt["input_read"], compressed_size=metadata.compressed_size,
                          crc32=oracle["crc32"])), flush=True)
    return event


def build_info(value: str | None) -> dict | None:
    if value is None:
        return None
    text = Path(value[1:]).read_text() if value.startswith("@") else value
    parsed = json.loads(text)
    require(isinstance(parsed, dict), "--build-info must be a JSON object or @JSON-file")
    return parsed


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe-native", type=Path, required=True)
    parser.add_argument("--probe-x86", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    lengths = parser.add_mutually_exclusive_group()
    lengths.add_argument("--long", action="store_true")
    lengths.add_argument("--count", type=int, help="short/custom smoke count; use --long for the long gate")
    parser.add_argument("--only", choices=("all", "deflate", "zstd"), default="all")
    parser.add_argument("--build-info", help="optional JSON object or @JSON-file with build/target details")
    args = parser.parse_args()
    count = LONG_COUNT if args.long else args.count if args.count is not None else DEFAULT_COUNT
    require(0 <= count < 1 << 64, "count must fit u64")
    supplied_build_info = build_info(args.build_info)
    args.output_dir = args.output_dir.resolve()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    report_path = args.output_dir / "report.json"
    report_path.unlink(missing_ok=True)
    probes = [("native", args.probe_native.resolve(), struct.calcsize("P") * 8)]
    if args.probe_x86:
        probes.append(("x86", args.probe_x86.resolve(), 32))
    for label, probe, _bits in probes:
        require(probe.is_file(), f"{label} probe does not exist: {probe}")
    formats = ("deflate", "zstd") if args.only == "all" else (args.only,)
    events = [invoke(args, label, probe, bits, format_name, count)
              for label, probe, bits in probes for format_name in formats]
    comparisons = {}
    if args.probe_x86:
        by_name = {event["name"]: event for event in events}
        comparisons = {format_name: by_name[f"native-{format_name}"]["archive_sha256"] ==
                       by_name[f"x86-{format_name}"]["archive_sha256"]
                       for format_name in formats}
    report = dict(
        schema="vort.zip.wide-input-gate.v1", status="ok",
        utc=datetime.now(timezone.utc).isoformat(),
        actual_command=[sys.executable, *sys.argv], count=count, long=args.long,
        long_proof=args.long and all(event["long_proof"] for event in events),
        only=args.only, cases=len(events), events=events,
        source_chunk_bytes=CHUNK, output_chunk_bytes=CHUNK,
        archive_collection=True, plaintext_collection=False, counter_seeding=False,
        native_x86_archive_comparisons=comparisons, build_info=supplied_build_info,
        environment=dict(python_version=sys.version, platform=platform.platform(),
                         machine=platform.machine(), cpu_model=cpu_model(),
                         pointer_bits=struct.calcsize("P") * 8,
                         zlib_compile_version=zlib.ZLIB_VERSION,
                         zlib_runtime_version=zlib.ZLIB_RUNTIME_VERSION),
        tool_sha256={name: sha_file(Path(__file__).with_name(name))
                     for name in ("driver.py", "zip_structure.py", "codec_oracle.py")},
    )
    write_json(report_path, report)
    print(json.dumps(dict(status="ok", cases=len(events), count=count,
                          long_proof=report["long_proof"], report=str(report_path))), flush=True)


if __name__ == "__main__":
    main()
