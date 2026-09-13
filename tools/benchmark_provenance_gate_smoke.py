#!/usr/bin/env python3
"""Exercise shared benchmark provenance gate validation."""

from __future__ import annotations

import hashlib
import json
import platform
import tempfile
from pathlib import Path
from urllib.parse import quote

from benchmark_provenance_gate import (
    validate_artifact_manifest_record,
    validate_provenance,
)
from benchmark_provenance import (
    executable_artifact,
    file_artifact,
    generated_source_tree_artifact,
    rustc_host,
    tool_version,
    verify_artifact_manifest,
)


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

        manifest = {
            "artifacts": [
                {
                    "kind": "executable",
                    "role": "vort_benchmark",
                    "sha256": valid["executable_sha256"],
                }
            ],
            "cargo_version": "cargo smoke",
            "python_version": "3.12.0",
            "rustc_host": "x86_64-unknown-linux-gnu",
            "rustc_version": "rustc smoke",
            "rustflags": "-C target-cpu=native",
            "schema": "vort.benchmark_artifact_set",
            "version": 1,
        }
        canonical = json.dumps(manifest, sort_keys=True, separators=(",", ":"))
        valid_v2 = valid | {
            "provenance_version": "2",
            "artifact_set_sha256": hashlib.sha256(canonical.encode()).hexdigest(),
            "artifact_manifest": quote(canonical, safe="-._~"),
        }
        assert validate_artifact_manifest_record(valid_v2) == manifest
        validate_provenance(
            [valid_v2], executable=executable, codec_thread_policy="single"
        )
        checks += 2

        malformed_manifests = (
            (manifest | {"artifacts": []}, "invalid artifact manifest entries"),
            (manifest | {"artifacts": manifest["artifacts"] * 2}, "invalid or duplicate artifact role"),
            (manifest | {"artifacts": [{"kind": "file", "role": "driver", "sha256": "bad"}]}, "invalid artifact hash"),
            (manifest | {"artifacts": [{"kind": "file", "role": "driver", "sha256": "b" * 64}]}, "primary executable is missing"),
            (manifest | {"rustc_version": ""}, "invalid artifact environment field"),
        )
        for bad_manifest, message in malformed_manifests:
            bad_canonical = json.dumps(
                bad_manifest, sort_keys=True, separators=(",", ":")
            )
            candidate = valid_v2 | {
                "artifact_set_sha256": hashlib.sha256(bad_canonical.encode()).hexdigest(),
                "artifact_manifest": quote(bad_canonical, safe="-._~"),
            }
            try:
                validate_artifact_manifest_record(candidate)
            except AssertionError as error:
                if message not in str(error):
                    raise AssertionError(
                        f"expected {message!r}, received {str(error)!r}"
                    ) from error
            else:
                raise AssertionError(f"expected manifest failure containing {message!r}")
            checks += 1

        driver = Path(name) / "driver.py"
        runner_source = Path(name) / "runner-source"
        runner_source.mkdir()
        runner_file = runner_source / "main.rs"
        driver.write_bytes(b"print('driver')\n")
        runner_file.write_bytes(b"fn main() {}\n")
        disk_manifest = {
            "artifacts": [
                file_artifact("driver", driver),
                executable_artifact("executable", executable),
                generated_source_tree_artifact("runner_source", runner_source),
            ],
            "cargo_version": tool_version("cargo"),
            "python_version": platform.python_version(),
            "rustc_host": rustc_host(),
            "rustc_version": tool_version("rustc"),
            "rustflags": "-C target-cpu=native",
            "schema": "vort.benchmark_artifact_set",
            "version": 1,
        }
        disk_canonical = json.dumps(
            disk_manifest, sort_keys=True, separators=(",", ":")
        )
        disk_record = valid | {
            "provenance_version": "2",
            "artifact_set_sha256": hashlib.sha256(disk_canonical.encode()).hexdigest(),
            "artifact_manifest": quote(disk_canonical, safe="-._~"),
        }
        expected = {
            "driver": ("file", driver),
            "executable": ("executable", executable),
            "runner_source": ("generated-source-tree", runner_source),
        }
        assert verify_artifact_manifest(disk_record, expected) == disk_manifest
        checks += 1
        for path, replacement in (
            (driver, b"changed driver\n"),
            (runner_file, b"fn main() { panic!() }\n"),
        ):
            original = path.read_bytes()
            path.write_bytes(replacement)
            try:
                verify_artifact_manifest(disk_record, expected)
            except AssertionError as error:
                assert "artifact mismatch" in str(error)
            else:
                raise AssertionError(f"expected artifact tamper failure for {path}")
            path.write_bytes(original)
            checks += 1

        failures = (
            ({"provenance_version": "3"}, "unsupported provenance"),
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
