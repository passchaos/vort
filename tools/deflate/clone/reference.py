#!/usr/bin/env python3
"""Native libz deflateCopy/inflateCopy oracle, independent of vort wire bytes.

Run with --input-dir (manifest.json) and --output-dir. The manifest is either a
case list or {"cases": [...]}. Paths are relative to the input directory. Cases
use name, format, prefix_path, tail_a_path, tail_b_path, optional dictionary_path,
window_bits (9 or 15), level, strategy, flush, and copy_output_capacity. Optional
copy_stage="header" copies after the first encoder call, before consuming the
prefix; otherwise the complete prefix is consumed before copying. Optional
params_level/params_strategy request deflateParams immediately before copying.
Combining copy_stage="header" and a changed level/strategy in a wrapped stream
forces an explicitly queued (Z_BUF_ERROR) parameter change on zlib 1.2.11.

The reusable decode_wire(wire, format, window_bits=15, dictionary=None,
library=None) returns (complete_plaintext, receipt). library may be a path or a
ZlibLibrary instance. All input and output bytes are checked, including trailers.
"""

import argparse
import ctypes as C
import ctypes.util
import hashlib
import json
from pathlib import Path
import re
import zlib


OK, END, NEED_DICT, BUF_ERROR = 0, 1, 2, -5
NO_FLUSH, FINISH = 0, 4
FLUSHES = {"none": 0, "partial": 1, "sync": 2, "full": 3, "block": 5}
CHUNK = 65536


def require(condition, detail):
    if not condition:
        raise AssertionError(detail)


def digest(data):
    return {"size": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "crc32": zlib.crc32(data) & 0xffffffff,
            "adler32": zlib.adler32(data) & 0xffffffff}


def wbits(format, window_bits):
    require(format in ("raw", "zlib", "gzip"), "unsupported format")
    require(window_bits in (9, 15), "window_bits must be 9 or 15")
    return -window_bits if format == "raw" else window_bits + (16 if format == "gzip" else 0)


class ZStream(C.Structure):
    _fields_ = [("next_in", C.c_void_p), ("avail_in", C.c_uint),
                ("total_in", C.c_ulong), ("next_out", C.c_void_p),
                ("avail_out", C.c_uint), ("total_out", C.c_ulong),
                ("msg", C.c_char_p), ("state", C.c_void_p),
                ("zalloc", C.c_void_p), ("zfree", C.c_void_p),
                ("opaque", C.c_void_p), ("data_type", C.c_int),
                ("adler", C.c_ulong), ("reserved", C.c_ulong)]


def library_path(handle):
    """Resolve the actual loaded file, including SONAME symlinks, for hashing."""
    class DlInfo(C.Structure):
        _fields_ = [("filename", C.c_char_p), ("base", C.c_void_p),
                    ("symbol", C.c_char_p), ("address", C.c_void_p)]
    try:
        process = C.CDLL(None)
        process.dladdr.argtypes = [C.c_void_p, C.POINTER(DlInfo)]
        process.dladdr.restype = C.c_int
        info = DlInfo()
        if process.dladdr(C.cast(handle.zlibVersion, C.c_void_p), C.byref(info)):
            return Path(info.filename.decode()).resolve()
    except (AttributeError, OSError):
        pass
    candidate = Path(handle._name)
    require(candidate.is_file(), "cannot resolve loaded libz file for its SHA-256")
    return candidate.resolve()


class ZlibLibrary:
    def __init__(self, path=None):
        self.handle = C.CDLL(str(path) if path else ctypes.util.find_library("z") or "libz.so.1")
        self._bind("zlibVersion", [], C.c_char_p)
        self.version = self.handle.zlibVersion()
        pointer = C.POINTER(ZStream)
        self._bind("deflateInit2_", [pointer, C.c_int, C.c_int, C.c_int,
                                    C.c_int, C.c_int, C.c_char_p, C.c_int])
        self._bind("inflateInit2_", [pointer, C.c_int, C.c_char_p, C.c_int])
        for family in ("deflate", "inflate"):
            self._bind(family, [pointer, C.c_int])
            self._bind(family + "End", [pointer])
            self._bind(family + "Copy", [pointer, pointer])
            self._bind(family + "SetDictionary", [pointer, C.c_void_p, C.c_uint])
        self._bind("deflatePending", [pointer, C.POINTER(C.c_uint), C.POINTER(C.c_int)])
        self._bind("deflateParams", [pointer, C.c_int, C.c_int])
        actual_path = library_path(self.handle)
        self.receipt = {"path": str(actual_path), "version": self.version.decode(),
                        "sha256": hashlib.sha256(actual_path.read_bytes()).hexdigest(),
                        "z_stream_size": C.sizeof(ZStream),
                        "python_zlib_compile_version": zlib.ZLIB_VERSION,
                        "python_zlib_runtime_version": zlib.ZLIB_RUNTIME_VERSION}

    def _bind(self, name, arguments, returns=C.c_int):
        function = getattr(self.handle, name)
        function.argtypes, function.restype = arguments, returns


class Stream:
    """Own z_stream and keep copied next_in/next_out storage alive explicitly."""
    def __init__(self, library, family, bits, level=6, strategy=0, dictionary=None):
        self.library, self.family = library, family
        self.state = ZStream()
        self.input_buffer = self.output_buffer = None
        self.calls = self.input_consumed = self.output_produced = 0
        self.dictionary = dictionary
        self.dictionary_set = False
        self.eof = self.closed = False
        self.last_code = OK
        if family == "deflate":
            code = library.handle.deflateInit2_(C.byref(self.state), level, 8, bits,
                                               8, strategy, library.version, C.sizeof(ZStream))
        else:
            code = library.handle.inflateInit2_(C.byref(self.state), bits,
                                               library.version, C.sizeof(ZStream))
        require(code == OK, f"{family}Init2: {code}")
        try:
            if dictionary is not None and (family == "deflate" or bits < 0):
                self.set_dictionary()
        except Exception:
            self.close()
            raise

    def set_dictionary(self):
        require(self.dictionary is not None, "stream requests an absent dictionary")
        buffer = C.create_string_buffer(self.dictionary)
        code = getattr(self.library.handle, self.family + "SetDictionary")(
            C.byref(self.state), C.cast(buffer, C.c_void_p), len(self.dictionary))
        require(code == OK, f"{self.family}SetDictionary: {code}")
        self.dictionary_set = True

    def feed(self, data):
        require(not self.state.avail_in, "replacing unconsumed input")
        require(len(data) <= 0xffffffff, "input chunk exceeds libz uInt")
        self.input_buffer = C.create_string_buffer(data)
        self.state.next_in = C.cast(self.input_buffer, C.c_void_p)
        self.state.avail_in = len(data)

    def _output(self, capacity):
        require(0 < capacity <= CHUNK, "output capacity outside 1..65536")
        self.output_buffer = C.create_string_buffer(capacity)
        self.state.next_out = C.cast(self.output_buffer, C.c_void_p)
        self.state.avail_out = capacity

    def _receipt(self, before, capacity, code):
        consumed = before - self.state.avail_in
        produced = capacity - self.state.avail_out
        self.input_consumed += consumed
        self.output_produced += produced
        self.calls += 1
        self.last_code = code
        output = self.output_buffer.raw[:produced]
        return code, output, consumed

    def step(self, flush=NO_FLUSH, capacity=CHUNK):
        require(not self.closed and not self.eof, "using ended stream")
        self._output(capacity)
        before = self.state.avail_in
        code = getattr(self.library.handle, self.family)(C.byref(self.state), flush)
        result = self._receipt(before, capacity, code)
        if code == NEED_DICT and self.family == "inflate":
            self.set_dictionary()
        else:
            require(code in (OK, END, BUF_ERROR),
                    f"{self.family}: {code}, {self.state.msg!r}")
        self.eof = code == END
        return result

    def params(self, level, strategy, capacity=CHUNK):
        self._output(capacity)
        before = self.state.avail_in
        code = self.library.handle.deflateParams(C.byref(self.state), level, strategy)
        result = self._receipt(before, capacity, code)
        require(code in (OK, BUF_ERROR), f"deflateParams: {code}")
        return result

    def copy(self):
        require(not self.closed, "copying a destroyed source")
        clone = object.__new__(Stream)
        clone.__dict__ = self.__dict__.copy()
        clone.state = ZStream()
        clone.closed = False
        code = getattr(self.library.handle, self.family + "Copy")(
            C.byref(clone.state), C.byref(self.state))
        require(code == OK, f"{self.family}Copy: {code}")
        return clone

    def snapshot(self):
        result = {key: int(getattr(self.state, key)) for key in
                  ("total_in", "total_out", "avail_in", "avail_out", "adler", "data_type")}
        result.update(input_consumed=self.input_consumed, output_produced=self.output_produced,
                      calls=self.calls, eof=self.eof, dictionary_set=self.dictionary_set,
                      last_code=self.last_code)
        if self.family == "deflate":
            pending, bits = C.c_uint(), C.c_int()
            code = self.library.handle.deflatePending(C.byref(self.state), C.byref(pending), C.byref(bits))
            require(code == OK, f"deflatePending: {code}")
            result.update(pending_bytes=pending.value, pending_bits=bits.value)
        return result

    def close(self):
        if not self.closed:
            code = getattr(self.library.handle, self.family + "End")(C.byref(self.state))
            # Ending a live compressor deliberately returns Z_DATA_ERROR (-3).
            require(code in (OK, -3) if self.family == "deflate" else code == OK,
                    f"{self.family}End: {code}")
            self.closed = True


def drain(stream, flush=NO_FLUSH, capacity=CHUNK):
    output = bytearray()
    while not stream.eof:
        code, piece, consumed = stream.step(flush, capacity)
        output += piece
        if code == NEED_DICT:
            continue
        if stream.eof:
            break
        if not stream.state.avail_in and stream.state.avail_out:
            break
        require(consumed or piece, "libz made no progress with pending input/output")
    return bytes(output)


def finish_inflate(stream, suffix):
    output = bytearray(drain(stream)) if stream.state.avail_in else bytearray()
    for offset in range(0, len(suffix), CHUNK):
        require(not stream.eof, "wire has trailing bytes")
        stream.feed(suffix[offset:offset + CHUNK])
        output += drain(stream)
    if not stream.eof:
        output += drain(stream)
    require(stream.eof, "wire has no complete trailer/EOF")
    require(not stream.state.avail_in, "wire has unconsumed trailing bytes")
    return bytes(output)


def decode_wire(wire, format, window_bits=15, dictionary=None, library=None):
    """Decode all bytes with native libz; reject incomplete or trailing wire."""
    library = library if isinstance(library, ZlibLibrary) else ZlibLibrary(library)
    stream = Stream(library, "inflate", wbits(format, window_bits), dictionary=dictionary)
    try:
        plain = finish_inflate(stream, wire)
        receipt = {**digest(plain), **stream.snapshot(), "complete": True,
                   "all_output_bytes_checked": True, "wire": digest(wire),
                   "library": library.receipt}
        return plain, receipt
    finally:
        stream.close()


def compress_fork(library, case, prefix, tails, dictionary):
    capacity = case.get("copy_output_capacity", 1)
    flush = FLUSHES[case.get("flush", "none")]
    source = Stream(library, "deflate", wbits(case["format"], case.get("window_bits", 15)),
                    case.get("level", 6), case.get("strategy", 0), dictionary)
    clones = []
    common = bytearray()
    flush_pending = False
    params = None
    try:
        source.feed(prefix)
        _, piece, _ = source.step(capacity=capacity)
        common += piece
        stage = case.get("copy_stage", "prefix")
        require(stage in ("prefix", "header"), "copy_stage must be prefix or header")
        if stage == "prefix":
            while source.state.avail_in:
                _, piece, consumed = source.step(capacity=CHUNK)
                common += piece
                require(consumed or piece, "prefix compression made no progress")
        if flush:
            require(not source.state.avail_in, "flush requires copy_stage=prefix")
            code, piece, _ = source.step(flush, capacity)
            common += piece
            flush_pending = code != BUF_ERROR and not source.state.avail_out
        if "params_level" in case or "params_strategy" in case:
            require(not flush_pending, "queued params and interrupted flush require separate cases")
            level = case.get("params_level", case.get("level", 6))
            strategy = case.get("params_strategy", case.get("strategy", 0))
            code, piece, _ = source.params(level, strategy, capacity)
            common += piece
            params = {"level": level, "strategy": strategy, "initial_code": code,
                      "queued_at_copy": code == BUF_ERROR}
        snapshot = source.snapshot()
        clones = [source.copy(), source.copy()]
        source.close()
        branches, wires = {}, {}
        for name, clone in zip(("a", "b"), clones):
            wire = bytearray(common)
            params_calls = 0
            if params and params["queued_at_copy"]:
                for _ in range(10000):
                    code, piece, _ = clone.params(params["level"], params["strategy"])
                    params_calls += 1
                    wire += piece
                    if code == OK:
                        break
                    require(piece, "queued deflateParams made no progress")
                else:
                    raise AssertionError("queued deflateParams iteration limit")
            if clone.state.avail_in:
                wire += drain(clone)
            if flush_pending:
                wire += drain(clone, flush)
            for offset in range(0, len(tails[name]), CHUNK):
                clone.feed(tails[name][offset:offset + CHUNK])
                wire += drain(clone)
            while not clone.eof:
                _, piece, consumed = clone.step(FINISH)
                wire += piece
                require(clone.eof or consumed or piece, "finishing compressor made no progress")
            wires[name] = bytes(wire)
            branches[name] = {**digest(wire), **clone.snapshot(), "complete": True,
                              "plaintext": digest(prefix + tails[name])}
            if params:
                branches[name]["params_completion"] = {"code": OK, "calls_after_copy": params_calls,
                                                        "level": params["level"],
                                                        "strategy": params["strategy"]}
        return wires, {"common_prefix_size": len(common), "copy_snapshot": snapshot,
                       "source_destroyed_before_branches": True, "params": params,
                       "flush": case.get("flush", "none"), "flush_pending_at_copy": flush_pending,
                       "branches": branches}
    finally:
        for stream in [source, *clones]:
            stream.close()


def inflate_fork(library, format, window_bits, dictionary, common, suffixes,
                 expected, pending_output=False):
    source = Stream(library, "inflate", wbits(format, window_bits), dictionary=dictionary)
    clones = []
    try:
        source.feed(common)
        if pending_output:
            _, decoded_prefix, _ = source.step(capacity=1)
        else:
            decoded_prefix = drain(source)
        snapshot = source.snapshot()
        clones = [source.copy(), source.copy()]
        source.close()
        result = {"copy_snapshot": snapshot, "common_wire_size": len(common),
                  "common_output": digest(decoded_prefix),
                  "source_destroyed_before_branches": True, "branches": {}}
        decoded = {}
        for name, clone in zip(("a", "b"), clones):
            plain = decoded_prefix + finish_inflate(clone, suffixes[name])
            require(plain == expected[name], f"inflateCopy {name}: complete plaintext differs")
            decoded[name] = plain
            result["branches"][name] = {**digest(plain), **clone.snapshot(),
                                         "complete": True, "all_output_bytes_checked": True}
        return decoded, result
    finally:
        for stream in [source, *clones]:
            stream.close()


def check_case(library, case, input_dir, output_dir, index):
    def read(key):
        return (input_dir / case[key]).read_bytes()
    prefix = read("prefix_path")
    tails = {"a": read("tail_a_path"), "b": read("tail_b_path")}
    dictionary = read("dictionary_path") if case.get("dictionary_path") else None
    format, window_bits = case["format"], case.get("window_bits", 15)
    require(not (format == "gzip" and dictionary is not None), "gzip does not support preset dictionaries")
    expected = {name: prefix + tail for name, tail in tails.items()}
    wires, compression = compress_fork(library, case, prefix, tails, dictionary)
    common_size = compression["common_prefix_size"]
    require(wires["a"][:common_size] == wires["b"][:common_size], "encoder clones lost shared prefix")
    decoded, fork = inflate_fork(library, format, window_bits, dictionary,
                                wires["a"][:common_size],
                                {name: wire[common_size:] for name, wire in wires.items()}, expected)
    checkpoints = {}
    header = 0 if format == "raw" else 2 if format == "zlib" else 10
    trailer = 0 if format == "raw" else 4 if format == "zlib" else 8
    for name, wire in wires.items():
        checkpoints[name] = []
        cuts = [("pending_output", max(0, len(wire) - trailer), True)]
        if header:
            cuts += [("partial_header", 1, False)]
        if trailer:
            cuts += [("partial_trailer", len(wire) - 1, False)]
        for cut in case.get("inflate_cuts", []):
            require(isinstance(cut, int) and 0 <= cut <= len(wire), "inflate_cuts out of range")
            cuts.append((f"cut_{cut}", cut, False))
        for label, cut, pending in cuts:
            _, result = inflate_fork(library, format, window_bits, dictionary, wire[:cut],
                                    {"a": wire[cut:], "b": wire[cut:]},
                                    {"a": expected[name], "b": expected[name]}, pending)
            result["name"] = label
            checkpoints[name].append(result)
    slug = re.sub(r"[^A-Za-z0-9_.-]", "_", str(case["name"]))[:100] or "case"
    relative = Path("cases") / f"{index:03d}-{slug}"
    (output_dir / relative).mkdir(parents=True, exist_ok=True)
    for name in ("a", "b"):
        wire_path, plain_path = relative / f"{name}.wire", relative / f"{name}.decoded"
        (output_dir / wire_path).write_bytes(wires[name])
        (output_dir / plain_path).write_bytes(decoded[name])
        compression["branches"][name]["wire_path"] = wire_path.as_posix()
        fork["branches"][name]["decoded_path"] = plain_path.as_posix()
        independent, receipt = decode_wire(wires[name], format, window_bits, dictionary, library)
        require(independent == expected[name], "independent full decode differs")
        fork["branches"][name]["independent_decode"] = receipt
    return {"name": case["name"], "ok": True, "format": format, "library": library.receipt,
            "window_bits": window_bits, "prefix": digest(prefix),
            "tails": {name: digest(tail) for name, tail in tails.items()},
            "dictionary": digest(dictionary) if dictionary is not None else None,
            "compression": compression, "inflation": {"fork": fork, "checkpoints": checkpoints}}


def run_manifest(input_dir, output_dir, library=None):
    input_dir, output_dir = Path(input_dir), Path(output_dir)
    library = library if isinstance(library, ZlibLibrary) else ZlibLibrary(library)
    manifest = json.loads((input_dir / "manifest.json").read_text())
    cases = manifest if isinstance(manifest, list) else manifest["cases"]
    output_dir.mkdir(parents=True, exist_ok=True)
    results = []
    for index, case in enumerate(cases):
        try:
            results.append(check_case(library, case, input_dir, output_dir, index))
        except Exception as error:
            results.append({"name": case.get("name", str(index)), "ok": False,
                            "error": f"{type(error).__name__}: {error}"})
    receipt = {"schema": "vort.deflate.clone.reference.v1", "library": library.receipt,
               "ok": all(case["ok"] for case in results), "case_count": len(results), "cases": results}
    (output_dir / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--library", help="libz shared library path (default: system libz)")
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    receipt = run_manifest(args.input_dir, args.output_dir, args.library)
    print(json.dumps({"ok": receipt["ok"], "case_count": receipt["case_count"],
                      "library": receipt["library"], "receipt": str(args.output_dir / "receipt.json")}))
    if not receipt["ok"]:
        for case in receipt["cases"]:
            if not case["ok"]:
                print(f"{case['name']}: {case['error']}")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
