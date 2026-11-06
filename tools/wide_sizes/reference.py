"""System libbrotli/libzstd streaming producers and bounded independent sinks."""
import ctypes as C
import ctypes.util
import hashlib
from pathlib import Path
import zlib

CHUNK = 65536
TILE_LEN = 1024 * 1024
WORD = b"information"
TILE = (WORD * (TILE_LEN // len(WORD) + 1))[:TILE_LEN]
REPEATED = b"R" * CHUNK
METADATA = b"wide-sizes-meta"
P = C.POINTER(C.c_uint8)


def require(ok, detail):
    if not ok:
        raise AssertionError(detail)


def bind(lib, name, result, *arguments):
    fn = getattr(lib, name)
    fn.restype, fn.argtypes = result, list(arguments)
    return fn


def pointer(data):
    return C.cast(C.c_char_p(data), P)


class Input(C.Structure):
    _fields_ = [("src", C.c_void_p), ("size", C.c_size_t), ("pos", C.c_size_t)]


class Output(C.Structure):
    _fields_ = [("dst", C.c_void_p), ("size", C.c_size_t), ("pos", C.c_size_t)]


class Libraries:
    def __init__(self):
        require(C.sizeof(C.c_size_t) == 8, "oracle runs in a native 64-bit Python process")
        self.z = C.CDLL(ctypes.util.find_library("zstd"))
        self.be = C.CDLL(ctypes.util.find_library("brotlienc"))
        self.bd = C.CDLL(ctypes.util.find_library("brotlidec"))
        self.z_version = bind(self.z, "ZSTD_versionString", C.c_char_p)().decode()
        self.br_version = bind(self.bd, "BrotliDecoderVersion", C.c_uint32)()
        self.z_error = bind(self.z, "ZSTD_isError", C.c_uint, C.c_size_t)
        self.z_create = bind(self.z, "ZSTD_createCCtx", C.c_void_p)
        self.z_free = bind(self.z, "ZSTD_freeCCtx", C.c_size_t, C.c_void_p)
        self.z_param = bind(self.z, "ZSTD_CCtx_setParameter", C.c_size_t, C.c_void_p, C.c_int, C.c_int)
        self.z_pledge = bind(self.z, "ZSTD_CCtx_setPledgedSrcSize", C.c_size_t, C.c_void_p, C.c_uint64)
        self.z_encode = bind(self.z, "ZSTD_compressStream2", C.c_size_t, C.c_void_p, C.POINTER(Output), C.POINTER(Input), C.c_int)
        self.z_dcreate = bind(self.z, "ZSTD_createDStream", C.c_void_p)
        self.z_dfree = bind(self.z, "ZSTD_freeDStream", C.c_size_t, C.c_void_p)
        self.z_dinit = bind(self.z, "ZSTD_initDStream", C.c_size_t, C.c_void_p)
        self.z_decode = bind(self.z, "ZSTD_decompressStream", C.c_size_t, C.c_void_p, C.POINTER(Output), C.POINTER(Input))
        self.br_create = bind(self.be, "BrotliEncoderCreateInstance", C.c_void_p, C.c_void_p, C.c_void_p, C.c_void_p)
        self.br_destroy = bind(self.be, "BrotliEncoderDestroyInstance", None, C.c_void_p)
        self.br_param = bind(self.be, "BrotliEncoderSetParameter", C.c_int, C.c_void_p, C.c_int, C.c_uint32)
        self.br_encode = bind(self.be, "BrotliEncoderCompressStream", C.c_int, C.c_void_p, C.c_int, C.POINTER(C.c_size_t), C.POINTER(P), C.POINTER(C.c_size_t), C.POINTER(P), C.POINTER(C.c_size_t))
        self.br_finished = bind(self.be, "BrotliEncoderIsFinished", C.c_int, C.c_void_p)
        self.br_dcreate = bind(self.bd, "BrotliDecoderCreateInstance", C.c_void_p, C.c_void_p, C.c_void_p, C.c_void_p)
        self.br_ddestroy = bind(self.bd, "BrotliDecoderDestroyInstance", None, C.c_void_p)
        self.br_decode = bind(self.bd, "BrotliDecoderDecompressStream", C.c_int, C.c_void_p, C.POINTER(C.c_size_t), C.POINTER(P), C.POINTER(C.c_size_t), C.POINTER(P), C.POINTER(C.c_size_t))

    def checked(self, result):
        require(not self.z_error(result), "system zstd error")
        return result

    def produce(self, family, path, count):
        state = self.z_create() if family == "zstd" else self.br_create(None, None, None)
        require(state, "reference encoder state")
        if family == "zstd":
            self.checked(self.z_param(state, 100, 1))
            self.checked(self.z_param(state, 201, 1))
            self.checked(self.z_pledge(state, count))
        else:
            require(self.br_param(state, 1, 1) and self.br_param(state, 2, 16), "Brotli Q1/window16")
        buffer = C.create_string_buffer(CHUNK)
        accepted, crc, calls, physical = 0, 0, 0, 0
        digest = hashlib.sha256()
        def emit(sink, piece, operation):
            nonlocal accepted, crc, calls, physical
            before_accepted = 0
            if family == "zstd":
                incoming = Input(C.cast(C.c_char_p(piece), C.c_void_p), len(piece), 0)
            else:
                incoming_size, incoming_ptr = C.c_size_t(len(piece)), pointer(piece)
            while True:
                if family == "zstd":
                    before = incoming.pos
                    output = Output(C.cast(buffer, C.c_void_p), CHUNK, 0)
                    result = self.checked(self.z_encode(state, C.byref(output), C.byref(incoming), operation))
                    consumed, written = incoming.pos - before, output.pos
                    finished = result == 0 if operation == 2 else incoming.pos == incoming.size
                else:
                    before = incoming_size.value
                    output_size, output_ptr, total = C.c_size_t(CHUNK), C.cast(buffer, P), C.c_size_t()
                    require(self.br_encode(state, operation, C.byref(incoming_size), C.byref(incoming_ptr), C.byref(output_size), C.byref(output_ptr), C.byref(total)), "reference Brotli encode")
                    consumed, written = before - incoming_size.value, CHUNK - output_size.value
                    finished = bool(self.br_finished(state)) if operation == 2 else incoming_size.value == 0 and written < CHUNK
                data = buffer.raw[:written]
                sink.write(data)
                digest.update(data)
                physical += written
                calls += 1
                if operation != 3:
                    crc = zlib.crc32(piece[before_accepted:before_accepted + consumed], crc)
                    accepted += consumed
                before_accepted += consumed
                if finished:
                    break
                require(consumed or written, "reference encoder no progress")
        try:
            with Path(path).open("wb") as sink:
                if family == "brotli":
                    emit(sink, METADATA, 3)
                while accepted < count:
                    emit(sink, REPEATED[:min(CHUNK, count - accepted)], 0)
                emit(sink, b"", 2)
        finally:
            self.z_free(state) if family == "zstd" else self.br_destroy(state)
        require(accepted == count, "actual reference source count")
        return dict(actual_source_bytes=accepted, source_crc32=crc & 0xFFFFFFFF,
                    wire_bytes=physical, wire_sha256=digest.hexdigest(), calls=calls,
                    metadata_bytes=len(METADATA) if family == "brotli" else 0,
                    source_chunk_bytes=CHUNK)

    def sink(self, family, count, dictionary=False):
        return Sink(self, family, count, dictionary)


class Sink:
    def __init__(self, libs, family, count, dictionary):
        self.libs, self.family, self.count, self.dictionary = libs, family, count, dictionary
        self.state = libs.z_dcreate() if family == "zstd" else libs.br_dcreate(None, None, None)
        require(self.state, "reference decoder state")
        if family == "zstd":
            libs.checked(libs.z_dinit(self.state))
        self.buffer = C.create_string_buffer(CHUNK)
        self.receipt = dict(input_read=0, output_written=0, calls=0, crc32=0,
                            completed=False, content_checked_bytes=0)
        self.digest = hashlib.sha256()

    def feed(self, piece):
        require(not self.receipt["completed"], "reference trailing wire")
        self.digest.update(piece)
        if self.family == "zstd":
            incoming = Input(C.cast(C.c_char_p(piece), C.c_void_p), len(piece), 0)
        else:
            incoming_size, incoming_ptr = C.c_size_t(len(piece)), pointer(piece)
        while True:
            if self.family == "zstd":
                before = incoming.pos
                output = Output(C.cast(self.buffer, C.c_void_p), CHUNK, 0)
                result = self.libs.checked(self.libs.z_decode(self.state, C.byref(output), C.byref(incoming)))
                consumed, written = incoming.pos - before, output.pos
                remaining, done = incoming.size - incoming.pos, result == 0
            else:
                before = incoming_size.value
                output_size, output_ptr, total = C.c_size_t(CHUNK), C.cast(self.buffer, P), C.c_size_t()
                result = self.libs.br_decode(self.state, C.byref(incoming_size), C.byref(incoming_ptr), C.byref(output_size), C.byref(output_ptr), C.byref(total))
                require(result != 0, "reference Brotli decode error")
                consumed, written = before - incoming_size.value, CHUNK - output_size.value
                remaining, done = incoming_size.value, result == 1
            data = self.buffer.raw[:written]
            position = self.receipt["output_written"]
            require(position + written <= self.count, "reference excess output")
            if self.dictionary:
                phase = position % TILE_LEN
                expected = TILE[phase:phase + written]
                if len(expected) < written:
                    expected += TILE[:written - len(expected)]
            else:
                expected = REPEATED[:written]
            require(data == expected, "reference decoded content mismatch")
            self.receipt["input_read"] += consumed
            self.receipt["output_written"] += written
            self.receipt["content_checked_bytes"] += written
            self.receipt["crc32"] = zlib.crc32(data, self.receipt["crc32"])
            self.receipt["calls"] += 1
            self.receipt["completed"] = done
            if done:
                require(remaining == 0, "reference trailing bytes")
                return
            if remaining == 0 and written < CHUNK:
                return
            require(consumed or written, "reference decoder no progress")

    def finish(self):
        require(self.receipt["completed"] and self.receipt["output_written"] == self.count, "actual reference EOF/output receipt")
        self.receipt["crc32"] &= 0xFFFFFFFF
        self.receipt["wire_sha256"] = self.digest.hexdigest()
        return dict(self.receipt)

    def close(self):
        self.libs.z_dfree(self.state) if self.family == "zstd" else self.libs.br_ddestroy(self.state)
