#!/usr/bin/env python3
"""Offline byte/source/diff/static-output audit; never run codecs or compilers."""
import argparse
from collections import Counter
import gzip
import hashlib
import io
import json
from pathlib import Path
import re
import struct
import subprocess
import tarfile

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
BASE = "492a0a74535992cd4a7e3ad3182777414c8c0fac"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def patched_files(patch, before):
    lines, result, index = patch.splitlines(keepends=True), {}, 0
    while index < len(lines):
        if not lines[index].startswith(b"--- "):
            index += 1; continue
        old_name = lines[index][4:].strip().decode()
        index += 1
        require(lines[index].startswith(b"+++ b/"), "Unexpected patch target")
        name = lines[index][6:].strip().decode(); index += 1
        old = [] if old_name == "/dev/null" else before[name].splitlines(keepends=True)
        output, position = [], 0
        while index < len(lines) and not lines[index].startswith(b"--- "):
            header = re.match(rb"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@", lines[index])
            if not header:
                index += 1; continue
            start = max(int(header[1]) - 1, 0)
            output.extend(old[position:start]); position = start; index += 1
            while index < len(lines) and not lines[index].startswith((b"@@ ", b"--- ")):
                line = lines[index]
                if line.startswith(b"\\"):
                    index += 1; continue
                require(line[:1] in (b" ", b"+", b"-"), "Unexpected patch hunk line")
                data = line[1:]
                if index + 1 < len(lines) and lines[index + 1].startswith(b"\\ No newline"):
                    data = data.removesuffix(b"\n")
                if line[:1] in (b" ", b"-"):
                    require(position < len(old) and old[position] == data, "Patch context differs")
                    position += 1
                if line[:1] in (b" ", b"+"):
                    output.append(data)
                index += 1
        output.extend(old[position:]); result[name] = b"".join(output)
    return result


def static_counts(files, side, expected):
    asm = files[side + "-aligned.asm"].decode()
    instructions = []
    for line in asm.splitlines():
        match = re.match(r"\s*([0-9a-f]+):\s+([a-z][\w.]*)\s*(.*)", line)
        if match:
            instructions.append((int(match[1], 16), match[2], match[3]))
    require(len(instructions) == expected["static_instruction_lines_including_padding"], "Static instruction lines differ")
    require(dict(Counter(mnemonic for _, mnemonic, _ in instructions)) == expected["mnemonic_counts"], "Static mnemonic counts differ")
    negative = sum(len(re.findall(r"-0x[0-9a-f]+\(%rbp", operands)) for _, _, operands in instructions)
    require(negative == expected["negative_rbp_operand_references"], "Whole-symbol RBP references differ")
    address = int(expected["symbol_address"], 16)
    require(instructions[0][0] == address, "Disassembly begins at wrong symbol")
    frame = next(int(re.search(r"\$0x([0-9a-f]+),%rsp", operands)[1], 16) for _, mnemonic, operands in instructions[:15] if mnemonic == "sub" and "%rsp" in operands)
    require(frame == expected["local_stack_reservation_bytes"], "Explicit stack reservation differs")
    nm = files[side + "-nm.txt"].decode()
    symbol = next(line.split() for line in nm.splitlines() if line.endswith(" deflate.semantic.linear_entry.aligned"))
    require(int(symbol[0], 16) == address and int(symbol[1], 16) == expected["symbol_bytes"], "nm symbol address/size differs")
    sections = files[side + "-sections.txt"].decode()
    text = re.search(r"\s+\d+ \.text\s+([0-9a-f]+)", sections)
    require(text and int(text[1], 16) == expected["elf_text_section_bytes"], "Section text total differs")


def verify(original=False):
    binding = json.loads((HERE / "archive-bindings.json").read_bytes())
    archive_data = (HERE / binding["archive"]).read_bytes()
    require(sha(archive_data) == binding["archive_sha256"], "Archive SHA differs")
    require(archive_data[:4] == b"\x1f\x8b\x08\x00" and archive_data[4:8] == bytes(4), "Non-deterministic gzip header")
    files = {}
    with tarfile.open(fileobj=io.BytesIO(gzip.decompress(archive_data)), mode="r:") as archive:
        members = archive.getmembers()
        require([m.name for m in members] == sorted({m.name for m in members}), "Duplicate/unsorted names")
        for member in members:
            require(member.isfile() and not member.name.startswith("/") and ".." not in Path(member.name).parts, "Unsafe member")
            require(member.uid == member.gid == member.mtime == 0 and member.uname == member.gname == "", "Metadata not normalized")
            require(member.mode == (0o755 if member.name in binding["executable_members"] else 0o644), "Wrong archive mode")
            files[member.name] = archive.extractfile(member).read()
    require(len(files) == binding["members"] == 36 and {name: sha(data) for name, data in files.items()} == binding["member_sha256"], "Original packet bytes differ")
    require(len(files["SHA256SUMS"].decode().splitlines()) == 35, "Producer checksum-covered file count differs")
    require({name: len(data) for name, data in files.items()} == binding["member_bytes"], "Packet lengths differ")
    if original:
        require(all((Path(binding["raw_root"]) / name).read_bytes() == data for name, data in files.items()), "Still-retained original bytes differ")
    for line in files["SHA256SUMS"].decode().splitlines():
        digest, name = line.split("  ", 1)
        require(sha(files[name]) == digest, "Producer checksum differs: " + name)
    receipt = json.loads(files["validation-receipt.json"])
    freeze = json.loads(files["candidate-freeze.json"])
    before_freeze = json.loads(files["before-freeze.json"])
    registry = json.loads(files["source-registry.json"])
    require(len(registry) == freeze["registry_count"] == 2765 and sha(files["source-registry.json"]) == freeze["source_registry_sha256"] == receipt["source_registry_sha256"], "Producer registry identity differs")
    before = {name.removeprefix("before-source/"): data for name, data in files.items() if name.startswith("before-source/")}
    candidate = {name.removeprefix("candidate-source/"): data for name, data in files.items() if name.startswith("candidate-source/")}
    require(len(before) == 4 and len(candidate) == 6, "Source overlay counts differ")
    require({name: sha(data) for name, data in before.items()} == before_freeze["source_sha256"], "Synchronized baseline overlay differs")
    require({name: sha(data) for name, data in candidate.items()} == freeze["source_sha256"] == receipt["source_overlay_sha256"], "Candidate overlay differs")
    changed = patched_files(files["candidate-only.patch"], before)
    require(set(changed) == set(receipt["owned_worktree_files"]), "Patch contains synchronized main changes")
    require(all(changed[name] == candidate[name] for name in changed), "Candidate-only patch does not reconstruct prototype")
    require(all(before[name] == candidate[name] for name in before if name not in changed), "Synchronized baseline files changed")
    process = subprocess.Popen(["git", "cat-file", "--batch"], cwd=REPO, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    for name, digest in registry.items():
        if name in candidate:
            data = candidate[name]
        else:
            process.stdin.write((BASE + ":" + name + "\n").encode()); process.stdin.flush()
            header = process.stdout.readline().split(); require(len(header) == 3 and header[1] == b"blob", "Immutable registered source missing")
            data = process.stdout.read(int(header[2])); require(process.stdout.read(1) == b"\n", "Bad Git batch")
        require(sha(data) == digest, "Registered source reconstruction differs: " + name)
    process.stdin.close(); require(process.wait() == 0, "Git source read failed")
    require(sha(files["candidate-compare"]) == sha(files["install/bin/vort-decode-compare"]) == receipt["probe_sha256"] == freeze["probe_sha256"], "Candidate executable differs")
    require(sha(files["baseline-compare"]) == receipt["baseline_probe_sha256"] == freeze["baseline_probe_sha256"], "Baseline executable differs")
    require(not receipt["benchmark_or_perf_executed"] and not receipt["git_stage_commit_push_performed"] and receipt["source_overlay_verified_unchanged_after_validation"], "Producer scope differs")
    expected_tests = (("helper_ReleaseSafe", "helper-safe.log", 2), ("filtered_public_generic_and_private_fallback_ReleaseSafe", "narrow-safe.log", 11), ("fullDeflateSafe", "fullDeflateSafe.log", 739))
    for key, log, count in expected_tests:
        require(receipt["validation"][key]["exit_code"] == 0 and receipt["validation"][key]["test_count"] == count and ("All " + str(count) + " tests passed.").encode() in files[log], "Recorded test proof differs")
    require(receipt["validation"]["helper_ReleaseSafe"]["complete_legal_pairs"] == 256 * 32768 == 8388608, "Exhaustive pair domain differs")
    require(receipt["validation"]["ReleaseFast_build_decode_compare"]["exit_code"] == 0 and b"7/7 steps succeeded" in files["build-decode-compare.log"], "ReleaseFast build proof differs")
    counts = json.loads(files["codegen-counts.json"])
    for side in ("baseline", "candidate"):
        static_counts(files, side, counts[side])
    for name, delta in counts["delta"].items():
        require(counts["candidate"][name] - counts["baseline"][name] == delta, "Static codegen delta differs")
    return {"schema": "vort.deflate.completed-match-offline-validation.v1", "original_members": 36, "producer_checksum_covered_files": 35,
            "registry_count": 2765, "registry_scope": "producer-defined registered paths only; not automatically complete compiler inputs",
            "frozen_source_counts": {"before": 4, "candidate": 6}, "candidate_only_patch_files": sorted(changed),
            "baseline_sha256": receipt["baseline_probe_sha256"], "candidate_sha256": receipt["probe_sha256"],
            "recorded_tests": {"helper": 2, "legal_pairs": 8388608, "filtered": 11, "full": 739},
            "static_delta": counts["delta"], "original_bytes_checked": original,
            "scope": "Offline byte/source/diff/test-receipt/raw-static-output validation only; no test or A/B/perf execution, no dynamic spill/heap/speed claim; prototype rejected"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--original-bytes", action="store_true")
    parser.add_argument("--receipt", type=Path)
    args = parser.parse_args()
    data = json.dumps(verify(args.original_bytes), indent=2, sort_keys=True) + "\n"
    if args.receipt:
        args.receipt.write_text(data)
    print(data, end="")


if __name__ == "__main__":
    main()
