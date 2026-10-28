#!/usr/bin/env python3
"""Audit the separate Vector3 negative epoch without changing prior archives."""

import argparse
import json
from pathlib import Path

import audit

ROOT = Path(__file__).resolve().parent
REVISION = "26d9eb062da7dedded4aa1e3b639d76a53192d4f"
STATE = "src/zstd/match/hq_parser/state.zig"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--libzstd", type=Path, default=Path("/home/passchaos/Work/zstd/lib/libzstd.so.1.6.0"))
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    index = json.loads((ROOT / "vector-index.json").read_text())
    audit.require(index["source_revision"] == REVISION, "vector revision")
    for name, digest in index["protected_original_artifacts"].items():
        audit.require(audit.sha((ROOT / name).read_bytes()) == digest, (name, "original archive changed"))
    if (ROOT / "vector-manifest.json").exists():
        for entry in json.loads((ROOT / "vector-manifest.json").read_text())["artifacts"]:
            data = (ROOT / entry["path"]).read_bytes()
            audit.require(len(data) == entry["bytes"] and audit.sha(data) == entry["sha256"],
                          "vector artifact identity")
    original_index = json.loads((ROOT / "index.json").read_text())
    shared = {a["path"]: a for a in original_index["archives"]}
    baseline = audit.unpack(shared[index["shared_baseline_archive"]])
    inputs = audit.unpack(shared[index["shared_inputs_archive"]])
    files = audit.unpack(index["archive"])
    source_count = audit.baseline_git(baseline)
    candidate = audit.patch(baseline[STATE], files["source.diff"].decode(), STATE)
    old = (b"            old.repeats[0] == candidate.repeats[0] and\n"
           b"            old.repeats[1] == candidate.repeats[1] and\n"
           b"            old.repeats[2] == candidate.repeats[2])")
    new = (b"            blk: {\n"
           b"                const old_vector: @Vector(3, usize) = old.repeats;\n"
           b"                const candidate_vector: @Vector(3, usize) = candidate.repeats;\n"
           b"                break :blk @reduce(.And, old_vector == candidate_vector);\n"
           b"            })")
    audit.require(baseline[STATE].count(old) == 1 and candidate == baseline[STATE].replace(old, new),
                  "only exact three-value vector expression")
    provenance = json.loads(files["source-provenance.json"])
    audit.require(audit.sha(candidate) == provenance["candidate_state_sha256"], "candidate source identity")
    audit.require(audit.sha(files["runner.zig"]) == provenance["runner_sha256"], "runner identity")
    for mode in ("debug", "releasefast", "x86"):
        result = json.loads(files["contracts-" + mode + ".json"])
        audit.require(result["exit_code"] == 0 and result["tests_passed"] == 3, (mode, "contract terminal"))
    compile_result = json.loads(files["compile-terminal.json"])
    audit.require(compile_result["exit_codes"] == [0, 0], "ordinary compile terminal")
    code = files["candidate-insert.asm"].decode()
    audit.require("vpcmpeqq" in code and "vpextrb" in code, "actual SIMD compare and lane reduction")
    metadata = {"ordinary_binaries": index["ordinary_binaries"]}
    ratios, wires = audit.screen_audit("vector", metadata, files, inputs)
    audit.require(all(r > 1 for row in ratios for r in row["paired_ratios"]), "all configurations regress twice")
    decode = audit.reference_decode(wires, args.libzstd)
    if (ROOT / "vector-reference-decode.json").exists():
        audit.require(decode == json.loads((ROOT / "vector-reference-decode.json").read_text()),
                      "stored vector reference decode")
    result = {"status": "ok", "baseline_git_blobs_verified": source_count,
              "protected_original_artifacts": len(index["protected_original_artifacts"]),
              "vector_archive_members": len(files), "ordinary_encodes": 24, "original_native_decodes": 48,
              "wire_profile_pairs": 12, "ratios": ratios, "decision": "not adopted: all paired ratios exceed one",
              "independent_reference": {k: decode[k] for k in ("library", "library_sha256", "version", "wires_decoded")}}
    if args.write:
        (ROOT / "vector-reference-decode.json").write_text(json.dumps(decode, indent=2, sort_keys=True) + "\n")
        (ROOT / "vector-audit-result.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: result[k] for k in ("status", "protected_original_artifacts", "ordinary_encodes",
                                           "original_native_decodes", "wire_profile_pairs", "independent_reference")}, sort_keys=True))


if __name__ == "__main__":
    main()
