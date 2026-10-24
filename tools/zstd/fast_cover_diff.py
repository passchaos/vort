#!/usr/bin/env python3
"""Independent FastCover dictionaries, held-out costs and interoperability."""
import argparse
import ctypes as C
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import random
import re
import statistics
import struct
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("dictionary_reference", ROOT / "tools/native/dictionary_resume_diff.py")
reference_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reference_module)
KINDS = ("text", "json", "source", "log", "binary", "small", "repetitive")


def require(condition, context):
    if not condition:
        raise AssertionError(context)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def run(*args):
    result = subprocess.run([str(arg) for arg in args], cwd=ROOT, capture_output=True)
    if result.returncode:
        raise RuntimeError(f"command failed: {' '.join(map(str, args))}\n{result.stderr.decode(errors='replace')}")
    return result


class Parameters(C.Structure):
    _fields_ = [(name, C.c_uint32) for name in ("k", "d", "f", "steps", "threads")]
    _fields_ += [("split", C.c_double)]
    _fields_ += [(name, C.c_uint32) for name in ("acceleration", "shrink", "regression")]
    _fields_ += [("level", C.c_int32), ("dictionary_id", C.c_uint32)]


class Result(C.Structure):
    _fields_ = [("elapsed_ns", C.c_uint64), ("selected", Parameters)]


def parameter_dict(parameters):
    return {name: getattr(parameters, name) for name, _ in Parameters._fields_}


class Reference(reference_module.Zstd):
    def __init__(self, helper):
        super().__init__()
        self.helper_path = helper.resolve()
        self.helper = C.CDLL(str(self.helper_path))
        bind = reference_module.bind
        self.header_version = bind(self.helper, "vfc_header_version", C.c_uint)()
        self.helper_runtime = bind(self.helper, "vfc_runtime_version", C.c_char_p)().decode()
        require(self.helper_runtime == self.version, "helper and Python load identical libzstd version")
        require(self.header_version == sum(int(part) * scale for part, scale in zip(self.version.split("."), (10000, 100, 1))),
                "compile header version equals runtime version")
        require(bind(self.helper, "vfc_parameters_size", C.c_size_t)() == C.sizeof(Parameters), "reference parameter ABI size")
        require(bind(self.helper, "vfc_result_size", C.c_size_t)() == C.sizeof(Result), "reference result ABI size")
        require(bind(self.helper, "vfc_split_offset", C.c_size_t)() == Parameters.split.offset, "reference split ABI offset")
        self.train_fast = bind(self.helper, "vfc_train", C.c_size_t, C.c_void_p, C.c_size_t, C.c_void_p,
                               C.POINTER(C.c_size_t), C.c_uint, C.POINTER(Parameters), C.c_uint, C.POINTER(Result))
        self.finalize_fast = bind(self.helper, "vfc_finalize", C.c_size_t, C.c_void_p, C.c_size_t, C.c_void_p,
                                  C.c_size_t, C.c_void_p, C.POINTER(C.c_size_t), C.c_uint, C.POINTER(Parameters), C.POINTER(Result))
        self.dictionary_id = bind(self.lib, "ZSTD_getDictID_fromDict", C.c_uint, C.c_void_p, C.c_size_t)
        self.frame_dictionary_id = bind(self.lib, "ZSTD_getDictID_fromFrame", C.c_uint, C.c_void_p, C.c_size_t)

    def train_parameters(self, samples, settings, capacity, content=None):
        combined = b"".join(samples)
        guarded_input = C.create_string_buffer(b"\xa5" * 8 + combined + b"\xa5" * 8)
        guarded_output = C.create_string_buffer(b"\xa5" * (capacity + 16))
        sizes = (C.c_size_t * len(samples))(*map(len, samples))
        parameters = Parameters(**{name: settings[name] for name, _ in Parameters._fields_})
        result = Result()
        if content is None:
            count = self.train_fast(C.byref(guarded_output, 8), capacity, C.byref(guarded_input, 8), sizes,
                                    len(samples), C.byref(parameters), int(settings["optimize"]), C.byref(result))
        else:
            count = self.finalize_fast(C.byref(guarded_output, 8), capacity, content, len(content),
                                       C.byref(guarded_input, 8), sizes, len(samples), C.byref(parameters), C.byref(result))
        require(guarded_input.raw[:len(combined) + 16] == b"\xa5" * 8 + combined + b"\xa5" * 8, "reference preserves training samples")
        require(guarded_output.raw[:8] == b"\xa5" * 8 and guarded_output.raw[capacity + 8:capacity + 16] == b"\xa5" * 8,
                "reference output guards")
        if self.error(count):
            return None, {"error": self.error_name(count).decode(), "selected": parameter_dict(result.selected)}
        require(0 < count <= capacity, "reference dictionary size bounds")
        dictionary = guarded_output.raw[8:8 + count]
        metadata = self.inspect(dictionary)
        require(metadata["id"] == settings["dictionary_id"], "reference requested dictionary ID")
        return dictionary, {"error": None, "selected": parameter_dict(result.selected), "instrumented_elapsed_ns": result.elapsed_ns,
                            "guards_unchanged": True, **metadata}

    def inspect(self, dictionary):
        require(dictionary[:4] == b"\x37\xa4\x30\xec", "standard dictionary magic")
        header = self.check(self.dict_header(dictionary, len(dictionary)))
        require(20 <= header < len(dictionary), "standard dictionary history present")
        repcodes = struct.unpack("<III", dictionary[header - 12:header])
        require(all(0 < offset <= len(dictionary) - header for offset in repcodes), "reference legal repeat offsets")
        return {"bytes": len(dictionary), "header_bytes": header, "content_bytes": len(dictionary) - header,
                "id": self.dictionary_id(dictionary, len(dictionary)), "repcodes": repcodes}

    def encode_level(self, payload, dictionary, level, checksum=True):
        context = self.create()
        require(context, "reference compression context")
        try:
            for parameter, value in ((100, level), (101, 17), (200, 1), (201, int(checksum)), (202, 1)):
                self.check(self.parameter(context, parameter, value))
            self.check(self.load(context, dictionary, len(dictionary)))
            output = C.create_string_buffer(self.bound(len(payload)))
            count = self.check(self.compress(context, output, len(output), payload, len(payload)))
            frame = output.raw[:count]
            self.verify(frame, payload, dictionary)
            return frame
        finally:
            self.free(context)

    def missing_dictionary_error(self, frame, output_size):
        context = self.dcreate()
        require(context, "reference decoder context")
        try:
            output = C.create_string_buffer(max(1, output_size))
            result = self.decode(context, output, len(output), frame, len(frame), b"", 0)
            require(self.error(result), "frame must need trained history without a dictionary")
            return self.error_name(result).decode()
        finally:
            self.dfree(context)


def sample_bytes(kind, index):
    seed = 0xFA57C0 + KINDS.index(kind) * 0x10000 + index * 977
    rng = random.Random(seed)
    if kind == "text":
        sentences = ("Dictionary history keeps repeated language close to later records.",
                     "A bounded streaming codec checks every offset before copying bytes.",
                     "Training and held out samples describe separate messages and identifiers.",
                     "Portable implementations measure memory and compressed frame sizes.")
        return ("\n".join(sentences[(index + j + rng.randrange(3)) % len(sentences)] for j in range(16)) + f"\nrecord={index}\n").encode()
    if kind == "json":
        return ("\n".join(json.dumps({"event": "dictionary", "service": f"svc-{index % 7}", "region": f"r-{index % 3}",
                                    "status": ("ok", "retry", "timeout")[j % 3], "request": index * 37 + j,
                                    "attributes": {"version": 2, "streaming": True}}, separators=(",", ":")) for j in range(8)) + "\n").encode()
    if kind == "source":
        return ("const std = @import(\"std\");\n" + "\n".join(
            f"pub fn record_{index}_{j}(buffer: []u8, value: u32) !usize {{\n"
            f"    if (buffer.len < {32 + j}) return error.BufferTooSmall;\n"
            "    std.mem.writeInt(u32, buffer[0..4], value, .little);\n"
            "    return buffer.len;\n}\n" for j in range(6))).encode()
    if kind == "log":
        return ("\n".join(f"2026-10-24T06:{index % 60:02d}:{j:02d}Z service=stream-{index % 5} request={index * 11 + j} "
                          f"level={('INFO', 'WARN', 'DEBUG')[j % 3]} event=frame_completed bytes={512 + j * 17} checksum=verified"
                          for j in range(10)) + "\n").encode()
    if kind == "binary":
        return b"".join(b"VORTREC\0" + struct.pack("<HHII", index, j, 0xDEADBEEF, index * 17 + j) +
                        bytes(rng.choices((0, 0, 1, 2, 7, 255), k=48)) + rng.randbytes(24) for j in range(12))
    if kind == "small":
        return f"event=frame id={index:04d} service={index % 7} result=ok bytes={index * 13:05d}\n".encode()
    return (b"bounded dictionary history and streaming frame pattern; " * 20 +
            f"record={index:04d} bucket={index % 5}\n".encode())


def make_corpus(directory):
    families = []
    for kind in KINDS:
        family = {"kind": kind}
        for partition, indices in (("training", range(64)), ("selector", range(64, 72)), ("heldout", range(72, 80))):
            rows = []
            for index in indices:
                data = sample_bytes(kind, index)
                name = f"{kind}-{partition}-{index:03d}.bin"
                (directory / name).write_bytes(data)
                rows.append({"path": name, "bytes": len(data), "sha256": digest(data)})
            family[partition] = rows
        families.append(family)
    manifest = {"schema": "vort-fast-cover-corpus-v1", "method": "fixed public synthetic generators; separate sample indices for training, selector and heldout",
                "generator_sha256": digest(Path(__file__).read_bytes()), "families": families}
    (directory / "corpus.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def samples(directory, family, partition):
    result = []
    for row in family[partition]:
        data = (directory / row["path"]).read_bytes()
        require(len(data) == row["bytes"] and digest(data) == row["sha256"], "frozen corpus sample hash")
        result.append(data)
    return result


def reference_matrix(dictionary_id):
    base = dict(k=64, d=6, f=12, steps=2, threads=1, split=1.0, acceleration=1, shrink=0,
                regression=3, level=3, dictionary_id=dictionary_id, optimize=False)
    variants = (("base", {}), ("d8", {"d": 8}), ("f16", {"f": 16}), ("acceleration10", {"acceleration": 10}),
                ("split75", {"split": 0.75}), ("shrink", {"shrink": 1}),
                ("optimizer-serial", {"k": 0, "d": 0, "optimize": True}),
                ("optimizer-parallel", {"k": 0, "d": 0, "threads": 2, "optimize": True}))
    return [(name, {**base, **changes, "dictionary_id": dictionary_id + index}) for index, (name, changes) in enumerate(variants)]


def prepare_reference(directory, corpus, reference):
    rows = []
    for index, family in enumerate(corpus["families"]):
        training = samples(directory, family, "training") + samples(directory, family, "selector")
        for name, settings in reference_matrix(0xFA570001 + index * 256):
            dictionary, metadata = reference.train_parameters(training, settings, 1024)
            row = {"kind": family["kind"], "case": name, "settings": settings, "dictionary_capacity": 1024,
                   "training_bytes": sum(map(len, training)), "training_sha256": digest(b"".join(training)), **metadata}
            if dictionary is not None:
                path = f"reference-{family['kind']}-{name}.zdict"
                (directory / path).write_bytes(dictionary)
                row.update(path=path, sha256=digest(dictionary))
                repeated, _ = reference.train_parameters(training, settings, 1024)
                row["deterministic"] = dictionary == repeated
                if not settings["optimize"]:
                    require(row["deterministic"], (family["kind"], name, "fixed reference trainer deterministic"))
                for payload in samples(directory, family, "heldout"):
                    frame = reference.encode(payload, dictionary)
                    reference.verify(frame, payload, dictionary)
            rows.append(row)
    manifest = {"schema": "vort-fast-cover-reference-v1", "created_utc": datetime.now(timezone.utc).isoformat(),
                "purpose": "functional preparation; instrumented times are not performance measurements",
                "version": reference.version, "header_version": reference.header_version,
                "helper_sha256": digest(reference.helper_path.read_bytes()),
                "helper_source_sha256": digest((ROOT / "tools/zstd/fast_cover_reference.c").read_bytes()), "rows": rows}
    (directory / "reference.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def source_hashes():
    paths = [ROOT / f"src/{name}.zig" for name in ("root", "zstd", "dictionary", "checksum", "core", "huffman", "lz77", "bitstream", "zstd_huffman_x2_object")]
    for name in ("zstd", "dictionary", "checksum"):
        paths += sorted((ROOT / f"src/{name}").rglob("*.zig"))
    paths += [ROOT / "src/io/working_allocator.zig", ROOT / "src/br/fast_bit_reader.zig",
              ROOT / "tools/native/dictionary_resume_diff.py", ROOT / "tools/zstd/fast_cover_probe.zig",
              ROOT / "tools/zstd/fast_cover_reference.c", Path(__file__).resolve()]
    return {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in paths}


def invoke_probe(args, name, config):
    configuration = args.work_dir / f"{name}-config.json"
    prefix = args.work_dir / name
    configuration.write_text(json.dumps(config) + "\n")
    return json.loads(run(args.probe, configuration, prefix).stdout)


def validate_probe(args, name, config, reference):
    stats = invoke_probe(args, name, config)
    require(stats["live_training_bytes_after_free"] == 0, (name, "caller frees every training allocation"))
    if config.get("expect_failure"):
        require(stats["error"] is not None and stats["dictionary_bytes"] == 0 and not stats["frames"], (name, "failed trainer publishes no dictionary or frames"))
        return stats
    require(stats["error"] is None and stats["deterministic"] and stats["profile_dictionary_verified"], (name, "deterministic profile-preserving dictionary"))
    dictionary = Path(stats["dictionary_path"]).read_bytes()
    require(len(dictionary) == stats["dictionary_bytes"], (name, "owned dictionary length"))
    require(stats["content_bytes"] <= config.get("target_size", 512), (name, "raw-history target bound"))
    require(stats["peak_requested_training_bytes"] <= config.get("max_working_memory", 128 * 1024 * 1024), (name, "requested live training memory bound"))
    for field in ("standard_profile", "optimization_profile", "standard_search_profile"):
        profile = stats.get(field)
        if profile:
            require(profile["peak_working_memory"] <= config.get("max_working_memory", 128 * 1024 * 1024),
                    (name, field, "complete heap and requested worker-stack budget"))
    if stats["full_dictionary"]:
        metadata = reference.inspect(dictionary)
        require(metadata["id"] == config["dictionary_id"] and metadata["content_bytes"] == stats["content_bytes"], (name, "independent standard header metadata"))
        content = dictionary[metadata["header_bytes"]:]
    else:
        content = dictionary
        require(stats["dictionary_id"] == 0, (name, "raw dictionary has natural zero ID"))
    charged = {}
    selector_encoded = 0
    for frame in stats["frames"]:
        payload = Path(frame["input_path"]).read_bytes()
        wire = Path(frame["path"]).read_bytes()
        require(len(wire) == frame["encoded_bytes"], (name, "encoded frame length"))
        require(reference.frame_dictionary_id(wire, len(wire)) == stats["dictionary_id"], (name, "independent frame dictionary ID"))
        reference.verify(wire, payload, dictionary)
        if frame["partition"] == "selector":
            selector_encoded += len(wire)
        else:
            charged[frame["level"]] = charged.get(frame["level"], len(dictionary)) + len(wire)
    if len(content) >= 4:
        proof = Path(args.work_dir / f"{name}-content-reference.zst").read_bytes()
        proof_input = content[-512:] * 2 + bytes(((content[-1] + 1) % 256,))
        reference.verify(proof, proof_input, dictionary)
        require(stats["content_reference_verified"], (name, "actual emitted trained-content reference"))
        stats["content_reference_without_dictionary_error"] = reference.missing_dictionary_error(proof, len(proof_input))
    heldout_total = len(dictionary) + sum(frame["encoded_bytes"] for frame in stats["frames"] if frame["partition"] == "heldout")
    stats.update(dictionary_sha256=digest(dictionary), charged_heldout_bytes=charged, charged_heldout_total=heldout_total,
                 selector_charged_bytes=len(dictionary) + selector_encoded)
    if config["mode"] == "codec_optimized_full":
        require(stats["validation_score"]["estimated_bits"] == stats["selector_charged_bytes"] * 8 and stats["validation_score"]["dictionary_bytes"] == len(dictionary),
                (name, "independent public one-shot selector frames equal codec-aware charged score"))
    return stats


def functional_campaign(args, prepared, corpus, upstream, reference):
    rows = []
    percentages = (100, 50, 34, 25, 20, 17, 14, 13, 11, 10)
    for family_index, family in enumerate(corpus["families"]):
        paths = lambda partition: [str(prepared / row["path"]) for row in family[partition]]
        base = dict(training_paths=paths("training"), heldout_paths=paths("heldout"),
                    target_size=512, segment_size=64, dmer_size=6, hash_log=12, acceleration=1,
                    dictionary_id=0xFA570001 + family_index * 256)
        raw_wires = {}
        for variant, changes in (("base", {}), ("d8", {"dmer_size": 8}), ("f16", {"hash_log": 16}), ("acceleration10", {"acceleration": 10})):
            for mode in ("raw", "prepared", "full"):
                name = f"vort-{family['kind']}-{mode}-{variant}"
                config = {**base, **changes, "mode": mode}
                stats = validate_probe(args, name, config, reference)
                if mode == "raw":
                    raw_wires[variant] = stats["dictionary_sha256"]
                elif mode == "prepared":
                    require(stats["prepared_reuse_verified"] and stats["dictionary_sha256"] == raw_wires[variant], (name, "prepared and one-shot same history"))
                    require(stats["preparation_profile"]["frequency_passes"] == 1 and stats["profile"]["frequency_passes"] == 0, (name, "preparation counts frequencies once"))
                elif stats["standard_profile"]:
                    count = len(config["training_paths"]) * percentages[config["acceleration"] - 1] // 100
                    require(stats["standard_profile"]["finalization_samples"] == count, (name, "exact finalization sample floor"))
                rows.append({"kind": family["kind"], "case": name, "config": config, **stats})
        optimizer = {**base, "training_paths": paths("training"), "selector_paths": paths("selector")}
        for mode in ("optimized_raw", "optimized_full", "codec_optimized_full"):
            serial = None
            for threads in (1, 2):
                name = f"vort-{family['kind']}-{mode}-threads{threads}"
                config = {**optimizer, "mode": mode, "threads": threads}
                stats = validate_probe(args, name, config, reference)
                signature = (stats["dictionary_sha256"], stats["selected_options"], stats["validation_score"])
                if serial is None:
                    serial = signature
                else:
                    require(signature == serial, (name, "serial and parallel deterministic selection"))
                rows.append({"kind": family["kind"], "case": name, "config": config, **stats})
        for numerator, denominator in ((3, 4), (1, 1)):
            name = f"vort-{family['kind']}-split{numerator}of{denominator}"
            config = {**base, "training_paths": paths("training") + paths("selector"), "mode": "optimized_split_raw", "split_numerator": numerator, "split_denominator": denominator}
            stats = validate_probe(args, name, config, reference)
            rows.append({"kind": family["kind"], "case": name, "config": config, **stats})
        for mode in ("optimized_raw", "codec_optimized_full"):
            name = f"vort-{family['kind']}-{mode}-shrink"
            config = {**optimizer, "mode": mode, "shrink_dictionary": True, "regression_tolerance_bps": 300}
            stats = validate_probe(args, name, config, reference)
            require(stats["optimization_profile"]["shrink_evaluations"] > 0, (name, "actual shrink search"))
            rows.append({"kind": family["kind"], "case": name, "config": config, **stats})
    for row in upstream["rows"]:
        if row["error"]:
            rows.append({**row, "case": f"upstream-{row['kind']}-{row['case']}", "direction": "upstream_training_error"})
            continue
        dictionary = (prepared / row["path"]).read_bytes()
        require(digest(dictionary) == row["sha256"], "frozen reference dictionary hash")
        family = next(f for f in corpus["families"] if f["kind"] == row["kind"])
        payload_path = prepared / family["heldout"][0]["path"]
        payload = payload_path.read_bytes()
        header = reference.inspect(dictionary)["header_bytes"]
        raw_dictionary = dictionary[header:]
        raw_path = args.work_dir / f"upstream-{row['kind']}-{row['case']}.raw"
        raw_path.write_bytes(raw_dictionary)
        raw_expected = args.work_dir / f"upstream-{row['kind']}-{row['case']}-raw-expected.bin"
        raw_expected.write_bytes(raw_dictionary[-512:])
        for form, dictionary_bytes, dictionary_path, expected_path, full in (
                ("full", dictionary, prepared / row["path"], payload_path, True),
                ("raw", raw_dictionary, raw_path, raw_expected, False)):
            for level in (-4, 3):
                name = f"upstream-{row['kind']}-{row['case']}-{form}-level{level}"
                expected = expected_path.read_bytes()
                wire = reference.encode_level(expected, dictionary_bytes, level)
                frame_path = args.work_dir / f"{name}.zst"
                frame_path.write_bytes(wire)
                config = dict(mode="decode_reference", dictionary_path=str(dictionary_path), full_dictionary=full,
                              frame_path=str(frame_path), expected_path=str(expected_path))
                stats = invoke_probe(args, name, config)
                require(stats["round_trip_verified"] and stats["outside_output_unchanged"], (name, "upstream FastCover dictionary and frame to Vort"))
                rows.append({"kind": row["kind"], "case": name, "direction": "upstream_to_vort", "config": config,
                             "dictionary_sha256": digest(dictionary_bytes), "frame_sha256": digest(wire), **stats})
    return rows


def resource_campaign(args, prepared, corpus, reference):
    family = corpus["families"][0]
    base = dict(mode="raw", training_paths=[str(prepared / row["path"]) for row in family["training"]],
                target_size=512, segment_size=64, dmer_size=6, hash_log=12, acceleration=1, dictionary_id=0xFA57F001)
    cases = (("d7", {"dmer_size": 7}, "InvalidDictionaryTraining"),
             ("f0", {"hash_log": 0}, "InvalidDictionaryTraining"),
             ("f32", {"hash_log": 32}, "InvalidDictionaryTraining"),
             ("acceleration0", {"acceleration": 0}, "InvalidDictionaryTraining"),
             ("acceleration11", {"acceleration": 11}, "InvalidDictionaryTraining"),
             ("segment0", {"segment_size": 0}, "InvalidDictionaryTraining"),
             ("dictionary-limit", {"max_dictionary_size": 511}, "InvalidDictionaryTraining"),
             ("corpus-limit", {"max_corpus_size": 1}, "InvalidDictionaryTraining"),
             ("memory-limit", {"max_working_memory": 1}, "WorkingMemoryLimitExceeded"),
             ("large-frequency-memory", {"hash_log": 31}, "WorkingMemoryLimitExceeded"),
             ("oom0", {"fail_index": 0}, "OutOfMemory"),
             ("oom2", {"fail_index": 2}, "OutOfMemory"),
             ("prepared-memory", {"mode": "prepared", "max_working_memory": 1}, "WorkingMemoryLimitExceeded"),
             ("full-memory", {"mode": "full", "max_working_memory": 1}, "WorkingMemoryLimitExceeded"),
             ("full-id0", {"mode": "full", "dictionary_id": 0}, "InvalidDictionaryMetadata"),
             ("full-target4", {"mode": "full", "target_size": 4}, "InvalidDictionaryTraining"),
             ("optimizer-candidate-limit", {"mode": "optimized_raw", "max_candidates": 1}, "InvalidDictionaryTraining"),
             ("optimizer-score-limit", {"mode": "optimized_raw", "max_scoring_calls": 1}, "InvalidDictionaryTraining"),
             ("optimizer-threads0", {"mode": "optimized_raw", "threads": 0}, "InvalidDictionaryTraining"))
    rows = []
    cases += (("optimizer-memory", {"mode": "optimized_raw", "threads": 2, "max_working_memory": 1}, "WorkingMemoryLimitExceeded"),
              ("codec-memory", {"mode": "codec_optimized_full", "threads": 2, "max_working_memory": 1}, "WorkingMemoryLimitExceeded"))
    for label, changes, expected_error in cases:
        name = f"resource-{label}"
        config = {**base, "selector_paths": [str(prepared / row["path"]) for row in family["selector"]], **changes, "expect_failure": True}
        stats = validate_probe(args, name, config, reference)
        require(stats["error"] == expected_error, (name, "exact training error", stats["error"]))
        disabled = validate_probe(args, name + "-unprofiled", {**config, "profile_enabled": False}, reference)
        require(disabled["error"] == stats["error"], (name, "profile preserves error"))
        rows.append({"case": name, "config": config, "unprofiled_error_verified": True, **stats})
    empty = {**base, "training_paths": [], "target_size": 0, "segment_size": None}
    rows.append({"case": "raw-empty-target0", "config": empty, **validate_probe(args, "raw-empty-target0", empty, reference)})
    floor_zero = {**base, "mode": "full", "training_paths": base["training_paths"][:5], "acceleration": 10}
    stats = validate_probe(args, "full-finalization-floor0", floor_zero, reference)
    require(stats["standard_profile"]["finalization_samples"] == 0 and stats["standard_profile"]["finalization_sample_bytes"] == 0,
            "small accelerated finalizer keeps exact zero floor")
    rows.append({"case": "full-finalization-floor0", "config": floor_zero, **stats})
    uniform_paths = []
    for index in range(10):
        path = args.work_dir / f"uniform-{index}.bin"
        path.write_bytes(b"Q" * 256)
        uniform_paths.append(str(path))
    for dmer in (6, 8):
        for acceleration in (1, 10):
            name = f"uniform-d{dmer}-acceleration{acceleration}"
            config = {**base, "training_paths": uniform_paths, "dmer_size": dmer, "acceleration": acceleration}
            raw = validate_probe(args, name + "-raw", config, reference)
            full_config = {**config, "mode": "full", "expect_failure": raw["content_bytes"] < 8}
            full = validate_probe(args, name + "-full", full_config, reference)
            if full_config["expect_failure"]:
                require(full["error"] == "InvalidDictionaryTraining", (name, "standard wrapper rejects unusable history without padding"))
            settings = {**reference_matrix(config["dictionary_id"])[0][1], "d": dmer, "acceleration": acceleration}
            dictionary, upstream = reference.train_parameters([b"Q" * 256] * 10, settings, 1024)
            if dictionary is not None:
                dictionary_path = args.work_dir / f"{name}-upstream.zdict"
                dictionary_path.write_bytes(dictionary)
                expected_path = args.work_dir / f"{name}-upstream-expected.bin"
                expected_path.write_bytes(b"Q" * 256 + b"R")
                frame_path = args.work_dir / f"{name}-upstream.zst"
                frame_path.write_bytes(reference.encode_level(expected_path.read_bytes(), dictionary, 3))
                decoded = invoke_probe(args, name + "-upstream-decode", dict(mode="decode_reference", dictionary_path=str(dictionary_path),
                                       full_dictionary=True, frame_path=str(frame_path), expected_path=str(expected_path)))
                require(decoded["round_trip_verified"] and decoded["outside_output_unchanged"], (name, "uniform upstream dictionary and frame decoded by Vort"))
                upstream["sha256"] = digest(dictionary)
                upstream["vort_decode"] = decoded
            rows.append({"case": name, "sample_count": 10, "sample_bytes": 256, "sample_sha256": digest(b"Q" * 256),
                         "config": config, "raw": raw, "full": full, "upstream_settings": settings, "upstream": upstream})
    return rows


def provenance(args, reference):
    cpu = re.search(r"^model name\s*:\s*(.+)$", Path("/proc/cpuinfo").read_text(), re.MULTILINE)
    library = next(Path(line.split()[-1]).resolve() for line in Path("/proc/self/maps").read_text().splitlines() if "/libzstd.so" in line)
    return {"created_utc": datetime.now(timezone.utc).isoformat(), "platform": platform.platform(),
            "cpu": cpu.group(1) if cpu else platform.processor(), "invocation": sys.argv,
            "cpu_flags": re.search(r"^flags\s*:\s*(.+)$", Path("/proc/cpuinfo").read_text(), re.MULTILINE).group(1).split(),
            "cpu_affinity": sorted(os.sched_getaffinity(0)),
            "probe_sha256": digest(args.probe.read_bytes()), "build_mode": args.build_mode,
            "zig_version": run(args.zig, "version").stdout.decode().strip(), "zig_sha256": digest(args.zig.read_bytes()),
            "zstd_helper_object_sha256": digest(args.zstd_helper_object.read_bytes()) if args.zstd_helper_object else None,
            "reference_version": reference.version, "reference_library": str(library), "reference_sha256": digest(library.read_bytes()),
            "reference_helper_sha256": digest(reference.helper_path.read_bytes()), "reference_header_version": reference.header_version,
            "reference_headers_sha256": {str(path): digest(path.read_bytes()) for path in (Path("/usr/include/zdict.h"), Path("/usr/include/zstd.h"))},
            "reference_helper_build": "cc -std=c11 -D_POSIX_C_SOURCE=200809L -O3 -fPIC -shared -Wall -Wextra -Werror tools/zstd/fast_cover_reference.c -lzstd",
            "local_reference_source_sha256": {str(path): digest(path.read_bytes()) for path in
                                               (Path("/home/passchaos/Work/zstd/lib/dictBuilder/fastcover.c"), Path("/home/passchaos/Work/zstd/lib/zdict.h"))}}


def timing_summary(values):
    require(values and all(value > 0 for value in values), "positive measured training durations")
    return {"samples_ns": values, "min_ns": min(values), "median_ns": statistics.median(values)}


def vort_measure(args, name, config, reference):
    measured_config = {**config, "profile_enabled": False, "heldout_paths": [], "encode_selector": False}
    validate_probe(args, name + "-warmup", measured_config, reference)
    first, repeated, preparations, totals = [], [], [], []
    signature = None
    for index in range(args.rounds):
        stats = validate_probe(args, f"{name}-round{index}", measured_config, reference)
        current = stats["dictionary_sha256"]
        if signature is None:
            signature = current
        require(current == signature, (name, "measurement preserves dictionary output"))
        first.append(stats["training_ns_samples"][0])
        repeated.extend(stats["training_ns_samples"][1:])
        preparations.extend(stats["preparation_ns_samples"])
        totals.extend(t + p for t, p in zip(stats["training_ns_samples"], stats["preparation_ns_samples"]))
    return {"scope": "public trainer call; input IO, dictionary validation, encoding and caller copying excluded",
            "caller_profile": False, "warmup_processes": 1, "rounds": args.rounds,
            "first_call_per_process": timing_summary(first), "repeated_calls_same_process": timing_summary(repeated),
            "preparation_samples_ns": preparations, "training_plus_preparation": timing_summary(totals), "dictionary_sha256": signature}


def reference_costs(reference, dictionary, selector_samples, heldout_samples):
    by_level, heldout_total, selector_total = {}, len(dictionary), len(dictionary)
    for level in (1, 3):
        sizes = [len(reference.encode_level(payload, dictionary, level)) for payload in heldout_samples]
        by_level[level] = len(dictionary) + sum(sizes)
        heldout_total += sum(sizes)
        selector_total += sum(len(reference.encode_level(payload, dictionary, level, checksum=False)) for payload in selector_samples)
    return {"charged_heldout_bytes": by_level, "charged_heldout_total": heldout_total, "selector_charged_bytes": selector_total}


def reference_assessment(args, name, reference, training, selectors, heldout, settings, capacity):
    warmup, warmup_metadata = reference.train_parameters(training, settings, capacity)
    if warmup is None:
        return {"error": warmup_metadata["error"], "settings": settings, "serialized_capacity": capacity}
    times, selected = [], None
    for _ in range(args.rounds):
        dictionary, metadata = reference.train_parameters(training, settings, capacity)
        require(dictionary == warmup, (name, "fixed reference measurement deterministic"))
        times.append(metadata["instrumented_elapsed_ns"])
        selected = metadata
    path = args.work_dir / f"{name}.zdict"
    path.write_bytes(warmup)
    return {"error": None, "settings": settings, "serialized_capacity": capacity, "dictionary_path": str(path),
            "dictionary_sha256": digest(warmup), **selected, **reference_costs(reference, warmup, selectors, heldout),
            "training": {"scope": "ZDICT FastCover selection plus standard entropy finalization; sample concatenation and output validation excluded",
                         "warmup_calls": 1, "rounds": args.rounds, **timing_summary(times)}}


def performance_campaign(args, prepared, corpus, reference, functional_rows):
    rows = []
    for index, family in enumerate(corpus["families"]):
        kind = family["kind"]
        paths = lambda partition: [str(prepared / row["path"]) for row in family[partition]]
        training, selectors, heldout = (samples(prepared, family, partition) for partition in ("training", "selector", "heldout"))
        base = dict(training_paths=paths("training"), selector_paths=paths("selector"), heldout_paths=paths("heldout"),
                    mode="full", target_size=512, segment_size=64, dmer_size=6, hash_log=12, acceleration=1,
                    dictionary_id=0xFA570001 + index * 256)
        functional = next(row for row in functional_rows if row["case"] == f"vort-{kind}-full-base")
        n = functional["dictionary_bytes"]
        settings = reference_matrix(base["dictionary_id"])[0][1]
        timings = {}
        for mode in ("raw", "prepared", "full"):
            timings[mode] = vort_measure(args, f"measure-{kind}-{mode}", {**base, "mode": mode}, reference)
        require(timings["full"]["dictionary_sha256"] == functional["dictionary_sha256"], (kind, "measured dictionary matches the frozen functional dictionary N"))
        matched = reference_assessment(args, f"assessment-{kind}-matched-{n}", reference, training, selectors, heldout, settings, n)
        fixed = reference_assessment(args, f"assessment-{kind}-capacity1024", reference, training, selectors, heldout, settings, 1024)
        ladder = []
        for target in (256, 512, 768):
            name = f"assessment-{kind}-ladder{target}"
            config = {**base, "target_size": target, "encode_selector": True, "profile_enabled": False}
            stats = validate_probe(args, name, config, reference)
            ladder.append({"raw_target": target, "eligible": stats["dictionary_bytes"] <= 1024, "config": config,
                           "training": vort_measure(args, name + "-measure", config, reference), **stats})
        eligible = [row for row in ladder if row["eligible"]]
        require(eligible, (kind, "fixed raw-target ladder has a dictionary inside serialized budget"))
        winner = min(eligible, key=lambda row: (row["selector_charged_bytes"], row["dictionary_bytes"], row["raw_target"]))
        rows.append({"kind": kind, "training_samples": len(training), "selector_samples": len(selectors), "heldout_samples": len(heldout),
                     "training_sha256": digest(b"".join(training)), "selector_sha256": digest(b"".join(selectors)),
                     "heldout_sha256": digest(b"".join(heldout)), "settings": base, "stage_training": timings,
                     "matched_serialized_capacity": {"capacity_method": "N is the already generated Vort full dictionary size; upstream trains with capacity N",
                                                     "n": n, "vort_dictionary_bytes": functional["dictionary_bytes"],
                                                     "vort_charged_heldout_bytes": functional["charged_heldout_bytes"],
                                                     "vort_charged_heldout_total": functional["charged_heldout_total"], "upstream": matched},
                     "fixed_serialized_budget": {"budget": 1024, "selection_method": "minimum charged selector bytes among fixed raw targets 256/512/768 whose full dictionary fits; heldout unused for selection",
                                                 "ladder": ladder, "selected_raw_target": winner["raw_target"],
                                                 "selected_full_dictionary_bytes": winner["dictionary_bytes"],
                                                 "selected_charged_heldout_bytes": winner["charged_heldout_bytes"],
                                                 "selected_charged_heldout_total": winner["charged_heldout_total"], "upstream": fixed}})
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference-helper", type=Path, required=True)
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--work-dir", type=Path, required=True)
    parser.add_argument("--prepared", type=Path)
    parser.add_argument("--probe", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--measure", action="store_true")
    parser.add_argument("--validated-report", type=Path, help="Reuse completed functional checks for the unchanged frozen source and probe during measurement")
    parser.add_argument("--rounds", type=int, default=3)
    parser.add_argument("--build-mode", choices=("Debug", "ReleaseSafe", "ReleaseFast", "ReleaseSmall"))
    parser.add_argument("--zig", type=Path, default=Path("/home/passchaos/Temp/zig-x86_64-linux-0.16.0/zig"))
    parser.add_argument("--zstd-helper-object", type=Path)
    args = parser.parse_args()
    args.work_dir = args.work_dir.resolve()
    args.work_dir.mkdir(parents=True, exist_ok=True)
    require(not any(args.work_dir.iterdir()), "--work-dir must be empty")
    require(args.rounds > 0, "rounds positive")
    require(not args.measure or args.rounds >= 3, "performance measurement requires at least three rounds")
    require(args.validated_report is None or args.measure, "--validated-report is only valid with --measure")
    reference = Reference(args.reference_helper)
    if args.prepared:
        prepared = args.prepared.resolve()
        corpus = json.loads((prepared / "corpus.json").read_text())
        upstream = json.loads((prepared / "reference.json").read_text())
        for family in corpus["families"]:
            for partition in ("training", "selector", "heldout"):
                samples(prepared, family, partition)
        for row in upstream["rows"]:
            if row["error"] is None:
                require(digest((prepared / row["path"]).read_bytes()) == row["sha256"], "frozen upstream dictionary hash")
    else:
        prepared = args.work_dir
        corpus = make_corpus(prepared)
        upstream = prepare_reference(prepared, corpus, reference)
    if args.prepare_only:
        print(f"fast_cover_prepared_families={len(corpus['families'])} upstream_cases={len(upstream['rows'])} "
              f"accepted={sum(row['error'] is None for row in upstream['rows'])} libzstd={reference.version} path={prepared}")
        return
    require(args.probe is not None, "--probe is required for Vort validation")
    args.probe = args.probe.resolve()
    starting_source = source_hashes()
    starting_probe = digest(args.probe.read_bytes())
    if args.validated_report:
        validated = json.loads(args.validated_report.read_text())
        require(validated["source_sha256"] == starting_source and validated["probe_sha256"] == starting_probe,
                "validated source and probe must match the measurement exactly")
        require(validated["corpus"] == corpus and validated["upstream_prepared"] == upstream,
                "validated frozen corpus and reference dictionaries must match")
        require(validated["reference_version"] == reference.version and validated["reference_helper_sha256"] == digest(reference.helper_path.read_bytes()),
                "validated reference implementation must match")
        rows = validated["rows"]
    else:
        rows = functional_campaign(args, prepared, corpus, upstream, reference)
        rows += resource_campaign(args, prepared, corpus, reference)
    require(source_hashes() == starting_source and digest(args.probe.read_bytes()) == starting_probe,
            "source or probe changed during campaign; rerun after freeze")
    report = {"schema": "vort-fast-cover-functional-v1", **provenance(args, reference), "source_sha256": starting_source,
              "capacity_semantics": "Vort target and maximum dictionary size limit raw history; upstream capacity limits serialized standard dictionary including entropy header",
              "corpus": corpus, "upstream_prepared": upstream, "performance_measurements": False, "rows": rows}
    if args.measure:
        report["performance"] = performance_campaign(args, prepared, corpus, reference, rows)
        report["performance_measurements"] = True
        report["measurement_completed_utc"] = datetime.now(timezone.utc).isoformat()
        report["measurement_conditions"] = "competing builds paused externally; one warmup, repeated trainer calls, all duration samples retained; first per-process and repeated calls distinguished, without hardware cache flushing"
        require(source_hashes() == starting_source and digest(args.probe.read_bytes()) == starting_probe, "source changed during measurement")
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(f"fast_cover_cases={len(rows)} families={len(corpus['families'])} upstream_accepted={sum(r['error'] is None for r in upstream['rows'])} "
          f"libzstd={reference.version} performance_measurements={str(args.measure).lower()}")


if __name__ == "__main__":
    main()
