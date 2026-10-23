#!/usr/bin/env python3
"""Bounded incremental LZFSE differentials through Apple and public step APIs.

The probe must publish bytes through IncrementalDecoder.step. This corpus
checks wire behavior and retained-memory bounds; it makes no throughput claim.
"""

import argparse
from collections import Counter
from contextlib import nullcontext
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import random
import struct
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("lzfse_wire", ROOT / "tools/lzfse/diff.py")
wire = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wire)
plan_spec = importlib.util.spec_from_file_location("lzfse_plans", ROOT / "tools/lzfse/fse_match_diff.py")
plans = importlib.util.module_from_spec(plan_spec)
plan_spec.loader.exec_module(plans)


def run(*args):
    result = subprocess.run([str(value) for value in args], cwd=ROOT, capture_output=True)
    if result.returncode:
        raise RuntimeError(f"command failed: {' '.join(map(str, args))}\n{result.stderr.decode(errors='replace')}")
    return result


def require(condition, context):
    if not condition:
        raise AssertionError(context)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def add_unused_fse_prefix(stream, prefix_size):
    """Grow both reverse payloads at their unused leading edge, keeping tails."""
    output = bytearray()
    padding = bytes((i * 137 + 31) & 255 for i in range(prefix_size))
    modified = 0
    for kind, start, end, _ in wire.scan(stream):
        if kind not in ("v1", "v2"):
            output.extend(stream[start:end])
            continue
        header = bytearray(stream[start:end])
        if kind == "v1":
            literal_size, lmd_size = struct.unpack_from("<II", header, 20)
            header_size = 772
            struct.pack_into("<I", header, 8, literal_size + lmd_size + 2 * prefix_size)
            struct.pack_into("<II", header, 20, literal_size + prefix_size, lmd_size + prefix_size)
        else:
            p0, p1, p2 = struct.unpack_from("<3Q", header, 8)
            literal_size, lmd_size, header_size = (p0 >> 20) & 0xFFFFF, (p1 >> 40) & 0xFFFFF, p2 & 0xFFFFFFFF
            require(max(literal_size, lmd_size) + prefix_size <= 0xFFFFF, "V2 payload size capacity")
            p0 = (p0 & ~(0xFFFFF << 20)) | ((literal_size + prefix_size) << 20)
            p1 = (p1 & ~(0xFFFFF << 40)) | ((lmd_size + prefix_size) << 40)
            struct.pack_into("<QQ", header, 8, p0, p1)
        output.extend(header[:header_size])
        output.extend(padding)
        output.extend(stream[start + header_size:start + header_size + literal_size])
        output.extend(padding)
        output.extend(stream[start + header_size + literal_size:end])
        modified += 1
    output.extend(b"bvx$")
    require(modified > 0, "prefix corpus must contain FSE blocks")
    return bytes(output)


def raw_stream(data):
    return b"bvx-" + struct.pack("<I", len(data)) + data + b"bvx$"


def literal_lzvn_stream(data):
    payload = bytearray()
    for index in range(0, len(data), 271):
        chunk = data[index:index + 271]
        if len(chunk) < 16:
            payload.append(0xe0 | len(chunk))
        else:
            payload.extend((0xe0, len(chunk) - 16))
        payload.extend(chunk)
    payload.extend((0x06, 0, 0, 0, 0, 0, 0, 0))
    return b"bvxn" + struct.pack("<II", len(data), len(payload)) + payload + b"bvx$"


def retained_bound(stream):
    maximum = 0
    for kind, start, _, _ in wire.scan(stream):
        if kind == "v1":
            literals, records, literal_payload, lmd_payload = struct.unpack_from("<4I", stream, start + 12)
            literal_bits, lmd_bits = struct.unpack_from("<i", stream, start + 28)[0], struct.unpack_from("<i", stream, start + 40)[0]
            frequencies = struct.unpack_from("<360H", stream, start + 50)
        elif kind == "v2":
            p0, p1, p2 = struct.unpack_from("<3Q", stream, start + 8)
            literals, records = p0 & 0xFFFFF, (p0 >> 40) & 0xFFFFF
            literal_payload, lmd_payload = (p0 >> 20) & 0xFFFFF, (p1 >> 40) & 0xFFFFF
            literal_bits, lmd_bits = ((p0 >> 60) & 7) - 7, ((p1 >> 60) & 7) - 7
            frequencies = wire.decode_frequencies(stream[start + 32:start + (p2 & 0xFFFFFFFF)])
        else:
            continue
        def max_bits(freqs, log, extras):
            return max((log - (frequency.bit_length() - 1) + extra
                        for frequency, extra in zip(freqs, extras) if frequency), default=0)
        literal_width = max_bits(frequencies[104:], 10, [0] * 256)
        lmd_width = (max_bits(frequencies[:20], 6, [0] * 16 + [2, 3, 5, 8])
                     + max_bits(frequencies[20:40], 6, [0] * 16 + [3, 5, 8, 11])
                     + max_bits(frequencies[40:104], 8, [0] * 4 + [n for n in range(1, 16) for _ in range(4)]))
        literal_tail = min(literal_payload, (literals * literal_width - literal_bits + 7) // 8) if literals else 0
        lmd_tail = min(lmd_payload, (records * lmd_width - lmd_bits + 7) // 8) if records else 0
        maximum = max(maximum, literal_tail + lmd_tail)
    return maximum


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", type=Path, required=True)
    parser.add_argument("--encode-probe", type=Path, required=True)
    parser.add_argument("--lzfse", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--work-dir", type=Path)
    args = parser.parse_args()
    args.probe, args.encode_probe, args.lzfse = args.probe.resolve(), args.encode_probe.resolve(), args.lzfse.resolve()
    if args.work_dir:
        args.work_dir = args.work_dir.resolve()
        args.work_dir.mkdir(parents=True, exist_ok=True)
        require(not any(args.work_dir.iterdir()), "--work-dir must be empty")
    workspace = nullcontext(str(args.work_dir)) if args.work_dir else tempfile.TemporaryDirectory(prefix="vort-lzfse-stream-")
    rows, cases = [], []
    rng = random.Random(0x57EA1F5E)
    with workspace as directory:
        temp = Path(directory)
        apple_status = wire.build_apple_status_probe(args.lzfse, temp, required=True)

        def apple(encoded, expected):
            source, output = temp / "apple-input", temp / "apple-output"
            source.write_bytes(encoded)
            if expected:
                run(args.lzfse, "-decode", "-i", source, "-o", output)
            else:
                run(apple_status, source, output, 0)
            require(output.read_bytes() == expected, "Apple output mismatch")

        def encode(name, data, strategy, version="v2", block_size=65536):
            source, output = temp / "encode-input", temp / "encode-output"
            source.write_bytes(data)
            run(args.encode_probe, "encode", source, output, strategy, version, block_size)
            encoded = output.read_bytes()
            apple(encoded, data)
            cases.append((name, encoded, data))
            return encoded

        text = b"LZFSE bounded decoder produces bytes before its frame ends.\n" * 1500
        json_data = b"\n".join(f'{{"id":{i},"kind":"stream","bucket":{i % 31}}}'.encode() for i in range(2000))
        source_data = b"pub fn lookup(key: u32) ?usize { return entries[key & 255]; }\n" * 1200
        for strategy in ("auto", "lzvn", "fse", "stored"):
            for name, data in (("empty", b""), ("tiny", b"abc"), ("text", text),
                               ("json", json_data), ("source", source_data), ("random", rng.randbytes(70001))):
                encode(f"{name}-{strategy}", data, strategy)
        for name, prefix, records, literals in plans.direct_plans():
            transport, expected = plans.build_plan(prefix, records, literals)
            source, output = temp / "plan-input", temp / "plan-output"
            source.write_bytes(transport)
            for version in ("v1", "v2"):
                run(args.encode_probe, "plan", source, output, version)
                encoded = output.read_bytes()
                apple(encoded, expected)
                cases.append((f"{name}-{version}", encoded, expected))
        for version in ("v1", "v2"):
            encode(f"large-count-block-{version}", text * 4, "fse", version, 524288)
            encoded = encode(f"prefix-base-{version}", json_data[:8192], "fse", version)
            for prefix_size in (17, 200000):
                grown = add_unused_fse_prefix(encoded, prefix_size)
                apple(grown, json_data[:8192])
                cases.append((f"unused-prefix-{prefix_size}-{version}", grown, json_data[:8192]))
        random_prefix = rng.randbytes(65536)
        fse_middle = encode("cross-block-fse", random_prefix + random_prefix[:16384] + text, "fse")
        lzvn_middle = encode("cross-block-lzvn", random_prefix + random_prefix[:16384] + text, "lzvn")
        raw = raw_stream(random_prefix)
        mixed = raw[:-4] + fse_middle[:-4] + lzvn_middle
        mixed_expected = random_prefix + (random_prefix + random_prefix[:16384] + text) * 2
        apple(mixed, mixed_expected)
        cases.append(("raw-fse-lzvn-mixed", mixed, mixed_expected))
        word = rng.randbytes(512)
        far_data = word + b"\0" * (262139 - len(word)) + word
        encode("history-ring-maximum-distance", far_data, "fse")
        large_literal_data = rng.randbytes(300001)
        large_lzvn = literal_lzvn_stream(large_literal_data)
        apple(large_lzvn, large_literal_data)
        cases.append(("large-lzvn-literal-payload", large_lzvn, large_literal_data))
        def check(name, encoded, expected, pattern="micro", mode="decode", **options):
            index = len(rows)
            encoded_path, expected_path, output_path, config_path = (temp / f"case-{index}-{suffix}" for suffix in
                                                                    ("input", "expected", "output", "config.json"))
            encoded_path.write_bytes(encoded)
            expected_path.write_bytes(expected)
            config = {"mode": mode, "pattern": pattern, **options}
            config_path.write_text(json.dumps(config) + "\n")
            result = json.loads(run(args.probe, encoded_path, expected_path, output_path, config_path).stdout)
            require(output_path.read_bytes() == expected[:result["output_written"]], (name, mode, "published prefix"))
            require(result["max_buffered_input"] <= options.get("max_compressed_buffer_len", 131072),
                    (name, mode, "bounded compressed retention"))
            require(result["max_history_len"] <= options.get("max_history_len", 262139), (name, mode, "history bound"))
            require(result["max_retained_compressed_capacity"] <= options.get("max_compressed_buffer_len", 131072),
                    (name, mode, "bounded compressed allocation"))
            if mode in ("decode", "limits", "reset", "oom"):
                require(result["max_buffered_input"] <= retained_bound(encoded), (name, mode, "count/frequency-derived suffix bound"))
            require(result["snapshot"]["input_read"] == result["input_read"]
                    and result["snapshot"]["output_written"] == result["output_written"],
                    (name, mode, "snapshot cumulative progress"))
            if mode == "decode":
                require(result["error"] is None and result["output_written"] == len(expected), (name, "complete output"))
                require(result["input_read"] == len(encoded), (name, "complete input"))
                if pattern == "one":
                    require(result["output_before_end_marker"] or not expected, (name, "early publication before EOS"))
            elif mode == "error":
                require(result["error"] == options["expected_error"], (name, "exact error", result))
                require(result["snapshot"]["last_error_name"] == result["error"], (name, "snapshot exact error"))
            if mode == "concat":
                require(result["streams"] == result["snapshot"]["stream_count"] == 2,
                        (name, "stopped stream continuation accounting"))
            rows.append({"case": name, "pattern": pattern, "mode": mode, "config": config,
                         "case_index": index,
                         "input_sha256": digest(encoded), "expected_sha256": digest(expected),
                         "output_sha256": digest(output_path.read_bytes()), "input_bytes": len(encoded),
                         "expected_bytes": len(expected), **result})
            return result

        for index, (name, encoded, expected) in enumerate(cases):
            for pattern in ("one", "micro", "wide"):
                check(name, encoded, expected, pattern)
            if index % 10 == 0:
                print(f"lzfse stream corpus={index + 1}/{len(cases)} checks={len(rows)} Apple=ok", flush=True)
        # Exact resource/limit/reset/OOM checks run on low-cost representative
        # streams. The probe never calls the allocating decoder to publish data.
        samples = {name: (encoded, expected) for name, encoded, expected in cases}
        for version in ("v1", "v2"):
            baseline = next(row for row in rows if row["case"] == f"prefix-base-{version}" and row["pattern"] == "micro")
            grown = next(row for row in rows if row["case"] == f"unused-prefix-200000-{version}" and row["pattern"] == "micro")
            require(grown["max_buffered_input"] <= 117502 and baseline["max_buffered_input"] <= 117502,
                    (version, "unused prefix remains bounded by frequency/count reach"))
            grown_wire = samples[f"unused-prefix-200000-{version}"][0]
            payload_bytes = sum(header["literal_payload_bytes"] + header["lmd_payload_bytes"] for header in plans.fse_headers(grown_wire))
            require(grown["payload_prefix_skipped"] == payload_bytes - retained_bound(grown_wire),
                    (version, "exact unused leading payload skip"))
        for name in ("text-fse", "text-lzvn", "text-stored", "unused-prefix-200000-v2"):
            encoded, expected = samples[name]
            check(name, encoded, expected, mode="limits")
            check(name, encoded, expected, mode="reset")
        for name in ("tiny-fse", "tiny-lzvn", "tiny-stored", "prefix-base-v2"):
            encoded, expected = samples[name]
            check(name, encoded, expected, "micro", mode="oom")
        raw_expected = b"raw progress before truncation" * 3
        raw_encoded = raw_stream(raw_expected)
        check("raw-no-history", raw_encoded, raw_expected, max_history_len=0, max_compressed_buffer_len=0)
        check("bad-magic", b"nope", b"", mode="error", expected_error="InvalidMagic")
        check("finished-before-input", raw_encoded, raw_expected, mode="error", expected_error="TrailingData",
              finish_before_input=True)
        corrupt_lzvn = bytes((0xe1, ord('a'), 0xf1, 0x06, 0, 0, 0, 0, 0, 0, 0))
        check("lzvn-partial-output-error", b"bvxn" + struct.pack("<II", 2, len(corrupt_lzvn)) + corrupt_lzvn + b"bvx$",
              b"a", "wide", mode="error", expected_error="InvalidLzvnStream")
        check("missing-eos", raw_encoded[:-4], raw_expected, mode="error", expected_error="TruncatedFrame")
        check("trailing-data", raw_encoded + b"x", raw_expected, "wide", mode="error", expected_error="TrailingData")
        check("output-limit", raw_encoded, raw_expected, "wide", mode="error", expected_error="OutputLimitExceeded",
              max_output_len=len(raw_expected) - 1)
        check("expected-length", raw_encoded, raw_expected, mode="error", expected_error="SizeMismatch",
              expected_output_len=len(raw_expected) + 1)
        check("invalid-history-option", raw_encoded, raw_expected, mode="error", expected_error="InvalidLzfseStream",
              max_history_len=262140)
        for name in ("maximum-distance-v2", "text-lzvn"):
            encoded, expected = samples[name]
            check(f"{name}-history-small", encoded, expected, mode="error", expected_error="HistoryLimitExceeded",
                  max_history_len=0)
        for name in ("text-fse", "text-lzvn"):
            encoded, expected = samples[name]
            check(f"{name}-compressed-zero", encoded, expected, mode="error", expected_error="CompressedBufferLimitExceeded",
                  max_compressed_buffer_len=0) if name == "text-fse" else check(
                      f"{name}-compressed-zero", encoded, expected, max_compressed_buffer_len=0)
        check("large-lzvn-zero-buffer", large_lzvn, large_literal_data, "micro", max_compressed_buffer_len=0)
        first, second = samples["text-fse"], samples["json-lzvn"]
        check("concatenated-stopped-streams", first[0] + second[0], first[1] + second[1], "micro",
              mode="concat", stop_after_end_marker=True)
        check("concatenated-cumulative-limit", first[0] + second[0], first[1] + second[1], "wide",
              mode="error", stop_after_end_marker=True, expected_error="OutputLimitExceeded",
              max_output_len=len(first[1]) + len(second[1]) - 1)
        require(any(row["error_partial_output"] > 0 for row in rows if row["mode"] == "error"),
                "at least one failing step must publish and report partial output progress")
        reference_dir = Path(run("git", "-C", args.lzfse.parent, "rev-parse", "--show-toplevel").stdout.decode().strip())
        report = {"schema": "vort-lzfse-bounded-stream-v1",
                  "claim": "incremental wire correctness, output progress and retained-memory bounds; no throughput claim",
                  "created_utc": datetime.now(timezone.utc).isoformat(), "invocation": sys.argv,
                  "repository_commit": run("git", "rev-parse", "HEAD").stdout.decode().strip(),
                  "probe_sha256": digest(args.probe.read_bytes()), "encode_probe_sha256": digest(args.encode_probe.read_bytes()),
                  "reference_probe_sha256": digest(args.lzfse.read_bytes()), "apple_status_probe_sha256": digest(apple_status.read_bytes()),
                  "reference_git": run("git", "-C", reference_dir, "rev-parse", "HEAD").stdout.decode().strip(),
                  "source_sha256": {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in
                                    [ROOT / "src/lzfse.zig", ROOT / "src/core.zig", *sorted((ROOT / "src/lzfse").rglob("*.zig")),
                                     ROOT / "tools/lzfse/stream_probe.zig", Path(__file__).resolve()]},
                  "reference_source_sha256": {name: digest((reference_dir / "src" / name).read_bytes()) for name in
                                               ("lzfse_decode_base.c", "lzfse_decode.c", "lzfse_fse.h")},
                  "corpus_cases": len(cases), "mode_counts": dict(Counter(row["mode"] for row in rows)), "rows": rows}
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, indent=2) + "\n")
        print(f"lzfse_stream_cases={len(rows)} corpus={len(cases)} modes={report['mode_counts']} Apple=ok")


if __name__ == "__main__":
    main()
