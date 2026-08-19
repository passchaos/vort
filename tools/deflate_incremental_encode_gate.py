#!/usr/bin/env python3
"""Validate persistent incremental DEFLATE benchmark evidence."""

from __future__ import annotations

import argparse
import csv
import io
import shlex
import subprocess
import sys


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--command", default="zig build -Doptimize=ReleaseFast bench-deflate-incremental-encode")
    args = parser.parse_args()

    completed = subprocess.run(shlex.split(args.command), check=True, text=True, capture_output=True)
    lines = completed.stdout.splitlines()
    try:
        header = lines.index("mode,input_bytes,output_bytes,iterations,elapsed_s,throughput_mib_s,mix")
    except ValueError as exc:
        raise SystemExit("missing incremental benchmark CSV header") from exc
    rows = list(csv.DictReader(io.StringIO("\n".join(lines[header : header + 3]))))
    by_name = {row["mode"]: row for row in rows}
    persistent = by_name.get("persistent-lazy")
    rebuild = by_name.get("rebuild-lazy")
    if persistent is None or rebuild is None:
        raise SystemExit("missing persistent-lazy or rebuild-lazy row")

    persistent_speed = float(persistent["throughput_mib_s"])
    rebuild_speed = float(rebuild["throughput_mib_s"])
    persistent_size = int(persistent["output_bytes"])
    rebuild_size = int(rebuild["output_bytes"])
    if persistent_speed < rebuild_speed:
        raise SystemExit(f"persistent lazy throughput regressed: {persistent_speed:.2f} < {rebuild_speed:.2f} MiB/s")
    if persistent_size > rebuild_size:
        raise SystemExit(f"persistent lazy size regressed: {persistent_size} > {rebuild_size}")

    print(
        "incremental deflate gate: "
        f"speed_ratio={persistent_speed / rebuild_speed:.3f} "
        f"size_ratio={persistent_size / rebuild_size:.3f}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
