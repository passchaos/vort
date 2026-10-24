#!/usr/bin/env python3
"""Bounded CLI validation for opt-in Brotli whole-meta-block parsing."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

from hq_cli_gate import Reference
from large_window_cli_gate import LargeWindowReference, assert_extension_prefix
from total_memory_cli_gate import memory_profile


def parse_profile(log):
    line = next(v for v in log.decode().splitlines() if v.startswith("br_parse_profile "))
    fields = dict(v.split("=", 1) for v in line.split()[1:])
    return {key: value if key == "parse_mode" else int(value) for key, value in fields.items()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cli", required=True, type=Path)
    args = parser.parse_args()
    cli = args.cli.resolve()
    standard = Reference()
    large = LargeWindowReference()
    counts = {"round_trips": 0, "default_bounded_wire_checks": 0, "whole_profile_wire_checks": 0,
              "whole_not_larger_checks": 0, "whole_span_checks": 0, "rejected_output_preserved": 0,
              "same_path_checks": 0, "exact_cap_checks": 0, "one_below_checks": 0}
    observations = []
    seed = b"abcd 0123456789 abcd repeated middle values tail\n"
    with tempfile.TemporaryDirectory(prefix="vort-br-whole-cli-") as text:
        folder = Path(text)
        source = folder / "input.raw"
        target = folder / "output.br"
        current = b""

        def invoke(command, flags, input_path=source, output_path=target):
            return subprocess.run([str(cli), command, str(input_path), str(output_path), *flags], stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        def success(command, flags, large_window=False, input_path=source, output_path=target):
            result = invoke(command, flags, input_path, output_path)
            assert result.returncode == 0, (command, flags, result.stderr.decode(errors="replace"))
            encoded = output_path.read_bytes()
            if large_window:
                assert_extension_prefix(encoded, 25)
                large.decode(encoded, current, True)
            else:
                standard.decode(encoded, current)
            assert (b"br_parse_profile " in result.stdout) == ("--hq-parse-mode=whole_block" in flags and "--profile" in flags)
            counts["round_trips"] += 1
            return encoded, result.stdout

        def failure(command, flags, expected="InvalidBlockPlan", input_path=source, output_path=target):
            sentinel = current if input_path == output_path else b"preserve output when whole parse is rejected\n"
            output_path.write_bytes(sentinel)
            result = invoke(command, flags, input_path, output_path)
            assert result.returncode != 0, (command, flags)
            assert output_path.read_bytes() == sentinel
            assert expected.encode() in result.stderr, result.stderr.decode(errors="replace")
            counts["rejected_output_preserved"] += 1

        # Eight representative cases: both qualities/formats/sizes, and both
        # public one-shot and incremental CLI paths. Small inputs cross two
        # meta-blocks; larger inputs prove a parse span beyond bounded 4096.
        for quality in (10, 11):
            for large_window in (False, True):
                command = "encode-br-file" if (quality == 10) != large_window else "encode-br-stream-file"
                for length in (128, 4100):
                    current = (seed * ((length + len(seed) - 1) // len(seed)))[:length]
                    source.write_bytes(current)
                    block_len = 64 if length == 128 else length
                    base = (f"--quality={quality}", "--hq", "--hq-depth=2", "--hq-nice-len=32", "--hq-beam-width=1", "--hq-iterations=1", f"--hq-block-len={block_len}")
                    if large_window:
                        base += ("--large-window", "--window-bits=25")
                    bounded, _ = success(command, base, large_window)
                    if length == 128:
                        explicit_bounded, _ = success(command, base + ("--hq-parse-mode=bounded",), large_window)
                        assert bounded == explicit_bounded, "explicit bounded changed default wire"
                        counts["default_bounded_wire_checks"] += 1
                    whole_flags = base + ("--hq-parse-mode=whole_block",)
                    whole, _ = success(command, whole_flags, large_window)
                    instrumented, log = success(command, whole_flags + ("--profile", "--memory-profile"), large_window)
                    assert whole == instrumented, "instrumentation changed whole output"
                    assert len(whole) <= len(bounded), (command, quality, large_window, length, len(whole), len(bounded))
                    data = parse_profile(log)
                    assert data["parse_mode"] == "whole_block"
                    assert data["whole_block_passes"] > 0 and data["bounded_passes"] > 0, data
                    assert data["max_parse_positions"] >= min(length, block_len), data
                    counts["whole_profile_wire_checks"] += 1
                    counts["whole_not_larger_checks"] += 1
                    counts["whole_span_checks"] += 1
                    memory = memory_profile(log)
                    assert memory["available"] and memory["live_requested_bytes"] == 0, memory
                    if quality == 10 and not large_window and length == 128:
                        exact = memory["peak_requested_bytes"]
                        capped, _ = success(command, whole_flags + (f"--max-total-memory={exact}",), large_window)
                        assert capped == whole
                        counts["exact_cap_checks"] += 1
                        failure(command, whole_flags + (f"--max-total-memory={exact-1}",), "WorkingMemoryLimitExceeded")
                        counts["one_below_checks"] += 1
                    failure(command, whole_flags + ("--hq-memory=0",), "WorkingMemoryLimitExceeded")
                    observations.append({"quality": quality, "large_window": large_window, "input_bytes": length, "block_len": block_len,
                                         "command": command, "bounded_bytes": len(bounded), "whole_bytes": len(whole), "profile": data})

        current = seed * 2
        source.write_bytes(current)
        for command in ("encode-br-file", "encode-br-stream-file"):
            for flags, expected in (
                (("--hq-parse-mode=whole_block",), "InvalidBlockPlan"),
                (("--quality=9", "--hq-parse-mode=whole_block"), "InvalidBlockPlan"),
                (("--quality=10", "--hq-parse-mode=invalid"), "InvalidBrotliParseMode"),
                (("--quality=10", "--hq-parse-mode=bounded", "--hq-parse-mode=whole_block"), "DuplicateBrotliOption"),
            ):
                failure(command, flags, expected)
            failure(command, ("--hq-parse-mode=whole_block",), "InvalidBlockPlan", folder / "absent.raw")
            failure(command, ("--quality=9", "--hq-parse-mode=whole_block"), "InvalidBlockPlan", source, source)
            counts["same_path_checks"] += 1
            source.write_bytes(current)

    print(json.dumps({**counts, "observations": observations, "reference_brotli_version": standard.version}))


if __name__ == "__main__":
    main()
