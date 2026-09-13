#!/usr/bin/env python3
"""Capture and verify composite benchmark artifact provenance."""

from __future__ import annotations

import csv
import hashlib
import io
import json
import platform
import subprocess
import sys
from pathlib import Path
from urllib.parse import quote

from benchmark_provenance_gate import (
    PROVENANCE_COLUMNS,
    PROVENANCE_V2_COLUMNS,
    is_sha256,
    validate_artifact_manifest_record,
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def source_tree_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    files = sorted(
        candidate
        for candidate in path.rglob("*")
        if candidate.is_file()
        and ".git" not in candidate.relative_to(path).parts
        and "target" not in candidate.relative_to(path).parts
        and "__pycache__" not in candidate.relative_to(path).parts
    )
    if not files:
        raise AssertionError(f"source tree contains no files: {path}")
    for candidate in files:
        relative = candidate.relative_to(path).as_posix().encode()
        content = candidate.read_bytes()
        digest.update(len(relative).to_bytes(8, "big"))
        digest.update(relative)
        digest.update(len(content).to_bytes(8, "big"))
        digest.update(content)
    return digest.hexdigest()


def git_metadata(path: Path) -> tuple[str, bool]:
    def git(*args: str) -> str:
        return subprocess.run(
            ["git", "-C", str(path), *args],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
        ).stdout.strip()

    return git("rev-parse", "HEAD"), bool(git("status", "--porcelain", "--", "."))


def command_text(argv: list[str]) -> str:
    return " ".join(quote(argument, safe="-._/:=") for argument in argv)


def executable_artifact(role: str, path: Path) -> dict[str, object]:
    return {"kind": "executable", "role": role, "sha256": sha256_file(path)}


def file_artifact(role: str, path: Path) -> dict[str, object]:
    return {"kind": "file", "role": role, "sha256": sha256_file(path)}


def source_tree_artifact(role: str, path: Path) -> dict[str, object]:
    commit, dirty = git_metadata(path)
    return {
        "git_commit": commit,
        "git_dirty": dirty,
        "kind": "source-tree",
        "role": role,
        "sha256": source_tree_sha256(path),
    }


def generated_source_tree_artifact(role: str, path: Path) -> dict[str, object]:
    return {
        "kind": "generated-source-tree",
        "role": role,
        "sha256": source_tree_sha256(path),
    }


def tool_version(command: str) -> str:
    return subprocess.run(
        [command, "--version"],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    ).stdout.strip()


def rustc_host() -> str:
    output = subprocess.run(
        ["rustc", "-vV"],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    ).stdout.splitlines()
    return next(line.removeprefix("host: ") for line in output if line.startswith("host: "))


def read_vort_provenance(executable: Path) -> dict[str, str]:
    output = subprocess.run(
        [str(executable), "--benchmark-provenance"],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    ).stdout
    rows = list(csv.DictReader(io.StringIO(output), strict=True))
    if len(rows) != 1 or set(rows[0]) != set(PROVENANCE_COLUMNS):
        raise AssertionError("invalid Vort benchmark provenance response")
    return rows[0]


def capture_composite(
    *,
    vort_executable: Path,
    driver: Path,
    runner_project: Path,
    runner_executable: Path,
    fdeflate: Path,
    miniz_oxide: Path,
    argv: list[str],
    extra_environment: dict[str, str] | None = None,
) -> dict[str, str]:
    provenance = read_vort_provenance(vort_executable)
    if provenance["optimize"] != "ReleaseFast":
        raise AssertionError("Deflate benchmark requires a ReleaseFast Vort artifact")
    artifacts = [
        file_artifact("python_driver", driver),
        file_artifact("python_provenance", Path(__file__).resolve()),
        file_artifact("python_provenance_gate", Path(__file__).with_name("benchmark_provenance_gate.py").resolve()),
        file_artifact("python_deflate_common", Path(__file__).with_name("rust_deflate_benchmark_common.py").resolve()),
        executable_artifact("python_interpreter", Path(sys.executable).resolve()),
        executable_artifact("vort_benchmark", vort_executable),
        generated_source_tree_artifact("rust_runner_source", runner_project),
        executable_artifact("rust_runner", runner_executable),
        source_tree_artifact("fdeflate_source", fdeflate),
        source_tree_artifact("miniz_oxide_source", miniz_oxide),
    ]
    manifest = {
        "artifacts": artifacts,
        "cargo_version": tool_version("cargo"),
        "python_version": platform.python_version(),
        "rustc_version": tool_version("rustc"),
        "rustc_host": rustc_host(),
        "rustflags": "-C target-cpu=native",
        "schema": "vort.benchmark_artifact_set",
        "version": 1,
    }
    if extra_environment:
        manifest["extra_environment"] = dict(sorted(extra_environment.items()))
    canonical = json.dumps(manifest, sort_keys=True, separators=(",", ":"))
    provenance.update({
        "provenance_version": "2",
        "command": command_text(argv),
        "artifact_set_sha256": hashlib.sha256(canonical.encode()).hexdigest(),
        "artifact_manifest": quote(canonical, safe="-._~"),
    })
    vort_artifact = next(artifact for artifact in artifacts if artifact["role"] == "vort_benchmark")
    if provenance["executable_sha256"] != vort_artifact["sha256"]:
        raise AssertionError("Vort executable self-hash mismatch")
    return provenance


def provenance_csv_values(provenance: dict[str, str]) -> str:
    return ",".join(provenance[column] for column in PROVENANCE_COLUMNS + PROVENANCE_V2_COLUMNS)


def verify_artifact_manifest(
    provenance: dict[str, str],
    expected: dict[str, tuple[str, Path]],
    expected_extra_environment: dict[str, str] | None = None,
) -> dict[str, object]:
    manifest = validate_artifact_manifest_record(provenance)
    expected_environment = {
        "cargo_version": tool_version("cargo"),
        "python_version": platform.python_version(),
        "rustc_host": rustc_host(),
        "rustc_version": tool_version("rustc"),
        "rustflags": "-C target-cpu=native",
    }
    for key, value in expected_environment.items():
        if manifest.get(key) != value:
            raise AssertionError(f"artifact environment mismatch for {key}")
    if manifest.get("extra_environment", {}) != (expected_extra_environment or {}):
        raise AssertionError("artifact extra environment mismatch")
    artifacts = manifest.get("artifacts")
    if not isinstance(artifacts, list):
        raise AssertionError("invalid artifact manifest entries")
    by_role = {entry.get("role"): entry for entry in artifacts if isinstance(entry, dict)}
    if len(by_role) != len(artifacts) or set(by_role) != set(expected):
        raise AssertionError(f"unexpected artifact roles: {sorted(by_role)}")
    for role, (kind, path) in expected.items():
        actual = (
            source_tree_artifact(role, path)
            if kind == "source-tree"
            else generated_source_tree_artifact(role, path)
            if kind == "generated-source-tree"
            else executable_artifact(role, path)
            if kind == "executable"
            else file_artifact(role, path)
        )
        if by_role[role] != actual:
            raise AssertionError(f"artifact mismatch for {role}")
    if not is_sha256(provenance["artifact_set_sha256"]):
        raise AssertionError("invalid artifact set hash")
    return manifest
