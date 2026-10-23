#!/usr/bin/env python3
"""Independent liblzma/XZ/7-Zip corpus for progressive XZ and raw LZMA2.

Checks wire behavior, progress and retained memory. No throughput claim.
"""
import argparse
from collections import Counter
from contextlib import nullcontext
from datetime import datetime, timezone
import hashlib
import json
import lzma
from pathlib import Path
import platform
import random
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib

ROOT = Path(__file__).resolve().parents[2]
DICTIONARY = 65536


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


def vli(value):
    encoded = bytearray()
    while value >= 128:
        encoded.append((value & 127) | 128)
        value >>= 7
    encoded.append(value)
    return bytes(encoded)


def crc(data):
    return struct.pack("<I", zlib.crc32(data))


def xz_wrap(raw, expected, compressed_delta=0, unpacked_delta=0, index_delta=0):
    flags = b"\0\0"
    stream_header = b"\xfd7zXZ\0" + flags + crc(flags)
    block_header = bytearray(b"\0\xc0" + vli(len(raw) + compressed_delta) + vli(len(expected) + unpacked_delta)
                             + b"\x21\x01\x08")
    block_header.extend(bytes(-len(block_header) % 4))
    block_header[0] = len(block_header) // 4
    block_header.extend(crc(block_header))
    unpadded = len(block_header) + len(raw)
    block = bytes(block_header) + raw + bytes(-len(raw) % 4)
    index = bytearray(b"\0\x01" + vli(unpadded + index_delta) + vli(len(expected)))
    index.extend(bytes(-len(index) % 4))
    index.extend(crc(index))
    footer_body = struct.pack("<I", len(index) // 4 - 1) + flags
    return stream_header + block + index + crc(footer_body) + footer_body + b"YZ"


def scan_raw(data, offset=0):
    chunks = []
    while True:
        start = offset
        control = data[offset]
        offset += 1
        if control == 0:
            return chunks, offset
        require(control in (1, 2) or control >= 128, "raw LZMA2 control")
        if control <= 2:
            unpacked = int.from_bytes(data[offset:offset + 2], "big") + 1
            offset += 2
            compressed, property_byte = unpacked, None
        else:
            unpacked = ((control & 31) << 16) + int.from_bytes(data[offset:offset + 2], "big") + 1
            compressed = int.from_bytes(data[offset + 2:offset + 4], "big") + 1
            offset += 4
            property_byte = data[offset] if control >= 192 else None
            offset += int(control >= 192)
        payload = offset
        offset += compressed
        require(offset <= len(data), "raw payload bounds")
        chunks.append({"start": start, "payload_start": payload, "end": offset, "control": control,
                       "unpacked": unpacked, "compressed": compressed, "properties": property_byte})


def xz_chunks(data):
    # Inspect standard block headers to find the raw LZMA2 boundaries; footer
    # validation remains independent liblzma's responsibility.
    offset, all_chunks = 12, []
    while data[offset] != 0:
        header_size = (data[offset] + 1) * 4
        chunks, payload_end = scan_raw(data, offset + header_size)
        all_chunks.extend(chunks)
        check_size = {0: 0, 1: 4, 4: 8, 10: 32}[data[7]]
        offset = payload_end + (-(payload_end - offset - header_size) % 4) + check_size
    return all_chunks


def raw_encode(data, lc=3, lp=0, pb=2):
    filters = [{"id": lzma.FILTER_LZMA2, "dict_size": DICTIONARY, "lc": lc, "lp": lp, "pb": pb}]
    encoded = lzma.compress(data, format=lzma.FORMAT_RAW, filters=filters)
    require(lzma.decompress(encoded, format=lzma.FORMAT_RAW, filters=filters) == data, "raw liblzma round trip")
    return encoded


def stored_raw(data):
    output = bytearray()
    for start in range(0, len(data), 65536):
        chunk = data[start:start + 65536]
        output.append(1 if start == 0 else 2)
        output.extend(struct.pack(">H", len(chunk) - 1))
        output.extend(chunk)
    return bytes(output) + b"\0"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", type=Path, required=True)
    parser.add_argument("--xz", type=Path, default=Path(shutil.which("xz") or "xz"))
    parser.add_argument("--seven-zip", "--modern-seven-zip", dest="modern_seven_zip", type=Path,
                        default=Path("/tmp/vort-7zip-26.02.21l9nV/7zz"))
    parser.add_argument("--zig", type=Path, default=Path("/home/passchaos/Temp/zig-x86_64-linux-0.16.0/zig"))
    parser.add_argument("--report", type=Path)
    parser.add_argument("--work-dir", type=Path)
    args = parser.parse_args()
    args.probe, args.xz, args.modern_seven_zip, args.zig = args.probe.resolve(), args.xz.resolve(), args.modern_seven_zip.resolve(), args.zig.resolve()
    require(args.modern_seven_zip.exists(), "modern 7-Zip reference is required for ARM64 and RISC-V coverage")
    if args.work_dir:
        args.work_dir = args.work_dir.resolve()
        args.work_dir.mkdir(parents=True, exist_ok=True)
        require(not any(args.work_dir.iterdir()), "--work-dir must be empty")
    workspace = nullcontext(str(args.work_dir)) if args.work_dir else tempfile.TemporaryDirectory(prefix="vort-xz-progressive-")
    rng = random.Random(0xA25A2026)
    text = b"XZ raw LZMA2 symbols flow before chunk payload completion.\n" * 1200
    semi = bytes(rng.randrange(64) for _ in range(200000))
    mixed = text[:32768] + rng.randbytes(80000) + text[:32768] + semi[:80000]
    families = {"empty": b"", "tiny": b"abc", "text": text, "random": rng.randbytes(70001),
                "semi-multichunk": semi, "mixed-controls": mixed,
                "repeat-2m": b"z" * (2 * 1024 * 1024)}
    cases, rows, reference_commands = [], [], []
    with workspace as directory:
        temp = Path(directory)
        for name, data in families.items():
            raw = raw_encode(data)
            cases.append(("raw", name, raw, data, "liblzma", scan_raw(raw)[0]))
            for check in (lzma.CHECK_NONE, lzma.CHECK_CRC32, lzma.CHECK_CRC64, lzma.CHECK_SHA256):
                encoded = lzma.compress(data, check=check, filters=[{"id": lzma.FILTER_LZMA2, "dict_size": DICTIONARY}])
                require(lzma.decompress(encoded) == data, "XZ liblzma round trip")
                cases.append(("xz", f"{name}-check{check}", encoded, data, "liblzma", xz_chunks(encoded)))
        for lc in range(5):
            for lp in range(5 - lc):
                for pb in range(5):
                    raw = raw_encode(text[:512], lc, lp, pb)
                    cases.append(("raw", f"properties-{lc}-{lp}-{pb}", raw, text[:512], "liblzma", scan_raw(raw)[0]))
        for lc, lp, pb in ((0, 0, 0), (4, 0, 4), (0, 4, 1), (2, 2, 3)):
            raw = raw_encode(text[:8192], lc, lp, pb)
            wrapped = xz_wrap(raw, text[:8192])
            require(lzma.decompress(wrapped) == text[:8192], "declared XZ wrapper")
            cases.append(("xz", f"declared-properties-{lc}-{lp}-{pb}", wrapped, text[:8192], "liblzma-validated wrapper", xz_chunks(wrapped)))
        stored_data = rng.randbytes(150000)
        raw = stored_raw(stored_data)
        filters = [{"id": lzma.FILTER_LZMA2, "dict_size": DICTIONARY}]
        require(lzma.decompress(raw, format=lzma.FORMAT_RAW, filters=filters) == stored_data, "stored chunk oracle")
        cases.append(("raw", "stored-chunks", raw, stored_data, "liblzma-validated wrapper", scan_raw(raw)[0]))
        wrapped = xz_wrap(raw, stored_data)
        require(lzma.decompress(wrapped) == stored_data, "stored XZ wrapper oracle")
        cases.append(("xz", "stored-chunks-declared", wrapped, stored_data, "liblzma-validated wrapper", xz_chunks(wrapped)))
        mixed_data = text[:16384] + rng.randbytes(70000) + text[:8192]
        mixed_raw = raw_encode(mixed_data[:16384])[:-1] + stored_raw(mixed_data[16384:86384])[:-1] + raw_encode(mixed_data[86384:])
        require(lzma.decompress(mixed_raw, format=lzma.FORMAT_RAW, filters=filters) == mixed_data,
                "compressed/stored/compressed mixed control oracle")
        cases.append(("raw", "compressed-stored-compressed", mixed_raw, mixed_data, "liblzma-validated wrapper", scan_raw(mixed_raw)[0]))
        wrapped = xz_wrap(mixed_raw, mixed_data)
        require(lzma.decompress(wrapped) == mixed_data, "mixed XZ wrapper oracle")
        cases.append(("xz", "compressed-stored-compressed-declared", wrapped, mixed_data,
                      "liblzma-validated wrapper", xz_chunks(wrapped)))
        first_data = bytes(65536)
        first = raw_encode(first_data)
        for reset_mode in (1, 2):
            second_data = bytes(65536)
            second = bytearray(raw_encode(second_data))
            second[0] = (second[0] & 31) | (0x80 + reset_mode * 0x20)
            if reset_mode == 1:
                del second[5]
            encoded = first[:-1] + bytes(second)
            require(lzma.decompress(encoded, format=lzma.FORMAT_RAW, filters=filters) == first_data + second_data, "reset mode oracle")
            cases.append(("raw", f"reset-mode-{reset_mode}", encoded, first_data + second_data,
                          "liblzma-validated reset stream", scan_raw(encoded)[0]))
        filter_rows = [
            ("delta", {"id": lzma.FILTER_DELTA, "dist": 7}, bytes(range(251)) * 100),
            ("x86", {"id": lzma.FILTER_X86, "start_offset": 4096}, bytes.fromhex("90e81000000090e9f0ffffff") * 1500),
            ("powerpc", {"id": lzma.FILTER_POWERPC}, bytes.fromhex("480000014bfffffd") * 1500),
            ("ia64", {"id": lzma.FILTER_IA64}, bytes.fromhex("1600000000a000000000000000000000") * 900),
            ("arm", {"id": lzma.FILTER_ARM}, bytes.fromhex("040000ebfcffffeb") * 1500),
            ("arm-thumb", {"id": lzma.FILTER_ARMTHUMB}, bytes.fromhex("00f000f8fff7ffff") * 1500),
            ("sparc", {"id": lzma.FILTER_SPARC}, bytes.fromhex("400000007fffffff") * 1500),
        ]
        for name, filter_, data in filter_rows:
            chain = [filter_, {"id": lzma.FILTER_LZMA2, "dict_size": DICTIONARY}]
            encoded = lzma.compress(data, filters=chain)
            cases.append(("xz", f"filter-{name}", encoded, data, "liblzma", xz_chunks(encoded)))
        chain = [{"id": lzma.FILTER_X86}, {"id": lzma.FILTER_DELTA, "dist": 4}, {"id": lzma.FILTER_LZMA2, "dict_size": DICTIONARY}]
        data = filter_rows[1][2]
        encoded = lzma.compress(data, filters=chain)
        cases.append(("xz", "filter-x86-delta", encoded, data, "liblzma", xz_chunks(encoded)))
        for name, extra_chain in (("delta-x86", [{"id": lzma.FILTER_DELTA, "dist": 4}, {"id": lzma.FILTER_X86}]),
                                  ("delta-delta", [{"id": lzma.FILTER_DELTA, "dist": 3}, {"id": lzma.FILTER_DELTA, "dist": 7}])):
            encoded = lzma.compress(data, filters=extra_chain + [{"id": lzma.FILTER_LZMA2, "dict_size": DICTIONARY}])
            require(lzma.decompress(encoded) == data, "multi-filter chain round trip")
            cases.append(("xz", f"filter-{name}", encoded, data, "liblzma", xz_chunks(encoded)))
        modern_version = None
        if args.modern_seven_zip.exists():
            modern_version = run(args.modern_seven_zip, "i").stdout.decode().splitlines()[1]
            for name, data in (("ARM64", bytes.fromhex("0000009400000090") * 1500),
                               ("RISCV", bytes.fromhex("ef0000001300000097010000e7800100") * 900)):
                source, output = temp / f"modern-{name}", temp / f"modern-{name}.xz"
                source.write_bytes(data)
                encode_command = [args.modern_seven_zip, "a", "-txz", f"-mf={name}", "-mx=1", "-md=64k", output, source]
                decode_command = [args.modern_seven_zip, "x", "-so", "-bd", output]
                run(*encode_command)
                require(run(*decode_command).stdout == data, "modern filter reference round trip")
                reference_commands.extend([[str(value) for value in command] for command in (encode_command, decode_command)])
                encoded = output.read_bytes()
                cases.append(("xz", f"filter-{name.lower()}", encoded, data, "7-Zip26", xz_chunks(encoded)))
        block_source, block_output = temp / "multi-block-source", temp / "multi-block.xz"
        block_source.write_bytes(mixed)
        block_command = [args.xz, "--compress", "--stdout", "--check=crc64", "--block-size=32768", "--lzma2=dict=64KiB", block_source]
        block_output.write_bytes(run(*block_command).stdout)
        reference_commands.append([str(value) for value in block_command])
        encoded = block_output.read_bytes()
        require(lzma.decompress(encoded) == mixed, "XZ Utils multi block")
        cases.append(("xz", "xzutils-multiple-blocks", encoded, mixed, "XZ Utils", xz_chunks(encoded)))

        def check(format_, name, encoded, expected, chunks, pattern="mixed", **config):
            index = len(rows)
            paths = [temp / f"case-{index}-{suffix}" for suffix in ("input", "expected", "output", "config.json")]
            paths[0].write_bytes(encoded)
            paths[1].write_bytes(expected)
            options = {"format": format_, "pattern": pattern, "dictionary_property": 8,
                       "max_dictionary_size": DICTIONARY, **config}
            paths[3].write_text(json.dumps(options) + "\n")
            stats = json.loads(run(args.probe, *paths).stdout)
            require(paths[2].read_bytes() == expected[:stats["output_written"]], (name, "published output prefix"))
            if config.get("expect_failure"):
                require(stats["error"] is not None, (name, "must reject"))
            else:
                require(stats["error"] is None and paths[2].read_bytes() == expected, (name, "complete output"))
                require(stats["input_read"] == config.get("accepted_length", len(encoded)), (name, "accepted input boundary"))
                if format_ == "xz":
                    require(stats["one_shot_verified"], (name, "public one-shot parity"))
                if format_ == "raw" and pattern == "one" and chunks and chunks[0]["control"] >= 128 and chunks[0]["compressed"] > 69:
                    require(stats["first_output_input_offset"] < chunks[0]["end"], (name, "output before compressed chunk ends"))
            if options.get("policy", "progressive") == "progressive":
                compressed_bound = options.get("max_compressed_buffer_len", 64 if format_ == "raw" else 131072)
                decoded_bound = 273 if format_ == "raw" else options.get("max_decoded_buffer_len", 4096)
                require(stats["max_compressed_live"] <= compressed_bound and stats["max_compressed_capacity"] <= compressed_bound,
                        (name, "symbol input guard bound"))
                require(stats["max_decoded_scratch"] <= decoded_bound, (name, "decoded symbol/filter staging bound"))
            rows.append({"case_index": index, "format": format_, "case": name, "config": options,
                         "input_sha256": digest(encoded), "expected_sha256": digest(expected), "output_sha256": digest(paths[2].read_bytes()),
                         "input_bytes": len(encoded), "expected_bytes": len(expected), "chunks": chunks, **stats})
            return stats

        for format_, name, encoded, data, reference, chunks in cases:
            for pattern in (("mixed", "large") if len(data) >= 2 * 1024 * 1024 else ("one", "mixed", "large")):
                stats = check(format_, name, encoded, data, chunks, pattern)
                rows[-1]["reference_generator"] = reference
            if name in ("text", "text-check4", "repeat-2m", "repeat-2m-check4"):
                require(stats["first_output_input_offset"] < chunks[0]["end"], (name, "large-input early publication"))
        lookup = {(format_, name): (encoded, data, chunks) for format_, name, encoded, data, _, chunks in cases}
        semi_chunks = lookup[("raw", "semi-multichunk")][2]
        require(sum(chunk["compressed"] for chunk in semi_chunks if chunk["control"] >= 128) > 65536
                and len(semi_chunks) > 1, "compressed payload beyond 64 KiB must span chunks")
        repeat_chunks = lookup[("raw", "repeat-2m")][2]
        require(repeat_chunks[0]["unpacked"] > 2 * 1024 * 1024 - 512, "near-maximum 2 MiB uncompressed chunk")
        for format_, name in (("raw", "text"), ("xz", "text-check4"), ("xz", "filter-x86-delta")):
            encoded, data, chunks = lookup[(format_, name)]
            check(format_, f"{name}-reset", encoded, data, chunks, reset_after=True)
            check(format_, f"{name}-OOM", encoded, data, chunks, oom=True)
            check(format_, f"{name}-exact", encoded, data, chunks, max_output_len=len(data), expected_output_len=len(data))
            check(format_, f"{name}-memory", encoded, data, chunks, check_limits=True)
            check(format_, f"{name}-limit", encoded, data, chunks, "large", max_output_len=len(data) - 1, expect_failure=True)
            check(format_, f"{name}-truncated", encoded[:-2], data, chunks, expect_failure=True)
        raw, data, chunks = lookup[("raw", "text")]
        check("raw", "raw-marker-stop", raw + b"opaque suffix", data, chunks, "large", stop_after_end_marker=True, accepted_length=len(raw))
        check("raw", "raw-trailing", raw + b"x", data, chunks, "large", expect_failure=True)
        check("raw", "raw-invalid-control", b"\x03", b"", [], expect_failure=True)
        check("raw", "raw-compressed-cap", raw, data, chunks, max_compressed_buffer_len=0, expect_failure=True)
        stored, stored_data, stored_chunks = lookup[("raw", "stored-chunks")]
        check("raw", "stored-zero-compressed-cap", stored, stored_data, stored_chunks, max_compressed_buffer_len=0)
        single, data, chunks = lookup[("xz", "text-check4")]
        check("xz", "xz-finite-buffers", single, data, chunks, max_compressed_buffer_len=128,
              max_decoded_buffer_len=4096)
        check("xz", "xz-dictionary-limit", single, data, chunks, max_dictionary_size=32768, expect_failure=True)
        check("xz", "xz-stop", single + b"opaque suffix", data, chunks, "large", stop_after_first_stream=True, accepted_length=len(single))
        check("xz", "xz-prevalidated", single, data, chunks, policy="prevalidated")
        check("xz", "xz-prevalidated-decoded-cap", single, data, chunks, policy="prevalidated",
              max_decoded_buffer_len=4096, expect_failure=True)
        corrupt = bytearray(single)
        payload_end = chunks[-1]["end"] + 1
        corrupt[payload_end + (-(payload_end - chunks[0]["start"]) % 4)] ^= 1
        check("xz", "xz-check-corrupt", bytes(corrupt), data, chunks, "large", expect_failure=True)
        prevalidated_error = check("xz", "xz-check-corrupt-prevalidated", bytes(corrupt), data, chunks,
                                  policy="prevalidated", expect_failure=True)
        require(prevalidated_error["output_written"] == 0, "prevalidated checksum error must not publish block output")
        check("xz", "xz-short-padding", single + b"\0", data, chunks, expect_failure=True)
        filtered, filtered_data, filtered_chunks = lookup[("xz", "filter-x86-delta")]
        check("xz", "filter-finite-decoded-cap", filtered, filtered_data, filtered_chunks,
              max_compressed_buffer_len=128, max_decoded_buffer_len=4096)
        check("xz", "filter-small-decoded-cap", filtered, filtered_data, filtered_chunks,
              max_decoded_buffer_len=128, expect_failure=True)
        second, second_data, _ = lookup[("xz", "tiny-check1")]
        check("xz", "xz-concatenated-padding", single + bytes(4) + second, data + second_data, chunks,
              one_shot_concatenated=True)
        for name, compressed_delta, unpacked_delta, index_delta in (("compressed-declaration", -1, 0, 0),
                                                                   ("unpacked-declaration", 0, 1, 0), ("index-mismatch", 0, 0, 1)):
            raw, data, raw_chunks = lookup[("raw", "text")]
            bad = xz_wrap(raw, data, compressed_delta, unpacked_delta, index_delta)
            check("xz", name, bad, data, raw_chunks, "large", expect_failure=True)
        bcj_filters = ("x86", "powerpc", "ia64", "arm", "arm-thumb", "sparc", "arm64", "riscv")
        require(all(any(name == f"filter-{filter_}" for _, name, *_ in cases) for filter_ in bcj_filters),
                "all eight supported BCJ filters require independent cases")
        cpu = platform.processor()
        if Path("/proc/cpuinfo").exists():
            cpu_match = re.search(r"^model name\s*:\s*(.+)$", Path("/proc/cpuinfo").read_text(), re.MULTILINE)
            if cpu_match:
                cpu = cpu_match.group(1)
        report = {"schema": "vort-xz-symbol-progressive-v1", "claim": "independent wire/progress/retained-memory correctness; no throughput claim",
                  "created_utc": datetime.now(timezone.utc).isoformat(), "platform": platform.platform(), "cpu": cpu,
                  "probe_build": "Zig 0.16.0 ReleaseFast; independent xz module",
                  "zig_version": run(args.zig, "version").stdout.decode().strip(), "zig_sha256": digest(args.zig.read_bytes()),
                  "invocation": sys.argv, "xz_version": run(args.xz, "--version").stdout.decode().strip(),
                  "python_version": sys.version, "python_sha256": digest(Path(sys.executable).read_bytes()),
                  "raw_encoder": "Python lzma.compress FORMAT_RAW LZMA2 dictionary=65536; explicit lc/lp/pb",
                  "lzma_module_origin": lzma.__spec__.origin, "modern_seven_zip_version": modern_version,
                  "modern_seven_zip_sha256": digest(args.modern_seven_zip.read_bytes()) if modern_version else None,
                  "reference_commands": reference_commands,
                  "xz_sha256": digest(args.xz.read_bytes()), "probe_sha256": digest(args.probe.read_bytes()),
                  "repository_commit": run("git", "rev-parse", "HEAD").stdout.decode().strip(),
                  "source_sha256": {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in
                                    [ROOT / "src/xz.zig", ROOT / "src/core.zig", ROOT / "src/checksum.zig", ROOT / "src/io/working_allocator.zig",
                                     *sorted((ROOT / "src/xz").rglob("*.zig")),
                                     *sorted((ROOT / "src/lzma").glob("*.zig")), ROOT / "tools/xz/progressive_probe.zig", Path(__file__).resolve()]},
                  "corpus_cases": len(cases), "format_counts": dict(Counter(row["format"] for row in rows)),
                  "bcj_filters": bcj_filters,
                  "raw_property_cases": sum(format_ == "raw" and name.startswith("properties-") for format_, name, *_ in cases),
                  "compressed_reset_modes": sorted({(chunk["control"] >> 5) & 3 for format_, _, _, _, _, chunks in cases
                                                    if format_ == "raw" for chunk in chunks if chunk["control"] >= 128}),
                  "one_shot_checks": sum(row["one_shot_verified"] for row in rows),
                  "resource_checks": sum(row["resource_checks"] for row in rows),
                  "oom_failure_cases": sum(row["oom_failures"] for row in rows),
                  "rejected_errors": dict(Counter(row["error"] for row in rows if row["error"])), "rows": rows}
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, indent=2) + "\n")
        print(f"xz_progressive_cases={len(rows)} corpus={len(cases)} formats={report['format_counts']} "
              f"rejected={sum(row['error'] is not None for row in rows)} liblzma/XZ/7Zip=ok")


if __name__ == "__main__":
    main()
