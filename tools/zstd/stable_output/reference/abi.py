"""Verified existing-library selection and matching-header ABI parsing."""
import ctypes as C
import ctypes.util
import hashlib
from pathlib import Path
import re


class ReferenceUnavailable(RuntimeError):
    pass


class Buffer(C.Structure):
    _fields_ = [("data", C.c_void_p), ("size", C.c_size_t), ("pos", C.c_size_t)]


class Bounds(C.Structure):
    _fields_ = [("error", C.c_size_t), ("lower", C.c_int), ("upper", C.c_int)]


class DlInfo(C.Structure):
    _fields_ = [("name", C.c_char_p), ("base", C.c_void_p),
                ("symbol", C.c_char_p), ("address", C.c_void_p)]


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def parameter(text, name):
    alias = re.search(r"^\s*#define\s+" + re.escape(name) + r"\s+(\w+)\s*$", text, re.M)
    if alias:
        return parameter(text, alias.group(1))
    value = re.search(r"\b" + re.escape(name) + r"\s*=\s*(\d+)\b", text)
    if value is None:
        raise ReferenceUnavailable("Matching header does not declare " + name)
    return int(value.group(1))


def load(path=None):
    candidates = [str(Path(path).expanduser().resolve(strict=True))] if path else []
    if path is None:
        local = Path.home() / "Work/zstd/lib/libzstd.so"
        if local.is_file():
            candidates.append(str(local.resolve()))
        system = ctypes.util.find_library("zstd")
        if system:
            candidates.append(system)
    failures = []
    for candidate in candidates:
        try:
            return C.CDLL(candidate), candidate
        except OSError as error:
            failures.append(str(error))
    raise ReferenceUnavailable("No existing libzstd: " + "; ".join(failures))


def loaded_path(function, selected):
    dladdr = C.CDLL(None).dladdr
    dladdr.restype, dladdr.argtypes = C.c_int, (C.c_void_p, C.POINTER(DlInfo))
    info = DlInfo()
    if not dladdr(C.cast(function, C.c_void_p), C.byref(info)) or not info.name:
        raise ReferenceUnavailable("Cannot identify the loaded libzstd symbol")
    actual = Path(info.name.decode()).resolve(strict=True)
    if Path(selected).is_absolute() and actual != Path(selected).resolve():
        raise ReferenceUnavailable("Zstd symbol comes from a different library")
    return actual


def header(path, version, explicit=None):
    candidates = [Path(explicit).expanduser()] if explicit else []
    if not explicit:
        for parent in path.parents:
            candidates += [parent / "zstd.h", parent / "include/zstd.h"]
        candidates += [Path("/usr/include/zstd.h"), Path("/usr/local/include/zstd.h")]
    for candidate in dict.fromkeys(candidates):
        if not candidate.is_file():
            continue
        text = candidate.read_text()
        parts = [re.search(r"^\s*#define\s+ZSTD_VERSION_" + part + r"\s+(\d+)\b", text, re.M)
                 for part in ("MAJOR", "MINOR", "RELEASE")]
        if all(parts) and ".".join(part.group(1) for part in parts) == version:
            return candidate.resolve(), text
    raise ReferenceUnavailable("No matching zstd.h for loaded library " + version)
