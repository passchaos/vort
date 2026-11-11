#!/usr/bin/env python3
"""Archive frozen compact-map evidence without executing codecs or compilers."""
import gzip
import hashlib
import io
import json
from pathlib import Path
import tarfile

HERE = Path(__file__).resolve().parent
RAW = Path("/tmp/vort-brotli-compact-map-20261112.093d5b9c")
PRIOR = HERE.parent / "decode-mozilla-distributions-20261112"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def directory(path, prefix):
    return {prefix + "/" + str(p.relative_to(path)): (p.read_bytes(), str(p), 0o644)
            for p in sorted(path.rglob("*")) if p.is_file()}


def archive(name, files):
    path = HERE / name
    with path.open("wb") as output, gzip.GzipFile(fileobj=output, filename="", mode="wb", mtime=0, compresslevel=9) as compressed:
        with tarfile.open(fileobj=compressed, mode="w", format=tarfile.GNU_FORMAT) as bundle:
            for name, (data, origin, mode) in sorted(files.items()):
                member = tarfile.TarInfo(name)
                member.size, member.mode = len(data), mode
                member.uid = member.gid = member.mtime = 0
                member.uname = member.gname = ""
                bundle.addfile(member, io.BytesIO(data))
    return {"sha256": sha(path.read_bytes()), "member_sha256": {name: sha(v[0]) for name, v in sorted(files.items())},
            "member_bytes": {name: len(v[0]) for name, v in sorted(files.items())},
            "original_paths": {name: v[1] for name, v in sorted(files.items())}, "members": len(files)}


def main():
    groups = {"screen.tar.gz": directory(RAW / "screen", "screen"),
              "initial-noexec.tar.gz": directory(RAW / "screen-initial-noexec", "initial-noexec"),
              "compact-source-probe.tar.gz": directory(RAW / "source", "source")}
    compact = RAW / "compact-compare"
    groups["compact-source-probe.tar.gz"]["bin/compact-compare"] = (compact.read_bytes(), str(compact), 0o755)
    groups["runner-builds.tar.gz"] = {name: ((RAW / name).read_bytes(), str(RAW / name), 0o644)
                                      for name in ("screen.py", "screen.log", "baseline.log", "build.log", "safe.log")}
    bindings = {"schema": "vort.br.compact-context-map-archive.v1", "raw_root": str(RAW),
                "archives": {name: archive(name, files) for name, files in groups.items()},
                "scope": "Frozen three-row, six-permutation target/control screen; initial PermissionDenied attempt is preserved separately and excluded",
                "policy": "Sorted GNU tar; regular files; uid/gid/mtime0; empty owners; 0644/0755; gzip9 filename empty timestamp0",
                "candidate_merged": False, "acceptance_72_rows_run": False}
    write_json(HERE / "archive-bindings.json", bindings)
    prior_bindings = json.loads((PRIOR / "archive-bindings.json").read_bytes())
    names = ("baseline-source.tar.gz", "cold-fallback-v2-source.tar.gz", "shared-dispatch-source.tar.gz", "probe-binaries.tar.gz")
    alias = RAW / "bin/previous-compare"
    reuse = {"schema": "vort.br.compact-context-map-reuse.v1", "prior_package": str(PRIOR.relative_to(HERE.parent)),
             "archives": {name: {"sha256": prior_bindings["archives"][name]["sha256"]} for name in names},
             "prior_bindings_sha256": sha((PRIOR / "archive-bindings.json").read_bytes()),
             "validator_sha256": sha((PRIOR / "verify.py").read_bytes()),
             "reference_reuse_sha256": sha((PRIOR / "reference-reuse.json").read_bytes()),
             "main_binary_member": "shared-dispatch/semantic-compare", "previous_binary_member": "cold-fallback-v2/semantic-compare",
             "previous_alias": {"path": str(alias), "sha256": sha(alias.read_bytes()), "bytes": alias.stat().st_size, "mode": alias.stat().st_mode & 0o777},
             "scope": "Reuse prior immutable219 source, previous8 overlay, identical093 main source/binary bytes and reference SO/fixture hash bindings; no duplicate full package or previous executable"}
    write_json(HERE / "reuse.json", reuse)
    print(json.dumps({"archives": len(groups), "members": sum(len(files) for files in groups.values())}, indent=2))


if __name__ == "__main__":
    main()
