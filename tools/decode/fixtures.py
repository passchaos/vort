"""Freeze plain inputs and independently verified reference-compressed frames."""
import ctypes
import hashlib
from pathlib import Path
import zlib

SILESIA = ("dickens", "mozilla", "mr", "nci", "ooffice", "osdb", "reymont", "samba", "sao", "webster", "xml", "x-ray")
LEVELS = {"deflate": (6, 9), "zstd": (3, 19), "brotli": (6, 11)}


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


class References:
    def __init__(self, config):
        self.config = config
        self.zstd = ctypes.CDLL(config["zstd"]["path"])
        self.zstd.ZSTD_versionString.restype = ctypes.c_char_p
        self.zstd.ZSTD_compressBound.argtypes = [ctypes.c_size_t]
        self.zstd.ZSTD_compressBound.restype = ctypes.c_size_t
        self.zstd.ZSTD_compress.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_int]
        self.zstd.ZSTD_compress.restype = ctypes.c_size_t
        self.zstd.ZSTD_decompress.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t]
        self.zstd.ZSTD_decompress.restype = ctypes.c_size_t
        self.zstd.ZSTD_isError.argtypes = [ctypes.c_size_t]
        self.zstd.ZSTD_isError.restype = ctypes.c_uint
        assert self.zstd.ZSTD_versionString().decode() == config["zstd"]["version"]
        # Load common first so both dependents use the selected closure.
        self.common = ctypes.CDLL(config["brotli"]["common"], mode=ctypes.RTLD_GLOBAL)
        self.encoder = ctypes.CDLL(config["brotli"]["encoder"])
        self.decoder = ctypes.CDLL(config["brotli"]["decoder"])
        for library, symbol in ((self.encoder, "BrotliEncoderVersion"), (self.decoder, "BrotliDecoderVersion")):
            getattr(library, symbol).restype = ctypes.c_uint32
        version = self.encoder.BrotliEncoderVersion()
        assert version == self.decoder.BrotliDecoderVersion()
        assert f"{version >> 24}.{(version >> 12) & 0xfff}.{version & 0xfff}" == config["brotli"]["version"]
        self.encoder.BrotliEncoderMaxCompressedSize.argtypes = [ctypes.c_size_t]
        self.encoder.BrotliEncoderMaxCompressedSize.restype = ctypes.c_size_t
        self.encoder.BrotliEncoderCompress.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_size_t, ctypes.c_void_p, ctypes.POINTER(ctypes.c_size_t), ctypes.c_void_p]
        self.encoder.BrotliEncoderCompress.restype = ctypes.c_int
        self.decoder.BrotliDecoderDecompress.argtypes = [ctypes.c_size_t, ctypes.c_void_p, ctypes.POINTER(ctypes.c_size_t), ctypes.c_void_p]
        self.decoder.BrotliDecoderDecompress.restype = ctypes.c_int

    def encode(self, codec, plain, level):
        if codec == "deflate":
            compressor = zlib.compressobj(level, zlib.DEFLATED, -15)
            wire = compressor.compress(plain) + compressor.flush()
            assert zlib.decompress(wire, -15) == plain
            return wire, {"api": "python.zlib.compressobj", "version": zlib.ZLIB_RUNTIME_VERSION, "level": level, "window_bits": -15}
        source = ctypes.create_string_buffer(plain)
        if codec == "zstd":
            capacity = self.zstd.ZSTD_compressBound(len(plain))
            output = ctypes.create_string_buffer(capacity)
            count = self.zstd.ZSTD_compress(output, capacity, source, len(plain), level)
            assert not self.zstd.ZSTD_isError(count)
            wire = output.raw[:count]
            decoded = ctypes.create_string_buffer(len(plain))
            size = self.zstd.ZSTD_decompress(decoded, len(plain), ctypes.create_string_buffer(wire), len(wire))
            assert not self.zstd.ZSTD_isError(size) and size == len(plain) and decoded.raw == plain
            return wire, {"api": "ZSTD_compress", "version": self.config["zstd"]["version"], "level": level}
        capacity = self.encoder.BrotliEncoderMaxCompressedSize(len(plain))
        assert capacity > 0
        output = ctypes.create_string_buffer(capacity)
        count = ctypes.c_size_t(capacity)
        assert self.encoder.BrotliEncoderCompress(level, 22, 0, len(plain), source, ctypes.byref(count), output) == 1
        wire = output.raw[:count.value]
        decoded = ctypes.create_string_buffer(len(plain))
        size = ctypes.c_size_t(len(plain))
        assert self.decoder.BrotliDecoderDecompress(len(wire), ctypes.create_string_buffer(wire), ctypes.byref(size), decoded) == 1
        assert size.value == len(plain) and decoded.raw == plain
        return wire, {"api": "BrotliEncoderCompress", "version": self.config["brotli"]["version"], "quality": level, "window_bits": 22, "mode": "generic"}


def freeze(out_dir, corpus, references, sizes, progress=print):
    root = Path(out_dir).resolve() / "fixtures"
    root.mkdir(parents=True, exist_ok=True)
    runtime = References(references)
    fixtures = []
    for name in SILESIA:
        original = (Path(corpus) / name).read_bytes()
        for size in sizes:
            plain = original if size == "full" else original[:int(size)]
            if size != "full" and len(plain) != int(size):
                raise ValueError(f"Corpus {name} is smaller than declared prefix {size}")
            plain_path = root / f"{name}.{size}.plain"
            plain_path.write_bytes(plain)
            for codec, levels in LEVELS.items():
                for level in levels:
                    key = f"{codec}/{name}/{size}/{level}"
                    wire, generator = runtime.encode(codec, plain, level)
                    encoded_path = root / f"{name}.{size}.{codec}.{level}.wire"
                    encoded_path.write_bytes(wire)
                    fixtures.append({"key": key, "codec": codec, "name": name, "size": size, "level": level, "scope": "silesia", "input_path": str(plain_path), "encoded_input_path": str(encoded_path), "input_bytes": len(plain), "input_first_byte": plain[0], "encoded_bytes": len(wire), "input_sha256": hashlib.sha256(plain).hexdigest(), "encoded_sha256": hashlib.sha256(wire).hexdigest(), "generator": generator})
                    progress(f"fixture {key}: plain={len(plain)} wire={len(wire)} verified", flush=True)
    return fixtures
