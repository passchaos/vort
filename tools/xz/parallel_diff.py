#!/usr/bin/env python3
"""Bounded XZ block-parallel functional QA. No compiler or timer is launched."""
from __future__ import annotations

import argparse
import binascii
import ctypes as C
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import re
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
CHECKS = {"none": 0, "crc32": 1, "crc64": 4, "sha256": 10}
CHECK_BYTES = {0: 0, 1: 4, 4: 8, 10: 32}
FILTER_IDS = {"delta": 3, "x86": 4, "powerpc": 5, "ia64": 6, "arm": 7,
              "arm_thumb": 8, "sparc": 9, "arm64": 10, "riscv": 11}


def require(value, context):
    if not value:
        raise AssertionError(context)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def identity(path):
    path = Path(path)
    body = path.read_bytes()
    return {"path": str(path), "bytes": len(body), "sha256": digest(body)}


def crc32(data):
    return (binascii.crc32(data) & 0xFFFFFFFF).to_bytes(4, "little")


class LzmaOptions(C.Structure):
    # Exact public lzma_options_lzma layout from the selected 5.8.4 header.
    _fields_ = [("dict_size", C.c_uint32), ("preset_dict", C.c_void_p), ("preset_dict_size", C.c_uint32),
                ("lc", C.c_uint32), ("lp", C.c_uint32), ("pb", C.c_uint32), ("mode", C.c_int),
                ("nice_len", C.c_uint32), ("mf", C.c_int), ("depth", C.c_uint32),
                ("ext_flags", C.c_uint32), ("ext_size_low", C.c_uint32), ("ext_size_high", C.c_uint32),
                ("reserved_int4", C.c_uint32), ("reserved_int5", C.c_uint32), ("reserved_int6", C.c_uint32),
                ("reserved_int7", C.c_uint32), ("reserved_int8", C.c_uint32),
                ("reserved_enum1", C.c_int), ("reserved_enum2", C.c_int), ("reserved_enum3", C.c_int),
                ("reserved_enum4", C.c_int), ("reserved_ptr1", C.c_void_p), ("reserved_ptr2", C.c_void_p)]


class DeltaOptions(C.Structure):
    _fields_ = [("type", C.c_int), ("dist", C.c_uint32), ("reserved_int1", C.c_uint32),
                ("reserved_int2", C.c_uint32), ("reserved_int3", C.c_uint32), ("reserved_int4", C.c_uint32),
                ("reserved_ptr1", C.c_void_p), ("reserved_ptr2", C.c_void_p)]


class BcjOptions(C.Structure):
    _fields_ = [("start_offset", C.c_uint32)]


class Filter(C.Structure):
    _fields_ = [("id", C.c_uint64), ("options", C.c_void_p)]


class Reference:
    def __init__(self, library, headers):
        self.library_path = library.resolve()
        self.headers = headers.resolve()
        self.lib = C.CDLL(str(self.library_path))
        def bind(name, result, *args):
            fn = getattr(self.lib, name)
            fn.restype, fn.argtypes = result, args
            return fn
        size, ptr = C.c_size_t, C.c_void_p
        self.version = bind("lzma_version_string", C.c_char_p)().decode()
        self.version_number = bind("lzma_version_number", C.c_uint32)()
        self.bound = bind("lzma_stream_buffer_bound", size, size)
        self.preset = bind("lzma_lzma_preset", C.c_uint8, C.POINTER(LzmaOptions), C.c_uint32)
        self.encode_fn = bind("lzma_stream_buffer_encode", C.c_int, C.POINTER(Filter), C.c_int, ptr,
                              ptr, size, ptr, C.POINTER(size), size)
        self.decode_fn = bind("lzma_stream_buffer_decode", C.c_int, C.POINTER(C.c_uint64), C.c_uint32,
                              ptr, ptr, C.POINTER(size), size, ptr, C.POINTER(size), size)
        self.support_filter = bind("lzma_filter_encoder_is_supported", C.c_uint8, C.c_uint64)
        self.support_check = bind("lzma_check_is_supported", C.c_uint8, C.c_int)

    def describe(self):
        class DlInfo(C.Structure):
            _fields_ = [("name", C.c_char_p), ("base", C.c_void_p), ("symbol", C.c_char_p), ("address", C.c_void_p)]
        fn = C.CDLL(None).dladdr
        fn.restype, fn.argtypes = C.c_int, (C.c_void_p, C.POINTER(DlInfo))
        info = DlInfo()
        require(fn(C.cast(self.decode_fn, C.c_void_p), C.byref(info)) and info.name, "liblzma symbol provenance")
        path = Path(info.name.decode()).resolve()
        require(path == self.library_path, "requested liblzma file differs from symbol owner")
        return {"library": identity(path), "version": self.version, "version_number": self.version_number,
                "headers": [identity(self.headers / "lzma.h"), *[identity(self.headers / "lzma" / name)
                                                               for name in ("version.h", "lzma12.h", "filter.h", "bcj.h", "delta.h", "container.h")]],
                "supported_checks": {name: bool(self.support_check(value)) for name, value in CHECKS.items()},
                "supported_filters": {name: bool(self.support_filter(value)) for name, value in FILTER_IDS.items()},
                "abi_scope": "ctypes layout follows selected public lzma_options_lzma/filter/delta/bcj headers"}

    def encode(self, payload, check="crc64", filters=()):
        lzma = LzmaOptions()
        require(not self.preset(C.byref(lzma), 0), "liblzma preset initialization")
        lzma.dict_size = 4096
        keep = [lzma]
        descriptors = []
        for row in filters:
            kind, parameter = row["kind"], row["parameter"]
            require(self.support_filter(FILTER_IDS[kind]), ("reference filter unsupported", kind))
            options = DeltaOptions(0, parameter) if kind == "delta" else BcjOptions(parameter)
            keep.append(options)
            descriptors.append(Filter(FILTER_IDS[kind], C.addressof(options)))
        descriptors.extend((Filter(0x21, C.addressof(lzma)), Filter((1 << 64) - 1, None)))
        chain = (Filter * len(descriptors))(*descriptors)
        capacity = self.bound(len(payload))
        output = C.create_string_buffer(b"\xa5" * (capacity + 16), capacity + 16)
        position = C.c_size_t()
        status = self.encode_fn(chain, CHECKS[check], None, payload, len(payload), C.byref(output, 8), C.byref(position), capacity)
        require(status == 0 and position.value <= capacity, ("reference XZ encode", status))
        require(output.raw[:8] == b"\xa5" * 8 and output.raw[-8:] == b"\xa5" * 8, "reference encoder guards")
        return output.raw[8:8 + position.value]

    def decode(self, wire, expected):
        capacity = len(expected) + 1
        output = C.create_string_buffer(b"\xa5" * (capacity + 16), capacity + 16)
        input_pos, output_pos, memory = C.c_size_t(), C.c_size_t(), C.c_uint64((1 << 64) - 1)
        status = self.decode_fn(C.byref(memory), 0, None, wire, C.byref(input_pos), len(wire),
                                C.byref(output, 8), C.byref(output_pos), capacity)
        require(output.raw[:8] == b"\xa5" * 8 and output.raw[-8:] == b"\xa5" * 8, "reference decoder guards")
        actual = output.raw[8:8 + output_pos.value]
        return {"status": status, "input_read": input_pos.value, "output_written": output_pos.value,
                "output_sha256": digest(actual), "caller_guards_verified": True,
                "complete_contents_verified": status == 0 and input_pos.value == len(wire) and actual == expected}


def vli(data, offset, limit):
    value = 0
    for index in range(9):
        require(offset < limit, "truncated XZ VLI")
        byte = data[offset]
        offset += 1
        value |= (byte & 127) << (index * 7)
        if not byte & 128:
            require(index == 0 or byte != 0, "noncanonical XZ VLI")
            return value, offset
    raise AssertionError("invalid XZ VLI width")


def scan_lzma2(data, offset, limit):
    start, unpacked, chunks = offset, 0, []
    while True:
        require(offset < limit, "truncated LZMA2 control")
        chunk_start, control = offset, data[offset]
        offset += 1
        if control == 0:
            break
        require(control in (1, 2) or control >= 128, "reserved LZMA2 control")
        if control <= 2:
            require(offset + 2 <= limit, "truncated stored LZMA2 header")
            plain = int.from_bytes(data[offset:offset + 2], "big") + 1
            encoded = plain
            offset += 2
        else:
            require(offset + 4 + int(control >= 192) <= limit, "truncated compressed LZMA2 header")
            plain = ((control & 31) << 16) + int.from_bytes(data[offset:offset + 2], "big") + 1
            encoded = int.from_bytes(data[offset + 2:offset + 4], "big") + 1
            offset += 4
            if control >= 192:
                require(data[offset] < 225, "invalid LZMA2 property")
                offset += 1
        require(offset + encoded <= limit, "truncated LZMA2 payload")
        offset += encoded
        unpacked += plain
        chunks.append({"start_byte": chunk_start, "control": control, "decoded_bytes": plain,
                       "encoded_payload_bytes": encoded, "end_byte": offset})
    return {"start_byte": start, "end_byte": offset, "serialized_bytes": offset - start,
            "decoded_bytes": unpacked, "chunks": chunks}


def inspect(wire):
    require(len(wire) >= 32 and wire[:6] == b"\xfd7zXZ\x00" and wire[-2:] == b"YZ", "XZ stream magic")
    flags = wire[6:8]
    require(flags[0] == 0 and flags[1] & 240 == 0 and flags[1] in CHECK_BYTES, "XZ stream flags/check")
    require(wire[8:12] == crc32(flags), "XZ stream header CRC")
    footer = wire[-12:]
    require(footer[:4] == crc32(footer[4:10]) and footer[8:10] == flags, "XZ stream footer CRC/flags")
    index_bytes = (int.from_bytes(footer[4:8], "little") + 1) * 4
    index_start = len(wire) - 12 - index_bytes
    require(12 <= index_start < len(wire) - 12 and wire[index_start] == 0, "XZ Index bounds")
    index_end = len(wire) - 16
    require(wire[index_end:index_end + 4] == crc32(wire[index_start:index_end]), "XZ Index CRC")
    count, cursor = vli(wire, index_start + 1, index_end)
    records = []
    for _ in range(count):
        unpadded, cursor = vli(wire, cursor, index_end)
        unpacked, cursor = vli(wire, cursor, index_end)
        records.append((unpadded, unpacked))
    require(all(byte == 0 for byte in wire[cursor:index_end]), "XZ Index padding")
    blocks, position, plain_start = [], 12, 0
    for index, (unpadded, expected_plain) in enumerate(records):
        start = position
        require(position < index_start and wire[position] != 0, "XZ block header bounds")
        header_bytes = (wire[position] + 1) * 4
        header_end = position + header_bytes
        require(header_end <= index_start and header_bytes >= 8 and wire[header_end - 4:header_end] == crc32(wire[start:header_end - 4]), "XZ block header CRC")
        block_flags, cursor = wire[start + 1], start + 2
        require(block_flags & 60 == 0, "reserved XZ block flags")
        compressed_field = uncompressed_field = None
        if block_flags & 64:
            compressed_field, cursor = vli(wire, cursor, header_end - 4)
        if block_flags & 128:
            uncompressed_field, cursor = vli(wire, cursor, header_end - 4)
        filters = []
        for _ in range((block_flags & 3) + 1):
            identifier, cursor = vli(wire, cursor, header_end - 4)
            property_bytes, cursor = vli(wire, cursor, header_end - 4)
            require(cursor + property_bytes <= header_end - 4, "XZ filter property bounds")
            filters.append({"id": identifier, "properties_hex": wire[cursor:cursor + property_bytes].hex()})
            cursor += property_bytes
        require(filters[-1]["id"] == 0x21 and all(byte == 0 for byte in wire[cursor:header_end - 4]), "XZ terminal LZMA2 filter/header padding")
        payload = scan_lzma2(wire, header_end, index_start)
        require(payload["decoded_bytes"] == expected_plain, "XZ block decoded size versus Index")
        padding = (-payload["serialized_bytes"]) % 4
        require(all(byte == 0 for byte in wire[payload["end_byte"]:payload["end_byte"] + padding]), "XZ block padding")
        position = payload["end_byte"] + padding + CHECK_BYTES[flags[1]]
        require(header_bytes + payload["serialized_bytes"] + CHECK_BYTES[flags[1]] == unpadded and position <= index_start,
                "XZ block unpadded Index extent")
        require(compressed_field is None or compressed_field == payload["serialized_bytes"], "XZ declared compressed size")
        require(uncompressed_field is None or uncompressed_field == expected_plain, "XZ declared plain size")
        blocks.append({"index": index, "start_byte": start, "header_bytes": header_bytes, "filters": filters,
                       "payload": payload, "check_bytes": CHECK_BYTES[flags[1]], "padding_bytes": padding,
                       "unpadded_bytes": unpadded, "decoded_start": plain_start, "decoded_bytes": expected_plain, "end_byte": position})
        plain_start += expected_plain
    require(position == index_start, "XZ block sequence meets Index exactly")
    return {"check_id": flags[1], "block_count": len(blocks), "blocks": blocks, "decoded_bytes": plain_start,
            "index_start_byte": index_start, "index_bytes": index_bytes, "serialized_bytes": len(wire),
            "scope": "independent header/Block/LZMA2 packet/Index/footer extents and CRCs; selected check/full plaintext verified by liblzma"}


def deterministic(length, seed=0x5A5A1026):
    result = bytearray()
    for _ in range(length):
        seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF
        result.append(seed >> 24)
    return bytes(result)


def fixtures():
    source = b"pub fn parallelXZ(input: []const u8) !void { return ordered(input); }\n"
    instructions = bytes.fromhex("e80000000090e9f0ffffff") * 1800
    return {"empty": b"", "tiny": b"XZ bounded parallel\x00\xff", "repeat": (b"XZ parallel block ordering and credit lifetime.\n" * 1500)[:50001],
            "random": deterministic(50001), "source": (source * 1000)[:50001], "binary": instructions[:18001],
            "boundary4095": deterministic(4095), "boundary4096": deterministic(4096), "boundary4097": deterministic(4097),
            "bytecap": deterministic(3000), "tiny3000": deterministic(3000)}


def matrix():
    for case in ("empty", "tiny", "repeat", "random"):
        for check in CHECKS:
            for parser in ("greedy", "lazy"):
                for workers in (1, 3):
                    yield case, {"check": check, "parser": parser, "worker_count": workers}, "base"
    for api in ("alloc", "append", "into"):
        for payload in ("compressed", "stored"):
            yield "repeat", {"api": api, "payload": payload, "compare_serial_incremental": True}, "public-output"
        yield "source", {"api": api, "lazy_entry": True, "compare_serial_incremental": True}, "lazy-entry"
    for kind in FILTER_IDS:
        parameter = 7 if kind == "delta" else 16
        yield "binary", {"filters": [{"kind": kind, "parameter": parameter}], "check": "sha256"}, "filter"
    yield "binary", {"filters": [{"kind": "delta", "parameter": 3}, {"kind": "x86", "parameter": 16}], "check": "crc32"}, "filter-chain"
    for parser, finder in (("fast", "hc4"), ("normal", "bt4"), ("literal_only", "hc3")):
        yield "source", {"parser": parser, "match_options": {"finder": finder, "nice_len": 32, "depth": 8}}, "advanced-parser"
    for case in ("boundary4095", "boundary4096", "boundary4097"):
        yield case, {"max_inflight_bytes": 4096, "max_inflight_blocks": 2, "compare_serial_incremental": True}, "block-boundary"
    for api in ("append", "into"):
        yield "repeat", {"api": api, "alias": True}, "alias"
    yield "repeat", {"api": "into", "short_output": True}, "short-output"
    for field, value in (("worker_count", 0), ("worker_count", 65), ("max_inflight_blocks", 0), ("max_inflight_bytes", 0)):
        yield "tiny", {field: value}, "invalid-options"
    yield "bytecap", {"max_inflight_bytes": 2999}, "actual-block-bytecap"
    yield "tiny3000", {"block_size": 4096, "max_inflight_bytes": 3000}, "actual-single-block-credit"
    yield "repeat", {"max_inflight_blocks": 1, "max_inflight_bytes": 4096}, "single-credit"
    yield "repeat", {"max_working_memory": 0}, "zero-memory"
    yield "source", {"parallel": False}, "null-parallel-legacy"
    for api in ("append", "into"):
        yield "repeat", {"api": api, "max_working_memory": 0}, "zero-memory"
        yield "repeat", {"api": api, "max_inflight_bytes": 4095}, "actual-block-bytecap"
    yield "tiny3000", {"payload": "stored", "worker_count": 1}, "deterministic-budget-base"


def source_identity():
    paths = [ROOT / "src/xz.zig", ROOT / "src/core.zig", ROOT / "src/lzma.zig", ROOT / "src/lzma2.zig",
             ROOT / "src/bitstream.zig", ROOT / "src/checksum.zig",
             ROOT / "tools/xz/parallel_probe.zig", Path(__file__).resolve()]
    for folder in ("xz", "lzma", "io", "checksum"):
        paths += sorted((ROOT / "src" / folder).rglob("*.zig"))
    rows = [{"path": str(path.relative_to(ROOT)), "sha256": digest(path.read_bytes())} for path in paths if path.exists()]
    return {"files": rows, "sha256": digest(json.dumps(rows, sort_keys=True).encode())}


def self_check(reference):
    for check in CHECKS:
        for payload in (b"", b"tiny reference", deterministic(4097)):
            wire = reference.encode(payload, check)
            parsed = inspect(wire)
            require(parsed["decoded_bytes"] == len(payload) and parsed["check_id"] == CHECKS[check] and
                    reference.decode(wire, payload)["complete_contents_verified"], "reference stream self-check")
    for kind in FILTER_IDS:
        payload = fixtures()["binary"]
        wire = reference.encode(payload, filters=[{"kind": kind, "parameter": 7 if kind == "delta" else 16}])
        require(reference.decode(wire, payload)["complete_contents_verified"] and inspect(wire)["decoded_bytes"] == len(payload), "filter reference self-check")
    return {"matrix_cases": len(list(matrix())), "filter_count": len(FILTER_IDS), "check_count": len(CHECKS)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", type=Path)
    parser.add_argument("--directory", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--source-epoch", default="unspecified")
    parser.add_argument("--reference", type=Path, default=Path("/tmp/vort-xz-ref.vVVDxq/build/liblzma.so.5.8.4"))
    parser.add_argument("--reference-headers", type=Path, default=Path("/tmp/vort-xz-ref.vVVDxq/xz/src/liblzma/api"))
    parser.add_argument("--self-check", action="store_true")
    args = parser.parse_args()
    reference = Reference(args.reference, args.reference_headers)
    checks = self_check(reference)
    if args.self_check:
        print(json.dumps({"self_check": "passed", "matrix": checks, "reference": reference.describe()}))
        return
    require(args.probe and args.directory, "--probe and --directory are required")
    probe, directory = args.probe.resolve(), args.directory.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    source_before = source_identity()
    inputs = fixtures()
    for name, payload in inputs.items():
        (directory / (name + ".input")).write_bytes(payload)
    results, failures, commands = [], [], []
    def run(name, c, input_path, output_path):
        config = directory / (name + ".json")
        config.write_text(json.dumps(c, indent=2) + "\n")
        command = [str(probe), str(input_path), str(output_path), str(config)]
        process = subprocess.run(command, capture_output=True, check=False, timeout=120)
        stdout, stderr = directory / (name + ".stdout"), directory / (name + ".stderr")
        stdout.write_bytes(process.stdout)
        stderr.write_bytes(process.stderr)
        commands.append({"command": command, "exit_code": process.returncode, "stdout": identity(stdout), "stderr": identity(stderr)})
        require(process.returncode == 0, (name, "probe exit", process.returncode, process.stderr.decode(errors="replace")))
        return json.loads(process.stdout)
    for index, (case, overrides, scope) in enumerate(matrix()):
        name = f"encode-{index:03d}-{case}-{scope}"
        c = {"operation": "encode", "api": "alloc", "block_size": 4096, "chunk_size": 4096, "dictionary_size": 4096,
             "worker_count": 3, "max_inflight_blocks": 4, "max_inflight_bytes": 4 * 1024 * 1024,
             "max_working_memory": 256 * 1024 * 1024, **overrides}
        payload = inputs[case]
        path = directory / (name + ".xz")
        record = {"name": name, "scope": scope, "settings": c, "input": identity(directory / (case + ".input"))}
        try:
            row = run(name, c, directory / (case + ".input"), path)
            record["probe"] = row
            expected_error = {"short-output": "OutputTooSmall", "invalid-options": "InvalidBlockPlan",
                              "actual-block-bytecap": "WorkingMemoryLimitExceeded", "zero-memory": "WorkingMemoryLimitExceeded"}.get(scope)
            if expected_error:
                require(row["error"] == expected_error, (name, "exact rejection", row))
                if c["api"] in ("append", "into"):
                    require(row["caller_preserved_on_error"], "failed publication must preserve caller buffer")
                record["expected_error"] = expected_error
            else:
                require(row["error"] is None and row["serial_wire_equal"] and row["self_decode_verified"] and row["caller_guards_verified"], (name, row))
                wire = path.read_bytes()
                require(row["input_sha256"] == digest(payload) and row["output_sha256"] == digest(wire) and row["output_bytes"] == len(wire), "probe wire/input identity")
                serial = Path(str(path) + ".serial.xz")
                require(serial.read_bytes() == wire and row["serial_sha256"] == digest(wire), "complete serial wire parity")
                parsed = inspect(wire)
                require(parsed["decoded_bytes"] == len(payload), "independent decoded extent")
                expected_blocks = 0 if not payload else (len(payload) + c["block_size"] - 1) // c["block_size"]
                require(parsed["block_count"] == expected_blocks, "block boundaries unchanged")
                profile = row["parallel_profile"]
                require(profile["live_requested_bytes"] == 0 and profile["peak_requested_bytes"] <= c["max_working_memory"] and
                        profile["peak_inflight_blocks"] <= c["max_inflight_blocks"] and
                        profile["peak_inflight_bytes"] <= c["max_inflight_bytes"], "parallel credits/requested heap bounds")
                if c.get("parallel", True) and (c["worker_count"] == 1 or expected_blocks <= 1):
                    require(profile["serial_fallback"], "worker1/empty/single-block serial fallback identity")
                if c.get("parallel", True) and c["worker_count"] > 1 and expected_blocks > 1 and not profile["serial_fallback"]:
                    require(profile["workers_started"] > 1 and profile["completed_blocks"] == expected_blocks and
                            profile["published_blocks"] == expected_blocks, "actual multiple workers and ordered publication")
                if c.get("compare_serial_incremental"):
                    require(row["serial_incremental_equal"], "unchanged serial incremental same-boundary parity")
                external = reference.decode(wire, payload)
                require(external["complete_contents_verified"], (name, "full independent plaintext", external))
                record.update({"wire": identity(path), "serial_wire": identity(serial), "independent_wire": parsed,
                               "reference_decode": external})
            record["status"] = "passed"
        except (AssertionError, OSError, json.JSONDecodeError) as error:
            record.update({"status": "failed", "failure": str(error)})
            failures.append({"name": name, "failure": str(error)})
        results.append(record)
    budget_base = next((row for row in results if row["scope"] == "deterministic-budget-base"), None)
    budget_checks = 0
    if budget_base is not None and budget_base["status"] == "passed":
        peak = budget_base["probe"]["parallel_profile"]["peak_requested_bytes"]
        if peak == 0:
            failures.append({"name": "requested-memory-proof", "failure": "fallback did not record a nonzero requested-memory peak"})
            peak = 1
        for label, limit, error in (("exact", peak, None), ("below", peak - 1, "WorkingMemoryLimitExceeded")):
            name = "deterministic-budget-" + label
            c = {**budget_base["settings"], "max_working_memory": limit}
            input_path, path = directory / "tiny3000.input", directory / (name + ".xz")
            entry = {"name": name, "scope": "exact-memory-boundary", "settings": c, "baseline_requested_peak": peak}
            try:
                row = run(name, c, input_path, path)
                entry["probe"] = row
                require(row["error"] == error, (name, "exact requested-memory boundary", row))
                if error is None:
                    wire = path.read_bytes()
                    require(row["serial_wire_equal"] and row["parallel_profile"]["peak_requested_bytes"] <= limit and
                            reference.decode(wire, inputs["tiny3000"])["complete_contents_verified"], "exact budget preserves full wire")
                    entry["wire"] = identity(path)
                    entry["independent_wire"] = inspect(wire)
                entry["status"] = "passed"
            except (AssertionError, OSError, json.JSONDecodeError) as failure:
                entry.update({"status": "failed", "failure": str(failure)})
                failures.append({"name": name, "failure": str(failure)})
            results.append(entry)
            budget_checks += 1
    reference_cases = [("tiny", check, []) for check in CHECKS]
    reference_cases += [("binary", "crc64", [{"kind": kind, "parameter": 7 if kind == "delta" else 16}]) for kind in FILTER_IDS]
    for index, (case, check, filters) in enumerate(reference_cases):
        name = f"decode-reference-{index:03d}"
        payload = inputs[case]
        wire = reference.encode(payload, check, filters)
        path, output = directory / (name + ".xz"), directory / (name + ".decoded")
        path.write_bytes(wire)
        record = {"name": name, "scope": "reference-to-target", "wire": identity(path), "independent_wire": inspect(wire)}
        try:
            row = run(name, {"operation": "decode", "parallel": False, "max_output_len": len(payload)}, path, output)
            require(row["error"] is None and output.read_bytes() == payload and row["output_sha256"] == digest(payload), "target reference decode")
            record.update({"probe": row, "status": "passed"})
        except (AssertionError, OSError, json.JSONDecodeError) as error:
            record.update({"status": "failed", "failure": str(error)})
            failures.append({"name": name, "failure": str(error)})
        results.append(record)
    source_after = source_identity()
    active = [row["probe"]["parallel_profile"]["peak_active_workers"] for row in results
              if row["status"] == "passed" and "probe" in row and row["scope"] != "reference-to-target"]
    observed_peak = max(active, default=0)
    if observed_peak <= 1:
        failures.append({"name": "actual-concurrent-worker-proof", "failure": "no actual simultaneously active worker count above one observed"})
    counts = {"cases": len(results), "passed": sum(row["status"] == "passed" for row in results), "failed": len(failures),
              "encode_cases": len(list(matrix())), "reference_decode_cases": len(reference_cases),
              "exact_memory_boundary_cases": budget_checks,
              "observed_peak_active_workers": observed_peak}
    report = {"schema": "vort.xz.parallel-differential.v1", "created_utc": datetime.now(timezone.utc).isoformat(),
              "source_epoch": args.source_epoch, "source": source_before, "source_after_sha256": source_after["sha256"],
              "sources_preserved": source_after == source_before, "probe": identity(probe), "reference": reference.describe(),
              "python": platform.python_version(), "host": platform.platform(), "inputs": {name: identity(directory / (name + ".input")) for name in inputs},
              "scope": "public one-shot parallel encoding, complete serial wire parity, real worker/profile evidence, ordered block/Index validation, full plaintext both directions, filters/checks/alias/limits",
              "measurement_scope": "functional progress, actual bytes, requested-memory and worker counters; no throughput, timing, OS stack or RSS claim",
              "counts": counts, "failures": failures, "results": results, "commands": commands}
    report_path = args.report or directory / "differential.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"report": str(report_path), **counts, "sources_preserved": report["sources_preserved"]}))
    require(not failures and report["sources_preserved"], ("XZ parallel gate failed", failures))


if __name__ == "__main__":
    main()
