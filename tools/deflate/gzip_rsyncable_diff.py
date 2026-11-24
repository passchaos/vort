#!/usr/bin/env python3
"""Check actual local rsync reuse after small edits to a gzip input."""

import hashlib
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


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
    else:
        call(cli, "encode-gzip-best-file", source, wire, "--rsyncable")


def check_decode(wire, expected):
    if call("gzip", "-dc", wire) != expected:
        raise AssertionError(f"GNU gzip decoded {wire.name} to unexpected bytes")


def rsync_literals(basis_wire, updated_wire, copied_basis):
    shutil.copyfile(basis_wire, copied_basis)
    report = call("rsync", "-I", "--no-whole-file", "--stats", updated_wire, copied_basis)
    if copied_basis.read_bytes() != updated_wire.read_bytes():
        raise AssertionError(f"rsync did not reconstruct {updated_wire.name} byte-for-byte")
    for line in report.splitlines():
        if line.startswith(b"Literal data:"):
            return int(line.split(b":", 1)[1].split()[0].replace(b",", b""))
    raise RuntimeError(f"rsync did not report literal bytes for {updated_wire.name}: {report!r}")


def main():
    if len(sys.argv) != 4:
        raise SystemExit(f"usage: {sys.argv[0]} <probe> <cli> <source>")
    probe, cli, source = sys.argv[1:]
    with open(source, "rb") as handle:
        original = handle.read(4 * 1024 * 1024)
    edit_end = EDIT_OFFSET + len(EDIT_MARKER)
    if len(original) < edit_end:
        raise ValueError(f"supply a source of at least {edit_end} bytes for the full edit span")
    prefix = original[:EDIT_OFFSET]
    suffix = original[edit_end:]
    edits = {
        "insertion": prefix + EDIT_MARKER + original[EDIT_OFFSET:],
        "replacement": prefix + EDIT_MARKER + suffix,
        "deletion": prefix + suffix,
    }
    source_digest = hashlib.sha256(original).hexdigest()
    print(f"source_bytes={len(original)} source_sha256={source_digest}")
    counts = {}
    with tempfile.TemporaryDirectory(prefix="vort-gzip-rsyncable-") as directory:
        temp = Path(directory)
        basis = temp / "basis"
        updated = temp / "updated"
        basis.write_bytes(original)
        basis_wires = {mode: temp / f"{mode}.basis.gz" for mode in ("plain", "rsyncable")}
        for mode, basis_wire in basis_wires.items():
            encode(probe, cli, basis, basis_wire, mode)
            check_decode(basis_wire, original)

        probe_wire = temp / "probe.rsyncable.basis.gz"
        call(probe, basis, probe_wire, "rsyncable")
        check_decode(probe_wire, original)
        if probe_wire.read_bytes() != basis_wires["rsyncable"].read_bytes():
            raise AssertionError("CLI rsyncable basis differs from the incremental probe wire")

        for edit, edited in edits.items():
            updated.write_bytes(edited)
            counts[edit] = {}
            for mode, basis_wire in basis_wires.items():
                updated_wire = temp / f"{edit}.{mode}.updated.gz"
                encode(probe, cli, updated, updated_wire, mode)
                check_decode(updated_wire, edited)
                transferred = rsync_literals(basis_wire, updated_wire, temp / "rsync.basis.gz")
                counts[edit][mode] = transferred
                print(
                    f"edit={edit} mode={mode} basis_wire={basis_wire.stat().st_size} "
                    f"edited_wire={updated_wire.stat().st_size} literal_bytes={transferred}"
                )

    # Keep the existing insertion gate for custom inputs. Equal-length edits in
    # particular can already be cheap in plain mode, so gate all edits only on nci.
    required_edits = edits if source_digest == REFERENCE_SHA256 else ("insertion",)
    for edit in required_edits:
        row = counts[edit]
        if row["plain"] == 0 or row["rsyncable"] * 5 > row["plain"]:
            raise AssertionError(f"expected at least a five-fold literal reduction for {edit}: {row}")
    print("gzip_rsyncable_diff_ok")


if __name__ == "__main__":
    main()
