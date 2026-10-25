#!/usr/bin/env python3
"""Validate old/new Deflate64 requested-allocation probe reports, without running or compiling codecs."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path


NAMES = ("empty", "tiny16", "pattern12079", "random4097", "random16387", "repeat65539", "distant131072")
SIZES = (0, 16, 12079, 4097, 16387, 65539, 131072)


def require(condition: bool, context: object) -> None:
    if not condition:
        raise AssertionError(context)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def random_bytes(length: int, seed: int) -> bytes:
    data = bytearray()
    state = seed
    for _ in range(length):
        state = (state * 1_664_525 + 1_013_904_223) & 0xFFFFFFFF
        data.append(state >> 24)
    return bytes(data)


def fixture(name: str) -> bytes:
    if name == "empty":
        return b""
    if name == "tiny16":
        return b"D64 tiny16 data\n"
    if name == "pattern12079":
        text = b"Deflate64 bounded index capacity pattern.\n"
        return (text * ((12079 + len(text) - 1) // len(text)))[:12079]
    if name == "random4097":
        return random_bytes(4097, 0xD6402026)
    if name == "random16387":
        return random_bytes(16387, 0xD6402026)
    if name == "repeat65539":
        return b"Q" * 65539
    if name == "distant131072":
        block = random_bytes(65536, 0x65362026)
        return block + block
    raise AssertionError(name)


def check_memory(row: dict, clean: bool, context: str) -> None:
    require(all(isinstance(value, int) and value >= 0 for value in row.values()), (context, "memory counters"))
    require(row["current_requested_bytes"] <= row["peak_requested_bytes"], (context, "live exceeds peak"))
    require(row["successful_allocations"] <= row["allocation_attempts"] and
            row["successful_resizes"] <= row["resize_attempts"] and
            row["successful_remaps"] <= row["remap_attempts"], (context, "operation successes"))
    require(row["growth_requested_bytes"] >= row["released_requested_bytes"] and
            row["growth_requested_bytes"] - row["released_requested_bytes"] == row["current_requested_bytes"],
            (context, "requested byte conservation"))
    if clean:
        require(row["current_requested_bytes"] == 0 and row["live_allocations"] == 0 and
                row["free_calls"] == row["successful_allocations"], (context, "codec cleanup"))


def check_allocations(events: list[dict], memory: dict, context: str) -> None:
    require(len(events) == memory["allocation_attempts"], (context, "complete allocator event list"))
    successful = [row for row in events if row["succeeded"] is True]
    require(len(successful) == memory["successful_allocations"] and
            sum(row["bytes"] for row in successful) == memory["successful_allocation_requested_bytes"],
            (context, "allocation event sums"))


def check_timing(row: dict | None, context: str) -> None:
    if row is None:
        return
    rounds = row["rounds_ns"]
    require(row["iterations"] > 0 and len(rounds) == 5 and all(isinstance(ns, int) and ns >= 0 for ns in rounds),
            (context, "five actual timing rounds"))
    require(row["minimum_ns"] == min(rounds) and row["median_ns"] == sorted(rounds)[2],
            (context, "timing summary"))


def validate(report: dict, label: str) -> None:
    require(report["schema"] == "vort.deflate64.index-resources.v1", (label, "schema"))
    require(tuple(row["name"] for row in report["one_shot"]) == NAMES, (label, "case matrix"))
    require(report["codec_options"] == {"max_chain": 128, "nice_length": 128}, (label, "common default options"))
    for row, size in zip(report["one_shot"], SIZES):
        expected = fixture(row["name"])
        require(len(expected) == size and row["input_bytes"] == size and row["input_sha256"] == digest(expected),
                (label, row["name"], "deterministic input identity"))
        bound = size + 5 * max(1, (size + 65534) // 65535)
        require(row["roundtrip_verified"] is True and row["encoded_bound"] == bound and
                0 < row["wire_bytes"] <= bound and len(row["wire_sha256"]) == 64,
                (label, row["name"], "codec output and bound"))
        check_memory(row["memory_at_return"], False, f"{label}/{row['name']}/return")
        require(row["memory_at_return"]["current_requested_bytes"] >= row["wire_bytes"],
                (label, row["name"], "returned wire accounted"))
        check_memory(row["memory_after_free"], True, f"{label}/{row['name']}/free")
        check_allocations(row["codec_allocations"], row["memory_after_free"], f"{label}/{row['name']}")
        require(row["cleanup_failure_checks"] == min(3, row["memory_after_free"]["allocation_attempts"]),
                (label, row["name"], "actual selected allocation failure checks"))
        check_timing(row["timing"], f"{label}/{row['name']}")
    stream = report["streaming"]
    text = b"Deflate64 reused input block for 4MiB bounded streaming.\n"
    block = (text * ((4096 + len(text) - 1) // len(text)))[:4096]
    hasher = hashlib.sha256()
    for _ in range(1024):
        hasher.update(block)
    require(stream["input_bytes"] == 4 * 1024 * 1024 and stream["input_sha256"] == hasher.hexdigest() and
            stream["reused_input_block_bytes"] == 4096 and stream["block_len"] == 4096,
            (label, "reused stream input identity"))
    require(stream["roundtrip_verified"] is True and stream["wire_bytes"] > 0 and
            len(stream["wire_sha256"]) == 64 and stream["steps"] > 0 and stream["cleanup_failure_checks"] == 3,
            (label, "stream result/cleanup"))
    check_memory(stream["init_memory"], True, f"{label}/stream/init")
    require(stream["init_memory"]["allocation_attempts"] == 0, (label, "lazy stream initialization"))
    check_memory(stream["memory_before_deinit"], False, f"{label}/stream/retained")
    check_memory(stream["memory_after_deinit"], True, f"{label}/stream/deinit")
    check_allocations(stream["codec_allocations"], stream["memory_after_deinit"], f"{label}/stream")
    require(stream["maximum_heads_entries"] == 32768 and stream["maximum_previous_entries"] == 65536 and
            0 < stream["first_output_input_offset"] <= stream["input_bytes"], (label, "complete history geometry"))
    previous = 0
    for checkpoint in stream["checkpoints"]:
        check_memory(checkpoint["memory"], False, f"{label}/stream/checkpoint")
        capacity = checkpoint["previous_entries"]
        require(checkpoint["heads_entries"] == 32768 and capacity > 0 and capacity & (capacity - 1) == 0 and
                previous < capacity <= 65536 and checkpoint["input_read"] <= stream["input_bytes"],
                (label, "index growth checkpoint"))
        previous = capacity
    require(previous == stream["maximum_previous_entries"], (label, "last observed index capacity"))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--old", type=Path, required=True)
    parser.add_argument("--new", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    old_bytes, new_bytes = args.old.read_bytes(), args.new.read_bytes()
    old, new = json.loads(old_bytes), json.loads(new_bytes)
    validate(old, "old")
    validate(new, "new")
    changes = []
    for before, after in zip(old["one_shot"], new["one_shot"]):
        for field in ("name", "input_bytes", "input_sha256", "wire_bytes", "wire_sha256", "encoded_bound"):
            require(before[field] == after[field], (before["name"], field, "old/new public behavior"))
        changes.append({"case": before["name"], "input_bytes": before["input_bytes"],
                        "wire_bytes": before["wire_bytes"], "wire_sha256": before["wire_sha256"],
                        "old_peak_requested_bytes": before["memory_at_return"]["peak_requested_bytes"],
                        "new_peak_requested_bytes": after["memory_at_return"]["peak_requested_bytes"],
                        "old_allocations": before["codec_allocations"], "new_allocations": after["codec_allocations"]})
    for field in ("input_bytes", "input_sha256", "wire_bytes", "wire_sha256"):
        require(old["streaming"][field] == new["streaming"][field], (field, "old/new streamed public behavior"))
    result = {"schema": "vort.deflate64.index-resources-comparison.v1",
              "created_utc": datetime.now(timezone.utc).isoformat(),
              "old_report": {"path": str(args.old), "sha256": digest(old_bytes), "provenance": old["provenance"]},
              "new_report": {"path": str(args.new), "sha256": digest(new_bytes), "provenance": new["provenance"]},
              "metric": "codec peak requested live allocation bytes including output; not RSS or whole-process memory",
              "remap_metric_limit": "logical API owned bytes only; rawRemap backing allocator physical transients are unobservable",
              "wire_identity_equal": True, "cleanup_verified": True, "one_shot": changes,
              "streaming": {"old": old["streaming"], "new": new["streaming"]},
              "timing_scope": "timings are preserved in original reports; this gate does not establish isolation or make speed claims"}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"report": str(args.report), "one_shot_cases": len(changes), "wire_identity_equal": True}))


if __name__ == "__main__":
    main()
