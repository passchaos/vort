#!/usr/bin/env python3
"""Validate portable LZ4 acceleration CLI semantics without throughput claims."""
import argparse
import ctypes
import ctypes.util
import json
from pathlib import Path
import random
import subprocess
import tempfile


class Reference:
    def __init__(self):
        self.lib = ctypes.CDLL(ctypes.util.find_library("lz4"))
        self.lib.LZ4_versionString.restype = ctypes.c_char_p
        self.version = self.lib.LZ4_versionString().decode()
        self.lib.LZ4_decompress_safe_usingDict.argtypes = (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_void_p, ctypes.c_int)
        self.lib.LZ4_decompress_safe_usingDict.restype = ctypes.c_int
        self.lib.LZ4_compress_default.argtypes = (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int, ctypes.c_int)
        self.lib.LZ4_compress_default.restype = ctypes.c_int
        self.lib.LZ4F_createDecompressionContext.argtypes = (ctypes.POINTER(ctypes.c_void_p), ctypes.c_uint)
        self.lib.LZ4F_createDecompressionContext.restype = ctypes.c_size_t
        self.lib.LZ4F_freeDecompressionContext.argtypes = (ctypes.c_void_p,)
        self.lib.LZ4F_decompress.argtypes = (ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(ctypes.c_size_t), ctypes.c_void_p, ctypes.POINTER(ctypes.c_size_t), ctypes.c_void_p)
        self.lib.LZ4F_decompress.restype = ctypes.c_size_t
        self.lib.LZ4F_isError.argtypes = (ctypes.c_size_t,)
        self.lib.LZ4F_isError.restype = ctypes.c_uint

    def canonical_empty(self):
        source, output = ctypes.create_string_buffer(b""), ctypes.create_string_buffer(16)
        size = self.lib.LZ4_compress_default(source, output, 0, len(output))
        assert size == 1 and output.raw[:size] == b"\x00"
        return output.raw[:size]

    def decode(self, encoded, expected, frame=False, prefix=b""):
        source = ctypes.create_string_buffer(encoded)
        output = ctypes.create_string_buffer(max(1, len(expected)))
        if frame:
            state = ctypes.c_void_p()
            assert not self.lib.LZ4F_isError(self.lib.LZ4F_createDecompressionContext(ctypes.byref(state), 100))
            try:
                input_size, output_size = ctypes.c_size_t(len(encoded)), ctypes.c_size_t(len(expected))
                result = self.lib.LZ4F_decompress(state, output, ctypes.byref(output_size), source, ctypes.byref(input_size), None)
                assert not self.lib.LZ4F_isError(result) and result == 0
                assert input_size.value == len(encoded) and output_size.value == len(expected)
            finally:
                self.lib.LZ4F_freeDecompressionContext(state)
        else:
            dictionary = ctypes.create_string_buffer(prefix)
            result = self.lib.LZ4_decompress_safe_usingDict(source, output, len(encoded), len(expected), dictionary, len(prefix))
            assert result == len(expected), (result, len(expected))
        assert output.raw[:len(expected)] == expected


def profile(log):
    line = next(v for v in log.decode().splitlines() if v.startswith("lz4_fast_profile "))
    return {key: int(value) for key, value in (v.split("=", 1) for v in line.split()[1:])}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cli", required=True, type=Path)
    args = parser.parse_args()
    cli = args.cli.resolve()
    reference = Reference()
    rng = random.Random(0xF45A4C)
    samples = {"empty": b"", "repeated": b"abcde 012345 abcde 012345\n" * 32, "random": rng.randbytes(2048)}
    counts = {"reference_round_trips": 0, "raw_empty_legacy_wire_checks": 0,
              "canonical_empty_reverse_decode_checks": 0, "profile_wire_checks": 0, "default_acceleration_wire_checks": 0,
              "normalization_checks": 0, "skipping_work_checks": 0, "prefix_history_checks": 0,
              "zero_chain_checks": 0, "idle_frame_profile_checks": 0, "rejected_output_preserved": 0, "same_path_checks": 0}
    with tempfile.TemporaryDirectory(prefix="vort-lz4-fast-cli-") as text:
        folder = Path(text)
        source, target = folder / "input.raw", folder / "output.lz4"

        def invoke(command, data, flags=(), prefix=b"", input_path=source, output_path=target):
            positional = (data.hex(), prefix.hex()) if command == "encode-lz4-block-prefix-hex" else ((data.hex(),) if command.endswith("hex") else (str(input_path), str(output_path)))
            return subprocess.run([str(cli), command, *positional, *flags], stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        def success(command, data, flags=(), prefix=b""):
            source.write_bytes(data)
            result = invoke(command, data, flags, prefix)
            assert result.returncode == 0, (command, flags, result.stderr.decode(errors="replace"))
            encoded = bytes.fromhex(result.stdout.decode().splitlines()[0]) if command.endswith("hex") else target.read_bytes()
            if not data and not command.startswith("encode-lz4-native"):
                # Vort's historical raw API encodes empty input as an empty
                # slice. This is not a canonical external LZ4 block.
                assert encoded == b""
                restored = subprocess.run([str(cli), "decode-lz4-block-hex", ""], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                assert restored.returncode == 0 and bytes.fromhex(restored.stdout.decode()) == b""
                counts["raw_empty_legacy_wire_checks"] += 1
            else:
                reference.decode(encoded, data, frame=command.startswith("encode-lz4-native"), prefix=prefix)
                counts["reference_round_trips"] += 1
            assert (b"lz4_fast_profile " in result.stdout) == ("--profile" in flags)
            return encoded, result.stdout

        canonical = reference.canonical_empty()
        reverse = subprocess.run([str(cli), "decode-lz4-block-hex", canonical.hex()], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        assert reverse.returncode == 0 and bytes.fromhex(reverse.stdout.decode()) == b""
        counts["canonical_empty_reverse_decode_checks"] += 1

        for command in ("encode-lz4-block-file", "encode-lz4-native-file", "encode-lz4-native-stream-file"):
            for name, data in samples.items():
                default, _ = success(command, data)
                instrumented, log = success(command, data, ("--profile",))
                assert default == instrumented
                explicit, _ = success(command, data, ("--acceleration=1",))
                assert explicit == default
                counts["profile_wire_checks"] += 1
                counts["default_acceleration_wire_checks"] += 1
                fast, _ = success(command, data, ("--acceleration=8", "--chain-depth=3"))
                fast_profiled, fast_log = success(command, data, ("--chain-depth", "3", "--acceleration", "8", "--profile"))
                assert fast == fast_profiled
                p = profile(fast_log)
                if p["blocks_attempted"] > 0:
                    assert p["acceleration"] == 8 and p["chain_depth"] == 3
                else:
                    assert not data and command.startswith("encode-lz4-native")
                    assert p["acceleration"] == 1 and p["chain_depth"] == 16
                    assert all(p[field] == 0 for field in ("positions_inspected", "positions_skipped", "chain_candidates", "history_positions_seeded", "match_positions_seeded", "blocks_attempted", "max_skip_step"))
                    counts["idle_frame_profile_checks"] += 1
                if name == "random":
                    assert p["positions_skipped"] > 0 and p["max_skip_step"] > 1
                    assert p["positions_inspected"] < profile(log)["positions_inspected"]
                    counts["skipping_work_checks"] += 1
                counts["profile_wire_checks"] += 1
            zero, log = success(command, samples["repeated"], ("--chain-depth=0", "--acceleration=8", "--profile"))
            assert profile(log)["chain_depth"] == 0 and profile(log)["chain_candidates"] == 0
            counts["zero_chain_checks"] += 1

        random_data = samples["random"]
        unit, _ = success("encode-lz4-block-hex", random_data, ("--acceleration=1",))
        for acceleration in (-2147483648, -1, 0):
            frame, log = success("encode-lz4-block-hex", random_data, (f"--acceleration={acceleration}", "--profile"))
            assert frame == unit and profile(log)["acceleration"] == 1
            counts["normalization_checks"] += 1
        maximum, _ = success("encode-lz4-block-hex", random_data, ("--acceleration=65537",))
        clamped, log = success("encode-lz4-block-hex", random_data, ("--acceleration=2147483647", "--profile"))
        assert clamped == maximum and profile(log)["acceleration"] == 65537
        counts["normalization_checks"] += 1

        dictionary = rng.randbytes(512)
        data = dictionary[64:256] + dictionary[64:256] + b"last-literals"
        for command, prefix in (("encode-lz4-block-hex", b""), ("encode-lz4-block-prefix-hex", dictionary)):
            for controls in ((), ("--acceleration=8", "--chain-depth=3")):
                first, _ = success(command, data, controls, prefix)
                second, log = success(command, data, controls + ("--profile",), prefix)
                assert first == second
                counts["profile_wire_checks"] += 1
                if prefix:
                    assert profile(log)["history_positions_seeded"] > 0
                    counts["prefix_history_checks"] += 1

        for command in ("encode-lz4-block-file", "encode-lz4-native-file", "encode-lz4-native-stream-file"):
            source.write_bytes(samples["repeated"])
            for flags in (("--chain-depth=17",), ("--acceleration=1", "--acceleration=2"), ("--profile", "--profile"), ("--acceleration",), ("--unknown=1",), ("extra",)):
                sentinel = b"preserve destination on rejected LZ4 controls\n"
                target.write_bytes(sentinel)
                result = invoke(command, samples["repeated"], flags)
                assert result.returncode != 0 and target.read_bytes() == sentinel
                counts["rejected_output_preserved"] += 1
            target.write_bytes(b"preserve missing-input destination")
            result = invoke(command, b"", ("--chain-depth=17",), input_path=folder / "absent.raw")
            assert result.returncode != 0 and b"InvalidBlockPlan" in result.stderr
            assert target.read_bytes() == b"preserve missing-input destination"
            counts["rejected_output_preserved"] += 1
            original = samples["repeated"]
            source.write_bytes(original)
            result = invoke(command, original, ("--chain-depth=17",), input_path=source, output_path=source)
            assert result.returncode != 0 and source.read_bytes() == original
            counts["same_path_checks"] += 1
            result = invoke(command, original, ("--acceleration=8",), input_path=source, output_path=source)
            assert result.returncode == 0
            reference.decode(source.read_bytes(), original, frame=command.startswith("encode-lz4-native"))
            counts["reference_round_trips"] += 1
            counts["same_path_checks"] += 1

    print(json.dumps({**counts, "reference_lz4_version": reference.version}))


if __name__ == "__main__":
    main()
