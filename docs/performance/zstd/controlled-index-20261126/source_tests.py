"""Source snapshots, recorded test terminals and complete benchmark ELF sections."""
import posixpath
import re
import struct

from archive_io import load, require, sha


def text_section(data):
    require(data[:6] == b"\x7fELF\x02\x01", "Expected little-endian ELF64")
    offset = struct.unpack_from("<Q", data, 40)[0]
    size, count, names_index = struct.unpack_from("<HHH", data, 58)
    names_header = offset + names_index * size
    names_offset, names_size = struct.unpack_from("<QQ", data, names_header + 24)
    names = data[names_offset:names_offset + names_size]
    for index in range(count):
        position = offset + index * size
        name_offset = struct.unpack_from("<I", data, position)[0]
        name = names[name_offset:].split(b"\0", 1)[0]
        if name == b".text":
            return struct.unpack_from("<Q", data, position + 32)[0]
    raise ValueError("ELF .text section is absent")


def verify_sources(campaign, sources, resources):
    mapping = load(sources, "source-mapping.json")
    counts = {}
    for label, record in mapping["variants"].items():
        actual = {name.removeprefix(label + "/"): sha(data) for name, data in sources.items() if name.startswith(label + "/src/")}
        recorded, snapshot = load(sources, label + "/source-identity.json"), load(sources, label + "/archived-src-sha256.json")
        require(actual == snapshot and all(actual.get(name) == digest for name, digest in recorded.items()), "Variant source snapshot differs")
        require(sorted(set(actual) - set(recorded)) == record["unrecorded_test_only_additions"] and len(actual) == record["source_files"],
                "Variant test-only addition differs")
        require(sha(campaign["bin/" + record["binary"]]) == record["binary_sha256"], "Variant benchmark ELF differs")
        counts[label] = {"recorded_files": len(recorded), "archived_files": len(actual), "extra_test_only_paths": record["unrecorded_test_only_additions"]}
    index = load(sources, "index/archived-src-sha256.json")
    earlier = load(campaign, "index-source-identity.json")
    require(all(index.get(name) == digest for name, digest in earlier.items()) and
            sorted(set(index) - set(earlier)) == ["src/zstd_index_equivalence_gate.zig"], "Earlier/final index source snapshot differs")
    baseline = {name.removeprefix("baseline-oracle/"): sha(data) for name, data in sources.items() if name.startswith("baseline-oracle/src/")}
    resource_baseline = load(resources, "baseline-source-before.json")
    require(all(baseline[name] == resource_baseline[name] for name in baseline.keys() & resource_baseline.keys()), "Common baseline/oracle source differs")
    oracle_only = sorted(set(baseline) - set(resource_baseline))
    resource_only = sorted(set(resource_baseline) - set(baseline))
    require(oracle_only == ["src/zstd_search_reference.zig"] and
            resource_only == ["src/deflate/zlib/fixtures/__pycache__/generate_small_cinfo.cpython-310.pyc"],
            "Unexpected independent oracle/resource source-scope difference")
    for label, registry in (("baseline", resource_baseline), ("candidate", index)):
        require(load(resources, label + "-source-before.json") == load(resources, label + "-source-after.json") ==
                load(resources, label + "-original-source-after.json") == registry, "Resource/archived source differs")
        actual = {name.removeprefix(label + "-source/"): sha(data) for name, data in resources.items() if name.startswith(label + "-source/src/")}
        require(actual == registry, "Resource full src snapshot differs")
    identity = load(campaign, "baseline-identity.json")
    require(sha(campaign["bin/baseline"]) == identity["executable_sha256"], "Corrected baseline benchmark ELF differs")
    for name, digest in identity["codec_source"].items():
        require(baseline[name] == digest, "Baseline parser oracle source differs")
    sections = load(campaign, "elf-sections.json")
    sizes = {}
    for row in sections["rows"]:
        sizes[row["variant"]] = text_section(campaign["bin/" + row["variant"]])
        require(sizes[row["variant"]] == row["sections"][".text"], "Complete ELF text-size receipt differs")
    require(sizes["candidate"] / sizes["baseline"] == sections["text_ratio"], "Complete ELF text ratio differs")
    return {"variants": counts, "baseline_oracle_files": len(baseline), "baseline_head": identity["head"],
            "baseline_oracle_resource_scope_difference": {"oracle_only": oracle_only, "resource_only": resource_only,
                "common_source_hashes_all_equal": True, "scope": "Independent parser oracle contains its test helper and omits the unrelated recorded Python cache; full resource baseline snapshot retained separately"},
            "complete_benchmark_elf_text_bytes": sizes, "complete_benchmark_elf_text_ratio": sections["text_ratio"],
            "scope": "All recorded src bytes verified, including explicit test-only additions and unrelated recorded Python cache. Real src/build/tools retained; docs/bench/corpus/vail symlinks excluded. ELF .text is full benchmark text, not isolated codec text or RSS."}


def verify_tests(data):
    require(b"Build Summary: 5/5 steps succeeded; 1491/1491 tests passed" in data["full-zstd.stderr"] and
            b"Build Summary: 5/5 steps succeeded; 62/62 tests passed" in data["full-controls.stderr"], "Recorded full test terminals differ")
    for name in ("index-planner.stderr", "validation/wasm-run.stderr"):
        require(b"All 23 tests passed." in data[name], "Recorded planner/WASI test terminal differs")
    require(b"validated RLE prefix model=4294967296 actual-final-input=7 wire-tail=4 bytes" in data["full-zstd.stderr"], "Recorded large-prefix marker differs")
    wasi = load(data, "validation/wasm-run.stdout")
    module = wasi["results"][0]
    require(wasi["status"] == "ok" and module["exit_code"] == 0 and
            sha(data["validation/controlled-kernels.wasm"]) == module["wasm_sha256"] and
            len(data["validation/controlled-kernels.wasm"]) == module["wasm_bytes"], "Actual WASI module/run receipt differs")
    attempts = {}
    for label in ("kernel-native", "kernel-gate-native"):
        receipt = load(data, "validation/" + label + ".exit.json")
        require(sha(data["validation/" + label + ".stderr"]) == receipt["stderr_sha256"] and
                sha(data["validation/" + label + ".stdout"]) == receipt["stdout_sha256"], "Focused native attempt output differs")
        attempts[label] = receipt["exit_code"]
    require(attempts == {"kernel-native": 1, "kernel-gate-native": 0}, "Original failed/successful focused attempts differ")
    return {"full_native_tests_recorded": 1491, "public_control_suite_tests_recorded": 62,
            "planner_tests_recorded": 23, "wasi_tests_recorded": 23, "large_prefix_test_marker_recorded": 1,
            "wasi_module_sha256": module["wasm_sha256"], "focused_attempt_exit_codes": attempts,
            "native_full_suite_exit_receipt": None,
            "scope": "Full native/control suites use actual final 5/5success logs; no vanished-session exit fabricated. Zig failed-command hints retained before terminal success. Initial direct-module-path failure retained, root-level focused harness passed. WASI verified by saved module/run23 output only; no tests executed offline."}
