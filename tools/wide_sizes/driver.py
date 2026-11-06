#!/usr/bin/env python3
"""Actual native/x86 count and static-dictionary wire receipts.

--long uses 4294967313 real source/decoded bytes. Size fixtures are streamed
through system encoders and independent sinks. Dictionary wire only uses a
pipe; no full plaintext or multi-GiB raw wire is retained.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import threading

sys.dont_write_bytecode = True
from reference import CHUNK, METADATA, TILE_LEN, Libraries, require

ROOT = Path(__file__).resolve().parents[2]
LONG_COUNT = (1 << 32) + 17
OUTPUT_LOCK = threading.Lock()


def emit(value):
    with OUTPUT_LOCK:
        print(json.dumps(value), flush=True)


def sha(path):
    value = hashlib.sha256()
    with path.open("rb") as source:
        while data := source.read(CHUNK):
            value.update(data)
    return value.hexdigest()


def record(args, name, command, probe, report, oracle, source=None):
    require(report["stream_count_bits"] == 64 and report["count"] == args.count, (name, "Count64/config"))
    require(report["wire_bytes"] == oracle["input_read"], (name, "physical wire receipt"))
    require(report["heap_live_after"] == 0, (name, "working allocations remain"))
    if args.long:
        require(oracle["output_written"] > 1 << 32 and oracle["content_checked_bytes"] > 1 << 32, (name, "actual decoded bytes did not cross 4GiB"))
        if source:
            require(source["actual_source_bytes"] > 1 << 32, (name, "actual source did not cross 4GiB"))
    event = dict(name=name, command=command, probe_sha256=sha(probe), report=report,
                 oracle=oracle, source=source, exit_code=0,
                 actual_decoded_bytes_exceed_4g=oracle["output_written"] > 1 << 32)
    (args.output_dir / (name + ".result.json")).write_text(json.dumps(event, indent=2) + "\n")
    emit(dict(case=name, status="ok", pointer_bits=report["pointer_bits"],
              logical_output=args.count, actual_decoded=oracle["output_written"],
              physical_wire=oracle["input_read"], heap_peak=report["heap_peak"]))
    return event


def sizes(args, libraries, label, probe, bits, family, fixture, source, oracle):
    name = label + "-" + family + "-sizes"
    path = args.output_dir / (name + ".config.json")
    path.write_text(json.dumps(dict(mode=family + "_size", count=args.count, wire_path=str(fixture.resolve()))) + "\n")
    command = [str(probe.resolve()), str(path.resolve())]
    emit(dict(case=name, status="running"))
    with (args.output_dir / (name + ".stderr.log")).open("wb") as log:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=log, cwd=ROOT)
    require(result.returncode == 0, (name, result.returncode, str(log.name)))
    report = json.loads(result.stdout)
    require(report["pointer_bits"] == bits, (name, "target word bits"))
    receipt = report["receipt"]
    require(receipt["decoded_count"] == args.count and receipt["count_bits"] == 64 and receipt["chunks_checked"], (name, "wide size/chunks"))
    require(receipt["output_limit_refusals"] > 0, (name, "output-limit semantics"))
    if family == "brotli":
        require(receipt["metadata_bytes"] == len(METADATA), (name, "metadata semantics"))
    else:
        require(receipt["checksum_frames"] == 1 and receipt["checksum_count_only"] and receipt["footer_truncation_refusals"] == 1, (name, "count-only checksum semantics"))
    return record(args, name, command, probe, report, oracle, source)


def dictionary(args, libraries, label, probe, bits, api):
    name = label + "-dictionary-" + api
    config_path = args.output_dir / (name + ".config.json")
    report_path = args.output_dir / (name + ".probe.json")
    report_path.unlink(missing_ok=True)
    config_path.write_text(json.dumps(dict(mode="dictionary_" + api, count=args.count, report_path=str(report_path.resolve()))) + "\n")
    command = [str(probe.resolve()), str(config_path.resolve())]
    emit(dict(case=name, status="running", target=args.count))
    partial = args.output_dir / (name + ".partial.json")
    partial.write_text(json.dumps(dict(name=name, status="running", target=args.count, actual_decoded=0)) + "\n")
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=ROOT)
    captured, omitted = bytearray(), [0]
    def stderr_reader():
        while data := process.stderr.read(4096):
            room = max(0, 65536 - len(captured))
            captured.extend(data[:room])
            omitted[0] += len(data) - min(room, len(data))
    thread = threading.Thread(target=stderr_reader, daemon=True)
    thread.start()
    sink = libraries.sink("brotli", args.count, True)
    checkpoint = 256 * 1024 * 1024
    try:
        while data := process.stdout.read(CHUNK):
            sink.feed(data)
            if sink.receipt["output_written"] >= checkpoint:
                partial.write_text(json.dumps(dict(name=name, status="running", target=args.count, oracle_receipt=sink.receipt)) + "\n")
                emit(dict(case=name, status="running", actual_decoded=sink.receipt["output_written"]))
                checkpoint = sink.receipt["output_written"] + 256 * 1024 * 1024
        oracle = sink.finish()
        status = process.wait()
    except BaseException:
        process.kill()
        process.wait()
        raise
    finally:
        sink.close()
        process.stdout.close()
        thread.join()
        process.stderr.close()
        if omitted[0]:
            captured.extend(("\n[omitted " + str(omitted[0]) + " bytes]\n").encode())
        (args.output_dir / (name + ".stderr.log")).write_bytes(captured)
    require(status == 0 and report_path.exists(), (name, status))
    report = json.loads(report_path.read_text())
    require(report["pointer_bits"] == bits and report["tile_bytes"] == TILE_LEN, (name, "word/tile geometry"))
    require(report["chunk_views"] == (args.count + TILE_LEN - 1) // TILE_LEN, (name, "physical chunk descriptors"))
    require(report["summary"]["decoded_bytes"] == args.count and report["summary"]["uses_static_dictionary"] and report["summary"]["static_dictionary_copy_count"] > 0, (name, "actual dictionary stream"))
    require(report["summary"]["metadata_bytes"] == len(METADATA), (name, "dictionary metadata"))
    require(report["input_limit_refusals"] == 1, (name, "logical input cap"))
    partial.unlink(missing_ok=True)
    return record(args, name, command, probe, report, oracle)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe-native", type=Path, required=True)
    parser.add_argument("--probe-x86", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    length = parser.add_mutually_exclusive_group()
    length.add_argument("--long", action="store_true")
    length.add_argument("--count", type=int)
    parser.add_argument("--only", choices=("all", "sizes", "dictionary"), default="all")
    parser.add_argument("--dictionary-api", choices=("both", "alloc", "append"), default="both")
    parser.add_argument("--jobs", type=int, default=1, help="Number of independent probe cases to run concurrently")
    args = parser.parse_args()
    args.count = LONG_COUNT if args.long else args.count if args.count is not None else 65553
    require(0 < args.count < 1 << 64, "positive u64 count")
    require(args.jobs > 0, "positive jobs")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    libraries = Libraries()
    probes = [("native", args.probe_native, 64)]
    if args.probe_x86:
        probes.append(("x86", args.probe_x86, 32))
    tasks, fixtures = [], []
    if args.only in ("all", "sizes"):
        for family in ("brotli", "zstd"):
            fixture = args.output_dir / (family + ".wire")
            emit(dict(fixture=family, status="producing", actual_target=args.count))
            source = libraries.produce(family, fixture, args.count)
            sink = libraries.sink(family, args.count)
            try:
                with fixture.open("rb") as file:
                    while data := file.read(CHUNK):
                        sink.feed(data)
                oracle = sink.finish()
            finally:
                sink.close()
            require(source["wire_bytes"] == oracle["input_read"] and source["wire_sha256"] == oracle["wire_sha256"] and source["source_crc32"] == oracle["crc32"], (family, "producer/sink receipts"))
            fixtures.append(dict(family=family, path=str(fixture.resolve()), source=source, oracle=oracle))
            for label, probe, bits in probes:
                tasks.append((sizes, (args, libraries, label, probe, bits, family, fixture, source, oracle)))
    if args.only in ("all", "dictionary"):
        apis = ("alloc", "append") if args.dictionary_api == "both" else (args.dictionary_api,)
        for label, probe, bits in probes:
            for api in apis:
                tasks.append((dictionary, (args, libraries, label, probe, bits, api)))
    # Only immutable fixtures and library function bindings are shared. Each
    # task owns its subprocess, pipe, decoder state, buffers and result paths.
    results, failures = {}, []
    with ThreadPoolExecutor(max_workers=args.jobs) as executor:
        futures = {executor.submit(function, *parameters): index for index, (function, parameters) in enumerate(tasks)}
        for future in as_completed(futures):
            try:
                results[futures[future]] = future.result()
            except Exception as error:
                failures.append(error)
    events = [results[index] for index in sorted(results)]
    # Preserve the canonical case order; a single main-thread writer publishes
    # every completed event, including receipts before another case failed.
    with (args.output_dir / "events.jsonl").open("w") as log:
        for event in events:
            log.write(json.dumps(event) + "\n")
    if failures:
        raise failures[0]
    result = dict(schema="vort.wide-size-oracle.v1", status="ok", utc=datetime.now(timezone.utc).isoformat(),
                  actual_command=[sys.executable, *sys.argv], count=args.count, long=args.long,
                  only=args.only, dictionary_api=args.dictionary_api, jobs=args.jobs, cases=len(events), events=events,
                  fixtures=fixtures, zstd_version=libraries.z_version, brotli_version=libraries.br_version,
                  oracle_pointer_bits=64, source_chunk_bytes=CHUNK, sink_chunk_bytes=CHUNK,
                  plaintext_collection=False, dictionary_wire_collection=False, counter_seeding=False)
    path = args.output_dir / "report.json"
    path.write_text(json.dumps(result, indent=2) + "\n")
    emit(dict(status="ok", cases=len(events), count=args.count, jobs=args.jobs, report=str(path.resolve())))


if __name__ == "__main__":
    main()
