#!/usr/bin/env python3
"""Bounded corruption checks on disposable package copies; never run decoders."""
import gzip
import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parent


def checksums(root):
    entries = [p for p in root.iterdir() if p.is_file() and p.name != "SHA256SUMS"]
    (root / "SHA256SUMS").write_text("".join(hashlib.sha256(p.read_bytes()).hexdigest() + "  " + p.name + "\n" for p in sorted(entries)))


def source_timestamp(root):
    path = root / "source-snapshot.tar.gz"
    data = bytearray(path.read_bytes())
    data[4:8] = (1).to_bytes(4, "little")
    path.write_bytes(data)
    bindings = json.loads((root / "archive-bindings.json").read_text())
    bindings["archives"][path.name]["sha256"] = hashlib.sha256(data).hexdigest()
    (root / "archive-bindings.json").write_text(json.dumps(bindings, indent=2) + "\n")
    checksums(root)


def probe_bytes(root):
    path = root / "probe.tar.gz"
    with tarfile.open(fileobj=io.BytesIO(gzip.decompress(path.read_bytes())), mode="r:") as archive:
        info = archive.getmembers()[0]
        data = bytearray(archive.extractfile(info).read())
    data[-1] ^= 1
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode="w", format=tarfile.GNU_FORMAT) as archive:
        archive.addfile(info, io.BytesIO(data))
    compressed = io.BytesIO()
    with gzip.GzipFile(fileobj=compressed, mode="wb", filename="", mtime=0, compresslevel=9) as target:
        target.write(stream.getvalue())
    path.write_bytes(compressed.getvalue())
    bindings = json.loads((root / "archive-bindings.json").read_text())
    binding = bindings["archives"][path.name]
    binding["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
    binding["member_sha256"][info.name] = hashlib.sha256(data).hexdigest()
    (root / "archive-bindings.json").write_text(json.dumps(bindings, indent=2) + "\n")
    checksums(root)


def main():
    results = []
    cases = (
        ("standalone checksum", lambda p: (p / "summary.json").write_bytes((p / "summary.json").read_bytes() + b" "), "Checksum differs"),
        ("deterministic gzip timestamp", source_timestamp, "Non-deterministic gzip header"),
        ("probe identity after forged container/member hashes", probe_bytes, "Probe binding differs"),
    )
    for name, mutate, expected in cases:
        with tempfile.TemporaryDirectory(prefix=".verify-smoke-", dir=ROOT) as temporary:
            clone = Path(temporary)
            for path in ROOT.iterdir():
                if path.is_file():
                    shutil.copyfile(path, clone / path.name)
            mutate(clone)
            child = subprocess.run([sys.executable, str(ROOT / "verify.py"), "--package", str(clone)], capture_output=True, text=True)
            assert child.returncode != 0 and expected in child.stderr, (name, child.stdout, child.stderr)
            results.append({"case": name, "rejected": True, "reason": child.stderr.strip()})
    print(json.dumps({"schema": "vort.decode-refresh-archive-corruption-smoke.v1", "success": True, "cases": results, "original_package_mutated": False, "decoder_execution": False}, indent=2))


if __name__ == "__main__":
    main()
