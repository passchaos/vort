"""Guarded future packer; current release state explicitly disables all work."""
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import tarfile
from package_io import json_documents

ROOT = Path(__file__).resolve().parent


def main():
    state = json.loads((ROOT / "release-state.json").read_bytes())
    if not state["heavy0_confirmed"] or state["final_full_exit_code"] != 0 or state["sampling_exit_code"] is None:
        raise RuntimeError("Archive packing remains pending: final full terminal and explicit Root HEAVY0 required")
    validation, benchmark = Path(state["validation_root"]), Path(state["benchmark_root"])
    sha = lambda data: hashlib.sha256(data).hexdigest()
    packages = {name: {} for name in ("sources.tar.gz", "benchmark.tar.gz", "validation.tar.gz")}
    def add(package, name, path):
        packages[package][name] = (path.read_bytes(), str(path))
    def tree(package, folder, prefix):
        for current, dirs, names in os.walk(folder, followlinks=False):
            dirs[:] = sorted(name for name in dirs if not (Path(current) / name).is_symlink() and
                            name not in ("__pycache__", ".git", ".zig-cache", "cache-old", "cache-current", "global-cache"))
            for name in sorted(names):
                path = Path(current) / name
                if not path.is_symlink() and path.is_file():
                    add(package, prefix + path.relative_to(folder).as_posix(), path)
    add("sources.tar.gz", "old-source.tar", benchmark / "old-source.tar")
    with tarfile.open(benchmark / "old-source.tar") as archive:
        old = {member.name: archive.extractfile(member).read() for member in archive if member.isfile()}
    with tarfile.open(benchmark / "current-source.tar") as archive:
        current = {member.name: archive.extractfile(member).read() for member in archive if member.isfile()}
    expected = json.loads((validation / state["frozen_source_manifest"]).read_bytes())
    actual = {name: sha(data) for name, data in current.items() if name.startswith("src/")}
    if actual != expected or len(actual) != state["frozen_source_count"]:
        raise ValueError("Current source tar does not match final frozen source2214")
    changed = []
    for name, data in current.items():
        if old.get(name) != data:
            packages["sources.tar.gz"]["overlay/" + name] = (data, "Exact current-source.tar member")
            changed.append(name)
    removed = sorted(name for name in old if name.startswith("src/") and name not in current)
    descriptor = {"changed": sorted(changed), "removed_src": removed, "source_files": len(actual), "base_head": state["base_head"]}
    packages["sources.tar.gz"]["overlay.json"] = ((json.dumps(descriptor, indent=2, sort_keys=True) + "\n").encode(), "Derived exact base/overlay reconstruction")
    add("sources.tar.gz", "final-source.json", validation / state["frozen_source_manifest"])
    for path in sorted(benchmark.iterdir()):
        if path.is_file() and not path.is_symlink() and path.name not in ("old-source.tar", "current-source.tar"):
            add("benchmark.tar.gz", path.name, path)
    for name in ("build", "inputs", "wires", "refs", "samples", "diagnosis-disasm"):
        tree("benchmark.tar.gz", benchmark / name, name + "/")
    # Captured reference files are data-only dependencies. Copy them after
    # heavy0 so later verification never opens the original system paths.
    reference_records = []
    for name in ("preflight.json", "refs/c-build-provenance.json", "refs/python-zlib.json", "sampling-release.json"):
        if (benchmark / name).is_file():
            record = json.loads((benchmark / name).read_bytes())
            reference_records.extend(record.get("reference_hashes", record.get("references", [])))
    references = {}
    for record in reference_records:
        path = Path(record["path"])
        content = path.read_bytes()
        if sha(content) != record["sha256"] or len(content) != record["size"]:
            raise ValueError("Captured reference identity differs")
        member = "refs/frozen/" + record["sha256"] + "-" + path.name
        packages["benchmark.tar.gz"][member] = (content, str(path))
        references[str(path)] = {"member": member, "size": len(content), "sha256": sha(content)}
    packages["benchmark.tar.gz"]["refs/reference-map.json"] = ((json.dumps(references, indent=2, sort_keys=True) + "\n").encode(), "Original captured reference paths mapped to package data; never executed")
    tree("validation.tar.gz", validation, "")
    # Latest WASI executions point to immutable build-cache modules. Preserve
    # their bytes as data; no runtime or original argv is invoked.
    wasi_documents = json_documents((validation / "latest-wasi.stdout").read_bytes())
    wasm_mapping = {}
    for module in [module for wasi in wasi_documents for module in wasi["results"]]:
        path = Path(module["wasm_path"])
        content = path.read_bytes()
        if sha(content) != module["wasm_sha256"] or len(content) != module["wasm_bytes"]:
            raise ValueError("Latest recorded WASI module identity differs")
        name = "wasm/" + module["label"] + ".wasm"
        packages["validation.tar.gz"][name] = (content, str(path))
        wasm_mapping[module["wasm_path"]] = name
    packages["validation.tar.gz"]["wasm-map.json"] = ((json.dumps(wasm_mapping, indent=2, sort_keys=True) + "\n").encode(), "Latest real WASI module paths mapped to package bytes")
    binding = {"schema": "vort.deflate.prepared-fixed.archive-bindings.v1", "archives": {}, "members": {}}
    for package, members in packages.items():
        records = {}
        with (ROOT / package).open("wb") as stream:
            with gzip.GzipFile(filename="", mode="wb", fileobj=stream, mtime=0, compresslevel=6) as compressed:
                with tarfile.open(fileobj=compressed, mode="w") as archive:
                    for name, (content, origin) in sorted(members.items()):
                        member = tarfile.TarInfo(name)
                        member.size, member.mode = len(content), 0o644
                        archive.addfile(member, io.BytesIO(content))
                        records[name] = {"bytes": len(content), "sha256": sha(content), "origin": origin}
        content = (ROOT / package).read_bytes()
        binding["archives"][package] = {"bytes": len(content), "sha256": sha(content)}
        binding["members"][package] = records
    (ROOT / "archive-bindings.json").write_text(json.dumps(binding, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
