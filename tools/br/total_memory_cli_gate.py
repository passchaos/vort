#!/usr/bin/env python3
"""Check the public Brotli total encoding budget through the thin CLI."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

from hq_cli_gate import Reference


def memory_profile(log):
    line = next(v for v in log.decode().splitlines() if v.startswith("br_memory_profile "))
    result = {}
    for field in line.split()[1:]:
        key, value = field.split("=", 1)
        result[key] = value == "true" if value in ("true", "false") else (None if value == "unlimited" else int(value))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cli", required=True, type=Path)
    args = parser.parse_args()
    cli = args.cli.resolve()
    reference = Reference()
    plain = b"time information compression dictionary repeated repeated data!!"
    assert len(plain) <= 64
    scenarios = (
        ("legacy_default", ()),
        ("quality0", ("--quality=0",)),
        ("quality5", ("--quality=5",)),
        ("quality8_window", ("--quality=8", "--window-bits=20")),
        ("quality11", ("--quality=11",)),
        ("hq10_text", ("--quality=10", "--mode=text", "--hq", "--hq-block-len=32")),
        ("hq11_font", ("--quality=11", "--mode=font", "--hq", "--hq-block-len=32", "--window-bits=20")),
    )
    valid = rejected = wire_checks = exact_checks = one_below_checks = same_path_checks = 0
    measurements = []
    with tempfile.TemporaryDirectory(prefix="vort-br-total-cli-") as name:
        folder = Path(name)
        source = folder / "input.raw"
        target = folder / "output.br"
        source.write_bytes(plain)

        def run(command, flags, input_path=source, output_path=target):
            return subprocess.run([str(cli), command, str(input_path), str(output_path), *flags], stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        def success(command, flags):
            nonlocal valid
            result = run(command, flags)
            assert result.returncode == 0, (command, flags, result.stderr.decode(errors="replace"))
            encoded = target.read_bytes()
            reference.decode(encoded, plain)
            assert (b"br_memory_profile " in result.stdout) == ("--memory-profile" in flags)
            assert b"br_hq_profile " not in result.stdout, "total instrumentation selected HQ profile"
            valid += 1
            return encoded, result.stdout

        def failure(command, flags, input_path=source, output_path=target, expected_error=None):
            nonlocal rejected
            sentinel = plain if input_path == output_path else b"preserve output on total memory rejection\n"
            output_path.write_bytes(sentinel)
            result = run(command, flags, input_path, output_path)
            assert result.returncode != 0, (command, flags)
            assert output_path.read_bytes() == sentinel, (command, flags)
            if expected_error:
                assert expected_error.encode() in result.stderr, result.stderr.decode(errors="replace")
            rejected += 1
            return result

        for command in ("encode-br-file", "encode-br-stream-file"):
            for label, flags in scenarios:
                untracked, _ = success(command, flags)
                tracked, log = success(command, flags + ("--memory-profile",))
                sample = memory_profile(log)
                assert sample["available"] and sample["peak_requested_bytes"] > 0, (command, label, sample)
                assert sample["live_requested_bytes"] == 0 and sample["limit"] is None, sample
                assert tracked == untracked, (command, label, "memory profile changed wire")
                wire_checks += 1
                exact = sample["peak_requested_bytes"]
                capped, capped_log = success(command, flags + (f"--max-total-memory={exact}", "--memory-profile"))
                capped_sample = memory_profile(capped_log)
                assert capped == tracked, (command, label, "exact cap changed wire")
                assert capped_sample["available"] and capped_sample["limit"] == exact
                assert capped_sample["peak_requested_bytes"] == exact and capped_sample["live_requested_bytes"] == 0, capped_sample
                exact_checks += 1
                failure(command, flags + (f"--max-total-memory={exact - 1}",), expected_error="WorkingMemoryLimitExceeded")
                one_below_checks += 1
                failure(command, flags + ("--max-total-memory=0",), expected_error="WorkingMemoryLimitExceeded")
                measurements.append({"command": command, "case": label, "peak_requested_bytes": exact})

            for flags in (("--max-total-memory",), ("--max-total-memory=",), ("--max-total-memory=-1",),
                          ("--max-total-memory=1", "--max-total-memory=2"), ("--memory-profile", "--memory-profile")):
                failure(command, flags)
            failure(command, ("--max-total-memory=-1",), input_path=folder / "absent.raw", expected_error="Overflow")
            failure(command, ("--quality=12", "--max-total-memory=100",), input_path=folder / "absent.raw", expected_error="InvalidBlockPlan")
            failure(command, ("--max-total-memory=0",), input_path=source, output_path=source, expected_error="WorkingMemoryLimitExceeded")
            same_path_checks += 1

        for flags in ((), ("--memory-profile",)):
            result = subprocess.run([str(cli), "encode-br-hex", "bounded memory", *flags], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            assert result.returncode == 0, result.stderr.decode(errors="replace")
            encoded = bytes.fromhex(result.stdout.decode().splitlines()[0])
            reference.decode(encoded, b"bounded memory")
            valid += 1
            if flags:
                sample = memory_profile(result.stdout)
                assert sample["available"] and sample["live_requested_bytes"] == 0

    print(json.dumps({"round_trips": valid, "profile_wire_checks": wire_checks, "exact_cap_checks": exact_checks,
                      "one_below_checks": one_below_checks, "rejected_output_preserved": rejected,
                      "same_path_checks": same_path_checks, "measurements": measurements,
                      "reference_brotli_version": reference.version, "external_dictionary_cli_cases": 0}))


if __name__ == "__main__":
    main()
