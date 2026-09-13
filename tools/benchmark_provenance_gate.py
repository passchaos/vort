#!/usr/bin/env python3
"""Shared validation for reproducible benchmark CSV provenance."""

from __future__ import annotations

import hashlib
from pathlib import Path


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


def validate_provenance(
    rows: list[dict[str, str]],
    *,
    executable: Path | None,
    codec_thread_policy: str,
) -> dict[str, str]:
    if not rows:
        raise AssertionError("benchmark CSV has no rows")
    provenance = {tuple(row[column] for column in PROVENANCE_COLUMNS) for row in rows}
    if len(provenance) != 1 or not all(next(iter(provenance))):
        raise AssertionError(f"inconsistent provenance: {provenance!r}")
    values = dict(zip(PROVENANCE_COLUMNS, next(iter(provenance)), strict=True))
    if values["provenance_version"] != "1":
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
    for row in rows:
        if not is_sha256(row["input_sha256"]):
            raise AssertionError(f"invalid input hash: {row!r}")
    return values
