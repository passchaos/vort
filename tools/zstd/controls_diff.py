#!/usr/bin/env python3
"""Frozen positive-level wire baseline and independent Zstd control checks."""
import argparse
from contextlib import nullcontext
import ctypes
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import platform
import random
import re
import struct
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("zstd_dictionary_reference", ROOT / "tools/native/dictionary_resume_diff.py")
reference_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reference_module)


def require(condition, context):
    if not condition:
        raise AssertionError(context)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def source_hashes():
    paths = [ROOT / f"src/{name}.zig" for name in ("zstd", "core", "checksum", "dictionary", "huffman", "lz77", "bitstream", "zstd_huffman_x2_object")]
    paths += sorted((ROOT / "src/zstd").rglob("*.zig"))
    paths += sorted((ROOT / "src/checksum").rglob("*.zig"))
    paths += sorted((ROOT / "src/dictionary").rglob("*.zig"))
    paths += [ROOT / "src/io/working_allocator.zig", ROOT / "src/br/fast_bit_reader.zig", ROOT / "tools/native/dictionary_resume_diff.py",
              ROOT / "tools/zstd/controls_probe.zig", ROOT / "tools/zstd/controls_legacy_probe.zig", Path(__file__).resolve()]
    return {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in paths}


def reference_encode(reference, payload, level=3, strategy=None, dictionary=b""):
    context = reference.create()
    require(context, "ZSTD_createCCtx")
    try:
        for parameter, value in ((100, level), (101, 14), (200, 0), (201, 1), (202, 1)):
            reference.check(reference.parameter(context, parameter, value))
        if strategy is not None:
            reference.check(reference.parameter(context, 107, strategy))
        reference.check(reference.load(context, dictionary, len(dictionary)))
        output = ctypes.create_string_buffer(reference.bound(len(payload)))
        count = reference.check(reference.compress(context, output, len(output), payload, len(payload)))
        frame = output.raw[:count]
        reference.verify(frame, payload, dictionary)
        return frame
    finally:
        reference.free(context)


def run(*args):
    result = subprocess.run([str(value) for value in args], cwd=ROOT, capture_output=True)
    if result.returncode:
        raise RuntimeError(f"command failed: {' '.join(map(str, args))}\n{result.stderr.decode(errors='replace')}")
    return result


def shapes(frame):
    require(frame[:4] == b"\x28\xb5\x2f\xfd", "Zstd magic")
    descriptor = frame[4]
    position = 5 + int(not descriptor & 32) + (0, 1, 2, 4)[descriptor & 3]
    position += (1 if descriptor & 32 else 0, 2, 4, 8)[descriptor >> 6]
    counts = {"raw_blocks": 0, "rle_blocks": 0, "compressed_blocks": 0, "huffman_blocks": 0, "sequence_blocks": 0}
    while True:
        header = int.from_bytes(frame[position:position + 3], "little")
        position += 3
        last, kind, size = bool(header & 1), (header >> 1) & 3, header >> 3
        require(kind < 3, "reserved block kind")
        counts[("raw_blocks", "rle_blocks", "compressed_blocks")[kind]] += 1
        if kind == 2:
            payload = frame[position:position + size]
            literal_kind, size_format = payload[0] & 3, (payload[0] >> 2) & 3
            if literal_kind in (0, 1):
                header_size = 1 if size_format in (0, 2) else (2 if size_format == 1 else 3)
                regenerated = int.from_bytes(payload[:header_size], "little") >> (3 if header_size == 1 else 4)
                literal_payload = regenerated if literal_kind == 0 else 1
            else:
                header_size = 3 if size_format < 2 else (4 if size_format == 2 else 5)
                packed = int.from_bytes(payload[:header_size], "little")
                literal_payload = (packed >> (14 if header_size == 3 else 18 if header_size == 4 else 22)) & ((1 << (10 if header_size == 3 else 14 if header_size == 4 else 18)) - 1)
                counts["huffman_blocks"] += 1
            offset = header_size + literal_payload
            require(offset < len(payload), "sequence count bounds")
            counts["sequence_blocks"] += int(payload[offset] != 0)
        position += 1 if kind == 1 else size
        if last:
            break
    require(position + (4 if descriptor & 4 else 0) == len(frame), "frame end")
    return counts


def stream_shapes(reference, stream):
    totals = {"raw_blocks": 0, "rle_blocks": 0, "compressed_blocks": 0, "huffman_blocks": 0, "sequence_blocks": 0,
              "frames": 0, "skippable_frames": 0}
    position = 0
    while position < len(stream):
        remaining = stream[position:]
        magic = int.from_bytes(remaining[:4], "little")
        if 0x184D2A50 <= magic <= 0x184D2A5F:
            require(len(remaining) >= 8, "skippable header bounds")
            size = 8 + int.from_bytes(remaining[4:8], "little")
            totals["skippable_frames"] += 1
        else:
            size = reference.check(reference.find_frame_size(remaining, len(remaining)))
            require(0 < size <= len(remaining), "reference frame size bounds")
            for field, count in shapes(remaining[:size]).items():
                totals[field] += count
            totals["frames"] += 1
        require(0 < size <= len(remaining), "stream bounds")
        position += size
    return totals


def make_baseline(directory, baseline_probe, old_source, reference):
    rng = random.Random(0xC07A0126)
    inputs = {"empty": b"", "tiny": b"hello zstd!", "rle": b"A" * 2048,
              "text": (b"Zstd positive levels keep legacy bytes and native controls.\n" * 100)[:4096],
              "json": b"\n".join(f'{{"id":{i},"type":"controls","bucket":{i % 31}}}'.encode() for i in range(70)),
              "random": rng.randbytes(4096), "huffman": bytes(rng.randrange(16) for _ in range(4096))}
    dictionary = reference.train_dictionary([f"Zstd dictionary controls training id={i} text sequence log\n".encode() * 20 + rng.randbytes(33) for i in range(100)])
    raw_dictionary = rng.randbytes(8192)
    dictionary_paths = {"full": directory / "dictionary-full", "raw": directory / "dictionary-raw"}
    dictionary_paths["full"].write_bytes(dictionary)
    dictionary_paths["raw"].write_bytes(raw_dictionary)
    inputs["dict-full"] = b"Zstd dictionary controls training id=7 text sequence log\n" * 16
    inputs["dict-raw"] = raw_dictionary[-512:] + raw_dictionary[1000:1500]
    rows = []
    def encode(name, config):
        index = len(rows)
        source, output, configuration = (directory / f"baseline-{index}-{suffix}" for suffix in ("input", "frame", "config.json"))
        source.write_bytes(inputs[name])
        configuration.write_text(json.dumps(config) + "\n")
        run(baseline_probe, source, output, configuration)
        data = output.read_bytes()
        dictionary_data = dictionary if config.get("full_dictionary") else raw_dictionary if config.get("dictionary_path") else b""
        reference.verify(data, inputs[name], dictionary_data)
        rows.append({"case": name, "config": config, "input": source.name, "frame": output.name,
                     "input_bytes": len(inputs[name]), "encoded_bytes": len(data), "input_sha256": digest(inputs[name]),
                     "frame_sha256": digest(data), "shapes": shapes(data)})
    for name in ("empty", "tiny", "rle", "text", "json", "random", "huffman"):
        for level in range(23):
            encode(name, {"mode": "level", "level": level})
        encode(name, {"mode": "default"})
        encode(name, {"mode": "native-default"})
        for selection in ("auto", "raw_or_rle", "literal_only", "fast_compressed"):
            encode(name, {"mode": "native", "selection": selection})
    for name in ("text", "random"):
        for mode in ("level", "native"):
            for options in ({"window_log": 10, "checksum": True}, {"window_log": 14, "checksum": False, "content_size": False}):
                encode(name, {"mode": mode, "level": 3, **options})
    for name, full in (("dict-full", True), ("dict-raw", False)):
        for mode in ("level", "native"):
            for use_set in ((False, True) if full else (False,)):
                encode(name, {"mode": mode, "level": 3, "dictionary_path": str(dictionary_paths["full" if full else "raw"]),
                              "full_dictionary": full, "dictionary_id": 0, "use_set": use_set, "checksum": True,
                              "content_size": False, "window_log": 14})
    manifest = {"schema": "vort-zstd-controls-legacy-wire-v1", "revision": "2cd7e82c", "created_utc": datetime.now(timezone.utc).isoformat(),
                "baseline_probe_sha256": digest(baseline_probe.read_bytes()), "helper_sha256": digest((ROOT / "tools/zstd/controls_legacy_probe.zig").read_bytes()),
                "old_source_sha256": {str(path.relative_to(old_source)): digest(path.read_bytes()) for path in
                                      [old_source / "zstd.zig", old_source / "core.zig", old_source / "checksum.zig", old_source / "dictionary.zig",
                                       *sorted((old_source / "zstd").rglob("*.zig"))]}, "rows": rows}
    (directory / "baseline.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", type=Path)
    parser.add_argument("--baseline-probe", type=Path, required=True)
    parser.add_argument("--baseline-only", action="store_true")
    parser.add_argument("--prepared-baseline", type=Path)
    parser.add_argument("--old-source", type=Path, default=Path("/tmp/vort-zstd-controls-legacy-oracle/src"))
    parser.add_argument("--zig", type=Path, default=Path("/home/passchaos/Temp/zig-x86_64-linux-0.16.0/zig"))
    parser.add_argument("--report", type=Path)
    parser.add_argument("--work-dir", type=Path)
    parser.add_argument("--zstd-helper-object", type=Path)
    parser.add_argument("--build-mode", choices=("Debug", "ReleaseSafe", "ReleaseFast", "ReleaseSmall"))
    args = parser.parse_args()
    require(args.baseline_only or args.probe, "--probe is required unless --baseline-only")
    require(not args.baseline_only or args.work_dir, "--baseline-only requires --work-dir")
    args.baseline_probe = args.baseline_probe.resolve()
    if args.work_dir:
        args.work_dir = args.work_dir.resolve()
        args.work_dir.mkdir(parents=True, exist_ok=True)
        require(not any(args.work_dir.iterdir()), "--work-dir must be empty")
    reference = reference_module.Zstd()
    reference.find_frame_size = reference_module.bind(reference.lib, "ZSTD_findFrameCompressedSize", ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t)
    workspace = nullcontext(str(args.work_dir)) if args.work_dir else tempfile.TemporaryDirectory(prefix="vort-zstd-controls-")
    with workspace as directory:
        temp = Path(directory)
        baseline_dir = args.prepared_baseline.resolve() if args.prepared_baseline else temp
        baseline = json.loads((baseline_dir / "baseline.json").read_text()) if args.prepared_baseline else make_baseline(temp, args.baseline_probe, args.old_source, reference)
        require(baseline["baseline_probe_sha256"] == digest(args.baseline_probe.read_bytes()), "frozen baseline probe hash")
        require(baseline["helper_sha256"] == digest((ROOT / "tools/zstd/controls_legacy_probe.zig").read_bytes()), "frozen baseline helper hash")
        if args.baseline_only:
            print(f"zstd_controls_old_wire_cases={len(baseline['rows'])} native_validation=false revision=2cd7e82c path={temp}")
            return
        args.probe = args.probe.resolve()
        starting_source = source_hashes()
        starting_probe = digest(args.probe.read_bytes())
        rows = []
        def check(name, payload, config, expected_wire=None, reference_dictionary=None):
            index = len(rows)
            source, output, configuration = (temp / f"case-{index}-{suffix}" for suffix in ("input", "frame", "config.json"))
            source.write_bytes(payload)
            configuration.write_text(json.dumps(config) + "\n")
            stats = json.loads(run(args.probe, source, output, configuration).stdout)
            if config.get("expect_failure"):
                require(stats["error"] == "InvalidBlockPlan", (name, "exact invalid-control error", stats["error"]))
            else:
                data = output.read_bytes()
                if expected_wire is not None:
                    require(data == expected_wire, (name, "positive/default old wire baseline"))
                dictionary = Path(config["dictionary_path"]).read_bytes() if config.get("dictionary_path") else b""
                reference.verify(data, payload, dictionary if reference_dictionary is None else reference_dictionary)
                require(stats["round_trip_verified"] and stats["deterministic"] and stats["profile_wire_verified"],
                        (name, "native/deterministic/profile verification"))
                stats["shapes"] = stream_shapes(reference, data)
                controlled = config.get("level", 3) < 0 or config.get("strategy", "auto") != "auto" or config.get("fast_acceleration") is not None
                profile = stats["control_stats"]
                if controlled:
                    require(profile["available"] and profile["controls_used"], (name, "active profile available"))
                    selected = config.get("strategy", "auto")
                    if selected == "auto":
                        selected = "fast"
                    require(profile["resolved_strategy"] == selected, (name, "resolved strategy"))
                    expected_acceleration = abs(config["level"]) if config.get("level", 3) < 0 else config.get("fast_acceleration") or 1
                    require(profile["fast_acceleration"] == expected_acceleration, (name, "resolved acceleration"))
                    if stats["shapes"]:
                        for field in ("raw_blocks", "rle_blocks", "compressed_blocks"):
                            require(profile[field] == stats["shapes"][field], (name, field, "actual selected wire"))
                        if stats["shapes"]["compressed_blocks"] == 0:
                            require(profile["dictionary_sequences"] == 0 and profile["history_sequences"] == 0 and profile["max_distance"] == 0,
                                    (name, "raw fallback excludes emitted references"))
                else:
                    require(not profile["available"] and not profile["controls_used"], (name, "legacy profile unavailable"))
                if config.get("api") == "reusable":
                    require(stats["reusable_verified"], (name, "reused state, profile accumulation and reset"))
            rows.append({"case": name, "config": config, "input_sha256": digest(payload),
                         "output_sha256": digest(output.read_bytes()), **stats})
            if reference_dictionary is not None:
                rows[-1]["reference_dictionary_sha256"] = digest(reference_dictionary)
                rows[-1]["reference_dictionary_method"] = "trained entropy header with matching ID, repcodes 1/4/8 and identical raw-content history; original Vort wire unchanged"
            return stats
        for row in baseline["rows"]:
            payload, old_wire = (baseline_dir / row["input"]).read_bytes(), (baseline_dir / row["frame"]).read_bytes()
            require(digest(payload) == row["input_sha256"] and digest(old_wire) == row["frame_sha256"], "frozen baseline hashes")
            check(f"old-{row['case']}", payload, row["config"], old_wire)
        rng = random.Random(0xACCE1)
        unmatched = rng.randbytes(32768)
        for level in (-1, -4, -16, -131072):
            for api in ("one_shot", "reusable", "incremental", "seekable"):
                check(f"negative-{level}-{api}", unmatched, {"mode": "level", "level": level, "api": api})
        for api in ("one_shot", "reusable", "incremental", "seekable"):
            check(f"negative-empty-explicit-window-{api}", b"",
                  {"mode": "level", "level": -1, "api": api, "window_log": 14, "content_size": True})
            for strategy in ("fast", "double_fast", "greedy", "lazy", "optimal"):
                check(f"empty-explicit-window-{strategy}-{api}", b"",
                      {"mode": "native", "strategy": strategy, "api": api, "window_log": 14, "content_size": True})
        for api in ("one_shot", "reusable", "incremental", "seekable"):
            check(f"negative-double-fast-{api}", unmatched[:8192],
                  {"mode": "level", "level": -4, "strategy": "double_fast", "fast_acceleration": 4, "api": api})
            for strategy in ("fast", "double_fast", "greedy", "lazy", "optimal"):
                check(f"level-controls-{strategy}-{api}", unmatched[:4096] * 2,
                      {"mode": "level", "level": 3, "strategy": strategy, "api": api})
        check("auto-acceleration", unmatched, {"mode": "native", "fast_acceleration": 4})
        magnitude_payload = b"zstd controls alpha beta gamma 0123456789\n" * 64
        check("negative-magnitude-1", magnitude_payload, {"mode": "level", "level": -1})
        magnitude_wire_1 = rows[-1]["output_sha256"]
        check("negative-magnitude-13", magnitude_payload, {"mode": "level", "level": -13})
        require(rows[-1]["output_sha256"] != magnitude_wire_1, "negative magnitude changes actual compressed wire on fixed repeated corpus")
        profiles = {}
        for strategy in ("fast", "double_fast", "greedy", "lazy", "optimal"):
            for shape, payload in (("empty", b""), ("tiny", b"abc"), ("rle", b"Q" * 4096)):
                check(f"controlled-{strategy}-{shape}", payload, {"mode": "native", "strategy": strategy})
            if strategy in ("greedy", "lazy", "optimal"):
                for api in ("one_shot", "reusable", "incremental", "seekable"):
                    stats = check(f"search-{strategy}-{api}", unmatched[:4096] * 2,
                                  {"mode": "native", "strategy": strategy, "api": api, "block_size": 4096})
                    require(stats["control_stats"]["positions_tested"] > 0, (strategy, "search engine actual work"))
                continue
            for acceleration in (1, 4, 16):
                stats = check(f"work-{strategy}-{acceleration}", unmatched,
                              {"mode": "native", "strategy": strategy, "fast_acceleration": acceleration})
                profiles[strategy, acceleration] = stats["control_stats"]
        raw_dictionary_path = baseline_dir / "dictionary-raw"
        raw_dictionary = raw_dictionary_path.read_bytes()
        full_dictionary_path = baseline_dir / "dictionary-full"
        full_dictionary = full_dictionary_path.read_bytes()
        raw_set_id = 0x54A71D01
        full_header_size = reference.check(reference.dict_header(full_dictionary, len(full_dictionary)))
        raw_reference_header = bytearray(full_dictionary[:full_header_size])
        raw_reference_header[4:8] = struct.pack("<I", raw_set_id)
        raw_reference_header[-12:] = struct.pack("<III", 1, 4, 8)
        raw_reference_dictionary = bytes(raw_reference_header) + raw_dictionary
        require(reference.check(reference.dict_header(raw_reference_dictionary, len(raw_reference_dictionary))) == full_header_size,
                "libzstd accepts raw-content reference entropy header")
        (temp / "dictionary-raw-reference-full").write_bytes(raw_reference_dictionary)
        for strategy in ("fast", "double_fast", "greedy", "lazy", "optimal"):
            fallback = check(f"fallback-dictionary-{strategy}", raw_dictionary[-4:],
                             {"mode": "native", "strategy": strategy, "dictionary_path": str(raw_dictionary_path),
                              "dictionary_id": 0, "window_log": 14, "content_size": False})
            require(fallback["control_stats"]["parser_matches"] > 0 and fallback["shapes"]["compressed_blocks"] == 0,
                    (strategy, "rejected dictionary-match candidate exercises raw fallback"))
            for api in ("one_shot", "reusable", "incremental", "seekable"):
                history = check(f"history-{strategy}-{api}", unmatched[:4096] * 2,
                                {"mode": "native", "strategy": strategy, "api": api, "block_size": 4096,
                                 "frame_size": 8192, "window_log": 14, "content_size": False})
                require(history["control_stats"]["history_sequences"] > 0, (strategy, api, "emitted history reference"))
                dictionary = check(f"dictionary-{strategy}-{api}", raw_dictionary[-512:],
                                   {"mode": "native", "strategy": strategy, "api": api, "dictionary_path": str(raw_dictionary_path),
                                    "dictionary_id": 0, "window_log": 14, "content_size": False})
                require(dictionary["control_stats"]["dictionary_sequences"] > 0, (strategy, api, "emitted dictionary reference"))
                require(dictionary["raw_dictionary_required"], (strategy, api, "wire requires raw history, not only header ID"))
                for path, payload, full in ((raw_dictionary_path, raw_dictionary[-512:], False),
                                            (full_dictionary_path, full_dictionary[-512:], True)):
                    dictionary_set = check(f"dictionary-set-{strategy}-{api}-full{full}", payload,
                                           {"mode": "native", "strategy": strategy, "api": api, "dictionary_path": str(path),
                                            "dictionary_id": 0 if full else raw_set_id, "full_dictionary": full, "use_set": True,
                                            "window_log": 14, "content_size": False},
                                           reference_dictionary=None if full else raw_reference_dictionary)
                    require(dictionary_set["control_stats"]["dictionary_sequences"] > 0, (strategy, api, full, "dictionary set emitted reference"))
        require(profiles["fast", 1]["long_hash_probes"] == 0 and profiles["double_fast", 1]["long_hash_probes"] > 0,
                "single and double hash kernels must differ in actual work")
        require(profiles["fast", 16]["positions_tested"] < profiles["fast", 1]["positions_tested"], "acceleration reduces visited positions")
        for name, config in (("invalid-level", {"mode": "level", "level": 23}),
                             ("invalid-negative", {"mode": "level", "level": -131073}),
                             ("negative-mismatch-acc", {"mode": "level", "level": -4, "fast_acceleration": 8}),
                             ("zero-controlled", {"mode": "level", "level": 0, "strategy": "fast"}),
                             ("raw-selection-controlled", {"mode": "native", "selection": "raw_or_rle", "strategy": "fast"}),
                             ("literal-selection-controlled", {"mode": "native", "selection": "literal_only", "strategy": "fast"}),
                             ("zero-acceleration", {"mode": "native", "fast_acceleration": 0}),
                             ("overflow-acceleration", {"mode": "native", "fast_acceleration": 131073}),
                             ("negative-search-strategy", {"mode": "level", "level": -4, "strategy": "greedy"}),
                             ("fast-budget-conflict", {"mode": "native", "strategy": "fast", "match_search_budget": 4}),
                             ("search-budget-overflow", {"mode": "native", "strategy": "lazy", "match_search_budget": 513}),
                             ("rep-beam-conflict", {"mode": "native", "strategy": "optimal", "rep_beam_search": True}),
                             ("search-acceleration", {"mode": "native", "strategy": "greedy", "fast_acceleration": 1}),
                             ("minimum-integer", {"mode": "level", "level": -2147483648})):
            check(name, unmatched[:512], {**config, "expect_failure": True})
        def check_decode(name, frame, expected, dictionary_path=None, full_dictionary=False, expect_failure=False, expected_error=None):
            index = len(rows)
            source, plain, output, configuration = (temp / f"decode-{index}-{suffix}" for suffix in ("frame", "expected", "output", "config.json"))
            source.write_bytes(frame)
            plain.write_bytes(expected)
            config = {"mode": "decode", "expected_path": str(plain), "expect_failure": expect_failure}
            if dictionary_path:
                config.update(dictionary_path=str(dictionary_path), full_dictionary=full_dictionary)
            configuration.write_text(json.dumps(config) + "\n")
            stats = json.loads(run(args.probe, source, output, configuration).stdout)
            require(stats["outside_output_unchanged"], (name, "caller guards"))
            if expect_failure:
                require(stats["error"] is not None, (name, "corrupt upstream frame must reject"))
                if expected_error is not None:
                    require(stats["error"] == expected_error, (name, "exact upstream corruption error"))
            else:
                require(stats["round_trip_verified"] and output.read_bytes() == expected, (name, "upstream-to-native decode"))
            rows.append({"case": name, "direction": "upstream_to_vort", "config": config,
                         "input_sha256": digest(frame), "expected_sha256": digest(expected), **stats})
        for level in (-8, 1, 9):
            frame = reference_encode(reference, unmatched[:8192], level)
            check_decode(f"upstream-level{level}", frame, unmatched[:8192])
        for strategy in range(1, 10):
            frame = reference_encode(reference, unmatched[:4096] * 2, 3, strategy)
            check_decode(f"upstream-strategy{strategy}", frame, unmatched[:4096] * 2)
        for path, dictionary, full in ((raw_dictionary_path, raw_dictionary, False), (full_dictionary_path, full_dictionary, True)):
            expected = dictionary[-512:]
            frame = reference_encode(reference, expected, 3, dictionary=dictionary)
            check_decode(f"upstream-dictionary-full{full}", frame, expected, path, full)
        frame = bytearray(reference_encode(reference, unmatched[:2048], 3))
        frame[-1] ^= 1
        check_decode("upstream-checksum-corrupt", bytes(frame), unmatched[:2048], expect_failure=True, expected_error="ChecksumMismatch")
        cpu = re.search(r"^model name\s*:\s*(.+)$", Path("/proc/cpuinfo").read_text(), re.MULTILINE)
        maps = Path("/proc/self/maps").read_text().splitlines()
        library = next(Path(line.split()[-1]).resolve() for line in maps if "/libzstd.so" in line)
        require(source_hashes() == starting_source, "source changed during differential; rerun after production freeze")
        require(digest(args.probe.read_bytes()) == starting_probe, "probe changed during differential")
        report = {"schema": "vort-zstd-controls-functional-v1", "claim": "legacy wire preservation, interoperability and actual work; no throughput or same-number strategy/ratio parity claim",
                  "created_utc": datetime.now(timezone.utc).isoformat(), "cpu": cpu.group(1) if cpu else platform.processor(),
                  "platform": platform.platform(), "invocation": sys.argv, "reference_version": reference.version,
                  "reference_library": str(library), "reference_sha256": digest(library.read_bytes()),
                  "build_mode": args.build_mode, "zstd_helper_object": str(args.zstd_helper_object.resolve()) if args.zstd_helper_object else None,
                  "zstd_helper_object_sha256": digest(args.zstd_helper_object.read_bytes()) if args.zstd_helper_object else None,
                  "zig_version": run(args.zig, "version").stdout.decode().strip(), "probe_sha256": starting_probe,
                  "baseline": baseline, "source_sha256": starting_source,
                  "rows": rows}
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, indent=2) + "\n")
        print(f"zstd_controls_cases={len(rows)} old_wire={len(baseline['rows'])} libzstd={reference.version} work=verified")


if __name__ == "__main__":
    main()
