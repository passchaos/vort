#!/usr/bin/env python3
"""Small CLI contracts for Brotli copy-length policy and per-plan work caps."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

from hq_cli_gate import Reference
from large_window_cli_gate import LargeWindowReference, assert_extension_prefix


def length_profile(log):
    line = next(v for v in log.decode().splitlines() if v.startswith("br_length_profile "))
    fields = dict(v.split("=", 1) for v in line.split()[1:])
    return {key: value if key == "copy_lengths" else int(value) for key, value in fields.items()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cli", required=True, type=Path)
    args = parser.parse_args()
    cli = args.cli.resolve()
    reference = Reference()
    large_reference = LargeWindowReference()
    first = (b"abcd 1234 abcd repeated payload!\n" * 3)[:64]
    samples = {"tiny64": first, "repeated_history": first + first}
    counts = {"round_trips": 0, "default_sampled_wire_checks": 0, "complete_profile_wire_checks": 0,
              "complete_not_larger_checks": 0, "complete_work_checks": 0, "exact_work_cap_checks": 0,
              "one_below_work_cap_checks": 0, "zero_work_cap_rejections": 0,
              "rejected_output_preserved": 0, "same_path_checks": 0}
    observations = []
    with tempfile.TemporaryDirectory(prefix="vort-br-complete-cli-") as text:
        folder = Path(text)
        source = folder / "input.raw"
        target = folder / "output.br"
        plain = b""

        def invoke(command, flags, input_path=source, output_path=target):
            return subprocess.run([str(cli), command, str(input_path), str(output_path), *flags], stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        def success(command, flags, large=False):
            result = invoke(command, flags)
            assert result.returncode == 0, (command, flags, result.stderr.decode(errors="replace"))
            encoded = target.read_bytes()
            if large:
                assert_extension_prefix(encoded, 25)
                large_reference.decode(encoded, plain, True)
            else:
                reference.decode(encoded, plain)
            assert (b"br_length_profile " in result.stdout) == ("--hq-copy-lengths=complete" in flags and "--profile" in flags)
            counts["round_trips"] += 1
            return encoded, result.stdout

        def failure(command, flags, expected_error, input_path=source, output_path=target):
            sentinel = plain if input_path == output_path else b"preserve output on copy-length search rejection\n"
            output_path.write_bytes(sentinel)
            result = invoke(command, flags, input_path, output_path)
            assert result.returncode != 0, (command, flags)
            assert output_path.read_bytes() == sentinel, (command, flags)
            assert expected_error.encode() in result.stderr, result.stderr.decode(errors="replace")
            counts["rejected_output_preserved"] += 1

        # Sixteen small cases exercise both qualities, formats and parse modes,
        # with a second sample retaining history across a meta-block boundary.
        for quality in (10, 11):
            for large in (False, True):
                command = "encode-br-file" if (quality == 10) != large else "encode-br-stream-file"
                for parse_mode in ("bounded", "whole_block"):
                    for sample_name, plain in samples.items():
                        source.write_bytes(plain)
                        base = (f"--quality={quality}", "--hq", "--hq-depth=2", "--hq-nice-len=32",
                                "--hq-beam-width=1", "--hq-iterations=1", "--hq-block-len=64", f"--hq-parse-mode={parse_mode}")
                        if large:
                            base += ("--large-window", "--window-bits=25")
                        sampled, _ = success(command, base, large)
                        if sample_name == "tiny64":
                            explicit, _ = success(command, base + ("--hq-copy-lengths=sampled",), large)
                            assert sampled == explicit, "explicit sampled changed default output"
                            counts["default_sampled_wire_checks"] += 1
                        flags = base + ("--hq-copy-lengths=complete",)
                        complete, _ = success(command, flags, large)
                        profiled, log = success(command, flags + ("--profile",), large)
                        assert complete == profiled, "profile changed complete-policy output"
                        assert len(complete) <= len(sampled), (quality, large, parse_mode, sample_name, len(complete), len(sampled))
                        metadata = length_profile(log)
                        assert metadata["copy_lengths"] == "complete"
                        assert metadata["complete_length_passes"] > 0 and metadata["sampled_length_passes"] > 0, metadata
                        assert metadata["max_copy_length_considered"] >= 2, metadata
                        assert metadata["max_plan_price_evaluations"] > 0, metadata
                        counts["complete_profile_wire_checks"] += 1
                        counts["complete_not_larger_checks"] += 1
                        counts["complete_work_checks"] += 1
                        if parse_mode == "bounded" and sample_name == "tiny64":
                            exact = metadata["max_plan_price_evaluations"]
                            capped, cap_log = success(command, flags + (f"--hq-max-price-evaluations={exact}", "--profile"), large)
                            assert capped == complete
                            assert length_profile(cap_log)["max_plan_price_evaluations"] == exact
                            counts["exact_work_cap_checks"] += 1
                            failure(command, flags + (f"--hq-max-price-evaluations={exact-1}",), "SearchLimitExceeded")
                            counts["one_below_work_cap_checks"] += 1
                        failure(command, flags + ("--hq-max-price-evaluations=0",), "SearchLimitExceeded")
                        counts["zero_work_cap_rejections"] += 1
                        observations.append({"quality": quality, "large_window": large, "parse_mode": parse_mode, "sample": sample_name,
                                             "command": command, "sampled_bytes": len(sampled), "complete_bytes": len(complete), "profile": metadata})

        plain = first
        source.write_bytes(plain)
        for command in ("encode-br-file", "encode-br-stream-file"):
            for flags, expected in (
                (("--hq-copy-lengths=complete",), "InvalidBlockPlan"),
                (("--quality=9", "--hq-copy-lengths=complete"), "InvalidBlockPlan"),
                (("--quality=10", "--hq-copy-lengths=literal"), "InvalidBrotliCopyLengths"),
                (("--quality=10", "--hq-copy-lengths=sampled", "--hq-copy-lengths=complete"), "DuplicateBrotliOption"),
                (("--quality=10", "--hq-max-price-evaluations=1", "--hq-max-price-evaluations=2"), "DuplicateBrotliOption"),
                (("--hq-max-price-evaluations",), "MissingBrotliOptionValue"),
            ):
                failure(command, flags, expected)
            failure(command, ("--quality=9", "--hq-copy-lengths=complete"), "InvalidBlockPlan", folder / "absent.raw")
            failure(command, ("--quality=10", "--hq-copy-lengths=complete", "--hq-max-price-evaluations=0"), "SearchLimitExceeded", source, source)
            counts["same_path_checks"] += 1
            source.write_bytes(plain)

    print(json.dumps({**counts, "observations": observations, "reference_brotli_version": reference.version}))


if __name__ == "__main__":
    main()
