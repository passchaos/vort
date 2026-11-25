#!/usr/bin/env python3
"""Check actual local rsync reuse after small edits to a gzip input."""

import argparse
import hashlib
import os
import shutil
import subprocess
import tempfile
from pathlib import Path


SOURCE_LIMIT = 4 * 1024 * 1024
EDIT_OFFSET = 4096
EDIT_MARKER = b"VORT_RSYNCPROBE"
REFERENCE_SHA256 = "2c98cbb056dfda7d28ef56c612e48a0ae11fb8cf5d23a6918d35c78db1573134"


def call(*argv):
    result = subprocess.run(argv, capture_output=True, env={**os.environ, "LC_ALL": "C"})
    if result.returncode:
        raise RuntimeError(f"{argv} exited {result.returncode}: {result.stderr.decode(errors='replace')}")
    return result.stdout


def encode(probe, cli, source, wire, mode):
    if mode == "plain":
        call(probe, source, wire, mode)
    elif mode == "rsyncable":
        call(cli, "encode-gzip-best-file", source, wire, "--rsyncable")
    elif mode in ("gnu-plain", "gnu-rsyncable"):
        flags = ("--rsyncable",) if mode == "gnu-rsyncable" else ()
        wire.write_bytes(call("gzip", "-n", "-6", "-c", *flags, source))
    else:
        raise ValueError(f"unknown gzip mode: {mode}")


def check_decode(wire, expected):
    if call("gzip", "-dc", wire) != expected:
        raise AssertionError(f"GNU gzip decoded {wire.name} to unexpected bytes")


def rsync_literals(basis_wire, updated_wire, copied_basis):
    shutil.copyfile(basis_wire, copied_basis)
    report = call("rsync", "-I", "--no-whole-file", "--stats", updated_wire, copied_basis)
    if copied_basis.read_bytes() != updated_wire.read_bytes():
        raise AssertionError(f"rsync did not reconstruct {updated_wire.name} byte-for-byte")
    stats = {}
    for line in report.splitlines():
        key, _, value = line.partition(b":")
        if key in (b"Literal data", b"Matched data"):
            stats[key] = int(value.split()[0].replace(b",", b""))
    if len(stats) != 2 or sum(stats.values()) != updated_wire.stat().st_size:
        raise AssertionError(f"rsync byte accounting for {updated_wire.name}: {stats}")
    return stats[b"Literal data"]


def edits_at(original, offset):
    end = offset + len(EDIT_MARKER)
    replacement = EDIT_MARKER
    if original[offset:end] == replacement:
        # An insertion marker already present in the basis must not make this a no-op.
        replacement = bytes((replacement[0] ^ 1,)) + replacement[1:]
    yield "insertion", original[:offset] + EDIT_MARKER + original[offset:]
    yield "replacement", original[:offset] + replacement + original[end:]
    yield "deletion", original[:offset] + original[end:]


def check_reuse(source_digest, offset, edit, counts, report_only):
    # Preserve the original gate at its tested offset; compare other rows
    # observationally because a clean round trip need not improve reuse.
    if report_only or offset != EDIT_OFFSET:
        return
    if edit != "insertion" and source_digest != REFERENCE_SHA256:
        return
    if counts["plain"] == 0 or counts["rsyncable"] * 5 > counts["plain"]:
        raise AssertionError(f"expected at least a five-fold literal reduction for {edit}: {counts}")


def measure_source(probe, cli, source, offsets, modes, report_only):
    with source.open("rb") as handle:
        original = handle.read(SOURCE_LIMIT)
    for offset in offsets:
        if offset + len(EDIT_MARKER) > len(original):
            raise ValueError(f"{source}: edit at {offset} does not fit in the {len(original)}-byte source slice")
    source_digest = hashlib.sha256(original).hexdigest()
    print(f"source={source.name!r} source_bytes={len(original)} source_sha256={source_digest}")
    with tempfile.TemporaryDirectory(prefix="vort-gzip-rsyncable-") as directory:
        temp = Path(directory)
        basis = temp / "basis"
        updated = temp / "updated"
        basis.write_bytes(original)
        basis_wires = {mode: temp / f"{mode}.basis.gz" for mode in modes}
        for mode, basis_wire in basis_wires.items():
            encode(probe, cli, basis, basis_wire, mode)
            check_decode(basis_wire, original)

        probe_wire = temp / "probe.rsyncable.basis.gz"
        call(probe, basis, probe_wire, "rsyncable")
        check_decode(probe_wire, original)
        if probe_wire.read_bytes() != basis_wires["rsyncable"].read_bytes():
            raise AssertionError("CLI rsyncable basis differs from the incremental probe wire")

        for offset in offsets:
            for edit, edited in edits_at(original, offset):
                updated.write_bytes(edited)
                counts = {}
                for mode, basis_wire in basis_wires.items():
                    updated_wire = temp / f"{mode}.updated.gz"
                    encode(probe, cli, updated, updated_wire, mode)
                    check_decode(updated_wire, edited)
                    transferred = rsync_literals(basis_wire, updated_wire, temp / "rsync.basis.gz")
                    counts[mode] = transferred
                    print(
                        f"edit={edit} offset={offset} mode={mode} basis_wire={basis_wire.stat().st_size} "
                        f"edited_wire={updated_wire.stat().st_size} literal_bytes={transferred}"
                    )
                check_reuse(source_digest, offset, edit, counts, report_only)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("probe")
    parser.add_argument("cli")
    parser.add_argument("source", type=Path, nargs="+")
    parser.add_argument("--offset", type=int, action="append", help="zero-based edit offset (repeatable; default: 4096)")
    parser.add_argument("--gnu", action="store_true", help="also measure GNU gzip -n -6 with and without --rsyncable")
    parser.add_argument("--report-only", action="store_true", help="skip the numerical reuse floor, not the byte-for-byte checks")
    args = parser.parse_args()
    offsets = args.offset if args.offset is not None else [EDIT_OFFSET]
    if min(offsets) < 0 or len(set(offsets)) != len(offsets):
        parser.error("edit offsets must be distinct and non-negative")
    modes = ("plain", "rsyncable") + (("gnu-plain", "gnu-rsyncable") if args.gnu else ())
    for source in args.source:
        measure_source(args.probe, args.cli, source, offsets, modes, args.report_only)
    print("gzip_rsyncable_diff_ok")


if __name__ == "__main__":
    main()
