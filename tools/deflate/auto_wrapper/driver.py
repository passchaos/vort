#!/usr/bin/env python3
"""Compare Vort zlib/gzip auto detection with Python libz wbits=47."""

import argparse
import json
import pathlib
import random
import subprocess
import zlib


def encode(data, fmt, level, dictionary=None):
    kwargs = {"level": level, "method": zlib.DEFLATED, "wbits": 15 if fmt == "zlib" else 31}
    if dictionary is not None:
        kwargs["zdict"] = dictionary
    compressor = zlib.compressobj(**kwargs)
    return compressor.compress(data) + compressor.flush()


def reference_prefix(data, dictionary=None):
    decoder = zlib.decompressobj(47, zdict=dictionary) if dictionary is not None else zlib.decompressobj(47)
    plain = decoder.decompress(data) + decoder.flush()
    if not decoder.eof:
        raise AssertionError("libz did not finish first stream")
    consumed = len(data) - len(decoder.unused_data) - len(decoder.unconsumed_tail)
    return plain, consumed


def invoke(probe, input_path, plain_path, config_path):
    result = subprocess.run([str(probe), str(input_path), str(plain_path), str(config_path)], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    receipt = json.loads(result.stdout)
    if receipt.get("status") != "ok":
        raise AssertionError(receipt)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe-native", type=pathlib.Path, required=True)
    parser.add_argument("--probe-x86", type=pathlib.Path, required=True)
    parser.add_argument("--output-dir", type=pathlib.Path, required=True)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    rng = random.Random(0x47A070)
    payloads = [
        ("empty", b""),
        ("tiny", b"auto wrapper payload"),
        ("text", b"the quick brown fox jumps over the lazy dog\n" * 256),
        ("matches", (b"0123456789abcdef" * 4096) + b"tail" + (b"0123456789abcdef" * 512)),
        ("random", rng.randbytes(16384)),
    ]
    cases = []
    for fmt in ("zlib", "gzip"):
        for index, (name, plain) in enumerate(payloads):
            level = (0, 1, 6, 9)[index % 4]
            frame = encode(plain, fmt, level)
            opposite = encode(b"opposite wrapper tail", "gzip" if fmt == "zlib" else "zlib", 3)
            same = encode(b"same wrapper tail", fmt, 3)
            suffix = b"\xaa invalid tail" if index % 3 == 0 else opposite if index % 3 == 1 else same
            joined = frame + suffix
            reference_plain, consumed = reference_prefix(joined)
            if reference_plain != plain or consumed != len(frame):
                raise AssertionError((fmt, name, consumed, len(frame)))
            stem = f"{fmt}-{name}"
            input_path = args.output_dir / f"{stem}.input"
            plain_path = args.output_dir / f"{stem}.plain"
            config_path = args.output_dir / f"{stem}.json"
            input_path.write_bytes(joined)
            plain_path.write_bytes(plain)
            config_path.write_text(json.dumps({"format": fmt, "frame_len": len(frame)}) + "\n")
            receipts = [invoke(probe, input_path, plain_path, config_path) for probe in (args.probe_native, args.probe_x86)]
            cases.append({"format": fmt, "name": name, "frame_bytes": len(frame), "suffix_bytes": len(suffix), "output_bytes": len(plain), "receipts": receipts})

    dictionary = (b"auto wrapper preset dictionary\n" * 2048) + rng.randbytes(257)
    plain = dictionary[-8192:] + b" dictionary payload " + dictionary[-1024:]
    frame = encode(plain, "zlib", 6, dictionary)
    joined = frame + encode(b"gzip tail", "gzip", 3)
    reference_plain, consumed = reference_prefix(joined, dictionary)
    if reference_plain != plain or consumed != len(frame):
        raise AssertionError("FDICT reference mismatch")
    dictionary_path = args.output_dir / "dictionary.bin"
    input_path = args.output_dir / "dictionary.input"
    plain_path = args.output_dir / "dictionary.plain"
    config_path = args.output_dir / "dictionary.json"
    dictionary_path.write_bytes(dictionary)
    input_path.write_bytes(joined)
    plain_path.write_bytes(plain)
    config_path.write_text(json.dumps({"format": "zlib", "frame_len": len(frame), "dictionary_path": str(dictionary_path)}) + "\n")
    receipts = [invoke(probe, input_path, plain_path, config_path) for probe in (args.probe_native, args.probe_x86)]
    cases.append({"format": "zlib", "name": "fdict", "frame_bytes": len(frame), "suffix_bytes": len(joined) - len(frame), "output_bytes": len(plain), "receipts": receipts})

    report = {
        "schema": "vort.deflate.zlib-or-gzip-auto-diff.v1",
        "status": "ok",
        "zlib_compile": zlib.ZLIB_VERSION,
        "zlib_runtime": zlib.ZLIB_RUNTIME_VERSION,
        "case_count": len(cases),
        "executions": sum(len(case["receipts"]) for case in cases),
        "cases": cases,
    }
    report_path = args.output_dir / "report.json"
    report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": "ok", "report": str(report_path), "cases": len(cases), "executions": report["executions"]}, sort_keys=True))


if __name__ == "__main__":
    main()
