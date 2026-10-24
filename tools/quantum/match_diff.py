#!/usr/bin/env python3
"""Quantum wire/size differentials through the public API and libmspack.

This is a deterministic compatibility corpus, not a throughput benchmark.
Standalone streams carry 0xff after every complete 32 KiB frame. CAB CFDATA
stores the frame payload; libmspack injects the marker itself.
"""

import argparse
from collections import Counter
from contextlib import nullcontext
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import random
import re
import struct
import subprocess
import sys
import tempfile


FRAME_SIZE = 32768
ROOT = Path(__file__).resolve().parents[2]


def run(*args):
    result = subprocess.run([str(arg) for arg in args], cwd=ROOT, capture_output=True)
    if result.returncode:
        raise RuntimeError(f"command failed ({result.returncode}): {' '.join(map(str, args))}\n"
                           f"{result.stdout.decode(errors='replace')}{result.stderr.decode(errors='replace')}")
    return result


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, context):
    if not condition:
        raise AssertionError(context)


def cab_data_blocks(wire):
    """Read generated CAB boundaries without depending on vort's parser."""
    require(wire[:4] == b"MSCF" and len(wire) >= 36, "CAB header")
    require(struct.unpack_from("<I", wire, 8)[0] == len(wire), "CAB size")
    folders, files, flags = struct.unpack_from("<HHH", wire, 26)
    require(folders == 1 and files == 1, "single-folder/single-file CAB")
    cursor, folder_reserve, data_reserve = 36, 0, 0
    if flags & 4:
        header_reserve, folder_reserve, data_reserve = struct.unpack_from("<HBB", wire, cursor)
        cursor += 4 + header_reserve
    for bit in (1, 2):
        if flags & bit:
            for _ in range(2):
                cursor = wire.index(b"\0", cursor) + 1
    data_offset, count, compression = struct.unpack_from("<IHH", wire, cursor)
    require(compression & 15 == 2, "Quantum CAB compression type")
    cursor += 8 + folder_reserve
    blocks = []
    cursor = data_offset
    for _ in range(count):
        _, compressed, uncompressed = struct.unpack_from("<IHH", wire, cursor)
        cursor += 8 + data_reserve
        payload = wire[cursor:cursor + compressed]
        require(len(payload) == compressed, "CFDATA payload bounds")
        blocks.append((payload, uncompressed))
        cursor += compressed
    require(cursor == len(wire), "CFDATA trailer bounds")
    return compression >> 8, blocks


def standalone_from_cab(wire):
    _, blocks = cab_data_blocks(wire)
    return b"".join(payload + (b"\xff" if length == FRAME_SIZE else b"")
                    for payload, length in blocks)


def wrap_single_frame(raw, input_size, bits):
    require(input_size <= FRAME_SIZE, "single frame wrapper")
    if input_size == FRAME_SIZE:
        require(raw[-1:] == b"\xff", "full standalone frame sentinel")
        raw = raw[:-1]
    require(len(raw) <= 65535, "CFDATA compressed size")
    name = b"payload.bin\0"
    files_offset = 44
    data_offset = files_offset + 16 + len(name)
    block = struct.pack("<IHH", 0, len(raw), input_size) + raw if input_size else b""
    header = struct.pack("<4sIIIIIBBHHHHH", b"MSCF", 0, data_offset + len(block), 0,
                         files_offset, 0, 3, 1, 1, 1, 0, 0, 0)
    folder = struct.pack("<IHH", data_offset, int(bool(input_size)), 2 | (1 << 4) | (bits << 8))
    entry = struct.pack("<IIHHHH", input_size, 0, 0, 0x21, 0, 0x20) + name
    return header + folder + entry + block


def corpus():
    rng = random.Random(0x51A47A)
    tiny_source = b"Quantum tiny payload\x00\xff\x80\x40\n" * 2000
    cases = {f"size-{size}": tiny_source[:size]
             for size in (0, 1, 2, 3, 4, 5, 9, 257, 32767, 32768, 32769)}
    seed = rng.randbytes(8192)
    text = (b"Quantum arithmetic models and repeated strings cross every frame.\n" * 1200)[:66019]
    json_data = b"\n".join(json.dumps({"id": i, "kind": "quantum", "active": bool(i & 1),
                                      "tags": ["match", "frame", "window"]},
                                     separators=(",", ":")).encode() for i in range(900))
    source = (b"pub fn lookup(key: u32) ?usize { return table[key & 255]; }\n" * 1100)
    fixed = bytearray()
    for length in (3, 4):
        for _ in range(80):
            word = rng.randbytes(length)
            fixed += word + b"\x00" + word + b"\xff" + rng.randbytes(7)
    variable = bytearray()
    for length in (5, 6, 9, 13, 20, 35, 67, 130, 258, 259):
        word = rng.randbytes(length)
        variable += word + b"\x00" + word + b"\xff"
    families = {
        "random": rng.randbytes(66019),
        "text": text,
        "json": json_data,
        "source": source,
        "fixed3-fixed4": bytes(fixed),
        "variable-lengths": bytes(variable),
        "near-overlap": b"a" * 32768 + (b"abcde" * 7000) + b"tail",
        "nonzero-extras": seed[:137] + seed[:259] + b"other-tail" + seed[:137],
        "window-wrap": rng.randbytes(768) * 87 + b"partial",
        "cross-frame-models": text[:32768] + seed * 4 + text[:32768] + b"odd tail",
    }
    return rng, cases, families


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", type=Path, required=True)
    parser.add_argument("--mspack-dir", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--work-dir", type=Path,
                        help="retain probe inputs and outputs in this new or empty directory")
    parser.add_argument("--windows", type=int, nargs="+", default=list(range(10, 22)),
                        help="subset for diagnosis; the default covers every supported window")
    args = parser.parse_args()
    args.probe = args.probe.resolve()
    args.mspack_dir = args.mspack_dir.resolve()
    require(all(10 <= bits <= 21 for bits in args.windows), "windows must be 10..21")
    rows = []
    rng, tiny, families = corpus()
    if args.work_dir:
        args.work_dir = args.work_dir.resolve()
        args.work_dir.mkdir(parents=True, exist_ok=True)
        require(not any(args.work_dir.iterdir()), "--work-dir must be empty")
    workspace = nullcontext(str(args.work_dir)) if args.work_dir else tempfile.TemporaryDirectory(prefix="vort-quantum-matches-")
    with workspace as directory:
        temp = Path(directory)
        mspack = temp / "mspack-probe"
        oracle_source = ROOT / "tools/lzx/mspack_probe.c"
        static_library = args.mspack_dir / ".libs/libmspack.a"
        oracle_build = ["cc", "-O2", f"-I{args.mspack_dir / 'mspack'}", oracle_source,
                        static_library, "-o", mspack]
        run(*oracle_build)
        oracle_hash = sha256(mspack.read_bytes())

        def oracle(cabinets, expected, context):
            restored = temp / "mspack-restored"
            try:
                run(mspack, cabinets[0], restored, *cabinets[1:])
            except RuntimeError as error:
                raise RuntimeError(f"{context}: {error}") from error
            require(restored.read_bytes() == expected, (*context, "libmspack mismatch"))

        def encode(mode, name, data, bits, strategy="greedy", max_distance=None, hash_log=15):
            index = len(rows)
            context = (mode, name, bits, strategy)
            source = temp / f"input-{index}"
            output, repeat = temp / f"output-{index}", temp / f"repeat-{index}"
            source.write_bytes(data)
            command = [args.probe, mode, source, output, bits, strategy,
                       (1 << 64) - 1 if max_distance is None else max_distance, hash_log]
            stats = json.loads(run(*command).stderr)
            command[3] = repeat
            repeated_stats = json.loads(run(*command).stderr)
            require(stats == repeated_stats, (*context, "summary determinism"))
            require(stats["input"] == len(data), (*context, "input accounting"))
            require(stats["literals"] + stats["matched_bytes"] == len(data), (*context, "summary accounting"))
            require(stats["max_offset"] <= 1 << bits, (*context, "window bound"))
            if max_distance is not None:
                require(stats["max_offset"] <= max_distance, (*context, "distance bound"))
            if strategy == "literals":
                require(stats["matched_bytes"] == 0 and stats["extra_bits"] == 0,
                        (*context, "literal strategy"))
            row = {"case_index": index, "format": mode, "case": name, "window_bits": bits, "strategy": strategy,
                   "hash_log": hash_log, "max_match_distance": max_distance,
                   **stats, "input_sha256": sha256(data)}
            if mode == "cab-set":
                parts, repeated = sorted(output.glob("*.cab")), sorted(repeat.glob("*.cab"))
                require(len(parts) == len(repeated) == stats["parts"], (*context, "part count"))
                require(bool(parts), (*context, "empty set"))
                split_fragments, full_frames = 0, 0
                for first, second in zip(parts, repeated):
                    wire = first.read_bytes()
                    require(wire == second.read_bytes(), (*context, "part determinism"))
                    require(len(wire) <= 2048, (*context, "2 KiB part bound"))
                    folder_bits, blocks = cab_data_blocks(wire)
                    require(folder_bits == bits, (*context, "window header"))
                    split_fragments += sum(size == 0 for _, size in blocks)
                    full_frames += sum(size == FRAME_SIZE for _, size in blocks)
                oracle(parts, data, context)
                row.update({"encoded_sha256": sha256(b"".join(part.read_bytes() for part in parts)),
                            "part_sha256": {part.name: sha256(part.read_bytes()) for part in parts},
                            "split_cfdata_fragments": split_fragments, "full_frames": full_frames})
                if name == "compressed-split-cfdata":
                    require(len(parts) > 1 and split_fragments > 0,
                            (*context, "compressed CFDATA must cross cabinets"))
            else:
                wire = output.read_bytes()
                require(wire == repeat.read_bytes(), (*context, "wire determinism"))
                require(len(wire) == stats["encoded"], (*context, "output accounting"))
                row["encoded_sha256"] = sha256(wire)
                if mode == "cab":
                    folder_bits, blocks = cab_data_blocks(wire)
                    require(folder_bits == bits, (*context, "window header"))
                    require(sum(size for _, size in blocks) == len(data), (*context, "CFDATA output accounting"))
                    oracle([output], data, context)
                    row["full_frames"] = sum(size == FRAME_SIZE for _, size in blocks)
                else:
                    wrapped = temp / "oracle.cab"
                    if len(data) <= FRAME_SIZE:
                        wrapped.write_bytes(wrap_single_frame(wire, len(data), bits))
                    else:
                        run(args.probe, "cab", source, wrapped, bits, strategy,
                            (1 << 64) - 1 if max_distance is None else max_distance, hash_log)
                        require(standalone_from_cab(wrapped.read_bytes()) == wire,
                                (*context, "standalone/CAB frame payload mismatch"))
                    oracle([wrapped], data, context)
                    row["oracle_cab_sha256"] = sha256(wrapped.read_bytes())
                    row["full_frames"] = len(data) // FRAME_SIZE
                    if mode == "limits":
                        row["resource_and_caller_output_checks"] = "passed"
            rows.append(row)
            return row

        for bits in args.windows:
            for name, data in tiny.items():
                encode("raw", name, data, bits)
            for name, data in families.items():
                greedy = encode("raw", name, data, bits)
                literal = encode("raw", name, data, bits, "literals")
                greedy["literal_strategy_encoded"] = literal["encoded"]
                encode("cab", name, data, bits)
                if name in ("text", "near-overlap"):
                    require(greedy["matched_bytes"] > len(data) // 2, (name, bits, "expected matching"))
                    require(greedy["encoded"] < literal["encoded"], (name, bits, "matching size benefit"))
                if name == "fixed3-fixed4":
                    require(greedy["fixed3_matches"] > 0 and greedy["fixed4_matches"] > 0,
                            (name, bits, "fixed selector coverage"))
                if name == "variable-lengths":
                    require(greedy["variable_matches"] > 0 and greedy["extra_bits"] > 0,
                            (name, bits, "variable selector/extra-field coverage"))
            # Give each wide window a real offset near its reach, with a unique
            # three-byte key to keep the bounded greedy table's candidate alive.
            distance = min((1 << bits) - 13, 1_500_000)
            word = rng.randbytes(259)
            prefix = word + b"\0" * (distance - len(word))
            far = prefix + word + b"different-tail"
            far_row = encode("raw", "far-window-match", far, bits)
            require(far_row["max_offset"] >= distance, (bits, "far match reach"))
            for strategy in ("greedy", "literals"):
                encode("limits", "resource-and-caller-output", families["variable-lengths"], bits, strategy)
            for distance_limit in (1, 7, 97):
                encode("raw", f"distance-{distance_limit}", b"abcd" * 1000, bits,
                       max_distance=distance_limit)
            for hash_log in (8, 12):
                encode("raw", f"hash-log-{hash_log}", families["fixed3-fixed4"], bits, hash_log=hash_log)
            print(f"quantum window_bits={bits} cases={len(rows)} libmspack=ok", flush=True)

        split = rng.randbytes(32768) + families["text"][:32768] + rng.randbytes(4097)
        for bits in sorted(set(args.windows) & {10, 15, 18, 21}):
            for strategy in ("greedy", "literals"):
                encode("cab-set", "compressed-split-cfdata", split, bits, strategy)

        totals = {field: sum(row[field] for row in rows if row["strategy"] == "greedy")
                  for field in ("fixed3_matches", "fixed4_matches", "variable_matches", "extra_bits")}
        for field, count in totals.items():
            require(count > 0, ("selector/extra-field coverage", field))
        configure = (args.mspack_dir / "configure.ac").read_text()
        version = re.search(r"AC_INIT\(\[libmspack\],\[([^]]+)\]", configure).group(1)
        source_paths = [ROOT / path for path in (
            "src/root.zig", "src/quantum.zig", "src/cab.zig", "src/cab/quantum.zig",
            "src/cab/writer.zig", "src/cab/set_writer.zig", "src/cab/decoder.zig",
            "tools/quantum/match_probe.zig", "tools/quantum/match_diff.py", "tools/lzx/mspack_probe.c")]
        source_paths += sorted((ROOT / "src/cab/quantum").glob("*.zig"))
        source_paths = [path for path in source_paths if path.exists()]
        report = {
            "schema": "vort-quantum-matches-v1",
            "claim": "functional interoperability, deterministic wire bytes and compressed sizes; no throughput claim",
            "created_utc": datetime.now(timezone.utc).isoformat(),
            "platform": platform.platform(),
            "invocation": sys.argv,
            "oracle_build_command": [str(value) for value in oracle_build],
            "repository_commit": run("git", "rev-parse", "HEAD").stdout.decode().strip(),
            "repository_dirty": bool(run("git", "status", "--porcelain").stdout),
            "windows": args.windows,
            "probe_sha256": sha256(args.probe.read_bytes()),
            "oracle_probe_sha256": oracle_hash,
            "source_sha256": {str(path.relative_to(ROOT)): sha256(path.read_bytes()) for path in source_paths},
            "libmspack_version": version,
            "libmspack_git": run("git", "-C", args.mspack_dir, "rev-parse", "HEAD").stdout.decode().strip(),
            "libmspack_static_sha256": sha256(static_library.read_bytes()),
            "reference_source_sha256": {name: sha256((args.mspack_dir / "mspack" / name).read_bytes())
                                        for name in ("qtmd.c", "qtm.h", "mspack.h")},
            "selector_totals": totals,
            "rows": rows,
        }
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, indent=2) + "\n")
        counts = Counter(row["format"] for row in rows)
        print(f"quantum_matches={len(rows)} raw={counts['raw']} cab={counts['cab']} "
              f"cab_sets={counts['cab-set']} limits={counts['limits']} "
              f"libmspack={version} selector4={totals['fixed3_matches']} "
              f"selector5={totals['fixed4_matches']} selector6={totals['variable_matches']} "
              f"extra_bits={totals['extra_bits']}")


if __name__ == "__main__":
    main()
