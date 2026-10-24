#!/usr/bin/env python3
"""Frozen default wires and independent LZMA/XZ encoder-control differentials."""
import argparse
import ctypes as C
from datetime import datetime, timezone
import hashlib
import json
import platform
from pathlib import Path
import random
import struct
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
OLD_REVISION = "c3521442fcc6406287d9e31d2470746f3d9c1b9a"
FORMATS = {"raw1": 0, "raw2": 1, "micro": 2, "alone": 3, "xz": 4}
FINDERS = {"hc3": 3, "hc4": 4, "bt2": 0x12, "bt3": 0x13, "bt4": 0x14}


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def run(*args):
    result = subprocess.run([str(arg) for arg in args], cwd=ROOT, capture_output=True)
    if result.returncode:
        raise RuntimeError(f"command failed: {' '.join(map(str, args))}\n{result.stderr.decode(errors='replace')}")
    return result


def bind(library, name, result, *arguments):
    function = getattr(library, name)
    function.restype, function.argtypes = result, list(arguments)
    return function


class Controls(C.Structure):
    _fields_ = [(name, C.c_uint32) for name in ("dictionary_size", "lc", "lp", "pb", "mode", "finder", "nice_len", "depth")]


class Reference:
    def __init__(self, helper):
        self.path = helper.resolve()
        # argparse may import shutil/lzma, loading the system SONAME first.
        # A separate loader namespace keeps the declared modern library exact.
        loader = C.CDLL("libdl.so.2")
        opened = bind(loader, "dlmopen", C.c_void_p, C.c_long, C.c_char_p, C.c_int)(-1, str(self.path).encode(), 2)
        require(opened, "isolated modern reference library namespace")
        self.lib = C.CDLL(str(self.path), handle=opened)
        self.version = bind(self.lib, "ecr_version_string", C.c_char_p)().decode()
        self.header_version = bind(self.lib, "ecr_header_version", C.c_uint32)()
        self.runtime_version = bind(self.lib, "ecr_runtime_version", C.c_uint32)()
        require(self.header_version == self.runtime_version, "reference header and runtime versions match")
        require(bind(self.lib, "ecr_controls_size", C.c_size_t)() == C.sizeof(Controls), "reference pointer ABI size")
        self.preset = bind(self.lib, "ecr_preset", C.c_int, C.c_uint32, C.c_uint32, C.POINTER(Controls))
        self.encode_fn = bind(self.lib, "ecr_encode", C.c_int, C.c_uint32, C.POINTER(Controls), C.c_uint32, C.c_uint32,
                              C.c_uint32, C.c_void_p, C.c_size_t, C.c_void_p, C.c_size_t, C.POINTER(C.c_size_t))
        self.decode_fn = bind(self.lib, "ecr_decode", C.c_int, C.c_uint32, C.POINTER(Controls), C.c_void_p, C.c_size_t,
                              C.c_void_p, C.c_size_t, C.POINTER(C.c_size_t), C.POINTER(C.c_size_t))

    def options(self, config):
        options = Controls()
        require(self.preset(config.get("preset", 6), config.get("extreme", False), C.byref(options)) == 0, "reference preset")
        for name in ("dictionary_size", "lc", "lp", "pb", "nice_len", "depth"):
            if name in config:
                setattr(options, name, config[name])
        if "mode" in config:
            options.mode = 1 if config["mode"] == "fast" else 2
        if "finder" in config:
            options.finder = FINDERS[config["finder"]]
        return options

    def preset_table(self):
        rows = []
        for extreme in (False, True):
            for level in range(10):
                options = Controls()
                require(self.preset(level, extreme, C.byref(options)) == 0, "all twenty upstream presets")
                rows.append({"level": level, "extreme": extreme, **{name: getattr(options, name) for name, _ in Controls._fields_}})
        return rows

    def encode(self, payload, format, config):
        options = self.options(config)
        zip_payload = format == "zip_payload"
        if zip_payload:
            format = "raw1"
        capacity = len(payload) * 2 + 65536
        output = C.create_string_buffer(b"\xa5" * (capacity + 16))
        count = C.c_size_t()
        result = self.encode_fn(FORMATS[format], C.byref(options), config.get("check", 4), config.get("filter_id", 0),
                                config.get("filter_argument", 0), payload, len(payload), C.byref(output, 8), capacity, C.byref(count))
        require(result == 0, ("reference encode", format, config, result))
        require(output.raw[:8] == b"\xa5" * 8 and output.raw[capacity + 8:capacity + 16] == b"\xa5" * 8, "reference encode guards")
        wire = output.raw[8:8 + count.value]
        if zip_payload:
            prop = (options.pb * 5 + options.lp) * 9 + options.lc
            wire = b"\x09\x04\x05\x00" + bytes([prop]) + struct.pack("<I", options.dictionary_size) + wire
        return wire

    def verify(self, wire, payload, format, config):
        if format == "zip_payload":
            require(wire[:4] == b"\x09\x04\x05\x00", "ZIP LZMA property prefix")
            prop = wire[4]
            config = {**config, "lc": prop % 9, "lp": prop // 9 % 5, "pb": prop // 45,
                      "dictionary_size": int.from_bytes(wire[5:9], "little")}
            wire, format = wire[9:], "raw1"
        options = self.options(config)
        capacity = len(payload) + 1
        output = C.create_string_buffer(b"\xa5" * (capacity + 16))
        consumed, written = C.c_size_t(), C.c_size_t()
        result = self.decode_fn(FORMATS[format], C.byref(options), wire, len(wire), C.byref(output, 8), capacity,
                                C.byref(consumed), C.byref(written))
        require(result == 0 and consumed.value == len(wire) and written.value == len(payload),
                ("reference decode progress", format, result, consumed.value, len(wire), written.value, len(payload)))
        require(output.raw[8:8 + len(payload)] == payload, "reference decoded bytes")
        require(output.raw[:8] == b"\xa5" * 8 and output.raw[8 + len(payload):capacity + 16] == b"\xa5" * 9,
                "reference decoder output guards")


def make_corpus(directory):
    rng = random.Random(0x12A4F00D)
    data = {
        "empty": b"", "tiny": b"ababaXababaYaaZ", "text": (b"bounded LZMA history and reusable streaming match state\n" * 80)[:4096],
        "json": b"\n".join(json.dumps({"id": i, "event": "encode_controls", "service": i % 7}, separators=(",", ":")).encode() for i in range(64)),
        "source": (b"pub fn encode(buffer: []u8, input: []const u8) !usize {\n    if (buffer.len < input.len) return error.OutputTooSmall;\n    @memcpy(buffer[0..input.len], input);\n    return input.len;\n}\n" * 24)[:4096],
        "log": b"\n".join(f"2026-10-24T08:{i % 60:02d}:00Z event=frame service={i % 5} bytes={i * 13} result=verified".encode() for i in range(64)),
        "binary": rng.randbytes(2048) + b"VORT\x00\xff\x00\x01" * 256,
        "small": b"event=frame id=0042 result=ok bytes=00128\n", "repetitive": b"abcde0123456789" * 512,
        "random": rng.randbytes(4096),
    }
    rows = []
    for name, payload in data.items():
        path = directory / f"corpus-{name}.bin"
        path.write_bytes(payload)
        rows.append({"case": name, "path": path.name, "bytes": len(payload), "sha256": digest(payload)})
    manifest = {"schema": "vort-lzma-encode-controls-corpus-v1", "seed": "0x12a4f00d", "rows": rows}
    (directory / "corpus.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def freeze_baseline(directory, corpus, legacy_probe, reference, old_source):
    rows = []
    for sample in corpus["rows"]:
        payload = (directory / sample["path"]).read_bytes()
        for format in ("alone", "xz", "raw2", "micro", "zip_payload"):
            config = {"format": format}
            source = directory / sample["path"]
            output = directory / f"legacy-{sample['case']}-{format}.bin"
            configuration = directory / f"legacy-{sample['case']}-{format}.json"
            configuration.write_text(json.dumps(config) + "\n")
            run(legacy_probe, source, output, configuration)
            wire = output.read_bytes()
            reference.verify(wire, payload, format, {"dictionary_size": 4096 if format == "raw2" else 32768})
            rows.append({"case": sample["case"], "config": config, "input": source.name, "wire": output.name,
                         "input_sha256": digest(payload), "wire_sha256": digest(wire), "encoded_bytes": len(wire),
                         "method": "legacy public Alone payload with standardized method-14 prefix" if format == "zip_payload" else "legacy public encoder"})
    manifest = {"schema": "vort-lzma-encode-controls-legacy-v1", "revision": OLD_REVISION,
                "created_utc": datetime.now(timezone.utc).isoformat(), "probe_sha256": digest(legacy_probe.read_bytes()),
                "probe_source_sha256": digest((ROOT / "tools/lzma/encode_controls_legacy_probe.zig").read_bytes()),
                "old_source_sha256": {str(path.relative_to(old_source)): digest(path.read_bytes()) for path in
                                      [old_source / "root.zig", old_source / "lzma.zig", old_source / "xz.zig", *sorted((old_source / "lzma").rglob("*.zig")), *sorted((old_source / "xz").rglob("*.zig"))]},
                "rows": rows}
    (directory / "legacy.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def source_hashes():
    files = [ROOT / "build.zig", ROOT / "build.zig.zon", *sorted((ROOT / "src").rglob("*.zig")),
             *sorted((ROOT / "tools/lzma").glob("encode_controls*"))]
    return {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in files if path.is_file()}


def probe_call(args, name, source, config, expected_error=None):
    configuration = args.work_dir / f"{name}.json"
    output = args.work_dir / f"{name}.bin"
    configuration.write_text(json.dumps(config, sort_keys=True) + "\n")
    guard = b"existing output must survive rejected encoder calls\x00\xa5"
    if expected_error:
        output.write_bytes(guard)
    executed = run(args.probe.resolve(), source, output, configuration)
    result = json.loads(executed.stdout)
    require(result.get("error") == expected_error, (name, result.get("error"), expected_error))
    if expected_error:
        require(output.read_bytes() == guard, (name, "error preserves existing output"))
        return result, None
    require(output.exists(), (name, "successful probe publishes bytes"))
    wire = output.read_bytes()
    require(result["input_bytes"] == source.stat().st_size and result["output_bytes"] == len(wire), (name, "public probe progress"))
    return result, wire


def validated_encode(args, name, source, config, reference, rows, reverse=True, expected_wire=None):
    payload = source.read_bytes()
    stats, wire = probe_call(args, name, source, config)
    resolved = stats["resolved"]
    ref_options = {key: resolved[key] for key in ("dictionary_size", "lc", "lp", "pb")}
    reference.verify(wire, payload, config["format"], ref_options)
    if expected_wire is not None:
        require(wire == expected_wire, (name, "frozen legacy complete wire"))
    rows.append({"name": name, "direction": "vort-to-liblzma", "config": config, "input_sha256": digest(payload),
                 "wire_sha256": digest(wire), "input_bytes": len(payload), "output_bytes": len(wire),
                 "legacy_wire_equal": expected_wire is not None, "probe": stats})
    if reverse:
        ref_config = {**config, **ref_options}
        upstream = reference.encode(payload, config["format"], ref_config)
        upstream_path = args.work_dir / f"{name}-upstream.bin"
        upstream_path.write_bytes(upstream)
        reverse_config = {**config, "operation": "decode", "expected_size": len(payload)}
        restored_stats, restored = probe_call(args, name + "-reverse", upstream_path, reverse_config)
        require(restored == payload, (name, "upstream encoded data restored by public Vort decoder"))
        rows.append({"name": name + "-reverse", "direction": "liblzma-to-vort", "config": reverse_config,
                     "input_sha256": digest(upstream), "decoded_sha256": digest(restored), "input_bytes": len(upstream),
                     "output_bytes": len(restored), "probe": restored_stats})
    return stats, wire


def campaign(args, prepared, corpus, legacy, reference):
    rows = []
    for item in corpus["rows"]:
        require(digest((prepared / item["path"]).read_bytes()) == item["sha256"], "prepared corpus hash")
    for item in legacy["rows"]:
        wire = (prepared / item["wire"]).read_bytes()
        require(digest(wire) == item["wire_sha256"], "frozen old dictionary wire hash")
        validated_encode(args, "legacy-" + item["case"] + "-" + item["config"]["format"], prepared / item["input"],
                         {**item["config"], "profile_enabled": False}, reference, rows, reverse=False, expected_wire=wire)

    tiny = args.work_dir / "preset-sample.bin"
    tiny.write_bytes(b"ab0ab1ab2ab3ab4ababababXbYbZb event=encode_controls\n" * 2)
    for expected in reference.preset_table():
        for format in ("alone", "xz", "raw2", "micro", "zip_payload"):
            config = {"format": format, "preset": expected["level"], "extreme": expected["extreme"], "profile_enabled": True}
            name = f"preset-{format}-{expected['level']}-extreme{int(expected['extreme'])}"
            stats, _ = validated_encode(args, name, tiny, config, reference, rows)
            resolved = stats["resolved"]
            for key in ("dictionary_size", "lc", "lp", "pb", "nice_len", "depth"):
                require(resolved[key] == expected[key], (name, key, resolved[key], expected[key]))
            require(resolved["mode"] == ("fast" if expected["mode"] == 1 else "normal"), (name, "preset mode"))
            require(FINDERS[resolved["finder"]] == expected["finder"], (name, "preset matcher"))

    family_names = {"text", "json", "source", "log", "binary", "small", "repetitive"}
    families = [row for row in corpus["rows"] if row["case"] in family_names]
    for item in families:
        short = args.work_dir / ("matrix-" + item["case"] + ".bin")
        short.write_bytes((prepared / item["path"]).read_bytes()[:256])
        for mode in ("fast", "normal"):
            for finder in FINDERS:
                for format in ("alone", "xz", "raw2", "micro", "zip_payload"):
                    config = {"format": format, "dictionary_size": 4096, "mode": mode, "finder": finder,
                              "nice_len": 2 if finder in ("hc3", "bt3") else 16, "depth": 4,
                              "lc": 1, "lp": 1, "pb": 3, "profile_enabled": True}
                    validated_encode(args, f"matrix-{item['case']}-{mode}-{finder}-{format}", short, config, reference, rows)

    for length in (0, 1, 2, 3, 5, 4095, 4096, 4097, 4368, 4369, 4370):
        tail = args.work_dir / f"tail-{length}.bin"
        tail.write_bytes((b"abcde0123456789\n" * 300)[:length])
        for mode, finder in (("fast", "hc4"), ("normal", "bt4")):
            for format in ("alone", "xz", "raw2", "micro", "zip_payload"):
                config = {"format": format, "dictionary_size": 4096, "mode": mode, "finder": finder,
                          "nice_len": 32, "profile_enabled": True}
                validated_encode(args, f"tail-{length}-{mode}-{format}", tail, config, reference, rows)

    rng = random.Random(0x70_096)
    wide = args.work_dir / "wide-history.bin"
    base = rng.randbytes(70_000)
    wide.write_bytes(base + base[:96])
    mixed = args.work_dir / "stored-history.bin"
    base = rng.randbytes(65_536)
    mixed.write_bytes(base + base[:512])
    for source in (wide, mixed):
        for mode, finder in (("fast", "hc4"), ("normal", "bt3")):
            for format in ("alone", "xz", "raw2"):
                config = {"format": format, "dictionary_size": 128 * 1024, "mode": mode, "finder": finder,
                          "nice_len": 32, "depth": 8, "profile_enabled": True}
                validated_encode(args, f"large-{source.stem}-{mode}-{format}", source, config, reference, rows)

    for check in (0, 1, 4, 10):
        config = {"format": "xz", "preset": 4, "dictionary_size": 4096, "check": check, "profile_enabled": True}
        validated_encode(args, f"xz-check-{check}", tiny, config, reference, rows)

    for format in ("alone", "xz", "raw2", "micro", "zip_payload"):
        for mode, finder in (("fast", "hc4"), ("normal", "bt4")):
            config = {"format": format, "dictionary_size": 4096, "mode": mode, "finder": finder, "profile_enabled": True}
            name = f"resource-{mode}-{format}"
            stats, wire = validated_encode(args, name + "-base", tiny, config, reference, rows, reverse=False)
            peak = stats["profile"]["peak_working_memory"]
            require(peak > 0, (name, "real matcher/parser peak"))
            _, exact = probe_call(args, name + "-exact", tiny, {**config, "max_working_memory": peak})
            require(exact == wire, (name, "exact quota preserves output"))
            failed, _ = probe_call(args, name + "-below", tiny, {**config, "max_working_memory": peak - 1}, "WorkingMemoryLimitExceeded")
            rows.append({"name": name + "-quota", "direction": "resource", "peak_working_memory": peak,
                         "exact_output_equal": True, "below_error": failed["error"]})
            _, unprofiled = probe_call(args, name + "-no-profile", tiny, {**config, "profile_enabled": False})
            require(unprofiled == wire, (name, "profile off preserves bytes"))

        invalid = [{"preset": 10}, {"extreme": True}, {"dictionary_size": 0}, {"dictionary_size": 4095},
                   {"dictionary_size": 1610612736 + 1}, {"nice_len": 1}, {"nice_len": 274},
                   {"lc": 5}, {"lp": 5}, {"pb": 5}, {"lc": 3, "lp": 2}]
        for index, bad in enumerate(invalid):
            config = {"format": format, "mode": "normal", **bad}
            expected_error = "InvalidBlockPlan" if format in ("xz", "raw2") and "dictionary_size" in bad else "InvalidLzmaOptions"
            failed, _ = probe_call(args, f"invalid-{format}-{index}", tiny, config, expected_error)
            rows.append({"name": f"invalid-{format}-{index}", "direction": "invalid", "config": config,
                         "error": failed["error"], "existing_output_preserved": True})
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference-helper", type=Path, required=True)
    parser.add_argument("--legacy-probe", type=Path)
    parser.add_argument("--old-source", type=Path, default=Path("/tmp/vort-lzma-controls-legacy-source/src"))
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--prepared", type=Path)
    parser.add_argument("--work-dir", type=Path, required=True)
    parser.add_argument("--probe", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--zig", type=Path, default=Path("/home/passchaos/Temp/zig-x86_64-linux-0.16.0/zig"))
    parser.add_argument("--build-mode", default="ReleaseFast")
    args = parser.parse_args()
    args.work_dir = args.work_dir.resolve()
    args.work_dir.mkdir(parents=True, exist_ok=True)
    require(not any(args.work_dir.iterdir()), "work directory must be empty")
    reference = Reference(args.reference_helper)
    if args.prepared:
        prepared = args.prepared.resolve()
        corpus = json.loads((prepared / "corpus.json").read_text())
        legacy = json.loads((prepared / "legacy.json").read_text())
    else:
        require(args.legacy_probe is not None, "initial preparation requires --legacy-probe")
        prepared = args.work_dir
        corpus = make_corpus(prepared)
        legacy = freeze_baseline(prepared, corpus, args.legacy_probe.resolve(), reference, args.old_source.resolve())
        (prepared / "presets.json").write_text(json.dumps({"version": reference.version, "rows": reference.preset_table()}, indent=2) + "\n")
    if args.prepare_only:
        print(f"lzma_controls_frozen_old={len(legacy['rows'])} corpus={len(corpus['rows'])} reference={reference.version} path={prepared}")
        return
    require(args.probe is not None, "--probe required for new control validation")
    before = source_hashes()
    rows = campaign(args, prepared, corpus, legacy, reference)
    after = source_hashes()
    require(before == after, "functional source hashes remain unchanged throughout the campaign")
    require(args.report is not None, "--report required for archived functional evidence")
    report = {"schema": "vort-lzma-xz-encode-controls-functional-v1", "created_utc": datetime.now(timezone.utc).isoformat(),
              "invocation": sys.argv, "purpose": "functional/parameter/resource verification, not a performance ranking",
              "platform": platform.platform(), "machine": platform.machine(), "build_mode": args.build_mode,
              "zig_version": run(args.zig, "version").stdout.decode().strip(), "zig_sha256": digest(args.zig.read_bytes()),
              "reference_version": reference.version, "reference_header_version": reference.header_version,
              "reference_runtime_version": reference.runtime_version, "reference_helper_sha256": digest(reference.path.read_bytes()),
              "probe_sha256": digest(args.probe.read_bytes()), "source_sha256": before, "source_after_sha256": after,
              "corpus": corpus, "legacy": legacy, "reference_presets": reference.preset_table(), "rows": rows}
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    counts = {kind: sum(row["direction"] == kind for row in rows) for kind in
              ("vort-to-liblzma", "liblzma-to-vort", "resource", "invalid")}
    print(json.dumps({"groups": len(rows), "counts": counts, "reference_version": reference.version,
                      "performance_measurements": False, "report": str(args.report)}))


if __name__ == "__main__":
    main()
