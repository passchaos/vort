#!/usr/bin/env python3
"""Bounded real wide encoder oracle; --long encodes 4294967313 actual bytes.

Every wire byte travels through a pipe into independent Python/libz inflate.
Only configuration, stderr and JSON receipts are retained on disk.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import threading
import zlib

sys.dont_write_bytecode = True
from oracle import CHUNK, inflate_stream, require

ROOT = Path(__file__).resolve().parents[3]
LONG_COUNT = (1 << 32) + 17
CASES = [(family, "repeat") for family in
         ("raw_stored", "raw_fixed", "raw_best", "zlib_fixed", "zlib_best", "gzip_fixed", "gzip_best")]
CASES += [("png", "zero"), ("png", "dirty")]


def sha_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while data := source.read(CHUNK):
            digest.update(data)
    return digest.hexdigest()


def invoke(args, label, probe, pointer_bits, family, pattern, count):
    name = label + "-" + family + "-" + pattern
    result_path = args.output_dir / (name + ".probe.json")
    config_path = args.output_dir / (name + ".config.json")
    config = dict(family=family, pattern=pattern, count=count, report_path=str(result_path.resolve()))
    config_path.write_text(json.dumps(config) + "\n")
    result_path.unlink(missing_ok=True)
    command = [str(probe.resolve()), str(config_path.resolve())]
    partial_path = args.output_dir / (name + ".partial.json")
    def progress(receipt):
        partial_path.write_text(json.dumps(dict(name=name, status="running", command=command,
                                              target_count=count, oracle_receipt=receipt)) + "\n")
        print(json.dumps(dict(case=name, status="running", decoded_output=receipt["output_written"],
                              wire_consumed=receipt["input_read"])), flush=True)
    progress(dict(input_read=0, output_written=0, source_bytes=0, crc32=0, adler32=1, completed=False))
    stderr_path = args.output_dir / (name + ".stderr.log")
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=ROOT)
    captured, omitted = bytearray(), [0]
    def drain_stderr():
        while data := process.stderr.read(4096):
            room = max(0, 65536 - len(captured))
            captured.extend(data[:room])
            omitted[0] += len(data) - min(room, len(data))
    thread = threading.Thread(target=drain_stderr, daemon=True)
    thread.start()
    try:
        oracle = inflate_stream(process.stdout, family, pattern, count, progress)
        status = process.wait()
    except BaseException:
        process.kill()
        process.wait()
        raise
    finally:
        process.stdout.close()
        thread.join()
        process.stderr.close()
        if omitted[0]:
            captured.extend(("\n[omitted " + str(omitted[0]) + " stderr bytes]\n").encode())
        stderr_path.write_bytes(captured)
    require(status == 0 and result_path.exists(), (name, status, str(stderr_path)))
    report = json.loads(result_path.read_text())
    receipt = report["receipt"]
    require(report["pointer_bits"] == pointer_bits, (name, "pointer bits"))
    require(receipt["counter_bits"] == 64 and receipt["step_progress_bits"] == pointer_bits, (name, "counter/progress widths"))
    require(receipt["completed"] and receipt["input_read"] == count and receipt["pledged_input_len"] == count, (name, "actual accepted input/pledge"))
    require(receipt["output_written"] == oracle["input_read"], (name, "published wire receipt"))
    require(receipt["input_read"] == oracle["output_written"], (name, "decoded receipt"))
    require(receipt["input_crc32"] == oracle["crc32"] and receipt["input_adler32"] == oracle["adler32"], (name, "checksums"))
    require(receipt["heap_live_after_deinit"] == 0, (name, "retained encoder allocations"))
    require(receipt["premature_pledge_refusals"] == 1 and receipt["excess_pledge_refusals"] == 1, (name, "pledge rejection controls"))
    matcher = receipt["matcher"]
    if family not in ("raw_stored", "png"):
        require(matcher is not None and matcher["initialized"] and matcher["absolute_position"] == count, (name, "matcher actual position"))
        require(matcher["counter_bits"] == 64 and matcher["indexed_positions"] > 0 and matcher["retained_history_bytes"] > 0, (name, "matcher history/count"))
    if family == "png":
        require(receipt["zero_run_counter_bits"] == 64 and receipt["heap_peak"] == 0, (name, "PNG run width/zero heap"))
    if args.long:
        require(receipt["input_read"] > 1 << 32 and oracle["output_written"] > 1 << 32, (name, "actual >4GiB transfer"))
        if matcher is not None:
            require(matcher["absolute_position"] > 1 << 32, (name, "actual matcher boundary"))
        if family == "raw_stored":
            require(receipt["output_written"] > 1 << 32, (name, "actual stored wire boundary"))
        if family == "png":
            require(receipt["peak_zero_run"] > 1 << 32, (name, "actual PNG run did not cross 32bit"))
    event = dict(name=name, command=command, exit_code=status, probe_sha256=sha_file(probe),
                 config=config, report=report, oracle=oracle,
                 actual_input_exceeds_4g=receipt["input_read"] > 1 << 32,
                 actual_wire_exceeds_4g=receipt["output_written"] > 1 << 32)
    (args.output_dir / (name + ".result.json")).write_text(json.dumps(event, indent=2) + "\n")
    with (args.output_dir / "events.jsonl").open("a") as log:
        log.write(json.dumps(event) + "\n")
    partial_path.unlink(missing_ok=True)
    print(json.dumps(dict(case=name, status="ok", pointer_bits=pointer_bits,
                          actual_input=receipt["input_read"], wire_bytes=receipt["output_written"],
                          crc32=receipt["input_crc32"], adler32=receipt["input_adler32"])), flush=True)
    return event


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe-native", type=Path, required=True)
    parser.add_argument("--probe-x86", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    length = parser.add_mutually_exclusive_group()
    length.add_argument("--long", action="store_true")
    length.add_argument("--count", type=int)
    parser.add_argument("--only", choices=("all", "raw", "wrappers", "stored", "fixtures", "png"), default="all")
    args = parser.parse_args()
    count = LONG_COUNT if args.long else args.count if args.count is not None else 65553
    require(2 <= count < 1 << 64, "u64 count >=2")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    probes = [("native", args.probe_native, 64)]
    if args.probe_x86:
        probes.append(("x86", args.probe_x86, 32))
    cases = [(family, pattern) for family, pattern in CASES if args.only == "all" or
             (args.only == "raw" and family.startswith("raw_")) or
             (args.only == "wrappers" and family.startswith(("zlib_", "gzip_"))) or
             (args.only == "stored" and family == "raw_stored") or
             (args.only == "fixtures" and family not in ("raw_stored", "png")) or
             (args.only == "png" and family == "png")]
    events = [invoke(args, label, probe, bits, family, pattern, count)
              for label, probe, bits in probes for family, pattern in cases]
    if len(probes) == 2:
        by_name = {event["name"]: event for event in events}
        for family, pattern in cases:
            key = family + "-" + pattern
            require(by_name["native-" + key]["oracle"]["wire_sha256"] ==
                    by_name["x86-" + key]["oracle"]["wire_sha256"],
                    (key, "deterministic native/x86 wire"))
    report = dict(schema="vort.deflate.wide-encode-gate.v1", status="ok",
                  utc=datetime.now(timezone.utc).isoformat(), actual_command=[sys.executable, *sys.argv],
                  python_version=sys.version, zlib_compile_version=zlib.ZLIB_VERSION,
                  zlib_runtime_version=zlib.ZLIB_RUNTIME_VERSION, long=args.long, count=count,
                  only=args.only, cases=len(events), events=events, source_chunk_bytes=CHUNK,
                  native_x86_wire_compared=len(probes) == 2,
                  output_chunk_bytes=CHUNK, wire_transport="pipe", wire_collection=False,
                  plaintext_collection=False, counter_seeding=False,
                  driver_sha256=sha_file(Path(__file__)), oracle_sha256=sha_file(Path(__file__).with_name("oracle.py")))
    path = args.output_dir / "report.json"
    path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(dict(status="ok", cases=len(events), count=count, report=str(path.resolve()))))


if __name__ == "__main__":
    main()
