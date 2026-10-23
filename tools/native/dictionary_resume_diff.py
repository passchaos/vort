#!/usr/bin/env python3
"""Independent libzstd/liblz4 dictionary-resume wire and progress differential."""
import argparse
from collections import Counter
from contextlib import nullcontext
import ctypes as C
import ctypes.util
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import random
import re
import struct
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def require(condition, context):
    if not condition:
        raise AssertionError(context)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def run(*args):
    result = subprocess.run([str(arg) for arg in args], cwd=ROOT, capture_output=True)
    if result.returncode:
        raise RuntimeError(f"command failed: {' '.join(map(str, args))}\n{result.stderr.decode(errors='replace')}")
    return result


def bind(lib, name, result, *arguments):
    function = getattr(lib, name)
    function.restype, function.argtypes = result, list(arguments)
    return function


class Zstd:
    def __init__(self):
        self.lib = C.CDLL(ctypes.util.find_library("zstd"))
        self.version = bind(self.lib, "ZSTD_versionString", C.c_char_p)().decode()
        self.error = bind(self.lib, "ZSTD_isError", C.c_uint, C.c_size_t)
        self.error_name = bind(self.lib, "ZSTD_getErrorName", C.c_char_p, C.c_size_t)
        self.bound = bind(self.lib, "ZSTD_compressBound", C.c_size_t, C.c_size_t)
        self.create = bind(self.lib, "ZSTD_createCCtx", C.c_void_p)
        self.free = bind(self.lib, "ZSTD_freeCCtx", C.c_size_t, C.c_void_p)
        self.parameter = bind(self.lib, "ZSTD_CCtx_setParameter", C.c_size_t, C.c_void_p, C.c_int, C.c_int)
        self.load = bind(self.lib, "ZSTD_CCtx_loadDictionary", C.c_size_t, C.c_void_p, C.c_void_p, C.c_size_t)
        self.compress = bind(self.lib, "ZSTD_compress2", C.c_size_t, C.c_void_p, C.c_void_p, C.c_size_t, C.c_void_p, C.c_size_t)
        self.dcreate = bind(self.lib, "ZSTD_createDCtx", C.c_void_p)
        self.dfree = bind(self.lib, "ZSTD_freeDCtx", C.c_size_t, C.c_void_p)
        self.decode = bind(self.lib, "ZSTD_decompress_usingDict", C.c_size_t, C.c_void_p, C.c_void_p, C.c_size_t,
                           C.c_void_p, C.c_size_t, C.c_void_p, C.c_size_t)
        self.train = bind(self.lib, "ZDICT_trainFromBuffer", C.c_size_t, C.c_void_p, C.c_size_t, C.c_void_p,
                          C.POINTER(C.c_size_t), C.c_uint)
        self.dict_header = bind(self.lib, "ZDICT_getDictHeaderSize", C.c_size_t, C.c_void_p, C.c_size_t)

    def check(self, value):
        require(not self.error(value), self.error_name(value).decode())
        return value

    def train_dictionary(self, samples):
        combined = b"".join(samples)
        sizes = (C.c_size_t * len(samples))(*map(len, samples))
        output = C.create_string_buffer(4096)
        size = self.check(self.train(output, len(output), combined, sizes, len(samples)))
        return output.raw[:size]

    def encode(self, payload, dictionary=b"", size=True, checksum=True, window=17):
        context = self.create()
        require(context, "ZSTD_createCCtx")
        try:
            for key, value in ((100, 3), (101, window), (200, int(size)), (201, int(checksum)), (202, 1)):
                self.check(self.parameter(context, key, value))
            self.check(self.load(context, dictionary, len(dictionary)))
            output = C.create_string_buffer(self.bound(len(payload)))
            length = self.check(self.compress(context, output, len(output), payload, len(payload)))
            return output.raw[:length]
        finally:
            self.free(context)

    def verify(self, frame, payload, dictionary):
        context = self.dcreate()
        require(context, "ZSTD_createDCtx")
        try:
            output = C.create_string_buffer(max(1, len(payload)))
            size = self.check(self.decode(context, output, len(output), frame, len(frame), dictionary, len(dictionary)))
            require(output.raw[:size] == payload, "libzstd dictionary decode")
        finally:
            self.dfree(context)


class FrameInfo(C.Structure):
    _fields_ = [("block_size", C.c_int), ("block_mode", C.c_int), ("content_check", C.c_int), ("frame_type", C.c_int),
                ("content_size", C.c_ulonglong), ("dictionary_id", C.c_uint), ("block_check", C.c_int)]


class Preferences(C.Structure):
    _fields_ = [("frame", FrameInfo), ("level", C.c_int), ("auto_flush", C.c_uint), ("favor_decode", C.c_uint),
                ("reserved", C.c_uint * 3)]


class Lz4:
    def __init__(self):
        self.lib = C.CDLL(ctypes.util.find_library("lz4"))
        self.version = bind(self.lib, "LZ4_versionString", C.c_char_p)().decode()
        self.error = bind(self.lib, "LZ4F_isError", C.c_uint, C.c_size_t)
        self.error_name = bind(self.lib, "LZ4F_getErrorName", C.c_char_p, C.c_size_t)
        self.bound = bind(self.lib, "LZ4F_compressFrameBound", C.c_size_t, C.c_size_t, C.POINTER(Preferences))
        self.create = bind(self.lib, "LZ4F_createCompressionContext", C.c_size_t, C.POINTER(C.c_void_p), C.c_uint)
        self.free = bind(self.lib, "LZ4F_freeCompressionContext", C.c_size_t, C.c_void_p)
        self.cdict = bind(self.lib, "LZ4F_createCDict", C.c_void_p, C.c_void_p, C.c_size_t)
        self.cdict_free = bind(self.lib, "LZ4F_freeCDict", None, C.c_void_p)
        self.compress = bind(self.lib, "LZ4F_compressFrame_usingCDict", C.c_size_t, C.c_void_p, C.c_void_p,
                             C.c_size_t, C.c_void_p, C.c_size_t, C.c_void_p, C.POINTER(Preferences))
        self.dcreate = bind(self.lib, "LZ4F_createDecompressionContext", C.c_size_t, C.POINTER(C.c_void_p), C.c_uint)
        self.dfree = bind(self.lib, "LZ4F_freeDecompressionContext", C.c_size_t, C.c_void_p)
        self.decode = bind(self.lib, "LZ4F_decompress_usingDict", C.c_size_t, C.c_void_p, C.c_void_p,
                           C.POINTER(C.c_size_t), C.c_void_p, C.POINTER(C.c_size_t), C.c_void_p, C.c_size_t, C.c_void_p)

    def check(self, value):
        require(not self.error(value), self.error_name(value).decode())
        return value

    def encode(self, payload, dictionary, id_, independent=False, size=True, block_check=False, content_check=True):
        preferences = Preferences(FrameInfo(4, int(independent), int(content_check), 0, len(payload) if size else 0,
                                            id_, int(block_check)), 9, 0, 0, (C.c_uint * 3)())
        context = C.c_void_p()
        self.check(self.create(C.byref(context), 100))
        cdict = self.cdict(dictionary, len(dictionary))
        require(cdict, "LZ4F_createCDict")
        try:
            output = C.create_string_buffer(self.bound(len(payload), C.byref(preferences)))
            length = self.check(self.compress(context, output, len(output), payload, len(payload), cdict, C.byref(preferences)))
            return output.raw[:length]
        finally:
            self.cdict_free(cdict)
            self.free(context)

    def verify(self, frame, payload, dictionary):
        context = C.c_void_p()
        self.check(self.dcreate(C.byref(context), 100))
        try:
            output = C.create_string_buffer(max(1, len(payload)) + 16)
            source_size, output_size = C.c_size_t(len(frame)), C.c_size_t(len(output))
            remaining = self.check(self.decode(context, output, C.byref(output_size), frame, C.byref(source_size),
                                               dictionary, len(dictionary), None))
            require(remaining == 0 and source_size.value == len(frame) and output.raw[:output_size.value] == payload,
                    "liblz4 dictionary decode")
        finally:
            self.dfree(context)


def zstd_id(frame):
    descriptor = frame[4]
    width = (0, 1, 2, 4)[descriptor & 3]
    start = 5 + int(not descriptor & 32)
    return int.from_bytes(frame[start:start + width], "little") if width else 0


def header_size(codec, frame):
    if codec == "lz4":
        return 7 + (8 if frame[4] & 8 else 0) + (4 if frame[4] & 1 else 0)
    descriptor = frame[4]
    single = bool(descriptor & 32)
    fcs = (1 if single else 0, 2, 4, 8)[descriptor >> 6]
    return 5 + int(not single) + (0, 1, 2, 4)[descriptor & 3] + fcs


def insert_raw_id(frame, id_):
    require(frame[4] & 3 == 0, "raw-content libzstd has no dictionary ID")
    position = 5 + int(not frame[4] & 32)
    patched = bytearray(frame[:position] + struct.pack("<I", id_) + frame[position:])
    patched[4] |= 3
    return bytes(patched)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zstd-probe", type=Path, required=True)
    parser.add_argument("--lz4-probe", type=Path, required=True)
    parser.add_argument("--zig", type=Path, default=Path("/home/passchaos/Temp/zig-x86_64-linux-0.16.0/zig"))
    parser.add_argument("--zstd-helper-object", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--work-dir", type=Path)
    args = parser.parse_args()
    args.zstd_probe, args.lz4_probe, args.zig = args.zstd_probe.resolve(), args.lz4_probe.resolve(), args.zig.resolve()
    if args.work_dir:
        args.work_dir = args.work_dir.resolve()
        args.work_dir.mkdir(parents=True, exist_ok=True)
        require(not any(args.work_dir.iterdir()), "--work-dir must be empty")
    workspace = nullcontext(str(args.work_dir)) if args.work_dir else tempfile.TemporaryDirectory(prefix="vort-native-dictionary-")
    rng = random.Random(0xD1C7A)
    zstd, lz4 = Zstd(), Lz4()
    samples = [f'{{"id":{i},"type":"native_dictionary","bucket":{i % 31},"log":"resume header then payload"}}\n'.encode()
               * 8 + rng.randbytes(57) for i in range(100)]
    full = zstd.train_dictionary(samples)
    full_id = int.from_bytes(full[4:8], "little")
    raw_dictionary = rng.randbytes(65536)
    raw_id = 0x54A71D01
    full_header_size = zstd.check(zstd.dict_header(full, len(full)))
    raw_reference_header = bytearray(full[:full_header_size])
    raw_reference_header[4:8] = struct.pack("<I", raw_id)
    raw_reference_header[-12:] = struct.pack("<III", 1, 4, 8)
    raw_reference_dictionary = bytes(raw_reference_header) + raw_dictionary
    dictionaries = {"full": (full_id, full, True), "raw": (raw_id, raw_dictionary, False),
                    "lz4": (0x1A4D1C7, raw_dictionary, False)}
    for name, id_ in (("full-id8", 201), ("full-id16", 65000)):
        modified = bytearray(full)
        modified[4:8] = struct.pack("<I", id_)
        dictionaries[name] = (id_, bytes(modified), True)
    rows, cases = [], []
    with workspace as directory:
        temp = Path(directory)
        dictionary_configs = {}
        for name, (id_, data, full_) in dictionaries.items():
            path = temp / f"dictionary-{name}"
            path.write_bytes(data)
            dictionary_configs[name] = {"id": id_, "path": str(path), "full": full_}
        (temp / "dictionary-raw-reference-full").write_bytes(raw_reference_dictionary)
        full_payload = samples[7] + samples[13] + samples[17] + samples[7]
        raw_payload = raw_dictionary[-4096:] + b"native raw dictionary payload\n" * 100 + raw_dictionary[1000:4000]
        for name, payload, reference_dict in (("full", full_payload, full), ("raw", raw_payload, raw_reference_dictionary)):
            for content_size in (False, True):
                for checksum in (False, True):
                    for window in (14, 17):
                        dictionary = dictionaries[name][1]
                        frame = zstd.encode(payload, dictionary, content_size, checksum, window)
                        if name == "raw":
                            frame = insert_raw_id(frame, raw_id)
                        require(zstd_id(frame) == dictionaries[name][0], "nonzero Zstd dictionary ID")
                        zstd.verify(frame, payload, reference_dict)
                        cases.append(("zstd", f"{name}-size{int(content_size)}-check{int(checksum)}-window{window}", frame,
                                      payload, name, checksum))
        for name, dictionary, reference in (("full", full, full), ("raw", raw_dictionary, raw_reference_dictionary)):
            frame = zstd.encode(b"", dictionary)
            if name == "raw":
                frame = insert_raw_id(frame, raw_id)
            zstd.verify(frame, b"", reference)
            cases.append(("zstd", f"empty-{name}", frame, b"", name, True))
        for name in ("full-id8", "full-id16"):
            dictionary = dictionaries[name][1]
            frame = zstd.encode(full_payload, dictionary)
            zstd.verify(frame, full_payload, dictionary)
            cases.append(("zstd", name, frame, full_payload, name, True))
        for independent in (False, True):
            for size in (False, True):
                for block_check in (False, True):
                    for content_check in (False, True):
                        payload = raw_payload * 8
                        frame = lz4.encode(payload, raw_dictionary, dictionaries["lz4"][0], independent, size, block_check, content_check)
                        lz4.verify(frame, payload, raw_dictionary)
                        cases.append(("lz4", f"CDict-independent{int(independent)}-size{int(size)}-block{int(block_check)}-content{int(content_check)}",
                                      frame, payload, "lz4", content_check))
        for independent in (False, True):
            frame = lz4.encode(b"", raw_dictionary, dictionaries["lz4"][0], independent, False, True, True)
            lz4.verify(frame, b"", raw_dictionary)
            cases.append(("lz4", f"empty-independent{int(independent)}", frame, b"", "lz4", True))

        def check(codec, name, frame, payload, dictionary_names, pattern="mixed", initializer="missing", **extra):
            index = len(rows)
            paths = [temp / f"case-{index}-{suffix}" for suffix in ("input", "expected", "output", "config.json")]
            paths[0].write_bytes(frame)
            paths[1].write_bytes(payload)
            config = {"pattern": pattern, "initializer": initializer,
                      "dictionaries": [dictionary_configs[name] for name in dictionary_names], **extra}
            paths[3].write_text(json.dumps(config) + "\n")
            probe = args.zstd_probe if codec == "zstd" else args.lz4_probe
            stats = json.loads(run(probe, *paths).stdout)
            require(paths[2].read_bytes() == payload[:stats["output_written"]], (name, "published output prefix"))
            if extra.get("expected_error"):
                require(stats["error"] == extra["expected_error"], (name, "exact fatal error", stats))
            else:
                require(stats["error"] is None and paths[2].read_bytes() == payload, (name, "resumed decode"))
            require(stats["input_received"] == stats["snapshot"]["input_received"]
                    and stats["output_written"] == stats["snapshot"]["output_written"], (name, "snapshot accounting"))
            if initializer in ("missing", "wrong", "set-miss"):
                require(stats["requests"], (name, "dictionary pause must occur"))
            for request in stats["requests"]:
                require(request["id"] in {dictionaries[name][0] for name in dictionary_names}, (name, "required ID"))
                require(request["wrong_id_checks"] == 2, (name, "wrong dictionary/set ID rejection"))
                require(request["set_miss_error"] == "NeedDictionary", (name, "dictionary-set miss preserves wait"))
                require(request["finish_error"] == "NeedDictionary", (name, "finish preserves wait"))
            rows.append({"case_index": index, "codec": codec, "case": name, "config": config,
                         "input_bytes": len(frame), "expected_bytes": len(payload), "input_sha256": digest(frame),
                         "expected_sha256": digest(payload), "output_sha256": digest(paths[2].read_bytes()), **stats})
            return stats

        for codec, name, frame, payload, dictionary_name, checksum in cases:
            for policy in ("block_stream", "prevalidated_frame"):
                for pattern in ("one", "mixed", "full"):
                    stats = check(codec, name, frame, payload, [dictionary_name], pattern, policy=policy)
                    if pattern == "one":
                        require(stats["requests"][0]["input_offset"] == header_size(codec, frame),
                                (name, "bytewise request after header, before payload"))
            print(f"native dictionary {codec}/{name} checks={len(rows)} reference=ok", flush=True)
        for codec in ("zstd", "lz4"):
            selected = next(case for case in cases if case[0] == codec and case[5])
            _, name, frame, payload, dictionary_name, _ = selected
            for initializer in ("correct", "set-hit", "set-miss", "wrong"):
                check(codec, f"{name}-{initializer}", frame, payload, [dictionary_name], initializer=initializer)
            check(codec, f"{name}-provide-set", frame, payload, [dictionary_name], provide_set=True)
            check(codec, f"{name}-reset", frame, payload, [dictionary_name], reset_after=True)
            check(codec, f"{name}-limits", frame, payload, [dictionary_name], check_limits=True)
            check(codec, f"{name}-OOM", frame, payload, [dictionary_name], oom=True)
            check(codec, f"{name}-output-limit", frame, payload, [dictionary_name], max_output_len=len(payload) - 1,
                  expected_error="OutputLimitExceeded")
            corrupt = bytearray(frame)
            corrupt[-1] ^= 1
            check(codec, f"{name}-fatal-checksum", bytes(corrupt), payload, [dictionary_name], "full", expected_error="ChecksumMismatch")
            check(codec, f"{name}-truncated", frame[:-1], payload, [dictionary_name], expected_error="TruncatedFrame")
            previous_payload = b"previous frame output\n" * 8
            previous = zstd.encode(previous_payload) if codec == "zstd" else lz4.encode(previous_payload, b"", 0)
            (zstd if codec == "zstd" else lz4).verify(previous, previous_payload, b"")
            concatenated = previous + frame + frame
            for policy in ("block_stream", "prevalidated_frame"):
                stats = check(codec, f"{name}-concatenated", concatenated, previous_payload + payload * 2,
                              [dictionary_name], "full", policy=policy)
                require(len(stats["requests"]) == 2 and stats["requests"][0]["output_offset"] == len(previous_payload),
                        (name, "prior member publication and override expiry"))
                check(codec, f"{name}-stop-next", concatenated, previous_payload + payload * 2, [dictionary_name], "full",
                      policy=policy, stop_next=True)
            check(codec, f"{name}-cumulative-limit", concatenated, previous_payload + payload * 2,
                  [dictionary_name], "full", stop_next=True, max_output_len=len(previous_payload) + len(payload) * 2 - 1,
                  expected_error="OutputLimitExceeded")
            check(codec, f"{name}-prevalidated-provide-set", frame, payload, [dictionary_name],
                  policy="prevalidated_frame", provide_set=True)
            check(codec, f"{name}-prevalidated-limits", frame, payload, [dictionary_name],
                  policy="prevalidated_frame", check_limits=True)
            check(codec, f"{name}-prevalidated-OOM", frame, payload, [dictionary_name],
                  policy="prevalidated_frame", oom=True)
            check(codec, f"{name}-prevalidated-checksum", bytes(corrupt), payload, [dictionary_name], "full",
                  policy="prevalidated_frame", expected_error="ChecksumMismatch")
            check(codec, f"{name}-prevalidated-cumulative-limit", concatenated, previous_payload + payload * 2,
                  [dictionary_name], "full", policy="prevalidated_frame", stop_next=True,
                  max_output_len=len(previous_payload) + len(payload) * 2 - 1, expected_error="OutputLimitExceeded")
        full_case = next(case for case in cases if case[0] == "zstd" and case[4] == "full")
        metadata_check = check("zstd", "correct-ID-malformed-full-metadata", full_case[2], full_case[3], ["full"], bad_metadata=True)
        require(metadata_check["requests"][0]["metadata_rejections"] == 1, "invalid full metadata preserves dictionary request")
        cpu_match = re.search(r"^model name\s*:\s*(.+)$", Path("/proc/cpuinfo").read_text(), re.MULTILINE)
        mapped = Path("/proc/self/maps").read_text().splitlines()
        reference_paths = {name: next(Path(line.split()[-1]).resolve() for line in mapped if f"/{name}.so" in line)
                           for name in ("libzstd", "liblz4")}
        requests = [request for row in rows for request in row["requests"]]
        report = {"schema": "vort-native-dictionary-resume-v1", "claim": "independent wire/dictionary recovery/progress/memory correctness; no throughput claim",
                  "created_utc": datetime.now(timezone.utc).isoformat(), "cpu": cpu_match.group(1) if cpu_match else platform.processor(),
                  "platform": platform.platform(), "invocation": sys.argv, "python_version": sys.version,
                  "zig_version": run(args.zig, "version").stdout.decode().strip(), "zig_sha256": digest(args.zig.read_bytes()),
                  "probe_build": "ReleaseFast; independent zstd/lz4 modules; optional Zstd X2 object",
                  "zstd_helper_object_sha256": digest(args.zstd_helper_object.read_bytes()) if args.zstd_helper_object else None,
                  "references": {name: {"version": object_.version, "library": str(reference_paths[name]),
                                        "sha256": digest(reference_paths[name].read_bytes())}
                                 for name, object_ in (("libzstd", zstd), ("liblz4", lz4))},
                  "raw_content_frame_method": "libzstd raw-content compression; explicit ID inserted in header; reference decoding with trained entropy-header wrapper and repcodes 1/4/8 plus identical history",
                  "raw_reference_dictionary_sha256": digest(raw_reference_dictionary), "full_dictionary_header_bytes": full_header_size,
                  "dictionaries": {name: {"id": id_, "full": full_, "bytes": len(data), "sha256": digest(data)}
                                   for name, (id_, data, full_) in dictionaries.items()},
                  "probe_sha256": {"zstd": digest(args.zstd_probe.read_bytes()), "lz4": digest(args.lz4_probe.read_bytes())},
                  "repository_commit": run("git", "rev-parse", "HEAD").stdout.decode().strip(),
                  "source_sha256": {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in
                                    [ROOT / "src/core.zig", ROOT / "src/zstd.zig", ROOT / "src/lz4.zig", ROOT / "src/checksum.zig",
                                     ROOT / "src/dictionary.zig", ROOT / "src/lz77.zig", ROOT / "src/io/working_allocator.zig", ROOT / "src/zstd_huffman_x2_object.zig",
                                     *sorted((ROOT / "src/zstd").rglob("*.zig")), *sorted((ROOT / "src/lz4").rglob("*.zig")),
                                     ROOT / "tools/native/dictionary_resume_probe.zig", Path(__file__).resolve()]},
                  "corpus_frames": len(cases), "dictionary_requests": len(requests),
                  "one_shot_reference_cases": len(cases), "rows": rows}
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, indent=2) + "\n")
        print(f"native_dictionary_resume_cases={len(rows)} corpus={len(cases)} requests={len(requests)} "
              f"codecs={dict(Counter(row['codec'] for row in rows))} libzstd={zstd.version} liblz4={lz4.version}")


if __name__ == "__main__":
    main()
