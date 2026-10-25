#!/usr/bin/env python3
"""Exact XZ declared Block sizes and instrumented MT decoder interoperability.

The parent builds the public-ABI adapter and test-only instrumented liblzma.
This tool never compiles, patches a reference, installs software, or times work.
"""
from __future__ import annotations

import argparse
import ctypes as C
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import sys

sys.dont_write_bytecode = True
from parallel_diff import Reference, inspect as base_inspect, vli, deterministic, identity, digest, CHECKS, FILTER_IDS

ROOT = Path(__file__).resolve().parents[2]
COUNTERS = ("workers_created", "worker_threads_entered", "worker_threads_exited", "worker_threads_live",
            "worker_jobs_entered", "worker_jobs_completed", "worker_jobs_failed", "worker_jobs_abandoned",
            "worker_decode_calls", "worker_call_input_bytes", "worker_call_output_bytes", "active_worker_decode_calls",
            "peak_active_worker_decode_calls", "active_worker_jobs", "peak_active_worker_jobs", "worker_call_identity_mask",
            "worker_completed_identity_mask", "worker_call_distinct", "worker_completed_distinct", "worker_identity_overflow",
            "direct_blocks_initialized", "direct_blocks_completed", "direct_decode_calls", "direct_call_input_bytes",
            "direct_call_output_bytes", "direct_reason_missing_size", "direct_reason_oversized", "direct_reason_memory_limit",
            "direct_reason_memory_overflow", "invariant_failures")


def require(value, context):
    if not value:
        raise AssertionError(context)


class Adapter:
    def __init__(self, path, original_library, instrumented_library):
        self.path, self.original, self.instrumented = path.resolve(), original_library.resolve(), instrumented_library.resolve()
        self.lib = C.CDLL(str(self.path))
        def bind(name, result, *arguments):
            fn = getattr(self.lib, name)
            fn.restype, fn.argtypes = result, arguments
            return fn
        size, ptr = C.c_size_t, C.c_void_p
        self.abi = bind("vort_xz_bs_adapter_abi", C.c_uint32)()
        require(self.abi == 1, "public reference adapter ABI")
        self.sizes = {name: bind("vort_xz_bs_sizeof_" + name, size)() for name in ("stream", "mt", "lzma_options")}
        self.owner = bind("vort_xz_bs_library_owner", C.c_int, C.c_char_p, ptr, size)
        self.decode_fn = bind("vort_xz_bs_decode_mt", C.c_int, C.c_char_p, C.c_uint32, C.c_uint64, C.c_uint64,
                              ptr, size, ptr, size, C.POINTER(C.c_uint64), C.POINTER(C.c_uint64), C.POINTER(C.c_uint32),
                              C.POINTER(C.c_uint64), size)
        self.encode_fn = bind("vort_xz_bs_encode_mt", C.c_int, C.c_char_p, C.c_uint32, C.c_uint64, C.c_uint32,
                              C.c_uint32, C.POINTER(C.c_uint64), C.POINTER(C.c_uint32), size, ptr, size, ptr, size,
                              C.POINTER(C.c_uint64), C.POINTER(C.c_uint32))

    def describe(self):
        owners = {}
        for name, path in (("original", self.original), ("instrumented", self.instrumented)):
            text = C.create_string_buffer(4096)
            require(self.owner(str(path).encode(), text, len(text)) == 0, "reference decoder MT symbol owner")
            actual = Path(text.value.decode()).resolve()
            require(actual == path, "requested library and actual MT symbol owner differ")
            owners[name] = identity(actual)
        return {"adapter": identity(self.path), "adapter_source": identity(ROOT / "tools/xz/block_sizes_reference.c"),
                "abi": self.abi, "public_struct_sizes": self.sizes, "actual_library_owners": owners,
                "counter_abi": 1, "counter_count": len(COUNTERS), "counter_fields": COUNTERS}

    def decode(self, wire, payload, threading_limit=64 * 1024 * 1024, threads=3, instrumented=True):
        capacity = len(payload) + 1
        output = C.create_string_buffer(b"\xa5" * (capacity + 16), capacity + 16)
        read, written, status = C.c_uint64(), C.c_uint64(), C.c_uint32()
        values = (C.c_uint64 * len(COUNTERS))()
        library = self.instrumented if instrumented else self.original
        result = self.decode_fn(str(library).encode(), threads, threading_limit, 256 * 1024 * 1024,
                                wire, len(wire), C.byref(output, 8), capacity, C.byref(read), C.byref(written),
                                C.byref(status), values if instrumented else None, len(COUNTERS) if instrumented else 0)
        require(result == 0, ("MT adapter invocation/snapshot", result))
        require(output.raw[:8] == b"\xa5" * 8 and output.raw[-8:] == b"\xa5" * 8, "MT decoder output guards")
        actual = output.raw[8:8 + written.value]
        result = {"adapter_status": result, "lzma_status": status.value, "input_read": read.value, "output_written": written.value,
                "output_sha256": digest(actual), "configured_threads": threads, "memlimit_threading": threading_limit,
                "memlimit_stop": 256 * 1024 * 1024, "caller_guards_verified": True,
                "selected_library": identity(library), "instrumented": instrumented,
                "complete_contents_verified": status.value == 1 and read.value == len(wire) and actual == payload}
        if instrumented:
            counters = dict(zip(COUNTERS, values))
            require(counters["worker_threads_live"] == counters["active_worker_decode_calls"] == counters["active_worker_jobs"] == 0 and
                    counters["invariant_failures"] == counters["worker_identity_overflow"] == 0, "instrumented worker lifecycle after lzma_end")
            result["counters"] = counters
        return result

    def encode(self, payload, check="crc64", filters=(), block_size=4096):
        ids = (C.c_uint64 * len(filters))(*(FILTER_IDS[row["kind"]] for row in filters))
        params = (C.c_uint32 * len(filters))(*(row["parameter"] for row in filters))
        capacity = len(payload) * 2 + 1024 * 1024
        output = C.create_string_buffer(b"\xa5" * (capacity + 16), capacity + 16)
        written, status = C.c_uint64(), C.c_uint32()
        result = self.encode_fn(str(self.original).encode(), 3, block_size, CHECKS[check], 0, ids, params, len(filters),
                                payload, len(payload), C.byref(output, 8), capacity, C.byref(written), C.byref(status))
        require(result == 0 and status.value == 1, ("native MT XZ encoder", result, status.value))
        require(output.raw[:8] == b"\xa5" * 8 and output.raw[-8:] == b"\xa5" * 8, "MT encoder output guards")
        return output.raw[8:8 + written.value]


def verify_provenance(path):
    provenance = json.loads(path.read_text())
    require(provenance["schema"] == "vort-xz-mt-probe-source-v1" and provenance["abi_version"] == 1 and
            provenance["counter_count"] == len(COUNTERS) and
            [provenance["counters"][str(index)] for index in range(len(COUNTERS))] == list(COUNTERS),
            "instrumentation provenance and adapter counter ABI differ")
    files = {}
    for key in ("patch", "header", "script"):
        row = provenance[key]
        actual = identity(row["path"])
        require(actual["sha256"] == row["sha256"], ("instrumentation input identity", key))
        files[key] = actual
    original_root, patched_root = Path(provenance["original_source_tree"]), Path(provenance["patched_source_tree"])
    checked = []
    for row in provenance["changed_files"]:
        original, patched = original_root / row["path"], patched_root / row["path"]
        if row["original_sha256"] is not None:
            require(identity(original)["sha256"] == row["original_sha256"], "original reference changed source hash")
        require(identity(patched)["sha256"] == row["patched_sha256"], "instrumented reference changed source hash")
        checked.append({"path": row["path"], "original": identity(original) if original.exists() else None, "patched": identity(patched)})
    source_index = identity(provenance["original_source_index"])
    indexed = json.loads(Path(provenance["original_source_index"]).read_text())
    require(isinstance(indexed, list) and indexed, "original reference source index rows")
    indexed_by_path = {}
    for row in indexed:
        relative = Path(row["path"])
        require(not relative.is_absolute() and ".." not in relative.parts and ".git" not in relative.parts and
                row["path"] not in indexed_by_path, "original source index local unique path")
        indexed_by_path[row["path"]] = row
    def scan_tree(root):
        rows = []
        for file in sorted(root.rglob("*")):
            relative = file.relative_to(root)
            if ".git" in relative.parts:
                continue
            require(not file.is_symlink(), ("reference source symlink", relative.as_posix()))
            if file.is_file():
                body = file.read_bytes()
                rows.append({"path": relative.as_posix(), "bytes": len(body), "sha256": digest(body)})
        # The source manifest's documented digest serializes each sorted path,
        # a NUL separator, the file hash and a newline; no patch code is imported.
        tree_hash = digest("".join(row["path"] + "\0" + row["sha256"] + "\n" for row in rows).encode())
        return rows, tree_hash
    original_rows, original_hash = scan_tree(original_root)
    patched_rows, patched_hash = scan_tree(patched_root)
    require(original_rows == indexed and original_hash == provenance["original_tree_sha256"],
            "complete original source tree differs from index or manifest")
    expected_patched = dict(indexed_by_path)
    for row in provenance["changed_files"]:
        expected_patched[row["path"]] = {"path": row["path"], "bytes": row["patched_bytes"], "sha256": row["patched_sha256"]}
    require({row["path"]: row for row in patched_rows} == expected_patched and
            patched_hash == provenance["patched_tree_sha256"],
            "complete patched source tree differs beyond declared changes")
    return {"identity": identity(path), "manifest": provenance, "inputs_verified": files,
            "changed_sources_verified": checked, "original_source_index": source_index,
            "complete_source_trees_verified": {"original_file_count": len(original_rows), "patched_file_count": len(patched_rows),
                                                "original_tree_sha256": original_hash, "patched_tree_sha256": patched_hash,
                                                "original_index_exact": True, "patched_declared_changes_only": True}}


def verify_build_record(path, provenance, adapter):
    record = json.loads(path.read_text())
    require(record["schema"] == "vort-xz-mt-reference-build-v1", "MT reference build record schema")
    instrumentation = record["instrumentation_manifest"]
    require(Path(instrumentation["path"]).resolve() == Path(provenance["identity"]["path"]).resolve() and
            identity(instrumentation["path"])["sha256"] == instrumentation["sha256"] == provenance["identity"]["sha256"] and
            identity(instrumentation["path"])["bytes"] == instrumentation["bytes"] == provenance["identity"]["bytes"],
            "build record binds the selected instrumentation manifest")
    require(record["original_tree_sha256"] == provenance["manifest"]["original_tree_sha256"] and
            record["patched_tree_sha256"] == provenance["manifest"]["patched_tree_sha256"],
            "build record reference source trees differ from verified provenance")
    files = {}
    for row in record["files"]:
        file = Path(row["path"])
        actual = identity(file)
        require(actual["bytes"] == row["bytes"] and actual["sha256"] == row["sha256"],
                ("actual reference build artifact identity", str(file)))
        key = str(file.resolve())
        require(key not in files, "duplicate reference build artifact path")
        files[key] = actual
    require(str(adapter.instrumented) in files and str(adapter.path) in files,
            "build record must contain the executed MT library and adapter")
    require(files[str(adapter.instrumented)]["sha256"] == identity(adapter.instrumented)["sha256"] and
            files[str(adapter.path)]["sha256"] == identity(adapter.path)["sha256"],
            "executed reference ELF differs from built artifact")
    require(str((ROOT / "tools/xz/block_sizes_reference.c").resolve()) in files,
            "build record must contain the actual adapter source")
    return {"identity": identity(path), "record": record, "artifact_files_verified": list(files.values()),
            "executed_library_in_record": True, "executed_adapter_in_record": True,
            "complete_source_trees_match_build_record": True}


def inspect(wire):
    parsed = base_inspect(wire)
    for block in parsed["blocks"]:
        start, cursor = block["start_byte"], block["start_byte"] + 2
        flags = wire[start + 1]
        fields = []
        for mask, name in ((64, "compressed"), (128, "uncompressed")):
            before = cursor
            value = None
            if flags & mask:
                value, cursor = vli(wire, cursor, start + block["header_bytes"] - 4)
            fields.append({"name": name, "present": bool(flags & mask), "value": value,
                           "vli_bytes": cursor - before, "start_byte": before if flags & mask else None})
        block["block_flags"] = flags
        block["declared_sizes"] = fields
        block["declared_compressed_size"] = fields[0]["value"]
        block["declared_uncompressed_size"] = fields[1]["value"]
        block["physical_payload_sha256"] = digest(wire[block["payload"]["start_byte"]:block["payload"]["end_byte"]])
        require(not flags & 64 or fields[0]["value"] == block["payload"]["serialized_bytes"], "declared payload includes LZMA2 terminal zero")
        require(not flags & 128 or fields[1]["value"] == block["decoded_bytes"], "declared size is original plain length")
    return parsed


def verify_sized_pair(wire, unsized, enabled):
    actual, baseline = inspect(wire), inspect(unsized)
    require(actual["block_count"] == baseline["block_count"] and actual["check_id"] == baseline["check_id"], "sized/unsized block count/check identity")
    for block, old in zip(actual["blocks"], baseline["blocks"]):
        require(block["decoded_bytes"] == old["decoded_bytes"] and block["filters"] == old["filters"] and
                block["physical_payload_sha256"] == old["physical_payload_sha256"], "declared headers preserve block payload/filter decisions")
        require(all(row["present"] == enabled for row in block["declared_sizes"]), "optional declared-size flags match caller")
        require(not any(row["present"] for row in old["declared_sizes"]), "legacy unsized reference remains undeclared")
    if not enabled:
        require(wire == unsized, "default/explicit false legacy wire parity")
    return actual


def fixtures():
    return {"empty": b"", "tiny": b"Declared XZ Block sizes\x00\xff", "random": deterministic(50001),
            "repeat": (b"Exact compressed size includes final LZMA2 zero.\n" * 1500)[:50001],
            "binary": bytes.fromhex("e80000000090e9f0ffffff") * 1800,
            "parallel": bytes(byte & 15 for byte in deterministic(262177)),
            **{f"vli{length}": deterministic(length) for length in (123, 124, 127, 128, 16379, 16380, 16383, 16384)},
            "credit": deterministic(3000)}


def matrix():
    for case in ("empty", "tiny", "repeat", "random"):
        for check in CHECKS:
            for enabled in (False, True):
                for parallel in (False, True):
                    yield case, {"check": check, "include_block_sizes": enabled, "parallel": parallel}, "base"
    for api in ("alloc", "append", "into"):
        for payload in ("stored", "compressed"):
            for enabled in (False, True):
                yield "repeat", {"api": api, "payload": payload, "include_block_sizes": enabled,
                                 "compare_serial_incremental": True}, "output-routes"
        yield "repeat", {"api": api, "lazy_entry": True, "compare_serial_incremental": True}, "lazy-entry"
    for length in (123, 124, 127, 128, 16379, 16380, 16383, 16384):
        yield f"vli{length}", {"payload": "stored", "block_size": 65536, "chunk_size": 65536}, "vli-boundary"
    for parser in ("greedy", "lazy", "fast", "normal"):
        overrides = {"parser": parser}
        if parser in ("fast", "normal"):
            overrides["match_options"] = {"finder": "hc4" if parser == "fast" else "bt4", "nice_len": 32, "depth": 8}
        yield "repeat", overrides, "parser"
    for preset in (0, 6):
        yield "tiny", {"preset": preset, "parallel": False}, "preset"
    for kind in FILTER_IDS:
        yield "binary", {"filters": [{"kind": kind, "parameter": 3 if kind == "delta" else 16}]}, "filter"
    yield "binary", {"filters": [{"kind": "delta", "parameter": 7}, {"kind": "x86", "parameter": 16}]}, "filter-chain"
    for api in ("append", "into"):
        yield "repeat", {"api": api, "alias": True}, "alias"
        yield "repeat", {"api": api, "max_working_memory": 0}, "memory-rejection"
        yield "repeat", {"api": api, "max_inflight_bytes": 4095}, "credit-rejection"
    yield "repeat", {"api": "into", "short_output": True}, "short-output"
    for enabled in (False, True):
        yield "parallel", {"include_block_sizes": enabled, "block_size": 32768, "chunk_size": 32768}, "worker-path"
    yield "credit", {"block_size": 4096, "max_inflight_bytes": 3000}, "actual-credit"
    yield "repeat", {"include_block_sizes": False, "omit_block_sizes_option": True}, "production-default-false"
    yield "repeat", {"parser": "literal_only", "parallel": False}, "parser"
    yield "tiny", {"preset": 0, "extreme": True, "parallel": False}, "preset-extreme"


def source_identity():
    paths = [ROOT / "src/xz.zig", ROOT / "src/lzma.zig", ROOT / "src/core.zig", ROOT / "src/bitstream.zig",
             ROOT / "tools/xz/block_sizes_probe.zig", ROOT / "tools/xz/block_sizes_reference.c", Path(__file__).resolve(),
             ROOT / "tools/xz/parallel_diff.py"]
    for folder in ("xz", "lzma", "io", "checksum"):
        paths += sorted((ROOT / "src" / folder).rglob("*.zig"))
    rows = [{"path": str(path.relative_to(ROOT)), "sha256": digest(path.read_bytes())} for path in paths if path.exists()]
    return {"files": rows, "sha256": digest(json.dumps(rows, sort_keys=True).encode())}


def check_worker_path(result, blocks, enabled, low_memory=False):
    require(result["complete_contents_verified"], "instrumented MT decoder full plaintext/consumption")
    counters = result["counters"]
    if not blocks:
        require(counters["worker_jobs_completed"] == counters["direct_blocks_completed"] == 0, "empty MT decode has no block jobs")
    elif not enabled or low_memory:
        require(counters["worker_jobs_completed"] == 0 and counters["worker_completed_distinct"] == 0 and
                counters["worker_decode_calls"] == 0 and counters["direct_blocks_completed"] == blocks,
                "unsized/low-memory MT decoder uses actual direct path")
        reason = "direct_reason_memory_limit" if low_memory else "direct_reason_missing_size"
        require(counters[reason] > 0, "observed direct path reason")
    elif blocks == 1:
        require(counters["worker_jobs_completed"] == 1 and counters["worker_completed_distinct"] == 1,
                "sized single block uses one actual decoder worker")
    else:
        require(counters["worker_jobs_completed"] == blocks and counters["worker_completed_distinct"] > 1 and
                counters["worker_call_distinct"] > 1 and counters["direct_blocks_initialized"] == 0 and
                counters["worker_jobs_failed"] == counters["worker_jobs_abandoned"] == 0,
                "sized multi-block uses multiple actual successful decoder workers")


def self_check(reference):
    for case, payload in fixtures().items():
        wire = reference.encode(payload)
        parsed = inspect(wire)
        require(parsed["decoded_bytes"] == len(payload) and reference.decode(wire, payload)["complete_contents_verified"], "reference parsed payload self-check")
    return {"target_encode_matrix": len(list(matrix())), "instrumented_counter_fields": len(COUNTERS), "reference_version": reference.version}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", type=Path)
    parser.add_argument("--directory", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--source-epoch", default="unspecified")
    parser.add_argument("--reference", type=Path, default=Path("/tmp/vort-xz-ref.vVVDxq/build/liblzma.so.5.8.4"))
    parser.add_argument("--reference-headers", type=Path, default=Path("/tmp/vort-xz-ref.vVVDxq/xz/src/liblzma/api"))
    parser.add_argument("--mt-adapter", type=Path)
    parser.add_argument("--mt-library", type=Path)
    parser.add_argument("--mt-provenance", type=Path)
    parser.add_argument("--mt-build-record", type=Path)
    parser.add_argument("--self-check", action="store_true")
    args = parser.parse_args()
    reference = Reference(args.reference, args.reference_headers)
    checked = self_check(reference)
    if args.self_check:
        print(json.dumps({"self_check": "passed", "checks": checked, "reference": reference.describe()}))
        return
    require(args.probe and args.directory and args.mt_adapter and args.mt_library and args.mt_provenance and args.mt_build_record,
            "--probe/--directory/--mt-adapter/--mt-library/--mt-provenance/--mt-build-record required; parent builds reference artifacts")
    adapter = Adapter(args.mt_adapter, args.reference, args.mt_library)
    adapter_identity = adapter.describe()
    provenance = verify_provenance(args.mt_provenance)
    build_record = verify_build_record(args.mt_build_record, provenance, adapter)
    directory, probe = args.directory.resolve(), args.probe.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    source_before = source_identity()
    inputs = fixtures()
    for name, payload in inputs.items():
        (directory / (name + ".input")).write_bytes(payload)
    commands, results, failures = [], [], []
    def run(name, c, input_path, output_path):
        config_path = directory / (name + ".json")
        config_path.write_text(json.dumps(c, indent=2) + "\n")
        command = [str(probe), str(input_path), str(output_path), str(config_path)]
        process = subprocess.run(command, capture_output=True, check=False, timeout=120)
        stdout, stderr = directory / (name + ".stdout"), directory / (name + ".stderr")
        stdout.write_bytes(process.stdout)
        stderr.write_bytes(process.stderr)
        commands.append({"command": command, "exit_code": process.returncode, "stdout": identity(stdout), "stderr": identity(stderr)})
        require(process.returncode == 0, (name, "target process", process.returncode, process.stderr.decode(errors="replace")))
        return json.loads(process.stdout)
    mt_rows = []
    for index, (case, overrides, scope) in enumerate(matrix()):
        name = f"encode-{index:03d}-{case}-{scope}"
        c = {"operation": "encode", "api": "alloc", "parallel": True, "include_block_sizes": True,
             "block_size": 4096, "chunk_size": 4096, "dictionary_size": 4096, "worker_count": 3,
             "max_inflight_blocks": 4, "max_inflight_bytes": 4 * 1024 * 1024, "max_working_memory": 256 * 1024 * 1024, **overrides}
        path = directory / (name + ".xz")
        payload = inputs[case]
        row = {"name": name, "scope": scope, "settings": c, "input": identity(directory / (case + ".input"))}
        try:
            report = run(name, c, directory / (case + ".input"), path)
            row["probe"] = report
            error = {"short-output": "OutputTooSmall", "memory-rejection": "WorkingMemoryLimitExceeded", "credit-rejection": "WorkingMemoryLimitExceeded"}.get(scope)
            require(report["error"] == error, (name, "exact result", report))
            if error:
                require(report["caller_preserved_on_error"], "failed caller publication unchanged")
                row["expected_error"] = error
            else:
                wire = path.read_bytes()
                unsized = Path(str(path) + ".unsized.xz")
                serial = Path(str(path) + ".serial.xz")
                require(report["input_sha256"] == digest(payload) and report["output_sha256"] == digest(wire) and
                        report["serial_wire_equal"] and wire == serial.read_bytes() and report["self_decode_verified"], "target complete serial wire identity")
                parsed = verify_sized_pair(wire, unsized.read_bytes(), c["include_block_sizes"])
                require(parsed["decoded_bytes"] == len(payload), "original input extent")
                if c.get("compare_serial_incremental"):
                    require(report["serial_incremental_equal"], "serial incremental same-boundary declared headers")
                direct = reference.decode(wire, payload)
                require(direct["complete_contents_verified"], "original 5.8.4 full plaintext")
                row.update({"wire": identity(path), "serial_wire": identity(serial), "unsized_wire": identity(unsized),
                            "independent_wire": parsed, "reference_decode": direct})
                # Worker path controls use sufficiently large independent blocks
                # so success on two actual worker identities is stable evidence.
                if scope == "worker-path" or case == "tiny" or case == "empty":
                    original_mt = adapter.decode(wire, payload, instrumented=False)
                    require(original_mt["complete_contents_verified"], "original uninstrumented MT decoder full plaintext/consumption")
                    row["original_mt_decode"] = original_mt
                    mt = adapter.decode(wire, payload)
                    check_worker_path(mt, parsed["block_count"], c["include_block_sizes"])
                    row["instrumented_mt_decode"] = mt
                    mt_rows.append(mt)
                if scope == "worker-path" and c["include_block_sizes"]:
                    original_low = adapter.decode(wire, payload, threading_limit=1, instrumented=False)
                    require(original_low["complete_contents_verified"], "original MT low-memory full plaintext/consumption")
                    row["original_low_memory_mt_decode"] = original_low
                    low = adapter.decode(wire, payload, threading_limit=1)
                    check_worker_path(low, parsed["block_count"], True, low_memory=True)
                    row["low_memory_mt_decode"] = low
            row["status"] = "passed"
        except (AssertionError, OSError, json.JSONDecodeError) as error:
            row.update({"status": "failed", "failure": str(error)})
            failures.append({"name": name, "failure": str(error)})
        results.append(row)
    # Actual original liblzma MT encoding emits declared fields natively. Feed
    # those exact bytes to public Vort decoding; no header synthesis is used.
    native_cases = [("parallel", check, []) for check in CHECKS]
    native_cases += [("binary", "crc64", [{"kind": kind, "parameter": 3 if kind == "delta" else 16}]) for kind in FILTER_IDS]
    for index, (case, check, filters) in enumerate(native_cases):
        name = f"native-mt-reference-{index:03d}"
        payload = inputs[case]
        wire = adapter.encode(payload, check, filters)
        path, output = directory / (name + ".xz"), directory / (name + ".decoded")
        path.write_bytes(wire)
        row = {"name": name, "scope": "native-mt-encode-to-target", "wire": identity(path)}
        try:
            parsed = inspect(wire)
            require(all(all(field["present"] for field in block["declared_sizes"]) for block in parsed["blocks"]), "native MT reference declares both sizes")
            report = run(name, {"operation": "decode", "parallel": False, "max_output_len": len(payload)}, path, output)
            require(report["error"] is None and output.read_bytes() == payload and report["output_sha256"] == digest(payload), "target decodes native declared-size frames")
            row.update({"probe": report, "independent_wire": parsed, "status": "passed"})
        except (AssertionError, OSError, json.JSONDecodeError) as error:
            row.update({"status": "failed", "failure": str(error)})
            failures.append({"name": name, "failure": str(error)})
        results.append(row)
    after = source_identity()
    require(adapter.describe() == adapter_identity and verify_provenance(args.mt_provenance) == provenance and
            verify_build_record(args.mt_build_record, provenance, adapter) == build_record,
            "executed reference artifacts/provenance changed during campaign")
    successful_worker_paths = [row for row in mt_rows if row["counters"]["worker_completed_distinct"] > 1]
    if not successful_worker_paths:
        failures.append({"name": "real-mt-worker-proof", "failure": "no multiple actual successful worker identities observed"})
    counts = {"cases": len(results), "passed": sum(row["status"] == "passed" for row in results), "failed": len(failures),
              "target_encodes": len(list(matrix())), "native_mt_reference_decodes": len(native_cases),
              "multiple_actual_worker_observations": len(successful_worker_paths),
              "original_mt_reference_calls": sum("original_mt_decode" in row for row in results),
              "original_low_memory_mt_reference_calls": sum("original_low_memory_mt_decode" in row for row in results),
              "instrumented_mt_reference_calls": len(mt_rows),
              "instrumented_low_memory_mt_reference_calls": sum("low_memory_mt_decode" in row for row in results),
              "maximum_completed_worker_distinct": max((row["counters"]["worker_completed_distinct"] for row in mt_rows), default=0)}
    report = {"schema": "vort.xz.block-sizes-differential.v1", "created_utc": datetime.now(timezone.utc).isoformat(),
              "source_epoch": args.source_epoch, "source": source_before, "source_after_sha256": after["sha256"],
              "sources_preserved": after == source_before, "probe": identity(probe), "reference": reference.describe(),
              "mt_adapter": adapter_identity, "mt_instrumentation_provenance": provenance,
              "mt_reference_build": build_record,
              "counter_scope": "Actual worker function identities/jobs and direct path counters from test-only 5.8.4 build; configured threads alone are not execution evidence",
              "measurement_scope": "functional content/byte extents and actual worker/requested-memory counters only; no timing or throughput claims",
              "python": platform.python_version(), "host": platform.platform(), "counts": counts,
              "results": results, "failures": failures, "commands": commands}
    report_path = args.report or directory / "differential.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"report": str(report_path), **counts, "sources_preserved": report["sources_preserved"]}))
    require(not failures and report["sources_preserved"], ("XZ declared-size gate", failures))


if __name__ == "__main__":
    main()
