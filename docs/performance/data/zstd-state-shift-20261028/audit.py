#!/usr/bin/env python3
"""Audit frozen shift evidence, recompute statistics and decode every wire."""

import argparse
from collections import Counter
import ctypes
from fractions import Fraction
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import tarfile


ROOT = Path(__file__).resolve().parent
REVISION = "dbbb64cdfe70fbb4705d8e9256c49a7580748767"
STATE = "src/zstd/match/hq_parser/state.zig"


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def read_json(data):
    return json.loads(data)


def load_archive(entry):
    path = ROOT / entry["path"]
    raw = path.read_bytes()
    require(len(raw) == entry["bytes"] and sha256(raw) == entry["sha256"], path)
    files = {}
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:xz") as archive:
        for member in archive:
            require(member.isfile(), (path, "non-file member", member.name))
            require(member.name not in files, (path, "duplicate member", member.name))
            require(not member.name.startswith("/") and ".." not in Path(member.name).parts,
                    (path, "unsafe member", member.name))
            files[member.name] = archive.extractfile(member).read()
    require(set(files) == set(entry["members"]), (path, "member set"))
    for name, data in files.items():
        expected = entry["members"][name]
        require(len(data) == expected["bytes"] and sha256(data) == expected["sha256"],
                (path, name, "member identity"))
    return files


def apply_diff(before, patch):
    lines = before.decode().splitlines(keepends=True)
    out, cursor = [], 0
    headers = [line for line in patch.splitlines() if line.startswith(("--- ", "+++ "))]
    require(headers == ["--- baseline/" + STATE, "+++ candidate/" + STATE], "diff scope")
    body = patch.splitlines(keepends=True)
    at = 0
    while at < len(body):
        match = re.match(r"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@", body[at])
        if not match:
            at += 1
            continue
        start = int(match.group(1)) - 1
        require(start >= cursor, "overlapping diff hunks")
        out.extend(lines[cursor:start])
        cursor = start
        old_count, new_count = 0, 0
        at += 1
        while at < len(body) and not body[at].startswith("@@ "):
            line = body[at]
            require(line[:1] in (" ", "-", "+"), "unsupported diff line")
            if line[:1] in (" ", "-"):
                require(cursor < len(lines) and lines[cursor] == line[1:], "diff context")
                cursor += 1
                old_count += 1
            if line[:1] in (" ", "+"):
                out.append(line[1:])
                new_count += 1
            at += 1
        require(old_count == int(match.group(2) or 1)
                and new_count == int(match.group(4) or 1), "diff hunk counts")
    out.extend(lines[cursor:])
    return "".join(out).encode()


def git_source_audit(source):
    repo = ROOT.parents[3]
    command = ["git", "ls-tree", "-rz", REVISION, "--", "src", "build.zig", "build.zig.zon"]
    raw = subprocess.run(command, cwd=repo, check=True, capture_output=True).stdout
    blobs = {}
    for record in raw.split(b"\0"):
        if not record:
            continue
        metadata, path = record.split(b"\t", 1)
        _, kind, digest = metadata.split()
        require(kind == b"blob", "unexpected Git tree entry")
        blobs[path.decode()] = digest.decode()
    require(set(source) == set(blobs), "baseline Git source paths")
    for name, data in source.items():
        git_blob = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
        require(git_blob == blobs[name], (name, "Git blob mismatch"))
    return len(blobs)


def median(values):
    ordered = sorted(values)
    middle = len(ordered) // 2
    return (Fraction(ordered[middle]) if len(ordered) % 2
            else Fraction(ordered[middle - 1] + ordered[middle], 2))


def prototype_audit(files, inputs, source):
    results = read_json(files["results.json"])
    provenance = read_json(files["source-provenance.json"])
    require(results["source_commit"] == REVISION and results["rounds"] == 2, "prototype revision/rounds")
    require(provenance["only_changed_original_files"] == [STATE], "source change list")
    require(sha256(source[STATE]) == provenance["baseline_state_sha256"], "baseline state hash")
    candidate = apply_diff(source[STATE], files["source.diff"].decode())
    require(sha256(candidate) == provenance["candidate_state_sha256"], "candidate state hash")
    old_tail = (b"    row[replace] = candidate;\n"
                b"    while (replace > 0 and less(row[replace], row[replace - 1])) : (replace -= 1)\n"
                b"        std.mem.swap(@TypeOf(candidate), &row[replace], &row[replace - 1]);\n")
    new_tail = (b"    while (replace > 0 and less(candidate, row[replace - 1])) : (replace -= 1)\n"
                b"        row[replace] = row[replace - 1];\n"
                b"    row[replace] = candidate;\n")
    require(source[STATE].count(old_tail) == 1
            and candidate == source[STATE].replace(old_tail, new_tail), "only swap-to-shift tail")
    require(sha256(source["src/zstd/match/hq_parser/state_tests.zig"])
            == provenance["state_tests_sha256"], "frozen oracle source")
    require(sha256(files["runner.zig"]) == provenance["runner_sha256"], "prototype runner")
    for mode, sizes in (("debug", (64, 56, 64)), ("releasefast", (64, 56, 64)), ("x86", (32, 40, 44))):
        contract = read_json(files["contracts-" + mode + ".json"])
        require(contract["exit_code"] == 0 and contract["random_trace_operations"] == 12288,
                (mode, "contract terminal"))
        actual = contract["node_sizes"]
        require((actual["usize_bits"], actual["Node"], actual["WholeNode"]) == sizes,
                (mode, "node layout"))
    frozen = read_json(inputs["input-index.json"])
    rows = results["rows"]
    require(len(rows) == 24, "ordinary encode count")
    summary = {(s["case"], s["strategy"], s["input_bytes"]): s for s in results["summary"]}
    require(len(summary) == 6, "case matrix")
    wires, ratios = [], []
    for key, item in sorted(summary.items()):
        case, strategy, length = key
        group = [r for r in rows if (r["case"], r["strategy"], r["input_bytes"]) == key]
        require(len(group) == 4, (key, "round count"))
        require(all(r["profile"] == group[0]["profile"] for r in group), (key, "full profile"))
        payload = inputs[frozen[case]["member"]]
        require(len(payload) == length and sha256(payload) == frozen[case]["sha256"], (key, "input"))
        reference_wire = None
        for row in group:
            path = "runs/{}/{}-{}/{}.zst".format(row["round"], case, strategy, row["mode"])
            wire = files[path]
            require(sha256(wire) == row["wire_sha256"] and len(wire) == row["wire_bytes"], (path, "wire"))
            require(row["input_sha256"] == sha256(payload), (path, "row input"))
            require(row["profile"]["resolved_strategy"] == strategy, (path, "strategy"))
            require(row["native_decode_verified"] and row["profiled_wire_equal"], (path, "original verification"))
            if reference_wire is not None:
                require(wire == reference_wire, (key, "full wire equality"))
            reference_wire = wire
            wires.append((path, wire, payload))
        times = {m: [r["ordinary_ns"] for r in group if r["mode"] == m] for m in ("baseline", "candidate")}
        require(times["baseline"] == item["baseline_ns"] and times["candidate"] == item["candidate_ns"],
                (key, "raw times"))
        ratio = median(times["candidate"]) / median(times["baseline"])
        require(abs(float(ratio) - item["median_ratio"]) < 1e-15, (key, "ratio of medians"))
        paired = []
        for round_index in range(2):
            pair = {r["mode"]: r["ordinary_ns"] for r in group if r["round"] == round_index}
            require(set(pair) == {"baseline", "candidate"}, (key, "paired round"))
            paired.append(Fraction(pair["candidate"], pair["baseline"]))
        require(all(abs(float(value) - expected) < 1e-15 for value, expected in zip(paired, item["paired_ratios"])),
                (key, "paired ratios"))
        ratios.append({"case": case, "strategy": strategy, "ratio": float(ratio),
                       "exact_numerator": ratio.numerator, "exact_denominator": ratio.denominator,
                       "paired_ratios": [float(r) for r in paired]})
    require(len(wires) == 24, "wire count")
    return wires, ratios


def sampling_audit(files, inputs):
    recordings = read_json(files["recordings.json"])
    summaries = {s["label"]: s for s in read_json(files["sample-summary.json"])}
    frozen = read_json(inputs["input-index.json"])
    output = []
    require(len(recordings) == 2, "sampling configuration count")
    for recording in recordings:
        label = recording["label"]
        summary = summaries[label]
        samples = []
        for line in files[label + ".ip-period.txt"].decode().splitlines():
            columns = line.split()
            if columns:
                samples.append((int(columns[1], 16), " ".join(columns[2:]), int(columns[0])))
        total = sum(s[2] for s in samples)
        require(total == summary["total_period"] and len(samples) == summary["sample_count"], (label, "denominator"))
        report = recording["report"]
        require(report["control_profile_null"] and report["diagnostic_profile_calls"] == 0
                and report["native_decode_verified"] and report["all_wires_equal"], (label, "ordinary scope"))
        payload = inputs[frozen[recording["input"]["case"]]["member"]]
        require(report["input_sha256"] == sha256(payload), (label, "sampling input"))
        require(report["wire_sha256"] == sha256(files[label + ".zst"]), (label, "sampling wire"))
        symbols = Counter()
        for _, symbol, period in samples:
            require(period > 0, "nonpositive sample period")
            symbols[symbol] += period
        for row in summary["top10"]:
            require(abs(100 * symbols[row["symbol"]] / total - row["global_pct"]) < 1e-9,
                    (label, "self share"))
        covered = set()
        parts = {}
        for name, part in summary["insert_parts"].items():
            segments = [(int(r["begin"], 16), int(r["end_exclusive"], 16)) for r in part["ranges"]]
            selected = {i for i, (ip, symbol, _) in enumerate(samples)
                        if symbol == summary["insert_symbol"] and any(a <= ip < b for a, b in segments)}
            require(not covered.intersection(selected), (label, "overlapping insert sample regions"))
            covered.update(selected)
            period = sum(samples[i][2] for i in selected)
            pct = 100 * period / total
            require(len(selected) == part["samples"] and abs(pct - part["global_pct"]) < 1e-9,
                    (label, name, "global attribution"))
            parts[name] = {"samples": len(selected), "period": period, "global_pct": pct}
        require(covered == {i for i, (_, symbol, _) in enumerate(samples) if symbol == summary["insert_symbol"]},
                (label, "insert region coverage"))
        cpus = Counter()
        for line in files[label + ".cpu-ip-period.txt"].decode().splitlines():
            for token in line.split():
                if re.fullmatch(r"\[\d+\]", token):
                    cpus[token] += 1
        require(dict(cpus) == {"[002]": len(samples)}, (label, "CPU affinity"))
        require("Total Lost Samples: 0" in files[label + ".report.txt"].decode(), (label, "lost samples"))
        output.append({"label": label, "sample_count": len(samples), "total_period": total,
                       "parts": parts, "diagnostic_calls": 0, "CPU": 2})
    return output


def reference_decode(wires, library):
    path = library.resolve()
    lib = ctypes.CDLL(str(path))
    lib.ZSTD_versionNumber.restype = ctypes.c_uint
    lib.ZSTD_versionString.restype = ctypes.c_char_p
    lib.ZSTD_decompress.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t]
    lib.ZSTD_decompress.restype = ctypes.c_size_t
    lib.ZSTD_isError.argtypes = [ctypes.c_size_t]
    lib.ZSTD_isError.restype = ctypes.c_uint
    require(lib.ZSTD_versionNumber() == 10600, "independent decoder must be libzstd 1.6.0")
    decoded = []
    for name, wire, expected in wires:
        destination = ctypes.create_string_buffer(len(expected))
        compressed = ctypes.create_string_buffer(wire)
        size = lib.ZSTD_decompress(destination, len(expected), compressed, len(wire))
        require(not lib.ZSTD_isError(size) and size == len(expected), (name, "reference decode size/error"))
        actual = destination.raw[:size]
        require(actual == expected, (name, "independent reference decoded bytes"))
        decoded.append({"wire": name, "wire_sha256": sha256(wire), "decoded_bytes": size,
                        "decoded_sha256": sha256(actual), "equal_input": True})
    return {"library_path": str(path), "library_sha256": sha256(path.read_bytes()),
            "version": lib.ZSTD_versionString().decode(), "decoder": "ZSTD_decompress",
            "wire_count": len(decoded), "rows": decoded}


def identity_audit(sampling, prototype):
    identities = json.loads((ROOT / "binary-identities.json").read_text())
    by_role = {row["role"]: row for row in identities["identities"]}
    require(len(by_role) == 6 and not identities["compiled_binaries_archived"], "binary identity scope")
    sample_manifest = read_json(sampling["artifact-manifest.json"])
    prototype_manifest = read_json(prototype["artifact-manifest.json"])
    sample_entries = {row["path"]: row for row in sample_manifest["artifacts"]}
    prototype_entries = {row["path"]: row for row in prototype_manifest["artifacts"]}
    for role, name, entries in (
            ("ordinary-only FP sampling runner", "ordinary-loop", sample_entries),
            ("ordinary non-FP baseline runner", "baseline-runner", prototype_entries),
            ("ordinary non-FP shift runner", "candidate-runner", prototype_entries)):
        actual, expected = by_role[role], entries[name]
        require(actual["sha256"] == expected["sha256"] and actual["bytes"] == expected["bytes"],
                (role, "original binary identity"))
        require(actual["elf_class"] == "ELF64" and actual["elf_machine"] == 62, (role, "ELF target"))
    sample_provenance = read_json(sampling["source-provenance.json"])
    prototype_results = read_json(prototype["results.json"])
    require(sample_provenance["binary_sha256"] == by_role["ordinary-only FP sampling runner"]["sha256"],
            "sampling executable binding")
    for mode, role in (("baseline", "ordinary non-FP baseline runner"),
                       ("candidate", "ordinary non-FP shift runner")):
        require(prototype_results["binary_sha256"][mode] == by_role[role]["sha256"], "prototype executable binding")
    for mode in ("debug", "releasefast", "x86"):
        binary = by_role["frozen state contracts " + mode]
        require(re.fullmatch(r"[0-9a-f]{64}", binary["sha256"]) and binary["bytes"] > 0,
                (mode, "test binary identity"))
        require((binary["elf_class"], binary["elf_machine"])
                == (("ELF32", 3) if mode == "x86" else ("ELF64", 62)), (mode, "test ELF target"))
    audited = json.loads((ROOT / "original-manifest-audit.json").read_text())
    for row, archived in zip(audited, (sampling, prototype)):
        original = read_json(archived["artifact-manifest.json"])
        require(row["all_size_hashes_equal"] and row["artifacts_checked"] == len(original["artifacts"])
                and row["manifest_sha256"] == sha256(archived["artifact-manifest.json"]),
                "original manifest audit binding")
    return {"ordinary_binaries": 3, "contract_test_binaries": 3,
            "original_artifacts_checked": sum(row["artifacts_checked"] for row in audited),
            "scope": "binary identities retained; compiled binaries and caches excluded"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--libzstd", type=Path, default=Path("/home/passchaos/Work/zstd/lib/libzstd.so.1.6.0"))
    parser.add_argument("--write", action="store_true", help="Write the stable audit and independent decode reports")
    args = parser.parse_args()
    index = json.loads((ROOT / "index.json").read_text())
    require(index["baseline_revision"] == REVISION, "index baseline")
    if (ROOT / "manifest.json").exists():
        for entry in json.loads((ROOT / "manifest.json").read_text())["artifacts"]:
            data = (ROOT / entry["path"]).read_bytes()
            require(len(data) == entry["bytes"] and sha256(data) == entry["sha256"], (entry["path"], "artifact identity"))
    archives = {entry["path"]: load_archive(entry) for entry in index["archives"]}
    source = archives["baseline-source.tar.xz"]
    source_count = git_source_audit(source)
    prototype = archives["shift-prototype.tar.xz"]
    frozen = archives["frozen-inputs.tar.xz"]
    wires, ratios = prototype_audit(prototype, frozen, source)
    sampling = sampling_audit(archives["ordinary-sampling.tar.xz"], frozen)
    identities = identity_audit(archives["ordinary-sampling.tar.xz"], prototype)
    decode = reference_decode(wires, args.libzstd)
    if (ROOT / "reference-decode.json").exists():
        require(decode == json.loads((ROOT / "reference-decode.json").read_text()), "reference decode evidence")
    result = {"status": "ok", "archives_verified": len(archives), "baseline_git_blobs_verified": source_count,
              "source_changes": [STATE], "wire_profile_pairs": 12, "ordinary_wires": len(wires),
              "ratio_definition": "median(candidate_ns) / median(baseline_ns)", "ratios": ratios,
              "binary_identity_audit": identities,
              "sampling_global_period_recomputed": sampling, "independent_decoder": {
                  key: decode[key] for key in ("library_path", "library_sha256", "version", "wire_count")},
              "parent_current_validation": "separate, mutable; not covered by this prototype audit"}
    if args.write:
        (ROOT / "reference-decode.json").write_text(json.dumps(decode, indent=2, sort_keys=True) + "\n")
        (ROOT / "audit-result.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({key: result[key] for key in ("status", "archives_verified", "baseline_git_blobs_verified",
                                                  "wire_profile_pairs", "ordinary_wires", "independent_decoder")}, sort_keys=True))


if __name__ == "__main__":
    main()
