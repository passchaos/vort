#!/usr/bin/env python3
"""Independent upstream Brotli literal context control and full-map inspection.

Library(path=None) auto-builds the private reference from BROTLI_SOURCE, default
~/Work/brotli. path may name a previously built libbrlc_reference.so or its
directory. An ordinary libbrotlidec without observation hooks is insufficient.
"""
from __future__ import annotations

import base64
import ctypes as C
import hashlib
import importlib.util
import json
from pathlib import Path


HERE = Path(__file__).resolve().parent
SIZE = C.c_size_t
PTR = C.c_void_p
BYTE_PTR = C.POINTER(C.c_uint8)
CALLBACK = C.CFUNCTYPE(None, PTR, C.c_uint, C.POINTER(C.c_uint32), BYTE_PTR, BYTE_PTR, BYTE_PTR)


def _sha256(body):
    return hashlib.sha256(body).hexdigest()


def _require(condition, detail):
    if not condition:
        raise RuntimeError(detail)


def _default_library():
    spec = importlib.util.spec_from_file_location("brlc_observer_build", HERE / "observer/build.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.build()


class Library:
    def __init__(self, path=None):
        self.path = Path(path).resolve() if path else _default_library()
        if self.path.is_dir():
            self.path /= "libbrlc_reference.so"
        manifest_path = self.path.parent / "manifest.json"
        _require(manifest_path.is_file(), f"reference manifest missing next to {self.path}")
        self.manifest = json.loads(manifest_path.read_text())
        _require(self.manifest["library_sha256"] == _sha256(self.path.read_bytes()),
                 "reference library SHA differs from matching-source manifest")
        self.lib = C.CDLL(str(self.path))
        def bind(name, result, *args):
            fn = getattr(self.lib, name)
            fn.restype, fn.argtypes = result, args
            return fn
        self.ec = bind("brlc_encoder_create", PTR)
        self.ed = bind("brlc_encoder_destroy", None, PTR)
        self.ep = bind("brlc_encoder_parameter", C.c_int, PTR, C.c_uint, C.c_uint32)
        self.es = bind("brlc_encoder_stream", C.c_int, PTR, C.c_uint, C.POINTER(SIZE),
                       C.POINTER(PTR), C.POINTER(SIZE), C.POINTER(PTR), C.POINTER(SIZE))
        self.ef = bind("brlc_encoder_finished", C.c_int, PTR)
        self.dc = bind("brlc_decoder_create", PTR, CALLBACK, PTR)
        self.dd = bind("brlc_decoder_destroy", None, PTR)
        self.dp = bind("brlc_decoder_parameter", C.c_int, PTR, C.c_uint, C.c_uint32)
        self.ds = bind("brlc_decoder_stream", C.c_int, PTR, C.POINTER(SIZE),
                       C.POINTER(PTR), C.POINTER(SIZE), C.POINTER(PTR), C.POINTER(SIZE))
        self.de = bind("brlc_decoder_error", C.c_int, PTR)
        self.versions = {side: bind(f"brlc_{side}_version", C.c_uint32)() for side in ("encoder", "decoder")}
        _require(self.versions["encoder"] == self.versions["decoder"], "reference source/version mismatch")

    def identity(self):
        return {"library_path": str(self.path), "library_sha256": self.manifest["library_sha256"],
                "versions": self.versions, "manifest_path": str(self.path.parent / "manifest.json"),
                "source_git_commit": self.manifest.get("source_git_commit"),
                "source_root": self.manifest["source_root"],
                "source_sha256": self.manifest["source_sha256"],
                "observer_sha256": self.manifest["observer_sha256"],
                "patched_decoder_sha256": self.manifest["patched_decoder_sha256"],
                "encoder_parameter": {"id": 4, "name": "BROTLI_PARAM_DISABLE_LITERAL_CONTEXT_MODELING"},
                "map_observer": "upstream DecodeContextMap output after inverse MTF; all literal 64 entries per block type"}

    def produce(self, payload, quality, disable, large=False, window=None):
        _require(isinstance(disable, bool), "disable must be bool")
        _require(0 <= quality <= 11, "quality outside 0..11")
        if window is None:
            window = 25 if large else 22
        _require(10 <= window <= (30 if large else 24), "window outside reference range")
        state = self.ec()
        _require(state, "reference encoder allocation failed")
        body = C.create_string_buffer(bytes(payload), len(payload) + 1)
        remaining, next_in = SIZE(len(payload)), PTR(C.addressof(body))
        output = bytearray()
        try:
            for key, value in ((1, quality), (4, int(disable)), (6, int(large)), (2, window)):
                _require(self.ep(state, key, value), f"reference encoder rejected parameter {key}={value}")
            while True:
                target = C.create_string_buffer(65536)
                room, next_out, total = SIZE(len(target)), PTR(C.addressof(target)), SIZE()
                before = remaining.value
                _require(self.es(state, 2, C.byref(remaining), C.byref(next_in), C.byref(room),
                                 C.byref(next_out), C.byref(total)), "reference FINISH failed")
                written = len(target) - room.value
                output.extend(target.raw[:written])
                if self.ef(state):
                    _require(not remaining.value, "finished with unconsumed plaintext")
                    return bytes(output)
                _require(before != remaining.value or written, "reference encoder made no progress")
        finally:
            self.ed(state)

    def inspect(self, wire, allow_large=True, content_limit=16384, max_output=64 * 1024 * 1024):
        """Return JSON-compatible upstream observations and a complete decode SHA.

        Constant means all 64 entries in EACH literal block type are equal.
        It does not require equal trees between block types, zero context modes,
        constant distance maps, or disabling static/shared dictionary contexts.
        """
        blocks = []
        callback_errors = []
        def observe(_opaque, kind, info_ptr, literal, distance, modes):
            try:
                info = [int(info_ptr[i]) for i in range(11)]
                if kind == 0:
                    blocks.append({"index": len(blocks), "window_bits": info[0],
                                   "is_last": bool(info[1]), "is_uncompressed": bool(info[2]),
                                   "is_metadata": bool(info[3]), "length": info[4],
                                   "kind": "metadata" if info[3] else "uncompressed" if info[2]
                                           else "empty" if info[4] == 0 else "compressed"})
                elif kind == 1:
                    _require(blocks and blocks[-1]["kind"] == "compressed", "map event without compressed header")
                    literal_blocks, command_blocks, distance_blocks = info[5:8]
                    maps = []
                    for index in range(literal_blocks):
                        entries = [int(literal[index * 64 + context]) for context in range(64)]
                        maps.append({"block_type": index, "context_mode": int(modes[index]) & 3,
                                     "entries": entries, "constant": len(set(entries)) == 1,
                                     "distinct_trees": sorted(set(entries))})
                    blocks[-1].update({"literal_block_types": literal_blocks,
                                       "command_block_types": command_blocks, "distance_block_types": distance_blocks,
                                       "literal_trees": info[8], "distance_trees": info[9],
                                       "distance_postfix_bits": info[10], "literal_context_maps": maps,
                                       "literal_maps_constant": all(item["constant"] for item in maps),
                                       "distance_context_maps": [[int(distance[index * 4 + context]) for context in range(4)]
                                                                 for index in range(distance_blocks)]})
                else:
                    raise RuntimeError(f"unknown observer event {kind}")
            except Exception as error:
                callback_errors.append(str(error))
        callback = CALLBACK(observe)
        state = self.dc(callback, None)
        _require(state, "reference decoder allocation failed")
        source = C.create_string_buffer(bytes(wire), len(wire) + 1)
        remaining, next_in = SIZE(len(wire)), PTR(C.addressof(source))
        output = bytearray()
        status = 0
        try:
            _require(self.dp(state, 1, int(allow_large)), "reference rejected Large Window decoder parameter")
            while True:
                target = C.create_string_buffer(65536)
                room, next_out, total = SIZE(len(target)), PTR(C.addressof(target)), SIZE()
                before = remaining.value
                status = self.ds(state, C.byref(remaining), C.byref(next_in), C.byref(room), C.byref(next_out), C.byref(total))
                written = len(target) - room.value
                output.extend(target.raw[:written])
                _require(len(output) <= max_output, f"reference decode exceeds max_output={max_output}")
                _require(not callback_errors, f"reference observation failed: {callback_errors}")
                if status == 1:
                    break
                _require(status != 0, f"reference invalid Brotli: decoder error {self.de(state)}")
                _require(status != 2, "reference truncated Brotli input")
                _require(before != remaining.value or written, "reference decoder made no progress")
            _require(not remaining.value, "reference found trailing input")
            compressed = [block for block in blocks if block["kind"] == "compressed"]
            _require(all("literal_context_maps" in block for block in compressed), "incomplete context-map observation")
            result = {"reference_decoded": True, "decoder_status": status, "decoder_error": self.de(state),
                      "input_consumed": len(wire), "wire_sha256": _sha256(wire),
                      "decoded_size": len(output), "decoded_sha256": _sha256(output),
                      "metablocks": blocks, "compressed_metablocks": len(compressed),
                      "literal_maps_constant": all(block["literal_maps_constant"] for block in compressed),
                      "nonconstant_literal_maps": sum(not item["constant"] for block in compressed
                                                       for item in block["literal_context_maps"]),
                      "literal_map_entries_checked": sum(64 * block["literal_block_types"] for block in compressed)}
            if len(output) <= content_limit:
                result["decoded_base64"] = base64.b64encode(output).decode("ascii")
                try:
                    result["decoded_utf8"] = output.decode("utf8")
                except UnicodeDecodeError:
                    pass
            return result
        finally:
            self.dd(state)
