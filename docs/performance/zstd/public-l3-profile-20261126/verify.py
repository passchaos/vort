#!/usr/bin/env python3
"""Portable, read-only verification; never run perf, a codec, or archived argv."""
import argparse
import csv
from decimal import Decimal
import hashlib
import io
import json
from pathlib import Path
import re
import sys
import tarfile

SCHEMA = "vort.zstd.public-l3-profile.archive.v1"
HEAD = "7b575072ee104d78a3fd2e35b8a979a3af4de390"
INPUT_SHA = "fc63a31770947b8c2062d3b19ca94c00485a232bb91b502021948fee983e1635"
WIRES = {"vort_bytes": 3320363, "reference_bytes": 2833843,
         "vort_sha256": "ccf0e89d5c0a295c797553da8e0f72dcd6ec5aefc7805ffd04de6333338b75c0",
         "reference_sha256": "183c5f1b703ec2eaac76b4bc8c5c24647b0d5e4725f0cb9f49ccca9f4a228ede"}
LEAVES = {"zstd.match.controlled_search.matchAt": "21.84",
          "zstd.match.controlled_search.planReuse": "20.43",
          "zstd.match.controlled_search.findBest": "17.09",
          "zstd.match.controlled_search.Index.seed": "13.26"}


class InvalidEvidence(Exception):
    pass


def require(condition, message):
    if not condition:
        raise InvalidEvidence(message)


def sha(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def unique(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "duplicate JSON key: " + key)
        result[key] = value
    return result


def read_json(data):
    def reject(value):
        raise InvalidEvidence("nonfinite JSON value: " + value)
    return json.loads(data, object_pairs_hook=unique, parse_constant=reject)


def arg(argv, name):
    indices = [i for i, value in enumerate(argv) if value == name]
    require(len(indices) == 1 and indices[0] + 1 < len(argv), "missing/duplicate argv option: " + name)
    return argv[indices[0] + 1]


def median(values):
    values = sorted(values)
    middle = len(values) // 2
    return values[middle] if len(values) % 2 else (values[middle - 1] + values[middle]) // 2


def verify(root):
    sums = {}
    for line in (root / "SHA256SUMS").read_text().splitlines():
        digest, name = line.split("  ", 1)
        require(re.fullmatch(r"[0-9a-f]{64}", digest) and name == Path(name).name and name not in sums, "invalid checksum entry")
        sums[name] = digest
        require(sha(root / name) == digest, "package checksum mismatch: " + name)
    require(set(sums) == {"README.md", "raw.tar.gz", "archive-bindings.json", "verify.py"}, "package checksums must cover all four artifacts")
    bindings = read_json((root / "archive-bindings.json").read_bytes())
    require(bindings["schema"] == SCHEMA and bindings["source_head"] == HEAD, "archive source/schema mismatch")
    require(bindings["archive_sha256"] == sums["raw.tar.gz"] and bindings["archive_bytes"] == (root / "raw.tar.gz").stat().st_size, "archive identity mismatch")
    logical = bindings["logical_files"]
    objects = {}
    for name, identity in logical.items():
        require(not Path(name).is_absolute() and ".." not in Path(name).parts, "invalid logical path")
        require(type(identity["bytes"]) is int and identity["bytes"] >= 0 and re.fullmatch(r"[0-9a-f]{64}", identity["sha256"]), "invalid logical identity")
        require(identity["object"] == "objects/" + identity["sha256"], "invalid content-addressed object")
        old = objects.setdefault(identity["object"], identity)
        require(old["bytes"] == identity["bytes"], "dedup object length conflict")
    small, prefixes, blob_oids = {}, {}, {}
    seen = set()
    with tarfile.open(root / "raw.tar.gz", mode="r|gz") as archive:
        for member in archive:
            require(member.isfile() and member.name in objects and member.name not in seen, "unbound/duplicate archive member")
            seen.add(member.name)
            expected = objects[member.name]
            require(member.size == expected["bytes"], "archive member size mismatch")
            source = archive.extractfile(member)
            digest = hashlib.sha256()
            blob = hashlib.sha1(b"blob " + str(member.size).encode() + b"\0")
            buffered = bytearray() if member.size <= 2 * 1024 * 1024 else None
            prefix = b""
            while chunk := source.read(1024 * 1024):
                digest.update(chunk)
                blob.update(chunk)
                if len(prefix) < 16:
                    prefix = (prefix + chunk)[:16]
                if buffered is not None:
                    buffered.extend(chunk)
            require(digest.hexdigest() == expected["sha256"], "archive member SHA256 mismatch")
            prefixes[member.name] = prefix
            blob_oids[member.name] = blob.hexdigest()
            if buffered is not None:
                small[member.name] = bytes(buffered)
    require(seen == set(objects), "archive lacks bound objects")
    require(bindings["deduplication"] == {"logical_files": len(logical), "unique_objects": len(objects), "logical_bytes": sum(v["bytes"] for v in logical.values()), "unique_bytes": sum(v["bytes"] for v in objects.values())}, "dedup totals mismatch")

    def data(name):
        return small[logical[name]["object"]]

    def doc(name):
        return read_json(data(name))

    def role(name):
        return logical[bindings["roles"][name]]

    before = doc("capture/identity-before.json")
    after = bindings["external_identity_after"]
    require(before["head"] == HEAD and all(after[path] == identity for path, identity in before["files"].items()), "captured input/ELF/reference before-after mismatch")
    for name in ("elf", "input", "reference", "explicit_input"):
        bound = role(name)
        require(after[bound["origin"]] == {"bytes": bound["bytes"], "sha256": bound["sha256"]}, "external role identity mismatch")
    require(role("input")["bytes"] == 33553445 and role("input")["sha256"] == INPUT_SHA, "original full NCI identity mismatch")
    require(role("explicit_input")["bytes"] == 65536, "explicit fixture size mismatch")
    require(prefixes[role("elf")["object"]].startswith(b"\x7fELF") and prefixes[role("reference")["object"]].startswith(b"\x7fELF"), "ELF/reference magic mismatch")
    require(prefixes[role("perf_data")["object"]].startswith(b"PERFILE2") and role("perf_data")["bytes"] == 201940120, "complete original perf.data mismatch")
    sources = bindings["sources"]
    require(sources["before"] == sources["after"], "archive-time source snapshot changed")
    for path, identity in sources["before"].items():
        bound = logical["Source/" + path]
        require(identity == {"bytes": bound["bytes"], "sha256": bound["sha256"]}, "Source object identity mismatch")
        recorded_oid = sources["git_blob_at_head"][path]
        if path.startswith("src/"):
            require(recorded_oid is not None and blob_oids[bound["object"]] == recorded_oid, "codec source differs from captured Git HEAD")

    run = doc("capture/run.command.json")
    require(run["exit_code"] == 0 and run["argv"] == before["argv"], "original capture receipt mismatch")
    argv = run["argv"]
    require(argv[:6] == ["taskset", "-c", "15", "perf", "record", "--call-graph"] and arg(argv, "--call-graph") == "dwarf", "capture instrumentation differs")
    for flag, expected in (("--level", "3"), ("--limit", "33553445"), ("--iterations", "1"), ("--rounds", "6")):
        require(arg(argv, flag) == expected, "capture command differs: " + flag)
    require(arg(argv, "--path") == role("input")["origin"] and arg(argv, "--libzstd") == role("reference")["origin"], "capture input/reference argv differs")
    require(argv[argv.index("--") + 1] == role("elf")["origin"], "capture executable argv differs")
    capture_stderr = data("capture/run.stderr").decode()
    require("23944 samples" in capture_stderr and "192.571 MB" in capture_stderr, "original perf capture completion missing")

    def samples(name, csv_name, explicit=False):
        report = doc(name)
        require(report["schema"] == "vort.codec_encode_samples" and report["version"] == 1 and report["codec"] == "zstd" and len(report["rows"]) == 1, "sample report schema mismatch")
        row = report["rows"][0]
        bound = role("explicit_input" if explicit else "input")
        require(row["input_bytes"] == bound["bytes"] and row["input_sha256"] == bound["sha256"] and row["iterations"] == 1, "sample input identity mismatch")
        require(report["provenance"]["executable_sha256"] == role("elf")["sha256"] and report["provenance"]["zig_version"] == "0.16.0" and report["provenance"]["optimize"] == "ReleaseFast", "sample executable/build identity mismatch")
        settings = row["settings"]
        primary = settings["resolved_primary"]
        require(settings["level"] == 3 and primary["fast_parser"] == "auto" and primary["selection"] == "fast_compressed" and primary["rep_beam_search"] is False and primary["block_size_max"] == 131072, "sample resolved policy mismatch")
        if explicit:
            require(settings["api"] == "native_frame" and settings["requested_strategy"] == "lazy" and settings["requested_native_selection"] == "fast_compressed" and primary["strategy"] == "lazy" and primary["match_search_budget"] == 41 and settings["internal_candidate_settings"] == "resolved_primary", "explicit native flags were not retained")
        else:
            require(settings["api"] == "level_policy" and settings["requested_strategy"] is None and settings["requested_fast_acceleration"] is None and settings["requested_native_selection"] is None and primary["strategy"] == "greedy" and primary["match_search_budget"] == 24 and settings["internal_candidate_settings"] == "public_auto_level_policy", "public default L3 does not describe greedy24")
            require(row["wires"] == WIRES, "historical full NCI wire metadata mismatch")
            require(report["provenance"]["cpu_affinity"] == "15" and report["provenance"]["affinity_cpu_count"] == 1, "profile CPU affinity mismatch")
        require(settings["wire_header"]["content_size"] == bound["bytes"] and settings["wire_header"]["window_size"] == bound["bytes"] and settings["reference"]["api"] == "ZSTD_compress" and settings["reference"]["level"] == 3, "wire/reference settings mismatch")
        require(len(report["references"]) == 1, "reference binding count mismatch")
        reference = report["references"][0]
        require(reference["version"] == "1.6.0" and reference["file_sha256"] == role("reference")["sha256"] and reference["canonical_file_path"] == role("reference")["origin"], "pinned libzstd file identity differs")
        rounds = row["rounds"]
        require(len(rounds) == (1 if explicit else 6), "raw round count mismatch")
        for index, sample in enumerate(rounds):
            require(sample["index"] == index and sample["vort_first"] is (index % 2 == 0), "raw alternating order mismatch")
            require(sample["vort_mix"] == row["wires"]["vort_bytes"] and sample["reference_mix"] == row["wires"]["reference_bytes"], "raw length mix mismatch")
        expected = {"vort_min_ns": min(r["vort_ns"] for r in rounds), "reference_min_ns": min(r["reference_ns"] for r in rounds), "vort_median_ns": median([r["vort_ns"] for r in rounds]), "reference_median_ns": median([r["reference_ns"] for r in rounds])}
        require(row["summary"] == expected, "raw diagnostic minima/median mismatch")
        csv_rows = list(csv.DictReader(io.StringIO(data(csv_name).decode())))
        require(len(csv_rows) == 1, "diagnostic CSV row count mismatch")
        csv_row = csv_rows[0]
        require(csv_row["input_sha256"] == bound["sha256"] and csv_row["executable_sha256"] == role("elf")["sha256"] and csv_row["reference_version"] == "1.6.0", "CSV identity mismatch")
        for field, expected_value in (("input_bytes", bound["bytes"]), ("level", 3), ("vort_bytes", row["wires"]["vort_bytes"]), ("reference_bytes", row["wires"]["reference_bytes"]), ("rounds", len(rounds)), ("vort_ns", expected["vort_min_ns"]), ("reference_ns", expected["reference_min_ns"])):
            require(int(csv_row[field]) == expected_value, "CSV raw metric differs: " + field)
        return row

    default = samples("capture/diagnostic.json", "capture/diagnostic.csv")
    explicit = samples("capture/explicit.json", "capture/explicit.csv", True)
    explicit_receipt = doc("capture/explicit.command.json")
    require(explicit_receipt["exit_code"] == 0 and arg(explicit_receipt["argv"], "--strategy") == "lazy" and arg(explicit_receipt["argv"], "--match-search-budget") == "41", "explicit smoke command mismatch")
    for name, expected_exit in (("perf-function-leaves", 0), ("perf-function-inclusive", 0), ("perf-leaf-report", 143), ("perf-inclusive-report", 143)):
        receipt = doc("capture/" + name + ".command.json")
        require(receipt["exit_code"] == expected_exit and "assembled after completion" in receipt["receipt_scope"], "report terminal status/receipt scope differs")
        require(arg(receipt["argv"], "-i") == arg(argv, "-o"), "report used a different capture")
        if expected_exit == 0:
            require("--no-inline" in receipt["argv"] and arg(receipt["argv"], "--call-graph") == "none", "reliable report expanded inline/callgraph")
            require("could not read first record" not in data("capture/" + name + ".stderr").decode(), "replacement report still failed symbolization")
        else:
            stderr = data("capture/" + name + ".stderr").decode()
            require("addr2line" in stderr and "could not read first record" in stderr, "preserved failure evidence missing")
    require(doc("capture/symbolization-failure.json")["replacement"] == "function symbols with inline expansion disabled", "symbolization replacement receipt missing")
    leaf_text = data("capture/perf-function-leaves.txt").decode()
    inclusive_text = data("capture/perf-function-inclusive.txt").decode()
    require("Total Lost Samples: 0" in leaf_text and "Total Lost Samples: 0" in inclusive_text, "lost-sample report mismatch")
    leaves = {symbol: Decimal(value) for value, symbol in re.findall(r"^\s*(\d+\.\d+)%\s+\[\.\]\s+(.+?)\s+-\s+-\s*$", leaf_text, re.M)}
    require(all(leaves.get(symbol) == Decimal(value) for symbol, value in LEAVES.items()), "recomputed key leaf percentages mismatch")
    total = sum((leaves[symbol] for symbol in LEAVES), Decimal(0))
    require(total == Decimal("72.62") and leaves["compiler_rt.memset"] == Decimal("6.49"), "leaf aggregate/memset mismatch")
    inclusive = {symbol: (Decimal(children), Decimal(self_pct)) for children, self_pct, symbol in re.findall(r"^\s*(\d+\.\d+)%\s+(\d+\.\d+)%\s+\[\.\]\s+(.+?)\s+-\s+-\s*$", inclusive_text, re.M)}
    require(inclusive["zstd.match.controlled_search.planReuse"][0] == Decimal("77.27") and inclusive["0xffffffffffffffff"][0] == Decimal("98.94"), "inclusive coverage boundary mismatch")
    require(any(".writeBlockImpl" in symbol and values[0] == Decimal("83.93") for symbol, values in inclusive.items()), "writeBlockImpl inclusive observation missing")
    return {"schema": "vort.zstd.public-l3-profile.verification.v1", "verified": True,
            "logical_files": len(logical), "unique_objects": len(objects), "source_files": len(sources["before"]),
            "perf_data_bytes": role("perf_data")["bytes"], "captured_samples": 23944,
            "input_bytes": default["input_bytes"], "input_sha256": default["input_sha256"], "source_head": HEAD,
            "default_policy": {"api": "level_policy", "strategy": "greedy", "match_search_budget": 24, "rep_beam_search": False, "fast_parser": "auto", "selection": "fast_compressed"},
            "wire_metadata": default["wires"], "explicit_smoke": {"api": "native_frame", "strategy": "lazy", "match_search_budget": 41, "input_bytes": explicit["input_bytes"]},
            "leaf_percent_of_capture": {symbol: float(leaves[symbol]) for symbol in LEAVES}, "four_leaf_sum_percent": float(total),
            "memset_leaf_percent": 6.49, "planReuse_inclusive_percent": 77.27, "writeBlockImpl_inclusive_percent": 83.93,
            "unresolved_root_inclusive_percent": 98.94, "report_exit_codes": {"function_leaves": 0, "function_inclusive": 0, "old_leaf": 143, "old_inclusive": 143},
            "scope": "Instrumented diagnosis only. Capture includes reference/SHA/validation. Leaf percentages use total recorded cycles; planReuse self includes inlined helpers. Inclusive percentages overlap and cannot be summed. No throughput gate, encoder-only normalization, perfect stack coverage, or universal memset attribution.",
            "identity_scope": "Original ELF/input/reference bytes preserved; Source is an archive-time before/after snapshot with codec Git blobs checked. Encoded frames were not separately retained: offline wire verification checks archived JSON/hash observations only. No original argv, perf, codec or decoder executed."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent)
    args = parser.parse_args()
    try:
        print(json.dumps(verify(args.root), indent=2, sort_keys=True))
    except (InvalidEvidence, OSError, ValueError, KeyError, TypeError, tarfile.TarError) as error:
        print("verification failed: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
