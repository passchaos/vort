"""Validate the saved source handoff and static code-generation observations."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile

from evidence import require
from screen import summarize


def digest(data):
    return hashlib.sha256(data).hexdigest()


def verify(package, capture):
    source = json.loads((package / "source.json").read_text())
    manifest = json.loads((capture / "manifest.json").read_text())
    summary = json.loads((package / "summary.json").read_text())
    require(summary == summarize(capture), "Summary does not reproduce")
    require(manifest["base_revision"] == source["base_revision"], "Wrong source epoch")
    patch = gzip.decompress((package / "candidate.patch.gz").read_bytes())
    require(digest(patch) == manifest["candidate_patch_sha256"] == source["candidate_patch_sha256"], "Wrong timing patch")
    for side in ("baseline", "candidate"):
        require(manifest["probes"][side]["sha256"] == source["probe_sha256"][side], "Wrong timed executable")
    original = gzip.decompress((package / "baseline-decoder.zig.gz").read_bytes())
    candidate = gzip.decompress((package / "candidate-decoder.zig.gz").read_bytes())
    require(digest(original) == source["baseline_source_sha256"], "Original source changed")
    require(digest(candidate) == source["candidate_source_sha256"], "Candidate source changed")
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        file = root / source["decoder_source"]
        file.parent.mkdir(parents=True)
        file.write_bytes(original)
        subprocess.run(["git", "apply", "-"], input=patch, cwd=root, check=True)
        require(file.read_bytes() == candidate, "Patch does not reconstruct the candidate")
    codegen = json.loads((package / "codegen.json").read_text())
    for side in ("baseline", "candidate"):
        asm = gzip.decompress((package / (side + "-aligned.asm.gz")).read_bytes()).decode()
        instructions = [line for line in asm.splitlines() if re.match(r"\s*[0-9a-f]+:\s+\S", line)]
        observed = codegen[side]
        _, size, _, name = (package / (side + "-symbol.txt")).read_text().split()
        require(name == "deflate.semantic.linear_entry.aligned" and int(size, 16) == observed["symbol_bytes"], "Raw nm symbol size drift")
        require(len(instructions) == observed["whole_symbol_instruction_lines"], "Instruction count drift")
        stack = re.findall(r"sub\s+\$0x([0-9a-f]+),%rsp", asm)
        require(int(stack[0], 16) == observed["prologue_stack_bytes"], "Stack reservation drift")
        require(sum(bool(re.search(r"-0x[0-9a-f]+\(%rbp", line)) for line in instructions) == observed["negative_rbp_references"], "Static stack operand count drift")
        for operation, count in observed["mnemonics"].items():
            require(sum(bool(re.search(r"\b" + operation + r"\b", line)) for line in instructions) == count, "Mnemonic count drift")
    contracts = json.loads((package / "contract-summary.json").read_text())
    fast = json.loads((package / "release-fast-receipt.json").read_text())
    require(contracts["base_revision"] == source["base_revision"], "Wrong contract epoch")
    require(contracts["oracle_sha256"] == source["baseline_source_sha256"] and contracts["candidate_sha256"] == source["candidate_source_sha256"], "Wrong differential sources")
    with tarfile.open(package / "contract-sources.tar.gz") as archive:
        root = archive.extractfile("src/copy_handoff_tests.zig").read()
        oracle = archive.extractfile("src/deflate/semantic/copy_handoff_reference.zig").read()
    require(digest(root) == contracts["test_root_sha256"] == fast["root_sha256"], "Differential test source drift")
    require(oracle == original, "Differential oracle is not the original source")
    require(sum(contracts["case_counts_by_mode"].values()) == contracts["differential_cases_each_build"], "Mode case accounting drift")
    require(fast["build_exit_code"] == fast["run_exit_code"] == 0, "Failed ReleaseFast differential")
    with tarfile.open(package / "contract-reports.tar.gz") as archive:
        for mode in ("debug", "release-safe", "release-fast"):
            output = archive.extractfile("contract-differential/" + mode + ".stderr").read().decode()
            require("All 2 tests passed." in output, "Incomplete differential runner")
            values = re.search(r"copy_handoff cases=(\d+) paired_calls=(\d+) fast_loop_admissions=(\d+) pauses=(\d+) errors=(\d+)", output)
            require(values is not None, "Missing case counters")
            fields = ("differential_cases_each_build", "paired_calls_each_build", "fast_loop_admissions_each_build", "pause_results_each_build", "error_results_each_build")
            require(tuple(map(int, values.groups())) == tuple(contracts[field] for field in fields), "Differential execution counts drift")
    print("Verified source reconstruction, paired timing samples, static code counts and all three differential runs")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    parser.add_argument("capture", type=Path)
    args = parser.parse_args()
    verify(args.package, args.capture)
