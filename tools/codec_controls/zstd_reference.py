#!/usr/bin/env python3
"""Small ctypes Zstd oracle using an existing library and matching local header.

The default loader prefers ~/Work/zstd/lib over the system library. Frames are
standard Zstd with a content checksum; callers may strip MAGIC for magicless
tests. Dictionaries are explicitly raw content, including dictionary-looking
prefixes. This module neither builds nor installs a reference implementation.
"""
from __future__ import annotations

import ctypes as C
import ctypes.util
import hashlib
from pathlib import Path
import re

MAGIC = b"\x28\xb5\x2f\xfd"
OUTPUT_CHUNK_SIZE = 64 * 1024
MAX_OUTPUT_SIZE = 64 * 1024 * 1024


class ReferenceUnavailable(RuntimeError):
    """The selected reference or its matching header is unavailable."""


class ZstdError(RuntimeError):
    """Reference decoding/encoding failed, including incomplete streams."""


class _Buffer(C.Structure):
    _fields_ = [("data", C.c_void_p), ("size", C.c_size_t), ("pos", C.c_size_t)]


class _DlInfo(C.Structure):
    _fields_ = [("name", C.c_char_p), ("base", C.c_void_p),
                ("symbol", C.c_char_p), ("address", C.c_void_p)]


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _resolve_parameter(text: str, name: str) -> int:
    alias = re.search(r"^\s*#define\s+" + re.escape(name) + r"\s+(\w+)\s*$",
                      text, re.MULTILINE)
    if alias:
        return _resolve_parameter(text, alias.group(1))
    value = re.search(r"\b" + re.escape(name) + r"\s*=\s*(\d+)\b", text)
    if value is None:
        raise ReferenceUnavailable(f"Zstd header has no parameter {name}")
    return int(value.group(1))


def _header_version(text: str) -> str | None:
    parts = [re.search(r"^\s*#define\s+ZSTD_VERSION_" + part + r"\s+(\d+)\b",
                       text, re.MULTILINE) for part in ("MAJOR", "MINOR", "RELEASE")]
    return ".".join(part.group(1) for part in parts) if all(parts) else None


def _find_header(path: Path, version: str, explicit: Path | None) -> tuple[Path, str]:
    candidates = [explicit] if explicit is not None else []
    if explicit is None:
        for parent in path.parents:
            candidates.extend((parent / "zstd.h", parent / "include/zstd.h"))
        candidates.extend((Path("/usr/include/zstd.h"), Path("/usr/local/include/zstd.h")))
    for candidate in dict.fromkeys(candidates):
        if candidate is not None and candidate.is_file():
            text = candidate.read_text()
            if _header_version(text) == version:
                return candidate.resolve(), text
    raise ReferenceUnavailable(f"No matching zstd.h for library {version} at {path}")


def _library_candidates(path: Path | str | None) -> list[str]:
    if path is not None:
        return [str(Path(path).expanduser().resolve(strict=True))]
    local = Path.home() / "Work/zstd/lib"
    candidates = [local / "libzstd.so", local / "libzstd.dylib"]
    candidates.extend(sorted(local.glob("libzstd.so.*"), reverse=True))
    result = list(dict.fromkeys(str(item.resolve()) for item in candidates if item.is_file()))
    system = ctypes.util.find_library("zstd")
    if system:
        result.append(system)
    return result


class Library:
    """Existing Zstd library with bounded streaming output and raw dictionaries.

    ``decode`` defaults to ZSTD_decompressStream; ``decode_one_shot`` exercises
    ZSTD_decompressDCtx with the same context parameters. A fresh context is used
    for every operation. The collected result is limited by max_output_size.
    """

    def __init__(self, path: Path | str | None = None, *, header: Path | None = None,
                 output_chunk_size: int = OUTPUT_CHUNK_SIZE,
                 max_output_size: int = MAX_OUTPUT_SIZE):
        if output_chunk_size <= 0 or max_output_size < 0:
            raise ValueError("Invalid Zstd output limits")
        self.output_chunk_size = output_chunk_size
        self.max_output_size = max_output_size
        failures = []
        try:
            candidates = _library_candidates(path)
        except OSError as error:
            raise ReferenceUnavailable(str(error)) from error
        for candidate in candidates:
            try:
                self.lib = C.CDLL(candidate)
                selected = candidate
                break
            except OSError as error:
                failures.append(str(error))
        else:
            raise ReferenceUnavailable("No existing libzstd found: " + "; ".join(failures))

        ptr, size, integer = C.c_void_p, C.c_size_t, C.c_int
        self._is_error = self._bind("ZSTD_isError", C.c_uint, size)
        self._error_name = self._bind("ZSTD_getErrorName", C.c_char_p, size)
        version_fn = self._bind("ZSTD_versionString", C.c_char_p)
        self.version = version_fn().decode()
        self.version_number = self._bind("ZSTD_versionNumber", C.c_uint)()
        self.path = self._loaded_path(version_fn, selected)
        explicit_header = Path(header).expanduser() if header is not None else None
        self.header_path, header_text = _find_header(self.path, self.version, explicit_header)
        names = ("ZSTD_c_compressionLevel", "ZSTD_c_contentSizeFlag", "ZSTD_c_checksumFlag",
                 "ZSTD_c_dictIDFlag", "ZSTD_d_format", "ZSTD_d_forceIgnoreChecksum",
                 "ZSTD_f_zstd1", "ZSTD_f_zstd1_magicless", "ZSTD_d_validateChecksum",
                 "ZSTD_d_ignoreChecksum", "ZSTD_dlm_byCopy", "ZSTD_dct_rawContent")
        self.parameters = {name: _resolve_parameter(header_text, name) for name in names}
        self._bound = self._bind("ZSTD_compressBound", size, size)
        self._ccreate = self._bind("ZSTD_createCCtx", ptr)
        self._cfree = self._bind("ZSTD_freeCCtx", size, ptr)
        self._cset = self._bind("ZSTD_CCtx_setParameter", size, ptr, integer, integer)
        self._cload = self._bind("ZSTD_CCtx_loadDictionary_advanced", size,
                                ptr, ptr, size, integer, integer)
        self._compress = self._bind("ZSTD_compress2", size, ptr, ptr, size, ptr, size)
        self._dcreate = self._bind("ZSTD_createDCtx", ptr)
        self._dfree = self._bind("ZSTD_freeDCtx", size, ptr)
        self._dset = self._bind("ZSTD_DCtx_setParameter", size, ptr, integer, integer)
        self._dload = self._bind("ZSTD_DCtx_loadDictionary_advanced", size,
                                ptr, ptr, size, integer, integer)
        self._stream = self._bind("ZSTD_decompressStream", size, ptr,
                                  C.POINTER(_Buffer), C.POINTER(_Buffer))
        self._one_shot = self._bind("ZSTD_decompressDCtx", size, ptr, ptr, size, ptr, size)
        self._content_size = self._bind("ZSTD_getFrameContentSize", C.c_ulonglong, ptr, size)
        self.dparams = self._probe_dparams()

    def _bind(self, name, result, *arguments):
        try:
            function = getattr(self.lib, name)
        except AttributeError as error:
            raise ReferenceUnavailable(f"Missing Zstd reference symbol {name}") from error
        function.restype, function.argtypes = result, arguments
        return function

    @staticmethod
    def _loaded_path(function, selected: str) -> Path:
        try:
            dladdr = C.CDLL(None).dladdr
            dladdr.restype, dladdr.argtypes = C.c_int, (C.c_void_p, C.POINTER(_DlInfo))
            info = _DlInfo()
            if dladdr(C.cast(function, C.c_void_p), C.byref(info)) and info.name:
                actual = Path(info.name.decode()).resolve(strict=True)
                if Path(selected).is_absolute() and actual != Path(selected).resolve():
                    raise ReferenceUnavailable("Zstd symbol is not from the requested library")
                return actual
        except AttributeError:
            pass
        candidate = Path(selected)
        if candidate.is_file():
            return candidate.resolve()
        raise ReferenceUnavailable("Cannot identify the loaded Zstd reference path")

    def _check(self, result: int, operation: str) -> int:
        if self._is_error(result):
            raise ZstdError(f"{operation}: {self._error_name(result).decode()}")
        return result

    def _probe_dparams(self) -> dict:
        context = self._dcreate()
        if not context:
            raise ReferenceUnavailable("ZSTD_createDCtx failed")
        try:
            result = {}
            for name, value in (("ZSTD_d_format", self.parameters["ZSTD_f_zstd1_magicless"]),
                                ("ZSTD_d_forceIgnoreChecksum", self.parameters["ZSTD_d_ignoreChecksum"])):
                supported = not self._is_error(self._dset(context, self.parameters[name], value))
                result[name] = {"parameter": self.parameters[name], "value": value, "supported": supported}
            return result
        finally:
            self._dfree(context)

    def provenance(self) -> dict:
        return {"version": self.version, "version_number": self.version_number,
                "path": str(self.path), "sha256": _sha256(self.path),
                "headerVersion": self.version, "header_path": str(self.header_path),
                "header_sha256": _sha256(self.header_path), "parameters": dict(self.parameters),
                "dparams": {name: dict(value) for name, value in self.dparams.items()},
                "output_chunk_size": self.output_chunk_size, "max_output_size": self.max_output_size,
                "dictionary_type": "raw_content", "encoder_checksum": True}

    def _load_dictionary(self, function, context, dictionary: bytes | None) -> None:
        data = b"" if dictionary is None else bytes(dictionary)
        self._check(function(context, data, len(data), self.parameters["ZSTD_dlm_byCopy"],
                             self.parameters["ZSTD_dct_rawContent"]), "load raw dictionary")

    def encode(self, payload: bytes, dictionary: bytes | None = None) -> bytes:
        """Produce one standard checksummed frame, optionally with raw history."""
        payload = bytes(payload)
        context = self._ccreate()
        if not context:
            raise ReferenceUnavailable("ZSTD_createCCtx failed")
        try:
            for name, value in (("ZSTD_c_compressionLevel", 3), ("ZSTD_c_contentSizeFlag", 1),
                                ("ZSTD_c_checksumFlag", 1), ("ZSTD_c_dictIDFlag", 1)):
                self._check(self._cset(context, self.parameters[name], value), "set encoder parameter")
            self._load_dictionary(self._cload, context, dictionary)
            capacity = self._check(self._bound(len(payload)), "compression bound")
            output = C.create_string_buffer(max(1, capacity))
            written = self._check(self._compress(context, output, capacity, payload, len(payload)), "encode")
            wire = output.raw[:written]
            if not wire.startswith(MAGIC) or not wire[4] & 4:
                raise AssertionError("Reference encoder did not produce a standard checksummed frame")
            return wire
        finally:
            self._cfree(context)

    def _decode_context(self, dictionary: bytes | None, ignore: bool, magicless: bool):
        context = self._dcreate()
        if not context:
            raise ReferenceUnavailable("ZSTD_createDCtx failed")
        try:
            format_ = "ZSTD_f_zstd1_magicless" if magicless else "ZSTD_f_zstd1"
            checksum = "ZSTD_d_ignoreChecksum" if ignore else "ZSTD_d_validateChecksum"
            for name, value in (("ZSTD_d_format", self.parameters[format_]),
                                ("ZSTD_d_forceIgnoreChecksum", self.parameters[checksum])):
                self._check(self._dset(context, self.parameters[name], value), "set decoder parameter")
            self._load_dictionary(self._dload, context, dictionary)
            return context
        except BaseException:
            self._dfree(context)
            raise

    def decode(self, wire: bytes, dictionary: bytes | None = None,
               ignore: bool = False, magicless: bool = False, *, api: str = "streaming") -> bytes:
        """Decode complete input; ignoring checksum still requires its full footer."""
        if api == "one_shot":
            return self.decode_one_shot(wire, dictionary, ignore, magicless)
        if api != "streaming":
            raise ValueError(f"Unknown reference decode API {api!r}")
        wire = bytes(wire)
        source = C.create_string_buffer(wire, len(wire) + 1)
        input_ = _Buffer(C.addressof(source), len(wire), 0)
        output = C.create_string_buffer(self.output_chunk_size)
        context = self._decode_context(dictionary, ignore, magicless)
        chunks, total = [], 0
        try:
            while True:
                before = input_.pos
                destination = _Buffer(C.addressof(output), self.output_chunk_size, 0)
                hint = self._check(self._stream(context, C.byref(destination), C.byref(input_)), "decode streaming")
                total += destination.pos
                if total > self.max_output_size:
                    raise ZstdError("decode streaming: output exceeds configured limit")
                if destination.pos:
                    chunks.append(output.raw[:destination.pos])
                if hint == 0 and input_.pos == len(wire):
                    return b"".join(chunks)
                if before == input_.pos and destination.pos == 0:
                    raise ZstdError("decode streaming: incomplete or truncated input")
        finally:
            self._dfree(context)

    def decode_one_shot(self, wire: bytes, dictionary: bytes | None = None,
                        ignore: bool = False, magicless: bool = False) -> bytes:
        """Exercise ZSTD_decompressDCtx; retry only a bounded destination size."""
        wire = bytes(wire)
        standard = MAGIC + wire if magicless else wire
        size_hint = self._content_size(standard, len(standard))
        known_size = size_hint < (1 << 64) - 2
        if known_size and size_hint > self.max_output_size:
            raise ZstdError("decode one shot: output exceeds configured limit")
        capacity = min(self.max_output_size, max(1, size_hint if known_size else self.output_chunk_size))
        while True:
            context = self._decode_context(dictionary, ignore, magicless)
            try:
                output = C.create_string_buffer(max(1, capacity))
                result = self._one_shot(context, output, capacity, wire, len(wire))
                if not self._is_error(result):
                    # The one-shot reference accepts empty input as an empty
                    # concatenation. The oracle requires at least one frame.
                    if not wire:
                        raise ZstdError("decode one shot: incomplete or truncated input")
                    return output.raw[:result]
                name = self._error_name(result).decode()
                if name != "Destination buffer is too small" or capacity >= self.max_output_size:
                    raise ZstdError(f"decode one shot: {name}")
                capacity = min(self.max_output_size, max(1, capacity * 2))
            finally:
                self._dfree(context)

    def expect_error(self, wire: bytes, dictionary: bytes | None = None,
                     ignore: bool = False, magicless: bool = False, *, api: str = "streaming") -> str:
        try:
            self.decode(wire, dictionary, ignore, magicless, api=api)
        except ZstdError as error:
            return str(error)
        raise AssertionError(f"Zstd reference unexpectedly accepted input ({api})")
