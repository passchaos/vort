#!/usr/bin/env python3
"""Single-frame Zstd MT functional interoperability. Never compiles or times work."""
from __future__ import annotations

import argparse
import ctypes as C
from datetime import datetime, timezone
import json
from pathlib import Path
import platform
import re
import subprocess
import sys

sys.dont_write_bytecode = True
from magicless_diff import Reference, inspect, digest, identity, deterministic

ROOT = Path(__file__).resolve().parents[2]
STRATEGIES = ("auto", "fast", "double_fast", "greedy", "lazy", "optimal", "lazy2", "btlazy2", "btopt", "btultra", "btultra2")


def require(value, context):
    if not value:
        raise AssertionError(context)


class MtReference(Reference):
    def __init__(self, library, header):
        super().__init__(library, header)
        text = header.read_text()
        self.mt_parameters = {}
        for name in ("ZSTD_c_nbWorkers", "ZSTD_c_jobSize", "ZSTD_c_overlapLog"):
            found = re.search(r"\b" + name + r"\s*=\s*(\d+)", text)
            require(found, ("reference MT parameter in selected header", name))
            self.mt_parameters[name] = int(found.group(1))
        self.get = self.lib.ZSTD_CCtx_getParameter
        self.get.restype, self.get.argtypes = C.c_size_t, (C.c_void_p, C.c_int, C.POINTER(C.c_int))

    def encode_mt(self, payload, format_, dictionary=b"", checksum=True, content_size=True):
        context = self.create()
        require(context, "reference MT createCCtx")
        values = {}
        try:
            for name, value in (("ZSTD_c_compressionLevel", 3), ("ZSTD_c_windowLog", 17),
                                ("ZSTD_c_checksumFlag", int(checksum)), ("ZSTD_c_contentSizeFlag", int(content_size)),
                                ("ZSTD_c_dictIDFlag", 1), ("ZSTD_c_format", int(format_ == "magicless"))):
                self.check(self.set(context, self.parameters[name], value))
            for name, value in (("ZSTD_c_nbWorkers", 3), ("ZSTD_c_jobSize", 512 * 1024), ("ZSTD_c_overlapLog", 9)):
                self.check(self.set(context, self.mt_parameters[name], value))
                actual = C.c_int()
                self.check(self.get(context, self.mt_parameters[name], C.byref(actual)))
                values[name] = actual.value
            self.check(self.load(context, dictionary, len(dictionary)))
            capacity = self.bound(len(payload))
            output = C.create_string_buffer(b"\xa5" * (capacity + 16), capacity + 16)
            count = self.check(self.compress(context, C.byref(output, 8), capacity, payload, len(payload)))
            require(output.raw[:8] == b"\xa5" * 8 and output.raw[-8:] == b"\xa5" * 8, "reference MT encode guards")
            wire = output.raw[8:8 + count]
            require(values["ZSTD_c_nbWorkers"] == 3, "reference accepts native MT worker setting")
            return wire, {"api": "ZSTD_CCtx_setParameter+ZSTD_compress2", "configured_values_read_back": values,
                          "scope": "actual libzstd encoding with MT enabled; no reference worker execution counter or performance claim"}
        finally:
            self.free(context)


def fixtures():
    far = deterministic(70000, 0xAF5D1026)
    text = b"Zstd single-frame Jobs preserve full history and remap entropy state.\n"
    prefix = deterministic(8192, 0x37102626)
    large_sequences = bytearray(prefix + prefix)
    index = 0
    while 24576 - len(large_sequences) >= 6:
        word = (index * 977 + 13) % 2048
        large_sequences.extend(prefix[word * 4:word * 4 + 4])
        large_sequences.extend((index & 0xFFFF).to_bytes(2, "little"))
        index += 1
    large_sequences.extend(deterministic(24576 - len(large_sequences), 0x4135))
    return {"empty": b"", "tiny": b"Zstd one Frame MT\x00\xff", "random": deterministic(4097),
            "text": text * 80, "structured": b"\n".join(f'{{"id":{i},"kind":"parallel","bucket":{i % 13}}}'.encode() for i in range(128)),
            "repeat": b"P" * 8193, "binary": bytes(range(256)) * 33,
            "mixed": deterministic(4096) + b"R" * 4096 + bytes(byte & 15 for byte in deterministic(4096)),
            "far-history": far + far[:8192], "many-jobs": (text * 15000)[:786449],
            "reference-multi": bytes(byte & 31 for byte in deterministic(1572897)), "credit": deterministic(3000),
            "large-sequences": bytes(large_sequences)}


def matrix():
    for case in ("empty", "tiny", "random", "text", "structured", "repeat", "binary"):
        for api in ("alloc", "append", "into"):
            for format_ in ("standard", "magicless"):
                yield case, {"api": api, "format": format_}, "base"
    for selection in ("raw_or_rle", "literal_only", "auto", "fast_compressed"):
        for format_ in ("standard", "magicless"):
            yield "mixed", {"selection": selection, "format": format_}, "block-types"
    for strategy in STRATEGIES:
        yield "tiny", {"strategy": strategy}, "strategy-control"
    for format_ in ("standard", "magicless"):
        for job in (4096, 5000, 32768):
            yield "far-history", {"strategy": "fast", "format": format_, "job_size": job,
                                  "window_log": 17, "max_inflight_bytes": 131072}, "cross-job-history"
        for jobs in (2, 4):
            yield "many-jobs", {"strategy": "fast", "format": format_, "job_size": 32768,
                                "max_inflight_jobs": jobs, "max_inflight_bytes": 131072}, "many-queue-cycles"
        yield "many-jobs", {"worker_count": 1, "strategy": "fast", "format": format_}, "worker1-control"
    for kind in ("raw", "full"):
        for api in ("alloc", "append", "into"):
            for format_ in ("standard", "magicless"):
                yield "dict-" + kind, {"dictionary_kind": kind, "use_dictionary_set": kind == "full", "api": api,
                                       "format": format_, "strategy": "fast", "job_size": 4096}, "dictionary"
    for flags in ((False, False), (False, True), (True, False)):
        yield "text", {"checksum": flags[0], "content_size": flags[1]}, "header-flags"
    for api in ("append", "into"):
        yield "text", {"api": api, "alias": True}, "caller-alias"
        yield "text", {"api": api, "max_working_memory": 0}, "heap-refusal"
    yield "text", {"api": "into", "short_output": True}, "short-output"
    yield "credit", {"job_size": 5000, "max_inflight_bytes": 3000}, "actual-tiny-credit"
    yield "credit", {"job_size": 5000, "max_inflight_bytes": 2999}, "byte-refusal"
    for field, value in (("worker_count", 0), ("worker_count", 65), ("job_size", 0), ("max_inflight_jobs", 0), ("max_inflight_bytes", 0)):
        yield "tiny", {field: value}, "invalid-options"
    yield "large-sequences", {"strategy": "fast", "block_size": 8192, "job_size": 8192,
                              "window_log": 15, "max_match_history_len": 32768, "worker_count": 2,
                              "max_inflight_jobs": 2, "max_inflight_bytes": 16384,
                              "max_working_memory": 64 * 1024 * 1024}, "large-sequence-reemission"


def source_identity():
    paths = [ROOT / f"src/{name}.zig" for name in ("zstd", "core", "checksum", "dictionary", "huffman", "lz77", "bitstream", "zstd_huffman_x2_object")]
    paths += [ROOT / "tools/zstd/parallel_frame_probe.zig", Path(__file__).resolve(), ROOT / "tools/zstd/magicless_diff.py"]
    for folder in ("zstd", "checksum", "dictionary", "io"):
        paths += sorted((ROOT / "src" / folder).rglob("*.zig"))
    rows = [{"path": str(path.relative_to(ROOT)), "sha256": digest(path.read_bytes())} for path in paths if path.exists()]
    return {"sha256": digest(json.dumps(rows, sort_keys=True).encode()), "files": rows}


def single_frame(wire, payload, c, dictionary_id=0):
    parsed = inspect(wire, c["format"])
    require(parsed["frame_count"] == 1 and not parsed["skippable_frames"], "exactly one actual frame, not concatenated worker frames")
    frame = parsed["frames"][0]
    require(frame["start_byte"] == 0 and frame["end_byte"] == len(wire) and sum(block["final"] for block in frame["blocks"]) == 1,
            "one header and one final block consume the complete frame")
    require(frame["checksum"] == c["checksum"] and frame["content_size"] == (len(payload) if c["content_size"] else None) and
            frame["dictionary_id"] == dictionary_id, "actual header/FCS/checksum/dictionary identity")
    return parsed


def sequence_count(payload):
    """Read the wire literal-section extent and Sequence_Count independently."""
    require(payload, "empty compressed block")
    kind, size_format = payload[0] & 3, (payload[0] >> 2) & 3
    if kind < 2:
        header_size = 1 if size_format in (0, 2) else 2 if size_format == 1 else 3
    else:
        header_size = 3 if size_format in (0, 1) else 4 if size_format == 2 else 5
    require(len(payload) >= header_size, "truncated literal section header")
    packed = int.from_bytes(payload[:header_size], "little")
    if kind == 1:
        literal_bytes = 1
    elif kind == 0:
        literal_bytes = packed >> (3 if header_size == 1 else 4)
    else:
        shift, width = (14, 10) if header_size == 3 else (18, 14) if header_size == 4 else (22, 18)
        literal_bytes = (packed >> shift) & ((1 << width) - 1)
    offset = header_size + literal_bytes
    require(offset < len(payload), "literal section consumes Sequence_Count")
    first = payload[offset]
    if first < 128:
        return first
    if first < 255:
        require(offset + 2 <= len(payload), "truncated two-byte Sequence_Count")
        return (first - 128) * 256 + payload[offset + 1]
    require(offset + 3 <= len(payload), "truncated three-byte Sequence_Count")
    return 0x7F00 + int.from_bytes(payload[offset + 1:offset + 3], "little")


def sequence_counts(wire, parsed):
    return [sequence_count(wire[block["start_byte"] + 3:block["end_byte"]]) if block["kind"] == "compressed" else 0
            for block in parsed["frames"][0]["blocks"]]


def self_check(reference):
    for wire, expected in ((b"\x00\x00", 0), (b"\x00\x7f", 127),
                           (b"\x00\x82\x01", 513), (b"\x00\xff\x01\x00", 0x7F01)):
        require(sequence_count(wire) == expected, "independent hand-packed Sequence_Count")
    for format_ in ("standard", "magicless"):
        payload = fixtures()["reference-multi"]
        wire, control = reference.encode_mt(payload, format_)
        parsed = single_frame(wire, payload, {"format": format_, "checksum": True, "content_size": True})
        require(len(parsed["frames"][0]["blocks"]) > 1 and reference.decode(wire, payload, format_)["complete_contents_verified"], "native MT single-frame reference contents")
    return {"target_encode_cases": len(list(matrix())), "strategy_controls": len(STRATEGIES), "reference_mt_selfchecks": 2}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", type=Path)
    parser.add_argument("--directory", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--source-epoch", default="unspecified")
    parser.add_argument("--reference", type=Path, default=Path("/home/passchaos/Work/zstd/lib/libzstd.so.1.6.0"))
    parser.add_argument("--reference-header", type=Path, default=Path("/home/passchaos/Work/zstd/lib/zstd.h"))
    parser.add_argument("--self-check", action="store_true")
    args = parser.parse_args()
    reference = MtReference(args.reference, args.reference_header)
    checks = self_check(reference)
    if args.self_check:
        print(json.dumps({"self_check": "passed", "checks": checks, "reference": reference.describe(), "reference_mt_parameters": reference.mt_parameters}))
        return
    require(args.probe and args.directory, "--probe and --directory are required")
    directory, probe = args.directory.resolve(), args.probe.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    before = source_identity()
    inputs = fixtures()
    dictionaries = {"raw": deterministic(8192, 0xD1C71026), "full": reference.dictionary()}
    inputs["dict-raw"] = dictionaries["raw"][-1024:] * 12
    inputs["dict-full"] = b'{"id":7,"service":"magicless","message":"dictionary format interoperability"}\n' * 120
    for name, payload in inputs.items():
        (directory / (name + ".input")).write_bytes(payload)
    for kind, body in dictionaries.items():
        (directory / ("dictionary-" + kind + ".bin")).write_bytes(body)
    commands, results, failures = [], [], []
    def call(name, c, input_path, output_path):
        config = directory / (name + ".json")
        config.write_text(json.dumps(c, indent=2) + "\n")
        command = [str(probe), str(input_path), str(output_path), str(config)]
        process = subprocess.run(command, capture_output=True, check=False, timeout=120)
        stdout, stderr = directory / (name + ".stdout"), directory / (name + ".stderr")
        stdout.write_bytes(process.stdout)
        stderr.write_bytes(process.stderr)
        commands.append({"command": command, "exit_code": process.returncode, "stdout": identity(stdout), "stderr": identity(stderr)})
        require(process.returncode == 0, (name, "probe process", process.returncode, process.stderr.decode(errors="replace")))
        return json.loads(process.stdout)
    for index, (case, overrides, scope) in enumerate(matrix()):
        name = f"encode-{index:03d}-{case}-{scope}"
        c = {"operation": "encode", "api": "alloc", "format": "standard", "selection": "auto", "strategy": "auto",
             "block_size": 4096, "job_size": 8192, "worker_count": 3, "max_inflight_jobs": 4,
             "max_inflight_bytes": 131072, "max_working_memory": 256 * 1024 * 1024, "checksum": True, "content_size": True, **overrides}
        kind = c.get("dictionary_kind")
        if kind:
            c["dictionary_path"] = str(directory / ("dictionary-" + kind + ".bin"))
        payload, path = inputs[case], directory / (name + ".zst")
        entry = {"name": name, "scope": scope, "settings": c, "input": identity(directory / (case + ".input"))}
        try:
            row = call(name, c, directory / (case + ".input"), path)
            entry["probe"] = row
            error = {"heap-refusal": "WorkingMemoryLimitExceeded", "byte-refusal": "WorkingMemoryLimitExceeded",
                     "invalid-options": "InvalidBlockPlan", "short-output": "OutputTooSmall"}.get(scope)
            require(row["error"] == error, (name, "exact result", row))
            require(row["caller_guards_verified"] and row["borrowed_input_verified"], "caller ownership/guard checks")
            if error:
                if c["api"] in ("append", "into"):
                    require(row["caller_preserved_on_error"], "failed publication preserves caller")
            else:
                wire = path.read_bytes()
                require(row["input_sha256"] == digest(payload) and row["output_sha256"] == digest(wire) and
                        row["output_bytes"] == len(wire) and len(wire) <= row["encoded_bound"] and row["self_decode_verified"], "actual bounded frame identities")
                dictionary_id = int.from_bytes(dictionaries["full"][4:8], "little") if kind == "full" else 0
                parsed = single_frame(wire, payload, c, dictionary_id)
                external = reference.decode(wire, payload, c["format"], dictionaries[kind] if kind else b"")
                require(external["complete_contents_verified"] and external["frames_completed"] == 1, "versioned libzstd full single-frame contents and exact input consumption")
                require(row["worker1_wire_equal"], "same geometry worker1 and MT complete wire parity")
                worker1 = Path(str(path) + ".worker1.zst")
                require(worker1.read_bytes() == wire and row["worker1_wire_bytes"] == len(wire) and
                        row["worker1_wire_sha256"] == digest(wire), "actual saved worker1 wire identity")
                require(row["original_serial_contents_verified"], "old public serial path retains correct complete contents")
                profile = row["parallel_profile"]
                effective = ((c["job_size"] + c["block_size"] - 1) // c["block_size"]) * c["block_size"]
                jobs = max(1, (len(payload) + effective - 1) // effective)
                require(profile["effective_job_size"] == effective and profile["job_count"] == jobs and
                        profile["encoded_jobs"] == profile["published_jobs"] == jobs and
                        profile["peak_inflight_jobs"] <= c["max_inflight_jobs"] and profile["peak_inflight_bytes"] <= c["max_inflight_bytes"] and
                        profile["peak_requested_bytes"] <= c["max_working_memory"] and profile["live_requested_bytes"] == profile["workers_live"] == 0,
                        "actual job geometry/credit/heap and worker lifecycle")
                slots = min(jobs, c["max_inflight_jobs"], max(1, c["max_inflight_bytes"] // effective))
                expected_workers = min(c["worker_count"], slots)
                require(profile["workers_started"] == (expected_workers if expected_workers > 1 else 0), "actual native worker cardinality")
                require(profile["encoded_blocks"] == profile["published_blocks"] == len(parsed["frames"][0]["blocks"]), "actual block publication cardinality")
                if c["worker_count"] == 1:
                    require(profile["serial_fallback"] and profile["workers_started"] == 0, "worker1 actual fallback")
                if scope == "cross-job-history":
                    emitted = row["control_emitted"]
                    require(emitted["history_sequences"] > 0 and emitted["max_distance"] >= effective,
                            "actual emitted cross-job history sequence")
                    entry["cross_job_history"] = {"emitted_history_sequences": emitted["history_sequences"], "emitted_max_distance": emitted["max_distance"],
                                                  "effective_job_size": effective, "proof": "an emitted distance at least one complete Job span has its source in earlier Job input; original decoder plaintext confirms semantics"}
                if scope == "large-sequence-reemission":
                    counts = sequence_counts(wire, parsed)
                    require(max(counts, default=0) > 512 and row["control_emitted"]["history_sequences"] > 512,
                            "actual large-sequence adapter and emitted cross-job history coverage")
                    entry["large_sequence_evidence"] = {"independent_block_sequence_counts": counts,
                                                         "maximum_sequence_count": max(counts),
                                                         "emitted_history_sequences": row["control_emitted"]["history_sequences"],
                                                         "scope": "physical literal section and Sequence_Count parsed without the production adapter"}
                entry.update({"wire": identity(path), "worker1_wire": identity(worker1), "independent_frame": parsed, "reference_decode": external})
            entry["status"] = "passed"
        except (AssertionError, OSError, json.JSONDecodeError, TypeError) as error:
            entry.update({"status": "failed", "failure": str(error)})
            failures.append({"name": name, "failure": str(error)})
        results.append(entry)
    native_streams = []
    for case in ("reference-multi", "dict-raw", "dict-full"):
        kind = case[5:] if case.startswith("dict-") else None
        for format_ in ("standard", "magicless"):
            payload = inputs[case]
            wire, controls = reference.encode_mt(payload, format_, dictionaries[kind] if kind else b"")
            name = "native-mt-" + case + "-" + format_
            path, output = directory / (name + ".zst"), directory / (name + ".decoded")
            path.write_bytes(wire)
            c = {"operation": "decode", "format": format_, "dictionary_path": str(directory / ("dictionary-" + kind + ".bin")) if kind else None,
                 "dictionary_kind": kind or "none", "use_dictionary_set": kind == "full", "expected_output_len": len(payload)}
            entry = {"name": name, "scope": "native-mt-to-target", "reference_controls": controls, "wire": identity(path)}
            try:
                row = call(name, c, path, output)
                require(row["error"] is None and output.read_bytes() == payload and row["output_sha256"] == digest(payload), "native MT to public target decode complete contents")
                entry.update({"probe": row, "independent_frame": single_frame(wire, payload, {"format": format_, "checksum": True, "content_size": True}, int.from_bytes(dictionaries["full"][4:8], "little") if kind == "full" else 0), "status": "passed"})
            except (AssertionError, OSError, json.JSONDecodeError, TypeError) as error:
                entry.update({"status": "failed", "failure": str(error)})
                failures.append({"name": name, "failure": str(error)})
            results.append(entry)
            native_streams.append(entry)
    dictionary_error_cases = 0
    wrong_full = bytearray(dictionaries["full"])
    original_id = int.from_bytes(wrong_full[4:8], "little")
    wrong_full[4:8] = (original_id ^ 0x12340000 or 1).to_bytes(4, "little")
    wrong_path = directory / "dictionary-wrong-id.bin"
    wrong_path.write_bytes(wrong_full)
    for format_ in ("standard", "magicless"):
        name = "native-mt-dict-full-" + format_
        wire_path = directory / (name + ".zst")
        for missing in (True, False):
            label = "dictionary-error-" + ("missing" if missing else "wrong-id") + "-" + format_
            c = {"operation": "decode", "format": format_, "dictionary_kind": "none" if missing else "full",
                 "dictionary_path": None if missing else str(wrong_path), "use_dictionary_set": not missing}
            entry = {"name": label, "scope": "dictionary-error", "settings": c, "wire": identity(wire_path)}
            try:
                row = call(label, c, wire_path, directory / (label + ".decoded"))
                entry["probe"] = row
                require(row["error"] == "NeedDictionary", "missing/wrong dictionary catalog exact rejection")
                bad = reference.decode(wire_path.read_bytes(), inputs["dict-full"], format_, b"" if missing else bytes(wrong_full))
                require(not bad["complete_contents_verified"], "native reference rejects missing/wrong dictionary")
                entry.update({"reference_rejection": bad, "status": "passed"})
            except (AssertionError, OSError, json.JSONDecodeError, TypeError) as error:
                entry.update({"status": "failed", "failure": str(error)})
                failures.append({"name": label, "failure": str(error)})
            results.append(entry)
            dictionary_error_cases += 1
    peak = max((row["probe"]["parallel_profile"]["peak_active_workers"] for row in results
                if row["status"] == "passed" and row["scope"] not in ("dictionary-error", "native-mt-to-target") and
                "wire" in row and "probe" in row), default=0)
    if peak <= 1:
        failures.append({"name": "actual-worker-overlap", "failure": "no natural target peak_active_workers above one"})
    after = source_identity()
    counts = {"cases": len(results), "passed": sum(row["status"] == "passed" for row in results), "failed": len(failures),
              "target_encode_cases": len(list(matrix())), "native_mt_reference_cases": len(native_streams), "observed_peak_active_workers": peak}
    counts["dictionary_error_cases"] = dictionary_error_cases
    counts["large_sequence_cases"] = sum(row["scope"] == "large-sequence-reemission" for row in results)
    counts["maximum_independent_sequence_count"] = max((row["large_sequence_evidence"]["maximum_sequence_count"]
                                                        for row in results if "large_sequence_evidence" in row), default=0)
    report = {"schema": "vort.zstd.parallel-frame-differential.v1", "created_utc": datetime.now(timezone.utc).isoformat(),
              "source_epoch": args.source_epoch, "source": before, "source_after_sha256": after["sha256"], "sources_preserved": before == after,
              "probe": identity(probe), "reference": reference.describe(), "reference_mt_parameters": reference.mt_parameters,
              "python": platform.python_version(), "host": platform.platform(), "counts": counts,
              "inputs": {name: identity(directory / (name + ".input")) for name in inputs},
              "dictionaries": {kind: identity(directory / ("dictionary-" + kind + ".bin")) for kind in dictionaries},
              "scope": "one actual Frame across multiple Jobs with exact public bounds, worker1 same-geometry parity, full-history emitted sequences, dictionaries, caller publication and libzstd MT interoperability",
              "measurement_scope": "actual serialized bytes and functional worker/credit/requested-memory counters; no timing, throughput, RSS or reference-worker-execution-count claim",
              "failures": failures, "results": results, "commands": commands}
    path = args.report or directory / "differential.json"
    path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"report": str(path), **counts, "sources_preserved": report["sources_preserved"]}))
    require(not failures and report["sources_preserved"], ("single-frame MT gate", failures))


if __name__ == "__main__":
    main()
