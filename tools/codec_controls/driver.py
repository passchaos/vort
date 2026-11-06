#!/usr/bin/env python3
"""Native/x86 public zlib window and Zstd content-checksum control matrix."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import threading
import zlib

sys.dont_write_bytecode = True
from zlib_cases import cases as zlib_cases
from zlib_oracle import inspect_zlib, window_distance_selfcheck
from zstd_cases import cases as zstd_cases
from zstd_reference import Library

ROOT = Path(__file__).resolve().parents[2]
LOCK = threading.Lock()


def require(ok, detail):
    if not ok:
        raise AssertionError(detail)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def emit(value):
    with LOCK:
        print(json.dumps(value), flush=True)


def invoke(output_dir, label, executable, bits, case):
    name = label + "-" + case["name"]
    config = dict(case["config"])
    wire_path = output_dir / (name + ".wire")
    config["output_path"] = str(wire_path.resolve())
    config_path = output_dir / (name + ".config.json")
    config_path.write_text(json.dumps(config) + "\n")
    command = [str(executable.resolve()), str(config_path.resolve())]
    with (output_dir / (name + ".stderr.log")).open("wb") as stderr:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=stderr, cwd=ROOT)
    require(result.returncode == 0, (name, result.returncode, str(stderr.name)))
    report = json.loads(result.stdout)
    require(report["pointer_bits"] == bits, (name, "target pointer bits"))
    receipt = report["receipt"]
    if config["family"] == "zlib":
        payload = Path(config["payload_path"]).read_bytes()
        dictionary = Path(config["dictionary_path"]).read_bytes() if config["dictionary_path"] else None
        incremental = config["api"].startswith("incremental_")
        presence = dictionary is not None and (not incremental or len(dictionary) != 0)
        oracle = inspect_zlib(wire_path.read_bytes(), payload, config["window_bits"], dictionary, presence)
        extra = []
        if incremental:
            require(receipt["stream_count"] == 3, (name, "reset/nextStream"))
            for stream in receipt["streams"][:3]:
                require(stream["input_read"] == len(payload) and stream["advertised_window"] == 1 << config["window_bits"], (name, "runtime window declaration"))
                path = Path(str(wire_path) + stream["suffix"])
                data = path.read_bytes()
                require(stream["wire_bytes"] == len(data), (name, "stream wire receipt"))
                extra.append(inspect_zlib(data, payload, config["window_bits"], dictionary, presence))
            if config["runtime_schedule"]:
                if config["api"] == "incremental_best":
                    require(receipt["streams"][0]["params_changes"] >= 2, (name, "runtime params"))
                else:
                    require(receipt["streams"][0]["unsupported_params_refusals"] == 2, (name, "unsupported fixed params"))
        else:
            require(receipt["invalid_options_refusals"] == 2, (name, "transactional setOptions window"))
        if config["window_bits"] == 15 and not config["api"].startswith("stored_chunks_"):
            require(receipt["default_bytes_checked"], (name, "default window bytes"))
        require(receipt["wire_bytes"] == wire_path.stat().st_size, (name, "wire receipt"))
        validation = dict(oracle=oracle, continued_streams=extra, wire_sha256=sha(wire_path),
                          dictionary_presence_expected=presence)
    else:
        oracle = case["oracle"]
        require(oracle["verified"], (name, "independent reference"))
        require(receipt["refused"] == (oracle["expected_error"] is not None), (name, "checksum/structure refusal"))
        if not receipt["refused"]:
            require(receipt["output_written"] == oracle["expected_bytes"], (name, "decoded byte count"))
        if oracle["expected_error"] and config["api"] in ("into", "append", "reuse_into", "reuse_append", "reuse_scratch"):
            require(receipt["atomic_failure_checked"], (name, "atomic publication"))
        if config["api"] == "incremental_direct" and not receipt["refused"]:
            require(receipt["direct_phase_seen"], (name, "actual direct path"))
        if config["api"] == "incremental_block" and not receipt["refused"]:
            require(receipt["streamed_sequences"] > 0, (name, "actual block sequence path"))
        if config["api"] == "incremental_prevalidated" and not receipt["refused"]:
            require(receipt["peak_compressed_buffered"] >= oracle["max_frame_bytes"], (name, "actual prevalidated compressed input"))
        validation = dict(oracle=oracle)
    event = dict(name=name, command=command, exit_code=0, report=report, validation=validation)
    (output_dir / (name + ".result.json")).write_text(json.dumps(event, indent=2) + "\n")
    emit(dict(case=name, status="ok", family=config["family"], api=config["api"], refused=receipt.get("refused", False)))
    return event


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe-native", type=Path, required=True)
    parser.add_argument("--probe-x86", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--reference-zstd", type=Path)
    parser.add_argument("--only", choices=("all", "zlib", "zstd"), default="all")
    parser.add_argument("--jobs", type=int, default=1)
    args = parser.parse_args()
    require(args.jobs > 0, "positive jobs")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    library = Library(args.reference_zstd)
    cases = []
    if args.only in ("all", "zlib"):
        cases.extend(zlib_cases(args.output_dir))
    if args.only in ("all", "zstd"):
        cases.extend(zstd_cases(args.output_dir, library))
    probes = [("native", args.probe_native, 64)]
    if args.probe_x86:
        probes.append(("x86", args.probe_x86, 32))
    tasks = [(args.output_dir, label, executable, bits, case) for label, executable, bits in probes for case in cases]
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        events = list(pool.map(lambda values: invoke(*values), tasks))
    with (args.output_dir / "events.jsonl").open("w") as output:
        for event in events:
            output.write(json.dumps(event) + "\n")
    report = dict(schema="vort.codec-format-controls.v1", status="ok", utc=datetime.now(timezone.utc).isoformat(),
                  actual_command=[sys.executable, *sys.argv], cases=len(events), jobs=args.jobs,
                  events=events, zstd_reference=library.provenance(), zlib_runtime=zlib.ZLIB_RUNTIME_VERSION,
                  independent_distance_boundary=window_distance_selfcheck(),
                  probes=[dict(label=label, path=str(path.resolve()), sha256=sha(path), pointer_bits=bits) for label, path, bits in probes])
    path = args.output_dir / "report.json"
    path.write_text(json.dumps(report, indent=2) + "\n")
    emit(dict(status="ok", cases=len(events), report=str(path.resolve())))


if __name__ == "__main__":
    main()
