#!/usr/bin/env python3
"""Independent Zstd standard/magicless format and public API differential QA.

Uses an already-built probe and an existing libzstd. Never compiles or installs
anything; no throughput or timing measurements are collected.
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
import re
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
MAGIC = b"\x28\xb5\x2f\xfd"
FORMATS = ("standard", "magicless")
ENCODE_APIS = ("one_shot", "into", "append", "reuse", "incremental")
DECODE_APIS = ("one_shot", "into", "append", "size", "reuse", "incremental")


def require(value, context):
    if not value:
        raise AssertionError(context)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def identity(path):
    path = Path(path)
    body = path.read_bytes()
    return {"path": str(path), "bytes": len(body), "sha256": digest(body)}


def header_parameters(path):
    """Resolve experimental aliases from the selected local header, not ABI guesses."""
    text = path.read_text()
    names = ("ZSTD_c_format", "ZSTD_d_format", "ZSTD_c_compressionLevel", "ZSTD_c_windowLog",
             "ZSTD_c_contentSizeFlag", "ZSTD_c_checksumFlag", "ZSTD_c_dictIDFlag", "ZSTD_f_zstd1_magicless")
    def resolve(name):
        alias = re.search(r"^\s*#define\s+" + re.escape(name) + r"\s+(\w+)\s*$", text, re.MULTILINE)
        if alias:
            return resolve(alias.group(1))
        value = re.search(r"\b" + re.escape(name) + r"\s*=\s*(\d+)\b", text)
        require(value is not None, ("local zstd header parameter", name))
        return int(value.group(1))
    result = {name: resolve(name) for name in names}
    require(result["ZSTD_f_zstd1_magicless"] == 1, "reference header magicless value")
    return result


class Buffer(C.Structure):
    _fields_ = [("data", C.c_void_p), ("size", C.c_size_t), ("pos", C.c_size_t)]


class Reference:
    def __init__(self, path, header):
        self.path = path.resolve()
        self.header = header.resolve()
        self.parameters = header_parameters(self.header)
        self.lib = C.CDLL(str(self.path))
        def bind(name, result, *arguments):
            fn = getattr(self.lib, name)
            fn.restype, fn.argtypes = result, arguments
            return fn
        ptr, size, integer = C.c_void_p, C.c_size_t, C.c_int
        self.version = bind("ZSTD_versionString", C.c_char_p)().decode()
        self.version_number = bind("ZSTD_versionNumber", C.c_uint)()
        self.error = bind("ZSTD_isError", C.c_uint, size)
        self.error_name = bind("ZSTD_getErrorName", C.c_char_p, size)
        self.bound = bind("ZSTD_compressBound", size, size)
        self.create = bind("ZSTD_createCCtx", ptr)
        self.free = bind("ZSTD_freeCCtx", size, ptr)
        self.set = bind("ZSTD_CCtx_setParameter", size, ptr, integer, integer)
        self.load = bind("ZSTD_CCtx_loadDictionary", size, ptr, ptr, size)
        self.compress = bind("ZSTD_compress2", size, ptr, ptr, size, ptr, size)
        self.dcreate = bind("ZSTD_createDCtx", ptr)
        self.dfree = bind("ZSTD_freeDCtx", size, ptr)
        self.dset = bind("ZSTD_DCtx_setParameter", size, ptr, integer, integer)
        self.dload = bind("ZSTD_DCtx_loadDictionary", size, ptr, ptr, size)
        self.decode_stream = bind("ZSTD_decompressStream", size, ptr, C.POINTER(Buffer), C.POINTER(Buffer))
        self.train = bind("ZDICT_trainFromBuffer", size, ptr, size, ptr, C.POINTER(size), C.c_uint)

    def check(self, value):
        require(not self.error(value), self.error_name(value).decode())
        return value

    def describe(self):
        class DlInfo(C.Structure):
            _fields_ = [("name", C.c_char_p), ("base", C.c_void_p), ("symbol", C.c_char_p), ("address", C.c_void_p)]
        fn = C.CDLL(None).dladdr
        fn.restype, fn.argtypes = C.c_int, (C.c_void_p, C.POINTER(DlInfo))
        info = DlInfo()
        require(fn(C.cast(self.decode_stream, C.c_void_p), C.byref(info)) and info.name, "libzstd symbol provenance")
        actual = Path(info.name.decode()).resolve()
        require(actual == self.path, "libzstd symbol loaded from requested file")
        return {"library": identity(actual), "version": self.version, "version_number": self.version_number,
                "header": identity(self.header), "resolved_parameters": self.parameters,
                "parameter_scope": "experimental format aliases resolved from this exact local header"}

    def encode(self, payload, format_, dictionary=b"", checksum=True, content_size=True):
        context = self.create()
        require(context, "ZSTD_createCCtx")
        try:
            settings = (("ZSTD_c_compressionLevel", 3), ("ZSTD_c_windowLog", 17),
                        ("ZSTD_c_contentSizeFlag", int(content_size)), ("ZSTD_c_checksumFlag", int(checksum)),
                        ("ZSTD_c_dictIDFlag", 1), ("ZSTD_c_format", int(format_ == "magicless")))
            for name, value in settings:
                self.check(self.set(context, self.parameters[name], value))
            self.check(self.load(context, dictionary, len(dictionary)))
            capacity = self.bound(len(payload))
            output = C.create_string_buffer(b"\xa5" * (capacity + 16), capacity + 16)
            size = self.check(self.compress(context, C.byref(output, 8), capacity, payload, len(payload)))
            require(output.raw[:8] == b"\xa5" * 8 and output.raw[-8:] == b"\xa5" * 8, "reference encoder guards")
            return output.raw[8:8 + size]
        finally:
            self.free(context)

    def decode(self, wire, expected, format_, dictionary=b""):
        context = self.dcreate()
        require(context, "ZSTD_createDCtx")
        try:
            self.check(self.dset(context, self.parameters["ZSTD_d_format"], int(format_ == "magicless")))
            self.check(self.dload(context, dictionary, len(dictionary)))
            source = C.create_string_buffer(wire, len(wire) + 1)
            capacity = len(expected) + 1
            output = C.create_string_buffer(b"\xa5" * (capacity + 16), capacity + 16)
            input_buffer = Buffer(C.addressof(source), len(wire), 0)
            output_buffer = Buffer(C.addressof(output) + 8, capacity, 0)
            frames = 0
            status, error = "incomplete", None
            while True:
                before = input_buffer.pos, output_buffer.pos
                hint = self.decode_stream(context, C.byref(output_buffer), C.byref(input_buffer))
                if self.error(hint):
                    status, error = "error", self.error_name(hint).decode()
                    break
                if hint == 0:
                    frames += 1
                    if input_buffer.pos == len(wire):
                        status = "complete"
                        break
                if before == (input_buffer.pos, output_buffer.pos) or output_buffer.pos == capacity:
                    break
            require(output.raw[:8] == b"\xa5" * 8 and output.raw[-8:] == b"\xa5" * 8, "reference decoder guards")
            actual = output.raw[8:8 + output_buffer.pos]
            return {"status": status, "error": error, "input_read": input_buffer.pos, "output_written": output_buffer.pos,
                    "decoded_sha256": digest(actual), "frames_completed": frames, "caller_guards_verified": True,
                    "complete_contents_verified": status == "complete" and input_buffer.pos == len(wire) and actual == expected}
        finally:
            self.dfree(context)

    def dictionary(self):
        samples = [f'{{"id":{index},"service":"magicless","message":"dictionary format interoperability"}}\n'.encode() * 10
                   + deterministic(97, 0x6400 + index) for index in range(80)]
        combined = b"".join(samples)
        sizes = (C.c_size_t * len(samples))(*map(len, samples))
        output = C.create_string_buffer(4096)
        count = self.check(self.train(output, len(output), combined, sizes, len(samples)))
        return output.raw[:count]


def take(wire, offset, count):
    require(offset + count <= len(wire), ("truncated Zstd fields", offset, count))
    return int.from_bytes(wire[offset:offset + count], "little"), offset + count


def inspect(wire, format_):
    position, frames, skippable = 0, [], []
    while position < len(wire):
        start = position
        if format_ == "standard":
            magic, position = take(wire, position, 4)
            if 0x184D2A50 <= magic <= 0x184D2A5F:
                size, position = take(wire, position, 4)
                require(position + size <= len(wire), "truncated skippable frame")
                skippable.append({"start_byte": start, "id": magic & 15, "payload_bytes": size, "end_byte": position + size})
                position += size
                continue
            require(magic == int.from_bytes(MAGIC, "little"), "standard frame magic")
        descriptor, position = take(wire, position, 1)
        require(descriptor & 0x08 == 0, "reserved frame descriptor")
        single, checksum = bool(descriptor & 32), bool(descriptor & 4)
        window_size = None
        if not single:
            wd, position = take(wire, position, 1)
            base = 1 << (10 + (wd >> 3))
            window_size = base + (base >> 3) * (wd & 7)
        dictionary_bytes = (0, 1, 2, 4)[descriptor & 3]
        dictionary_id, position = take(wire, position, dictionary_bytes)
        fcs_bytes = (int(single), 2, 4, 8)[descriptor >> 6]
        fcs, position = take(wire, position, fcs_bytes)
        content_size = fcs + 256 if fcs_bytes == 2 else fcs if fcs_bytes else None
        if single:
            window_size = content_size
        header_end = position
        blocks = []
        while True:
            block_start = position
            header, position = take(wire, position, 3)
            final, kind, size = bool(header & 1), (header >> 1) & 3, header >> 3
            require(kind != 3 and size <= min(131072, window_size or 131072), "reserved/oversized Zstd block")
            encoded = 1 if kind == 1 else size
            require(position + encoded <= len(wire), "truncated Zstd block payload")
            blocks.append({"kind": ("raw", "rle", "compressed")[kind], "final": final, "start_byte": block_start,
                           "header_bytes": 3, "block_size_field": size, "encoded_payload_bytes": encoded,
                           "end_byte": position + encoded})
            position += encoded
            if final:
                break
        checksum_value, position = take(wire, position, 4 if checksum else 0)
        frames.append({"start_byte": start, "magic_bytes": 4 if format_ == "standard" else 0,
                       "descriptor_byte": start + (4 if format_ == "standard" else 0), "descriptor": descriptor,
                       "header_bytes": header_end - start, "dictionary_id": dictionary_id, "dictionary_id_bytes": dictionary_bytes,
                       "content_size": content_size, "content_size_bytes": fcs_bytes, "single_segment": single,
                       "window_size": window_size, "checksum": checksum, "checksum_value": checksum_value if checksum else None,
                       "blocks": blocks, "end_byte": position, "serialized_bytes": position - start})
    require(position == len(wire) and frames, "complete nonempty frame stream")
    return {"format": format_, "frames": frames, "frame_count": len(frames), "skippable_frames": skippable,
            "serialized_bytes": len(wire), "exact_frame_bytes": sum(row["serialized_bytes"] for row in frames),
            "parsing_scope": "frame header at physical offset zero/four, exact block extents and checksum trailer; entropy payload semantics independently decoded"}


def deterministic(length, seed=0x5A640026):
    output = bytearray()
    for _ in range(length):
        seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF
        output.append(seed >> 24)
    return bytes(output)


def payloads():
    return {"empty": b"", "tiny": b"Zstd magicless\x00\xff\n", "random": deterministic(4097),
            "repeat": b"magicless bounded repeated stream\n" * 128,
            "json": b"\n".join(f'{{"id":{i},"kind":"magicless","bucket":{i % 11}}}'.encode() for i in range(64)),
            "source": b"pub fn testMagicless(input: []const u8) !void { return verify(input); }\n" * 64,
            "multi": (b"Zstd magicless multi-block source history continuity.\n" * 3000)[:131333]}


def encode_configs():
    for name in ("empty", "tiny", "random", "repeat", "json", "source"):
        for api in ENCODE_APIS:
            for format_ in FORMATS:
                for selection in ("raw_or_rle", "literal_only", "auto"):
                    yield name, {"operation": "encode", "api": api, "format": format_, "selection": selection,
                                 "checksum": selection != "raw_or_rle", "content_size": selection != "literal_only"}
    for name in ("repeat", "json", "source"):
        for api in ENCODE_APIS:
            for format_ in FORMATS:
                for strategy in ("greedy", "btopt"):
                    yield name, {"operation": "encode", "api": api, "format": format_, "selection": "auto",
                                 "strategy": strategy, "hq": strategy == "btopt", "checksum": True, "content_size": True}
    for api in ("reuse", "incremental"):
        for format_ in FORMATS:
            yield "multi", {"operation": "encode", "api": api, "format": format_, "selection": "auto",
                            "checksum": True, "content_size": False, "block_size": 65536}
    for kind in ("raw", "full"):
        for api in ENCODE_APIS:
            for format_ in FORMATS:
                for strategy in ("auto", "greedy"):
                    yield "dict-" + kind, {"operation": "encode", "api": api, "format": format_, "selection": "auto",
                                           "strategy": strategy, "checksum": True, "content_size": False,
                                           "dictionary_kind": kind, "use_dictionary_set": kind == "full"}


def sources():
    paths = [ROOT / f"src/{name}.zig" for name in ("zstd", "core", "checksum", "dictionary", "huffman", "lz77", "bitstream", "zstd_huffman_x2_object")]
    for folder in ("zstd", "checksum", "dictionary"):
        paths += sorted((ROOT / "src" / folder).rglob("*.zig"))
    paths += [ROOT / "tools/zstd/magicless_probe.zig", Path(__file__).resolve()]
    records = [{"path": str(path.relative_to(ROOT)), "sha256": digest(path.read_bytes())} for path in paths]
    return {"files": records, "sha256": digest(json.dumps(records, sort_keys=True).encode())}


def self_check(reference):
    for name, payload in payloads().items():
        standard = reference.encode(payload, "standard")
        magicless = reference.encode(payload, "magicless")
        require(standard[:4] == MAGIC and standard[4:] == magicless, "native reference physical magicless output")
        for format_, wire in (("standard", standard), ("magicless", magicless)):
            parsed = inspect(wire, format_)
            require(parsed["frames"][0]["content_size"] == len(payload), "independent reference frame header")
            require(reference.decode(wire, payload, format_)["complete_contents_verified"], "reference full decode")
            require(not reference.decode(wire, payload, "magicless" if format_ == "standard" else "standard")["complete_contents_verified"],
                    "explicit format mismatch reference rejection")
        require(reference.decode(magicless + magicless, payload + payload, "magicless")["complete_contents_verified"], "magicless concat reference")
    dictionaries = {"raw": deterministic(8192, 0xD1640026), "full": reference.dictionary()}
    payload = b'{"id":7,"service":"magicless","message":"dictionary format interoperability"}\n' * 16
    for kind, dictionary in dictionaries.items():
        for format_ in FORMATS:
            wire = reference.encode(payload, format_, dictionary, content_size=False)
            require(reference.decode(wire, payload, format_, dictionary)["complete_contents_verified"], "native magicless dictionary self-check")
            parsed = inspect(wire, format_)
            require(parsed["frames"][0]["content_size"] is None and parsed["frames"][0]["dictionary_id"] ==
                    (int.from_bytes(dictionary[4:8], "little") if kind == "full" else 0), "dictionary physical header self-check")
    return {"reference_samples": len(payloads()), "target_encode_matrix": len(list(encode_configs()))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", type=Path)
    parser.add_argument("--directory", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--source-epoch", default="unspecified")
    parser.add_argument("--reference", type=Path, default=Path("/home/passchaos/Work/zstd/lib/libzstd.so.1.6.0"))
    parser.add_argument("--reference-header", type=Path, default=Path("/home/passchaos/Work/zstd/lib/zstd.h"))
    parser.add_argument("--self-check", action="store_true")
    args = parser.parse_args()
    reference = Reference(args.reference, args.reference_header)
    checks = self_check(reference)
    if args.self_check:
        print(json.dumps({"self_check": "passed", "checks": checks, "reference": reference.describe()}))
        return
    require(args.probe and args.directory, "--probe and --directory are required")
    probe, directory = args.probe.resolve(), args.directory.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    source_before = sources()
    inputs = payloads()
    dictionaries = {"raw": deterministic(8192, 0xD1640026), "full": reference.dictionary()}
    inputs["dict-raw"] = dictionaries["raw"][-1024:] + dictionaries["raw"][128:512]
    inputs["dict-full"] = b'{"id":7,"service":"magicless","message":"dictionary format interoperability"}\n' * 16
    for name, body in inputs.items():
        (directory / (name + ".input")).write_bytes(body)
    for kind, body in dictionaries.items():
        (directory / ("dictionary-" + kind + ".bin")).write_bytes(body)
    commands, results, failures, paired = [], [], [], {}
    def run(name, config, input_path, output_path):
        configuration = directory / (name + ".config.json")
        configuration.write_text(json.dumps(config, indent=2) + "\n")
        command = [str(probe), str(input_path), str(output_path), str(configuration)]
        process = subprocess.run(command, capture_output=True, check=False, timeout=120)
        stdout, stderr = directory / (name + ".stdout"), directory / (name + ".stderr")
        stdout.write_bytes(process.stdout)
        stderr.write_bytes(process.stderr)
        commands.append({"command": command, "exit_code": process.returncode, "stdout": identity(stdout), "stderr": identity(stderr)})
        require(process.returncode == 0, (name, "probe process", process.returncode, process.stderr.decode(errors="replace")))
        return json.loads(process.stdout)
    def encode_case(index, input_name, config):
        c = dict(config)
        kind = c.get("dictionary_kind")
        if kind:
            c["dictionary_path"] = str(directory / ("dictionary-" + kind + ".bin"))
        name = f"encode-{index:03d}-{input_name}-{c['api']}-{c['format']}"
        wire_path = directory / (name + ".zst")
        record = {"name": name, "scope": "target-encode", "settings": c, "input_name": input_name}
        try:
            row = run(name, c, directory / (input_name + ".input"), wire_path)
            record["probe"] = row
            require(row["error"] is None and row["self_decode_verified"] and row["caller_guards_verified"], (name, row))
            wire, payload = wire_path.read_bytes(), inputs[input_name]
            require(row["input_sha256"] == digest(payload) and row["output_sha256"] == digest(wire) and row["output_bytes"] == len(wire), "target encode identities")
            parsed = inspect(wire, c["format"])
            require(all(frame["checksum"] == c["checksum"] and (frame["content_size"] is not None) == c["content_size"] for frame in parsed["frames"]), "actual checksum/content size flags")
            require(parsed["frame_count"] == 1 and parsed["frames"][0]["dictionary_id"] ==
                    (int.from_bytes(dictionaries["full"][4:8], "little") if kind == "full" else 0), "target frame dictionary identity")
            if c["api"] == "incremental":
                require(row["progress"]["input_read"] == len(payload) and row["progress"]["output_written"] == len(wire) and
                        row["progress"]["zero_input_offers"] > 0 and row["progress"]["zero_output_offers"] > 0,
                        "incremental encode progress")
            decoded = reference.decode(wire, payload, c["format"], dictionaries[kind] if kind else b"")
            require(decoded["complete_contents_verified"], (name, "target to native full contents", decoded))
            key = json.dumps({key: value for key, value in c.items() if key != "format"}, sort_keys=True) + input_name
            pair = paired.setdefault(key, {})
            pair[c["format"]] = wire
            if len(pair) == 2:
                require(pair["standard"][:4] == MAGIC and pair["standard"][4:] == pair["magicless"], "only four physical magic bytes differ")
            record.update({"wire": identity(wire_path), "independent_wire": parsed, "reference_decode": decoded, "status": "passed"})
        except (AssertionError, OSError, json.JSONDecodeError) as error:
            record.update({"status": "failed", "failure": str(error)})
            failures.append({"name": name, "failure": str(error)})
        results.append(record)
    for index, (name, c) in enumerate(encode_configs()):
        encode_case(index, name, c)
    # Omitted format must preserve the same complete standard wire as an
    # explicit standard option, for every public encoding output route.
    for api in ENCODE_APIS:
        name = "default-format-" + api
        c = {"operation": "encode", "api": api, "selection": "auto", "checksum": True, "content_size": True}
        path = directory / (name + ".zst")
        record = {"name": name, "scope": "standard-default-parity", "settings": c}
        try:
            row = run(name, c, directory / "tiny.input", path)
            record["probe"] = row
            require(row["error"] is None, "omitted format encode")
            explicit = next(entry for entry in results if entry["scope"] == "target-encode" and
                            entry["input_name"] == "tiny" and entry["settings"]["api"] == api and
                            entry["settings"]["format"] == "standard" and entry["settings"]["selection"] == "auto")
            require(explicit["status"] == "passed" and path.read_bytes() == Path(explicit["wire"]["path"]).read_bytes(), "default standard complete wire changed")
            record.update({"status": "passed", "wire": identity(path), "explicit_standard_wire": explicit["wire"]})
        except (AssertionError, OSError, json.JSONDecodeError) as error:
            record.update({"status": "failed", "failure": str(error)})
            failures.append({"name": name, "failure": str(error)})
        results.append(record)
    reference_wires = []
    for input_name in ("empty", "tiny", "random", "repeat", "json", "source", "multi", "dict-raw", "dict-full"):
        kind = input_name[5:] if input_name.startswith("dict-") else None
        for format_ in FORMATS:
            for flags in ((True, True), (False, False)):
                payload = inputs[input_name]
                wire = reference.encode(payload, format_, dictionaries[kind] if kind else b"", *flags)
                wire_path = directory / f"reference-{input_name}-{format_}-{int(flags[0])}.zst"
                wire_path.write_bytes(wire)
                reference_wires.append((input_name, kind, format_, wire_path, payload, "native-reference"))
    for input_name in ("tiny", "repeat", "dict-full"):
        kind = "full" if input_name == "dict-full" else None
        for format_ in FORMATS:
            payload = inputs[input_name]
            wire = reference.encode(payload, format_, dictionaries[kind] if kind else b"")
            path = directory / f"concat-{input_name}-{format_}.zst"
            path.write_bytes(wire + wire)
            reference_wires.append((input_name, kind, format_, path, payload + payload, "concat-reference"))
    for format_ in FORMATS:
        payload = inputs["repeat"]
        wire = bytearray(reference.encode(payload, format_))
        wire[4 if format_ == "standard" else 0] |= 16  # Unused descriptor bit is accepted by the format.
        path = directory / ("unused-descriptor-" + format_ + ".zst")
        path.write_bytes(wire)
        require(reference.decode(bytes(wire), payload, format_)["complete_contents_verified"], "reference unused descriptor bit")
        reference_wires.append(("repeat", None, format_, path, payload, "unused-descriptor-positive"))
    skip = bytes.fromhex("502a4d18") + (5).to_bytes(4, "little") + b"skip!"
    ordinary = reference.encode(inputs["repeat"], "standard")
    path = directory / "standard-mixed-skippable.zst"
    path.write_bytes(ordinary + skip + ordinary)
    require(reference.decode(path.read_bytes(), inputs["repeat"] * 2, "standard")["complete_contents_verified"], "ordinary mixed skippable reference")
    reference_wires.append(("repeat", None, "standard", path, inputs["repeat"] * 2, "ordinary-skippable-positive"))
    for index, (input_name, kind, format_, wire_path, payload, scope) in enumerate(reference_wires):
        plaintext = directory / f"reference-plain-{index}.input"
        plaintext.write_bytes(payload)
        parsed = inspect(wire_path.read_bytes(), format_)
        for api in DECODE_APIS:
            name = f"decode-{index:03d}-{api}"
            c = {"operation": "decode", "api": api, "format": format_, "expected_output_len": len(payload),
                 "max_output_len": len(payload), "dictionary_path": str(directory / ("dictionary-" + kind + ".bin")) if kind else None,
                 "dictionary_kind": kind or "none", "use_dictionary_set": kind == "full",
                 "resume_dictionary": kind == "full" and api == "incremental"}
            record = {"name": name, "scope": scope, "settings": c, "reference_wire": identity(wire_path), "independent_wire": parsed}
            output_path = directory / (name + ".decoded")
            try:
                row = run(name, c, wire_path, output_path)
                record["probe"] = row
                require(row["error"] is None and row["output_bytes"] == len(payload) and row["output_sha256"] == digest(payload) and row["caller_guards_verified"], (name, "native to target decode", row))
                require(row["input_sha256"] == digest(wire_path.read_bytes()) and row["input_bytes"] == wire_path.stat().st_size,
                        "target received exact physical reference frame")
                if api != "size":
                    require(output_path.read_bytes() == payload, "target complete decoded bytes")
                else:
                    require(row["measured_size"] == len(payload), "public decoded-size route")
                if api == "incremental":
                    require(row["progress"]["input_read"] == wire_path.stat().st_size and row["progress"]["output_written"] == len(payload) and
                            row["progress"]["zero_input_offers"] > 0 and row["progress"]["zero_output_offers"] > 0,
                            "incremental exact progress")
                    require(row["decoder_snapshot"]["data_frame_count"] == parsed["frame_count"], "incremental concatenated frame count")
                    if c["resume_dictionary"]:
                        require(row["dictionary_resumes"] > 0, "full dictionary resumable request")
                if api == "reuse":
                    require(row["reusable_repeated"], "reusable decoder respects format options")
                record["status"] = "passed"
            except (AssertionError, OSError, json.JSONDecodeError) as error:
                record.update({"status": "failed", "failure": str(error)})
                failures.append({"name": name, "failure": str(error)})
            results.append(record)
            if api == "incremental" and scope == "concat-reference":
                # One retained-frame path per concatenated fixture also proves
                # format selection survives the decoder's prevalidation path.
                label = name + "-prevalidated"
                options = {**c, "input_policy": "prevalidated_frame"}
                output = directory / (label + ".decoded")
                entry = {"name": label, "scope": "prevalidated-concat", "settings": options, "reference_wire": identity(wire_path)}
                try:
                    row = run(label, options, wire_path, output)
                    entry["probe"] = row
                    require(row["error"] is None and output.read_bytes() == payload and row["decoder_snapshot"]["data_frame_count"] == parsed["frame_count"], "prevalidated magicless concat")
                    entry["status"] = "passed"
                except (AssertionError, OSError, json.JSONDecodeError) as error:
                    entry.update({"status": "failed", "failure": str(error)})
                    failures.append({"name": label, "failure": str(error)})
                results.append(entry)
    # All negative expectations remain exact. Wrong-format input is never
    # prefixed with magic or probed heuristically by the target tool.
    standard = reference.encode(inputs["repeat"], "standard")
    magicless = reference.encode(inputs["repeat"], "magicless")
    negatives = [("standard-in-magicless", standard, "magicless", "CorruptFrame"),
                 ("magicless-in-standard", magicless, "standard", "InvalidMagic"),
                 ("truncated-header", magicless[:1], "magicless", "TruncatedFrame"),
                 ("truncated-block", magicless[:-6], "magicless", "TruncatedFrame"),
                 ("truncated-checksum", magicless[:-1], "magicless", "TruncatedFrame"),
                 ("trailing-byte", magicless + b"\x00", "magicless", "TruncatedFrame"),
                 ("mixed-skippable", magicless + bytes.fromhex("502a4d18") + (0).to_bytes(4, "little") + magicless, "magicless", "TruncatedFrame")]
    corrupt = bytearray(magicless)
    corrupt[-1] ^= 1
    negatives.append(("checksum-corrupt", bytes(corrupt), "magicless", "ChecksumMismatch"))
    reserved = bytearray(magicless)
    reserved[0] |= 8
    negatives.append(("reserved-descriptor", bytes(reserved), "magicless", "CorruptFrame"))
    for name, wire, format_, expected_error in negatives:
        path = directory / ("negative-" + name + ".zst")
        path.write_bytes(wire)
        for api in ("one_shot", "into", "append", "incremental"):
            label = "negative-" + name + "-" + api
            c = {"operation": "decode", "api": api, "format": format_, "max_output_len": 1024 * 1024}
            record = {"name": label, "scope": "malformed-format", "expected_error": expected_error, "wire": identity(path)}
            try:
                row = run(label, c, path, directory / (label + ".decoded"))
                record["probe"] = row
                require(row["error"] == expected_error, (label, "exact rejection", row))
                record["status"] = "passed"
            except (AssertionError, OSError, json.JSONDecodeError) as error:
                record.update({"status": "failed", "failure": str(error)})
                failures.append({"name": label, "failure": str(error)})
            results.append(record)
    magicless_path = directory / "quota-magicless.zst"
    magicless_path.write_bytes(magicless)
    controls = [("output-quota", {"max_output_len": len(inputs["repeat"]) - 1}, "OutputLimitExceeded"),
                ("expected-too-small", {"max_output_len": len(inputs["repeat"]) + 1, "expected_output_len": len(inputs["repeat"]) - 1}, "SizeMismatch"),
                ("expected-too-large", {"max_output_len": len(inputs["repeat"]) + 1, "expected_output_len": len(inputs["repeat"]) + 1}, "SizeMismatch")]
    full_path = directory / "missing-full-dictionary.zst"
    full_path.write_bytes(reference.encode(inputs["dict-full"], "magicless", dictionaries["full"]))
    for name, options, error in controls + [("missing-dictionary", {}, "NeedDictionary")]:
        path = full_path if name == "missing-dictionary" else magicless_path
        for api in ("one_shot", "incremental"):
            label = name + "-" + api
            c = {"operation": "decode", "api": api, "format": "magicless", **options}
            entry = {"name": label, "scope": "quota-and-dictionary-error", "expected_error": error, "settings": c, "wire": identity(path)}
            try:
                row = run(label, c, path, directory / (label + ".decoded"))
                entry["probe"] = row
                require(row["error"] == error, (label, "exact control rejection", row))
                entry["status"] = "passed"
            except (AssertionError, OSError, json.JSONDecodeError) as failure:
                entry.update({"status": "failed", "failure": str(failure)})
                failures.append({"name": label, "failure": str(failure)})
            results.append(entry)
    after = sources()
    counts = {"cases": len(results), "passed": sum(row["status"] == "passed" for row in results), "failed": len(failures),
              "encode_pairs": sum(len(row) == 2 for row in paired.values()), "target_encodes": len(list(encode_configs())),
              "native_reference_streams": len(reference_wires), "native_reference_decode_routes": len(reference_wires) * len(DECODE_APIS),
              "malformed_checks": len(negatives) * 4, "default_standard_checks": len(ENCODE_APIS),
              "prevalidated_concat_checks": 6, "quota_and_dictionary_checks": 8}
    report = {"schema": "vort.zstd.magicless-differential.v1", "created_utc": datetime.now(timezone.utc).isoformat(),
              "source_epoch": args.source_epoch, "source": source_before, "source_after_sha256": after["sha256"],
              "sources_preserved": after == source_before, "probe": identity(probe), "reference": reference.describe(),
              "python": platform.python_version(), "host": platform.platform(), "inputs": {name: identity(directory / (name + ".input")) for name in inputs},
              "dictionaries": {name: identity(directory / ("dictionary-" + name + ".bin")) for name in dictionaries},
              "matrix": {"encode_apis": ENCODE_APIS, "decode_apis": DECODE_APIS, "formats": FORMATS,
                         "selections": ("raw_or_rle", "literal_only", "auto"), "controlled_strategies": ("greedy", "btopt")},
              "evidence_scope": "actual native format operations in both directions, exact physical headers/block/checksum extents, standard-vs-magicless only four magic bytes differ, full plaintext, concatenation, dictionaries and resume/progress",
              "measurement_scope": "functional serialized bytes and progress only; no timing or performance claims", "counts": counts,
              "results": results, "failures": failures, "commands": commands}
    report_path = args.report or directory / "differential.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"report": str(report_path), **counts, "sources_preserved": report["sources_preserved"]}))
    require(not failures and report["sources_preserved"], ("magicless external gate", failures, report["sources_preserved"]))


if __name__ == "__main__":
    main()
