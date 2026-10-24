#!/usr/bin/env python3
"""Public Brotli owned/caller-history stream contracts against libbrotli.

All ordinary streams are generated independently by the reference encoder.
One explicitly labeled Vort large-header diagnostic fixture is reference
decoded to exercise header replacement, simultaneous-live memory and OOM.
The report is correctness evidence, not a throughput benchmark.
"""
from __future__ import annotations

import argparse
from collections import Counter
import ctypes as C
import ctypes.util
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import random
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
U8 = C.POINTER(C.c_uint8)
SZ = C.POINTER(C.c_size_t)


def require(value, context):
    if not value:
        raise AssertionError(context)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def command(*args):
    result = subprocess.run([str(a) for a in args], capture_output=True, cwd=ROOT)
    if result.returncode:
        raise RuntimeError(f"command failed: {args}\n{result.stderr.decode(errors='replace')}")
    return result.stdout


def sources():
    paths = [ROOT / "src/br.zig", ROOT / "src/core.zig", ROOT / "src/io/working_allocator.zig",
             ROOT / "src/huffman.zig", ROOT / "src/bitstream.zig", ROOT / "src/lz77.zig", *(ROOT / "src/br").rglob("*.zig")]
    rows = [{"path": str(p.relative_to(ROOT)), "sha256": sha(p.read_bytes())} for p in sorted(paths)]
    return {"files": rows, "sha256": sha(json.dumps(rows, sort_keys=True).encode())}


def cpu():
    for line in Path("/proc/cpuinfo").read_text().splitlines():
        if line.startswith("model name"):
            return line.split(":", 1)[1].strip()
    return platform.processor()


def array(data):
    return (C.c_uint8 * max(1, len(data))).from_buffer_copy(data or b"\0")


class Brotli:
    def __init__(self, directory=None):
        if directory is None:
            candidates = sorted(Path("/tmp").glob("vort-br-upstream.*"))
            candidates += [Path("/tmp/vort-brotli-shared-build")]
            directory = next((p for p in candidates if (p / "libbrotlidec.so").exists()), None)
        self.directory = str(directory) if directory else None
        self.paths = {name: str((Path(directory) / f"libbrotli{name}.so").resolve()) if directory else ctypes.util.find_library(f"brotli{name}") for name in ("common", "enc", "dec")}
        self.common = C.CDLL(self.paths["common"], mode=C.RTLD_GLOBAL)
        self.enc = C.CDLL(self.paths["enc"])
        self.dec = C.CDLL(self.paths["dec"])
        self.bind(self.enc, "BrotliEncoderVersion", C.c_uint32, [])
        self.bind(self.dec, "BrotliDecoderVersion", C.c_uint32, [])
        for lib, side in ((self.enc, "Encoder"), (self.dec, "Decoder")):
            self.bind(lib, f"Brotli{side}CreateInstance", C.c_void_p, [C.c_void_p] * 3)
            self.bind(lib, f"Brotli{side}DestroyInstance", None, [C.c_void_p])
            self.bind(lib, f"Brotli{side}SetParameter", C.c_int, [C.c_void_p, C.c_int, C.c_uint32])
        self.bind(self.enc, "BrotliEncoderCompressStream", C.c_int, [C.c_void_p, C.c_int, SZ, C.POINTER(U8), SZ, C.POINTER(U8), SZ])
        self.bind(self.enc, "BrotliEncoderHasMoreOutput", C.c_int, [C.c_void_p])
        self.bind(self.enc, "BrotliEncoderIsFinished", C.c_int, [C.c_void_p])
        self.bind(self.dec, "BrotliDecoderDecompressStream", C.c_int, [C.c_void_p, SZ, C.POINTER(U8), SZ, C.POINTER(U8), SZ])
        self.dictionaries = all(hasattr(lib, name) for lib, name in (
            (self.enc, "BrotliEncoderPrepareDictionary"), (self.enc, "BrotliEncoderAttachPreparedDictionary"),
            (self.dec, "BrotliDecoderAttachDictionary")))
        if self.dictionaries:
            self.bind(self.enc, "BrotliEncoderPrepareDictionary", C.c_void_p, [C.c_int, C.c_size_t, U8, C.c_int, C.c_void_p, C.c_void_p, C.c_void_p])
            self.bind(self.enc, "BrotliEncoderAttachPreparedDictionary", C.c_int, [C.c_void_p, C.c_void_p])
            self.bind(self.enc, "BrotliEncoderDestroyPreparedDictionary", None, [C.c_void_p])
            self.bind(self.dec, "BrotliDecoderAttachDictionary", C.c_int, [C.c_void_p, C.c_int, C.c_size_t, U8])

    @staticmethod
    def bind(lib, name, restype, argtypes):
        fn = getattr(lib, name)
        fn.restype, fn.argtypes = restype, argtypes

    def encode(self, operations, quality=5, lgwin=16, large=False, dictionary=None):
        state = self.enc.BrotliEncoderCreateInstance(None, None, None)
        require(state, "reference encoder state")
        prepared = None
        keep = None
        try:
            for param, value in ((1, quality), (6, int(large)), (2, lgwin)):
                require(self.enc.BrotliEncoderSetParameter(state, param, value), ("encoder parameter", param, value))
            if dictionary is not None:
                require(self.dictionaries, "reference dictionary API")
                keep = array(dictionary)
                prepared = self.enc.BrotliEncoderPrepareDictionary(0, len(dictionary), keep, quality, None, None, None)
                require(prepared and self.enc.BrotliEncoderAttachPreparedDictionary(state, prepared), "reference dictionary attachment")
            result = bytearray()
            for operation, data in operations:
                storage = array(data)
                available_in, next_in = C.c_size_t(len(data)), C.cast(storage, U8)
                while True:
                    output = (C.c_uint8 * 4096)()
                    available_out, next_out = C.c_size_t(len(output)), C.cast(output, U8)
                    require(self.enc.BrotliEncoderCompressStream(state, operation, C.byref(available_in), C.byref(next_in), C.byref(available_out), C.byref(next_out), None), "reference encode")
                    result.extend(bytes(output[:len(output) - available_out.value]))
                    if available_in.value == 0 and not self.enc.BrotliEncoderHasMoreOutput(state):
                        break
            require(self.enc.BrotliEncoderIsFinished(state), "reference encoder finish")
            return bytes(result)
        finally:
            self.enc.BrotliEncoderDestroyInstance(state)
            if prepared:
                self.enc.BrotliEncoderDestroyPreparedDictionary(prepared)

    def decode(self, data, large=False, dictionary=None):
        state = self.dec.BrotliDecoderCreateInstance(None, None, None)
        require(state, "reference decoder state")
        keep = None
        try:
            if large:
                require(self.dec.BrotliDecoderSetParameter(state, 1, 1), "reference large window")
            if dictionary is not None:
                keep = array(dictionary)
                require(self.dec.BrotliDecoderAttachDictionary(state, 0, len(dictionary), keep), "reference decoder dictionary")
            storage = array(data)
            available_in, next_in = C.c_size_t(len(data)), C.cast(storage, U8)
            result = bytearray()
            while True:
                output = (C.c_uint8 * 4096)()
                available_out, next_out = C.c_size_t(len(output)), C.cast(output, U8)
                status = self.dec.BrotliDecoderDecompressStream(state, C.byref(available_in), C.byref(next_in), C.byref(available_out), C.byref(next_out), None)
                result.extend(bytes(output[:len(output) - available_out.value]))
                if status != 3:
                    return bytes(result), status, available_in.value
        finally:
            self.dec.BrotliDecoderDestroyInstance(state)

    def provenance(self):
        return {"encoder_version": hex(self.enc.BrotliEncoderVersion()), "decoder_version": hex(self.dec.BrotliDecoderVersion()),
                "library_directory": self.directory, "libraries": {k: {"path": p, "sha256": sha(Path(p).read_bytes()) if Path(p).is_file() else None} for k, p in self.paths.items()},
                "raw_dictionary_api": self.dictionaries}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", type=Path)
    parser.add_argument("--brotli-lib-dir", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--work-dir", type=Path)
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    require(args.prepare_only or args.probe, "--probe is required unless --prepare-only")
    probe = args.probe.resolve() if args.probe else None
    before = sources()
    driver_sha = sha(Path(__file__).read_bytes())
    ref = Brotli(args.brotli_lib_dir)
    tmp = tempfile.TemporaryDirectory(prefix="vort-br-contract-") if args.work_dir is None else None
    work = Path(tmp.name) if tmp else args.work_dir.resolve()
    work.mkdir(parents=True, exist_ok=True)
    rng = random.Random(0xB8071107)
    corpus, rows, cases, skipped = [], [], [], []

    def add(name, wire, data, source="libbrotli streaming encoder", **options):
        decoded, status, unused = ref.decode(wire, options.get("allow_large_window", False), options.get("dictionary"))
        require(status == 1 and unused == 0 and decoded == data, (name, "reference decode", status, len(decoded)))
        cases.append((name, wire, data, options))
        corpus.append({"name": name, "source": source, "compressed_bytes": len(wire), "output_bytes": len(data),
                       "compressed_sha256": sha(wire), "output_sha256": sha(data), "options": {k: sha(v) if isinstance(v, bytes) else v for k, v in options.items()}})

    payloads = [("empty", b""), ("tiny", b"hello brotli"), ("repetitive", b"bounded Brotli symbol state\n" * 1000),
                ("random", rng.randbytes(16387)), ("source", (ROOT / "src/root.zig").read_bytes()[:32768]),
                ("static-dictionary", b"transformation compression dictionary information encyclopedia\n" * 71)]
    for quality in (0, 5, 11):
        for name, data in payloads:
            add(f"{name}-q{quality}", ref.encode([(2, data)], quality), data, quality=quality, lgwin=16)
    data = payloads[2][1]
    metadata = b"resource-contract-metadata\0\xff"
    operations = [(0, data[:91]), (1, b""), (3, metadata), (0, data[91:1234]), (1, b""), (3, b""), (2, data[1234:])]
    add("flush-metadata-flush", ref.encode(operations), data, metadata=metadata)
    try:
        add("large-window25", ref.encode([(2, data)], lgwin=25, large=True), data, allow_large_window=True, lgwin=25)
    except (AssertionError, RuntimeError) as exc:
        skipped.append({"feature": "large-window", "reason": str(exc)})
    dictionary = rng.randbytes(8192)
    dictionary_path = work / "dictionary.raw"
    dictionary_path.write_bytes(dictionary)
    if ref.dictionaries:
        dict_data = dictionary[-3072:] + b"\0" * 41 + dictionary[-819:]
        add("raw-shared-dictionary", ref.encode([(2, dict_data)], dictionary=dictionary), dict_data, dictionary=dictionary)
    else:
        skipped.append({"feature": "RAW dictionaries", "reason": "loaded reference does not export prepared encoder/decoder dictionary APIs"})
    upstream = Path.home() / "Work/brotli/tests/testdata"
    for name in ("quickfox.compressed", "empty.compressed.18"):
        path = upstream / name
        if path.is_file():
            decoded, status, unused = ref.decode(path.read_bytes())
            if status == 1 and unused == 0:
                add(f"upstream-{name}", path.read_bytes(), decoded, source=str(path))

    def check(name, wire, expected_data, pattern="mixed", kind="owned", error=None, **options):
        index = len(rows)
        inp, expected, output, cfg = (work / f"{index}-{s}" for s in ("input.br", "expected", "output", "config.json"))
        inp.write_bytes(wire)
        expected.write_bytes(expected_data)
        config = {"kind": kind, "pattern": pattern, "max_history_len": max(1, len(expected_data)), "expected_output_len": len(expected_data),
                  "expect_failure": error is not None, **options}
        cfg.write_text(json.dumps(config) + "\n")
        try:
            result = json.loads(command(probe, inp, expected, output, cfg))
        except Exception as exc:
            raise RuntimeError(f"Brotli case {name}: {config}") from exc
        actual = output.read_bytes()
        require(actual == expected_data[:result["output_written"]], (name, kind, "published prefix"))
        require(result["snapshot"]["total_compressed"] == result["input_read"] + result["warmup_input_read"]
                and result["snapshot"]["total_output"] == len(actual) + result["warmup_output_written"], (name, kind, "total progress"))
        require(result["peak_working_bytes"] <= config.get("max_working_memory", 2**64 - 1), (name, "working limit"))
        if error is None:
            require(result["error"] is None and actual == expected_data, (name, kind, "decode"))
        else:
            require(result["error"] in ([error] if isinstance(error, str) else error), (name, error, result["error"]))
            require(result["sticky_checks"] > 0, (name, "sticky error"))
        rows.append({"name": name, "config": config, "compressed_sha256": sha(wire), "output_sha256": sha(actual), **result})
        return result

    if not args.prepare_only:
        for name, wire, expected_data, options in cases:
            cfg = {k: v for k, v in options.items() if k in ("allow_large_window",)}
            if "dictionary" in options:
                cfg["dictionary_path"] = str(dictionary_path)
            for kind in ("owned", "caller"):
                for pattern in ("one", "mixed", "wide"):
                    row = check(name, wire, expected_data, pattern, kind, **cfg)
                    if "metadata" in options:
                        require(row["metadata_hex"] == options["metadata"].hex() and sum(row["metadata_lengths"]) == len(options["metadata"])
                                and row["metadata_lengths"].count(0) >= 1, (name, kind, "metadata capture including empty flush blocks"))
        wire = next(w for n, w, _, _ in cases if n == "repetitive-q5")
        for name, wide_wire, wide_data, _ in cases:
            if name in ("repetitive-q5", "random-q5"):
                for kind in ("owned", "caller"):
                    zero = check(f"wide-zero-output-{name}", wide_wire, wide_data, "wide_zero", kind)
                    require(zero["zero_output_steps"] > 0, "wide input with zero/tiny output")
        empty_wire = next(w for n, w, _, _ in cases if n == "empty-q5")
        for kind in ("owned", "caller"):
            empty = check("empty-zero-resource", empty_wire, b"", kind=kind, max_output_len=0, max_total_output_len=0,
                          max_history_len=0, max_working_memory=0)
            require(empty["peak_working_bytes"] == 0 and empty["max_history_capacity"] == 0, "empty decode uses zero owned heap")
        history_prefix = rng.randbytes(8192)
        history_data = history_prefix * 2
        history_wire = ref.encode([(2, history_data)], quality=11)
        add("history-distance8192", history_wire, history_data)
        for kind in ("owned", "caller"):
            large = next((w for n, w, _, _ in cases if n == "large-window25"), None)
            if large is not None:
                check("large-window-strict-rejection", large, data, kind=kind, error="CorruptFrame")
            for pattern in ("one", "mixed", "wide"):
                check("history-exact", history_wire, history_data, pattern, kind, max_history_len=8192)
                check("history-below", history_wire, history_data, pattern, kind,
                      "OutputLimitExceeded" if kind == "owned" else "InvalidMatch", max_history_len=8191)
            check("reset-move", wire, data, kind=kind, reset_after=True, move_after_steps=7, oom=kind == "owned")
            for pattern in ("one", "mixed", "wide"):
                baseline = check("limits-baseline", wire, data, pattern, kind)
                check("output-exact", wire, data, pattern, kind, max_output_len=len(data))
                check("output-below", wire, data, pattern, kind, "OutputLimitExceeded", max_output_len=len(data) - 1, expected_output_len=None)
                check("total-output-exact", wire, data, pattern, kind, max_total_output_len=len(data))
                check("total-output-below", wire, data, pattern, kind, "OutputLimitExceeded", max_total_output_len=len(data) - 1, expected_output_len=None)
                if kind == "owned":
                    peak = baseline["peak_working_bytes"]
                    check("working-exact", wire, data, pattern, kind, max_working_memory=peak)
                    check("working-below", wire, data, pattern, kind, "WorkingMemoryLimitExceeded", max_working_memory=peak - 1)
                    check("compressed-exact", wire, data, pattern, kind, max_compressed_len=len(wire))
                    check("compressed-below", wire, data, pattern, kind, "OutputLimitExceeded", max_compressed_len=len(wire) - 1)
                    check("compressed-size-exact", wire, data, pattern, kind, expected_compressed_len=len(wire))
                    # A wide offer violates the declared size immediately;
                    # bytewise input can complete the declared member first,
                    # making the extra byte trailing input after implicit EOF.
                    check("compressed-size-below", wire, data, pattern, kind, ("SizeMismatch", "TrailingData"), expected_compressed_len=len(wire) - 1)
            second_data = b"next frame is bounded by operation total\n" * 51
            second = ref.encode([(2, second_data)])
            combined = wire + second
            cfg = {"frame_input_lengths": [len(wire), len(second)], "frame_output_lengths": [len(data), len(second_data)],
                   "check_next_frame_retry": kind == "owned", "next_frame_default_operation_caps": True, "expected_output_len": None}
            for pattern in ("one", "mixed", "wide"):
                total = len(data) + len(second_data)
                success = check("next-frame-total-exact", combined, data + second_data, pattern, kind, max_total_output_len=total, reset_after=True, **cfg)
                require(success["frames"] == 2, "next-frame count")
                check("next-frame-total-below", combined, data + second_data, pattern, kind, "OutputLimitExceeded", max_total_output_len=total - 1, **cfg)
            for cut in (0, 1, 2, len(wire) // 2, len(wire) - 1):
                for pattern in ("mixed", "wide"):
                    check(f"truncated-{cut}", wire[:cut], data, pattern, kind, "TruncatedFrame", expected_output_len=None)
            check("invalid-window", b"\x11\x00", b"", kind=kind, error=("CorruptFrame", "UnsupportedBrotliFeature"), expected_output_len=None)
        # This exceptional fixture reaches a legal entropy header >16 KiB.
        strong_path = work / "vort-diagnostic-large-header.br"
        command(probe, "--large-header", strong_path)
        strong = strong_path.read_bytes()
        add("diagnostic-large-header", strong, b"x", source="Explicit Vort diagnostic fixture, independently libbrotli decoded")
        warm_wire = ref.encode([(2, b"x")])
        add("public-header-warmup-small-frame", warm_wire, b"x")
        warm_path = work / "warmup-reference-x.br"
        warm_path.write_bytes(warm_wire)
        for pattern in ("one", "mixed", "wide"):
            # Allocation points are identical for this header across schedules.
            # Walk them once with wide input; retain all schedules for progress,
            # memory boundaries and caller-owned replacement.
            retained = {"warmup_stream_path": str(warm_path), "warmup_header_limit": 16385, "max_compressed_header_len": 32768}
            base = check("large-header-public-warmup-grow", strong, b"x", pattern, oom=pattern == "wide", move_after_steps=7, **retained)
            require(base["max_owned_header_capacity"] > 16384 and base["peak_working_bytes"] > base["max_owned_header_capacity"] + base["max_history_capacity"], "simultaneously live header replacement accounting")
            require(base["warmup_input_read"] == len(warm_wire) and base["warmup_output_written"] == 1 and base["reset_checks"] == 1,
                    "public reset/nextFrame warmup retains owned header")
            if pattern != "one":
                check("large-header-working-exact", strong, b"x", pattern, max_working_memory=base["peak_working_bytes"], **retained)
                check("large-header-working-below", strong, b"x", pattern, error="WorkingMemoryLimitExceeded", max_working_memory=base["peak_working_bytes"] - 1, **retained)
                check("large-header-max-below", strong, b"x", pattern, error="OutputLimitExceeded", max_compressed_header_len=16384)
                check("large-header-caller-scratch", strong, b"x", pattern, "caller", header_scratch_len=len(strong), move_after_steps=7)
            retry = check("large-header-caller-grow-retry", strong, b"x", pattern, "caller", grow_header_on_exhaustion=True,
                          retry_header_scratch_len=len(strong), reset_after=pattern == "wide", move_after_steps=7)
            require(retry["header_retry_checks"] == 1, "caller-header replacement without replay")
            if pattern != "one":
                check("large-header-caller-no-scratch", strong, b"x", pattern, "caller", "UnsupportedBrotliFeature")
        for pattern in ("mixed", "wide"):
            corrupted = strong[:-1] + bytes([strong[-1] | 0x80])
            _, status, _ = ref.decode(corrupted)
            if status != 1:
                check("corrupt-header-trailer", corrupted, b"x", pattern, error=("CorruptFrame", "TruncatedFrame", "InvalidHuffmanCode"))
        # A header buffer ending just past the header/payload boundary must
        # parse its last bounded batch before declaring resource exhaustion.
        # Otherwise a retry can attempt to unread bytes accepted in an earlier
        # call. A reference decoder verifies the exact first-frame/tail split.
        tail = bytes(range(32))
        decoded, status, unused = ref.decode(strong + tail)
        require(decoded == b"x" and status == 1 and unused == len(tail), "reference header-boundary tail")
        for capacity in (len(strong) - 1, len(strong), len(strong) + 1, len(strong) + 15):
            for pattern in ("wide", "wide_zero"):
                boundary = check(f"caller-header-boundary-{capacity}", strong + tail, b"x", pattern, "caller",
                                 allow_trailing_data=True, header_scratch_len=capacity, grow_header_on_exhaustion=True,
                                 retry_header_scratch_len=len(strong) + len(tail))
                retained_tail = bytes.fromhex(boundary["trailing_hex"])
                require(retained_tail + (strong + tail)[boundary["input_read"]:] == tail, "header-boundary tail content and progress")
                if capacity >= len(strong):
                    require(boundary["header_retry_checks"] == 0, "complete bounded header must parse before grow/retry")
    require(before == sources(), "codec sources changed during differential; rebuild and rerun after source freeze")
    require(driver_sha == sha(Path(__file__).read_bytes()), "driver changed during differential; rerun after source freeze")
    report = {"schema": "vort.brotli_stream_contracts", "schema_version": 1,
              "status": "reference_prepared" if args.prepare_only else "ok", "utc": datetime.now(timezone.utc).isoformat(),
              "python": sys.version, "zig": command("zig", "version").decode().strip(), "cpu": cpu(), "build_mode": rows[0]["build_mode"] if rows else None,
              "command": sys.argv, "probe": str(probe) if probe else None, "probe_sha256": sha(probe.read_bytes()) if probe else None,
              "driver_sha256": driver_sha, "sources": before, "reference": ref.provenance(), "corpus": corpus, "skipped": skipped,
              "git_head": command("git", "rev-parse", "HEAD").decode().strip(),
              "cases": rows, "summary": {"corpus_streams": len(corpus), "runs": len(rows), "errors": dict(Counter(r["error"] for r in rows if r["error"])),
                                        "oom_failure_cases": sum(r["oom_failure_cases"] for r in rows)}}
    if args.report:
        args.report.resolve().parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], **report["summary"]}, sort_keys=True))
    if tmp:
        tmp.cleanup()


if __name__ == "__main__":
    main()
