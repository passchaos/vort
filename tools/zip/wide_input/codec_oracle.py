"""Bounded independent raw Deflate and libzstd member decompression."""

from __future__ import annotations

import ctypes
import ctypes.util
import hashlib
from pathlib import Path
import zlib

from zip_structure import ZipMetadata, require

CHUNK = 65536
REPEAT = b"R" * CHUNK
MAX_ZSTD_WINDOW = 64 * 1024 * 1024


def member_chunks(path: Path, metadata: ZipMetadata):
    with path.open("rb") as source:
        source.seek(metadata.compressed_offset)
        remaining = metadata.compressed_size
        while remaining:
            chunk = source.read(min(CHUNK, remaining))
            require(bool(chunk), "truncated compressed member")
            remaining -= len(chunk)
            yield chunk


class OutputCheck:
    def __init__(self, count: int, progress=None):
        self.count = count
        self.size = 0
        self.crc32 = 0
        self.calls = 0
        self.max_chunk = 0
        self.progress = progress
        self.next_progress = 256 * 1024 * 1024

    def accept(self, output: bytes) -> None:
        require(len(output) <= CHUNK, "oracle output exceeds the bounded buffer")
        require(output == REPEAT[:len(output)], f"decoded content mismatch at {self.size}")
        self.size += len(output)
        require(self.size <= self.count, "oracle produced excess plaintext")
        self.crc32 = zlib.crc32(output, self.crc32) & 0xFFFFFFFF
        self.calls += 1
        self.max_chunk = max(self.max_chunk, len(output))
        if self.progress and self.size >= self.next_progress:
            self.progress(dict(output_written=self.size, crc32=self.crc32, calls=self.calls))
            self.next_progress = self.size + 256 * 1024 * 1024

    def receipt(self, metadata: ZipMetadata, consumed: int, wire_hash, codec: str) -> dict:
        require(self.size == self.count, "oracle decoded length mismatch")
        require(consumed == metadata.compressed_size, "oracle compressed extent mismatch")
        require(self.crc32 == metadata.crc32, "oracle/ZIP metadata CRC mismatch")
        return dict(codec=codec, input_read=consumed, output_written=self.size,
                    crc32=self.crc32, calls=self.calls, completed=True, eof=True,
                    all_output_bytes_checked=True, exact_compressed_extent_checked=True,
                    trailing_bytes=0, input_chunk_bytes=CHUNK, output_chunk_bytes=CHUNK,
                    maximum_output_chunk_bytes=self.max_chunk,
                    compressed_sha256=wire_hash.hexdigest(),
                    plaintext_retained=False, counter_seeding=False)


def decode_deflate(path: Path, metadata: ZipMetadata, progress=None) -> dict:
    decoder = zlib.decompressobj(-15)
    check = OutputCheck(metadata.uncompressed_size, progress)
    wire_hash = hashlib.sha256()
    consumed = 0
    source_bytes = 0
    for chunk in member_chunks(path, metadata):
        require(not decoder.eof, "raw Deflate bytes follow stream EOF")
        source_bytes += len(chunk)
        wire_hash.update(chunk)
        pending = chunk
        while True:
            before = len(pending)
            output = decoder.decompress(pending, CHUNK)
            tail = decoder.unused_data if decoder.eof else decoder.unconsumed_tail
            used = before - len(tail)
            require(used >= 0, "raw Deflate input accounting mismatch")
            consumed += used
            check.accept(output)
            pending = decoder.unconsumed_tail
            if decoder.eof:
                require(not pending and not decoder.unused_data,
                        "raw Deflate member contains trailing bytes")
                require(source_bytes == metadata.compressed_size,
                        "raw Deflate EOF precedes the compressed extent")
                break
            if not pending and len(output) < CHUNK:
                break
            require(used > 0 or bool(output), "raw Deflate oracle made no progress")
    require(decoder.eof, "truncated raw Deflate member")
    result = check.receipt(metadata, consumed, wire_hash, "Python zlib raw Deflate")
    result.update(wbits=-15, zlib_compile_version=zlib.ZLIB_VERSION,
                  zlib_runtime_version=zlib.ZLIB_RUNTIME_VERSION)
    return result


class ZstdInput(ctypes.Structure):
    _fields_ = [("src", ctypes.c_void_p), ("size", ctypes.c_size_t), ("pos", ctypes.c_size_t)]


class ZstdOutput(ctypes.Structure):
    _fields_ = [("dst", ctypes.c_void_p), ("size", ctypes.c_size_t), ("pos", ctypes.c_size_t)]


class ZstdLibrary:
    def __init__(self):
        self.name = ctypes.util.find_library("zstd")
        require(self.name is not None, "system libzstd is required for the Zstandard oracle")
        self.lib = ctypes.CDLL(self.name)
        declarations = {
            "ZSTD_versionString": ([], ctypes.c_char_p),
            "ZSTD_createDStream": ([], ctypes.c_void_p),
            "ZSTD_freeDStream": ([ctypes.c_void_p], ctypes.c_size_t),
            "ZSTD_initDStream": ([ctypes.c_void_p], ctypes.c_size_t),
            "ZSTD_DCtx_setParameter": ([ctypes.c_void_p, ctypes.c_int, ctypes.c_int], ctypes.c_size_t),
            "ZSTD_isError": ([ctypes.c_size_t], ctypes.c_uint),
            "ZSTD_getErrorName": ([ctypes.c_size_t], ctypes.c_char_p),
            "ZSTD_getFrameContentSize": ([ctypes.c_void_p, ctypes.c_size_t], ctypes.c_ulonglong),
            "ZSTD_decompressStream": ([ctypes.c_void_p, ctypes.POINTER(ZstdOutput),
                                       ctypes.POINTER(ZstdInput)], ctypes.c_size_t),
        }
        for name, (arguments, result) in declarations.items():
            function = getattr(self.lib, name)
            function.argtypes = arguments
            function.restype = result
        self.version = self.lib.ZSTD_versionString().decode("ascii")

    def checked(self, result: int) -> int:
        if self.lib.ZSTD_isError(result):
            raise AssertionError("libzstd: " + self.lib.ZSTD_getErrorName(result).decode("utf-8"))
        return result


def decode_zstd(path: Path, metadata: ZipMetadata, progress=None) -> dict:
    library = ZstdLibrary()
    lib = library.lib
    with path.open("rb") as source:
        source.seek(metadata.compressed_offset)
        prefix = source.read(min(CHUNK, metadata.compressed_size))
    require(prefix[:4] == b"\x28\xb5\x2f\xfd", "Zstandard member is not a standard frame")
    prefix_buffer = ctypes.create_string_buffer(prefix, len(prefix))
    declared_size = lib.ZSTD_getFrameContentSize(prefix_buffer, len(prefix))
    require(declared_size < (1 << 64) - 2, "Zstandard frame content size missing or malformed")
    require(declared_size == metadata.uncompressed_size, "Zstandard declared content size mismatch")
    stream = lib.ZSTD_createDStream()
    require(bool(stream), "libzstd could not create a DStream")
    check = OutputCheck(metadata.uncompressed_size, progress)
    wire_hash = hashlib.sha256()
    consumed = 0
    source_bytes = 0
    finished = False
    output_buffer = ctypes.create_string_buffer(CHUNK)
    try:
        library.checked(lib.ZSTD_initDStream(stream))
        # Stable ZSTD_d_windowLogMax parameter bounds the library's history.
        library.checked(lib.ZSTD_DCtx_setParameter(stream, 100, 26))
        for chunk in member_chunks(path, metadata):
            require(not finished, "Zstandard bytes follow frame EOF")
            source_bytes += len(chunk)
            wire_hash.update(chunk)
            input_buffer = ctypes.create_string_buffer(chunk, len(chunk))
            input_view = ZstdInput(ctypes.cast(input_buffer, ctypes.c_void_p), len(chunk), 0)
            while True:
                output_view = ZstdOutput(ctypes.cast(output_buffer, ctypes.c_void_p), CHUNK, 0)
                before = input_view.pos
                remaining = library.checked(lib.ZSTD_decompressStream(
                    stream, ctypes.byref(output_view), ctypes.byref(input_view)))
                used = input_view.pos - before
                require(0 <= used <= len(chunk) - before, "libzstd input accounting mismatch")
                consumed += used
                check.accept(output_buffer.raw[:output_view.pos])
                if remaining == 0:
                    require(input_view.pos == input_view.size and
                            source_bytes == metadata.compressed_size,
                            "Zstandard frame EOF precedes the exact member extent")
                    finished = True
                    break
                if input_view.pos == input_view.size and output_view.pos < CHUNK:
                    break
                require(used > 0 or output_view.pos > 0, "libzstd oracle made no progress")
        require(finished, "truncated Zstandard frame")
    finally:
        library.checked(lib.ZSTD_freeDStream(stream))
    result = check.receipt(metadata, consumed, wire_hash, "system libzstd DStream")
    result.update(libzstd_library=library.name, libzstd_version=library.version,
                  declared_content_size=declared_size, single_frame_checked=True,
                  maximum_window_bytes=MAX_ZSTD_WINDOW)
    return result
