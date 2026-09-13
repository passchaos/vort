#!/usr/bin/env python3
"""Exercise shared benchmark provenance gate validation."""

from __future__ import annotations

import hashlib
import tempfile
from pathlib import Path

from benchmark_provenance_gate import validate_provenance


def expect_failure(row: dict[str, str], message: str, executable: Path) -> None:
    try:
        validate_provenance(
            [row], executable=executable, codec_thread_policy="single"
        )
    except AssertionError as error:
        if message not in str(error):
            raise AssertionError(
                f"expected {message!r}, received {str(error)!r}"
            ) from error
    else:
        raise AssertionError(f"expected provenance failure containing {message!r}")


def main() -> int:
    checks = 0
    with tempfile.TemporaryDirectory(prefix="vort-provenance-gate-") as name:
        executable = Path(name) / "benchmark"
        executable.write_bytes(b"benchmark artifact")
        valid = {
            "provenance_version": "1",
            "optimize": "ReleaseFast",
            "zig_version": "0.16.0",
            "target_arch": "x86_64",
            "target_os": "linux",
            "target_abi": "gnu",
            "target_cpu": "raptorlake",
            "cpu_model": "smoke-cpu",
            "cpu_affinity": "2-4;8",
            "affinity_cpu_count": "4",
            "benchmark_threads": "1",
            "codec_thread_policy": "single",
            "executable_sha256": hashlib.sha256(executable.read_bytes()).hexdigest(),
            "command": "benchmark%20--iterations%20100",
            "input_sha256": hashlib.sha256(b"input").hexdigest(),
        }
        values = validate_provenance(
            [valid, dict(valid)],
            executable=executable,
            codec_thread_policy="single",
        )
        assert values["cpu_affinity"] == "2-4;8"
        checks += 1

        failures = (
            ({"provenance_version": "2"}, "unsupported provenance"),
            ({"optimize": "Debug"}, "non-ReleaseFast benchmark"),
            ({"cpu_affinity": "4-2"}, "invalid cpu_affinity"),
            ({"cpu_affinity": "2-4;4"}, "invalid cpu_affinity"),
            ({"affinity_cpu_count": "3"}, "invalid CPU/thread provenance"),
            ({"benchmark_threads": "0"}, "invalid CPU/thread provenance"),
            ({"codec_thread_policy": "internal-auto"}, "invalid CPU/thread provenance"),
            ({"executable_sha256": "bad"}, "invalid executable hash"),
            ({"command": "benchmark,--bad"}, "command is not CSV-safe"),
            ({"input_sha256": "bad"}, "invalid input hash"),
        )
        for override, message in failures:
            expect_failure(valid | override, message, executable)
            checks += 1

        changed = Path(name) / "changed-benchmark"
        changed.write_bytes(b"different artifact")
        expect_failure(valid, "executable hash mismatch", changed)
        checks += 1

        inconsistent = dict(valid)
        inconsistent["cpu_model"] = "other-cpu"
        try:
            validate_provenance(
                [valid, inconsistent],
                executable=executable,
                codec_thread_policy="single",
            )
        except AssertionError as error:
            assert "inconsistent provenance" in str(error)
        else:
            raise AssertionError("expected inconsistent provenance failure")
        checks += 1

    print(f"benchmark_provenance_gate_smoke=ok checks={checks}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
