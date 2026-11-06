#!/usr/bin/env python3
"""Actual native/x86 ZIP64 metadata and >4GiB streaming decode receipts.

Default smoke is small; --long uses 4294967313 real R bytes. Existing Deflate
and Zstd ZIPs may be reused. Method 9 comes from the public writer and Info-ZIP.
Stored ZIP64 is physically written, streamed, independently decoded, then removed.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import json
from pathlib import Path
import shutil
import subprocess
import sys
import threading

sys.dont_write_bytecode = True
from oracle import CHUNK, check_stream, metadata, require, sha, stored_archive, stored_decode, unzip

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/zip/wide_input"))
from codec_oracle import decode_deflate, decode_zstd

LONG_COUNT = (1 << 32) + 17
LOCK = threading.Lock()


def emit(value):
    with LOCK:
        print(json.dumps(value), flush=True)


def probe(args, executable, name, config):
    path = args.output_dir / (name + ".config.json")
    path.write_text(json.dumps(config) + "\n")
    command = [str(executable.resolve()), str(path.resolve())]
    emit(dict(case=name, status="running", operation=config["operation"]))
    with (args.output_dir / (name + ".stderr.log")).open("wb") as stderr:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=stderr, cwd=ROOT)
    require(result.returncode == 0, (name, result.returncode, str(stderr.name)))
    report = json.loads(result.stdout)
    (args.output_dir / (name + ".probe.json")).write_text(json.dumps(report, indent=2) + "\n")
    return command, report


def read_case(args, label, executable, bits, format_name, path, info, oracle, owned=None):
    kind = "source" if owned is None else "owned" if owned else "direct"
    name = label + "-" + format_name + "-" + kind
    command, report = probe(args, executable, name, dict(operation="read_archive" if owned is None else "read_entry",
                                                       path=str(path.resolve()), count=args.count,
                                                       crc32=info.crc32, owned=True if owned is None else owned))
    require(report["pointer_bits"] == bits, (name, "pointer bits"))
    result, receipt = report["result"], report["result"]["receipt"]
    require(receipt["counter_bits"] == 64 and receipt["progress_bits"] == bits and result["metadata"]["metadata_count_bits"] == 64, (name, "wide types"))
    require(receipt["completed"] and receipt["output_written"] == oracle["output_written"] == args.count and receipt["crc32"] == oracle["crc32"] == info.crc32, (name, "actual decoded receipt"))
    require(receipt["input_read"] == (info.archive_size if owned is None else info.compressed_size), (name, "input receipt"))
    require(result["metadata"]["uncompressed_size"] == args.count and result["metadata"]["compressed_size"] == info.compressed_size, (name, "public metadata values"))
    if owned is not None:
        require(result["metadata"]["canonical_parse"] and result["limit_refusals"] == 1, (name, "actual public parse/entryAt/limit"))
        if args.long and bits == 32:
            require(result["physical_extract_refusals"] == 1, (name, "checked physical extraction refusal"))
    else:
        require(result["central_offset"] == info.central_offset and receipt["entry_done"] == 1, (name, "public sourceReader metadata"))
    if args.long:
        require(receipt["output_written"] > 1 << 32, (name, "actual output did not cross 4GiB"))
        if format_name == "stored":
            require(receipt["input_read"] > 1 << 32, (name, "actual stored input did not cross 4GiB"))
    event = dict(name=name, command=command, report=report, metadata=info.report(), oracle=oracle,
                 archive_sha256=sha(path), probe_sha256=sha(executable), exit_code=0)
    (args.output_dir / (name + ".result.json")).write_text(json.dumps(event, indent=2) + "\n")
    emit(dict(case=name, status="ok", input_read=receipt["input_read"], output_written=receipt["output_written"], crc32=receipt["crc32"]))
    return event


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe-native", type=Path, required=True)
    parser.add_argument("--probe-x86", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--input-dir", type=Path)
    parser.add_argument("--unzip", type=Path, default=Path(shutil.which("unzip") or "/usr/bin/unzip"))
    parser.add_argument("--jobs", type=int, default=1)
    parser.add_argument("--only", choices=("all", "compressed", "deflate64", "stored"), default="all")
    length = parser.add_mutually_exclusive_group()
    length.add_argument("--long", action="store_true")
    length.add_argument("--count", type=int)
    args = parser.parse_args()
    args.count = LONG_COUNT if args.long else args.count if args.count is not None else 65553
    require(0 < args.count < 1 << 64 and args.jobs > 0, "positive u64 Count/jobs")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    probes = [("native", args.probe_native, 64)]
    if args.probe_x86:
        probes.append(("x86", args.probe_x86, 32))
    if args.long and args.input_dir is None:
        args.input_dir = Path("/tmp/vort-zip-wide-input-v2-long")
    version = subprocess.run([str(args.unzip), "-v"], stdout=subprocess.PIPE, check=True).stdout.decode(errors="replace")
    require("USE_DEFLATE64" in version, "Info-ZIP must support Deflate64")
    tasks, artifacts, stored_path = [], [], None
    for label, executable, bits in probes:
        for family in (("deflate", "zstd", "deflate64") if args.only == "all" else ("deflate", "zstd") if args.only == "compressed" else ("deflate64",) if args.only == "deflate64" else ()):
            path = args.output_dir / (label + "-" + family + ".zip")
            written = None
            if family != "deflate64" and args.input_dir:
                path = args.input_dir / path.name
                require(path.exists(), ("missing actual ZIP fixture", str(path)))
            else:
                _, written = probe(args, executable, label + "-write-" + family, dict(operation="write_archive", path=str(path.resolve()), count=args.count,
                                                                                    method={"deflate": "deflate", "zstd": "zstandard", "deflate64": "deflate64"}[family]))
                require(written["receipt"]["input_read"] == args.count and written["receipt"]["completed"] and written["receipt"]["metadata"]["canonical_parse"], "actual public writer receipt")
            info = metadata(path, args.count)
            require(info.method == {"deflate": 8, "zstd": 93, "deflate64": 9}[family], "ZIP compression method")
            def progress(value, case=label + "-" + family): emit(dict(case=case, status="independent-decoding", **value))
            oracle = decode_deflate(path, info, progress) if family == "deflate" else decode_zstd(path, info, progress) if family == "zstd" else unzip(path, info, args.unzip, progress)
            artifacts.append(dict(path=str(path.resolve()), metadata=info.report(), oracle=oracle,
                                  public_writer_receipt=written))
            for owned in ((False, True, None) if family == "deflate" else (True, None)):
                tasks.append((args, label, executable, bits, family, path, info, oracle, owned))
    if args.only in ("all", "stored"):
        stored_path = args.output_dir / "temporary-stored.zip"
        emit(dict(case="stored", status="physically-generating", count=args.count))
        source = stored_archive(stored_path, args.count)
        info = metadata(stored_path, args.count)
        oracle = stored_decode(stored_path, info)
        require(source["actual_source_bytes"] == args.count and source["crc32"] == oracle["crc32"], "stored source/independent receipt")
        artifacts.append(dict(path=str(stored_path.resolve()), source=source, metadata=info.report(), oracle=oracle, temporary=True))
        for label, executable, bits in probes:
            tasks.append((args, label, executable, bits, "stored", stored_path, info, oracle, None))
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        events = list(pool.map(lambda parameters: read_case(*parameters), tasks))
    with (args.output_dir / "events.jsonl").open("w") as log:
        for event in events: log.write(json.dumps(event) + "\n")
    if stored_path:
        stored_path.unlink()
    report = dict(schema="vort.zip.wide-read-oracle.v1", status="ok", utc=datetime.now(timezone.utc).isoformat(),
                  actual_command=[sys.executable, *sys.argv], count=args.count, long=args.long, jobs=args.jobs,
                  cases=len(events), events=events, artifacts=artifacts, unzip_version=version, unzip_sha256=sha(args.unzip),
                  input_chunk_bytes=CHUNK, output_chunk_bytes=CHUNK, plaintext_collection=False,
                  stored_reference_removed=stored_path is not None, counter_seeding=False)
    path = args.output_dir / "report.json"
    path.write_text(json.dumps(report, indent=2) + "\n")
    emit(dict(status="ok", cases=len(events), count=args.count, report=str(path.resolve())))


if __name__ == "__main__":
    main()
