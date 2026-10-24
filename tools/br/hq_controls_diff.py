#!/usr/bin/env python3
"""Bounded Brotli HQ interoperability with versioned, attached-dictionary references."""
import argparse
import ctypes as C
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import random
import subprocess
import sys
import zlib

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
OLD_REVISION = "a2cfc30b3b1a778e05675eb90217bd7ead1d981c"
REFERENCE_SOURCE = "558fc647cdaf391228d614ca85f711e02e4e583b"


def require(value, detail):
    if not value:
        raise AssertionError(detail)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def bind(library, name, result, *arguments):
    function = getattr(library, name)
    function.restype, function.argtypes = result, list(arguments)
    return function


class Controls(C.Structure):
    _fields_ = [(name, C.c_uint32) for name in ("quality", "mode", "window_bits", "npostfix", "ndirect_high", "lgblock")]


class Dictionary(C.Structure):
    _fields_ = [("type", C.c_uint32), ("data", C.c_void_p), ("size", C.c_size_t)]


class Reference:
    def __init__(self, helper):
        self.path = helper.resolve()
        loader = C.CDLL("libdl.so.2")
        handle = bind(loader, "dlmopen", C.c_void_p, C.c_long, C.c_char_p, C.c_int)(-1, str(self.path).encode(), 2)
        require(handle, "independent reference loader namespace")
        self.library = C.CDLL(str(self.path), handle=handle)
        self.header_version = bind(self.library, "bhqr_header_version", C.c_uint32)()
        self.encoder_version = bind(self.library, "bhqr_encoder_version", C.c_uint32)()
        self.decoder_version = bind(self.library, "bhqr_decoder_version", C.c_uint32)()
        require(self.encoder_version == self.decoder_version, "matching Brotli encoder and decoder runtime")
        if self.header_version:
            require(self.header_version == self.encoder_version, "matching modern Brotli headers and runtime")
        self.raw_dictionaries = bool(bind(self.library, "bhqr_dictionary_api", C.c_uint32)())
        require(bind(self.library, "bhqr_controls_size", C.c_size_t)() == C.sizeof(Controls), "Brotli controls pointer ABI")
        require(bind(self.library, "bhqr_dictionary_size", C.c_size_t)() == C.sizeof(Dictionary), "Brotli dictionary pointer ABI")
        path = bind(self.library, "bhqr_library_path", C.c_char_p, C.c_uint32)
        self.paths = {kind: Path(path(index).decode()).resolve() for index, kind in enumerate(("encoder", "decoder", "common"))}
        self.encode_fn = bind(self.library, "bhqr_encode", C.c_int, C.POINTER(Controls), C.POINTER(Dictionary), C.c_size_t,
                              C.c_void_p, C.c_size_t, C.c_void_p, C.c_size_t, C.POINTER(C.c_size_t), C.POINTER(C.c_size_t))
        self.decode_fn = bind(self.library, "bhqr_decode", C.c_int, C.POINTER(Dictionary), C.c_size_t,
                              C.c_void_p, C.c_size_t, C.c_void_p, C.c_size_t, C.POINTER(C.c_size_t), C.POINTER(C.c_size_t), C.POINTER(C.c_int))
        self.word_fn = bind(self.library, "bhqr_builtin_word", C.c_int, C.c_uint32, C.c_uint32, C.c_uint32,
                            C.c_void_p, C.c_size_t, C.POINTER(C.c_size_t))

    def dictionaries(self, data):
        storage = [C.create_string_buffer(payload) for type, payload in data]
        descriptors = (Dictionary * len(data))(*[Dictionary(type, C.cast(buffer, C.c_void_p), len(payload))
                                                for (type, payload), buffer in zip(data, storage)])
        return storage, descriptors

    def supports(self, dictionaries):
        if dictionaries and not self.raw_dictionaries:
            return "system Brotli 1.0.9 does not provide the prepared-encoder / attach-decoder shared dictionary API"
        if any(type == 1 for type, data in dictionaries):
            return "Brotli 1.2.0 public SERIALIZED type documents that attachment methods fail; no dictionary bytes or headers are removed"
        return None

    def encode(self, payload, config, dictionaries=()):
        require(self.supports(dictionaries) is None, self.supports(dictionaries))
        storage, descriptors = self.dictionaries(dictionaries)
        options = Controls(config.get("quality", 10), {"generic": 0, "text": 1, "font": 2}[config.get("mode", "generic")],
                           config.get("window_bits", 18), config.get("npostfix", 0), config.get("ndirect_high", 0), config.get("lgblock", 0))
        capacity = len(payload) * 2 + 16384
        output = C.create_string_buffer(b"\xa5" * (capacity + 16))
        consumed, written = C.c_size_t(), C.c_size_t()
        status = self.encode_fn(C.byref(options), descriptors, len(dictionaries), payload, len(payload), C.byref(output, 8),
                                capacity, C.byref(consumed), C.byref(written))
        require(status == 0 and consumed.value == len(payload), ("reference encode", status, consumed.value, config))
        require(output.raw[:8] == b"\xa5" * 8 and output.raw[capacity + 8:capacity + 16] == b"\xa5" * 8, "reference encode guards")
        return output.raw[8:8 + written.value]

    def verify(self, wire, payload, dictionaries=()):
        require(self.supports(dictionaries) is None, self.supports(dictionaries))
        storage, descriptors = self.dictionaries(dictionaries)
        capacity = len(payload) + 1
        output = C.create_string_buffer(b"\xa5" * (capacity + 16))
        consumed, written, error = C.c_size_t(), C.c_size_t(), C.c_int()
        status = self.decode_fn(descriptors, len(dictionaries), wire, len(wire), C.byref(output, 8), capacity,
                                C.byref(consumed), C.byref(written), C.byref(error))
        require(status == 0 and consumed.value == len(wire) and written.value == len(payload)
                and output.raw[8:8 + written.value] == payload, ("reference decode", status, error.value, consumed.value, written.value))
        require(output.raw[:8] == b"\xa5" * 8 and output.raw[8 + len(payload):capacity + 16] == b"\xa5" * 9, "reference decoder guards")

    def word(self, length, index, transform):
        output = C.create_string_buffer(256)
        written = C.c_size_t()
        require(self.word_fn(length, index, transform, output, len(output), C.byref(written)) == 0, "matching-header static word fixture")
        return output.raw[:written.value]

    def provenance(self):
        paths = self.paths
        return {"header_version": hex(self.header_version) if self.header_version else None,
                "header_version_note": "matching source common/version.h" if self.header_version else "system public headers expose no package-version macro",
                "encoder_version": hex(self.encoder_version), "decoder_version": hex(self.decoder_version),
                "helper_sha256": digest(self.path.read_bytes()), "libraries": {kind: {"path": str(path), "sha256": digest(path.read_bytes())} for kind, path in paths.items()},
                "raw_dictionary_api": self.raw_dictionaries, "serialized_dictionary_public_api": False,
                "header_source_revision": REFERENCE_SOURCE if self.raw_dictionaries else None,
                "existing_runtime_source_revision": "not independently reconstructed"}


def corpus():
    rng = random.Random(0xa2cfc30b)
    return {name: data[:2048] for name, data in {
        "text": b"explicit high quality Brotli parsing and entropy state\n" * 60,
        "json": b'{"version":1,"items":[1,2,3],"state":"stable"}\n' * 60,
        "source": b"fn encode(input: []const u8) usize { return input.len; }\n" * 60,
        "binary": bytes(range(256)) * 8,
        "logs": b"2026-10-24 INFO request=7 status=success bytes=2048\n" * 60,
        "repetitive": b"abcabcXabcabcYaaaaaaZ" * 150,
        "mixed": b"source prefix\n" * 80 + zlib.compress(rng.randbytes(1024)),
    }.items()}


def probe_call(probe, directory, name, payload, config, expected_error=None):
    source, output, settings = [directory / (name + suffix) for suffix in (".input", ".wire", ".json")]
    source.write_bytes(payload)
    output.write_bytes(b"existing output sentinel")
    settings.write_text(json.dumps(config) + "\n")
    result = subprocess.run([str(probe), str(source), str(output), str(settings)], cwd=ROOT, capture_output=True, timeout=120)
    require(result.returncode == 0, (name, result.stderr.decode(errors="replace")))
    report = json.loads(result.stdout)
    require(report["error"] == expected_error, (name, config, report))
    if expected_error:
        require(output.read_bytes() == b"existing output sentinel", "failed operation changed output")
    return output.read_bytes(), report


def freeze_baseline(args, references):
    configurations = [{"level": level} for level in ("fast", "balanced", "ratio")]
    configurations += [{"quality": 10}, {"quality": 11},
                       {"quality": 10, "api": "chunks", "block_len": 512},
                       {"quality": 11, "api": "incremental", "block_len": 512}]
    rows = []
    for family, payload in corpus().items():
        for index, config in enumerate(configurations):
            name = "legacy-" + family + "-" + str(index)
            wire, _ = probe_call(args.legacy_probe, args.output_dir, name, payload, config)
            for reference in references:
                reference.verify(wire, payload)
            rows.append({"case": family, "config": config, "input": name + ".input", "wire": name + ".wire",
                         "input_sha256": digest(payload), "wire_sha256": digest(wire)})
    files = sorted((args.legacy_source / "src").rglob("*.zig"))
    manifest = {"schema": "vort-br-hq-null-wire-v1", "revision": OLD_REVISION, "rows": rows,
                "probe_sha256": digest(args.legacy_probe.read_bytes()), "probe_source_sha256": digest((ROOT / "tools/br/hq_controls_probe.zig").read_bytes()),
                "source_sha256": {str(path.relative_to(args.legacy_source)): digest(path.read_bytes()) for path in files}}
    (args.output_dir / "baseline.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def first_metablock(wire):
    bit = 0
    def take(count):
        nonlocal bit
        require(bit + count <= len(wire) * 8, "truncated Brotli envelope")
        value = sum(((wire[(bit + index) // 8] >> ((bit + index) % 8)) & 1) << index for index in range(count))
        bit += count
        return value
    if take(1) == 0:
        window = 16
    else:
        upper = take(3)
        if upper:
            window = 17 + upper
        else:
            lower = take(3)
            require(lower != 1, "reserved / large-window Brotli code")
            window = 17 if lower == 0 else 8 + lower
    last = bool(take(1))
    if last and take(1):
        return {"window_bits": window, "kind": "empty", "output_bytes": 0}
    nibbles = take(2) + 4
    if nibbles == 7:
        return {"window_bits": window, "kind": "metadata"}
    size = take(nibbles * 4) + 1
    stored = not last and bool(take(1))
    return {"window_bits": window, "kind": "stored" if stored else "compressed", "output_bytes": size}


def checked_case(args, references, rows, name, payload, config, dictionaries=()):
    wire, stats = probe_call(args.probe, args.output_dir, name, payload, config)
    require(stats["profile"]["effective"] is not None and stats["profile"]["passes"] > 0, "explicit HQ did not execute its parser")
    parsed = first_metablock(wire)
    require(parsed["window_bits"] == config["window_bits"] and stats["resolved"]["window_bits"] == parsed["window_bits"], "actual standard window header")
    directions = []
    for label, reference in references.items():
        skipped = reference.supports(dictionaries)
        if skipped:
            directions.append({"reference": label, "status": "skipped", "reason": skipped})
            continue
        reference.verify(wire, payload, dictionaries)
        independent = reference.encode(payload, config, dictionaries)
        decoded, _ = probe_call(args.probe, args.output_dir, name + "-" + label + "-decode", independent,
                                {**config, "operation": "decode"})
        require(decoded == payload, "Vort decoded versioned reference bytes")
        directions.append({"reference": label, "status": "ok", "direction": "bidirectional", "dictionary_attached": bool(dictionaries)})
    off, off_stats = probe_call(args.probe, args.output_dir, name + "-profile-off", payload, {**config, "profile_enabled": False})
    require(off == wire and off_stats["resolved"] == stats["resolved"], "profile changed wire or actual resolved options")
    row = {"case": name, "input_bytes": len(payload), "wire_bytes": len(wire), "wire_sha256": digest(wire),
           "config": config, "envelope": parsed, "probe": stats, "reference_results": directions}
    rows.append(row)
    return wire, stats


def campaign(args, references, baseline):
    rows = []
    for index, row in enumerate(baseline["rows"]):
        payload, expected = [(args.output_dir / row[key]).read_bytes() for key in ("input", "wire")]
        require(digest(payload) == row["input_sha256"] and digest(expected) == row["wire_sha256"], "frozen legacy input / wire hash")
        wire, _ = probe_call(args.probe, args.output_dir, "null-baseline-" + str(index), payload, row["config"])
        require(wire == expected, ("null HQ wire changed", row["case"], row["config"]))
    base = {"hq": True, "search_depth": 32, "nice_len": 64, "beam_width": 4, "iterations": 1, "window_bits": 18}
    for quality in (10, 11):
        checked_case(args, references, rows, "default-hq-q" + str(quality), corpus()["text"][:512],
                     {"hq": True, "quality": quality, "window_bits": 18})
        for family, payload in corpus().items():
            checked_case(args, references, rows, "q" + str(quality) + "-" + family, payload, {**base, "quality": quality})
        for window in range(10, 25):
            checked_case(args, references, rows, "window-q" + str(quality) + "-" + str(window), corpus()["text"][:384],
                         {**base, "quality": quality, "window_bits": window})
    shapes = {(npostfix, 15) for npostfix in range(4)} | {(3, high) for high in range(16)} | {(0, 0), (1, 6)}
    for npostfix, high in sorted(shapes):
        _, stats = checked_case(args, references, rows, "distance-" + str(npostfix) + "-" + str(high), corpus()["repetitive"][:512],
                                 {**base, "quality": 11, "npostfix": npostfix, "ndirect_high": high})
        require(stats["resolved"]["npostfix"] == npostfix and stats["resolved"]["ndirect_high"] == high, "resolved distance parameters")
    modern = references["modern"]
    word_rows = [{"base_length": 4, "index": 0, "transform": transform, "output": modern.word(4, 0, transform)}
                 for transform in (0, 1, 9, 44, 120)]
    payload = b"|".join(row["output"] for row in word_rows)
    _, stats = checked_case(args, references, rows, "word-transformed-lengths", payload, {**base, "quality": 11, "window_bits": 16})
    require(stats["profile"]["emitted_static_commands"] > 0, "word fixture emitted no actual static dictionary command")
    rows[-1]["word_oracle"] = [{key: value for key, value in row.items() if key != "output"} | {"output_length": len(row["output"]), "output_sha256": digest(row["output"])} for row in word_rows]
    prefix = random.Random(0x747de31).randbytes(512)
    wide = prefix + b"z" * 66000 + prefix
    for api in ("one_shot", "chunks", "incremental"):
        wire, stats = checked_case(args, references, rows, "wide-" + api, wide,
                                   {**base, "quality": 10, "api": api, "block_len": 32768, "input_chunk": 4093, "output_chunk": 8191})
        require(stats["profile"]["emitted_max_distance"] > 65535, "wide source history was not actually referenced")
        if api == "one_shot":
            first = wire
        else:
            require(wire == first, "equivalent HQ block settings changed across public APIs")
    for name, prefixes, payload in (
        ("raw-prefix", [corpus()["text"]], corpus()["text"][-192:] + b"!"),
        ("compound-cross-chunk", [b"first-prefix-0123456789abcdef", b"second-prefix-ghijklmnopqrst"], b"0123456789abcdefsecond-prefix-ghi!"),
    ):
        paths = []
        for index, prefix in enumerate(prefixes):
            path = args.output_dir / (name + "-" + str(index) + ".dictionary")
            path.write_bytes(prefix)
            paths.append(str(path))
        _, stats = checked_case(args, references, rows, name, payload, {**base, "quality": 11, "raw_dictionary_paths": paths},
                                 [(0, data) for data in prefixes])
        require(stats["profile"]["emitted_compound_commands"] > 0, "RAW shared prefix was not actually used")
    payload = random.Random(0x53544f52).randbytes(4096)
    _, _ = checked_case(args, references, rows, "stored-fallback", payload, {**base, "quality": 11})
    require(rows[-1]["envelope"]["kind"] == "stored", "random fallback did not publish a stored meta-block")
    config = {**base, "quality": 10}
    wire, stats = probe_call(args.probe, args.output_dir, "memory-measure", corpus()["text"], config)
    peak = stats["profile"]["peak_working_memory"]
    require(peak > 0, "HQ working-memory profile")
    exact, _ = probe_call(args.probe, args.output_dir, "memory-exact", corpus()["text"], {**config, "max_working_memory": peak})
    require(exact == wire, "exact memory limit changed output")
    probe_call(args.probe, args.output_dir, "memory-below", corpus()["text"], {**config, "max_working_memory": peak - 1}, "WorkingMemoryLimitExceeded")
    for name, overrides in (("quality", {"quality": 9}), ("window", {"window_bits": 25}), ("depth", {"search_depth": 0}),
                            ("nice", {"nice_len": 1}), ("beam", {"beam_width": 33}), ("iterations", {"iterations": 9}),
                            ("postfix", {"npostfix": 4}), ("direct", {"ndirect_high": 16})):
        probe_call(args.probe, args.output_dir, "invalid-" + name, b"invalid", {**config, **overrides}, "InvalidBlockPlan")
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--system-reference", type=Path, required=True)
    parser.add_argument("--probe", type=Path)
    parser.add_argument("--legacy-probe", type=Path)
    parser.add_argument("--legacy-source", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    args.output_dir = args.output_dir.resolve()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for name in ("reference", "system_reference", "probe", "legacy_probe", "legacy_source"):
        if getattr(args, name): setattr(args, name, getattr(args, name).resolve())
    modern, system = Reference(args.reference), Reference(args.system_reference)
    require(modern.encoder_version == 0x1002000 and system.encoder_version == 0x1000009, "declared 1.2.0 and 1.0.9 reference layers")
    manifest_path = args.output_dir / "baseline.json"
    if manifest_path.exists():
        baseline = json.loads(manifest_path.read_text())
        require(baseline["revision"] == OLD_REVISION, "legacy null wire revision")
    else:
        require(args.legacy_probe and args.legacy_source, "legacy probe/source required only for initial wire freeze")
        baseline = freeze_baseline(args, (modern, system))
    require(args.prepare_only or args.probe, "--probe is required for the HQ campaign")
    paths = [ROOT / "src/root.zig", ROOT / "src/br.zig", ROOT / "src/core.zig", ROOT / "build.zig",
             ROOT / "src/bitstream.zig", ROOT / "src/huffman.zig", ROOT / "src/lz77.zig",
             *sorted((ROOT / "src/br").rglob("*.zig")), *sorted((ROOT / "tools/br").glob("hq_controls*"))]
    before = {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in paths if path.is_file()}
    rows = [] if args.prepare_only else campaign(args, {"modern": modern, "system": system}, baseline)
    after = {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in paths if path.is_file()}
    require(before == after, "Brotli HQ source changed during campaign")
    compiler = subprocess.run(["cc", "--version"], capture_output=True, text=True, check=True).stdout.splitlines()[0]
    cpu = next((line.split(":", 1)[1].strip() for line in Path("/proc/cpuinfo").read_text().splitlines() if line.startswith("model name")), platform.machine())
    report = {"schema": "vort-br-hq-controls-v1", "status": "prepared" if args.prepare_only else "ok", "utc": datetime.now(timezone.utc).isoformat(),
              "references": {"modern": modern.provenance(), "system": system.provenance()},
              "baseline_rows": len(baseline["rows"]), "baseline_manifest_sha256": digest(manifest_path.read_bytes()),
              "probe_path": str(args.probe) if args.probe else None, "probe_sha256": digest(args.probe.read_bytes()) if args.probe else None,
              "source_sha256": before, "source_after_sha256": after, "rows": rows, "cpu": cpu,
              "helper_compiler": compiler, "helper_build_mode": "O2 PIC shared C wrapper", "existing_library_build_flags": "not independently reconstructed",
              "scope": "functional wire interoperability; parameters and work counters do not establish ratio or throughput parity"}
    (args.output_dir / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "baseline_rows": report["baseline_rows"], "report": str(args.output_dir / "report.json")}))


if __name__ == "__main__":
    main()
