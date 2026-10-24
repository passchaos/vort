#!/usr/bin/env python3
"""Public LZFSE FSE writer differentials with the independent Apple codec.

The corpus measures interoperability, deterministic bytes, and encoded sizes.
It does not measure or claim throughput. Direct Plan cases exercise the bit
stream separately from matcher selection and stored/LZVN fallback.
"""

import argparse
from collections import Counter
from contextlib import nullcontext
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import platform
import random
import struct
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("lzfse_diff", ROOT / "tools/lzfse/diff.py")
wire_format = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wire_format)


def run(*args):
    result = subprocess.run([str(value) for value in args], cwd=ROOT, capture_output=True)
    if result.returncode:
        raise RuntimeError(f"command failed ({result.returncode}): {' '.join(map(str, args))}\n"
                           f"{result.stdout.decode(errors='replace')}{result.stderr.decode(errors='replace')}")
    return result


def require(condition, context):
    if not condition:
        raise AssertionError(context)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def fse_headers(wire):
    headers = []
    for kind, start, end, raw_size in wire_format.scan(wire):
        if kind == "v1":
            literal_count, record_count, literal_size, lmd_size = struct.unpack_from("<4I", wire, start + 12)
            header_size = wire_format.V1_HEADER_SIZE
            frequencies = struct.unpack_from("<360H", wire, start + 50)
        elif kind == "v2":
            p0, p1, p2 = struct.unpack_from("<3Q", wire, start + 8)
            literal_count, record_count = p0 & 0xFFFFF, (p0 >> 40) & 0xFFFFF
            literal_size, lmd_size = (p0 >> 20) & 0xFFFFF, (p1 >> 40) & 0xFFFFF
            header_size = p2 & 0xFFFFFFFF
            frequencies = wire_format.decode_frequencies(wire[start + 32:start + header_size])
        else:
            continue
        require(literal_count <= 40000 and literal_count % 4 == 0, (kind, "four-lane literal count"))
        require(0 < record_count <= 10000, (kind, "LMD record count"))
        require(lmd_size >= 8, (kind, "LMD read padding"))
        require(start + header_size + literal_size + lmd_size == end, (kind, "payload sizes"))
        require([sum(frequencies[a:b]) for a, b in ((0, 20), (20, 40), (40, 104), (104, 360))]
                == [64, 64, 256, 1024], (kind, "normalized frequency totals"))
        headers.append({"kind": kind, "raw_size": raw_size, "header_size": header_size,
                        "literal_count": literal_count, "records": record_count,
                        "literal_payload_bytes": literal_size, "lmd_payload_bytes": lmd_size,
                        "payload_sha256": sha256(wire[start + header_size:end])})
    return headers


def build_plan(prefix, records, literals):
    require(sum(l for l, _, _ in records) == len(literals), "plan literal accounting")
    expected, cursor = bytearray(prefix), 0
    for literal_len, match_len, distance in records:
        expected.extend(literals[cursor:cursor + literal_len])
        cursor += literal_len
        for _ in range(match_len):
            expected.append(expected[-distance])
    transport = b"LFSP" + struct.pack("<3I", len(prefix), len(literals), len(records))
    transport += prefix + literals + b"".join(struct.pack("<HHI", *record) for record in records)
    return transport, bytes(expected)


def direct_plans():
    plans = [(f"four-lane-tail-{size}", b"", [(size, 0, 1)], b"abcdefgh"[:size]) for size in range(1, 9)]
    plans.append(("zero-literal-payload", b"q", [(0, 2359, 1)] * 3, b""))
    plans.append(("maximum-match", b"a", [(0, 2359, 1)], b""))
    prefix = bytes(range(256)) * 1025
    plans.append(("maximum-distance", prefix, [(0, 2359, 262139)], b""))
    literal_bases, literal_extra = list(range(16)) + [16, 20, 28, 60], [0] * 16 + [2, 3, 5, 8]
    match_bases, match_extra = list(range(16)) + [16, 24, 56, 312], [0] * 16 + [3, 5, 8, 11]
    distance_bases = [0, 1, 2, 3, 4, 6, 8, 10, 12, 16, 20, 24, 28, 36, 44, 52,
                      60, 76, 92, 108, 124, 156, 188, 220, 252, 316, 380, 444, 508, 636,
                      764, 892, 1020, 1276, 1532, 1788, 2044, 2556, 3068, 3580, 4092,
                      5116, 6140, 7164, 8188, 10236, 12284, 14332, 16380, 20476, 24572,
                      28668, 32764, 40956, 49148, 57340, 65532, 81916, 98300, 114684,
                      131068, 163836, 196604, 229372]
    distance_extra = [0] * 4 + [bits for bits in range(1, 16) for _ in range(4)]
    records = [(literal_bases[i % 20] + (1 << literal_extra[i % 20]) - 1,
                max(1, match_bases[i % 20] + (1 << match_extra[i % 20]) - 1),
                distance_bases[i] + (1 << distance_extra[i]) - 1) for i in range(64)]
    records[0], records[1] = (3, 3, 1), (2, 2, 1)
    records.append((315, 0, 1))
    literals = bytes((i * 73 + 31) % 256 for i in range(sum(record[0] for record in records)))
    plans.append(("all-extra-endpoints", prefix, records, literals))
    literal_data = b"abcdefghijklmnopqrst" * 2000
    records = [(min(315, len(literal_data) - i), 0, 1) for i in range(0, len(literal_data), 315)]
    plans.append(("maximum-literal-count", b"", records, literal_data))
    plans.append(("maximum-record-count", b"z", [(0, 1, 1)] * 10000, b""))
    return plans


def corpus():
    rng = random.Random(0x1F5E2026)
    text = (b"LZFSE four interleaved literal lanes and L/M/D arithmetic records.\n" * 4000)
    source = (b"pub fn lookup(key: u32) ?usize { return values[key & 255]; }\n" * 3600)
    json_data = b"\n".join(json.dumps({"id": i, "kind": "lzfse", "bucket": i % 31},
                                     separators=(",", ":")).encode() for i in range(12000))
    random_data = rng.randbytes(200000)
    families = {"empty": b"", "tiny": b"abc", "size-1": b"x", "size-4": b"abcd",
                "size-9": b"tiny tail", "size-315": text[:315], "size-316": text[:316],
                "text": text, "json": json_data, "source": source, "random": random_data,
                "zeros": bytes(100000), "full64k": text[:65536],
                "raw-fse-transitions": random_data[:65536] + text[:65536] + random_data[65536:131072] + text[:65536]}
    return rng, families


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", type=Path, required=True)
    parser.add_argument("--lzfse", type=Path, required=True)
    parser.add_argument("--reference-dir", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--work-dir", type=Path, help="retain all inputs/outputs in a new or empty directory")
    args = parser.parse_args()
    args.probe, args.lzfse = args.probe.resolve(), args.lzfse.resolve()
    reference_dir = (args.reference_dir or args.lzfse.parent).resolve()
    if args.work_dir:
        args.work_dir = args.work_dir.resolve()
        args.work_dir.mkdir(parents=True, exist_ok=True)
        require(not any(args.work_dir.iterdir()), "--work-dir must be empty")
    workspace = nullcontext(str(args.work_dir)) if args.work_dir else tempfile.TemporaryDirectory(prefix="vort-lzfse-fse-")
    rows, conversions, reference_rows = [], [], []
    rng, families = corpus()
    with workspace as directory:
        temp = Path(directory)
        apple_status = wire_format.build_apple_status_probe(args.lzfse, temp, reference_dir, required=True)

        def verify(wire_path, expected, context):
            native, apple = temp / "native-restored", temp / "apple-restored"
            run(args.probe, "decode", wire_path, native, len(expected))
            require(native.read_bytes() == expected, (*context, "native mismatch"))
            if expected:
                try:
                    run(args.lzfse, "-decode", "-i", wire_path, "-o", apple)
                except RuntimeError as error:
                    raise RuntimeError(f"{context}: {error}") from error
                require(apple.read_bytes() == expected, (*context, "Apple mismatch"))
            else:
                run(apple_status, wire_path, apple, 0)
                require(apple.read_bytes() == expected, (*context, "Apple empty status mismatch"))

        def conversion(wire_path, expected, context):
            original = wire_path.read_bytes()
            converted, count = wire_format.convert_v2_to_v1(original)
            if count:
                output = temp / f"converted-{len(conversions)}.lzfse"
                output.write_bytes(converted)
                verify(output, expected, (*context, "V2-to-V1"))
                original_headers, converted_headers = fse_headers(original), fse_headers(converted)
                require([header["payload_sha256"] for header in original_headers]
                        == [header["payload_sha256"] for header in converted_headers], (*context, "unchanged payload"))
                conversions.append({"context": list(context), "converted_blocks": count,
                                    "original_sha256": sha256(original), "converted_sha256": sha256(converted)})
                return converted
            return None

        def record(mode, name, source_data, expected, strategy="auto", version="v2", block_size=65536,
                   hash_log=15, max_distance=262139):
            index = len(rows)
            source, output, repeat = temp / f"input-{index}", temp / f"output-{index}.lzfse", temp / f"repeat-{index}.lzfse"
            source.write_bytes(source_data)
            command = [args.probe, mode, source, output]
            command += [version] if mode == "plan" else [strategy, version, block_size, hash_log, max_distance]
            stats = json.loads(run(*command).stderr)
            command[3] = repeat
            repeated = json.loads(run(*command).stderr)
            wire = output.read_bytes()
            require(wire == repeat.read_bytes() and stats == repeated, (name, strategy, version, "determinism"))
            require(stats["input"] == len(expected) and stats["encoded"] == len(wire), (name, "byte accounting"))
            blocks, headers = wire_format.scan(wire), fse_headers(wire)
            counts = Counter(kind for kind, _, _, _ in blocks)
            require([stats[field] for field in ("stored_blocks", "lzvn_blocks", "fse_v1_blocks", "fse_v2_blocks")]
                    == [counts[kind] for kind in ("raw", "lzvn", "v1", "v2")], (name, "summary block counts"))
            require(stats["fse_literal_payload_bytes"] == sum(header["literal_payload_bytes"] for header in headers),
                    (name, "literal payload accounting"))
            require(stats["fse_lmd_payload_bytes"] == sum(header["lmd_payload_bytes"] for header in headers),
                    (name, "LMD payload accounting"))
            require(stats["fse_records"] == sum(header["records"] for header in headers), (name, "record accounting"))
            require(stats["fse_literal_bytes"] + stats["fse_matched_bytes"]
                    == sum(header["raw_size"] for header in headers), (name, "FSE output accounting"))
            padding = sum(header["literal_count"] for header in headers) - stats["fse_literal_bytes"]
            require(0 <= padding <= 3 * len(headers), (name, "unpadded summary/four-lane padding"))
            require(stats["max_fse_distance"] <= max_distance and stats["max_fse_match_length"] <= 2359,
                    (name, "M/D limits"))
            if mode != "plan":
                require(all(raw_size <= block_size for _, _, _, raw_size in blocks), (name, "block size max"))
                if strategy in ("stored", "legacy-stored"):
                    require(not headers and not counts["lzvn"], (name, "stored compatibility strategy"))
                if strategy == "lzvn":
                    require(not headers, (name, "explicit LZVN strategy"))
                if strategy in ("fse", "override-fse"):
                    require(not counts["lzvn"], (name, "explicit FSE strategy"))
            verify(output, expected, (mode, name, strategy, version))
            converted = conversion(output, expected, (mode, name, strategy, version))
            row = {"case_index": index, "mode": mode, "case": name, "strategy": strategy, "version": version,
                   "block_size": block_size, "hash_log": hash_log, "max_match_distance": max_distance,
                   **stats, "input_sha256": sha256(expected), "probe_input_sha256": sha256(source_data),
                   "encoded_sha256": sha256(wire), "blocks": dict(counts), "fse_headers": headers}
            rows.append(row)
            return row, wire, converted

        for name, prefix, records, literals in direct_plans():
            transport, expected = build_plan(prefix, records, literals)
            first, v1, _ = record("plan", name, transport, expected, version="v1")
            second, _, converted = record("plan", name, transport, expected, version="v2")
            require(converted == v1, (name, "version-only header difference"))
            if name == "zero-literal-payload":
                require(first["fse_literal_payload_bytes"] == second["fse_literal_payload_bytes"] == 0,
                        (name, "zero literal payload"))
        print(f"lzfse direct_plans={len(rows)} Apple=ok", flush=True)

        size_wins = []
        for name, data in families.items():
            for version in ("v1", "v2"):
                results = {}
                for strategy in ("auto", "fse", "lzvn", "stored", "default", "legacy-stored", "override-fse"):
                    row, wire, _ = record("encode", name, data, data, strategy, version)
                    results[strategy] = (row, wire)
                require(results["auto"][1] == results["default"][1], (name, version, "default auto upgrade"))
                require(results["stored"][1] == results["legacy-stored"][1], (name, version, "legacy false meaning"))
                require(results["fse"][1] == results["override-fse"][1], (name, version, "explicit strategy priority"))
                fse, lzvn = results["fse"][0], results["lzvn"][0]
                if fse["fse_v1_blocks"] + fse["fse_v2_blocks"] > 0 and fse["encoded"] < lzvn["encoded"]:
                    size_wins.append({"case": name, "version": version, "input_bytes": len(data),
                                      "fse_bytes": fse["encoded"], "lzvn_bytes": lzvn["encoded"]})
                if name == "full64k":
                    require(any(header["raw_size"] > 32768 for header in fse["fse_headers"]),
                            (name, version, "FSE is not capped at 32 KiB"))
                if name == "raw-fse-transitions":
                    transition = results["fse"][0]
                    require(transition["stored_blocks"] and transition["fse_v1_blocks"] + transition["fse_v2_blocks"],
                            (name, version, "raw/FSE transition coverage"))
            if data:
                original, encoded, restored = temp / f"apple-input-{name}", temp / f"apple-{name}.lzfse", temp / f"apple-native-{name}"
                original.write_bytes(data)
                run(args.lzfse, "-encode", "-i", original, "-o", encoded)
                verify(encoded, data, ("Apple-encode", name))
                conversion(encoded, data, ("Apple-encode", name))
                run(args.probe, "decode", encoded, restored, len(data))
                row, _, _ = record("encode", f"Apple-reencode-{name}", restored.read_bytes(), data)
                reference_rows.append({"case": name, "input_sha256": sha256(data), "apple_encoded_bytes": encoded.stat().st_size,
                                       "apple_encoded_sha256": sha256(encoded.read_bytes()), "reencoded_sha256": row["encoded_sha256"]})
            print(f"lzfse family={name} cases={len(rows)} Apple=ok", flush=True)

        cut_values = bytearray()
        for _ in range(120000):
            value = rng.randrange(16)
            if cut_values and value == cut_values[-1]:
                value = (value + 1) & 15
            cut_values.append(value)
        cut_data = bytes(cut_values)
        for version in ("v1", "v2"):
            cut, cut_wire, _ = record("encode", "literal-count-cut", cut_data, cut_data,
                                      strategy="fse", version=version, block_size=131072, max_distance=1)
            require(len(fse_headers(cut_wire)) >= 3 and cut["fse_matched_bytes"] == 0,
                    (version, "40,000 literal-count cut"))
            wide, _, _ = record("encode", "wide-configured-block", families["text"][:120000], families["text"][:120000],
                                strategy="fse", version=version, block_size=131072)
            require(any(header["raw_size"] > 65536 for header in wide["fse_headers"]),
                    (version, "count-driven block above 64 KiB"))
            for strategy in ("auto", "fse", "lzvn", "stored"):
                resource_data = families["text"][:4096]
                resource, _, _ = record("limits", "resource-and-caller-protection", resource_data,
                                         resource_data, strategy, version)
                resource["resource_and_caller_checks"] = "passed"
        for strategy, version in (("auto", "v1"), ("auto", "v2"), ("fse", "v1"), ("fse", "v2"),
                                  ("lzvn", "v2"), ("stored", "v2")):
            oom_data = families["text"][:2048]
            failure_row, _, _ = record("oom", "allocation-failure-and-caller-protection", oom_data,
                                        oom_data, strategy, version)
            require(failure_row["allocation_failure_cases"] > 0, (strategy, version, "OOM injection"))
        for block_size in (9, 315, 4096):
            data = families["text"][:1234]
            record("encode", f"block-size-{block_size}", data, data, block_size=block_size)
        for hash_log in (8, 20):
            data = families["json"][:4096]
            record("encode", f"hash-log-{hash_log}", data, data, strategy="fse", hash_log=hash_log)
        for distance in (1, 31, 1024):
            data = families["text"][:4096]
            record("encode", f"distance-limit-{distance}", data, data, strategy="fse", max_distance=distance)
        word = rng.randbytes(512)
        far = word + b"\0" * (262139 - len(word)) + word
        far_row, _, _ = record("encode", "maximum-public-match-distance", far, far, strategy="fse")
        require(far_row["max_fse_distance"] == 262139, "public matcher maximum distance")
        require(size_wins, "at least one real FSE result must beat LZVN size")
        encoder_fse_blocks = sum(row["fse_v1_blocks"] + row["fse_v2_blocks"] for row in rows if row["mode"] == "encode")
        auto_fse_blocks = sum(row["fse_v1_blocks"] + row["fse_v2_blocks"] for row in rows
                              if row["mode"] == "encode" and row["strategy"] in ("auto", "default"))
        require(encoder_fse_blocks > 0 and auto_fse_blocks > 0, "public/default encoder must emit real FSE blocks")
        reference_root = Path(run("git", "-C", reference_dir, "rev-parse", "--show-toplevel").stdout.decode().strip())
        report = {"schema": "vort-lzfse-fse-matches-v1",
                  "claim": "functional Apple interoperability, deterministic wire bytes and encoded sizes; no throughput claim",
                  "created_utc": datetime.now(timezone.utc).isoformat(), "platform": platform.platform(), "invocation": sys.argv,
                  "repository_commit": run("git", "rev-parse", "HEAD").stdout.decode().strip(),
                  "repository_dirty": bool(run("git", "status", "--porcelain").stdout),
                  "reference_git": run("git", "-C", reference_dir, "rev-parse", "HEAD").stdout.decode().strip(),
                  "reference_version": run("git", "-C", reference_dir, "describe", "--always", "--dirty").stdout.decode().strip(),
                  "reference_probe_sha256": sha256(args.lzfse.read_bytes()), "probe_sha256": sha256(args.probe.read_bytes()),
                  "apple_status_probe_sha256": sha256(apple_status.read_bytes()),
                  "reference_source_sha256": {name: sha256((reference_root / "src" / name).read_bytes()) for name in
                                               ("lzfse_encode_base.c", "lzfse_decode_base.c", "lzfse_fse.c", "lzfse_fse.h",
                                                "lzfse_encode_tables.h", "lzfse_internal.h")},
                  "source_sha256": {str(path.relative_to(ROOT)): sha256(path.read_bytes()) for path in
                                    [ROOT / "src/root.zig", ROOT / "src/lzfse.zig", *sorted((ROOT / "src/lzfse").rglob("*.zig")),
                                     *sorted((ROOT / "tools/lzfse").glob("*.zig")), *sorted((ROOT / "tools/lzfse").glob("*.py")),
                                     *sorted((ROOT / "tools/lzfse").glob("*.c"))]},
                  "encoder_fse_blocks": encoder_fse_blocks, "auto_fse_blocks": auto_fse_blocks,
                  "empty_apple_decode": "unmodified internal decoder status/eos/full-input consumption; CLI zero-return ambiguity bypassed",
                  "size_wins_over_lzvn": size_wins, "rows": rows, "v2_to_v1_conversions": conversions, "reference_rows": reference_rows}
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, indent=2) + "\n")
        counts = Counter()
        for row in rows:
            counts.update(row["blocks"])
        require(counts["v1"] > 0 and counts["v2"] > 0, "both real FSE writers must run")
        print(f"lzfse_fse_cases={len(rows)} Apple=ok v1={counts['v1']} v2={counts['v2']} "
              f"conversions={len(conversions)} size_wins_over_lzvn={len(size_wins)}")


if __name__ == "__main__":
    main()
