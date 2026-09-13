#!/usr/bin/env python3
"""Shared validation for reproducible benchmark CSV provenance."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from urllib.parse import quote, unquote


PROVENANCE_COLUMNS = [
    "provenance_version",
    "optimize",
    "zig_version",
    "target_arch",
    "target_os",
    "target_abi",
    "target_cpu",
    "cpu_model",
    "cpu_affinity",
    "affinity_cpu_count",
    "benchmark_threads",
    "codec_thread_policy",
    "executable_sha256",
    "command",
]
PROVENANCE_V2_COLUMNS = ["artifact_set_sha256", "artifact_manifest"]
HEX = frozenset("0123456789abcdef")


def is_sha256(value: str) -> bool:
    return len(value) == 64 and set(value) <= HEX


def affinity_count(value: str) -> int:
    count = 0
    previous_end = -1
    try:
        for item in value.split(";"):
            parts = item.split("-")
            if len(parts) == 1:
                start = end = int(parts[0])
            elif len(parts) == 2:
                start, end = map(int, parts)
            else:
                raise ValueError
            if start < 0 or end < start or start <= previous_end:
                raise ValueError
            count += end - start + 1
            previous_end = end
    except ValueError as error:
        raise AssertionError(f"invalid cpu_affinity: {value!r}") from error
    return count


def validate_artifact_manifest_record(values: dict[str, str]) -> dict[str, object]:
    artifact_set_sha256 = values["artifact_set_sha256"]
    if not is_sha256(artifact_set_sha256):
        raise AssertionError(f"invalid artifact set hash: {values!r}")
    encoded = values["artifact_manifest"]
    if any(character in encoded for character in ",\r\n"):
        raise AssertionError(f"artifact manifest is not CSV-safe: {values!r}")
    canonical = unquote(encoded)
    try:
        manifest = json.loads(canonical)
    except (UnicodeError, json.JSONDecodeError) as error:
        raise AssertionError("invalid artifact manifest") from error
    if not isinstance(manifest, dict):
        raise AssertionError("invalid artifact manifest root")
    if json.dumps(manifest, sort_keys=True, separators=(",", ":")) != canonical:
        raise AssertionError("artifact manifest is not canonical JSON")
    if quote(canonical, safe="-._~") != encoded:
        raise AssertionError("artifact manifest is not canonically encoded")
    if hashlib.sha256(canonical.encode()).hexdigest() != artifact_set_sha256:
        raise AssertionError("artifact set hash mismatch")
    if (
        manifest.get("schema") != "vort.benchmark_artifact_set"
        or manifest.get("version") != 1
    ):
        raise AssertionError("unsupported artifact manifest")
    for key in (
        "cargo_version", "python_version", "rustc_host",
        "rustc_version", "rustflags",
    ):
        if not isinstance(manifest.get(key), str) or not manifest[key]:
            raise AssertionError(f"invalid artifact environment field: {key}")
    extra_environment = manifest.get("extra_environment", {})
    if not isinstance(extra_environment, dict) or any(
        not isinstance(key, str) or not key or not isinstance(value, str) or not value
        for key, value in extra_environment.items()
    ):
        raise AssertionError("invalid artifact extra environment")
    artifacts = manifest.get("artifacts")
    if not isinstance(artifacts, list) or not artifacts:
        raise AssertionError("invalid artifact manifest entries")
    roles: set[str] = set()
    executable_hashes: set[str] = set()
    for entry in artifacts:
        if not isinstance(entry, dict):
            raise AssertionError("invalid artifact manifest entry")
        role = entry.get("role")
        kind = entry.get("kind")
        digest = entry.get("sha256")
        if not isinstance(role, str) or not role or role in roles:
            raise AssertionError("invalid or duplicate artifact role")
        roles.add(role)
        if kind not in {"file", "executable", "generated-source-tree", "source-tree"}:
            raise AssertionError(f"invalid artifact kind for {role}")
        if not isinstance(digest, str) or not is_sha256(digest):
            raise AssertionError(f"invalid artifact hash for {role}")
        if kind == "executable":
            executable_hashes.add(digest)
        if kind == "source-tree":
            commit = entry.get("git_commit")
            if not isinstance(commit, str) or len(commit) != 40 or not set(commit) <= HEX:
                raise AssertionError(f"invalid artifact commit for {role}")
            if not isinstance(entry.get("git_dirty"), bool):
                raise AssertionError(f"invalid artifact dirty state for {role}")
    if values["executable_sha256"] not in executable_hashes:
        raise AssertionError("primary executable is missing from artifact manifest")
    return manifest


def validate_provenance(
    rows: list[dict[str, str]],
    *,
    executable: Path | None,
    codec_thread_policy: str,
) -> dict[str, str]:
    if not rows:
        raise AssertionError("benchmark CSV has no rows")
    version = rows[0]["provenance_version"]
    present_v2 = set(PROVENANCE_V2_COLUMNS).intersection(rows[0])
    columns = PROVENANCE_COLUMNS + (PROVENANCE_V2_COLUMNS if version == "2" else [])
    if version == "2" and any(column not in rows[0] for column in PROVENANCE_V2_COLUMNS):
        raise AssertionError("incomplete provenance v2 columns")
    if version != "2" and present_v2:
        raise AssertionError("unexpected provenance v2 columns")
    provenance = {tuple(row[column] for column in columns) for row in rows}
    if len(provenance) != 1 or not all(next(iter(provenance))):
        raise AssertionError(f"inconsistent provenance: {provenance!r}")
    values = dict(zip(columns, next(iter(provenance)), strict=True))
    if values["provenance_version"] not in {"1", "2"}:
        raise AssertionError(f"unsupported provenance: {values!r}")
    if values["optimize"] != "ReleaseFast":
        raise AssertionError(f"non-ReleaseFast benchmark: {values!r}")
    try:
        recorded_affinity_count = int(values["affinity_cpu_count"])
        benchmark_threads = int(values["benchmark_threads"])
    except ValueError as error:
        raise AssertionError(f"invalid CPU/thread provenance: {values!r}") from error
    affinity = values["cpu_affinity"]
    affinity_valid = (
        recorded_affinity_count == 0
        if affinity == "unavailable"
        else affinity_count(affinity) == recorded_affinity_count
    )
    if (
        not affinity_valid
        or benchmark_threads != 1
        or values["codec_thread_policy"] != codec_thread_policy
    ):
        raise AssertionError(f"invalid CPU/thread provenance: {values!r}")
    if not is_sha256(values["executable_sha256"]):
        raise AssertionError(f"invalid executable hash: {values!r}")
    if executable is not None:
        actual = hashlib.sha256(executable.read_bytes()).hexdigest()
        if actual != values["executable_sha256"]:
            raise AssertionError(
                f"executable hash mismatch: expected={values['executable_sha256']} actual={actual}"
            )
    if any(character in values["command"] for character in ",\r\n"):
        raise AssertionError(f"command is not CSV-safe: {values!r}")
    if version == "2":
        validate_artifact_manifest_record(values)
    for row in rows:
        if not is_sha256(row["input_sha256"]):
            raise AssertionError(f"invalid input hash: {row!r}")
    return values
