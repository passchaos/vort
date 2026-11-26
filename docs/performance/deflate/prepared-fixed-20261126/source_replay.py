"""Exact frozen source/ELF/probe reconstruction after packages are released."""
import io
import tarfile

from package_io import load, require, sha


def verify(source, benchmark, manifest):
    require(sha(source["old-source.tar"]) == manifest["old_source_archive_sha256"], "Original base source tar differs")
    files = {}
    with tarfile.open(fileobj=io.BytesIO(source["old-source.tar"]), mode="r:") as archive:
        for member in archive:
            require(not member.name.startswith("/") and ".." not in member.name.split("/"), "Unsafe original base member")
            if member.isfile():
                files[member.name] = archive.extractfile(member).read()
    overlay = load(source, "overlay.json")
    for name in overlay["removed_src"]:
        files.pop(name, None)
    for name, data in source.items():
        if name.startswith("overlay/"):
            files[name.removeprefix("overlay/")] = data
    actual = {name: sha(data) for name, data in files.items() if name.startswith("src/")}
    require(actual == load(source, "final-source.json") and len(actual) == 2214, "Final source2214 base/overlay differs")
    for which in ("old", "current"):
        built = load(benchmark, "build/" + which + "-build.json")
        require(built["returncode"] == 0 and sha(benchmark["build/" + which + "-probe"]) == built["elf_sha256"] and
                len(benchmark["build/" + which + "-probe"]) == built["elf_size"] and
                sha(benchmark["build/probe.zig"]) == built["probe_sha256"], "Probe/source/build identity differs")
        if which == "current":
            recorded = {"src/" + entry["path"]: entry["sha256"] for entry in built["source_manifest"]["files"]}
            require(recorded == actual, "Current ELF source manifest differs from final2214")
    return {"base_head": manifest["old_commit"], "final_source_files": 2214, "exact_overlay": True,
            "scope": "Frozen package src/base/overlay and build probe bytes; no production/tmp/Git lookup or executable invocation"}
