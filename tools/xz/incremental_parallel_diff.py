#!/usr/bin/env python3
"""Persistent XZ parallel encoding protocol QA with explicit caller progress.

No build, timer, polling thread, sleep or production hook is used. Existing
liblzma artifacts decode complete wire independently; snapshots prove workers.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import platform
import subprocess
import sys

sys.dont_write_bytecode = True
from parallel_diff import Reference, deterministic, digest, identity, CHECKS, FILTER_IDS
from block_sizes_diff import inspect, Adapter, verify_provenance, verify_build_record

ROOT = Path(__file__).resolve().parents[2]


def require(value, context):
    if not value:
        raise AssertionError(context)


def fixtures():
    return {"empty": b"", "tiny": b"Incremental XZ parallel\x00\xff", "repeat": (b"Owned XZ jobs retain input until ordered delivery.\n" * 1500)[:50017],
            "random": deterministic(50017), "cycles": bytes(byte & 15 for byte in deterministic(262177)),
            "binary": bytes.fromhex("e80000000090e9f0ffffff") * 1800,
            "partial": deterministic(3001), "tiny-credit": deterministic(3000)}


def matrix():
    for case in ("empty", "tiny", "repeat", "random"):
        for check in CHECKS:
            for sizes in (False, True):
                yield case, {"check": check, "include_block_sizes": sizes}, "normal"
    for case in ("repeat", "cycles"):
        for block in (4096, 32768):
            for credit in (2, 4):
                yield case, {"block_size": block, "chunk_size": block, "input_chunk": block,
                             "max_inflight_blocks": credit, "max_inflight_bytes": block * credit}, "queue-cycles"
    for scenario in ("flush", "concat", "reset", "move"):
        for sizes in (False, True):
            c = {"scenario": scenario, "include_block_sizes": sizes}
            if scenario == "flush":
                c["flush_at"] = 1537
            yield "cycles", c, scenario
    for parser in ("greedy", "lazy", "fast", "normal"):
        yield "repeat", {"parser": parser}, "parser"
    for kind in FILTER_IDS:
        yield "binary", {"filters": [{"kind": kind, "parameter": 3 if kind == "delta" else 16}]}, "filter"
    for preset in (0, 6):
        yield "tiny", {"preset": preset}, "preset"
    yield "repeat", {"parallel": False}, "null-parallel"
    yield "repeat", {"worker_count": 1}, "worker1"
    yield "partial", {"scenario": "partial_credit", "block_size": 4096, "input_chunk": 4096,
                      "max_inflight_bytes": 3000, "max_inflight_blocks": 2}, "recover-partial-credit"
    yield "tiny-credit", {"max_inflight_bytes": 3000}, "actual-tiny-credit"
    yield "repeat", {"scenario": "pending_retry", "max_pending_output_len": 12}, "recover-pending"
    yield "repeat", {"scenario": "input_retry", "max_input_len": 3}, "recover-input"
    yield "repeat", {"scenario": "heap_sticky", "codec_memory_limit": 0}, "sticky-worker-error"
    yield "cycles", {"scenario": "concat", "next_parallel": True}, "continued-pool"


def sources():
    paths = [ROOT / "src/xz.zig", ROOT / "src/core.zig", ROOT / "src/lzma.zig", ROOT / "src/bitstream.zig",
             ROOT / "tools/xz/incremental_parallel_probe.zig", Path(__file__).resolve(),
             ROOT / "tools/xz/block_sizes_diff.py", ROOT / "tools/xz/parallel_diff.py"]
    for folder in ("xz", "lzma", "io", "checksum"):
        paths += sorted((ROOT / "src" / folder).rglob("*.zig"))
    rows = [{"path": str(path.relative_to(ROOT)), "sha256": digest(path.read_bytes())} for path in paths if path.exists()]
    return {"sha256": digest(json.dumps(rows, sort_keys=True).encode()), "files": rows}


def validate_snapshots(row, c):
    observed = []
    for point in row["snapshots"]:
        snapshot, p = point["snapshot"], point["snapshot"]["parallel"]
        if not p["enabled"]:
            continue
        require(p["inflight_bytes"] <= c["max_inflight_bytes"] and p["inflight_blocks"] <= c["max_inflight_blocks"], "snapshot input credits")
        require(p["live_requested_bytes"] <= c["max_working_memory"] and p["peak_requested_bytes"] <= c["max_working_memory"], "snapshot whole requested heap")
        require(p["delivered_blocks"] <= p["published_blocks"] <= p["encoded_blocks"] <= p["accepted_blocks"], "ordered job stages")
        require(p["owned_input_bytes"] == p["inflight_bytes"] and p["partial_input_bytes"] <= p["owned_input_bytes"], "accepted plaintext remains owned")
        if point["stage"] == "zero_output_startup":
            require(snapshot["input_read"] == 0 and snapshot["pending_output"] == 12, "zero output startup admission")
        if point["stage"] in ("done", "flush_acknowledged"):
            require(p["inflight_blocks"] == p["inflight_bytes"] == 0 and p["delivered_blocks"] == p["accepted_blocks"],
                    "completion/flush requires all accepted jobs delivered")
        if point["stage"] == "next_stream_initial":
            require(snapshot["current_input"] == snapshot["current_output"] == 0 and p["inflight_bytes"] == 0,
                    "next frame clears logical progress and credits")
        observed.append(p)
    return {"enabled_snapshot_count": len(observed), "maximum_started_workers": max((p["workers_started"] for p in observed), default=0),
            "maximum_active_workers": max((p["peak_active_workers"] for p in observed), default=0),
            "owned_input_observed": any(p["owned_input_bytes"] for p in observed),
            "done_can_retain_requested_heap": any(point["stage"] == "done" and point["snapshot"]["parallel"]["live_requested_bytes"] > 0 for point in row["snapshots"])}


def self_check(reference):
    for name, payload in fixtures().items():
        wire = reference.encode(payload)
        parsed = inspect(wire)
        require(parsed["decoded_bytes"] == len(payload) and reference.decode(wire, payload)["complete_contents_verified"], "reference fixture self-check")
    return {"cases": len(list(matrix())), "checks": len(CHECKS), "filters": len(FILTER_IDS)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", type=Path)
    parser.add_argument("--directory", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--source-epoch", default="unspecified")
    parser.add_argument("--reference", type=Path, default=Path("/tmp/vort-xz-ref.vVVDxq/build/liblzma.so.5.8.4"))
    parser.add_argument("--reference-headers", type=Path, default=Path("/tmp/vort-xz-ref.vVVDxq/xz/src/liblzma/api"))
    parser.add_argument("--mt-adapter", type=Path)
    parser.add_argument("--mt-library", type=Path)
    parser.add_argument("--mt-provenance", type=Path)
    parser.add_argument("--mt-build-record", type=Path)
    parser.add_argument("--self-check", action="store_true")
    args = parser.parse_args()
    reference = Reference(args.reference, args.reference_headers)
    checks = self_check(reference)
    if args.self_check:
        print(json.dumps({"self_check": "passed", "matrix": checks, "reference": reference.describe()}))
        return
    require(args.probe and args.directory, "--probe and --directory required")
    mt = None
    mt_identity = provenance = build_record = None
    if args.mt_adapter:
        require(args.mt_library and args.mt_provenance and args.mt_build_record, "optional MT adapter needs complete prior provenance/build artifacts")
        mt = Adapter(args.mt_adapter, args.reference, args.mt_library)
        mt_identity = mt.describe()
        provenance = verify_provenance(args.mt_provenance)
        build_record = verify_build_record(args.mt_build_record, provenance, mt)
    probe, directory = args.probe.resolve(), args.directory.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    before = sources()
    inputs = fixtures()
    for name, payload in inputs.items():
        (directory / (name + ".input")).write_bytes(payload)
    commands, results, failures = [], [], []
    for index, (case, overrides, scope) in enumerate(matrix()):
        name = f"case-{index:03d}-{case}-{scope}"
        config = {"parallel": True, "scenario": "normal", "check": "crc64", "include_block_sizes": True,
                  "block_size": 4096, "chunk_size": 4096, "dictionary_size": 4096, "input_chunk": 4096,
                  "worker_count": 3, "max_inflight_blocks": 4, "max_inflight_bytes": 16384,
                  "max_working_memory": 128 * 1024 * 1024, **overrides}
        config_path, wire_path = directory / (name + ".json"), directory / (name + ".xz")
        config_path.write_text(json.dumps(config, indent=2) + "\n")
        command = [str(probe), str(directory / (case + ".input")), str(wire_path), str(config_path)]
        process = subprocess.run(command, capture_output=True, check=False, timeout=120)
        stdout, stderr = directory / (name + ".stdout"), directory / (name + ".stderr")
        stdout.write_bytes(process.stdout)
        stderr.write_bytes(process.stderr)
        commands.append({"command": command, "exit_code": process.returncode, "stdout": identity(stdout), "stderr": identity(stderr)})
        entry = {"name": name, "scope": scope, "settings": config, "input": identity(directory / (case + ".input")), "config": identity(config_path)}
        try:
            require(process.returncode == 0, (name, "probe process", process.returncode, process.stderr.decode(errors="replace")))
            row = json.loads(process.stdout)
            entry["probe"] = row
            expected_error = "WorkingMemoryLimitExceeded" if scope == "sticky-worker-error" else None
            require(row["error"] == expected_error, (name, "result", row["error"]))
            require(row["caller_guards_verified"] and row["deinit_profile_live_bytes"] == 0, "caller guards and closed lifetime")
            witness = validate_snapshots(row, config)
            entry["protocol_witness"] = witness
            if expected_error:
                require(row["sticky_checks"] > 0, "worker error remains sticky")
                require(any(point["snapshot"]["parallel"]["failed"] for point in row["snapshots"]), "worker failure snapshot stays poisoned")
            else:
                payload, wire = inputs[case], wire_path.read_bytes()
                require(row["input_sha256"] == digest(payload) and row["output_sha256"] == digest(wire) and
                        row["output_bytes"] == len(wire) and row["serial_wire_equal"] and row["self_decode_verified"], "exact stream identities/serial wire parity")
                serial_path = Path(str(wire_path) + ".serial.xz")
                require(serial_path.read_bytes() == wire, "independent complete serial wire identity")
                entry["serial_wire"] = identity(serial_path)
                if row["serial_one_shot_equal"] is not None:
                    require(row["serial_one_shot_equal"], "unflushed stream same-boundary one-shot parity")
                require(row["zero_input_offers"] > 0 and row["zero_output_offers"] > 0, "zero-sized caller offers")
                if config["parallel"]:
                    require(row["startup_zero_output_verified"], "zero-output startup no input consumed")
                if scope == "move":
                    require(row["moves"] == 1 and row["move_with_jobs"], "active value move witness")
                if scope.startswith("recover-"):
                    require(row["recoveries"], "configured recovery scenario must observe actual error")
                    expected = "WorkingMemoryLimitExceeded" if scope == "recover-partial-credit" else "OutputLimitExceeded"
                    require(any(recovery["error_name"] == expected for recovery in row["recoveries"]), "actual recoverable admission error")
                    require(all(not recovery["snapshot"]["parallel"]["failed"] for recovery in row["recoveries"]), "recoverable caller limit must not poison workers")
                position, frames = 0, []
                for frame in row["frames"]:
                    require(frame["start"] == position and frame["input_bytes"] == len(payload), "frame progress identity")
                    require(isinstance(frame["input_sha256"], str) and frame["input_sha256"] == digest(payload),
                            "frame accepted plaintext hash must be the exact hex string")
                    encoded = wire[position:position + frame["bytes"]]
                    parsed = inspect(encoded)
                    external = reference.decode(encoded, payload)
                    require(parsed["decoded_bytes"] == len(payload) and external["complete_contents_verified"], "frame full external plaintext")
                    require(all(all(field["present"] == config["include_block_sizes"] for field in block["declared_sizes"]) for block in parsed["blocks"]), "declared-size option survives stream lifetime")
                    records = {"parsed": parsed, "reference_decode": external, "wire_bytes": len(encoded)}
                    if mt and scope == "queue-cycles" and config["include_block_sizes"]:
                        original = mt.decode(encoded, payload, instrumented=False)
                        require(original["complete_contents_verified"], "original MT decoder full incremental output")
                        records["original_mt_decode"] = original
                    frames.append(records)
                    position += frame["bytes"]
                require(position == len(wire), "frame extents consume whole output")
                entry.update({"wire": identity(wire_path), "frames": frames})
                if len(payload) > config["block_size"] and config["parallel"] and config["worker_count"] > 1 and scope not in ("recover-partial-credit", "actual-tiny-credit"):
                    require(witness["maximum_started_workers"] > 1, "real persistent workers started")
                    require(row["staging_overwrites"] > 0, "accepted caller staging was actually overwritten before full-content verification")
                    states = set()
                    for point in row["snapshots"]:
                        p = point["snapshot"]["parallel"]
                        if p["partial_input_bytes"]:
                            states.add("partial")
                        if p["queued_blocks"]:
                            states.add("queued")
                        if p["active_blocks"]:
                            states.add("active")
                        if p["completed_waiting_blocks"]:
                            states.add("completed")
                        if p["delivering_block"]:
                            states.add("delivering")
                    entry["ownership_witness"] = {
                        "actual_staging_overwrites": row["staging_overwrites"],
                        "observed_owned_input": witness["owned_input_observed"],
                        "observed_owned_input_states": sorted(states),
                        "actual_overwrites_with_queued_or_active_jobs": row["overwrites_with_jobs"],
                        "completed_before_return_allowed": True,
                        "per_case_peak_active_workers": row["peak_active_workers"],
                        "scope": "accepted input may be partial, queued, active, completed or delivering; completed delivery before step returns is valid and full plaintext remains mandatory",
                    }
            entry["status"] = "passed"
        except (AssertionError, OSError, json.JSONDecodeError, TypeError) as error:
            entry.update({"status": "failed", "failure": str(error)})
            failures.append({"name": name, "failure": str(error)})
        results.append(entry)
    native_cases = [("tiny", check, []) for check in CHECKS]
    native_cases += [("binary", "crc64", [{"kind": kind, "parameter": 3 if kind == "delta" else 16}]) for kind in FILTER_IDS]
    for index, (case, check, filters) in enumerate(native_cases):
        name = f"native-reference-{index:03d}"
        payload = inputs[case]
        encoded = reference.encode(payload, check, filters)
        input_path, output_path, config_path = directory / (name + ".xz"), directory / (name + ".decoded"), directory / (name + ".json")
        input_path.write_bytes(encoded)
        config_path.write_text(json.dumps({"operation": "decode", "max_output_len": len(payload)}) + "\n")
        command = [str(probe), str(input_path), str(output_path), str(config_path)]
        process = subprocess.run(command, capture_output=True, check=False, timeout=120)
        stdout, stderr = directory / (name + ".stdout"), directory / (name + ".stderr")
        stdout.write_bytes(process.stdout)
        stderr.write_bytes(process.stderr)
        commands.append({"command": command, "exit_code": process.returncode, "stdout": identity(stdout), "stderr": identity(stderr)})
        entry = {"name": name, "scope": "native-reference-to-target", "wire": identity(input_path), "independent_wire": inspect(encoded)}
        try:
            require(process.returncode == 0, "native-to-target decoder process")
            row = json.loads(process.stdout)
            entry["probe"] = row
            require(row["error"] is None and row["input_sha256"] == digest(encoded) and
                    row["output_sha256"] == digest(payload) and output_path.read_bytes() == payload, "native-to-target full decoded contents")
            entry["status"] = "passed"
        except (AssertionError, OSError, json.JSONDecodeError, TypeError) as error:
            entry.update({"status": "failed", "failure": str(error)})
            failures.append({"name": name, "failure": str(error)})
        results.append(entry)
    after = sources()
    maximum_workers = max((row["probe"]["peak_active_workers"] for row in results if "probe" in row), default=0)
    deferred_overwrites = sum(row["probe"]["overwrites_with_jobs"] for row in results if "probe" in row)
    moves_with_jobs = sum(row["probe"]["moves"] for row in results if "probe" in row and row["probe"]["move_with_jobs"])
    if maximum_workers <= 1:
        failures.append({"name": "actual-concurrent-worker-proof", "failure": "no natural peak active worker count above one"})
    if deferred_overwrites == 0:
        failures.append({"name": "actual-deferred-owned-input-proof", "failure": "no staging overwrite with queued or active jobs observed in the campaign"})
    if moves_with_jobs == 0:
        failures.append({"name": "actual-move-with-jobs-proof", "failure": "no actual encoder move with queued or active jobs observed in the campaign"})
    counts = {"cases": len(results), "passed": sum(row["status"] == "passed" for row in results), "failed": len(failures),
              "incremental_encode_cases": len(list(matrix())), "native_reference_decode_cases": len(native_cases),
              "observed_peak_active_workers": maximum_workers,
              "input_overwrites_with_jobs": deferred_overwrites,
              "actual_moves": sum(row["probe"]["moves"] for row in results if "probe" in row),
              "actual_moves_with_jobs": moves_with_jobs}
    report = {"schema": "vort.xz.incremental-parallel-differential.v1", "created_utc": datetime.now(timezone.utc).isoformat(),
              "source_epoch": args.source_epoch, "source": before, "source_after_sha256": after["sha256"], "sources_preserved": before == after,
              "probe": identity(probe), "reference": reference.describe(), "optional_original_mt_adapter": mt_identity,
              "optional_mt_provenance": provenance, "optional_mt_build_record": build_record,
              "python": platform.python_version(), "host": platform.platform(), "counts": counts, "failures": failures,
              "scope": "persistent parallel incremental XZ worker/input ownership, value movement, credit/retry/flush/stream transitions and full serial/independent wire correctness",
              "measurement_scope": "functional step/snapshot/worker/requested-heap counters only; no timing or RSS claims",
              "results": results, "commands": commands}
    path = args.report or directory / "differential.json"
    path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"report": str(path), **counts, "sources_preserved": report["sources_preserved"]}))
    require(not failures and report["sources_preserved"], ("incremental parallel gate", failures))


if __name__ == "__main__":
    main()
