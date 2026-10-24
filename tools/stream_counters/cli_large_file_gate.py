#!/usr/bin/env python3
"""Real x86 CLI file IO gate. --large authorizes one >4 GiB sparse source.

Each encoder reads the source once. Independent decoders drain through 64 KiB
buffers and verify every byte. A prior encode-attempt receipt prevents silently
restarting a large stream after a failure. No throughput rankings are produced.
"""
import argparse
import ctypes as C
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from datetime import datetime, timezone

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
CHUNK = 65536
TAIL = b"vort-4GiB-tail!!!"
LARGE_PREFIX = 1 << 32


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def sha_file(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as source:
        while data := source.read(1024 * 1024):
            h.update(data)
    return h.hexdigest()


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + "\n")


def bind(library, name, result, *arguments):
    method = getattr(library, name)
    method.restype, method.argtypes = result, list(arguments)
    return method


class VerifiedContent:
    def __init__(self, prefix):
        self.prefix = prefix
        self.size = prefix + len(TAIL)
        self.total = 0
        self.hash = hashlib.sha256()
        self.zero = bytes(CHUNK)
        self.tail = bytearray()
        self.calls = 0

    def feed(self, data):
        require(self.total + len(data) <= self.size, "decoder exceeded expected logical size")
        zero_count = min(len(data), max(0, self.prefix - self.total))
        require(data[:zero_count] == self.zero[:zero_count], "decoded zero prefix differs")
        if zero_count != len(data):
            start = self.total + zero_count - self.prefix
            tail = data[zero_count:]
            require(tail == TAIL[start:start + len(tail)], "decoded tail marker differs")
            self.tail.extend(tail)
        self.hash.update(data)
        self.total += len(data)
        self.calls += 1

    def finish(self):
        require(self.total == self.size and bytes(self.tail) == TAIL, "truncated logical content or tail")
        return {"decoded_bytes": self.total, "decoded_sha256": self.hash.hexdigest(),
                "tail_hex": bytes(self.tail).hex(), "verified_output_chunks": self.calls,
                "largest_output_buffer": CHUNK}


class Decoder:
    def __init__(self, family, path):
        self.family, self.path = family, Path(path).resolve()
        loader = C.CDLL("libdl.so.2")
        handle = bind(loader, "dlmopen", C.c_void_p, C.c_long, C.c_char_p, C.c_int)(-1, os.fsencode(self.path), 2)
        require(handle, f"cannot load isolated reference {self.path}")
        self.library = C.CDLL(str(self.path), handle=handle)
        self.output = C.create_string_buffer(CHUNK)
        if family == "brotli":
            self.version = bind(self.library, "BrotliDecoderVersion", C.c_uint)()
            self.create = bind(self.library, "BrotliDecoderCreateInstance", C.c_void_p, C.c_void_p, C.c_void_p, C.c_void_p)
            self.destroy = bind(self.library, "BrotliDecoderDestroyInstance", None, C.c_void_p)
            self.decode = bind(self.library, "BrotliDecoderDecompressStream", C.c_int, C.c_void_p,
                               C.POINTER(C.c_size_t), C.POINTER(C.c_void_p), C.POINTER(C.c_size_t),
                               C.POINTER(C.c_void_p), C.POINTER(C.c_size_t))
            self.error = bind(self.library, "BrotliDecoderGetErrorCode", C.c_int, C.c_void_p)
        else:
            self.version = bind(self.library, "ZSTD_versionNumber", C.c_uint)()
            self.create = bind(self.library, "ZSTD_createDStream", C.c_void_p)
            self.destroy = bind(self.library, "ZSTD_freeDStream", C.c_size_t, C.c_void_p)
            self.initialize = bind(self.library, "ZSTD_initDStream", C.c_size_t, C.c_void_p)
            self.decode = bind(self.library, "ZSTD_decompressStream", C.c_size_t, C.c_void_p,
                               C.POINTER(ZstdOutput), C.POINTER(ZstdInput))
            self.is_error = bind(self.library, "ZSTD_isError", C.c_uint, C.c_size_t)
            self.error = bind(self.library, "ZSTD_getErrorName", C.c_char_p, C.c_size_t)

    def verify(self, path, prefix):
        content = VerifiedContent(prefix)
        state = self.create(None, None, None) if self.family == "brotli" else self.create()
        require(state, "reference decoder allocation failed")
        encoded_bytes, finished = 0, False
        if self.family == "zstd":
            require(not self.is_error(self.initialize(state)), "Zstd reference init failed")
        try:
            with Path(path).open("rb") as wire:
                while data := wire.read(CHUNK):
                    require(not finished, "unexpected trailing encoded bytes")
                    encoded_bytes += len(data)
                    source = C.create_string_buffer(data)
                    offset = 0
                    while True:
                        if self.family == "brotli":
                            remaining = C.c_size_t(len(data) - offset)
                            next_in = C.c_void_p(C.addressof(source) + offset)
                            available = C.c_size_t(CHUNK)
                            next_out = C.c_void_p(C.addressof(self.output))
                            result = self.decode(state, C.byref(remaining), C.byref(next_in),
                                                 C.byref(available), C.byref(next_out), None)
                            require(result != 0, f"Brotli reference error {self.error(state)}")
                            consumed = len(data) - offset - remaining.value
                            produced = CHUNK - available.value
                            finished = result == 1
                        else:
                            input_buffer = ZstdInput(C.addressof(source), len(data), offset)
                            output_buffer = ZstdOutput(C.addressof(self.output), CHUNK, 0)
                            result = self.decode(state, C.byref(output_buffer), C.byref(input_buffer))
                            require(not self.is_error(result), self.error(result).decode())
                            consumed, produced = input_buffer.pos - offset, output_buffer.pos
                            finished = result == 0
                        offset += consumed
                        if produced:
                            content.feed(self.output.raw[:produced])
                        if finished:
                            require(offset == len(data), "trailing bytes at reference end")
                            break
                        if offset == len(data) and produced < CHUNK:
                            break
                        require(consumed or produced, "reference made no progress")
            require(finished, "reference did not finish")
            return {**content.finish(), "encoded_bytes": encoded_bytes, "library": str(self.path),
                    "library_sha256": sha_file(self.path), "version_number": self.version}
        finally:
            self.destroy(state)


class ZstdInput(C.Structure):
    _fields_ = [("src", C.c_void_p), ("size", C.c_size_t), ("pos", C.c_size_t)]


class ZstdOutput(C.Structure):
    _fields_ = [("dst", C.c_void_p), ("size", C.c_size_t), ("pos", C.c_size_t)]


def frame_content_size(path):
    header = Path(path).open("rb").read(18)
    require(header[:4] == bytes.fromhex("28b52ffd"), "wrong Zstd magic")
    descriptor = header[4]
    single_segment = bool(descriptor & 32)
    offset = 5 + int(not single_segment)
    offset += (0, 1, 2, 4)[descriptor & 3]
    flag = descriptor >> 6
    width = (1 if single_segment else 0) if flag == 0 else (2, 4, 8)[flag - 1]
    require(width != 0 and len(header) >= offset + width, "Zstd content size missing")
    size = int.from_bytes(header[offset:offset + width], "little") + (256 if width == 2 else 0)
    return {"content_size": size, "field_bytes": width, "single_segment": single_segment,
            "header_hex": header[:offset + width].hex()}


def create_sparse(path, prefix):
    path = Path(path)
    with path.open("xb") as file:
        file.truncate(prefix + len(TAIL))
        file.seek(prefix)
        file.write(TAIL)
        file.flush()
        os.fsync(file.fileno())
    stat = path.stat()
    return {"path": str(path), "logical_bytes": stat.st_size,
            "allocated_block_bytes": stat.st_blocks * 512, "zero_prefix_bytes": prefix,
            "tail_hex": TAIL.hex(), "tail_offset": prefix}


def source_snapshot():
    paths = {path for path in (ROOT / "src").rglob("*") if path.is_file()}
    paths.update((ROOT / "examples" / "cli").rglob("*.zig"))
    paths.update(ROOT / relative for relative in ("examples/brotli_cli_probe.zig", "examples/zstd_cli_probe.zig",
                                                "examples/cli.zig", "build.zig", "build.zig.zon",
                                                "tools/stream_counters/cli_large_file_gate.py"))
    dependency = ROOT.parent / "vail" / "archive_crypto"
    paths.update(path for path in (dependency / "src").rglob("*") if path.is_file())
    paths.update((dependency / "build.zig", dependency / "build.zig.zon"))
    return {str(path.resolve()): sha_file(path) for path in sorted(paths) if "__pycache__" not in path.parts}


def run_encoded_once(args, family, source, wire, size):
    receipt = args.output_dir / f"{family}-encode-started.json"
    require(not receipt.exists(), f"refusing to repeat {family} encoding; diagnose the prior attempt")
    cli = args.brotli_cli if family == "brotli" else args.zstd_cli
    cap = 32 * 1024 * 1024
    mode = ["--quality=0"] if family == "brotli" else ["raw_or_rle", "true", "true"]
    command = [str(cli), "encode-br-stream-file" if family == "brotli" else "encode-zstd-native-stream-file",
               str(source), str(wire), *mode, f"--max-input-len={size}", f"--max-output-len={cap}", "--memory-profile"]
    write_json(receipt, {"started_utc": datetime.now(timezone.utc).isoformat(), "command": command,
                        "source_logical_bytes": size, "complete": False})
    stdout_path, stderr_path = args.output_dir / f"{family}.stdout", args.output_dir / f"{family}.stderr"
    usage_path = args.output_dir / f"{family}.usage.json"
    with stdout_path.open("wb") as stdout, stderr_path.open("wb") as stderr:
        timed = ["/usr/bin/time", "-f", '{"max_resident_set_kib":%M,"user_seconds":%U,"system_seconds":%S,"exit_code":%x}',
                 "-o", str(usage_path), *command]
        completed = subprocess.run(timed, stdout=stdout, stderr=stderr)
    require(completed.returncode == 0, f"{family} CLI failed: {stderr_path.read_text(errors='replace')}")
    output = stdout_path.read_text()
    counts = re.search(r"(?:br|zstd_native)_compressed_bytes=(\d+) decoded_bytes=(\d+)", output)
    require(counts and int(counts[2]) == size and int(counts[1]) == wire.stat().st_size, "CLI logical counts mismatch")
    profile = re.search(r"(?:br|zstd)_memory_profile available=(true|false) peak_requested_bytes=(\d+) live_requested_bytes=(\d+) limit=(\S+)", output)
    require(profile and profile[1] == "true" and int(profile[2]) > 0 and int(profile[3]) == 0, "CLI memory profile missing or owner not released")
    require(wire.stat().st_size <= cap, "encoded output cap violated")
    report = {"command": command, "binary_sha256": sha_file(cli), "decoded_bytes": size,
              "encoded_bytes": wire.stat().st_size, "encoded_sha256": sha_file(wire),
              "peak_requested_heap_bytes": int(profile[2]), "live_requested_heap_bytes_after_release": int(profile[3]),
              "output_cap_bytes": cap, "resource_usage": json.loads(usage_path.read_text()),
              "resource_note": "requested heap excludes caller/stack/IO buffers and allocator bookkeeping; max RSS is a separate OS observation, not the requested heap or a throughput result"}
    write_json(receipt, {"complete": True, **report})
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--brotli-cli", required=True, type=Path)
    parser.add_argument("--zstd-cli", required=True, type=Path)
    parser.add_argument("--brotli-reference", action="append", type=Path, required=True)
    parser.add_argument("--zstd-reference", action="append", type=Path, required=True)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--large", action="store_true")
    parser.add_argument("--source-file", type=Path, help="Reuse the exactly sized existing sparse source without regenerating it")
    parser.add_argument("--prefix-bytes", type=int, default=1024 * 1024)
    args = parser.parse_args()
    args.output_dir = args.output_dir.resolve()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    args.brotli_cli, args.zstd_cli = args.brotli_cli.resolve(), args.zstd_cli.resolve()
    prefix = LARGE_PREFIX if args.large else args.prefix_bytes
    require(0 <= prefix <= LARGE_PREFIX, "prefix outside smoke/approved large range")
    status = {"phase": "large" if args.large else "smoke", "started_utc": datetime.now(timezone.utc).isoformat(),
              "source_reads_per_encoder": 1, "old_large_matrices_repeated": False, "cpu": subprocess.check_output(["lscpu"], text=True),
              "zig_version": subprocess.check_output(["zig", "version"], text=True).strip(), "status": "running"}
    write_json(args.output_dir / "status.json", status)
    before = source_snapshot()
    write_json(args.output_dir / "source-before.json", before)
    if args.source_file is not None:
        source = args.source_file.resolve()
        stat = source.stat()
        require(stat.st_size == prefix + len(TAIL), "reused source size differs")
        with source.open("rb") as file:
            file.seek(prefix)
            require(file.read(len(TAIL)) == TAIL, "reused source tail differs")
        fixture = {"path": str(source), "logical_bytes": stat.st_size, "allocated_block_bytes": stat.st_blocks * 512,
                   "zero_prefix_bytes": prefix, "tail_hex": TAIL.hex(), "tail_offset": prefix, "reused_existing_source": True}
    else:
        source = args.output_dir / "zero-prefix-tail.raw"
        fixture = create_sparse(source, prefix)
    write_json(args.output_dir / "source-fixture.json", fixture)
    rows, decoded_hash = [], None
    try:
        for family, references in (("brotli", args.brotli_reference), ("zstd", args.zstd_reference)):
            wire = args.output_dir / f"{family}.wire"
            wire.write_bytes(b"previous target sentinel")
            encoded = run_encoded_once(args, family, source, wire, prefix + len(TAIL))
            header = frame_content_size(wire) if family == "zstd" else None
            if header:
                require(header["content_size"] == prefix + len(TAIL), "independent Zstd u64 FCS mismatch")
            receipts = [Decoder(family, reference).verify(wire, prefix) for reference in references]
            for receipt in receipts:
                if decoded_hash is None:
                    decoded_hash = receipt["decoded_sha256"]
                require(receipt["decoded_sha256"] == decoded_hash, "reference/codec content hashes differ")
            old = wire.read_bytes()
            command = encoded["command"][:]
            index = next(index for index, argument in enumerate(command) if argument.startswith("--max-input-len="))
            command[index] = f"--max-input-len={prefix + len(TAIL) - 1}"
            rejected = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            require(rejected.returncode != 0 and b"OutputLimitExceeded" in rejected.stderr, "input cap did not reject source stat")
            require(wire.read_bytes() == old, "pre-stat rejection replaced the valid target")
            (args.output_dir / f"{family}-input-cap.stderr").write_bytes(rejected.stderr)
            row = {"family": family, **encoded, "references": receipts, "zstd_content_size": header,
                   "prestat_input_cap_preserved_target": True, "prestat_rejection_did_not_read_file_content": True}
            rows.append(row)
            write_json(args.output_dir / f"{family}-report.json", row)
        after = source_snapshot()
        write_json(args.output_dir / "source-after.json", after)
        delta = {path: {"before": before.get(path), "after": after.get(path)} for path in before.keys() | after.keys()
                 if before.get(path) != after.get(path)}
        write_json(args.output_dir / "source-delta.json", delta)
        report = {"status": "passed" if not delta else "passed-runtime-source-window-changed", "phase": status["phase"],
                  "source_fixture": fixture, "rows": rows, "decoded_sha256": decoded_hash,
                  "source_window_equal": not delta, "source_delta": delta,
                  "finished_utc": datetime.now(timezone.utc).isoformat(), "functional_validation_only": True,
                  "full_plaintext_allocation": False, "maximum_reference_output_buffer_bytes": CHUNK}
        write_json(args.output_dir / "report.json", report)
        print(json.dumps(report))
    except Exception as error:
        write_json(args.output_dir / "failure.json", {"error": str(error), "rows_completed": len(rows),
                   "source_fixture": fixture, "no_automatic_large_retry": True})
        raise


if __name__ == "__main__":
    main()
