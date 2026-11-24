#!/usr/bin/env python3
"""Check actual local rsync reuse after a small insertion into a gzip input."""

import os
import subprocess
import sys
import tempfile
from pathlib import Path


def call(*argv):
    result = subprocess.run(argv, capture_output=True, env={**os.environ, "LC_ALL": "C"})
    if result.returncode:
        raise RuntimeError(f"{argv} exited {result.returncode}: {result.stderr.decode(errors='replace')}")
    return result.stdout


def main():
    probe, source = sys.argv[1:]
    with open(source, "rb") as handle:
        original = handle.read(4 * 1024 * 1024)
    if len(original) <= 4096:
        raise ValueError("supply a source larger than the insertion offset (4096 bytes)")
    edited = original[:4096] + b"VORT_RSYNCPROBE" + original[4096:]
    counts = {}
    with tempfile.TemporaryDirectory(prefix="vort-gzip-rsyncable-") as directory:
        temp = Path(directory)
        basis = temp / "basis"
        updated = temp / "updated"
        basis.write_bytes(original)
        updated.write_bytes(edited)
        for mode in ("plain", "rsyncable"):
            basis_wire = temp / f"{mode}.basis.gz"
            updated_wire = temp / f"{mode}.updated.gz"
            call(probe, basis, basis_wire, mode)
            call(probe, updated, updated_wire, mode)
            assert call("gzip", "-dc", basis_wire) == original
            assert call("gzip", "-dc", updated_wire) == edited
            report = call("rsync", "-I", "--no-whole-file", "--stats", updated_wire, basis_wire)
            literal = next(line for line in report.splitlines() if line.startswith(b"Literal data:"))
            transferred = int(literal.split(b":", 1)[1].split()[0].replace(b",", b""))
            assert basis_wire.read_bytes() == updated_wire.read_bytes()
            counts[mode] = transferred
            print(f"{mode} edited_wire={updated_wire.stat().st_size} literal_bytes={transferred}")
    if counts["rsyncable"] * 5 > counts["plain"] or counts["plain"] == 0:
        raise AssertionError(f"expected at least a five-fold reduction for this fixture: {counts}")
    print("gzip_rsyncable_diff_ok")


if __name__ == "__main__":
    main()
