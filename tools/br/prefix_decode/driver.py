#!/usr/bin/env python3
"""Compare Vort first-stream boundaries with libbrotli streaming decode."""

import argparse
import brotli
import ctypes
import ctypes.util
import json
import pathlib
import random
import subprocess


SUCCESS, ERROR, NEEDS_MORE_INPUT, NEEDS_MORE_OUTPUT = 1, 0, 2, 3


class Reference:
    def __init__(self):
        name = ctypes.util.find_library("brotlidec") or "libbrotlidec.so.1"
        self.lib = ctypes.CDLL(name)
        self.lib.BrotliDecoderCreateInstance.restype = ctypes.c_void_p
        self.lib.BrotliDecoderDestroyInstance.argtypes = [ctypes.c_void_p]
        self.lib.BrotliDecoderDecompressStream.argtypes = [
            ctypes.c_void_p,
            ctypes.POINTER(ctypes.c_size_t),
            ctypes.POINTER(ctypes.POINTER(ctypes.c_uint8)),
            ctypes.POINTER(ctypes.c_size_t),
            ctypes.POINTER(ctypes.POINTER(ctypes.c_uint8)),
            ctypes.POINTER(ctypes.c_size_t),
        ]
        self.lib.BrotliDecoderDecompressStream.restype = ctypes.c_int
        self.lib.BrotliDecoderVersion.restype = ctypes.c_uint32
        self.name = name

    def decode_prefix(self, data, expected):
        state = self.lib.BrotliDecoderCreateInstance(None, None, None)
        if not state:
            raise MemoryError("BrotliDecoderCreateInstance")
        try:
            in_buffer = (ctypes.c_uint8 * len(data)).from_buffer_copy(data)
            out_buffer = (ctypes.c_uint8 * (len(expected) + 1))()
            next_in = ctypes.cast(in_buffer, ctypes.POINTER(ctypes.c_uint8))
            next_out = ctypes.cast(out_buffer, ctypes.POINTER(ctypes.c_uint8))
            available_in = ctypes.c_size_t(len(data))
            available_out = ctypes.c_size_t(len(out_buffer))
            total_out = ctypes.c_size_t(0)
            while True:
                result = self.lib.BrotliDecoderDecompressStream(
                    state,
                    ctypes.byref(available_in),
                    ctypes.byref(next_in),
                    ctypes.byref(available_out),
                    ctypes.byref(next_out),
                    ctypes.byref(total_out),
                )
                if result == SUCCESS:
                    break
                if result == NEEDS_MORE_OUTPUT:
                    if available_out.value == 0:
                        raise AssertionError("reference output exceeded expected size")
                    continue
                if result == NEEDS_MORE_INPUT:
                    raise AssertionError("reference requested input past supplied prefix")
                if result == ERROR:
                    raise AssertionError("reference rejected generated stream")
                raise AssertionError(f"unknown reference result {result}")
            produced = len(out_buffer) - available_out.value
            decoded = bytes(out_buffer[:produced])
            if decoded != expected:
                raise AssertionError((len(decoded), len(expected)))
            return len(data) - available_in.value
        finally:
            self.lib.BrotliDecoderDestroyInstance(state)


def invoke(probe, input_path, plain_path, mode):
    result = subprocess.run([str(probe), str(input_path), str(plain_path), mode], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    receipt = json.loads(result.stdout)
    if receipt.get("status") != "ok":
        raise AssertionError(receipt)
    return receipt


def payloads():
    rng = random.Random(0xB40711)
    return [
        ("empty", b""),
        ("tiny", b"hello Brotli prefix"),
        ("text", b"the quick brown fox jumps over the lazy dog\n" * 256),
        ("matches", (b"0123456789abcdef" * 8192) + b"tail" + (b"0123456789abcdef" * 1024)),
        ("random", rng.randbytes(32768)),
    ]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe-native", type=pathlib.Path, required=True)
    parser.add_argument("--probe-x86", type=pathlib.Path, required=True)
    parser.add_argument("--output-dir", type=pathlib.Path, required=True)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    reference = Reference()
    cases = []
    all_payloads = payloads()
    modes = [brotli.MODE_GENERIC, brotli.MODE_TEXT, brotli.MODE_FONT]
    for payload_index, (name, plain) in enumerate(all_payloads):
        plain_path = args.output_dir / f"{name}.plain"
        plain_path.write_bytes(plain)
        for quality in (0, 5, 11):
            frame = brotli.compress(plain, mode=modes[payload_index % len(modes)], quality=quality)
            suffix = b"\xaa\xbb invalid suffix" if quality != 5 else brotli.compress(b"next member", quality=3)
            joined = frame + suffix
            input_path = args.output_dir / f"{name}-q{quality}.joined"
            input_path.write_bytes(joined)
            consumed = reference.decode_prefix(joined, plain)
            if consumed != len(frame):
                raise AssertionError((name, quality, consumed, len(frame)))
            mode = "byte" if len(joined) <= 4096 else "patterned"
            receipts = [invoke(probe, input_path, plain_path, mode) for probe in (args.probe_native, args.probe_x86)]
            if any(receipt["input_read"] != consumed for receipt in receipts):
                raise AssertionError((name, quality, consumed, receipts))
            cases.append({"name": name, "quality": quality, "frame_bytes": len(frame), "suffix_bytes": len(suffix), "plain_bytes": len(plain), "reference_input_read": consumed, "receipts": receipts})

    report = {
        "schema": "vort.br.prefix-decode-diff.v1",
        "status": "ok",
        "python_brotli": getattr(brotli, "__version__", "unknown"),
        "libbrotli": reference.name,
        "libbrotli_version": reference.lib.BrotliDecoderVersion(),
        "case_count": len(cases),
        "executions": sum(len(case["receipts"]) for case in cases),
        "cases": cases,
    }
    report_path = args.output_dir / "report.json"
    report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": "ok", "report": str(report_path), "cases": len(cases), "executions": report["executions"]}, sort_keys=True))


if __name__ == "__main__":
    main()
