#!/usr/bin/env python3
"""Audit two isolated exploratory HQ screens; optionally decode their wires."""

import argparse
import ctypes
from fractions import Fraction
import hashlib
import io
import json
import lzma
from pathlib import Path
import re
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parent
REVISION = "26d9eb062da7dedded4aa1e3b639d76a53192d4f"


def require(value, message):
    if not value:
        raise AssertionError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def unpack(entry):
    data = (ROOT / entry["path"]).read_bytes()
    require(len(data) == entry["bytes"] and sha(data) == entry["sha256"], entry["path"])
    files = {}
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:xz") as archive:
        for member in archive:
            require(member.isfile() and member.name not in files, "archive member type/duplicate")
            require(not member.name.startswith("/") and ".." not in Path(member.name).parts, "archive member path")
            files[member.name] = archive.extractfile(member).read()
    require(set(files) == set(entry["members"]), "archive member set")
    for name, blob in files.items():
        expected = entry["members"][name]
        require(len(blob) == expected["bytes"] and sha(blob) == expected["sha256"], name)
    return files


def patch(before, diff, path):
    require([line for line in diff.splitlines() if line.startswith(("--- ", "+++ "))]
            == ["--- baseline/" + path, "+++ candidate/" + path], "patch source scope")
    lines = before.decode().splitlines(keepends=True)
    output, cursor = [], 0
    body = diff.splitlines(keepends=True)
    at = 0
    while at < len(body):
        header = re.match(r"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@", body[at])
        if not header:
            at += 1
            continue
        start = int(header[1]) - 1
        require(start >= cursor, "patch ordering")
        output.extend(lines[cursor:start])
        cursor, old_count, new_count = start, 0, 0
        at += 1
        while at < len(body) and not body[at].startswith("@@ "):
            line = body[at]
            require(line[:1] in (" ", "-", "+"), "patch line")
            if line[:1] in (" ", "-"):
                require(lines[cursor] == line[1:], "patch context")
                cursor += 1
                old_count += 1
            if line[:1] in (" ", "+"):
                output.append(line[1:])
                new_count += 1
            at += 1
        require(old_count == int(header[2] or 1) and new_count == int(header[4] or 1), "patch hunk counts")
    output.extend(lines[cursor:])
    return "".join(output).encode()


def median(values):
    values = sorted(values)
    half = len(values) // 2
    return (Fraction(values[half]) if len(values) % 2
            else Fraction(values[half - 1] + values[half], 2))


def baseline_git(source):
    result = subprocess.run(["git", "ls-tree", "-rz", REVISION, "--", "src", "build.zig", "build.zig.zon"],
                            cwd=ROOT.parents[3], check=True, capture_output=True)
    expected = {}
    for item in result.stdout.split(b"\0"):
        if not item:
            continue
        metadata, name = item.split(b"\t", 1)
        _, kind, digest = metadata.split()
        require(kind == b"blob", "Git entry type")
        expected[name.decode()] = digest.decode()
    require(set(expected) == set(source), "baseline source names")
    for name, blob in source.items():
        digest = hashlib.sha1(b"blob " + str(len(blob)).encode() + b"\0" + blob).hexdigest()
        require(digest == expected[name], (name, "Git identity"))
    return len(expected)


def source_audit(name, meta, files, baseline):
    path = meta["changed_source"]
    original = baseline[path]
    candidate = patch(original, files["source.diff"].decode(), path)
    require(sha(original) == meta["baseline_source_sha256"]
            and sha(candidate) == meta["candidate_source_sha256"], (name, "source hashes"))
    require(sha(files["runner.zig"]) == meta["runner_sha256"], (name, "ordinary runner"))
    if name == "xor":
        old = (b"            old.repeats[0] == candidate.repeats[0] and\n"
               b"            old.repeats[1] == candidate.repeats[1] and\n"
               b"            old.repeats[2] == candidate.repeats[2])")
        new = (b"            ((old.repeats[0] ^ candidate.repeats[0]) |\n"
               b"                (old.repeats[1] ^ candidate.repeats[1]) |\n"
               b"                (old.repeats[2] ^ candidate.repeats[2])) == 0)")
        require(original.count(old) == 1 and candidate == original.replace(old, new), "only XOR expression")
        for mode in ("debug", "releasefast", "x86"):
            terminal = json.loads(files["contracts-" + mode + ".json"])
            require(terminal["exit_code"] == 0 and terminal["tests_passed"] == 3, (mode, "XOR contracts"))
    else:
        insertion = (
            b"        while (available - offset >= 8) : (offset += 8) {\n"
            b"            const difference = std.mem.readInt(u64, left[offset..][0..8], .little) ^\n"
            b"                std.mem.readInt(u64, right[offset..][0..8], .little);\n"
            b"            if (difference != 0) {\n"
            b"                const mismatch: usize = @intCast(@ctz(difference) / 8);\n"
            b"                if (profile) |p| p.add(\"byte_comparisons\", mismatch + 1);\n"
            b"                return length + offset + mismatch;\n"
            b"            }\n"
            b"            if (profile) |p| p.add(\"byte_comparisons\", 8);\n"
            b"        }\n")
        anchor = b"        while (offset < available) : (offset += 1) {\n"
        require(original.count(anchor) == 1 and candidate == original.replace(anchor, insertion + anchor),
                "only short 8-byte tail")
        require(files["match-length-reference.zig"] == original, "short frozen oracle")
        observations = json.loads(files["parent-terminal-observations.json"])
        require(all(t["exit_code"] == 0 for t in observations["compiler"]), "parent compiler observations")
        require(all(t["exit_code"] == 0 and t["tests_passed"] == 3 for t in observations["contracts"]),
                "parent contract observations")
        count = 16 * 16 * sum(1 + n for n in range(97)) + 65 * 65 * 13 * 8 * 3 + 4096
        require(count == observations["source_derived_check_calls"] == 2539064, "source-derived oracle count")


def screen_audit(name, meta, files, inputs):
    results = json.loads(files["results.json"])
    require(results["source_commit"] == REVISION and results["rounds"] == 2, "screen baseline/rounds")
    require(len(results["rows"]) == 24 and len(results["summary"]) == 6, "screen dimensions")
    for mode, identity in meta["ordinary_binaries"].items():
        require(identity["sha256"] == results["binary_sha256"][mode]
                and identity["ELF_class"] == 2 and identity["ELF_machine"] == 62, "binary identity")
    frozen = json.loads(inputs["input-index.json"])
    summary, wires = [], []
    for row in results["summary"]:
        case, strategy, length = row["case"], row["strategy"], row["input_bytes"]
        group = [r for r in results["rows"] if (r["case"], r["strategy"], r["input_bytes"]) == (case, strategy, length)]
        require(len(group) == 4 and all(r["profile"] == group[0]["profile"] for r in group), "full profiles")
        expected = inputs[frozen[case]["member"]]
        require(len(expected) == length and sha(expected) == frozen[case]["sha256"], "frozen input")
        all_wire = None
        for actual in group:
            wire_name = "runs/{}/{}-{}/{}.zst".format(actual["round"], case, strategy, actual["mode"])
            wire = files[wire_name]
            require(sha(wire) == actual["wire_sha256"] and len(wire) == actual["wire_bytes"], "wire identity")
            require(actual["input_sha256"] == sha(expected), "row input identity")
            require(actual["native_decode_verified"] and actual["profiled_wire_equal"], "original decode/profile check")
            require(actual["profile"]["resolved_strategy"] == strategy, "actual strategy")
            if all_wire is not None:
                require(wire == all_wire, "complete wire pair")
            all_wire = wire
            wires.append((name + "/" + wire_name, wire, expected))
        times = {m: [r["ordinary_ns"] for r in group if r["mode"] == m] for m in ("baseline", "candidate")}
        require(times["baseline"] == row["baseline_ns"] and times["candidate"] == row["candidate_ns"], "raw times")
        ratio = median(times["candidate"]) / median(times["baseline"])
        require(abs(float(ratio) - row["median_ratio"]) < 1e-15, "ratio of medians")
        paired = []
        for round_index in range(2):
            pair = {r["mode"]: r["ordinary_ns"] for r in group if r["round"] == round_index}
            require(set(pair) == {"baseline", "candidate"}, "balanced paired round")
            paired.append(Fraction(pair["candidate"], pair["baseline"]))
        require(all(abs(float(r) - old) < 1e-15 for r, old in zip(paired, row["paired_ratios"])), "paired ratios")
        summary.append({"case": case, "strategy": strategy, "ratio": float(ratio),
                        "exact_numerator": ratio.numerator, "exact_denominator": ratio.denominator,
                        "paired_ratios": [float(r) for r in paired]})
    return summary, wires


def reference_decode(wires, library):
    lib = ctypes.CDLL(str(library.resolve()))
    lib.ZSTD_versionNumber.restype = ctypes.c_uint
    lib.ZSTD_versionString.restype = ctypes.c_char_p
    lib.ZSTD_decompress.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t]
    lib.ZSTD_decompress.restype = ctypes.c_size_t
    lib.ZSTD_isError.argtypes = [ctypes.c_size_t]
    lib.ZSTD_isError.restype = ctypes.c_uint
    require(lib.ZSTD_versionNumber() == 10600, "reference decoder version")
    rows = []
    for name, wire, expected in wires:
        output = ctypes.create_string_buffer(len(expected))
        source = ctypes.create_string_buffer(wire)
        size = lib.ZSTD_decompress(output, len(expected), source, len(wire))
        require(not lib.ZSTD_isError(size) and size == len(expected) and output.raw[:size] == expected,
                (name, "independent reference decode"))
        rows.append({"wire": name, "wire_sha256": sha(wire), "decoded_sha256": sha(expected), "decoded_bytes": size})
    return {"library": str(library.resolve()), "library_sha256": sha(library.read_bytes()),
            "version": lib.ZSTD_versionString().decode(), "wires_decoded": len(rows), "rows": rows}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--libzstd", type=Path)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    index = json.loads((ROOT / "index.json").read_text())
    require(index["source_revision"] == REVISION, "index source")
    if (ROOT / "manifest.json").exists():
        for entry in json.loads((ROOT / "manifest.json").read_text())["artifacts"]:
            data = (ROOT / entry["path"]).read_bytes()
            require(sha(data) == entry["sha256"] and len(data) == entry["bytes"], "immutable artifact")
    archives = {a["path"]: unpack(a) for a in index["archives"]}
    baseline = archives["baseline-source.tar.xz"]
    source_count = baseline_git(baseline)
    summaries, wires = {}, []
    for name, metadata in index["experiments"].items():
        files = archives[metadata["archive"]]
        preview = "xor.diff.xz" if name == "xor" else "short-tail.diff.xz"
        require(lzma.decompress((ROOT / preview).read_bytes()) == files["source.diff"],
                "reviewable diff matches frozen archive")
        source_audit(name, metadata, files, baseline)
        summaries[name], decoded = screen_audit(name, metadata, files, archives["frozen-inputs.tar.xz"])
        wires.extend(decoded)
    result = {"status": "ok", "archives_verified": len(archives), "baseline_git_blobs_verified": source_count,
              "screens": summaries, "ordinary_encodes": 48, "original_native_decodes": 96,
              "full_wire_profile_pairs": 24, "ratio_definition": "median(candidate_ns) / median(baseline_ns)",
              "short_terminal_scope": "parent observations; original full logs/test commands not retained",
              "raw_sample_periods": "not collected for these timing screens"}
    if args.libzstd:
        decode = reference_decode(wires, args.libzstd)
        if (ROOT / "reference-decode.json").exists():
            require(decode == json.loads((ROOT / "reference-decode.json").read_text()),
                    "stored reference decode report")
        result["independent_reference"] = {k: decode[k] for k in ("library", "library_sha256", "version", "wires_decoded")}
        if args.write:
            (ROOT / "reference-decode.json").write_text(json.dumps(decode, indent=2, sort_keys=True) + "\n")
    if args.write:
        (ROOT / "audit-result.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: result[k] for k in ("status", "archives_verified", "baseline_git_blobs_verified",
                                           "ordinary_encodes", "original_native_decodes", "full_wire_profile_pairs")}, sort_keys=True))


if __name__ == "__main__":
    main()
