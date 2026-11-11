#!/usr/bin/env python3
"""Verify frozen public linear contracts offline; run with taskset -c 0."""
import argparse
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import tarfile

BASE = "8adfb3bae74409bae146fed2ed9b6594a1d3cdb8"


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def unpack(path):
    data = path.read_bytes()
    require(data[:4] == b"\x1f\x8b\x08\x00" and data[4:8] == bytes(4), "Gzip header differs")
    files = {}
    with tarfile.open(fileobj=io.BytesIO(gzip.decompress(data)), mode="r:") as archive:
        members = archive.getmembers()
        require([m.name for m in members] == sorted({m.name for m in members}), "Tar member order differs")
        for member in members:
            require(member.isfile() and not member.name.startswith("/") and ".." not in Path(member.name).parts, "Unsafe tar member")
            require(member.uid == member.gid == member.mtime == 0 and member.uname == member.gname == "", "Tar metadata differs")
            files[member.name] = archive.extractfile(member).read()
    return files


def checksum_inventory(root):
    path = root / "SHA256SUMS"
    if not path.exists():
        return
    hashes = {name: digest for digest, name in (line.split("  ", 1) for line in path.read_text().splitlines())}
    require(set(hashes) == {p.name for p in root.iterdir() if p.is_file() and p != path}, "Checksum inventory differs")
    require(all(sha((root / name).read_bytes()) == digest for name, digest in hashes.items()), "Checksum differs")


def dynamic_header(data):
    position = 0
    def read(width):
        nonlocal position
        require(position + width <= len(data) * 8, "Header truncated")
        value = sum(((data[(position + i) // 8] >> ((position + i) % 8)) & 1) << i for i in range(width))
        position += width
        return value
    _ = read(1)
    require(read(2) == 2, "Expected dynamic block")
    hlit, hdist, hclen = read(5) + 257, read(5) + 1, read(4) + 4
    order = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]
    lengths = [0] * 19
    for symbol in order[:hclen]:
        lengths[symbol] = read(3)
    counts = {width: lengths.count(width) for width in range(1, 8)}
    next_code, code = {}, 0
    for width in range(1, 8):
        code = (code + counts.get(width - 1, 0)) << 1
        next_code[width] = code
    codes = {}
    for symbol, width in enumerate(lengths):
        if width:
            codes[width, next_code[width]] = symbol
            next_code[width] += 1
    def decode():
        code = 0
        for width in range(1, 8):
            code = (code << 1) | read(1)
            if (width, code) in codes:
                return codes[width, code]
        raise ValueError("Invalid code-length prefix")
    result = []
    while len(result) < hlit + hdist:
        symbol = decode()
        if symbol < 16:
            result.append(symbol)
        elif symbol == 16:
            require(bool(result), "Repeat lacks previous length")
            result.extend([result[-1]] * (3 + read(2)))
        else:
            result.extend([0] * ((3 + read(3)) if symbol == 17 else (11 + read(7))))
        require(len(result) <= hlit + hdist, "Length repeat overruns alphabet")
    ll, dist = result[:hlit], result[hlit:]
    def complete(values):
        maximum = max(values)
        return sum(1 << (maximum - width) for width in values if width) == 1 << maximum
    return {"hlit": hlit, "hdist": hdist, "header_bits": position, "literal_max_bits": max(ll),
            "distance_max_bits": max(dist), "literal_leaves": sum(v != 0 for v in ll),
            "distance_leaves": sum(v != 0 for v in dist), "literal_complete": complete(ll), "distance_complete": complete(dist)}


def verify(root, baseline_package, originals=False, git_repo=None):
    checksum_inventory(root)
    binding = json.loads((root / "archive-bindings.json").read_text())
    require(binding["base_revision"] == BASE, "Functional base epoch rebound")
    archives, original_count = {}, 0
    for name, record in binding["archives"].items():
        files = unpack(root / name)
        require({name: sha(data) for name, data in files.items()} == record["files"], "Archived bytes differ")
        archives[name] = files
        if originals:
            for member, origin in record["origins"].items():
                require(Path(origin).read_bytes() == files[member], "Original retained bytes differ")
                original_count += 1
    reuse = binding["reuse"]
    source_path = baseline_package / "shared-dispatch-source.tar.gz"
    require(sha(source_path.read_bytes()) == reuse["source_archive_sha256"], "Reused baseline container differs")
    base = {name.removeprefix(reuse["source_prefix"]): data for name, data in unpack(source_path).items()}
    raw, source, binaries, fixtures = [archives[name] for name in ("raw-validation.tar.gz", "source-overlay.tar.gz", "test-executables.tar.gz", "small-fixtures.tar.gz")]
    validation = json.loads(raw["validation.json"])
    require(sha(raw["validation.json"]) == "60467185e9e59d32b876ab864fd442628fcba3477fcb20eb7b56f27180ff8622" and (root / "validation.json").read_bytes() == raw["validation.json"], "Original validation bytes differ")
    require({name: sha(data) for name, data in source.items()} == validation["source_sha256"] == json.loads(raw["source-sha256.json"]), "Frozen source hashes differ")
    require(len(source) == 3 and validation["source_unchanged"] is True and validation["behavioral_public_scenarios"] == 27 and validation["direct_root_calls"] == 2, "Behavioral counts differ")
    for name, hook in (("src/deflate.zig", "Deflate public generic semantic linear contracts"), ("src/root.zig", "root public generic semantic linear contracts")):
        removed, count = re.subn(r'\ntest "' + hook + r'" \{.*?\n\}\n', '', source[name].decode(), count=1, flags=re.S)
        require(count == 1 and removed.encode() == base[name], "Change includes more than the declared test hookup")
    require(len(validation["runs"]) == 8, "Missing validation runs")
    for run in validation["runs"]:
        data = raw[run["raw_log"]]
        require(run["returncode"] == 0 and sha(data) == run["raw_log_sha256"] and sha(binaries[run["executable"]]) == run["executable_sha256"], "Run log/executable identity differs")
        require(("All " + str(run["tests_passed"]) + " tests passed.").encode() in data, "Successful test output missing")
        if run["tests_passed"] in (8, 90):
            imports = sum(re.search(rb"\.test_[0-9]+\.\.\.OK$", line) is not None for line in data.splitlines())
            require(imports == (7 if run["tests_passed"] == 8 else 88), "Aggregate/import scope differs")
        if run["executable"].endswith(".wasm"):
            require(binaries[run["executable"]][:8] == b"\0asm\x01\0\0\0" and b"wasi_snapshot_preview1" in binaries[run["executable"]], "WASI artifact differs")
    osdb = fixtures["osdb-zlib6-64k.deflate"]
    require(sha(osdb) == validation["fixture_sha256"] and osdb == base[binding["fixture_git_path"]], "Original Git OSDB fixture differs")
    shape14 = dynamic_header(osdb)
    require((shape14["hlit"], shape14["hdist"], shape14["header_bits"], shape14["literal_max_bits"], shape14["distance_max_bits"], shape14["distance_leaves"]) == (279, 30, 762, 14, 9, 22) and shape14["literal_complete"] and shape14["distance_complete"], "Real LL14 header shape differs")
    shape10 = dynamic_header(fixtures["ll10-missing-distance-primary.deflate"])
    require(shape10["literal_max_bits"] == 10 and shape10["header_bits"] == 1226 and shape10["literal_leaves"] == 11 and shape10["literal_complete"] and shape10["distance_leaves"] == 2 and not shape10["distance_complete"], "LL10 malformed witness differs")
    oracle = json.loads(raw["oracle-validation.json"])
    require((root / "oracle-validation.json").read_bytes() == raw["oracle-validation.json"] and oracle["status"] == "pass" and oracle["case_count"] == oracle["passed_case_count"] == 8 and oracle["zlib_runtime_version"] == "1.2.11", "Post-freeze oracle status differs")
    require(sha(raw["oracle.py"]) == oracle["oracle_script_sha256"] == "8d7ae9a7281a0c6a5584178ee1f98fcdbb15ddd5ef6b002ad376514f177210f2", "Original oracle source differs")
    records = [json.loads(line) for line in raw["oracle.log"].splitlines()]
    cases = [{key: value for key, value in record.items() if key != "record"} for record in records if record["record"] == "case"]
    require(cases == oracle["cases"] and records[-1]["status"] == "pass", "Exact oracle stdout/cases differ")
    for case in cases:
        wire = fixtures[case["case_id"] + ".deflate"]
        require(len(wire) == case["wire_length_bytes"] and sha(wire) == case["wire_sha256"] and case["pass"] is True, "Small bare-wire fixture differs")
        if case["expected"]["outcome"] == "success":
            size = case["expected"]["output_length_bytes"]
            require(case["actual"]["output_length_bytes"] == size and case["actual"]["output_sha256"] == sha(bytes(size)), "Recorded zero output differs")
        else:
            require(case["actual"]["zlib_error_code"] == (-3 if case["expected"]["error_category"] == "invalid_history" else -5), "Recorded oracle rejection differs")
    git_count = 0
    if git_repo:
        names = list(base)
        result = subprocess.run(["git", "cat-file", "--batch"], cwd=git_repo, input=''.join(BASE + ':' + name + '\n' for name in names).encode(), capture_output=True, check=True)
        offset = 0
        for name in names:
            end = result.stdout.index(b"\n", offset); parts = result.stdout[offset:end].split(); require(len(parts) == 3 and parts[1] == b"blob", "Missing frozen baseline Git blob")
            size = int(parts[2]); offset = end + 1
            require(result.stdout[offset:offset + size] == base[name], "Baseline Git blob differs")
            offset += size + 1; git_count += 1
        oid = subprocess.check_output(["git", "rev-parse", BASE + ':' + binding["fixture_git_path"]], cwd=git_repo, text=True).strip()
        require(oid == binding["fixture_git_blob"], "Fixture Git object identity differs")
        if binding.get("equivalent_test_commit"):
            for name, data in source.items():
                require(subprocess.check_output(["git", "show", binding["equivalent_test_commit"] + ':' + name], cwd=git_repo) == data, "Equivalent test commit differs")
    return {"schema": "vort.deflate.public-linear-archive-validation.v1", "valid": True,
            "scope": "independent raw-byte/source/shape/recorded-oracle validation; no compiler, codec or benchmark rerun",
            "cpu_affinity": sorted(os.sched_getaffinity(0)), "base_revision": BASE, "source_overlay_files": 3,
            "baseline_git_blobs_verified": git_count, "validation_runs": 8, "public_scenarios": 27,
            "direct_root_calls": 2, "filtered_deflate_aggregate_import_tests": 8, "filtered_root_aggregate_import_tests": 90,
            "full_deflate_tests": 734, "test_only_hookups": True, "original_files_verified": original_count,
            "ll14_shape": shape14, "ll10_shape": shape10, "recorded_zlib_oracle_cases": 8,
            "oracle_is_new_post_freeze_revalidation": True, "new_production_wire_bug_fixed": False, "performance_claim": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-package", type=Path)
    parser.add_argument("--originals", action="store_true")
    parser.add_argument("--git-repo", type=Path)
    args = parser.parse_args(); root = Path(__file__).resolve().parent
    baseline = args.baseline_package or root.parents[1] / "br/decode-mozilla-distributions-20261112"
    print(json.dumps(verify(root, baseline, args.originals, args.git_repo), indent=2))


if __name__ == "__main__":
    main()
