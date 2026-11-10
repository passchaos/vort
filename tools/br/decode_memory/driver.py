#!/usr/bin/env python3
"""Bounded native/ELF32 Brotli decode policy and bidirectional wire verification."""

import argparse
import ctypes as C
import ctypes.util
import datetime
import hashlib
import json
import pathlib
import platform
import random
import struct
import subprocess
import sys

import brotli


ROOT = pathlib.Path(__file__).resolve().parents[3]
U8 = C.POINTER(C.c_uint8)
SIZE = C.POINTER(C.c_size_t)
MODES = {"generic": brotli.MODE_GENERIC, "text": brotli.MODE_TEXT, "font": brotli.MODE_FONT}


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def buffer(data):
    return (C.c_uint8 * max(1, len(data))).from_buffer_copy(data or b"\0")


class Reference:
    def __init__(self, directory):
        self.paths = {
            side: str((directory / f"libbrotli{side}.so").resolve()) if directory else ctypes.util.find_library(f"brotli{side}")
            for side in ("enc", "dec")
        }
        require(all(self.paths.values()), "libbrotli encoder/decoder unavailable")
        self.encoder = C.CDLL(self.paths["enc"])
        self.decoder = C.CDLL(self.paths["dec"])
        self.bind(self.encoder, "BrotliEncoderVersion", C.c_uint32, [])
        self.bind(self.decoder, "BrotliDecoderVersion", C.c_uint32, [])
        self.bind(self.encoder, "BrotliEncoderMaxCompressedSize", C.c_size_t, [C.c_size_t])
        self.bind(self.encoder, "BrotliEncoderCompress", C.c_int, [C.c_int, C.c_int, C.c_int, C.c_size_t, U8, SIZE, U8])
        self.bind(self.decoder, "BrotliDecoderCreateInstance", C.c_void_p, [C.c_void_p] * 3)
        self.bind(self.decoder, "BrotliDecoderDestroyInstance", None, [C.c_void_p])
        self.bind(self.decoder, "BrotliDecoderDecompressStream", C.c_int, [C.c_void_p, SIZE, C.POINTER(U8), SIZE, C.POINTER(U8), SIZE])

    @staticmethod
    def bind(library, name, result, arguments):
        function = getattr(library, name)
        function.restype = result
        function.argtypes = arguments

    def compress(self, plain, quality, mode):
        capacity = max(16, self.encoder.BrotliEncoderMaxCompressedSize(len(plain)))
        encoded = (C.c_uint8 * capacity)()
        length = C.c_size_t(capacity)
        require(self.encoder.BrotliEncoderCompress(quality, 22, mode, len(plain), buffer(plain), C.byref(length), encoded) == 1, "libbrotli compression failed")
        return bytes(encoded[:length.value])

    def decode_prefix(self, wire, plain):
        state = self.decoder.BrotliDecoderCreateInstance(None, None, None)
        require(state, "libbrotli decoder allocation failed")
        try:
            encoded = buffer(wire)
            decoded = (C.c_uint8 * (len(plain) + 1))()
            next_input, next_output = C.cast(encoded, U8), C.cast(decoded, U8)
            available_input, available_output = C.c_size_t(len(wire)), C.c_size_t(len(decoded))
            total = C.c_size_t(0)
            result = self.decoder.BrotliDecoderDecompressStream(
                state, C.byref(available_input), C.byref(next_input),
                C.byref(available_output), C.byref(next_output), C.byref(total),
            )
            require(result == 1, f"libbrotli decode result {result}, expected SUCCESS")
            produced = len(decoded) - available_output.value
            require(bytes(decoded[:produced]) == plain, "libbrotli output mismatch")
            return len(wire) - available_input.value
        finally:
            self.decoder.BrotliDecoderDestroyInstance(state)

    def identity(self):
        loaded = {}
        maps = pathlib.Path("/proc/self/maps")
        if maps.exists():
            for line in maps.read_text().splitlines():
                fields = line.split()
                if len(fields) >= 6 and fields[-1].startswith("/"):
                    for side in ("enc", "dec"):
                        if pathlib.Path(fields[-1]).name.startswith(f"libbrotli{side}.so"):
                            loaded[side] = fields[-1]
        return {
            "requested_paths": self.paths,
            "loaded_paths": loaded,
            "library_sha256": {side: sha256(pathlib.Path(name).read_bytes()) for side, name in loaded.items()},
            "encoder_version": hex(self.encoder.BrotliEncoderVersion()),
            "decoder_version": hex(self.decoder.BrotliDecoderVersion()),
        }


def payloads():
    return [
        ("empty", b""),
        ("tiny", b"Memory budget!\0\n"),
        ("random", random.Random(0xB40711).randbytes(4096)),
        ("repetitive", (b"request=decode status=ok bytes=4096\n" * 128)[:4096]),
        ("context_source", (ROOT / "src/br/decode/one_shot.zig").read_bytes()[:4096]),
        ("rle", b"A" * 4096),
    ]


def probe_identity(name, expected_bits):
    data = name.read_bytes()
    require(data[:4] == b"\x7fELF", f"probe is not ELF: {name}")
    require(data[5] == 1, "only little-endian probe evidence is supported")
    bits = {1: 32, 2: 64}.get(data[4])
    machine = struct.unpack_from("<H", data, 18)[0]
    require(bits == expected_bits, f"expected {expected_bits}-bit ELF probe, got {bits}")
    if expected_bits == 32:
        require(machine == 3, "32-bit probe must be actual x86 ELF")
    return {"path": str(name.resolve()), "sha256": sha256(data), "elf_bits": bits, "elf_machine": machine}


def invoke(probe, frame_path, plain_path, joined_path, expected_bits):
    process = subprocess.run([str(probe), str(frame_path), str(plain_path), str(joined_path)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=60)
    require(process.returncode == 0, f"probe {probe} exited {process.returncode}: {process.stderr}")
    receipt = json.loads(process.stdout)
    require(receipt.get("schema") == "vort-brotli-decode-memory-probe-v1" and receipt.get("status") == "ok", receipt)
    require(receipt["pointer_bits"] == expected_bits and receipt["live_after_deinit"] == 0, receipt)
    if expected_bits == 32:
        require(receipt["target_arch"] == "x86" and receipt["target_abi"] == "musl", receipt)
    require(len(receipt["modes"]) == 20 and receipt["strict_tail_error"] == "TrailingData" and receipt["strict_tail_checks"] == 8, receipt)
    require(receipt["guards_verified"] and receipt["caller_state_preserved_on_refusal"], receipt)
    for mode in receipt["modes"]:
        require(mode["exact_cap_successes"] == 2, mode)
        require(mode["exact_minus_one_refusals"] == (2 if mode["profiled_peak_requested_bytes"] else 0), mode)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe-native", type=pathlib.Path, required=True)
    parser.add_argument("--probe-x86", type=pathlib.Path, required=True)
    parser.add_argument("--output-dir", type=pathlib.Path, required=True)
    parser.add_argument("--libbrotli-dir", type=pathlib.Path, help="Use a pinned local shared-library build instead of system libbrotli")
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    probes = [(args.probe_native.resolve(), struct.calcsize("P") * 8), (args.probe_x86.resolve(), 32)]
    reference = Reference(args.libbrotli_dir)
    cases, reverse = [], []
    source_paths = [ROOT / "build/br_decode_memory.zig", ROOT / "src/br.zig", ROOT / "src/root.zig", ROOT / "src/br/incremental/copy_decoder.zig", ROOT / "src/br/incremental/owned_copy_decoder.zig"]
    source_paths += sorted((ROOT / "src/br/decode").rglob("*.zig"))
    source_paths += sorted(pathlib.Path(__file__).parent.glob("*.*"))
    report = {
        "schema": "vort-brotli-decode-memory-reference-v1", "status": "running",
        "utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "python_version": sys.version, "python_brotli_version": getattr(brotli, "__version__", "unknown"),
        "python_brotli_path": brotli.__file__, "libbrotli": reference.identity(),
        "machine": platform.machine(), "platform": platform.platform(),
        "probes": [probe_identity(probe, bits) for probe, bits in probes],
        "source_sha256": {str(name.relative_to(ROOT)): sha256(name.read_bytes()) for name in source_paths if name.is_file()},
        "quality_modes": {"qualities": [0, 5, 11], "modes": list(MODES)},
        "scope": "correctness and requested heap contracts on small corpora; no performance claim",
        "cases": cases, "reverse_cases": reverse,
    }
    try:
        for name, plain in payloads():
            plain_path = args.output_dir / f"{name}.plain"
            plain_path.write_bytes(plain)
            reversed_payload = False
            for encoder in ("libbrotli", "python_brotli"):
                for quality in (0, 5, 11):
                    for mode_name, mode in MODES.items():
                        frame = reference.compress(plain, quality, mode) if encoder == "libbrotli" else brotli.compress(plain, mode=mode, quality=quality, lgwin=22)
                        require(brotli.decompress(frame) == plain, "Python Brotli disagrees on reference frame")
                        suffix = brotli.compress(b"next member", quality=3) if quality == 5 else b"\xaa\xbb invalid suffix"
                        joined = frame + suffix
                        stem = f"{name}-{encoder}-q{quality}-{mode_name}"
                        frame_path, joined_path = args.output_dir / f"{stem}.br", args.output_dir / f"{stem}.joined"
                        frame_path.write_bytes(frame)
                        joined_path.write_bytes(joined)
                        consumed = reference.decode_prefix(joined, plain)
                        require(consumed == len(frame), (stem, consumed, len(frame)))
                        receipts = [invoke(probe, frame_path, plain_path, joined_path, bits) for probe, bits in probes]
                        require(all(receipt["input_read"] == consumed and receipt["output_written"] == len(plain) for receipt in receipts), stem)
                        if not reversed_payload:
                            for kind in ("stored", "rle"):
                                wires = [receipt[f"{kind}_wire_hex"] for receipt in receipts]
                                require(wires[0] == wires[1], f"native/x86 {kind} wire identity mismatch")
                                if wires[0] is None:
                                    continue
                                wire = bytes.fromhex(wires[0])
                                require(reference.decode_prefix(wire, plain) == len(wire), f"libbrotli {kind} decode boundary")
                                require(brotli.decompress(wire) == plain, f"Python Brotli {kind} output mismatch")
                                wire_path = args.output_dir / f"{name}-vort-{kind}.br"
                                wire_path.write_bytes(wire)
                                reverse.append({"payload": name, "encoding": kind, "wire_path": str(wire_path), "wire_sha256": sha256(wire), "plain_bytes": len(plain), "wire_bytes": len(wire), "native_x86_wire_identity": True, "libbrotli_and_python_decode": "ok"})
                            reversed_payload = True
                        for receipt in receipts:
                            del receipt["stored_wire_hex"]
                            del receipt["rle_wire_hex"]
                        cases.append({"payload": name, "encoder": encoder, "quality": quality, "mode": mode_name,
                                      "plain_bytes": len(plain), "plain_sha256": sha256(plain), "frame_bytes": len(frame),
                                      "frame_sha256": sha256(frame), "suffix": "concatenated" if quality == 5 else "invalid",
                                      "reference_input_read": consumed, "receipts": receipts})
            print(json.dumps({"payload": name, "verified_cases": len(cases), "status": "ok"}), flush=True)
        report["status"] = "ok"
        report["case_count"] = len(cases)
        report["probe_executions"] = sum(len(case["receipts"]) for case in cases)
        report["mode_executions"] = sum(len(receipt["modes"]) for case in cases for receipt in case["receipts"])
        report["exact_minus_one_refusals"] = sum(mode["exact_minus_one_refusals"] for case in cases for receipt in case["receipts"] for mode in receipt["modes"])
        report["reverse_case_count"] = len(reverse)
    except Exception as error:
        report["status"] = "failed"
        report["error"] = str(error)
        raise
    finally:
        report_path = args.output_dir / "report.json"
        report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": "ok", "report": str(report_path), "cases": len(cases), "probe_executions": report["probe_executions"], "reverse_cases": len(reverse)}, sort_keys=True))


if __name__ == "__main__":
    main()
