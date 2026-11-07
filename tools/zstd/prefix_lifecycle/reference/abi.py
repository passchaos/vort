"""Existing libzstd loader and matching-header ABI for prefix lifecycle tests."""
from __future__ import annotations
import ctypes as C
import ctypes.util
import hashlib
from pathlib import Path
import re


class ReferenceUnavailable(RuntimeError):
    pass


class ZstdError(RuntimeError):
    pass


class Buffer(C.Structure):
    _fields_ = [("data", C.c_void_p), ("size", C.c_size_t), ("pos", C.c_size_t)]


class FrameHeader(C.Structure):
    _fields_ = [("frameContentSize", C.c_ulonglong), ("windowSize", C.c_ulonglong),
                ("blockSizeMax", C.c_uint), ("frameType", C.c_int),
                ("headerSize", C.c_uint), ("dictID", C.c_uint),
                ("checksumFlag", C.c_uint), ("reserved1", C.c_uint), ("reserved2", C.c_uint)]


class DlInfo(C.Structure):
    _fields_ = [("name", C.c_char_p), ("base", C.c_void_p),
                ("symbol", C.c_char_p), ("address", C.c_void_p)]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def parameter(text: str, name: str) -> int:
    alias = re.search(r"^\s*#define\s+" + re.escape(name) + r"\s+(\w+)\s*$", text, re.M)
    if alias:
        return parameter(text, alias.group(1))
    match = re.search(r"\b" + re.escape(name) + r"\s*=\s*(\d+)\b", text)
    if match is None:
        raise ReferenceUnavailable(f"Matching header has no enum {name}")
    return int(match.group(1))


def version(text: str) -> str | None:
    parts = [re.search(r"^\s*#define\s+ZSTD_VERSION_" + part + r"\s+(\d+)\b", text, re.M)
             for part in ("MAJOR", "MINOR", "RELEASE")]
    return ".".join(part.group(1) for part in parts) if all(parts) else None


class ABI:
    def __init__(self, path=None, *, header=None):
        if path is not None:
            candidates = [str(Path(path).expanduser().resolve(strict=True))]
        else:
            local = Path.home() / "Work/zstd/lib"
            candidates = [str(item.resolve()) for item in (local / "libzstd.so", local / "libzstd.dylib") if item.is_file()]
            system = ctypes.util.find_library("zstd")
            if system:
                candidates.append(system)
        failures = []
        for selected in candidates:
            try:
                self.lib = C.CDLL(selected)
                break
            except OSError as error:
                failures.append(str(error))
        else:
            raise ReferenceUnavailable("No existing libzstd: " + "; ".join(failures))
        self.fn = {}
        self.bind("ZSTD_isError", C.c_uint, C.c_size_t)
        self.bind("ZSTD_getErrorName", C.c_char_p, C.c_size_t)
        version_fn = self.bind("ZSTD_versionString", C.c_char_p)
        self.version = version_fn().decode()
        self.version_number = self.bind("ZSTD_versionNumber", C.c_uint)()
        try:
            dladdr = C.CDLL(None).dladdr
            dladdr.restype, dladdr.argtypes = C.c_int, (C.c_void_p, C.POINTER(DlInfo))
            info = DlInfo()
            if not dladdr(C.cast(version_fn, C.c_void_p), C.byref(info)) or not info.name:
                raise ReferenceUnavailable("Cannot resolve actual libzstd path")
            self.path = Path(info.name.decode()).resolve(strict=True)
        except AttributeError:
            self.path = Path(selected).resolve(strict=True)
        if Path(selected).is_absolute() and self.path != Path(selected).resolve():
            raise ReferenceUnavailable("Resolved symbol belongs to another library")
        candidates = [Path(header).expanduser()] if header is not None else []
        if header is None:
            for parent in self.path.parents:
                candidates.extend((parent / "zstd.h", parent / "include/zstd.h"))
            candidates.extend((Path("/usr/include/zstd.h"), Path("/usr/local/include/zstd.h")))
        for candidate in candidates:
            if candidate.is_file() and version(candidate.read_text()) == self.version:
                self.header_path, self.header_text = candidate.resolve(), candidate.read_text()
                break
        else:
            raise ReferenceUnavailable(f"No matching zstd.h for {self.version}")
        names = ("ZSTD_c_compressionLevel", "ZSTD_c_contentSizeFlag", "ZSTD_c_checksumFlag",
                 "ZSTD_c_dictIDFlag", "ZSTD_c_format", "ZSTD_d_format", "ZSTD_d_forceIgnoreChecksum",
                 "ZSTD_f_zstd1", "ZSTD_f_zstd1_magicless", "ZSTD_dct_auto", "ZSTD_dct_rawContent",
                 "ZSTD_dct_fullDict", "ZSTD_dlm_byCopy", "ZSTD_e_continue", "ZSTD_e_flush", "ZSTD_e_end",
                 "ZSTD_reset_session_only", "ZSTD_reset_parameters", "ZSTD_reset_session_and_parameters")
        self.parameters = {name: parameter(self.header_text, name) for name in names}
        ptr, size, integer = C.c_void_p, C.c_size_t, C.c_int
        for side in ("C", "D"):
            self.bind("ZSTD_create" + side + "Ctx", ptr)
            self.bind("ZSTD_free" + side + "Ctx", size, ptr)
            self.bind("ZSTD_" + side + "Ctx_reset", size, ptr, integer)
            self.bind("ZSTD_" + side + "Ctx_setParameter", size, ptr, integer, integer)
            self.bind("ZSTD_" + side + "Ctx_getParameter", size, ptr, integer, C.POINTER(integer))
            self.bind("ZSTD_" + side + "Ctx_refPrefix", size, ptr, ptr, size)
            self.bind("ZSTD_" + side + "Ctx_refPrefix_advanced", size, ptr, ptr, size, integer)
            self.bind("ZSTD_" + side + "Ctx_loadDictionary_advanced", size, ptr, ptr, size, integer, integer)
        self.bind("ZSTD_CCtx_setPledgedSrcSize", size, ptr, C.c_ulonglong)
        self.bind("ZSTD_compressBound", size, size)
        self.bind("ZSTD_compress2", size, ptr, ptr, size, ptr, size)
        self.bind("ZSTD_decompressDCtx", size, ptr, ptr, size, ptr, size)
        self.bind("ZSTD_compressStream2", size, ptr, C.POINTER(Buffer), C.POINTER(Buffer), integer)
        self.bind("ZSTD_decompressStream", size, ptr, C.POINTER(Buffer), C.POINTER(Buffer))
        self.bind("ZSTD_getFrameHeader_advanced", size, C.POINTER(FrameHeader), ptr, size, integer)
        self.bind("ZSTD_getDictID_fromDict", C.c_uint, ptr, size)
        self.bind("ZDICT_getDictHeaderSize", size, ptr, size)
        self.bind("ZSTD_initDStream", size, ptr)
        self.bind("ZSTD_resetDStream", size, ptr)
        self.bind("ZSTD_writeSkippableFrame", size, ptr, size, ptr, size, C.c_uint)

    def bind(self, name, result, *arguments):
        try:
            function = getattr(self.lib, name)
        except AttributeError as error:
            raise ReferenceUnavailable(f"Missing symbol {name}") from error
        function.restype, function.argtypes = result, arguments
        self.fn[name] = function
        return function

    def result(self, value: int) -> dict:
        error = self.fn["ZSTD_getErrorName"](value).decode() if self.fn["ZSTD_isError"](value) else None
        return {"ret": int(value), "error": error}

    def check(self, value: int, operation: str) -> int:
        result = self.result(value)
        if result["error"]:
            raise ZstdError(operation + ": " + result["error"])
        return value
