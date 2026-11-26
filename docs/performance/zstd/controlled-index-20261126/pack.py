#!/usr/bin/env python3
"""Archive completed evidence only after the recorded Root heavy0 boundary."""
from concurrent.futures import ThreadPoolExecutor
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import tarfile

ROOT = Path(__file__).resolve().parent


def sha(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def real_files(folder):
    """Never descend readonly docs/bench/corpus/vail symlinks or private caches."""
    for current, directories, names in os.walk(folder, followlinks=False):
        directories[:] = sorted(name for name in directories
                                if not (Path(current) / name).is_symlink() and
                                name not in (".git", ".zig-cache", "zig-out", "local-cache", "global-cache"))
        for name in sorted(names):
            path = Path(current) / name
            if not path.is_symlink() and path.is_file():
                yield path


def main():
    release = json.loads((ROOT / "release-state.json").read_bytes())
    require(release["heavy0_confirmed"], "Packing disabled until Root confirms heavy0")
    source = Path(release["source_root"])
    verification = json.loads((source / "formal-verification.json").read_bytes())
    require(verification["evidence_integrity_pass"] and verification["complete_acceptance_pass"] is False,
            "Expected complete rejected reducer result is unavailable")
    for name in ("formal", "controls"):
        require(json.loads((source / (name + "-exit.json")).read_bytes())["exit_code"] == 0 and
                "ended_unix" in json.loads((source / (name + "-manifest.json")).read_bytes()), "Campaign incomplete")
    packages = {name: {} for name in ("campaign.tar.gz", "sources.tar.gz", "resources.tar.gz", "validation.tar.gz")}

    def add(package, name, path):
        require(name not in packages[package], "Duplicate member: " + name)
        packages[package][name] = (path.read_bytes(), str(path))

    def tree(package, folder, prefix):
        for path in real_files(folder):
            add(package, prefix + path.relative_to(folder).as_posix(), path)

    for path in sorted(source.iterdir()):
        if path.is_file() and not path.is_symlink():
            add("campaign.tar.gz", path.name, path)
    for name in ("pilot-runs", "bounded-pilot-runs", "index-pilot-runs", "formal-runs", "controls-runs", "bin", "build", "fixtures"):
        tree("campaign.tar.gz", source / name, name + "/")
    reference = Path(verification["retained_reference_identity"]["path"])
    data = reference.read_bytes()
    require(sha(data) == verification["retained_reference_identity"]["sha256"], "Pinned reference differs")
    add("campaign.tar.gz", "references/" + reference.name, reference)
    variants = {
        "hash-local": ("source", "source-identity.json", "hash-local-candidate", "pilot"),
        "bounded": ("bounded-source", "bounded-source-identity.json", "bounded-candidate", "bounded-pilot"),
        "index": ("index-source", "final-source-identity.json", "candidate", "index-pilot/formal/controls"),
    }
    mapping = {}
    for label, (folder, registry_name, binary, campaign) in variants.items():
        directory = source / folder
        registry = json.loads((source / registry_name).read_bytes())
        actual = {path.relative_to(directory).as_posix(): sha(path.read_bytes()) for path in real_files(directory / "src")}
        require(all(actual.get(name) == digest for name, digest in registry.items()), "Recorded source file differs: " + label)
        additions = sorted(set(actual) - set(registry))
        require(not additions or (label == "hash-local" and additions == ["src/zstd_controlled_kernels_gate.zig"]),
                "Unexpected unrecorded source addition: " + label)
        tree("sources.tar.gz", directory / "src", label + "/src/")
        if (directory / "tools").is_dir() and not (directory / "tools").is_symlink():
            tree("sources.tar.gz", directory / "tools", label + "/tools/")
        for name in ("build.zig", "build.zig.zon", "LICENSE", "README.md"):
            if (directory / name).is_file() and not (directory / name).is_symlink():
                add("sources.tar.gz", label + "/" + name, directory / name)
        add("sources.tar.gz", label + "/source-identity.json", source / registry_name)
        actual_data = (json.dumps(actual, indent=2, sort_keys=True) + "\n").encode()
        packages["sources.tar.gz"][label + "/archived-src-sha256.json"] = (actual_data, "Current full src snapshot; original recorded hashes verified, test-only addition explicit")
        mapping[label] = {"directory": folder, "registry": registry_name, "recorded_source_files": len(registry), "source_files": len(actual),
                          "unrecorded_test_only_additions": additions,
                          "binary": binary, "binary_sha256": sha((source / "bin" / binary).read_bytes()), "campaigns": campaign}
    reference_source = source / "reference-source"
    tree("sources.tar.gz", reference_source / "src", "baseline-oracle/src/")
    if (reference_source / "tools").is_dir() and not (reference_source / "tools").is_symlink():
        tree("sources.tar.gz", reference_source / "tools", "baseline-oracle/tools/")
    for name in ("build.zig", "build.zig.zon", "LICENSE", "README.md"):
        if (reference_source / name).is_file() and not (reference_source / name).is_symlink():
            add("sources.tar.gz", "baseline-oracle/" + name, reference_source / name)
    resource = source / "resource"
    for path in real_files(resource):
        relative = path.relative_to(resource)
        if relative.parts[0] in ("baseline-source", "candidate-source"):
            # Preserve all src snapshot members, including the recorded unrelated pyc.
            if len(relative.parts) < 2 or relative.parts[1] != "src":
                continue
        elif relative.parts[0] == "__pycache__":
            continue
        add("resources.tar.gz", relative.as_posix(), path)
    tree("validation.tar.gz", source / "validation", "validation/")
    for path in sorted(source.iterdir()):
        if path.is_file() and path.name.endswith((".stderr", ".stdout")):
            add("validation.tar.gz", path.name, path)
    mapping_data = (json.dumps({"schema": "vort.zstd.controlled-index.source-mapping.v1", "variants": mapping,
        "baseline_oracle": "reference-source/src is the unchanged main parser oracle; formal baseline ELF is independently reused from baseline-identity receipt",
        "scope": "All src registry files plus real build/tools inputs; readonly docs/bench/corpus/vail symlinks excluded. Final index registry includes added test-only gate."}, indent=2, sort_keys=True) + "\n").encode()
    packages["sources.tar.gz"]["source-mapping.json"] = (mapping_data, "Generated from verified Root variant mapping")

    def pack(item):
        name, members = item
        records = {}
        with (ROOT / name).open("wb") as stream:
            with gzip.GzipFile(filename="", fileobj=stream, mode="wb", mtime=0, compresslevel=6) as compressed:
                with tarfile.open(fileobj=compressed, mode="w") as archive:
                    for member, (content, origin) in sorted(members.items()):
                        info = tarfile.TarInfo(member)
                        info.size, info.mode = len(content), 0o644
                        archive.addfile(info, io.BytesIO(content))
                        records[member] = {"bytes": len(content), "sha256": sha(content), "origin": origin}
        content = (ROOT / name).read_bytes()
        return name, {"bytes": len(content), "sha256": sha(content)}, records

    binding = {"schema": "vort.zstd.controlled-index.archive-bindings.v1", "archives": {}, "members": {},
               "scope": "Completed Root heavy0 archive; all raw/outliers retained; no symlink dereference into unrelated documentation or parent checkout"}
    with ThreadPoolExecutor(max_workers=4) as pool:
        for name, identity, members in pool.map(pack, packages.items()):
            binding["archives"][name], binding["members"][name] = identity, members
    (ROOT / "archive-bindings.json").write_text(json.dumps(binding, indent=2, sort_keys=True) + "\n")
    (ROOT / ".gitattributes").write_text("*.tar.gz binary\n")
    print(json.dumps({"archives": binding["archives"], "members": {name: len(rows) for name, rows in binding["members"].items()}}, sort_keys=True))


if __name__ == "__main__":
    main()
