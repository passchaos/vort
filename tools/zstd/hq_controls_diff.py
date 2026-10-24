#!/usr/bin/env python3
"""Bounded Zstd HQ interoperability with frozen legacy wires and two references."""
import argparse
import ctypes as C
from datetime import datetime, timezone
import json
from pathlib import Path
import platform
import random
import subprocess
import sys
import zlib

sys.dont_write_bytecode = True
from controls_diff import ROOT, digest, require, reference_module, reference_encode

OLD_REVISION = "f95c34467c9af2e238e8279ee6424d2d7433dfb9"
HQ_STRATEGIES = {"lazy2": 5, "btlazy2": 6, "btopt": 7, "btultra": 8, "btultra2": 9}
OLD_STRATEGIES = ("fast", "double_fast", "greedy", "lazy", "optimal", "auto")
bind = reference_module.bind


class HqControls(C.Structure):
    _fields_ = [("level", C.c_int32)] + [(name, C.c_uint32) for name in
                ("strategy", "search_log", "min_match", "target_length", "window_log", "checksum", "content_size")]


class ModernReference:
    def __init__(self, helper):
        self.path = helper.resolve()
        loader = C.CDLL("libdl.so.2")
        handle = bind(loader, "dlmopen", C.c_void_p, C.c_long, C.c_char_p, C.c_int)(-1, str(self.path).encode(), 2)
        require(handle, "isolated modern Zstd namespace")
        self.lib = C.CDLL(str(self.path), handle=handle)
        self.version = bind(self.lib, "hqr_version_string", C.c_char_p)().decode()
        self.header_version = bind(self.lib, "hqr_header_version", C.c_uint32)()
        self.runtime_version = bind(self.lib, "hqr_runtime_version", C.c_uint32)()
        require(self.header_version == self.runtime_version, "modern Zstd matching header/runtime")
        self.runtime_path = Path(bind(self.lib, "hqr_runtime_library_path", C.c_char_p)().decode()).resolve()
        require(bind(self.lib, "hqr_controls_size", C.c_size_t)() == C.sizeof(HqControls), "HQ pointer ABI")
        self.error = bind(self.lib, "ZSTD_isError", C.c_uint, C.c_size_t)
        self.error_name = bind(self.lib, "ZSTD_getErrorName", C.c_char_p, C.c_size_t)
        self.bound = bind(self.lib, "ZSTD_compressBound", C.c_size_t, C.c_size_t)
        self.encode_fn = bind(self.lib, "hqr_encode", C.c_size_t, C.POINTER(HqControls), C.c_void_p, C.c_size_t,
                              C.c_void_p, C.c_size_t, C.c_void_p, C.c_size_t)
        self.decode_fn = bind(self.lib, "hqr_decode", C.c_size_t, C.c_void_p, C.c_size_t, C.c_void_p, C.c_size_t,
                              C.c_void_p, C.c_size_t)
        self.ddict_decode_fn = bind(self.lib, "hqr_decode_ddict", C.c_size_t, C.c_void_p, C.c_size_t, C.c_void_p, C.c_size_t,
                                    C.c_void_p, C.c_size_t)
        self.train_fn = bind(self.lib, "hqr_train", C.c_size_t, C.c_void_p, C.POINTER(C.c_size_t), C.c_uint32,
                             C.c_void_p, C.c_size_t)

    def check(self, count):
        require(not self.error(count), self.error_name(count).decode())
        return count

    def encode(self, payload, strategy="auto", dictionary=b""):
        options = HqControls(3, HQ_STRATEGIES.get(strategy, 0), 6, 3, 64, 17, 1, 1)
        capacity = self.bound(len(payload))
        output = C.create_string_buffer(b"\xa5" * (capacity + 16))
        count = self.check(self.encode_fn(C.byref(options), payload, len(payload), dictionary, len(dictionary),
                                         C.byref(output, 8), capacity))
        require(output.raw[:8] == b"\xa5" * 8 and output.raw[capacity + 8:capacity + 16] == b"\xa5" * 8,
                "modern encoder output guards")
        return output.raw[8:8 + count]

    def verify(self, wire, payload, dictionary=b""):
        capacity = max(1, len(payload))
        output = C.create_string_buffer(b"\xa5" * (capacity + 16))
        decode = self.ddict_decode_fn if dictionary else self.decode_fn
        count = self.check(decode(wire, len(wire), dictionary, len(dictionary), C.byref(output, 8), capacity))
        require(count == len(payload) and output.raw[8:8 + count] == payload, "modern reference decoded bytes")
        require(output.raw[:8] == b"\xa5" * 8 and output.raw[capacity + 8:capacity + 16] == b"\xa5" * 8,
                "modern decoder output guards")

    def train(self, samples):
        sizes = (C.c_size_t * len(samples))(*map(len, samples))
        output = C.create_string_buffer(4096)
        count = self.check(self.train_fn(b"".join(samples), sizes, len(samples), output, len(output)))
        return output.raw[:count]

    def provenance(self):
        return {"version": self.version, "header_version": self.header_version, "runtime_version": self.runtime_version,
                "helper_sha256": digest(self.path.read_bytes()), "runtime_library": str(self.runtime_path),
                "runtime_library_sha256": digest(self.runtime_path.read_bytes())}


def corpus():
    rng = random.Random(0xf95c3446)
    rows = {
        "text": b"bounded high quality parsing and entropy state\n" * 90,
        "json": b'{"kind":"event","keys":[1,2,3],"status":"stable"}\n' * 90,
        "source": b"fn parse(input: []const u8) usize { return input.len; }\n" * 90,
        "binary": bytes(range(256)) * 16,
        "logs": b"2026-10-24 INFO worker=3 result=complete bytes=4096\n" * 90,
        "repetitive": b"abcabcXabcabcYaaaaaaaaZ" * 190,
        "mixed": (b"prefix source text\n" * 100) + zlib.compress(rng.randbytes(2400)),
    }
    return {name: data[:4096] for name, data in rows.items()}


def call(probe, directory, name, payload, config, expected_error=None):
    source, output, settings = [directory / (name + suffix) for suffix in (".input", ".wire", ".json")]
    source.write_bytes(payload)
    output.write_bytes(b"existing output sentinel")
    settings.write_text(json.dumps(config) + "\n")
    result = subprocess.run([str(probe), str(source), str(output), str(settings)], cwd=ROOT,
                            capture_output=True, timeout=90)
    require(result.returncode == 0, (name, result.stderr.decode(errors="replace")))
    report = json.loads(result.stdout)
    require(report["error"] == expected_error, (name, config, report))
    if expected_error:
        require(output.read_bytes() == b"existing output sentinel", "failed operation replaced existing output")
    return output.read_bytes(), report


def prepare(args, reference, secondary):
    directory = args.output_dir
    rows = []
    for family, payload in corpus().items():
        for strategy in OLD_STRATEGIES:
            config = {"strategy": strategy}
            name = "old-" + family + "-" + strategy
            wire, _ = call(args.legacy_probe, directory, name, payload, config)
            reference.verify(wire, payload)
            secondary.verify(wire, payload, b"")
            rows.append({"case": family, "config": config, "input": name + ".input", "wire": name + ".wire",
                         "input_sha256": digest(payload), "wire_sha256": digest(wire)})
        for mode in ("default", "native-default"):
            config = {"mode": mode}
            name = "old-" + family + "-" + mode
            wire, _ = call(args.legacy_probe, directory, name, payload, config)
            reference.verify(wire, payload)
            secondary.verify(wire, payload, b"")
            rows.append({"case": family, "config": config, "input": name + ".input", "wire": name + ".wire",
                         "input_sha256": digest(payload), "wire_sha256": digest(wire)})
    source_paths = sorted((args.legacy_source / "src").rglob("*.zig"))
    baseline = {"schema": "vort-zstd-hq-old-wire-v1", "revision": OLD_REVISION,
                "probe_sha256": digest(args.legacy_probe.read_bytes()),
                "probe_source_sha256": digest((ROOT / "tools/zstd/hq_controls_probe.zig").read_bytes()),
                "source_sha256": {str(path.relative_to(args.legacy_source)): digest(path.read_bytes()) for path in source_paths},
                "rows": rows}
    (directory / "baseline.json").write_text(json.dumps(baseline, indent=2) + "\n")
    return baseline


def prepare_dictionary_fixtures(args):
    source = args.dictionary_fixtures
    if source is None and args.legacy_source:
        candidate = args.legacy_source / "dictionary-fixtures.json"
        if candidate.exists():
            source = candidate
    if source is None:
        return
    manifest = json.loads(source.read_text())
    dictionary = Path(manifest["dictionary_path"]).read_bytes()
    require(digest(dictionary) == manifest["dictionary_sha256"], "full dictionary fixture hash")
    dictionary_name = "fixture-full-dictionary.bin"
    (args.output_dir / dictionary_name).write_bytes(dictionary)
    copied = {**manifest, "dictionary_path": dictionary_name, "source_manifest_sha256": digest(source.read_bytes()),
              "scope": "original valid dictionary fixture; OF2 high-frequency pricing is a separate unit math model, not a changed header",
              "cases": {}}
    for name, row in manifest["cases"].items():
        payload = Path(row["path"]).read_bytes()
        require(digest(payload) == row["sha256"] and len(payload) == row["size"], "dictionary plaintext fixture hash")
        payload_name = "fixture-" + name + ".input"
        (args.output_dir / payload_name).write_bytes(payload)
        copied["cases"][name] = {**row, "path": payload_name}
    (args.output_dir / "hq-dictionary-fixtures.json").write_text(json.dumps(copied, indent=2) + "\n")


def campaign(args, reference, secondary, baseline):
    rows = []
    for index, row in enumerate(baseline["rows"]):
        payload = (args.output_dir / row["input"]).read_bytes()
        expected = (args.output_dir / row["wire"]).read_bytes()
        require(digest(payload) == row["input_sha256"] and digest(expected) == row["wire_sha256"], "old golden hash")
        wire, _ = call(args.probe, args.output_dir, "baseline-" + str(index), payload, row["config"])
        require(wire == expected, ("old strategy/default wire changed", row["case"], row["config"]))
    for strategy in HQ_STRATEGIES:
        for family, payload in corpus().items():
            config = {"strategy": strategy, "search_depth": 64, "nice_len": 64, "min_match": 3,
                      "checksum": True, "mode": "native"}
            wire, profile = call(args.probe, args.output_dir, strategy + "-" + family, payload, config)
            require(profile["resolved"]["strategy"] == strategy, "HQ strategy resolution")
            require(profile["profile"]["hq_used"], "HQ dispatch profile")
            if strategy == "btultra2":
                require(profile["profile"]["hq_passes"] >= 2 and profile["profile"]["refinement_passes"] >= 1,
                        "cold plain btultra2 did not execute both passes")
            reference.verify(wire, payload)
            secondary.verify(wire, payload, b"")
            for label, ref_wire in (("modern", reference.encode(payload, strategy)),
                                    ("system", reference_encode(secondary, payload, strategy=HQ_STRATEGIES[strategy]))):
                decoded, _ = call(args.probe, args.output_dir, strategy + "-" + family + "-" + label,
                                  ref_wire, {"operation": "decode"})
                require(decoded == payload, "Vort decoded independent HQ reference")
            unprofiled, _ = call(args.probe, args.output_dir, strategy + "-" + family + "-unprofiled", payload,
                                  {**config, "profile_enabled": False})
            require(unprofiled == wire, "HQ profile changed output wire")
            rows.append({"case": family, "strategy": strategy, "input_bytes": len(payload), "wire_bytes": len(wire),
                         "wire_sha256": digest(wire), "probe": profile})
    payload = (b"LL0 repeated offset transitions abcabcXabcabcY\n" * 2200)[:98304]
    for strategy in HQ_STRATEGIES:
        config = {"strategy": strategy, "mode": "native", "block_size": 65536,
                  "search_depth": 64, "nice_len": 64, "min_match": 3, "checksum": True,
                  "input_chunk": 4093, "output_chunk": 8191}
        one, _ = call(args.probe, args.output_dir, strategy + "-wide", payload, config)
        for api in ("incremental", "seekable"):
            wire, stats = call(args.probe, args.output_dir, strategy + "-" + api, payload,
                                {**config, "api": api, "frame_size": 40000})
            if api == "incremental":
                require(wire == one, "HQ one-shot/incremental wire differs")
            reference.verify(wire, payload)
            secondary.verify(wire, payload, b"")
            decoded, _ = call(args.probe, args.output_dir, strategy + "-" + api + "-decode", wire,
                              {"operation": "decode", "api": api})
            require(decoded == payload, "HQ wide/seekable public decode")
            rows.append({"case": "wide", "strategy": strategy, "api": api, "probe": stats})
    samples = [data + bytes([index]) * 20 for index in range(12) for data in corpus().values()]
    raw_dictionary = corpus()["text"]
    full_dictionary = reference.train(samples)
    for kind, dictionary in (("raw", raw_dictionary), ("standard", full_dictionary)):
        path = args.output_dir / (kind + ".dictionary")
        path.write_bytes(dictionary)
        payload = raw_dictionary[-2048:] + b"abcabcXabcabcY" * 100
        config = {"strategy": "btultra2", "mode": "native", "search_depth": 64, "nice_len": 64,
                  "dictionary_path": str(path), "full_dictionary": kind == "standard", "checksum": True}
        wire, stats = call(args.probe, args.output_dir, kind + "-dictionary", payload, config)
        require(stats["profile"]["dictionary_sequences"] > 0, "dictionary case emitted no dictionary reference")
        require(stats["profile"]["hq_passes"] == 1 and stats["profile"]["refinement_passes"] == 0,
                "dictionary btultra2 must report its actual single-pass dispatch")
        reference.verify(wire, payload, dictionary)
        secondary.verify(wire, payload, dictionary)
        decoded, _ = call(args.probe, args.output_dir, kind + "-dictionary-reference", reference.encode(payload, "btultra2", dictionary),
                          {**config, "operation": "decode"})
        require(decoded == payload, "HQ dictionary reference decode")
        rows.append({"case": kind + "-dictionary", "dictionary_sha256": digest(dictionary), "probe": stats})
    fixture_path = args.output_dir / "hq-dictionary-fixtures.json"
    if fixture_path.exists():
        fixtures = json.loads(fixture_path.read_text())
        dictionary_path = args.output_dir / fixtures["dictionary_path"]
        dictionary = dictionary_path.read_bytes()
        require(digest(dictionary) == fixtures["dictionary_sha256"], "original full entropy dictionary bytes")
        for strategy in ("btopt", "btultra2"):
            for name, row in fixtures["cases"].items():
                payload = (args.output_dir / row["path"]).read_bytes()
                require(digest(payload) == row["sha256"], "LL dictionary fixture bytes")
                config = {"strategy": strategy, "mode": "native", "window_log": 17, "content_size": False,
                          "checksum": True, "search_depth": 64, "nice_len": 128, "min_match": 3,
                          "dictionary_path": str(dictionary_path), "full_dictionary": True}
                wire, stats = call(args.probe, args.output_dir, "full-fixture-" + strategy + "-" + name, payload, config)
                reference.verify(wire, payload, dictionary)
                secondary.verify(wire, payload, dictionary)
                decoded, _ = call(args.probe, args.output_dir, "full-fixture-reference-" + strategy + "-" + name,
                                  reference.encode(payload, strategy, dictionary), {**config, "operation": "decode"})
                require(decoded == payload, "full entropy DDict fixture reference bytes")
                require(stats["profile"]["hq_passes"] == 1 and stats["profile"]["refinement_passes"] == 0,
                        "full entropy dictionary fixture single pass")
                rows.append({"case": "full-fixture-" + name, "strategy": strategy, "probe": stats,
                             "dictionary_sha256": digest(dictionary), "reference_decoder": "ZSTD_decompress_usingDDict",
                             "scope": "original dictionary and wire decode; exact offset price selection covered separately by unit QA"})
    dictionary = random.Random(0x741ad069).randbytes(1024) + b"\xff" * (96 * 1024 - 1024)
    payload = dictionary[16:528]
    dictionary_path = args.output_dir / "far-raw.dictionary"
    dictionary_path.write_bytes(dictionary)
    config = {"strategy": "btopt", "mode": "native", "window_log": 17, "content_size": False, "search_depth": 64,
              "nice_len": 128, "dictionary_path": str(dictionary_path), "checksum": True}
    wire, stats = call(args.probe, args.output_dir, "far-raw-dictionary", payload, config)
    require(stats["profile"]["dictionary_sequences"] > 0 and stats["profile"]["max_distance"] > 65535,
            "far raw dictionary was not actually referenced")
    reference.verify(wire, payload, dictionary)
    secondary.verify(wire, payload, dictionary)
    decoded, _ = call(args.probe, args.output_dir, "far-raw-reference", reference.encode(payload, "btopt", dictionary),
                      {**config, "operation": "decode"})
    require(decoded == payload, "far raw reference dictionary bytes")
    rows.append({"case": "far-raw-dictionary", "dictionary_sha256": digest(dictionary), "probe": stats,
                 "reference_decoder": "ZSTD_decompress_usingDDict"})
    frame = reference.encode(b"first frame", "lazy2") + reference.encode(b"second frame", "btultra2")
    decoded, _ = call(args.probe, args.output_dir, "concatenated", frame, {"operation": "decode", "api": "concatenated"})
    require(decoded == b"first framesecond frame", "concatenated reference frames")
    for level in (-1, 0):
        call(args.probe, args.output_dir, "invalid-level-" + str(level), b"invalid", {"level": level, "strategy": "btopt"}, "InvalidBlockPlan")
    for name, control in (("depth", {"search_depth": 0}), ("nice", {"nice_len": 2}), ("min", {"min_match": 8})):
        call(args.probe, args.output_dir, "invalid-" + name, b"invalid", {"strategy": "btopt", **control}, "InvalidBlockPlan")
    resource_payload = corpus()["text"]
    config = {"strategy": "btopt", "mode": "native", "search_depth": 64, "nice_len": 64}
    wire, stats = call(args.probe, args.output_dir, "memory-measure", resource_payload, config)
    peak = stats["profile"]["peak_working_memory"]
    require(peak > 0, "HQ working memory profile")
    exact, _ = call(args.probe, args.output_dir, "memory-exact", resource_payload, {**config, "max_working_memory": peak})
    require(exact == wire, "exact HQ memory budget changed wire")
    call(args.probe, args.output_dir, "memory-below", resource_payload, {**config, "max_working_memory": peak - 1},
         "WorkingMemoryLimitExceeded")
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--probe", type=Path)
    parser.add_argument("--legacy-probe", type=Path)
    parser.add_argument("--legacy-source", type=Path)
    parser.add_argument("--dictionary-fixtures", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    args.output_dir = args.output_dir.resolve()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for field in ("reference", "probe", "legacy_probe", "legacy_source", "dictionary_fixtures"):
        if getattr(args, field):
            setattr(args, field, getattr(args, field).resolve())
    reference = ModernReference(args.reference)
    secondary = reference_module.Zstd()
    prepare_dictionary_fixtures(args)
    secondary_paths = {Path(line.split()[-1]).resolve() for line in Path("/proc/self/maps").read_text().splitlines()
                       if "libzstd.so" in line and line.split()[-1].startswith("/")}
    secondary_paths.discard(reference.runtime_path)
    require(len(secondary_paths) == 1, "actual system Zstd library path")
    secondary_path = secondary_paths.pop()
    compiler = subprocess.run(["cc", "--version"], capture_output=True, text=True, check=True).stdout.splitlines()[0]
    reference_checkout = Path("/home/passchaos/Work/zstd")
    git_version = subprocess.run(["git", "-C", str(reference_checkout), "rev-parse", "HEAD"], capture_output=True, text=True)
    baseline_path = args.output_dir / "baseline.json"
    if baseline_path.exists():
        baseline = json.loads(baseline_path.read_text())
        require(baseline["revision"] == OLD_REVISION, "frozen baseline revision")
    else:
        require(args.legacy_probe and args.legacy_source, "legacy probe/source needed only for initial freeze")
        baseline = prepare(args, reference, secondary)
    require(args.prepare_only or args.probe, "--probe required for HQ campaign")
    sources = [ROOT / "src/root.zig", ROOT / "src/zstd.zig", ROOT / "src/core.zig", ROOT / "build.zig",
               *sorted((ROOT / "src/zstd").rglob("*.zig")), *sorted((ROOT / "tools/zstd").glob("hq_controls*"))]
    before = {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in sources if path.is_file()}
    rows = [] if args.prepare_only else campaign(args, reference, secondary, baseline)
    after = {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in sources if path.is_file()}
    require(before == after, "HQ source changed during campaign")
    cpu = next((line.split(":", 1)[1].strip() for line in Path("/proc/cpuinfo").read_text().splitlines()
                if line.startswith("model name")), platform.machine())
    report = {"schema": "vort-zstd-hq-controls-v1", "utc": datetime.now(timezone.utc).isoformat(),
              "status": "prepared" if args.prepare_only else "ok", "reference": reference.provenance(),
              "secondary_version": secondary.version, "secondary_runtime_library": str(secondary_path),
              "secondary_runtime_library_sha256": digest(secondary_path.read_bytes()),
              "reference_source_revision": git_version.stdout.strip() if git_version.returncode == 0 else None,
              "helper_compiler": compiler, "helper_build_mode": "O2 PIC shared C wrapper",
              "runtime_library_build_mode": "existing native library; build flags not independently reconstructed",
              "cpu": cpu, "machine": platform.machine(),
              "probe_sha256": digest(args.probe.read_bytes()) if args.probe else None,
              "probe_path": str(args.probe) if args.probe else None,
              "baseline_manifest_sha256": digest(baseline_path.read_bytes()), "baseline_rows": len(baseline["rows"]),
              "dictionary_fixture_manifest_sha256": digest((args.output_dir / "hq-dictionary-fixtures.json").read_bytes())
              if (args.output_dir / "hq-dictionary-fixtures.json").exists() else None,
              "source_sha256": before, "source_after_sha256": after, "rows": rows,
              "scope": "functional interoperability; work counters do not rank match quality or throughput"}
    path = args.output_dir / "report.json"
    path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "rows": len(rows), "baseline_rows": report["baseline_rows"], "report": str(path)}))


if __name__ == "__main__":
    main()
