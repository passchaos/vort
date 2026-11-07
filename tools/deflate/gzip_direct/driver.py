#!/usr/bin/env python3
"""Generate independent gzip frames and exercise Vort's direct chunk APIs."""

import argparse
import gzip
import json
import pathlib
import shutil
import subprocess
import zlib


def run(cmd, *, data=None):
    return subprocess.run(cmd, input=data, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def payloads():
    state = 0x12345678
    randomish = bytearray(32768)
    for index in range(len(randomish)):
        state = (state * 1664525 + 1013904223) & 0xFFFFFFFF
        randomish[index] = state >> 24
    return [
        ("empty", b""),
        ("tiny", b"hello direct gzip chunks"),
        ("text", b"the quick brown fox jumps over the lazy dog\n" * 256),
        ("matches", (b"0123456789abcdef" * 8192) + b"tail" + (b"0123456789abcdef" * 1024)),
        ("randomish", bytes(randomish)),
    ]


def invoke(probe, frame_path, plain_path, mode):
    result = run([str(probe), str(frame_path), str(plain_path), mode])
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

    cases = []
    for name, plain in payloads():
        plain_path = args.output_dir / f"{name}.plain"
        plain_path.write_bytes(plain)
        for level in (0, 1, 6, 9):
            frame = gzip.compress(plain, compresslevel=level, mtime=0)
            frame_path = args.output_dir / f"{name}-python-l{level}.gz"
            frame_path.write_bytes(frame)
            mode = "byte" if len(frame) <= 4096 else "patterned"
            receipts = [invoke(probe, frame_path, plain_path, mode) for probe in (args.probe_native, args.probe_x86)]
            cases.append({"name": name, "source": f"python-gzip-{level}", "frame_bytes": len(frame), "plain_bytes": len(plain), "receipts": receipts})

    gzip_cli = shutil.which("gzip")
    if gzip_cli:
        name, plain = payloads()[3]
        plain_path = args.output_dir / f"{name}.plain"
        frame = run([gzip_cli, "-n", "-1", "-c"], data=plain).stdout
        frame_path = args.output_dir / f"{name}-system.gz"
        frame_path.write_bytes(frame)
        receipts = [invoke(probe, frame_path, plain_path, "patterned") for probe in (args.probe_native, args.probe_x86)]
        cases.append({"name": name, "source": "system-gzip", "frame_bytes": len(frame), "plain_bytes": len(plain), "receipts": receipts})

    report = {
        "schema": "vort.deflate.gzip-direct-diff.v1",
        "status": "ok",
        "python_zlib_compile": zlib.ZLIB_VERSION,
        "python_zlib_runtime": zlib.ZLIB_RUNTIME_VERSION,
        "gzip_cli": gzip_cli,
        "cases": cases,
        "case_count": len(cases),
        "executions": sum(len(case["receipts"]) for case in cases),
    }
    report_path = args.output_dir / "report.json"
    report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": "ok", "report": str(report_path), "cases": len(cases), "executions": report["executions"]}, sort_keys=True))


if __name__ == "__main__":
    main()
