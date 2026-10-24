#!/usr/bin/env python3
"""Real stream-counter gates: bounded sources, drains and independent C sinks.

Default lengths are smoke-sized. --long is the explicitly approved >4GiB
matrix; no virtual counter seeds, sparse files or full plaintext collections.
"""
import argparse
import ctypes as C
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
def fixed_pattern():
    value, data = 0x51a7c0de, bytearray()
    for _ in range(65536):
        value ^= (value << 13) & 0xffffffff
        value ^= value >> 17
        value ^= (value << 5) & 0xffffffff
        data.append(value & 255)
    return bytes(data)
PATTERN = fixed_pattern()
CHUNK = 65536


def require(value, detail):
    if not value: raise AssertionError(detail)


def bind(lib, name, result, *arguments):
    function = getattr(lib, name)
    function.restype, function.argtypes = result, list(arguments)
    return function


def sha(data): return hashlib.sha256(data).hexdigest()


class Receipt(C.Structure):
    _fields_ = [(name, C.c_uint64) for name in ("input_read", "output_written", "calls", "content_checks", "xxh64")]
    _fields_ += [(name, C.c_uint32) for name in ("done", "failed")]


class Reference:
    def __init__(self, path):
        self.path = path.resolve()
        loader = C.CDLL("libdl.so.2")
        handle = bind(loader, "dlmopen", C.c_void_p, C.c_long, C.c_char_p, C.c_int)(-1, str(self.path).encode(), 2)
        require(handle, "reference namespace")
        self.lib = C.CDLL(str(self.path), handle=handle)
        self.zstd = bind(self.lib, "rc_zstd_version", C.c_uint32)()
        self.br = bind(self.lib, "rc_br_version", C.c_uint32)()
        self.zstd_header = bind(self.lib, "rc_zstd_header_version", C.c_uint32)()
        require(self.zstd == self.zstd_header, "matching Zstd headers/runtime")
        require(bind(self.lib, "rc_receipt_size", C.c_size_t)() == C.sizeof(Receipt), "reference receipt ABI")
        path_fn = bind(self.lib, "rc_library_path", C.c_char_p, C.c_uint32)
        self.paths = [Path(path_fn(index).decode()).resolve() for index in (0, 1)]
        self.create = bind(self.lib, "rc_create", C.c_void_p, C.c_uint32, C.c_uint32, C.c_uint64, C.c_uint64, C.c_void_p, C.c_size_t)
        self.feed = bind(self.lib, "rc_feed", C.c_int, C.c_void_p, C.c_void_p, C.c_size_t)
        self.finish = bind(self.lib, "rc_finish", C.c_int, C.c_void_p, C.POINTER(Receipt))
        self.destroy = bind(self.lib, "rc_destroy", None, C.c_void_p)
        self.rle = bind(self.lib, "rc_rle_fixture", C.c_size_t, C.c_uint64, C.c_void_p, C.c_size_t, C.POINTER(C.c_uint64))

    def state(self, family, kind, count, prefix=None, tail=b""):
        return Sink(self, family, kind, count, count if prefix is None else prefix, tail)

    def fixture(self, count):
        output, checksum = C.create_string_buffer(1024 * 1024), C.c_uint64()
        size = self.rle(count, output, len(output), C.byref(checksum))
        require(size, "bounded RLE fixture size")
        return output.raw[:size], checksum.value

    def provenance(self):
        return {"helper": str(self.path), "helper_sha256": sha(self.path.read_bytes()), "zstd_header": self.zstd_header,
                "zstd_runtime": self.zstd, "br_runtime": hex(self.br),
                "libraries": [{"path": str(path), "sha256": sha(path.read_bytes())} for path in self.paths]}


class Sink:
    def __init__(self, reference, family, kind, count, prefix, tail):
        self.reference, self.tail = reference, C.create_string_buffer(tail)
        self.pointer = reference.create(family, kind, count, prefix, self.tail, len(tail))
        require(self.pointer, "C stream reference state")

    def feed(self, data):
        require(self.reference.feed(self.pointer, data, len(data)) == 0, "independent stream reference rejected bytes/content")

    def finish(self):
        receipt = Receipt()
        require(self.reference.finish(self.pointer, C.byref(receipt)) == 0, "reference final progress")
        return {name: getattr(receipt, name) for name, _ in Receipt._fields_}

    def close(self):
        self.reference.destroy(self.pointer)
        self.pointer = None


def payload_chunk(offset, count):
    phase = offset % len(PATTERN)
    repeats = (count + phase + len(PATTERN) - 1) // len(PATTERN)
    return (PATTERN * repeats)[phase:phase + count]


def br_header(first, kind, size):
    bit, value = 0, 0
    def add(item, width):
        nonlocal bit, value
        value |= item << bit
        bit += width
    if first: add(0, 1)
    add(0, 1)
    if kind == "metadata":
        add(3, 2); add(0, 1)
        width = 1 if size <= 256 else 2 if size <= 65536 else 3
        add(width, 2); add(size - 1, width * 8)
    else:
        width = 16 if size <= 65536 else 20 if size <= 1048576 else 24
        add(width // 4 - 4, 2); add(size - 1, width); add(1, 1)
    return value.to_bytes((bit + 7) // 8, "little")


def generated(kind, count, block, suffix=b""):
    if kind == "metadata":
        require(br_header(True, kind, 1 << 24) == bytes.fromhex("ecffff7f"), "audited first metadata header")
        require(br_header(False, kind, 1 << 24) == bytes.fromhex("f6ffff3f"), "audited following metadata header")
    elif kind == "stored":
        require(br_header(True, kind, 1 << 24) == bytes.fromhex("f8ffff1f"), "audited first stored header")
        require(br_header(False, kind, 1 << 24) == bytes.fromhex("fcffff0f"), "audited following stored header")
    remaining, offset, first = count, 0, True
    while remaining:
        size = min(remaining, block)
        yield (b"\x50\x2a\x4d\x18" + size.to_bytes(4, "little")) if kind == "skip" else br_header(first, kind, size)
        first = False
        left = size
        while left:
            take = min(CHUNK, left)
            yield payload_chunk(offset, take)
            left -= take; remaining -= take; offset += take
    if kind != "skip": yield suffix or (b"\x06" if first else b"\x03")


def invoke(args, name, probe, config, sinks=()):
    path = args.output_dir / (name + ".config.json")
    result_path = args.output_dir / (name + ".result.json")
    config = {**config}
    if config.get("wire_stdout"): config["result_path"] = str(result_path)
    path.write_text(json.dumps(config) + "\n")
    command = [str(probe), str(path)]
    output_hash, output_count = hashlib.sha256(), 0
    with (args.output_dir / (name + ".stderr.log")).open("wb") as log:
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=log, cwd=ROOT)
        if config.get("wire_stdout"):
            while True:
                data = process.stdout.read(CHUNK)
                if not data: break
                output_hash.update(data); output_count += len(data)
                for sink in sinks: sink.feed(data)
            status = process.wait()
            report = json.loads(result_path.read_text()) if result_path.exists() else None
        else:
            data = process.stdout.read()
            status = process.wait()
            report = json.loads(data) if data else None
            if report is not None: result_path.write_text(json.dumps(report, indent=2) + "\n")
    require(status == 0 and report is not None, (name, status, str(args.output_dir / (name + ".stderr.log"))))
    require(report["allocation_live_after_deinit"] == 0, (name, "live codec allocations"))
    event = {"name": name, "command": command, "exit_code": status, "probe_sha256": sha(probe.read_bytes()), "report": report}
    if config.get("wire_stdout"):
        event.update(wire_sha256=output_hash.hexdigest(), wire_bytes=output_count)
    with (args.output_dir / "events.jsonl").open("a") as log: log.write(json.dumps(event) + "\n")
    print(json.dumps({"case": name, "status": "ok", "pointer_bits": report["pointer_bits"]}), flush=True)
    return event


def verify_references(references, family, kind, expected, pieces, prefix=None, tail=b""):
    sinks = [reference.state(family, kind, expected, prefix, tail) for reference in references]
    try:
        for piece in pieces:
            for sink in sinks: sink.feed(piece)
        return [sink.finish() for sink in sinks]
    finally:
        for sink in sinks: sink.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--br-probe", type=Path, required=True)
    parser.add_argument("--zstd-probe", type=Path, required=True)
    parser.add_argument("--reference", type=Path, action="append", required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--long", action="store_true")
    parser.add_argument("--reuse-reference-report", type=Path)
    args = parser.parse_args()
    args.output_dir = args.output_dir.resolve(); args.output_dir.mkdir(parents=True, exist_ok=True)
    args.br_probe = args.br_probe.resolve(); args.zstd_probe = args.zstd_probe.resolve()
    references = [Reference(path) for path in args.reference]
    old = json.loads(args.reuse_reference_report.read_text()) if args.reuse_reference_report else None
    prefix = (1 << 32) if args.long else 262144
    block = (1 << 24) if args.long else 65536
    fixture_path = args.output_dir / "zstd-rle.bin"
    if old:
        require(old["long"] == args.long, "reference reuse scale")
        fixture = Path(old["rle_fixture_path"]).read_bytes(); checksum = old["rle_checksum"]
    else: fixture, checksum = references[0].fixture(prefix + 1)
    fixture_path.write_bytes(fixture)
    rows, reference_rows = [], {}
    rows.append(invoke(args, "zstd-rle", args.zstd_probe, {"operation": "decode_rle", "count": prefix + 1, "fixture_path": str(fixture_path)}))
    reference_rows["zstd-rle"] = old["reference_rows"]["zstd-rle"] if old else verify_references(references, 0, 0, prefix + 1, [fixture])
    require(all(row["xxh64"] == checksum for row in reference_rows["zstd-rle"]), "independent XXH64 and content checksum")
    count = prefix + 1
    rows.append(invoke(args, "zstd-skip", args.zstd_probe, {"operation": "decode_skip", "count": count}))
    reference_rows["zstd-skip"] = old["reference_rows"]["zstd-skip"] if old else verify_references(references, 0, 2, 0, generated("skip", count, (1 << 32) - 1))
    wire_path = args.output_dir / "zstd-encoded.bin"
    rows.append(invoke(args, "zstd-encode", args.zstd_probe, {"operation": "encode", "count": prefix + 17, "output_path": str(wire_path)}))
    wire = wire_path.read_bytes()
    if old:
        require(sha(wire) == old["zstd_encoder_wire_sha256"], "cross-target encoder wire equality")
        reference_rows["zstd-encode"] = old["reference_rows"]["zstd-encode"]
    else: reference_rows["zstd-encode"] = verify_references(references, 0, 1, prefix + 17, [wire], prefix=prefix)
    require(all(row["xxh64"] == rows[-1]["report"]["content_xxh64"] for row in reference_rows["zstd-encode"]),
            "actual encoder streaming XXH64 disagrees with independent C")
    rows.append(invoke(args, "br-metadata", args.br_probe, {"operation": "metadata", "count": prefix + 1, "block_len": block}))
    reference_rows["br-metadata"] = old["reference_rows"]["br-metadata"] if old else verify_references(references, 1, 2, 0, generated("metadata", prefix + 1, block))
    tail_wire_path, tail_plain_path = args.output_dir / "br-copy-tail.bin", args.output_dir / "br-copy-tail-plain.bin"
    proof_path = args.output_dir / "br-copy-tail-normal-history-proof.bin"
    rows.append(invoke(args, "br-stored-copy", args.br_probe, {"operation": "stored_copy", "count": prefix, "block_len": block, "tail_wire_path": str(tail_wire_path), "tail_plain_path": str(tail_plain_path), "tail_proof_path": str(proof_path)}))
    tail_wire, tail_plain = tail_wire_path.read_bytes(), tail_plain_path.read_bytes()
    proof_receipts = verify_references(references, 1, 2, len(tail_plain) * 2, [proof_path.read_bytes()], prefix=0, tail=tail_plain * 2)
    require(all(row["output_written"] == 4096 for row in proof_receipts), "independent normal-history distance tail fixture")
    if old:
        require(sha(tail_wire) == old["br_copy_tail_sha256"], "cross-target copy-tail wire equality")
        reference_rows["br-stored-copy"] = old["reference_rows"]["br-stored-copy"]
    else: reference_rows["br-stored-copy"] = verify_references(references, 1, 2, prefix + len(tail_plain), generated("stored", prefix, block, tail_wire), prefix=prefix, tail=tail_plain)
    rows.append(invoke(args, "br-stored-subset", args.br_probe, {"operation": "stored", "count": prefix + 1, "block_len": block}))
    reference_rows["br-stored-subset"] = old["reference_rows"]["br-stored-subset"] if old else verify_references(references, 1, 2, prefix + 1, generated("stored", prefix + 1, block))
    sinks = [] if old else [ref.state(1, 2, prefix + 1) for ref in references]
    try:
        encoded = invoke(args, "br-encode", args.br_probe, {"operation": "encode", "count": prefix + 1, "wire_stdout": True}, sinks)
        rows.append(encoded)
        if old:
            require(encoded["wire_sha256"] == old["br_encoder_wire_sha256"], "cross-target actual large stored-encoder wire digest")
            reference_rows["br-encode"] = old["reference_rows"]["br-encode"]
        else: reference_rows["br-encode"] = [sink.finish() for sink in sinks]
    finally:
        for sink in sinks: sink.close()
    report = {"schema": "vort-stream-counters-real-v1", "status": "ok", "utc": datetime.now(timezone.utc).isoformat(), "long": args.long,
              "rows": rows, "reference_rows": reference_rows, "reference_provenance": [ref.provenance() for ref in references],
              "reference_reused_from": str(args.reuse_reference_report) if old else None, "rle_fixture_path": str(fixture_path), "rle_fixture_sha256": sha(fixture),
              "rle_checksum": checksum, "zstd_encoder_wire_sha256": sha(wire), "br_copy_tail_sha256": sha(tail_wire), "br_encoder_wire_sha256": encoded["wire_sha256"],
              "scope": "actual accepted/emitted bytes through public streaming APIs, bounded source/output buffers; no seed, sparse-file or declared-size substitute"}
    by_name = {row["name"]: row["report"] for row in rows}
    for policy in by_name["zstd-rle"]["policies"]:
        require(policy["progress"]["input_read"] == len(fixture) and policy["progress"]["output_written"] == prefix + 1,
                "actual wide RLE decoder progress")
    skip_frames = (prefix + 1 + (1 << 32) - 2) // ((1 << 32) - 1)
    for policy in by_name["zstd-skip"]["policies"]:
        require(policy["progress"]["input_read"] == prefix + 1 + skip_frames * 8 and policy["snapshot"]["skippable_total"] == prefix + 1,
                "actual wide skippable input progress")
    for consumer in by_name["br-metadata"]["consumers"]:
        require(consumer["metadata_total"] == prefix + 1 and consumer["progress"]["output_written"] == 0,
                "actual wide Brotli metadata progress")
    for consumer in by_name["br-stored-copy"]["consumers"]:
        require(consumer["progress"]["output_written"] == prefix + 2048 and consumer["last_copy_distance"] == 2048,
                "actual normal-history copy after generated prefix")
    for consumer in by_name["br-stored-subset"]["consumers"]:
        require(consumer["progress"]["output_written"] == prefix + 1, "actual stored subset output")
    require(by_name["zstd-encode"]["progress"]["input_read"] == prefix + 17 and by_name["br-encode"]["progress"]["input_read"] == prefix + 1,
            "actual generated encoder input counts")
    if args.long:
        require(by_name["br-encode"]["progress"]["output_written"] > 1 << 32, "stored encoder did not physically produce a wide wire")
        require(all(consumer["progress"]["input_read"] == (1 << 32) + 1028 for consumer in by_name["br-metadata"]["consumers"]),
                "audited wide metadata input overhead")
        require(all(consumer["progress"]["input_read"] == (1 << 32) + 1029 for consumer in by_name["br-stored-subset"]["consumers"]),
                "audited wide stored input overhead")
    report["reference_reused_report_sha256"] = sha(args.reuse_reference_report.read_bytes()) if old else None
    report["normal_history_copy_tail_fixture"] = {"wire_sha256": sha(proof_path.read_bytes()), "decoded_bytes": 4096, "distance": 2048, "reference_receipts": proof_receipts}
    report["source_pattern"] = {"size": len(PATTERN), "sha256": sha(PATTERN), "generator": "xorshift32 seed0x51a7c0de; fixed64KiB repeated by absolute phase"}
    path = args.output_dir / "report.json"; path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": "ok", "rows": len(rows), "long": args.long, "report": str(path)}))


if __name__ == "__main__": main()
