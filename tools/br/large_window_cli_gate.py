#!/usr/bin/env python3
"""Bounded validation for the explicitly selected Brotli Large Window CLI."""
import argparse
import ctypes
import ctypes.util
import json
from pathlib import Path
import subprocess
import tempfile

from hq_cli_gate import Reference, profile
from total_memory_cli_gate import memory_profile


class LargeWindowReference:
    def __init__(self):
        self.lib = ctypes.CDLL(ctypes.util.find_library("brotlidec"))
        self.lib.BrotliDecoderVersion.restype = ctypes.c_uint
        self.version = self.lib.BrotliDecoderVersion()
        self.lib.BrotliDecoderCreateInstance.argtypes = (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p)
        self.lib.BrotliDecoderCreateInstance.restype = ctypes.c_void_p
        self.lib.BrotliDecoderDestroyInstance.argtypes = (ctypes.c_void_p,)
        self.lib.BrotliDecoderSetParameter.argtypes = (ctypes.c_void_p, ctypes.c_int, ctypes.c_uint)
        self.lib.BrotliDecoderSetParameter.restype = ctypes.c_int
        self.lib.BrotliDecoderDecompressStream.argtypes = (
            ctypes.c_void_p, ctypes.POINTER(ctypes.c_size_t), ctypes.POINTER(ctypes.c_void_p),
            ctypes.POINTER(ctypes.c_size_t), ctypes.POINTER(ctypes.c_void_p), ctypes.POINTER(ctypes.c_size_t),
        )
        self.lib.BrotliDecoderDecompressStream.restype = ctypes.c_int

    def decode(self, encoded, plain, allow_large_window):
        state = self.lib.BrotliDecoderCreateInstance(None, None, None)
        assert state
        try:
            if allow_large_window:
                # BROTLI_DECODER_PARAM_LARGE_WINDOW = 1; do not silently skip.
                assert self.lib.BrotliDecoderSetParameter(state, 1, 1) == 1
            source = ctypes.create_string_buffer(encoded)
            output = ctypes.create_string_buffer(max(1, len(plain)))
            available_in = ctypes.c_size_t(len(encoded))
            available_out = ctypes.c_size_t(len(plain))
            next_in = ctypes.c_void_p(ctypes.addressof(source))
            next_out = ctypes.c_void_p(ctypes.addressof(output))
            status = self.lib.BrotliDecoderDecompressStream(
                state, ctypes.byref(available_in), ctypes.byref(next_in), ctypes.byref(available_out), ctypes.byref(next_out), None,
            )
            if allow_large_window:
                assert status == 1 and available_in.value == 0 and available_out.value == 0
                assert output.raw[:len(plain)] == plain
            else:
                assert status == 0, "ordinary decoder unexpectedly accepted extension"
        finally:
            self.lib.BrotliDecoderDestroyInstance(state)


def assert_extension_prefix(encoded, width):
    assert len(encoded) >= 2
    low14 = int.from_bytes(encoded[:2], "little") & 0x3FFF
    assert low14 == (0x11 | (width << 8)), (encoded[:2].hex(), width, low14)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cli", required=True, type=Path)
    args = parser.parse_args()
    cli = args.cli.resolve()
    reference = LargeWindowReference()
    standard_reference = Reference()
    plain = (b"Large Window Brotli CLI repeat!\n" * 2)[:64]
    counts = {"round_trips": 0, "extension_prefix_checks": 0, "strict_decoder_rejections": 0,
              "profile_wire_checks": 0, "exact_cap_checks": 0, "one_below_checks": 0,
              "rejected_output_preserved": 0, "same_path_checks": 0, "standard_profile_wire_checks": 0}
    measurements = []
    with tempfile.TemporaryDirectory(prefix="vort-br-large-cli-") as text:
        folder = Path(text)
        source = folder / "input.raw"
        target = folder / "output.br"
        source.write_bytes(plain)

        def invoke(command, flags, input_path=source, output_path=target):
            return subprocess.run([str(cli), command, str(input_path), str(output_path), *flags], stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        def success(command, flags, width, large=True, input_path=source, output_path=target):
            result = invoke(command, flags, input_path, output_path)
            assert result.returncode == 0, (command, flags, result.stderr.decode(errors="replace"))
            encoded = output_path.read_bytes()
            if large:
                assert_extension_prefix(encoded, width)
                counts["extension_prefix_checks"] += 1
                reference.decode(encoded, plain, True)
                reference.decode(encoded, plain, False)
                counts["strict_decoder_rejections"] += 1
            else:
                assert int.from_bytes(encoded[:2], "little") & 0xFF != 0x11
                standard_reference.decode(encoded, plain)
            counts["round_trips"] += 1
            if "--profile" in flags:
                metadata = profile(result.stdout)
                assert metadata["effective"] and metadata["passes"] > 0 and metadata["states"] > 0 and metadata["price_evaluations"] > 0, metadata
                format_lines = [v for v in result.stdout.decode().splitlines() if v.startswith("br_format_profile ")]
                assert format_lines == (["br_format_profile format=large_window"] if large else []), format_lines
            return encoded, result.stdout

        def failure(command, flags, input_path=source, output_path=target, expected_error=None):
            sentinel = plain if input_path == output_path else b"preserve output on rejected Large Window controls\n"
            output_path.write_bytes(sentinel)
            result = invoke(command, flags, input_path, output_path)
            assert result.returncode != 0, (command, flags)
            assert output_path.read_bytes() == sentinel
            if expected_error:
                assert expected_error.encode() in result.stderr, result.stderr.decode(errors="replace")
            counts["rejected_output_preserved"] += 1

        for command in ("encode-br-file", "encode-br-stream-file"):
            for quality in (10, 11):
                core = (f"--quality={quality}", "--hq", "--hq-depth=8", "--hq-beam-width=2", "--hq-iterations=1", "--hq-block-len=32")
                for width in (16, 25, 30):
                    flags = core + ("--large-window", f"--window-bits={width}")
                    first, _ = success(command, flags, width)
                    second, log = success(command, tuple(reversed(flags)) + ("--profile", "--memory-profile"), width)
                    assert first == second, (command, quality, width, "profile or flag order changed wire")
                    counts["profile_wire_checks"] += 1
                    memory = memory_profile(log)
                    assert memory["available"] and memory["live_requested_bytes"] == 0
                    if width == 25:
                        exact = memory["peak_requested_bytes"]
                        capped, _ = success(command, flags + (f"--max-total-memory={exact}", "--memory-profile"), width)
                        assert capped == first
                        counts["exact_cap_checks"] += 1
                        failure(command, flags + (f"--max-total-memory={exact-1}",), expected_error="WorkingMemoryLimitExceeded")
                        counts["one_below_checks"] += 1
                        measurements.append({"command": command, "quality": quality, "width": width, "peak_requested_bytes": exact})
                standard_flags = core + ("--window-bits=16",)
                standard, _ = success(command, standard_flags, 16, large=False)
                tracked, _ = success(command, standard_flags + ("--profile",), 16, large=False)
                assert standard == tracked
                counts["standard_profile_wire_checks"] += 1

            for invalid in (("--large-window",), ("--large-window", "--quality=10"), ("--large-window", "--quality=9", "--hq"),
                            ("--large-window", "--quality=11", "--hq", "--window-bits=31"), ("--quality=11", "--hq", "--window-bits=25"),
                            ("--large-window", "--quality=11", "--hq", "--window-bits=9"), ("--large-window", "--large-window")):
                failure(command, invalid)
            failure(command, ("--large-window",), folder / "absent.raw", expected_error="InvalidBlockPlan")
            source.write_bytes(plain)
            failure(command, ("--large-window", "--quality=9", "--hq"), source, source, expected_error="InvalidBlockPlan")
            counts["same_path_checks"] += 1
            source.write_bytes(plain)
            success(command, ("--large-window", "--quality=11", "--hq", "--hq-beam-width=2", "--hq-iterations=1", "--window-bits=30"), 30, input_path=source, output_path=source)
            counts["same_path_checks"] += 1
            source.write_bytes(plain)

    print(json.dumps({**counts, "measurements": measurements, "reference_brotli_version": reference.version}))


if __name__ == "__main__":
    main()
