#!/usr/bin/env python3
"""Independent existing-libzstd stable output control and progress oracle."""
from __future__ import annotations
import ctypes as C
import hashlib
import importlib.util
from pathlib import Path


def _module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


_abi = _module("_stable_output_abi", Path(__file__).with_name("reference") / "abi.py")
_wire = _module("_stable_output_wire", Path(__file__).with_name("reference") / "wire.py")
ReferenceUnavailable = _abi.ReferenceUnavailable
Buffer = _abi.Buffer
frame_header, inspect_stream = _wire.frame_header, _wire.inspect_stream
sha256 = _abi.sha256


class ZstdError(RuntimeError):
    def __init__(self, message, receipt=None):
        self.receipt = receipt
        super().__init__(message)


class Library:
    """Fresh C contexts, a stable caller destination and actual input/pos traces."""
    def __init__(self, path=None, *, header=None, max_output_size=64 * 1024 * 1024):
        self.lib, selected = _abi.load(path)
        self.max_output_size = max_output_size
        ptr, size, integer = C.c_void_p, C.c_size_t, C.c_int
        version = self._bind("ZSTD_versionString", C.c_char_p)
        self.version = version().decode()
        self.path = _abi.loaded_path(version, selected)
        self.header_path, text = _abi.header(self.path, self.version, header)
        names = ("ZSTD_d_stableOutBuffer", "ZSTD_d_forceIgnoreChecksum", "ZSTD_d_format", "ZSTD_f_zstd1", "ZSTD_f_zstd1_magicless",
                 "ZSTD_c_compressionLevel", "ZSTD_c_contentSizeFlag", "ZSTD_c_checksumFlag", "ZSTD_c_format",
                 "ZSTD_e_continue", "ZSTD_e_end", "ZSTD_dct_fullDict", "ZSTD_dlm_byCopy")
        self.parameters = {name: _abi.parameter(text, name) for name in names}
        self._is_error = self._bind("ZSTD_isError", C.c_uint, size)
        self._error_name = self._bind("ZSTD_getErrorName", C.c_char_p, size)
        self._create_d = self._bind("ZSTD_createDCtx", ptr)
        self._free_d = self._bind("ZSTD_freeDCtx", size, ptr)
        self._set_d = self._bind("ZSTD_DCtx_setParameter", size, ptr, integer, integer)
        self._get_d = self._bind("ZSTD_DCtx_getParameter", size, ptr, integer, C.POINTER(integer))
        self._bounds_d = self._bind("ZSTD_dParam_getBounds", _abi.Bounds, integer)
        self._stream_d = self._bind("ZSTD_decompressStream", size, ptr, C.POINTER(Buffer), C.POINTER(Buffer))
        self._load_d = self._bind("ZSTD_DCtx_loadDictionary_advanced", size, ptr, ptr, size, integer, integer)
        self._create_c = self._bind("ZSTD_createCCtx", ptr)
        self._free_c = self._bind("ZSTD_freeCCtx", size, ptr)
        self._set_c = self._bind("ZSTD_CCtx_setParameter", size, ptr, integer, integer)
        self._pledge = self._bind("ZSTD_CCtx_setPledgedSrcSize", size, ptr, C.c_ulonglong)
        self._stream_c = self._bind("ZSTD_compressStream2", size, ptr, C.POINTER(Buffer), C.POINTER(Buffer), integer)
        bounds = self._bounds_d(self.parameters["ZSTD_d_stableOutBuffer"])
        self._check(bounds.error)
        if (bounds.lower, bounds.upper) != (0, 1):
            raise ReferenceUnavailable("Unexpected stableOutBuffer bounds")
        context = self._create_d()
        if not context:
            raise ReferenceUnavailable("Cannot create decoder context")
        try:
            controls = []
            for value in (0, 1):
                self._check(self._set_d(context, self.parameters["ZSTD_d_stableOutBuffer"], value))
                observed = C.c_int()
                self._check(self._get_d(context, self.parameters["ZSTD_d_stableOutBuffer"], C.byref(observed)))
                if observed.value != value:
                    raise ReferenceUnavailable("stableOutBuffer set/get disagreed")
                controls.append({"set": value, "observed": observed.value})
            self.preflight = {"stable_parameter": self.parameters["ZSTD_d_stableOutBuffer"],
                              "bounds": [bounds.lower, bounds.upper], "set_get": controls}
        finally:
            self._free_d(context)

    def _bind(self, name, result, *arguments):
        function = getattr(self.lib, name)
        function.restype, function.argtypes = result, arguments
        return function

    def _check(self, result):
        if self._is_error(result):
            raise ZstdError(self._error_name(result).decode())
        return result

    def _format(self, format):
        if format not in ("standard", "magicless"):
            raise ValueError("Unknown frame format")
        return self.parameters["ZSTD_f_zstd1_magicless" if format == "magicless" else "ZSTD_f_zstd1"]

    def provenance(self):
        return {"version": self.version, "path": str(self.path), "sha256": sha256(self.path),
                "header_path": str(self.header_path), "header_sha256": sha256(self.header_path),
                "parameters": self.parameters, "preflight": self.preflight,
                "source_path": str(Path(__file__).resolve()), "source_sha256": sha256(Path(__file__)),
                "helper_sources": [{"path": str(Path(module.__file__).resolve()), "sha256": sha256(module.__file__)} for module in (_abi, _wire)],
                "memory_scope": "C behavior and caller-buffer progress only; no RSS or Vort requested-heap comparison"}

    def encode(self, payload, *, known_size=True, checksum=True, format="standard", input_chunk_size=4093, level=3):
        payload = bytes(payload)
        if input_chunk_size <= 0:
            raise ValueError("Invalid input chunk")
        context = self._create_c()
        if not context:
            raise ReferenceUnavailable("Cannot create encoder context")
        try:
            for name, value in (("ZSTD_c_compressionLevel", level), ("ZSTD_c_contentSizeFlag", int(known_size)),
                                ("ZSTD_c_checksumFlag", int(checksum)), ("ZSTD_c_format", self._format(format))):
                self._check(self._set_c(context, self.parameters[name], value))
            if known_size:
                self._check(self._pledge(context, len(payload)))
            scratch = C.create_string_buffer(65536)
            chunks = []
            for offset in range(0, len(payload), input_chunk_size):
                data = payload[offset:offset + input_chunk_size]
                source = C.create_string_buffer(data, len(data) + 1)
                input_ = Buffer(C.addressof(source), len(data), 0)
                while input_.pos < input_.size:
                    output = Buffer(C.addressof(scratch), len(scratch), 0)
                    self._check(self._stream_c(context, C.byref(output), C.byref(input_), self.parameters["ZSTD_e_continue"]))
                    chunks.append(scratch.raw[:output.pos])
            input_ = Buffer(None, 0, 0)
            while True:
                output = Buffer(C.addressof(scratch), len(scratch), 0)
                remaining = self._check(self._stream_c(context, C.byref(output), C.byref(input_), self.parameters["ZSTD_e_end"]))
                chunks.append(scratch.raw[:output.pos])
                if remaining == 0:
                    return b"".join(chunks)
        finally:
            self._free_c(context)

    def _pump(self, wire, output_size, *, format="standard", stable=True, input_chunk_size=3,
              chunks=None, initial_pos=0, mutation=None, mutation_call=1, initial_output=b"", dictionary=None, ignore_checksum=False):
        wire = bytes(wire)
        if output_size < 0 or output_size > self.max_output_size or not 0 <= initial_pos <= output_size or input_chunk_size <= 0:
            raise ValueError("Invalid caller output size, position or input chunk")
        if len(initial_output) > initial_pos:
            raise ValueError("Initial output exceeds initial pos")
        destination = C.create_string_buffer(max(1, output_size))
        alternate = C.create_string_buffer(max(1, output_size))
        C.memset(destination, 0xa5, len(destination))
        if initial_output:
            C.memmove(destination, initial_output, len(initial_output))
        output = Buffer(C.addressof(destination), output_size, initial_pos)
        trace, consumed, frame_count, failure, hint = [], 0, 0, None, 1
        schedule = list(chunks) if chunks is not None else [min(input_chunk_size, len(wire) - offset) for offset in range(0, len(wire), input_chunk_size)]
        if not schedule:
            schedule = [0]
        if any(size < 0 for size in schedule) or sum(schedule) != len(wire):
            raise ValueError("Input chunks must exactly span the wire (zero chunks permitted)")
        context = self._create_d()
        if not context:
            raise ReferenceUnavailable("Cannot create decoder context")
        try:
            self._check(self._set_d(context, self.parameters["ZSTD_d_format"], self._format(format)))
            self._check(self._set_d(context, self.parameters["ZSTD_d_stableOutBuffer"], int(stable)))
            self._check(self._set_d(context, self.parameters["ZSTD_d_forceIgnoreChecksum"], int(ignore_checksum)))
            if dictionary is not None:
                dictionary = bytes(dictionary)
                self._check(self._load_d(context, dictionary, len(dictionary),
                                        self.parameters["ZSTD_dlm_byCopy"], self.parameters["ZSTD_dct_fullDict"]))
            for count in schedule:
                data = wire[consumed:consumed + count]
                source = C.create_string_buffer(data, len(data) + 1)
                input_ = Buffer(C.addressof(source), count, 0)
                while True:
                    if mutation is not None and len(trace) == mutation_call:
                        if mutation == "dst":
                            output.data = C.addressof(alternate)
                        elif mutation == "size":
                            output.size -= 1
                        elif mutation == "pos":
                            output.pos = output.pos - 1 if output.pos else 1
                        else:
                            raise ValueError("Unknown buffer mutation")
                    before_input, before_output = input_.pos, output.pos
                    result = self._stream_d(context, C.byref(output), C.byref(input_))
                    error = self._error_name(result).decode() if self._is_error(result) else None
                    event = {"call": len(trace), "input_offset": consumed, "input_offered": count,
                             "input_pos_before": before_input, "input_pos_after": input_.pos,
                             "input_read": input_.pos - before_input, "output_pos_before": before_output,
                             "output_pos_after": output.pos, "output_written": output.pos - before_output,
                             "output_size": output.size, "output_available_before": output.size - before_output,
                             "hint": None if error else result, "error": error}
                    trace.append(event)
                    if error:
                        failure = error
                        break
                    hint = result
                    if hint == 0:
                        frame_count += 1
                    if input_.pos == input_.size:
                        break
                    if before_input == input_.pos and before_output == output.pos:
                        failure = "Reference pump made no progress"
                        break
                consumed += input_.pos
                if failure:
                    break
            if failure is None and (consumed != len(wire) or hint != 0):
                failure = "Incomplete or truncated input"
            raw = destination.raw[initial_pos:min(output.pos, output_size)]
            receipt = {"stable": bool(stable), "output_size": output_size, "initial_pos": initial_pos,
                       "output_pos": output.pos, "output_written": sum(call["output_written"] for call in trace),
                       "output_sha256": hashlib.sha256(raw).hexdigest(),
                       "input_bytes": len(wire), "input_read": consumed, "frames_completed": frame_count,
                       "error": failure, "calls": trace, "complete": failure is None,
                       "zero_available_output_calls": sum(call["output_available_before"] == 0 for call in trace),
                       "zero_available_output_input_read": sum(call["input_read"] for call in trace if call["output_available_before"] == 0),
                       "mutation": mutation, "mutation_call": mutation_call,
                       "output_pointer_constant": mutation != "dst"}
            return raw, receipt
        finally:
            self._free_d(context)

    def observe(self, wire, output_size, **options):
        """Return actual C progress and errors without raising decoder failures."""
        return self._pump(wire, output_size, **options)[1]

    def decode_stable(self, wire, expected_output_len, **options):
        """Return (plaintext, receipt) using exactly the caller's whole-output size."""
        output, receipt = self._pump(wire, expected_output_len, stable=True, **options)
        if receipt["error"]:
            raise ZstdError(receipt["error"], receipt)
        if len(output) != expected_output_len:
            raise ZstdError("Decoded size disagrees with expected_output_len", receipt)
        return output, receipt

    def decode(self, wire, *, expected_output_len=None, **options):
        """Plaintext convenience with a bounded destination (stable mode by default)."""
        if expected_output_len is None:
            sizes = [frame["header"]["content_size"] for frame in inspect_stream(wire, options.get("format", "standard")) if not frame["skippable"]]
            expected_output_len = sum(sizes) if all(size is not None for size in sizes) else self.max_output_size
        output, receipt = self._pump(wire, expected_output_len, **options)
        if receipt["error"]:
            raise ZstdError(receipt["error"], receipt)
        return output
