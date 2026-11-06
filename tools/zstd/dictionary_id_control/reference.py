#!/usr/bin/env python3
"""Independent libzstd oracle for complete dictionaries and dictIDFlag.

This module deliberately does not reuse the raw-dictionary controls oracle.
Every nonempty dictionary is loaded with ZSTD_dct_fullDict, including frames
whose dictionary ID has been suppressed. No reference build is performed.
"""
from __future__ import annotations

import ctypes as C
import ctypes.util
import hashlib
import importlib.util
from pathlib import Path
import re

MAGIC = bytes.fromhex("28b52ffd")
DICTIONARY_MAGIC = bytes.fromhex("37a430ec")
OUTPUT_CHUNK_SIZE = 64 * 1024
MAX_OUTPUT_SIZE = 64 * 1024 * 1024

# Load by exact sibling path as well as through package imports. Differential
# drivers commonly import this oracle with spec_from_file_location().
_format_path = Path(__file__).with_name("reference_format.py")
_format_spec = importlib.util.spec_from_file_location("_dictionary_control_format", _format_path)
_format_module = importlib.util.module_from_spec(_format_spec)
_format_spec.loader.exec_module(_format_module)
frame_header, entropy_modes = _format_module.frame_header, _format_module.entropy_modes


class ReferenceUnavailable(RuntimeError):
    """The existing library, matching headers or required ABI is unavailable."""


class ZstdError(RuntimeError):
    """libzstd rejected the operation or the input was incomplete."""


class _Buffer(C.Structure):
    _fields_ = [("data", C.c_void_p), ("size", C.c_size_t), ("pos", C.c_size_t)]


class _DictionaryParameters(C.Structure):
    _fields_ = [("compressionLevel", C.c_int), ("notificationLevel", C.c_uint),
                ("dictID", C.c_uint)]


class _DlInfo(C.Structure):
    _fields_ = [("name", C.c_char_p), ("base", C.c_void_p),
                ("symbol", C.c_char_p), ("address", C.c_void_p)]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _parameter(text: str, name: str) -> int:
    alias = re.search(r"^\s*#define\s+" + re.escape(name) + r"\s+(\w+)\s*$",
                      text, re.MULTILINE)
    if alias:
        return _parameter(text, alias.group(1))
    value = re.search(r"\b" + re.escape(name) + r"\s*=\s*(\d+)\b", text)
    if value is None:
        raise ReferenceUnavailable(f"Matching header does not declare {name}")
    return int(value.group(1))


def _header_version(text: str) -> str | None:
    parts = [re.search(r"^\s*#define\s+ZSTD_VERSION_" + part + r"\s+(\d+)\b",
                       text, re.MULTILINE) for part in ("MAJOR", "MINOR", "RELEASE")]
    return ".".join(part.group(1) for part in parts) if all(parts) else None


def _headers(path: Path, version: str, explicit: Path | None) -> tuple[Path, Path, str]:
    candidates = [explicit] if explicit is not None else []
    if explicit is None:
        for parent in path.parents:
            candidates.extend((parent / "zstd.h", parent / "include/zstd.h"))
        candidates.extend((Path("/usr/include/zstd.h"), Path("/usr/local/include/zstd.h")))
    for candidate in dict.fromkeys(candidates):
        if candidate is None or not candidate.is_file():
            continue
        text = candidate.read_text()
        dictionary_header = candidate.parent / "zdict.h"
        if _header_version(text) == version and dictionary_header.is_file():
            return candidate.resolve(), dictionary_header.resolve(), text
    raise ReferenceUnavailable(f"No matching zstd.h and zdict.h for {version} at {path}")


def _candidates(path: Path | str | None) -> list[str]:
    if path is not None:
        return [str(Path(path).expanduser().resolve(strict=True))]
    root = Path.home() / "Work/zstd/lib"
    candidates = [root / "libzstd.so", root / "libzstd.dylib"]
    candidates.extend(sorted(root.glob("libzstd.so.*"), reverse=True))
    selected = list(dict.fromkeys(str(item.resolve()) for item in candidates if item.is_file()))
    system = ctypes.util.find_library("zstd")
    if system:
        selected.append(system)
    return selected


class Library:
    """Complete-dictionary encoder/decoder with fresh contexts and bounded output."""

    def __init__(self, path: Path | str | None = None, *, header: Path | str | None = None,
                 output_chunk_size: int = OUTPUT_CHUNK_SIZE,
                 max_output_size: int = MAX_OUTPUT_SIZE):
        if output_chunk_size <= 0 or max_output_size < 0:
            raise ValueError("Invalid output limits")
        self.output_chunk_size, self.max_output_size = output_chunk_size, max_output_size
        failures = []
        try:
            candidates = _candidates(path)
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
        ptr, size, integer, unsigned = C.c_void_p, C.c_size_t, C.c_int, C.c_uint
        self._is_error = self._bind("ZSTD_isError", unsigned, size)
        self._error_name = self._bind("ZSTD_getErrorName", C.c_char_p, size)
        version_fn = self._bind("ZSTD_versionString", C.c_char_p)
        self.version = version_fn().decode()
        self.version_number = self._bind("ZSTD_versionNumber", unsigned)()
        self.path = self._loaded_path(version_fn, selected)
        explicit = Path(header).expanduser() if header is not None else None
        self.header_path, self.dictionary_header_path, text = _headers(self.path, self.version, explicit)
        names = ("ZSTD_c_compressionLevel", "ZSTD_c_contentSizeFlag", "ZSTD_c_checksumFlag",
                 "ZSTD_c_dictIDFlag", "ZSTD_c_format", "ZSTD_d_format", "ZSTD_dlm_byCopy",
                 "ZSTD_dct_fullDict", "ZSTD_f_zstd1", "ZSTD_f_zstd1_magicless",
                 "ZSTD_e_continue", "ZSTD_e_end")
        self.parameters = {name: _parameter(text, name) for name in names}
        if self.parameters["ZSTD_c_dictIDFlag"] != 202:
            raise ReferenceUnavailable("Matching header does not declare dictIDFlag parameter 202")
        self._bound = self._bind("ZSTD_compressBound", size, size)
        self._ccreate = self._bind("ZSTD_createCCtx", ptr)
        self._cfree = self._bind("ZSTD_freeCCtx", size, ptr)
        self._cset = self._bind("ZSTD_CCtx_setParameter", size, ptr, integer, integer)
        self._pledge = self._bind("ZSTD_CCtx_setPledgedSrcSize", size, ptr, C.c_ulonglong)
        self._cload = self._bind("ZSTD_CCtx_loadDictionary_advanced", size,
                                ptr, ptr, size, integer, integer)
        self._compress = self._bind("ZSTD_compress2", size, ptr, ptr, size, ptr, size)
        self._cstream = self._bind("ZSTD_compressStream2", size, ptr,
                                  C.POINTER(_Buffer), C.POINTER(_Buffer), integer)
        self._dcreate = self._bind("ZSTD_createDCtx", ptr)
        self._dfree = self._bind("ZSTD_freeDCtx", size, ptr)
        self._dset = self._bind("ZSTD_DCtx_setParameter", size, ptr, integer, integer)
        self._dload = self._bind("ZSTD_DCtx_loadDictionary_advanced", size,
                                ptr, ptr, size, integer, integer)
        self._dstream = self._bind("ZSTD_decompressStream", size, ptr,
                                  C.POINTER(_Buffer), C.POINTER(_Buffer))
        self._dict_id = self._bind("ZSTD_getDictID_fromDict", unsigned, ptr, size)
        self._dict_header_size = self._bind("ZDICT_getDictHeaderSize", size, ptr, size)
        self._finalize = self._bind("ZDICT_finalizeDictionary", size, ptr, size, ptr,
                                   size, ptr, C.POINTER(size), unsigned, _DictionaryParameters)
        self._dict_is_error = self._bind("ZDICT_isError", unsigned, size)
        self._dict_error_name = self._bind("ZDICT_getErrorName", C.c_char_p, size)
        self.preflight = self._preflight()

    def _bind(self, name, result, *arguments):
        try:
            function = getattr(self.lib, name)
        except AttributeError as error:
            raise ReferenceUnavailable(f"Missing reference symbol {name}") from error
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
        if Path(selected).is_file():
            return Path(selected).resolve()
        raise ReferenceUnavailable("Cannot identify loaded reference library path")

    def _check(self, result: int, operation: str) -> int:
        if self._is_error(result):
            raise ZstdError(f"{operation}: {self._error_name(result).decode()}")
        return result

    def _preflight(self) -> dict:
        encoder, decoder = self._ccreate(), self._dcreate()
        if not encoder or not decoder:
            if encoder:
                self._cfree(encoder)
            if decoder:
                self._dfree(decoder)
            raise ReferenceUnavailable("Cannot allocate preflight contexts")
        try:
            for value in (0, 1):
                self._check(self._cset(encoder, 202, value), "preflight dictIDFlag 202")
            for name in ("ZSTD_f_zstd1", "ZSTD_f_zstd1_magicless"):
                self._check(self._cset(encoder, self.parameters["ZSTD_c_format"], self.parameters[name]),
                            "preflight encoder format")
                self._check(self._dset(decoder, self.parameters["ZSTD_d_format"], self.parameters[name]),
                            "preflight decoder format")
            return {"dictIDFlag": {"parameter": 202, "values": [0, 1], "supported": True},
                    "encoder_format": self.parameters["ZSTD_c_format"],
                    "decoder_format": self.parameters["ZSTD_d_format"],
                    "dictionary_type": self.parameters["ZSTD_dct_fullDict"],
                    "dictionary_parameters_size": C.sizeof(_DictionaryParameters)}
        finally:
            self._cfree(encoder)
            self._dfree(decoder)

    def provenance(self) -> dict:
        return {"version": self.version, "version_number": self.version_number,
                "path": str(self.path), "sha256": sha256(self.path),
                "header_path": str(self.header_path), "header_version": self.version,
                "header_sha256": sha256(self.header_path),
                "dictionary_header_path": str(self.dictionary_header_path),
                "dictionary_header_sha256": sha256(self.dictionary_header_path),
                "reference_source_path": str(Path(__file__).resolve()),
                "reference_source_sha256": sha256(Path(__file__).resolve()),
                "format_source_sha256": sha256(_format_path),
                "parameters": dict(self.parameters), "preflight": self.preflight,
                "dictionary_type": "full_standard", "encoder_checksum": True,
                "output_chunk_size": self.output_chunk_size, "max_output_size": self.max_output_size}

    def dictionary_id(self, dictionary: bytes) -> int:
        return self._dict_id(dictionary, len(dictionary))

    def dictionary_header_size(self, dictionary: bytes) -> int:
        result = self._dict_header_size(dictionary, len(dictionary))
        if self._dict_is_error(result):
            raise ZstdError("dictionary header: " + self._dict_error_name(result).decode())
        return result

    def finalize_dictionary(self, samples: list[bytes], history: bytes, *, dict_id: int,
                            level: int = 3, capacity: int | None = None) -> bytes:
        """Build entropy tables + explicit ID + exact custom history using C ZDICT."""
        samples, history = [bytes(sample) for sample in samples], bytes(history)
        if not samples or not history or not 0 < dict_id <= 0xffffffff:
            raise ValueError("Nonempty samples/history and a positive uint32 dict_id are required")
        capacity = max(256, len(history) + 1024) if capacity is None else capacity
        if capacity < max(256, len(history)):
            raise ValueError("Dictionary capacity is too small")
        joined = b"".join(samples)
        sizes = (C.c_size_t * len(samples))(*(len(sample) for sample in samples))
        output = C.create_string_buffer(capacity)
        result = self._finalize(output, capacity, history, len(history), joined, sizes,
                                len(samples), _DictionaryParameters(level, 0, dict_id))
        if self._dict_is_error(result):
            raise ZstdError("finalize dictionary: " + self._dict_error_name(result).decode())
        dictionary = output.raw[:result]
        if not dictionary.startswith(DICTIONARY_MAGIC) or self.dictionary_id(dictionary) != dict_id:
            raise AssertionError("ZDICT producer did not emit a complete dictionary with the requested ID")
        header_size = self.dictionary_header_size(dictionary)
        if header_size <= 20 or dictionary[header_size:] != history:
            raise AssertionError("Finalized dictionary has missing entropy tables or truncated history")
        # Both strict full-dictionary loaders validate the produced tables.
        for create, load, free in ((self._ccreate, self._cload, self._cfree),
                                   (self._dcreate, self._dload, self._dfree)):
            context = create()
            if not context:
                raise ReferenceUnavailable("Cannot allocate dictionary validation context")
            try:
                self._load_dictionary(load, context, dictionary)
            finally:
                free(context)
        return dictionary

    def _load_dictionary(self, function, context, dictionary: bytes | None) -> None:
        data = b"" if dictionary is None else bytes(dictionary)
        self._check(function(context, data, len(data), self.parameters["ZSTD_dlm_byCopy"],
                             self.parameters["ZSTD_dct_fullDict"]), "load complete dictionary")

    def _format(self, format: str) -> int:
        if format not in ("standard", "magicless"):
            raise ValueError(f"Unknown frame format {format!r}")
        return self.parameters["ZSTD_f_zstd1_magicless" if format == "magicless" else "ZSTD_f_zstd1"]

    def encode(self, payload: bytes, dictionary: bytes | None = None, include_id: bool = True,
               *, format: str = "standard", streaming: bool = False, known_size: bool = True,
               level: int = 3, input_chunk_size: int = 31) -> bytes:
        """Encode with dictIDFlag 202; unknown streams withhold the source pledge."""
        payload = bytes(payload)
        if input_chunk_size <= 0:
            raise ValueError("Invalid encoder input chunk size")
        context = self._ccreate()
        if not context:
            raise ReferenceUnavailable("ZSTD_createCCtx failed")
        try:
            # Withhold the pledge for unknown streams while keeping the normal
            # content-size flag enabled. An unknown frame therefore tests actual
            # unknown-source streaming, rather than only hiding a known size.
            content_size_flag = int(known_size or (streaming and bool(payload)))
            values = (("ZSTD_c_compressionLevel", level), ("ZSTD_c_contentSizeFlag", content_size_flag),
                      ("ZSTD_c_checksumFlag", 1), ("ZSTD_c_dictIDFlag", int(include_id)),
                      ("ZSTD_c_format", self._format(format)))
            for name, value in values:
                self._check(self._cset(context, self.parameters[name], value), "set encoder parameter")
            self._load_dictionary(self._cload, context, dictionary)
            if streaming:
                if known_size:
                    self._check(self._pledge(context, len(payload)), "pledge encoder source size")
                wire = self._encode_stream(context, payload, input_chunk_size)
            else:
                capacity = self._check(self._bound(len(payload)), "compression bound")
                output = C.create_string_buffer(max(1, capacity))
                result = self._check(self._compress(context, output, capacity, payload, len(payload)), "encode")
                wire = output.raw[:result]
            header = frame_header(wire, format)
            expected_id = self.dictionary_id(dictionary) if dictionary and include_id else 0
            if header["dictionary_id"] != expected_id:
                raise AssertionError("Reference encoder dictionary ID does not match dictIDFlag")
            if not include_id and header["dictionary_id_flag"] != 0:
                raise AssertionError("Reference encoder did not suppress the dictionary ID field")
            if header["content_size"] != (len(payload) if known_size else None):
                raise AssertionError("Reference encoder did not honor content-size visibility")
            if not header["checksum"]:
                raise AssertionError("Reference encoder omitted its checksum")
            return wire
        finally:
            self._cfree(context)

    def _encode_stream(self, context, payload: bytes, input_chunk_size: int) -> bytes:
        output = C.create_string_buffer(self.output_chunk_size)
        chunks = []
        for start in range(0, len(payload), input_chunk_size):
            part = payload[start:start + input_chunk_size]
            source = C.create_string_buffer(part, len(part) + 1)
            input_ = _Buffer(C.addressof(source), len(part), 0)
            while input_.pos < input_.size:
                before = input_.pos
                destination = _Buffer(C.addressof(output), self.output_chunk_size, 0)
                self._check(self._cstream(context, C.byref(destination), C.byref(input_),
                                         self.parameters["ZSTD_e_continue"]), "encode streaming continue")
                if destination.pos:
                    chunks.append(output.raw[:destination.pos])
                if input_.pos == before and destination.pos == 0:
                    raise ZstdError("encode streaming: no progress")
        input_ = _Buffer(None, 0, 0)
        while True:
            destination = _Buffer(C.addressof(output), self.output_chunk_size, 0)
            hint = self._check(self._cstream(context, C.byref(destination), C.byref(input_),
                                            self.parameters["ZSTD_e_end"]), "encode streaming end")
            if destination.pos:
                chunks.append(output.raw[:destination.pos])
            if hint == 0:
                return b"".join(chunks)
            if destination.pos == 0:
                raise ZstdError("encode streaming end: no progress")

    def decode(self, wire: bytes, dictionary: bytes | None = None, *, format: str = "standard",
               input_chunk_size: int | None = None) -> bytes:
        """Decode whole input with optional segmented input and bounded output."""
        wire = bytes(wire)
        if not wire or (input_chunk_size is not None and input_chunk_size <= 0):
            raise ZstdError("decode streaming: empty input or invalid input chunk size")
        context = self._dcreate()
        if not context:
            raise ReferenceUnavailable("ZSTD_createDCtx failed")
        try:
            self._check(self._dset(context, self.parameters["ZSTD_d_format"], self._format(format)),
                        "set decoder format")
            self._load_dictionary(self._dload, context, dictionary)
            output = C.create_string_buffer(self.output_chunk_size)
            chunks, total, hint = [], 0, 1
            chunk_size = input_chunk_size or len(wire)
            for start in range(0, len(wire), chunk_size):
                part = wire[start:start + chunk_size]
                source = C.create_string_buffer(part, len(part) + 1)
                input_ = _Buffer(C.addressof(source), len(part), 0)
                while True:
                    before = input_.pos
                    destination = _Buffer(C.addressof(output), self.output_chunk_size, 0)
                    hint = self._check(self._dstream(context, C.byref(destination), C.byref(input_)),
                                       "decode streaming")
                    total += destination.pos
                    if total > self.max_output_size:
                        raise ZstdError("decode streaming: output exceeds configured limit")
                    if destination.pos:
                        chunks.append(output.raw[:destination.pos])
                    if input_.pos == input_.size and (hint == 0 or destination.pos < self.output_chunk_size):
                        break
                    if before == input_.pos and destination.pos == 0:
                        raise ZstdError("decode streaming: no progress")
            if hint != 0:
                raise ZstdError("decode streaming: incomplete or truncated input")
            return b"".join(chunks)
        finally:
            self._dfree(context)

    def expect_error(self, wire: bytes, dictionary: bytes | None = None, *,
                     format: str = "standard") -> str:
        try:
            self.decode(wire, dictionary, format=format)
        except ZstdError as error:
            return str(error)
        raise AssertionError("Complete-dictionary reference unexpectedly accepted input")
