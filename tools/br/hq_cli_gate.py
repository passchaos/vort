#!/usr/bin/env python3
"""Bounded Brotli HQ CLI correctness, profile and atomic-output verification."""
import argparse
import ctypes
import ctypes.util
import json
from pathlib import Path
import subprocess
import tempfile


class Reference:
    def __init__(self):
        self.lib = ctypes.CDLL(ctypes.util.find_library("brotlidec"))
        self.lib.BrotliDecoderVersion.restype = ctypes.c_uint
        self.version = self.lib.BrotliDecoderVersion()
        self.lib.BrotliDecoderDecompress.argtypes = (ctypes.c_size_t, ctypes.c_void_p, ctypes.POINTER(ctypes.c_size_t), ctypes.c_void_p)
        self.lib.BrotliDecoderDecompress.restype = ctypes.c_int

    def decode(self, data, expected):
        output = ctypes.create_string_buffer(max(1, len(expected)))
        size = ctypes.c_size_t(len(expected))
        source = ctypes.create_string_buffer(data)
        assert self.lib.BrotliDecoderDecompress(len(data), source, ctypes.byref(size), output) == 1
        assert output.raw[:size.value] == expected


def profile(log):
    line = next(v for v in log.decode().splitlines() if v.startswith("br_hq_profile "))
    result = {}
    for field in line.split()[1:]:
        key, value = field.split("=", 1)
        result[key] = value == "true" if value in ("true", "false") else int(value)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cli", required=True, type=Path)
    args = parser.parse_args()
    cli = args.cli.resolve()
    reference = Reference()
    corpus = {"empty": b"", "tiny": b"x", "text": b"Brotli HQ CLI repeated text fields and phrases.\n" * 24,
              "json": b'{"service":"vort","value":123,"status":"ready"}\n' * 24,
              "font": bytes(range(128)) * 8}
    valid = rejected = profile_checks = samepath = equivalent = 0
    work = {}
    with tempfile.TemporaryDirectory(prefix="vort-br-hq-cli-") as text:
        folder = Path(text)
        source = folder / "input.raw"
        target = folder / "output.br"

        def invoke(command, flags, input_path=source, output_path=target):
            return subprocess.run([str(cli), command, str(input_path), str(output_path), *flags], stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        def success(command, flags, expected, input_path=source, output_path=target):
            nonlocal valid
            result = invoke(command, flags, input_path, output_path)
            assert result.returncode == 0, result.stderr.decode(errors="replace")
            encoded = output_path.read_bytes()
            reference.decode(encoded, expected)
            assert (b"br_hq_profile " in result.stdout) == ("--profile" in flags)
            valid += 1
            return encoded, result.stdout

        def failure(command, flags, input_path=source, output_path=target, existing=None):
            nonlocal rejected
            sentinel = existing if existing is not None else b"preserve existing output on every rejected option\n"
            output_path.write_bytes(sentinel)
            result = invoke(command, flags, input_path, output_path)
            assert result.returncode != 0, (command, flags)
            assert output_path.read_bytes() == sentinel, (command, flags)
            rejected += 1
            return result

        for command in ("encode-br-file", "encode-br-stream-file"):
            for quality in (10, 11):
                for mode in ("generic", "text", "font"):
                    totals = {"tree_nodes": 0, "price_evaluations": 0, "passes": 0, "refinement_passes": 0, "emitted_metablocks": 0}
                    flags = (f"--quality={quality}", f"--mode={mode}", "--hq", "--hq-block-len=64", "--hq-memory=33554432")
                    for name, plain in corpus.items():
                        source.write_bytes(plain)
                        first, _ = success(command, flags, plain)
                        second, log = success(command, flags + ("--profile",), plain)
                        assert first == second, (command, quality, mode, name, "profile changed wire")
                        metadata = profile(log)
                        assert metadata["effective"] and metadata["quality"] == quality
                        assert metadata["depth"] == 64 and metadata["nice_len"] == 128
                        assert metadata["beam_width"] == (8 if quality == 10 else 16)
                        assert metadata["iterations"] == (1 if quality == 10 else 2)
                        assert (metadata["npostfix"], metadata["ndirect_high"]) == ((1, 6) if mode == "font" else (0, 0))
                        assert metadata["peak_working_memory"] <= 33554432
                        for key in totals: totals[key] += metadata[key]
                        if command == "encode-br-stream-file" and len(plain) > 64:
                            assert metadata["emitted_metablocks"] >= 2
                        profile_checks += 1
                    assert totals["tree_nodes"] > 0 and totals["price_evaluations"] > 0 and totals["passes"] > 0, totals
                    if quality == 11: assert totals["refinement_passes"] > 0, totals
                    work[f"{command}:{quality}:{mode}"] = totals

            source.write_bytes(corpus["json"])
            for quality in (0, 5, 9, 10, 11):
                a, _ = success(command, (str(quality), "generic", "16"), corpus["json"])
                b, _ = success(command, (f"--quality={quality}", "--mode=generic", "--window-bits=16"), corpus["json"])
                assert a == b, (command, quality, "positional/flag mapping changed wire")
                equivalent += 1
            success(command, (), corpus["json"])
            bad = (("--hq",), ("--quality=9", "--hq"), ("--quality=12",), ("--mode=unknown",), ("--window-bits=9",),
                   ("--quality=10", "--hq-depth=0"), ("--quality=10", "--hq-depth=65537"), ("--quality=10", "--hq-nice-len=1"),
                   ("--quality=10", "--hq-nice-len=16777217"), ("--quality=10", "--hq-beam-width=33"), ("--quality=10", "--hq-iterations=9"),
                   ("--quality=10", "--hq-block-len=0"), ("--quality=10", "--hq-block-len=16777217"), ("--quality=10", "--hq-npostfix=4"),
                   ("--quality=10", "--hq-ndirect-high=16"), ("--quality=11", "--profile"), ("--hq", "--hq"), ("--quality=10", "--quality=10"),
                   ("--hq-depth",), ("--hq-unknown=1",), ("10", "generic", "16", "extra"))
            for flags in bad: failure(command, flags)
            early = failure(command, ("--quality=10", "--hq-depth=0"), folder / "absent.raw")
            assert b"InvalidBlockPlan" in early.stderr
            for limit in (0, 1): failure(command, ("--quality=10", "--hq", f"--hq-memory={limit}"))
            original = corpus["text"]
            source.write_bytes(original)
            failure(command, ("--quality=9", "--hq"), source, source, existing=original)
            samepath += 1
            source.write_bytes(original)
            success(command, ("--quality=10", "--hq", "--hq-block-len=64"), original, source, source)
            samepath += 1

        for quality in (10, 11):
            result = subprocess.run([str(cli), "encode-br-hex", "HQ text text text", f"--quality={quality}", "--hq"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            assert result.returncode == 0, result.stderr.decode(errors="replace")
            reference.decode(bytes.fromhex(result.stdout.decode()), b"HQ text text text")
            valid += 1

    print(json.dumps({"round_trips": valid, "profile_wire_checks": profile_checks, "rejected_output_preserved": rejected,
                      "same_path_checks": samepath, "null_hq_mapping_wire_checks": equivalent, "hq_work": work, "reference_brotli_version": reference.version}))


if __name__ == "__main__": main()
