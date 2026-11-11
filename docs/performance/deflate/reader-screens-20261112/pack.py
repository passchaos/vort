#!/usr/bin/env python3
"""Package finished reader screens; never execute producers or codecs."""
import gzip
import hashlib
import io
import json
from pathlib import Path
import tarfile

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
PRIOR = REPO / "docs/performance/br/decode-mozilla-distributions-20261112"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def directory(root, prefix):
    return {prefix + "/" + str(path.relative_to(root)): (path.read_bytes(), str(path), 0o644)
            for path in sorted(root.rglob("*")) if path.is_file()}


def archive(name, files):
    path = HERE / name
    with path.open("wb") as output, gzip.GzipFile(fileobj=output, mode="wb", filename="", mtime=0, compresslevel=9) as compressed:
        with tarfile.open(fileobj=compressed, mode="w", format=tarfile.GNU_FORMAT) as bundle:
            for name, (data, origin, mode) in sorted(files.items()):
                member = tarfile.TarInfo(name)
                member.size, member.mode = len(data), mode
                member.uid = member.gid = member.mtime = 0
                member.uname = member.gname = ""
                bundle.addfile(member, io.BytesIO(data))
    return {"sha256": sha(path.read_bytes()), "members": len(files),
            "member_sha256": {name: sha(value[0]) for name, value in sorted(files.items())},
            "member_bytes": {name: len(value[0]) for name, value in sorted(files.items())},
            "origins": {name: value[1] for name, value in sorted(files.items())}}


def main():
    groups, raw, dependencies = {}, {}, {}
    for label in ("prefix", "refill"):
        root = Path("/tmp/vort-deflate-" + label + "-screen-20261112.8adfb3ba")
        raw.update(directory(root / "rows", label + "/rows"))
        source = directory(root / "source", label + "/source")
        binary = root / "candidate-compare"
        source[label + "/candidate-compare"] = (binary.read_bytes(), str(binary), 0o755)
        groups[label + "-source-probe.tar.gz"] = source
        for name in ("screen.py", "screen.log", "build.log", "full-safe.log", "freeze.json", "independent-stats.json", "codegen-audit.json", "first-block-shapes.json", "payload-counts.json"):
            path = root / name
            dependencies[label + "/" + name] = (path.read_bytes(), str(path), 0o644)
    pilot = Path("/tmp/vort-mozilla-profile-20261111.5fb4c695/pilot.py")
    dependencies["imports/pilot.py"] = (pilot.read_bytes(), str(pilot), 0o644)
    for name in ("matrix.py", "evidence.py", "fixtures.py"):
        path = Path("/home/passchaos/project-z/vort-mozilla-profile-20261111.5fb4c695/tools/decode") / name
        dependencies["imports/" + name] = (path.read_bytes(), str(path), 0o644)
    for name, path in (("inputs/pilot-manifest.json", Path("/tmp/vort-mozilla-profile-20261111.5fb4c695/pairs/manifest.json")),
                       ("inputs/prior-manifest.json", Path("/tmp/vort-decode-refresh-20261111.ea193be2/manifest.json"))):
        dependencies[name] = (path.read_bytes(), str(path), 0o644)
    groups["screens-raw.tar.gz"] = raw
    groups["runners-validation.tar.gz"] = dependencies
    binding = {"schema": "vort.deflate.reader-screens-archive.v1", "archives": {name: archive(name, files) for name, files in groups.items()},
               "scope": "Two rejected twelve-row cold screens; exact frozen overlays and binaries, not live prefix worktree",
               "policy": "sorted GNU tar, uid/gid/mtime0, empty owner names, 0644/0755; gzip9 empty filename/mtime0",
               "codegen_scope": "main-authored derived codegen summaries; original audit nm/objdump stdout was not separately retained; no dynamic cost inference",
               "codec_execution_during_archival": False}
    (HERE / "archive-bindings.json").write_text(json.dumps(binding, indent=2, sort_keys=True) + "\n")
    old = json.loads((PRIOR / "archive-bindings.json").read_bytes())
    ref = json.loads((PRIOR / "reference-reuse.json").read_bytes())
    reuse = {"prior_package": str(PRIOR.relative_to(REPO)), "prior_binding_sha256": sha((PRIOR / "archive-bindings.json").read_bytes()),
             "archives": {name: old["archives"][name]["sha256"] for name in ("shared-dispatch-source.tar.gz", "probe-binaries.tar.gz")},
             "source_prefix": "shared-dispatch/", "baseline_binary_member": "shared-dispatch/semantic-compare",
             "reference_libraries": ref["reference_libraries"], "modern_manifest": ref["modern_manifest"],
             "scope": "Reuse exact2062 source bytes/2527c721 baseline binary and pinned reference libraries; base8ad advances docs only"}
    (HERE / "reuse.json").write_text(json.dumps(reuse, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"archives": len(groups), "members": sum(len(value) for value in groups.values())}, indent=2))


if __name__ == "__main__":
    main()
