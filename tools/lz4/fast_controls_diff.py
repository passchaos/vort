#!/usr/bin/env python3
"""Small native LZ4 acceleration controls and independent reference wires."""
import argparse
import ctypes as C
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import random
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
OLD_REVISION = "fef87a827f5aeaa1c5a7b2035a7eb0c7648d9389"


def require(value, detail):
    if not value:raise AssertionError(detail)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def bind(library, name, result, *arguments):
    function = getattr(library, name);function.restype, function.argtypes = result, list(arguments);return function


def normalized(acceleration):
    return max(1, min(65537, acceleration))


class Controls(C.Structure):
    _fields_ = [("acceleration", C.c_int32), ("frame_level", C.c_int32)] + [(name, C.c_uint32) for name in
                  ("block_size_id", "block_independent", "content_size", "content_checksum", "block_checksum", "dictionary_id")]


class Reference:
    def __init__(self, helper):
        self.path = helper.resolve()
        loader = C.CDLL("libdl.so.2")
        handle = bind(loader, "dlmopen", C.c_void_p, C.c_long, C.c_char_p, C.c_int)(-1, str(self.path).encode(), 2)
        require(handle, "isolated LZ4 reference namespace")
        self.library = C.CDLL(str(self.path), handle=handle)
        self.version = bind(self.library, "lfcr_version_string", C.c_char_p)().decode()
        self.header_version = bind(self.library, "lfcr_header_version", C.c_uint32)()
        self.runtime_version = bind(self.library, "lfcr_runtime_version", C.c_uint32)()
        require(self.header_version == self.runtime_version, "LZ4 matching reference headers/runtime")
        self.runtime_path = Path(bind(self.library, "lfcr_runtime_library_path", C.c_char_p)().decode()).resolve()
        require(bind(self.library, "lfcr_controls_size", C.c_size_t)() == C.sizeof(Controls), "header-owned Controls pointer ABI")
        self.preferences_size = bind(self.library, "lfcr_frame_preferences_size", C.c_size_t)()
        self.block_encode = bind(self.library, "lfcr_block_encode", C.c_int, C.c_int32, C.c_void_p, C.c_size_t, C.c_void_p, C.c_size_t, C.c_void_p, C.c_size_t)
        self.block_decode = bind(self.library, "lfcr_block_decode", C.c_int, C.c_void_p, C.c_size_t, C.c_void_p, C.c_size_t, C.c_void_p, C.c_size_t)
        self.frame_bound = bind(self.library, "lfcr_frame_bound", C.c_size_t, C.POINTER(Controls), C.c_size_t)
        self.frame_encode = bind(self.library, "lfcr_frame_encode", C.c_size_t, C.POINTER(Controls), C.c_void_p, C.c_size_t, C.c_void_p, C.c_size_t, C.c_void_p, C.c_size_t)
        self.frame_decode = bind(self.library, "lfcr_frame_decode", C.c_size_t, C.c_void_p, C.c_size_t, C.c_void_p, C.c_size_t, C.c_void_p, C.c_size_t, C.POINTER(C.c_size_t), C.POINTER(C.c_size_t))
        self.error = bind(self.library, "LZ4F_isError", C.c_uint, C.c_size_t)
        self.error_name = bind(self.library, "LZ4F_getErrorName", C.c_char_p, C.c_size_t)

    def options(self, config, dictionary):
        acceleration = normalized(config.get("acceleration", 1))
        # liblz4 frame source maps level<0 to -level+1, not abs(level).
        return Controls(acceleration, 1 - acceleration, config.get("block_size_id", 4), config.get("block_mode", "independent") == "independent",
                        config.get("content_size", True), config.get("content_checksum", True), config.get("block_checksum", False), config.get("dictionary_id", 7) if dictionary else 0)

    def encode(self, payload, config, dictionary=b""):
        options = self.options(config, dictionary)
        capacity = len(payload) + len(payload) // 255 + 65536
        output = C.create_string_buffer(b"\xa5" * (capacity + 16))
        if config["format"] == "raw":
            count = self.block_encode(config.get("acceleration", 1), payload, len(payload), dictionary, len(dictionary), C.byref(output, 8), capacity)
            require(count > 0, "reference raw/continue encode")
        else:
            count = self.frame_encode(C.byref(options), payload, len(payload), dictionary, len(dictionary), C.byref(output, 8), capacity)
            require(not self.error(count), ("reference frame encode", self.error_name(count).decode()))
        require(output.raw[:8] == b"\xa5" * 8 and output.raw[capacity + 8:capacity + 16] == b"\xa5" * 8, "reference encoder output guards")
        return output.raw[8:8 + count]

    def verify(self, wire, payload, format, dictionary=b""):
        capacity = max(1, len(payload))
        output = C.create_string_buffer(b"\xa5" * (capacity + 16))
        if format == "raw":
            count = self.block_decode(wire, len(wire), dictionary, len(dictionary), C.byref(output, 8), capacity)
            require(count == len(payload), ("reference raw usingDict decode", count, len(payload)))
        else:
            consumed, written = C.c_size_t(), C.c_size_t()
            status = self.frame_decode(wire, len(wire), dictionary, len(dictionary), C.byref(output, 8), capacity, C.byref(consumed), C.byref(written))
            require(status == 0 and consumed.value == len(wire) and written.value == len(payload), ("reference frame usingDict decode", status, consumed.value, written.value))
            count = written.value
        require(output.raw[8:8 + count] == payload, "reference decoded bytes")
        require(output.raw[:8] == b"\xa5" * 8 and output.raw[capacity + 8:capacity + 16] == b"\xa5" * 8, "reference decoder output guards")

    def provenance(self):
        return {"version": self.version, "header_version": self.header_version, "runtime_version": self.runtime_version,
                "helper_sha256": digest(self.path.read_bytes()), "runtime_path": str(self.runtime_path), "runtime_sha256": digest(self.runtime_path.read_bytes()),
                "controls_size": C.sizeof(Controls), "header_owned_frame_preferences_size": self.preferences_size,
                "frame_level_mapping": "fast acceleration=max(1,min(65537,1-level)) for negative frame levels; generator selects level=1-normalized_acceleration"}


def samples(directory):
    rng = random.Random(0xfe87a82)
    noisy = rng.randbytes(4096) + b"LZ4 sparse sampling native parser\n" * 96
    prefix = rng.randbytes(4096)
    path = directory / "fast-prefix.dictionary"
    if path.exists():require(path.read_bytes() == prefix, "fixed prefix changed")
    else:path.write_bytes(prefix)
    cases = []
    for format in ("raw", "frame"):
        for acceleration in (-2147483648, -1, 0, 1, 2, 17, 65537, 65538, 2147483647):
            cases.append({"name": format + "-normalize-" + str(acceleration), "payload": noisy, "dictionary": b"",
                          "config": {"format": format, "acceleration": acceleration}})
    for acceleration in (1, 17):
        for format, api in (("raw", "reusable"), ("raw", "into"), ("frame", "reusable"), ("frame", "incremental"), ("frame", "chunks"), ("frame", "into")):
            cases.append({"name": format + "-" + api + "-" + str(acceleration), "payload": noisy, "dictionary": b"",
                          "config": {"format": format, "api": api, "acceleration": acceleration, "input_chunk": 127, "output_chunk": 31}})
        for format in ("raw", "frame"):
            cases.append({"name": format + "-prefix-" + str(acceleration), "payload": prefix[-1024:] + b"tail", "dictionary": prefix,
                          "config": {"format": format, "acceleration": acceleration, "dictionary_path": str(path), "block_mode": "linked"}})
    cases.append({"name": "frame-linked-cross-block", "payload": noisy * 12, "dictionary": b"",
                  "config": {"format": "frame", "acceleration": 2, "block_mode": "linked", "block_size_id": 4, "api": "incremental", "input_chunk": 4093, "output_chunk": 8191}})
    for format in ("raw", "frame"):
        cases.append({"name": format + "-empty", "payload": b"", "dictionary": b"", "config": {"format": format, "acceleration": 1}})
    return cases


def call(probe, directory, name, payload, config, expected_error=None):
    source, output, settings = [directory / (name + suffix) for suffix in (".input", ".wire", ".json")]
    source.write_bytes(payload);output.write_bytes(b"existing output sentinel");settings.write_text(json.dumps(config) + "\n")
    result = subprocess.run([str(probe), str(source), str(output), str(settings)], cwd=ROOT, capture_output=True, timeout=120)
    require(result.returncode == 0, (name, result.stderr.decode(errors="replace")))
    stats = json.loads(result.stdout);require(stats["error"] == expected_error, (name, config, stats))
    if expected_error:require(output.read_bytes() == b"existing output sentinel", "error changed output")
    with (directory / "fast-events.jsonl").open("a") as events:events.write(json.dumps({"name": name, "expected_error": expected_error, "report": stats}) + "\n")
    return output.read_bytes(), stats


def baseline(args, cases, references):
    path = args.output_dir / "fast-controls-baseline.json"
    if path.exists():
        data = json.loads(path.read_text());require(data["revision"] == OLD_REVISION, "old fef baseline revision");return data
    require(args.legacy_probe and args.legacy_source, "old source/probe needed only for initial wire freeze")
    names = {"raw-normalize-1", "frame-normalize-1", "raw-reusable-1", "frame-reusable-1", "frame-incremental-1", "frame-chunks-1", "raw-prefix-1", "frame-prefix-1"}
    rows = []
    for case in cases:
        if case["name"] not in names:continue
        config = {key: value for key, value in case["config"].items() if key != "acceleration"}
        wire, _ = call(args.legacy_probe, args.output_dir, "legacy-" + case["name"], case["payload"], config)
        for reference in references:reference.verify(wire, case["payload"], config["format"], case["dictionary"])
        rows.append({"name": case["name"], "wire": "legacy-" + case["name"] + ".wire", "wire_sha256": digest(wire), "input_sha256": digest(case["payload"]), "config": config})
    paths = [args.legacy_source / "src/root.zig", args.legacy_source / "src/lz4.zig", args.legacy_source / "fast_controls_probe.zig", *sorted((args.legacy_source / "src/lz4").rglob("*.zig"))]
    data = {"schema": "vort-lz4-fast-baseline-v1", "revision": OLD_REVISION, "rows": rows, "probe_sha256": digest(args.legacy_probe.read_bytes()), "source_sha256": {str(file.relative_to(args.legacy_source)): digest(file.read_bytes()) for file in paths}}
    path.write_text(json.dumps(data, indent=2) + "\n");return data


def reference_normalization(reference):
    payload = random.Random(0x193).randbytes(2048) + b"abcabcxyz" * 160
    rows = []
    for format in ("raw", "frame"):
        canonical = {value: reference.encode(payload, {"format": format, "acceleration": value}) for value in (1, 17, 65537)}
        for requested in (-2147483648, -1, 0, 1, 17, 65537, 65538, 2147483647):
            wire = reference.encode(payload, {"format": format, "acceleration": requested})
            require(wire == canonical[normalized(requested)], "reference normalization equivalence")
            reference.verify(wire, payload, format)
            rows.append({"format": format, "requested": requested, "normalized": normalized(requested), "wire_sha256": digest(wire)})
    return rows


def empty_baseline(args, cases):
    path = args.output_dir / "fast-empty-baseline.json"
    if path.exists():return json.loads(path.read_text())
    require(args.legacy_probe, "legacy probe needed only for the two independent empty-wire baselines")
    rows = []
    for case in cases:
        if not case["name"].endswith("-empty"):continue
        config = {"format": case["config"]["format"]}
        wire, _ = call(args.legacy_probe, args.output_dir, "legacy-" + case["name"], b"", config)
        rows.append({"name": case["name"], "wire": "legacy-" + case["name"] + ".wire", "wire_sha256": digest(wire), "wire_bytes": len(wire)})
    data = {"revision": OLD_REVISION, "rows": rows, "scope": "independent old empty-wire supplement; original eight-row baseline unchanged"}
    path.write_text(json.dumps(data, indent=2) + "\n");return data


def campaign(args, cases, references, old, empty):
    rows, outputs = [], {}
    originals = {row["name"]: row for row in old["rows"]}
    for case in cases:
        name, payload, config = case["name"], case["payload"], case["config"]
        if args.case and name not in args.case:continue
        wire, stats = call(args.probe, args.output_dir, name, payload, config)
        resolved = normalized(config["acceleration"])
        require(stats["resolved"]["acceleration"] == resolved and stats["profile"]["resolved_acceleration"] == resolved, "actual native normalization")
        if payload:require(stats["profile"]["blocks_attempted"] > 0 and stats["profile"]["positions_inspected"] > 0, "actual native work profile")
        if resolved > 1 and not case["dictionary"]:
            require(stats["profile"]["positions_skipped"] > 0 and stats["profile"]["max_skip_step"] > 1, "mixed input acceleration did not actually skip search positions")
        if name in originals:
            expected = (args.output_dir / originals[name]["wire"]).read_bytes();require(digest(expected) == originals[name]["wire_sha256"] and wire == expected, "default acceleration changed old native wire")
        if not payload:
            old_empty = next(row for row in empty["rows"] if row["name"] == name)
            expected = (args.output_dir / old_empty["wire"]).read_bytes()
            require(wire == expected and digest(wire) == old_empty["wire_sha256"], "legacy empty wire changed")
        off, off_stats = call(args.probe, args.output_dir, name + "-off", payload, {**config, "profile_enabled": False})
        require(off == wire and off_stats["resolved"] == stats["resolved"], "profile changed native wire/resolution")
        results = []
        if not payload and config["format"] == "raw":
            require(wire == b"", "legacy raw empty is zero bytes")
            own, _ = call(args.probe, args.output_dir, name + "-own-decode", wire, {"format": "raw", "operation": "decode", "expected_size": 0})
            require(own == b"", "own raw-empty decode failed")
        for index, reference in enumerate(references):
            if not payload and config["format"] == "raw":
                target = C.create_string_buffer(1)
                status = reference.block_decode(wire, 0, b"", 0, target, 1)
                require(status == -1, "reference raw-empty rejection changed")
                canonical = reference.encode(b"", config)
                require(canonical == b"\x00", "liblz4 canonical raw empty byte")
                reference.verify(canonical, b"", "raw")
                restored, _ = call(args.probe, args.output_dir, name + "-canonical-reverse-" + str(index), canonical,
                                    {"format": "raw", "operation": "decode", "expected_size": 0})
                require(restored == b"", "canonical reference raw-empty reverse decode")
                results.append({"reference_version": reference.version, "direction": "reference-to-vort only", "raw_empty_legacy": {"wire_bytes": 0, "reference_decode_result": status, "status": "known format boundary"}, "canonical_reference_reverse": {"wire_hex": "00", "decoded_bytes": 0}})
                continue
            reference.verify(wire, payload, config["format"], case["dictionary"])
            decoded, _ = call(args.probe, args.output_dir, name + "-reverse-" + str(index), reference.encode(payload, config, case["dictionary"]),
                              {**config, "operation": "decode", "expected_size": len(payload)})
            require(decoded == payload, "public decode of independent reference wire")
            results.append({"reference_version": reference.version, "direction": "bidirectional", "dictionary_api": "continue/loadDict and usingDict" if case["dictionary"] else None})
        if "normalize" in name:
            key = (config["format"], resolved)
            if key in outputs:require(outputs[key] == wire, "normalization equivalent native inputs changed wire")
            outputs[key] = wire
        rows.append({"name": name, "input_bytes": len(payload), "wire_bytes": len(wire), "wire_sha256": digest(wire), "config": config,
                     "probe": stats, "reference_results": results,
                     "api_scope": "public incremental encoder with chunked input" if config.get("api") == "chunks" else config.get("api", "one_shot")})
    if not args.case:
        require(outputs[("raw", 1)] != outputs[("raw", 17)], "fixed mixed corpus did not demonstrate a changed acceleration wire")
        config = {"format": "raw", "acceleration": 17, "chain_depth": 0}
        payload = cases[0]["payload"]
        wire, stats = call(args.probe, args.output_dir, "chain-zero", payload, config)
        require(stats["resolved"]["chain_depth"] == 0 and stats["profile"]["chain_candidates"] == 0, "chain depth was not independent")
        for reference in references:reference.verify(wire, payload, "raw")
        call(args.probe, args.output_dir, "invalid-chain", payload, {**config, "chain_depth": 17}, "InvalidBlockPlan")
        _, failed = call(args.probe, args.output_dir, "into-too-small", payload, {"format": "raw", "api": "into", "acceleration": 17, "output_capacity": 0}, "OutputTooSmall")
        require(failed["profile"]["blocks_attempted"] > 0, "failed output attempt lost its work profile")
        call(args.probe, args.output_dir, "unknown-control", payload, {"format": "raw", "unknown_control": True}, "UnknownField")
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path, action="append", required=True)
    for field in ("probe", "legacy-probe", "legacy-source"):parser.add_argument("--" + field, type=Path)
    parser.add_argument("--output-dir", type=Path, required=True);parser.add_argument("--prepare-only", action="store_true");parser.add_argument("--case", action="append")
    args = parser.parse_args();args.reference = [path.resolve() for path in args.reference]
    for field in ("probe", "legacy_probe", "legacy_source", "output_dir"):
        if getattr(args, field):setattr(args, field, getattr(args, field).resolve())
    args.output_dir.mkdir(parents=True, exist_ok=True);references = [Reference(path) for path in args.reference];cases = samples(args.output_dir)
    if args.case:require(set(args.case) <= {case["name"] for case in cases}, "unknown stage case")
    old = baseline(args, cases, references);empty = empty_baseline(args, cases);normalizations = {reference.version + ":" + str(index): reference_normalization(reference) for index, reference in enumerate(references)}
    require(args.prepare_only or args.probe, "public probe required for native campaign")
    paths = [ROOT / "build.zig", *sorted((ROOT / "src").rglob("*")), *sorted((ROOT / "tools/lz4").glob("fast_controls*"))]
    before = {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in paths if path.is_file()};rows = [] if args.prepare_only else campaign(args, cases, references, old, empty)
    after = {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in paths if path.is_file()}
    if not args.case:require(before == after, "source changed during final fast-controls campaign")
    report = {"schema": "vort-lz4-fast-controls-v1", "status": "prepared" if args.prepare_only else "ok", "utc": datetime.now(timezone.utc).isoformat(), "rows": rows,
              "baseline_rows": len(old["rows"]), "baseline_manifest_sha256": digest((args.output_dir / "fast-controls-baseline.json").read_bytes()),
              "empty_baseline_rows": len(empty["rows"]), "empty_baseline_sha256": digest((args.output_dir / "fast-empty-baseline.json").read_bytes()),
              "references": [reference.provenance() for reference in references], "reference_normalizations": normalizations, "stage_cases": args.case,
              "source_sha256": before, "source_after_sha256": after, "source_before_after_equal": before == after,
              "probe_path": str(args.probe) if args.probe else None, "probe_sha256": digest(args.probe.read_bytes()) if args.probe else None,
              "scope": "functional acceleration and independent compatible references, no native/reference byte-output, ratio or speed parity claim"}
    path = args.output_dir / "fast-controls-report.json";path.write_text(json.dumps(report, indent=2) + "\n");print(json.dumps({"status": report["status"], "rows": len(rows), "baseline_rows": len(old["rows"]), "report": str(path)}))


if __name__ == "__main__":main()
