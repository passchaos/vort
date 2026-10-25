#!/usr/bin/env python3
"""Independent full-range Brotli metadata QA; uses built probes and system libs.

No compiler, installer, benchmark timer, or Git operation is run. Metadata bodies
live in files and are identified by length and SHA-256, never copied into JSON.
"""
from __future__ import annotations

import argparse
import ctypes as C
import ctypes.util
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import sys
import sysconfig

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
MAX_METADATA = 1 << 24
QUALITIES = (0, 1, 4, 8, 10, 11)
APIS = ("one_shot", "chunks", "reusable", "incremental_options", "incremental_prefix", "incremental_mid")
BOUNDARIES = (0, 1, 255, 256, 257, 65535, 65536, 65537, MAX_METADATA)
PAYLOAD = (b"Brotli metadata remains opaque across API routes.\x00\xff\n" * 4)[:193]


def require(condition, context):
    if not condition:
        raise AssertionError(context)


def digest(data):
    return hashlib.sha256(data).hexdigest()


class Bits:
    def __init__(self, wire, offset=0):
        self.wire, self.offset = wire, offset

    def take(self, width):
        require(self.offset + width <= len(self.wire) * 8, ("truncated bits", self.offset, width))
        value = sum(((self.wire[(self.offset + bit) // 8] >> ((self.offset + bit) % 8)) & 1) << bit
                    for bit in range(width))
        self.offset += width
        return value

    def align(self):
        count = (-self.offset) % 8
        require(self.take(count) == 0, ("nonzero padding", self.offset - count))
        return count


def window(bits):
    if bits.take(1) == 0:
        return {"window_bits": 16, "large_window": False, "prefix_bits": bits.offset}
    low = bits.take(3)
    if low:
        return {"window_bits": 17 + low, "large_window": False, "prefix_bits": bits.offset}
    tail = bits.take(3)
    if tail != 1:
        return {"window_bits": 17 if tail == 0 else tail + 8, "large_window": False, "prefix_bits": bits.offset}
    require(bits.take(1) == 0, "reserved Large Window bit")
    width = bits.take(6)
    require(10 <= width <= 30, "invalid Large Window width")
    return {"window_bits": width, "large_window": True, "prefix_bits": bits.offset}


def metadata_header(bits, start):
    require(bits.take(1) == 0, ("reserved metadata bit", start))
    width = bits.take(2)
    value = bits.take(width * 8) if width else 0
    require(width <= 1 or value >> ((width - 1) * 8) != 0, ("overlong metadata length", start, width, value))
    length = value + 1 if width else 0
    require(length <= MAX_METADATA, "metadata length exceeds format")
    field_end = bits.offset
    padding = bits.align()
    return {"start_bit": start, "field_end_bit": field_end, "header_bits": bits.offset - start,
            "mskipbytes": width, "length_minus_one": value if width else None, "metadata_bytes": length,
            "padding_bits": padding, "body_byte_offset": bits.offset // 8, "end_bit": bits.offset + length * 8}


def block_prefix(bits):
    start = bits.offset
    final = bool(bits.take(1))
    if final and bits.take(1):
        return {"kind": "final_empty", "start_bit": start, "end_bit": bits.offset}
    nibbles = bits.take(2) + 4
    if nibbles == 7:
        require(not final, "metadata block must be non-final")
        return {"kind": "metadata", **metadata_header(bits, start)}
    value = bits.take(nibbles * 4)
    require(nibbles == 4 or value >> ((nibbles - 1) * 4) != 0, "overlong content length")
    uncompressed = bool(bits.take(1)) if not final else False
    return {"kind": "stored" if uncompressed else "compressed", "start_bit": start,
            "final": final, "decoded_bytes": value + 1, "header_field_end_bit": bits.offset}


def metadata_body(wire, row, expected):
    offset, count = row["body_byte_offset"], row["metadata_bytes"]
    require(offset + count <= len(wire), ("truncated metadata body", row))
    body = wire[offset:offset + count]
    require(body == expected, ("metadata body differs", count, len(expected)))
    row["metadata_sha256"] = digest(body)
    minimal = 0 if count == 0 else 1 if count <= 256 else 2 if count <= 65536 else 3
    require(row["mskipbytes"] == minimal, ("nonminimal MSKIPBYTES", row))
    return row


def inspect_stored(wire, payload, metadata, expected_count):
    bits = Bits(wire)
    profile = window(bits)
    rows, metadata_rows, plaintext = [], [], bytearray()
    while True:
        row = block_prefix(bits)
        rows.append(row)
        if row["kind"] == "metadata":
            metadata_rows.append(metadata_body(wire, row, metadata))
            bits.offset = row["end_bit"]
        elif row["kind"] == "stored":
            row["padding_bits"] = bits.align()
            offset, count = bits.offset // 8, row["decoded_bytes"]
            require(offset + count <= len(wire), "truncated stored body")
            plaintext.extend(wire[offset:offset + count])
            bits.offset += count * 8
            row["end_bit"] = bits.offset
        elif row["kind"] == "final_empty":
            end_bit = bits.offset
            padding = bits.align()
            require(bits.offset == len(wire) * 8, "trailing Brotli bytes")
            break
        else:
            raise AssertionError("stored encoder emitted compressed block")
    require(bytes(plaintext) == payload and len(metadata_rows) == expected_count, "stored contents/metadata count")
    return {**profile, "scope": "all blocks and complete stored plaintext", "blocks": rows,
            "metadata_blocks": metadata_rows, "end_bit": end_bit, "padding_bits": padding,
            "serialized_bits": len(wire) * 8}


class Reference:
    """ABI-only ctypes binding to installed libbrotli encoder and decoder."""
    def __init__(self, encoder=None, decoder=None, common=None):
        self.requested = {"encoder": str(encoder or ctypes.util.find_library("brotlienc")),
                          "decoder": str(decoder or ctypes.util.find_library("brotlidec")),
                          "common": str(common) if common else None}
        self.common = C.CDLL(str(common), mode=C.RTLD_GLOBAL) if common else None
        self.enc = C.CDLL(str(encoder or ctypes.util.find_library("brotlienc")))
        self.dec = C.CDLL(str(decoder or ctypes.util.find_library("brotlidec")))
        ptr, size, number = C.c_void_p, C.c_size_t, C.c_int
        def bind(lib, name, result, *args):
            fn = getattr(lib, name)
            fn.restype, fn.argtypes = result, args
            return fn
        self.ec = bind(self.enc, "BrotliEncoderCreateInstance", ptr, ptr, ptr, ptr)
        self.ed = bind(self.enc, "BrotliEncoderDestroyInstance", None, ptr)
        self.ep = bind(self.enc, "BrotliEncoderSetParameter", number, ptr, number, C.c_uint32)
        self.es = bind(self.enc, "BrotliEncoderCompressStream", number, ptr, number, C.POINTER(size),
                       C.POINTER(ptr), C.POINTER(size), C.POINTER(ptr), C.POINTER(size))
        self.ef = bind(self.enc, "BrotliEncoderIsFinished", number, ptr)
        self.eh = bind(self.enc, "BrotliEncoderHasMoreOutput", number, ptr)
        self.dc = bind(self.dec, "BrotliDecoderCreateInstance", ptr, ptr, ptr, ptr)
        self.dd = bind(self.dec, "BrotliDecoderDestroyInstance", None, ptr)
        self.dp = bind(self.dec, "BrotliDecoderSetParameter", number, ptr, number, C.c_uint32)
        self.ds = bind(self.dec, "BrotliDecoderDecompressStream", number, ptr, C.POINTER(size),
                       C.POINTER(ptr), C.POINTER(size), C.POINTER(ptr), C.POINTER(size))
        self.de = bind(self.dec, "BrotliDecoderGetErrorCode", number, ptr)
        self.versions = {"encoder": bind(self.enc, "BrotliEncoderVersion", C.c_uint32)(),
                         "decoder": bind(self.dec, "BrotliDecoderVersion", C.c_uint32)()}

    def identity(self):
        files = sorted({line.split()[-1] for line in Path("/proc/self/maps").read_text().splitlines()
                        if line.split()[-1].startswith("/") and "libbrotli" in line.split()[-1]})
        class DlInfo(C.Structure):
            _fields_ = [("name", C.c_char_p), ("base", C.c_void_p), ("symbol", C.c_char_p), ("address", C.c_void_p)]
        dladdr = C.CDLL(None).dladdr
        dladdr.restype, dladdr.argtypes = C.c_int, (C.c_void_p, C.POINTER(DlInfo))
        owners = {}
        for name, symbol in (("encoder", self.es), ("decoder", self.ds),
                             ("encoder_common", getattr(self.enc, "BrotliGetDictionary")),
                             ("decoder_common", getattr(self.dec, "BrotliGetDictionary"))):
            info = DlInfo()
            require(dladdr(C.cast(symbol, C.c_void_p), C.byref(info)) and info.name, ("reference symbol provenance", name))
            path = Path(info.name.decode()).resolve()
            owners[name] = {"path": str(path), "sha256": digest(path.read_bytes())}
        if self.common is not None:
            require(owners["encoder_common"]["path"] == str(Path(self.requested["common"]).resolve()) and
                    owners["decoder_common"]["path"] == str(Path(self.requested["common"]).resolve()),
                    ("reference common dependency differs from explicit library", owners))
        return {"requested_libraries": self.requested, "symbol_owners": owners,
                "common_load_mode": "RTLD_GLOBAL before encoder/decoder" if self.common is not None else "system dependency resolution",
                "versions": {key: {"packed": value, "version": f"{value >> 24}.{(value >> 12) & 4095}.{value & 4095}"}
                             for key, value in self.versions.items()},
                "libraries": [{"path": str(Path(path).resolve()), "sha256": digest(Path(path).read_bytes())} for path in files],
                "encode_operation": "BROTLI_OPERATION_EMIT_METADATA (3), one full body per call sequence"}

    def encode(self, payload, metadata, *, large=False, mid=False):
        state = self.ec(None, None, None)
        require(state, "libbrotli encoder allocation")
        output = bytearray()
        try:
            require(self.ep(state, 1, 5) and self.ep(state, 6, int(large)) and self.ep(state, 2, 25 if large else 16),
                    "libbrotli encoder parameters")
            def operation(op, body):
                source = C.create_string_buffer(body, len(body) + 1)
                remaining, next_in = C.c_size_t(len(body)), C.c_void_p(C.addressof(source))
                while True:
                    target = C.create_string_buffer(b"\xa5" * (65536 + 16), 65536 + 16)
                    capacity, next_out, total = C.c_size_t(65536), C.c_void_p(C.addressof(target) + 8), C.c_size_t()
                    before = remaining.value
                    ok = self.es(state, op, C.byref(remaining), C.byref(next_in), C.byref(capacity), C.byref(next_out), C.byref(total))
                    require(ok, ("libbrotli encode operation", op, len(body)))
                    written = 65536 - capacity.value
                    require(target.raw[:8] == b"\xa5" * 8 and target.raw[-8:] == b"\xa5" * 8, "reference encode output guards")
                    output.extend(target.raw[8:8 + written])
                    if op == 2 and self.ef(state):
                        break
                    if op != 2 and remaining.value == 0 and not self.eh(state):
                        break
                    require(before != remaining.value or written != 0, "reference encoder made no progress")
            if mid:
                operation(0, payload[:len(payload) // 2])
            operation(3, metadata)
            operation(2, payload[len(payload) // 2:] if mid else payload)
            return bytes(output)
        finally:
            self.ed(state)

    def decode(self, wire, expected, *, allow_large=False):
        state = self.dc(None, None, None)
        require(state, "libbrotli decoder allocation")
        try:
            require(self.dp(state, 1, int(allow_large)), "libbrotli decoder Large Window setting")
            source = C.create_string_buffer(wire, len(wire) + 1)
            capacity = len(expected) + 1
            target = C.create_string_buffer(b"\xa5" * (capacity + 16), capacity + 16)
            available, next_in = C.c_size_t(len(wire)), C.c_void_p(C.addressof(source))
            room, next_out, total = C.c_size_t(capacity), C.c_void_p(C.addressof(target) + 8), C.c_size_t()
            status = self.ds(state, C.byref(available), C.byref(next_in), C.byref(room), C.byref(next_out), C.byref(total))
            written = capacity - room.value
            require(target.raw[:8] == b"\xa5" * 8 and target.raw[-8:] == b"\xa5" * 8, "reference decode output guards")
            result = {"status": status, "decoder_error": self.de(state), "input_read": len(wire) - available.value,
                      "output_written": written, "output_sha256": digest(target.raw[8:8 + written]),
                      "caller_guards_verified": True}
            result["complete_contents_verified"] = status == 1 and not available.value and target.raw[8:8 + written] == expected
            return result
        finally:
            self.dd(state)


def installed_reference():
    # A soname lookup after an explicit latest library was loaded can return
    # that already-loaded object. Resolve installed files before CDLL instead.
    multiarch = sysconfig.get_config_var("MULTIARCH")
    roots = [Path("/usr/lib"), Path("/lib")]
    if multiarch:
        roots = [root / multiarch for root in roots] + roots
    paths = []
    for library in ("brotlienc", "brotlidec"):
        soname = ctypes.util.find_library(library)
        require(soname, ("installed reference library", library))
        path = next((root / soname for root in roots if (root / soname).exists()), None)
        require(path is not None, ("resolve installed reference file", soname))
        paths.append(path.resolve())
    return Reference(*paths)


def find_mid_metadata(wire, payload, metadata, reference, large):
    """Prove a candidate ends a valid independently decodable content prefix.

    Metadata ends on a byte boundary. Appending ISLAST+ISLASTEMPTY to that
    prefix gives a standalone stream containing exactly the preceding payload.
    This avoids interpreting compressed entropy bits as metadata by pattern.
    """
    starts = []
    if metadata:
        position = wire.find(metadata)
        while position >= 0:
            starts.extend(range(max(0, position * 8 - 37), position * 8))
            position = wire.find(metadata, position + 1)
    else:
        starts = range(len(wire) * 8)
    candidates = {}
    for start in starts:
        try:
            bits = Bits(wire, start)
            row = block_prefix(bits)
            if row["kind"] != "metadata" or row["metadata_bytes"] != len(metadata):
                continue
            metadata_body(wire, row, metadata)
            end = row["end_bit"] // 8
            prefix = reference.decode(wire[:end] + b"\x03", payload[:len(payload) // 2], allow_large=large)
            if prefix["complete_contents_verified"]:
                row["independent_prefix_completion"] = prefix
                candidates[start] = row
        except AssertionError:
            continue
    require(len(candidates) == 1, ("unique independently proven mid-stream metadata", list(candidates)))
    return next(iter(candidates.values()))


def inspect_planned(wire, payload, metadata, count, api, reference, large):
    bits = Bits(wire)
    profile = window(bits)
    if api == "incremental_mid":
        row = find_mid_metadata(wire, payload, metadata, reference, large)
        return {**profile, "scope": "metadata header/body and reference-proven preceding content prefix", "metadata_blocks": [row]}
    first = block_prefix(bits)
    rows = []
    if count:
        require(first["kind"] == "metadata", "missing metadata prefix")
        rows.append(metadata_body(wire, first, metadata))
        bits.offset = first["end_bit"]
        suffix = block_prefix(bits)
        require(suffix["kind"] != "metadata", "duplicate prefix metadata")
    else:
        require(first["kind"] != "metadata", "empty options metadata changed legacy prefix")
        suffix = first
    return {**profile, "scope": "metadata prefix header/body and following block prefix", "metadata_blocks": rows,
            "following_block_prefix": suffix}


def pack(fields, body=b"", final=True, prefix_offset=0):
    bits = [0] * prefix_offset
    bits.extend((value >> bit) & 1 for value, width in fields for bit in range(width))
    bits.extend([0] * ((-len(bits)) % 8))
    wire = bytes(sum(value << bit for bit, value in enumerate(bits[index:index + 8])) for index in range(0, len(bits), 8))
    return wire + body + (b"\x03" if final else b"")


def reference_stream(reference, payload, metadata, large):
    native = reference.encode(payload, metadata, large=large)
    decoded = reference.decode(native, payload, allow_large=large)
    if decoded["complete_contents_verified"]:
        return native, "native BROTLI_OPERATION_EMIT_METADATA", None
    # Installed 1.0.9 mis-encodes length 1 as MSKIPBYTES=0. Keep that wire
    # as a negative artifact; do not claim it is an interoperable encoder.
    require(len(metadata) == 1 and reference.versions["encoder"] == 0x01000009 and decoded["decoder_error"] == -15,
            ("unexpected native reference encoder defect", len(metadata), decoded))
    bits = Bits(native)
    window(bits)
    header = block_prefix(bits)
    require(header["kind"] == "metadata" and header["mskipbytes"] == 0 and header["metadata_bytes"] == 0,
            "libbrotli 1.0.9 one-byte defect differs")
    zero = reference.encode(payload, b"", large=large)
    bits = Bits(zero)
    window(bits)
    zero_header = block_prefix(bits)
    fields = ((1, 1), (0, 3), (1, 3), (0, 1), (25, 6)) if large else ((0, 1),)
    prefix = pack(fields + ((0, 1), (3, 2), (0, 1), (1, 2), (0, 8)), metadata, final=False)
    wire = prefix + zero[zero_header["end_bit"] // 8:]
    require(reference.decode(wire, payload, allow_large=large)["complete_contents_verified"],
            "independent one-byte metadata header reference decode")
    return wire, "independent RFC one-byte metadata header with native compressed suffix", {
        "wire": native, "reference_decode": decoded, "expected_target_error": "CorruptFrame",
        "reason": "libbrotlienc 1.0.9 emits MSKIPBYTES=0 for a one-byte body"}


def self_check(reference):
    for length in BOUNDARIES:
        width = 0 if length == 0 else 1 if length <= 256 else 2 if length <= 65536 else 3
        for offset in range(8):
            wire = pack(((0, 1), (3, 2), (0, 1), (width, 2), (max(0, length - 1), width * 8)), final=False, prefix_offset=offset)
            bits = Bits(wire, offset)
            row = block_prefix(bits)
            require(row["metadata_bytes"] == length and row["mskipbytes"] == width and
                    row["end_bit"] == ((offset + 6 + width * 8 + 7) // 8) * 8 + length * 8,
                    "metadata hand-packed geometry self-check")
    for length in (0, 1, 256, 257, 65536, 65537):
        metadata = bytes((index * 29 + 7) & 255 for index in range(length))
        wire, _, _ = reference_stream(reference, PAYLOAD, metadata, False)
        require(reference.decode(wire, PAYLOAD)["complete_contents_verified"], "reference metadata self round trip")
        rows = inspect_planned(wire, PAYLOAD, metadata, 1, "one_shot", reference, False)
        require(rows["metadata_blocks"][0]["mskipbytes"] == (0 if not length else 1 if length <= 256 else 2 if length <= 65536 else 3),
                "reference native metadata field width")
    mid = reference.encode(PAYLOAD, b"", mid=True)
    find_mid_metadata(mid, PAYLOAD, b"", reference, False)


def source_identity():
    paths = [ROOT / "src/br.zig", ROOT / "src/huffman.zig", ROOT / "src/core.zig",
             ROOT / "tools/br/metadata_probe.zig", Path(__file__).resolve()]
    paths += sorted((ROOT / "src/br").rglob("*.zig"))
    records = [{"path": str(path.relative_to(ROOT)), "sha256": digest(path.read_bytes())} for path in paths]
    return {"files": records, "sha256": digest(json.dumps(records, sort_keys=True).encode())}


def matrix():
    codecs = [("stored", 0)] + [("planned", quality) for quality in QUALITIES]
    for codec, quality in codecs:
        for api in APIS:
            for large in (False, True):
                for length in (0, 65537):
                    yield codec, quality, api, large, length
    for length in (1, 255, 256, 257, 65535, 65536):
        for large in (False, True):
            yield "stored", 0, "one_shot", large, length
            yield "planned", 11, "incremental_prefix", large, length
    yield "stored", 0, "one_shot", False, MAX_METADATA
    yield "planned", 11, "incremental_prefix", True, MAX_METADATA


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", type=Path, help="already-built public br probe; never compiled here")
    parser.add_argument("--directory", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--reference-encoder", type=Path)
    parser.add_argument("--reference-decoder", type=Path)
    parser.add_argument("--reference-common", type=Path, help="load globally before explicit encoder/decoder libraries")
    parser.add_argument("--self-check", action="store_true", help="only independent parser and installed-reference self checks")
    args = parser.parse_args()
    reference = Reference(args.reference_encoder, args.reference_decoder, args.reference_common)
    reference_identity = reference.identity()
    self_check(reference)
    if args.self_check:
        print(json.dumps({"self_check": "passed", "reference": reference_identity}))
        return
    require(args.probe is not None and args.directory is not None, "--probe and --directory are required")
    probe, directory = args.probe.resolve(), args.directory.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    sources = source_identity()
    (directory / "payload.input").write_bytes(PAYLOAD)
    metadata_files = {}
    seed_block = bytes((index * 29 + 7) & 255 for index in range(256))
    for length in BOUNDARIES + (MAX_METADATA + 1,):
        path = directory / f"metadata-{length}.input"
        body = (seed_block * ((length + 255) // 256))[:length]
        path.write_bytes(body)
        metadata_files[length] = {"path": path, "bytes": length, "sha256": digest(body)}
    commands, results, references, rejects, negatives, reference_defects = [], [], [], [], [], []
    def call(*arguments):
        command = [str(probe), *(str(value) for value in arguments)]
        result = subprocess.run(command, capture_output=True, check=False, timeout=120)
        commands.append({"command": command, "exit_code": result.returncode,
                         "stdout_sha256": digest(result.stdout), "stderr": result.stderr.decode(errors="replace")})
        require(result.returncode == 0, (command, result.returncode, result.stderr.decode(errors="replace")))
        try:
            return json.loads(result.stdout)
        except json.JSONDecodeError as error:
            raise AssertionError((command, "probe JSON", result.stdout[:1000])) from error
    def encode_call(action, codec, quality, api, large, length, path):
        return call(action, codec, api, quality, 25 if large else 16, "large" if large else "standard",
                    directory / "payload.input", metadata_files[length]["path"], path)
    for codec, quality, api, large, length in matrix():
        name = f"{codec}-q{quality}-{api}-{'large25' if large else 'standard16'}-meta{length}"
        path = directory / (name + ".br")
        row = encode_call("encode", codec, quality, api, large, length, path)
        require(row["error"] is None, (name, row))
        wire, metadata = path.read_bytes(), metadata_files[length]["path"].read_bytes()
        count = int(length != 0 or api in ("incremental_prefix", "incremental_mid"))
        require(row["max_metadata_meta_block_len"] == MAX_METADATA and row["input_bytes"] == len(PAYLOAD) and
                row["input_sha256"] == digest(PAYLOAD) and row["metadata_sha256"] == digest(metadata) and
                row["wire_bytes"] == len(wire) and row["wire_sha256"] == digest(wire) and
                row["wire_bytes"] <= row["encoded_bound"] and row["self_decode_verified"] and
                row["borrowed_input_guards_verified"], (name, "public probe identities/bound"))
        require(row["summary"]["metadata_meta_block_count"] == count and row["summary"]["metadata_bytes"] == length,
                (name, "public metadata summary"))
        if api.startswith("incremental_"):
            progress = row["progress"]
            require(progress["input_read"] == len(PAYLOAD) and progress["output_written"] == len(wire) and
                    progress["zero_input_offers"] > 0 and progress["zero_output_offers"] > 0 and
                    progress["caller_guards_verified"], (name, "progress/guards"))
            if api != "incremental_options":
                require(progress["metadata_acknowledged"], (name, "metadata acknowledgement"))
        if api == "reusable":
            require(row["progress"]["reusable_repeated"], (name, "reusable repetition"))
        parsed = inspect_stored(wire, PAYLOAD, metadata, count) if codec == "stored" else inspect_planned(wire, PAYLOAD, metadata, count, api, reference, large)
        require(parsed["window_bits"] == (25 if large else 16) and parsed["large_window"] == large, (name, "actual format identity"))
        external = reference.decode(wire, PAYLOAD, allow_large=large)
        require(external["complete_contents_verified"], (name, "system reference full contents", external))
        results.append({"name": name, "wire_file": path.name, "metadata_file": metadata_files[length]["path"].name,
                        "codec": codec, "quality": quality, "api": api, "large_window": large,
                        "probe": row, "independent_wire": parsed, "reference_decode": external})
    for length in BOUNDARIES:
        for large in (False, True):
            metadata = metadata_files[length]["path"].read_bytes()
            wire, origin, defect = reference_stream(reference, PAYLOAD, metadata, large)
            path = directory / f"reference-{'large25' if large else 'standard16'}-meta{length}.br"
            path.write_bytes(wire)
            decoded_path = directory / (path.stem + ".decoded")
            row = call("decode", "large" if large else "standard", path, decoded_path)
            require(row["error"] is None and decoded_path.read_bytes() == PAYLOAD and row["input_sha256"] == digest(wire),
                    (path.name, "target decodes native system metadata"))
            parsed = inspect_planned(wire, PAYLOAD, metadata, 1, "one_shot", reference, large)
            require(parsed["metadata_blocks"][0]["mskipbytes"] == (0 if length == 0 else 1 if length <= 256 else 2 if length <= 65536 else 3),
                    (path.name, "native reference metadata width"))
            references.append({"wire_file": path.name, "wire_bytes": len(wire), "wire_sha256": digest(wire),
                               "metadata_bytes": length, "metadata_sha256": digest(metadata), "large_window": large,
                               "origin": origin, "target_decode": row, "independent_wire": parsed})
            if defect is not None:
                invalid = directory / f"reference-defect-1.0.9-meta1-{'large' if large else 'standard'}.br"
                invalid.write_bytes(defect.pop("wire"))
                rejected = call("decode", "large" if large else "standard", invalid, directory / (invalid.stem + ".decoded"))
                require(rejected["error"] == defect["expected_target_error"], "target rejects native one-byte encoder defect")
                reference_defects.append({**defect, "wire_file": invalid.name, "wire_sha256": digest(invalid.read_bytes()),
                                          "metadata_bytes": 1, "large_window": large, "target_decode": rejected})
    for codec, quality in [("stored", 0)] + [("planned", quality) for quality in QUALITIES]:
        for api in APIS:
            for large in (False, True):
                path = directory / f"reject-{codec}-q{quality}-{api}-{int(large)}.br"
                row = encode_call("reject", codec, quality, api, large, MAX_METADATA + 1, path)
                require(row["error"] == "InvalidBlockPlan" and row["rejected_before_allocation"] and not path.exists(),
                        (path.name, "oversize rejected before allocation"))
                rejects.append(row)
    if reference.versions["encoder"] != 0x01000009:
        system = installed_reference()
        if system.versions["encoder"] == 0x01000009:
            _, _, defect = reference_stream(system, PAYLOAD, b"\x07", False)
            require(defect is not None, "installed 1.0.9 one-byte defect regression differs")
            invalid = directory / "reference-defect-system-1.0.9-meta1.br"
            invalid.write_bytes(defect.pop("wire"))
            rejected = call("decode", "standard", invalid, directory / (invalid.stem + ".decoded"))
            require(rejected["error"] == defect["expected_target_error"], "target rejects installed reference one-byte defect")
            reference_defects.append({**defect, "wire_file": invalid.name, "wire_sha256": digest(invalid.read_bytes()),
                                      "metadata_bytes": 1, "large_window": False, "target_decode": rejected,
                                      "reference": system.identity()})
    negative_wires = {
        "reserved": (pack(((0, 1), (0, 1), (3, 2), (1, 1), (0, 2))), "CorruptFrame"),
        "overlong-two-byte": (pack(((0, 1), (0, 1), (3, 2), (0, 1), (2, 2), (0, 16)), b"X"), "CorruptFrame"),
        "overlong-three-byte": (pack(((0, 1), (0, 1), (3, 2), (0, 1), (3, 2), (256, 24)), b"X" * 257), "CorruptFrame"),
        "truncated-length-field": (pack(((0, 1), (0, 1), (3, 2), (0, 1), (3, 2), (65536, 24)))[:3], "TruncatedFrame"),
        "truncated-body": (pack(((0, 1), (0, 1), (3, 2), (0, 1), (3, 2), (65536, 24)), b"short"), "TruncatedFrame"),
        "empty-wire": (b"", "TruncatedFrame"),
    }
    complete = reference.encode(PAYLOAD, metadata_files[65537]["path"].read_bytes())
    negative_wires["truncated-final"] = complete[:-1], "TruncatedFrame"
    negative_wires["trailing-byte"] = complete + b"\x00", "TrailingData"
    padded = bytearray(pack(((0, 1), (0, 1), (3, 2), (0, 1), (1, 2), (0, 8)), b"X"))
    padded[1] |= 128
    negative_wires["nonzero-padding"] = bytes(padded), "CorruptFrame"
    for name, (wire, error) in negative_wires.items():
        path, decoded_path = directory / ("invalid-" + name + ".br"), directory / ("invalid-" + name + ".decoded")
        path.write_bytes(wire)
        row = call("decode", "standard", path, decoded_path)
        require(row["error"] == error and not decoded_path.exists(), (name, "exact target rejection", row))
        external = reference.decode(wire, PAYLOAD)
        require(not external["complete_contents_verified"], (name, "reference rejected complete stream", external))
        negatives.append({"name": name, "wire_file": path.name, "wire_sha256": digest(wire), "expected_error": error,
                          "target_decode": row, "reference_decode": external})
    large_path = directory / "reference-large25-meta65537.br"
    row = call("decode", "standard", large_path, directory / "large-disallowed.decoded")
    external = reference.decode(large_path.read_bytes(), PAYLOAD, allow_large=False)
    require(row["error"] == "CorruptFrame" and not external["complete_contents_verified"], "Large Window requires opt-in")
    negatives.append({"name": "large-window-opt-in", "target_decode": row, "reference_decode": external})
    require(source_identity() == sources, "source changed during metadata gate")
    report = {"schema": "vort.br.metadata-differential.v1", "created_utc": datetime.now(timezone.utc).isoformat(),
              "python": platform.python_version(), "host": {"platform": platform.platform(), "machine": platform.machine()},
              "probe": {"path": str(probe), "sha256": digest(probe.read_bytes())}, "source": sources,
              "reference": reference_identity, "payload": {"file": "payload.input", "bytes": len(PAYLOAD), "sha256": digest(PAYLOAD)},
              "metadata": [{"file": row["path"].name, "bytes": row["bytes"], "sha256": row["sha256"]} for row in metadata_files.values()],
              "scope": "full format metadata 0..16777216; all public API/quality routes at 0 and 65537, exact field boundaries, two real maximum-length target routes, native reference widths, allocator-before-rejection, malformed streams",
              "measurement_scope": "actual serialized bytes/exact independently parsed metadata bits and full plaintext; no timing/performance claims",
              "counts": {"target_encodes": len(results), "reference_decoder_fixtures": len(references),
                         "native_reference_encodes": sum(row["origin"].startswith("native ") for row in references),
                         "known_reference_encoder_defects": len(reference_defects),
                         "preallocation_rejects": len(rejects), "malformed_rejects": len(negatives)},
              "results": results, "reference_streams": references, "preallocation_rejects": rejects,
              "malformed_streams": negatives, "known_reference_encoder_defects": reference_defects, "commands": commands}
    report_path = args.report or directory / "differential.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"report": str(report_path), **report["counts"]}))


if __name__ == "__main__":
    main()
