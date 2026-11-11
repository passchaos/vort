#!/usr/bin/env python3
"""Package frozen evidence; never run a codec, compiler, test, or benchmark."""
import gzip
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
RAW = Path("/tmp/vort-mozilla-distributions-20261112.21952b95")
KERNEL = Path("/home/passchaos/project-z/vort-mozilla-kernel-20261112.21952b95")
BASE = "21952b95e99a6979dd640447f0beebcb16b29f49"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def load(path):
    return json.loads(path.read_bytes())


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def git_sources(expected, revision=BASE):
    result = {}
    process = subprocess.Popen(["git", "cat-file", "--batch"], cwd=REPO,
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    for name, digest in sorted(expected.items()):
        if name.startswith("/") or ".." in Path(name).parts or "\n" in name:
            raise ValueError("Unsafe Git source path")
        process.stdin.write((revision + ":" + name + "\n").encode())
        process.stdin.flush()
        header = process.stdout.readline().split()
        if len(header) != 3 or header[1] != b"blob":
            raise ValueError("Missing immutable blob: " + name)
        data = process.stdout.read(int(header[2]))
        if process.stdout.read(1) != b"\n" or sha(data) != digest:
            raise ValueError("Immutable baseline differs: " + name)
        result[name] = (data, "git:" + revision + ":" + name, 0o644)
    process.stdin.close()
    if process.wait() != 0:
        raise ValueError("Git cat-file failed")
    return result


def files_under(root, prefix):
    return {prefix + "/" + str(path.relative_to(root)): (path.read_bytes(), str(path), 0o644)
            for path in sorted(root.rglob("*")) if path.is_file() and "__pycache__" not in path.parts}


def append_file(files, name, path, mode=0o644):
    files[name] = (path.read_bytes(), str(path), mode)


def archive(name, files):
    target = HERE / name
    with target.open("wb") as output, gzip.GzipFile(fileobj=output, mode="wb", filename="", mtime=0, compresslevel=9) as compressed:
        with tarfile.open(fileobj=compressed, mode="w", format=tarfile.GNU_FORMAT) as bundle:
            for member_name, (data, origin, mode) in sorted(files.items()):
                entry = tarfile.TarInfo(member_name)
                entry.size, entry.mode = len(data), mode
                entry.uid = entry.gid = entry.mtime = 0
                entry.uname = entry.gname = ""
                bundle.addfile(entry, io.BytesIO(data))
    # Read back exact archived payloads before recording the binding.
    with tarfile.open(target, "r:gz") as bundle:
        extracted = {member.name: bundle.extractfile(member).read() for member in bundle.getmembers()}
    if extracted != {member: record[0] for member, record in files.items()}:
        raise ValueError("Archive payload changed")
    return {"sha256": sha(target.read_bytes()), "members": len(files),
            "member_sha256": {member: sha(record[0]) for member, record in sorted(files.items())},
            "member_bytes": {member: len(record[0]) for member, record in sorted(files.items())},
            "original_paths": {member: record[1] for member, record in sorted(files.items())}}


def correct_source_copy(files, name, digest, choices):
    for candidate in choices:
        if candidate.is_file() and sha(candidate.read_bytes()) == digest:
            append_file(files, name, candidate)
            return True
    return False


def main():
    baseline = load(RAW / "semantic-screen/baseline.manifest.json")
    candidate = load(RAW / "semantic-screen/candidate.manifest.json")
    counts = load(RAW / "counts-source-freeze.json")
    meta = load(RAW / "meta-blocks/source-freeze.json")
    if baseline["source"]["revision"] != BASE or counts["baseline_source"]["revision"] != BASE:
        raise ValueError("Unexpected base revision")

    groups = {"baseline-source.tar.gz": git_sources(baseline["source"]["sha256"])}
    groups["counts.tar.gz"] = files_under(RAW / "counts", "counts")
    append_file(groups["counts.tar.gz"], "counts-source-freeze.json", RAW / "counts-source-freeze.json")
    groups["meta-blocks.tar.gz"] = files_under(RAW / "meta-blocks", "meta-blocks")
    append_file(groups["meta-blocks.tar.gz"], "meta_blocks_probe.zig", RAW / "meta_blocks_probe.zig")
    groups["semantic-screen.tar.gz"] = files_under(RAW / "semantic-screen", "original")
    groups["semantic-source.tar.gz"] = files_under(RAW / "semantic-screen-source", "original")
    binaries = {}
    for name, path, digest in [
        ("counts/payload-counts", RAW / "payload-counts", load(RAW / "counts/distribution-overview.json")["executable"]["sha256"]),
        ("counts/payload-counts-tests", RAW / "payload-counts-tests", load(RAW / "counts/compile-identity-receipt.json")["test_probe"]["sha256"]),
        ("meta/meta-blocks-probe", RAW / "meta-blocks-probe", load(RAW / "meta-blocks/run-complete.json")["probe_sha256"]),
        ("original/baseline-compare", Path(baseline["probe"]), baseline["probe_sha256"]),
        ("original/semantic-compare", RAW / "semantic-compare", candidate["probe_sha256"]),
    ]:
        if sha(path.read_bytes()) != digest:
            raise ValueError("Frozen executable differs: " + name)
        append_file(binaries, name, path, 0o755)
    groups["probe-binaries.tar.gz"] = binaries
    runners = {}
    for name in ("semantic_screen.py", "semantic-screen.log", "semantic-kernel-build.log", "main-counts-build.log", "main-diagnostics-safe-gate.log", "meta-blocks-build.log"):
        append_file(runners, name, RAW / name)
    groups["runners-builds.tar.gz"] = runners

    proof_root = Path("/tmp/vort-mozilla-kernel-20261112.21952b95/semantic-command-proof")
    groups["correctness-supplement.tar.gz"] = files_under(proof_root, "semantic-helper")
    oracle_path = Path("/tmp/vort-semantic-wide-payload-contracts-receipt.json")
    oracle = load(oracle_path)
    proofs = groups["correctness-supplement.tar.gz"]
    append_file(proofs, "actual-kernel/receipt.json", oracle_path)
    for run in oracle["runs"]:
        path = Path(run["log"])
        if sha(path.read_bytes()) != run["log_sha256"]:
            raise ValueError("Kernel correctness log changed")
        append_file(proofs, "actual-kernel/" + path.name, path)
    available = {}
    for name, digest in oracle["source_sha256_after_final_gates"].items():
        available[name] = correct_source_copy(proofs, "actual-kernel/source/" + name, digest,
                                             [RAW / "semantic-screen-source" / name,
                                              RAW / "semantic-cold-screen-source" / name,
                                              RAW / "meta-blocks/source" / name, KERNEL / name])

    # A later screen is added only from an explicit frozen supplement descriptor.
    extra_path = HERE / "supplements.json"
    extras = load(extra_path) if extra_path.exists() else {"screens": [], "files": {}}
    screens = [{"name": "original", "source_archive": "semantic-source.tar.gz", "screen_archive": "semantic-screen.tar.gz",
                "baseline_binary": "original/baseline-compare", "candidate_binary": "original/semantic-compare"}]
    for extra in extras["screens"]:
        label = extra["name"]
        groups[label + "-screen.tar.gz"] = files_under(Path(extra["raw_root"]), label)
        manifest = load(Path(extra["raw_root"]) / "candidate.manifest.json")
        if extra.get("immutable_revision"):
            groups[label + "-source.tar.gz"] = {label + "/" + name: value for name, value in git_sources(manifest["source"]["sha256"], extra["immutable_revision"]).items()}
        else:
            groups[label + "-source.tar.gz"] = files_under(Path(extra["source_root"]), label)
        binary = Path(extra["binary"])
        if sha(binary.read_bytes()) != manifest["probe_sha256"]:
            raise ValueError("Supplement binary is not frozen: " + label)
        append_file(binaries, label + "/semantic-compare", binary, 0o755)
        screens.append({"name": label, "source_archive": label + "-source.tar.gz", "screen_archive": label + "-screen.tar.gz",
                        "baseline_binary": "original/baseline-compare", "candidate_binary": label + "/semantic-compare",
                        "candidate_revision": manifest["source"]["revision"], "source_bytes_git_revision": extra.get("immutable_revision")})
    for name, value in extras["files"].items():
        path = Path(value["path"])
        if sha(path.read_bytes()) != value["sha256"]:
            raise ValueError("Supplement changed: " + name)
        append_file(proofs, name, path)
    groups["brotli-smoke.tar.gz"] = files_under(RAW / "frozen-brotli-smoke", "smoke")
    append_file(runners, "frozen-brotli-smoke.log", RAW / "frozen-brotli-smoke.log")

    bindings = {"schema": "vort.brotli.mozilla-distributions-archive.v1", "base_revision": BASE,
                "raw_root": str(RAW), "archives": {name: archive(name, files) for name, files in groups.items()},
                "source_registries": {"counts": len(counts["baseline_source"]["sha256"]), "meta": len(meta["source"]["sha256"]),
                                      "semantic_baseline": len(baseline["source"]["sha256"]), "semantic_original": len(candidate["source"]["sha256"])},
                "screens": screens, "kernel_oracle_source_copies_available": available,
                "source_policy": "Baseline archive is read from immutable 21952b95 Git blobs, not live source. Every timing candidate uses its own frozen overlay and binary. Correctness supplements are later epochs; no retroactive source/timing identity is claimed.",
                "archive_policy": "Sorted GNU tar regular files; uid/gid/mtime 0; empty owner names; mode 0644 or binary0755; gzip9 with empty filename and mtime0",
                "screen_returncode_scope": "Original events have no separately captured returncode field; frozen runner required rc0 before recording every event and only wrote events.json after all checks. Diagnostic runs preserve explicit process returncodes.",
                "codegen_scope": "Main reconstructed codegen-audit.json from the read-only explorer's tool stdout/final message plus its own V2 ELF inspection. Original disassembler stdout was not separately saved; the offline validator independently reconstructs static ELF and natural-loop metrics from frozen binaries. No dynamic cost claim.",
                "full_72_row_acceptance_run": False, "industry_leadership_claim": False}
    write_json(HERE / "archive-bindings.json", bindings)

    modern = REPO / "docs/performance/modern-decode-refresh-20261111"
    modern_current = REPO / "docs/performance/modern-decode-current-20261111"
    modern_manifest = json.loads(gzip.decompress((modern / "manifest.json.gz").read_bytes()))
    selected = load(RAW / "counts/selected-fixtures-used.json")
    by_key = {fixture["key"]: fixture for fixture in modern_manifest["fixtures"]}
    if any(by_key[fixture["key"]] != fixture for fixture in selected):
        raise ValueError("Selected frozen fixtures differ from prior modern manifest")
    reuse = {"schema": "vort.brotli.mozilla-distributions-reuse.v1", "selected_fixtures": selected,
             "scope": "Reuse exact fixture metadata/hashes and reference SO archives; do not duplicate payloads or libraries",
             "modern_manifest": {"path": str((modern / "manifest.json.gz").relative_to(REPO)), "sha256": sha((modern / "manifest.json.gz").read_bytes())},
             "modern_reference_reuse": {"path": str((modern / "reference-reuse.json").relative_to(REPO)), "sha256": sha((modern / "reference-reuse.json").read_bytes())},
             "reference_libraries": {"path": str((modern_current / "reference-libraries.tar.gz").relative_to(REPO)), "sha256": sha((modern_current / "reference-libraries.tar.gz").read_bytes())},
             "brotli_reference": baseline["references"]["brotli"]}
    write_json(HERE / "reference-reuse.json", reuse)
    print(json.dumps({"archives": len(groups), "members": sum(len(files) for files in groups.values()), "base_revision": BASE, "screens": [s["name"] for s in screens]}, indent=2))


if __name__ == "__main__":
    main()
