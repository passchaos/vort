#!/usr/bin/env python3
"""Exercise Deflate benchmark matrix validation without timing codecs."""

from __future__ import annotations

import copy
import hashlib

from rust_deflate_bench_gate import DECODE_ENGINES, ENCODE_ENGINES, validate_matrix
from rust_deflate_benchmark_common import payloads


def fixture(kind: str) -> list[dict[str, str]]:
    rows = []
    engines = ENCODE_ENGINES if kind == "encode" else DECODE_ENGINES
    for case, payload in payloads(encode=kind == "encode"):
        for engine, wire_format in engines:
            iterations = 2
            elapsed_ns = 1_000_000
            row = {
                "engine": engine,
                "format": wire_format,
                "case": case,
                "input_bytes": str(len(payload)),
                "input_sha256": hashlib.sha256(payload).hexdigest(),
                "frame_bytes": "1",
                "iterations": str(iterations),
                "repeat": "3",
                "elapsed_ns": str(elapsed_ns),
                "elapsed_s": "0.001000",
                "throughput_mib_s": f"{len(payload) * iterations / (1024 * 1024) / 0.001:.2f}",
                "mix": "1",
            }
            if kind == "encode":
                row["frame_bytes"] = str(len(payload))
                row["ratio"] = "1.0000"
            rows.append(row)
    return rows


def expect_failure(
    rows: list[dict[str, str]], kind: str, message: str
) -> None:
    try:
        validate_matrix(rows, kind, 3)
    except AssertionError as error:
        if message not in str(error):
            raise AssertionError(
                f"expected {message!r}, received {str(error)!r}"
            ) from error
    else:
        raise AssertionError(f"expected matrix failure containing {message!r}")


def main() -> int:
    checks = 0
    for kind in ("decode", "encode"):
        rows = fixture(kind)
        validate_matrix(rows, kind, 3)
        checks += 1

        expect_failure(rows + [dict(rows[0])], kind, "duplicate row")
        checks += 1
        expect_failure(rows[:-1], kind, "bad engines")
        checks += 1
        mutations = (
            ("input_sha256", "0" * 64, "input hash mismatch"),
            ("repeat", "2", "unexpected repeat count"),
            ("elapsed_s", "0.002", "elapsed time mismatch"),
            ("throughput_mib_s", "1", "throughput mismatch"),
        )
        for key, value, message in mutations:
            changed = copy.deepcopy(rows)
            changed[0][key] = value
            expect_failure(changed, kind, message)
            checks += 1
        if kind == "encode":
            changed = copy.deepcopy(rows)
            changed[0]["ratio"] = "2"
            expect_failure(changed, kind, "compression ratio mismatch")
            checks += 1

    print(f"rust_deflate_bench_gate_smoke=ok checks={checks}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
