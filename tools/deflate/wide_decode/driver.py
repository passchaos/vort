#!/usr/bin/env python3
"""Actual bounded Deflate count receipts, independently checked by Python libz.

--long feeds 4294967313 real 'R' bytes per selected decode. Plaintext and raw
stored wire are never collected; compressed fixtures remain ordinary files.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zlib

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
CHUNK = 65536
REPEATED = b"R" * CHUNK
STORED_PAYLOAD = REPEATED[:65535]
LONG_COUNT = (1 << 32) + 17
WBITS = {"raw_all": -15, "zlib": 15, "gzip": 31}


def require(ok, detail):
    if not ok:
        raise AssertionError(detail)


def sha_file(path):
    value = hashlib.sha256()
    with path.open("rb") as source:
        while data := source.read(CHUNK):
            value.update(data)
    return value.hexdigest()


def stored_source(count):
    remaining = count
    while remaining >= 65535:
        yield b"\x00\xff\xff\x00\x00"
        yield STORED_PAYLOAD
        remaining -= 65535
    yield b"\x01" + remaining.to_bytes(2, "little") + (remaining ^ 65535).to_bytes(2, "little")
    if remaining:
        yield REPEATED[:remaining]


def file_source(path):
    with path.open("rb") as source:
        while data := source.read(CHUNK):
            yield data


def inflate_receipt(pieces, wbits, count):
    decoder = zlib.decompressobj(wbits)
    receipt = dict(input_read=0, output_written=0, source_bytes=0, calls=0,
                   crc32=0, completed=False, all_output_bytes_checked=True)
    wire_hash = hashlib.sha256()
    for piece in pieces:
        require(not decoder.eof, "oracle received bytes after stream end")
        receipt["source_bytes"] += len(piece)
        wire_hash.update(piece)
        pending = piece
        while True:
            before = len(pending)
            output = decoder.decompress(pending, CHUNK)
            consumed = before - len(decoder.unconsumed_tail) - len(decoder.unused_data)
            require(consumed >= 0, "oracle input receipt")
            receipt["input_read"] += consumed
            receipt["output_written"] += len(output)
            receipt["calls"] += 1
            require(output == REPEATED[:len(output)], "oracle plaintext content")
            receipt["crc32"] = zlib.crc32(output, receipt["crc32"])
            require(receipt["output_written"] <= count, "oracle excess plaintext")
            pending = decoder.unconsumed_tail
            if decoder.eof:
                require(not pending and not decoder.unused_data, "oracle trailing bytes")
                break
            if not pending and len(output) < CHUNK:
                break
            require(consumed != 0 or output, "oracle no progress")
    require(decoder.eof, "oracle truncated stream")
    require(receipt["input_read"] == receipt["source_bytes"], "oracle wire receipt")
    require(receipt["output_written"] == count, "oracle decoded receipt")
    receipt["crc32"] &= 0xFFFFFFFF
    receipt["completed"] = True
    receipt["wire_sha256"] = wire_hash.hexdigest()
    return receipt


def compressed_fixture(path, family, count):
    encoder = zlib.compressobj(level=6, wbits=WBITS[family])
    remaining, consumed, crc, calls = count, 0, 0, 0
    with path.open("wb") as sink:
        while remaining:
            size = min(CHUNK, remaining)
            piece = REPEATED[:size]
            sink.write(encoder.compress(piece))
            crc = zlib.crc32(piece, crc)
            consumed += size
            remaining -= size
            calls += 1
        sink.write(encoder.flush(zlib.Z_FINISH))
    require(consumed == count, "compressor real input receipt")
    return dict(path=str(path.resolve()), family=family, input_processed=consumed,
                input_crc32=crc & 0xFFFFFFFF, input_calls=calls,
                compressed_bytes=path.stat().st_size, sha256=sha_file(path),
                level=6, wbits=WBITS[family])


def invoke(args, name, probe, pointer_bits, config, oracle):
    config_path = args.output_dir / (name + ".config.json")
    config_path.write_text(json.dumps(config) + "\n")
    command = [str(probe.resolve()), str(config_path.resolve())]
    with (args.output_dir / (name + ".stderr.log")).open("wb") as log:
        completed = subprocess.run(command, stdout=subprocess.PIPE, stderr=log, cwd=ROOT)
    require(completed.returncode == 0, (name, completed.returncode, str(log.name)))
    report = json.loads(completed.stdout)
    receipt = report["receipt"]
    require(report["pointer_bits"] == pointer_bits, (name, "pointer width"))
    require(receipt["counter_bits"] == 64, (name, "cumulative Count width"))
    require(receipt["step_progress_bits"] == pointer_bits, (name, "local progress width"))
    require(report["all_output_bytes_checked"] and receipt["completed"], (name, "content/completion"))
    for field in ("input_read", "output_written", "source_bytes", "crc32"):
        require(receipt[field] == oracle[field], (name, field, receipt[field], oracle[field]))
    if args.long:
        require(receipt["output_written"] > 1 << 32, (name, "actual output did not cross 4 GiB"))
        if config["operation"] == "generated_stored":
            require(receipt["input_read"] > 1 << 32, (name, "actual input did not cross 4 GiB"))
    if config["operation"] == "decode_fixture" and config["family"] == "raw_all":
        if config["semantic"] and config["count"] > 1 << 32:
            require(receipt["semantic_blocks_completed"] > 0, (name, "semantic path was not exercised"))
        elif not config["semantic"]:
            require(receipt["semantic_blocks_started"] == 0, (name, "fallback selected semantic path"))
    if config["family"] in ("zlib", "gzip"):
        require(receipt["member_end_offset"] == oracle["input_read"], (name, "footer boundary"))
    event = dict(name=name, command=command, exit_code=completed.returncode,
                 probe_sha256=sha_file(probe), config=config, report=report, oracle=oracle,
                 actual_input_exceeds_4g=receipt["input_read"] > 1 << 32,
                 actual_output_exceeds_4g=receipt["output_written"] > 1 << 32)
    (args.output_dir / (name + ".result.json")).write_text(json.dumps(event, indent=2) + "\n")
    with (args.output_dir / "events.jsonl").open("a") as log:
        log.write(json.dumps(event) + "\n")
    print(json.dumps(dict(case=name, status="ok", pointer_bits=pointer_bits,
                          input_read=receipt["input_read"], output_written=receipt["output_written"],
                          crc32=receipt["crc32"])), flush=True)
    return event


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe-native", type=Path, required=True)
    parser.add_argument("--probe-x86", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    length = parser.add_mutually_exclusive_group()
    length.add_argument("--long", action="store_true")
    length.add_argument("--count", type=int)
    parser.add_argument("--only", choices=("all", "stored", "fixtures"), default="all")
    args = parser.parse_args()
    count = LONG_COUNT if args.long else args.count if args.count is not None else 65553
    require(0 < count < 1 << 64, "u64 positive count")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    probes = [("native", args.probe_native, 64)]
    if args.probe_x86:
        probes.append(("x86", args.probe_x86, 32))
    events, fixtures = [], []
    if args.only in ("all", "stored"):
        oracle = inflate_receipt(stored_source(count), -15, count)
        require(oracle["input_read"] == count + 5 * (count // 65535 + 1), "stored RFC wire length")
        for label, probe, bits in probes:
            for family in ("raw_stored", "raw_all"):
                config = dict(operation="generated_stored", family=family, count=count, semantic=False)
                events.append(invoke(args, label + "-stored-" + family, probe, bits, config, oracle))
    if args.only in ("all", "fixtures"):
        for family in ("raw_all", "zlib", "gzip"):
            fixture_path = args.output_dir / (family + ".deflate")
            fixture = compressed_fixture(fixture_path, family, count)
            oracle = inflate_receipt(file_source(fixture_path), WBITS[family], count)
            require(fixture["input_crc32"] == oracle["crc32"], "compressor/oracle CRC")
            require(fixture["sha256"] == oracle["wire_sha256"], "fixture input identity")
            fixtures.append(fixture)
            for label, probe, bits in probes:
                for semantic in ((False, True) if family == "raw_all" else (False,)):
                    config = dict(operation="decode_fixture", family=family, count=count,
                                  semantic=semantic, fixture_path=str(fixture_path.resolve()))
                    name = label + "-fixture-" + family + ("-semantic" if semantic else "-fallback")
                    events.append(invoke(args, name, probe, bits, config, oracle))
    report = dict(schema="vort.deflate.wide-decode-gate.v1", status="ok",
                  utc=datetime.now(timezone.utc).isoformat(), actual_command=[sys.executable, *sys.argv],
                  python_version=sys.version, zlib_compile_version=zlib.ZLIB_VERSION,
                  zlib_runtime_version=zlib.ZLIB_RUNTIME_VERSION, long=args.long,
                  count=count, only=args.only, cases=len(events), fixtures=fixtures, events=events,
                  source_chunk_bytes=CHUNK, output_chunk_bytes=CHUNK,
                  plaintext_chunk_bytes=CHUNK, plaintext_collection=False, counter_seeding=False)
    (args.output_dir / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(dict(status="ok", cases=len(events), count=count,
                          report=str((args.output_dir / "report.json").resolve()))))


if __name__ == "__main__":
    main()
