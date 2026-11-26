"""Preserve finite rejected experiment bytes, base tar and four-file overlay."""
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import tarfile

ROOT = Path(__file__).resolve().parent
SOURCE = Path("/tmp/vort-br-word-prefix.a8eqcdli")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    packages = {name: {} for name in ("source.tar.gz", "evidence.tar.gz", "profile.tar.gz")}
    def add(package, name, path):
        packages[package][name] = (path.read_bytes(), str(path))
    def tree(package, folder, prefix):
        for current, dirs, names in os.walk(folder, followlinks=False):
            dirs[:] = sorted(name for name in dirs if not (Path(current) / name).is_symlink() and name != "__pycache__")
            for name in sorted(names):
                path = Path(current) / name
                if not path.is_symlink() and path.is_file():
                    add(package, prefix + path.relative_to(folder).as_posix(), path)
    add("source.tar.gz", "base-source.tar", SOURCE / "base-source.tar")
    add("source.tar.gz", "candidate-source.json", SOURCE / "candidate-source.json")
    with tarfile.open(SOURCE / "base-source.tar") as base_archive:
        base = {member.name: base_archive.extractfile(member).read() for member in base_archive if member.isfile()}
        base_head = base_archive.pax_headers.get("comment")
    registry = json.loads((SOURCE / "candidate-source.json").read_bytes())
    changed = []
    for name, digest in registry.items():
        content = (SOURCE / "source" / name).read_bytes()
        if sha(content) != digest:
            raise ValueError("Candidate source differs: " + name)
        if name not in base or sha(base[name]) != digest:
            changed.append(name)
            add("source.tar.gz", "overlay/" + name, SOURCE / "source" / name)
    expected = ["src/lz77.zig", "src/lz77/modeled_pair_root_tests.zig", "src/lz77/modeled_pair_tests.zig", "src/lz77/modeled_plan.zig"]
    if sorted(changed) != expected or len(registry) != 2201:
        raise ValueError("Expected four-file combined overlay differs")
    mapping = {"base_head": base_head, "candidate_src_files": len(registry), "overlay_files": sorted(changed),
               "scope": "Original gitarchive src/build/tools snapshot plus exact four-file overlay; no component attribution"}
    packages["source.tar.gz"]["source-overlay.json"] = ((json.dumps(mapping, indent=2, sort_keys=True) + "\n").encode(), "Generated from original base tar and verified source hashes")
    for path in sorted(SOURCE.iterdir()):
        if path.is_file() and path.name not in ("base-source.tar", "candidate-source.json"):
            add("evidence.tar.gz", path.name, path)
    for name in ("bin", "build", "inputs", "pilot-runs"):
        tree("evidence.tar.gz", SOURCE / name, name + "/")
    identity = json.loads((SOURCE / "identity.json").read_bytes())
    add("evidence.tar.gz", "baseline-original-build-receipt.json", Path(identity["baseline_build_receipt"]))
    reference = json.loads((SOURCE / "pilot-manifest.json").read_bytes())["reference_decode_outside_timing"]
    for path, digest in reference["files"].items():
        file = Path(path)
        if sha(file.read_bytes()) != digest:
            raise ValueError("Pinned decoder differs")
        add("evidence.tar.gz", "references/" + file.name, file)
    tree("profile.tar.gz", SOURCE / "profile", "")
    completion = {"pilot_parent_reported_session": 98758, "pilot_parent_reported_exit_code": 0, "heavy0_reported": True,
                  "profile_addr2line_report_stopped_by_root": True, "addr2line_is_codec_failure": False,
                  "scope": "Root-observed pilot terminal and postprocessing status; no additional runs or guessed tool exit receipt"}
    packages["evidence.tar.gz"]["completion-receipt.json"] = ((json.dumps(completion, indent=2, sort_keys=True) + "\n").encode(), "Root terminal and bounded task report")
    binding = {"schema": "vort.br.modeled-lanes.archive-bindings.v1", "archives": {}, "members": {}}
    for package, members in packages.items():
        records = {}
        with (ROOT / package).open("wb") as stream:
            with gzip.GzipFile(filename="", fileobj=stream, mode="wb", mtime=0, compresslevel=6) as compressed:
                with tarfile.open(fileobj=compressed, mode="w") as archive:
                    for name, (content, origin) in sorted(members.items()):
                        info = tarfile.TarInfo(name)
                        info.size, info.mode = len(content), 0o644
                        archive.addfile(info, io.BytesIO(content))
                        records[name] = {"bytes": len(content), "sha256": sha(content), "origin": origin}
        content = (ROOT / package).read_bytes()
        if len(content) >= 100 * 1024 * 1024:
            raise ValueError("Archive exceeds the requested single-file ceiling")
        binding["archives"][package] = {"bytes": len(content), "sha256": sha(content)}
        binding["members"][package] = records
    (ROOT / "archive-bindings.json").write_text(json.dumps(binding, indent=2, sort_keys=True) + "\n")
    (ROOT / ".gitattributes").write_text("*.tar.gz binary\n")
    print(json.dumps({"archives": binding["archives"], "members": {name: len(rows) for name, rows in binding["members"].items()}}, sort_keys=True))


if __name__ == "__main__":
    main()
