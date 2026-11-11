#!/usr/bin/env python3
"""Preserve the completed-match producer packet without running its binaries."""
import gzip
import hashlib
import io
import json
from pathlib import Path
import tarfile

HERE = Path(__file__).resolve().parent
RAW = Path("/tmp/vort-completed-match-candidate-20261112.492a0a74")
EXECUTABLES = {"baseline-compare", "candidate-compare", "helper-safe", "narrow-safe", "fullDeflateSafe", "install/bin/vort-decode-compare"}


def main():
    files = {str(path.relative_to(RAW)): path for path in sorted(RAW.rglob("*")) if path.is_file()}
    if len(files) != 36:
        raise ValueError("Frozen producer packet file count changed")
    target = HERE / "prototype-packet.tar.gz"
    with target.open("wb") as output, gzip.GzipFile(fileobj=output, mode="wb", filename="", mtime=0, compresslevel=9) as compressed:
        with tarfile.open(fileobj=compressed, mode="w", format=tarfile.GNU_FORMAT) as archive:
            for name, path in sorted(files.items()):
                data = path.read_bytes()
                member = tarfile.TarInfo(name)
                member.size, member.mode = len(data), 0o755 if name in EXECUTABLES else 0o644
                member.uid = member.gid = member.mtime = 0
                member.uname = member.gname = ""
                archive.addfile(member, io.BytesIO(data))
    binding = {"schema": "vort.deflate.completed-match-archive.v1", "raw_root": str(RAW), "archive": "prototype-packet.tar.gz",
               "archive_sha256": hashlib.sha256(target.read_bytes()).hexdigest(), "members": len(files),
               "member_sha256": {name: hashlib.sha256(path.read_bytes()).hexdigest() for name, path in files.items()},
               "member_bytes": {name: path.stat().st_size for name, path in files.items()}, "executable_members": sorted(EXECUTABLES),
               "policy": "sorted GNU tar, regular files, uid/gid/mtime0, empty owners, 0644/0755, gzip9 empty filename/mtime0",
               "scope": "No A/B or perf run; rejected static-codegen prototype. Producer-defined registry2765 is not a compiler-open/input trace."}
    (HERE / "archive-bindings.json").write_text(json.dumps(binding, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"members": len(files), "archive_bytes": target.stat().st_size}, indent=2))


if __name__ == "__main__":
    main()
