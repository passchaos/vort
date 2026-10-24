#!/usr/bin/env python3
"""Bounded large-LZMA2 chunk checks against the modern liblzma ABI.

The envelope reader interprets wire lengths and reset controls independently;
liblzma checks the actual decoded bytes. Large dictionary headers are submitted
unchanged to a memory-limited reference decoder, never to a smaller dictionary.
"""
import argparse
import binascii
import ctypes as C
from datetime import datetime, timezone
import json
from pathlib import Path
import random
import subprocess
import sys

sys.dont_write_bytecode = True
from encode_controls_diff import Controls, Reference, ROOT, bind, digest, require

CHECKPOINT = "a549b7a2"
MAX_CHUNK = 2 * 1024 * 1024
MAX_DICTIONARY = 1610612736


class LargeReference(Reference):
    def __init__(self, path):
        super().__init__(path)
        self.property_fn = bind(self.lib, "lbr_dictionary_property", C.c_int, C.POINTER(Controls),
                                C.POINTER(C.c_uint8), C.POINTER(C.c_uint64))
        self.budget_fn = bind(self.lib, "lbr_decode_budgeted", C.c_int, C.c_uint32, C.c_uint64,
                              C.c_void_p, C.c_size_t, C.c_void_p, C.c_size_t,
                              C.POINTER(C.c_size_t), C.POINTER(C.c_size_t), C.POINTER(C.c_uint64))
        self.status_fn = bind(self.lib, "lbr_status_name", C.c_char_p, C.c_uint32)
        self.property_size_fn = bind(self.lib, "lbr_dictionary_size_from_property", C.c_int,
                                     C.c_uint8, C.POINTER(C.c_uint32))
        library = bind(self.lib, "lbr_runtime_library_path", C.c_char_p)()
        require(library, "actual reference runtime library path")
        self.runtime_path = Path(library.decode()).resolve()

    def property(self, dictionary):
        options = self.options({"dictionary_size": dictionary})
        property, memory = C.c_uint8(), C.c_uint64()
        require(self.property_fn(C.byref(options), C.byref(property), C.byref(memory)) == 0,
                ("reference dictionary property", dictionary))
        size = C.c_uint32()
        require(self.property_size_fn(property.value, C.byref(size)) == 0, "reference property decoder")
        return property.value, memory.value, size.value

    def budgeted(self, wire, payload, format, budget):
        output = C.create_string_buffer(b"\xa5" * (len(payload) + 18))
        consumed, written, memory = C.c_size_t(), C.c_size_t(), C.c_uint64()
        status = self.budget_fn(format, budget, wire, len(wire), C.byref(output, 8), len(payload) + 1,
                                C.byref(consumed), C.byref(written), C.byref(memory))
        require(output.raw[:8] == b"\xa5" * 8 and output.raw[len(payload) + 9:len(payload) + 17] == b"\xa5" * 8,
                "budgeted reference output guards")
        if status == 0:
            require(consumed.value == len(wire) and written.value == len(payload)
                    and output.raw[8:8 + len(payload)] == payload, "budgeted original-container bytes")
        return {"status": self.status_fn(status).decode(), "memory_limit": budget,
                "memory_needed": memory.value, "input_read": consumed.value, "output_written": written.value}


def lzma2_envelope(data, offset=0, exact=True):
    start, total, rows = offset, 0, []
    dictionary_ready = properties_ready = False
    state_reset_required = True
    while True:
        require(offset < len(data), "truncated LZMA2 control")
        chunk_offset, control = offset, data[offset]
        offset += 1
        if control == 0:
            if exact:
                require(offset == len(data), "LZMA2 trailing bytes")
            return {"bytes": offset - start, "output_bytes": total, "chunks": rows}, offset
        require(control in (1, 2) or control >= 0x80, ("reserved LZMA2 control", control))
        compressed = control >= 0x80
        header_bytes = 4 if compressed else 2
        require(offset + header_bytes <= len(data), "truncated LZMA2 lengths")
        plain_size = int.from_bytes(data[offset:offset + 2], "big") + 1
        if compressed:
            plain_size += (control & 0x1f) << 16
            wire_size = int.from_bytes(data[offset + 2:offset + 4], "big") + 1
            require(plain_size <= MAX_CHUNK and wire_size <= 65536, "compressed 21/16-bit lengths")
            dictionary_reset, properties_reset, state_reset = control >= 0xe0, control >= 0xc0, control >= 0xa0
            if dictionary_reset:
                dictionary_ready = True
            require(dictionary_ready, "compressed chunk before dictionary reset")
            require(properties_ready or properties_reset, "compressed chunk before properties")
            require(not state_reset_required or state_reset, "compressed state not reset after stored data")
            offset += 4
            if properties_reset:
                require(offset < len(data) and data[offset] <= 224, "invalid LZMA properties")
                offset += 1
                properties_ready = True
            state_reset_required = False
        else:
            wire_size = plain_size
            require(plain_size <= 65536, "stored 16-bit length")
            dictionary_reset, properties_reset, state_reset = control == 1, False, False
            if dictionary_reset:
                dictionary_ready = True
            require(dictionary_ready, "stored chunk before dictionary reset")
            state_reset_required = True
            offset += 2
        require(offset + wire_size <= len(data), "truncated LZMA2 payload")
        rows.append({"offset": chunk_offset, "control": control, "compressed": compressed,
                     "output_bytes": plain_size, "payload_bytes": wire_size,
                     "dictionary_reset": dictionary_reset, "properties_reset": properties_reset,
                     "state_reset": state_reset})
        total += plain_size
        offset += wire_size


def vli(data, offset, limit):
    value = 0
    for index in range(9):
        require(offset < limit, "truncated XZ VLI")
        byte = data[offset]
        offset += 1
        value |= (byte & 127) << (7 * index)
        if byte < 128:
            require(index == 0 or byte != 0, "noncanonical XZ VLI")
            return value, offset
    raise AssertionError("oversized XZ VLI")


def envelope(wire, format):
    if format == "raw2":
        parsed, _ = lzma2_envelope(wire)
        return {"blocks": [parsed], "output_bytes": parsed["output_bytes"]}
    require(wire[:6] == b"\xfd7zXZ\x00" and len(wire) >= 24, "XZ stream header")
    require(wire[6] == 0 and wire[7] in (0, 1, 4, 10), "XZ supported stream flags")
    require(binascii.crc32(wire[6:8]) == int.from_bytes(wire[8:12], "little"), "XZ header CRC")
    check_size = {0: 0, 1: 4, 4: 8, 10: 32}[wire[7]]
    offset, blocks = 12, []
    while wire[offset] != 0:
        size = (wire[offset] + 1) * 4
        end = offset + size
        require(end <= len(wire) and size >= 8, "truncated XZ block header")
        require(binascii.crc32(wire[offset:end - 4]) == int.from_bytes(wire[end - 4:end], "little"), "XZ block header CRC")
        flags, cursor = wire[offset + 1], offset + 2
        require(flags & 0x3c == 0, "XZ reserved block flags")
        for flag in (0x40, 0x80):
            if flags & flag:
                _, cursor = vli(wire, cursor, end - 4)
        filters = []
        for _ in range((flags & 3) + 1):
            id, cursor = vli(wire, cursor, end - 4)
            properties_size, cursor = vli(wire, cursor, end - 4)
            require(cursor + properties_size <= end - 4, "XZ filter properties length")
            filters.append((id, wire[cursor:cursor + properties_size]))
            cursor += properties_size
        require(filters[-1][0] == 0x21 and len(filters[-1][1]) == 1, "XZ LZMA2 filter")
        require(not any(wire[cursor:end - 4]), "XZ block header padding")
        parsed, payload_end = lzma2_envelope(wire, end, exact=False)
        parsed["dictionary_property"] = filters[-1][1][0]
        padding = (-parsed["bytes"]) % 4
        require(not any(wire[payload_end:payload_end + padding]), "XZ block padding")
        offset = payload_end + padding + check_size
        require(offset < len(wire) - 12, "XZ block check/index boundary")
        blocks.append(parsed)
    require(wire[-2:] == b"YZ", "XZ footer")
    return {"blocks": blocks, "output_bytes": sum(block["output_bytes"] for block in blocks)}


def parser_self_test():
    stored = b"\x01\xff\xff" + b"S" * 65536 + b"\x00"
    require(lzma2_envelope(stored)[0]["output_bytes"] == 65536, "stored maximum envelope")
    # This synthetic payload tests the envelope only; it is not an LZMA stream.
    compressed = b"\xff\xff\xff\x00\x00\x5dZ\x00"
    require(lzma2_envelope(compressed)[0]["output_bytes"] == MAX_CHUNK, "compressed 21-bit maximum envelope")
    for invalid in (b"\x03", stored[:-1], compressed[:-2], b"\x80\x00\x00\x00\x00Z\x00"):
        try:
            lzma2_envelope(invalid)
        except AssertionError:
            continue
        raise AssertionError("invalid envelope accepted")


def probe_call(args, name, payload, config, expected_error=None):
    directory = args.output_dir
    source, output, settings = [directory / (name + suffix) for suffix in (".input", ".wire", ".json")]
    source.write_bytes(payload)
    output.write_bytes(b"unchanged output sentinel")
    settings.write_text(json.dumps(config) + "\n")
    result = subprocess.run([str(args.probe), str(source), str(output), str(settings)], cwd=ROOT,
                            capture_output=True, timeout=args.case_timeout)
    require(result.returncode == 0, (name, result.stderr.decode(errors="replace")))
    report = json.loads(result.stdout)
    require(report["error"] == expected_error, (name, config, report))
    if expected_error:
        require(output.read_bytes() == b"unchanged output sentinel", "failed operation changed output")
    return output.read_bytes(), report


def legacy_rows(args):
    if args.legacy_prepared is None:
        return None
    manifest_path = args.legacy_prepared / "legacy.json"
    manifest = json.loads(manifest_path.read_text())
    bridge_path = ROOT / "docs/performance/data/lzma-xz-encode-controls-functional-x86-20261024.json"
    bridge = json.loads(bridge_path.read_text())
    verified = {(row["input_sha256"], row["wire_sha256"], row["config"]["format"])
                for row in bridge["rows"] if row.get("legacy_wire_equal") is True}
    rows = []
    for index, row in enumerate(manifest["rows"]):
        payload = (args.legacy_prepared / row["input"]).read_bytes()
        expected = (args.legacy_prepared / row["wire"]).read_bytes()
        require(digest(payload) == row["input_sha256"] and digest(expected) == row["wire_sha256"], "frozen legacy hashes")
        require((digest(payload), digest(expected), row["config"]["format"]) in verified,
                "frozen legacy wire lacks checkpoint bridge evidence")
        if not args.prepare_only:
            actual, _ = probe_call(args, "legacy-" + str(index), payload, {**row["config"], "profile_enabled": False})
            require(actual == expected, ("default wire changed", row["case"], row["config"]))
        rows.append({"case": row["case"], "config": row["config"], "wire_sha256": digest(expected)})
    return {"checkpoint": CHECKPOINT, "oracle_revision": manifest.get("revision"),
            "manifest_sha256": digest(manifest_path.read_bytes()),
            "bridge_report": str(bridge_path.relative_to(ROOT)), "bridge_report_sha256": digest(bridge_path.read_bytes()),
            "bridge_legacy_equal_rows": len(verified), "rows": rows}


def campaign(args, reference):
    rng = random.Random(0x24a549b7)
    random_block = rng.randbytes(MAX_CHUNK)
    cases = [("compressed-2m", b"A" * MAX_CHUNK, 4096),
             ("compressed-2m-dict8m", b"abcdefgh" * (MAX_CHUNK // 8), 8 * 1024 * 1024),
             ("stored-2m", random_block, 4096),
             ("stored-then-reset", random_block + b"abcde" * 13107 + b"!", 4096)]
    rows = []
    for name, payload, dictionary in cases:
        for format in ("raw2", "xz"):
            config = {"format": format, "dictionary_size": dictionary, "chunk_size": MAX_CHUNK,
                      "block_size": len(payload), "input_chunk": 4093, "output_chunk": 8191}
            one_shot = None
            for operation in ("encode", "incremental"):
                wire, report = probe_call(args, name + "-" + format + "-" + operation, payload,
                                          {**config, "operation": operation})
                require(report["resolved"]["chunk_size"] == MAX_CHUNK, "resolved chunk_size")
                parsed = envelope(wire, format)
                require(parsed["output_bytes"] == len(payload), "envelope plaintext accounting")
                chunks = [chunk for block in parsed["blocks"] for chunk in block["chunks"]]
                if name.startswith("compressed"):
                    require(any(chunk["compressed"] and chunk["output_bytes"] == MAX_CHUNK for chunk in chunks),
                            "no actual 2 MiB compressed chunk")
                if name.startswith("stored"):
                    require(sum(not chunk["compressed"] for chunk in chunks) >= 32, "wide stored fallback was not split")
                if name == "stored-then-reset":
                    stored_before = False
                    transition = False
                    for chunk in chunks:
                        if not chunk["compressed"]:
                            stored_before = True
                        elif stored_before:
                            require(chunk["state_reset"], "next compressed chunk must reset after stored fallback")
                            transition = True
                    require(transition, "missing stored-to-compressed reset transition")
                reference.verify(wire, payload, format, config)
                if one_shot is None:
                    one_shot = wire
                    reference_wire = reference.encode(payload, format, config)
                    decoded, _ = probe_call(args, name + "-" + format + "-reference-decode", reference_wire,
                                             {**config, "operation": "decode", "expected_size": len(payload)})
                    require(decoded == payload, "Vort decoded reference bytes")
                else:
                    require(wire == one_shot, "one-shot/incremental wire differs")
                rows.append({"case": name, "format": format, "operation": operation,
                             "input_bytes": len(payload), "wire_sha256": digest(wire), "envelope": parsed})
    for chunk_size in (1, 65536, 65537, 1048576, MAX_CHUNK):
        for format in ("raw2", "xz"):
            payload = b"small boundary control" * 3
            wire, report = probe_call(args, "chunk-" + str(chunk_size) + "-" + format, payload,
                                      {"format": format, "chunk_size": chunk_size})
            require(report["resolved"]["chunk_size"] == chunk_size, "chunk setting not reported")
            reference.verify(wire, payload, format, {"dictionary_size": 4096})
            rows.append({"case": "chunk-control", "format": format, "chunk_size": chunk_size, "envelope": envelope(wire, format)})
    for chunk_size in (0, MAX_CHUNK + 1):
        for format in ("raw2", "xz"):
            probe_call(args, "invalid-chunk-" + str(chunk_size) + "-" + format, b"bad",
                       {"format": format, "chunk_size": chunk_size}, "InvalidBlockPlan")
    return rows


def dictionary_campaign(args, reference):
    rows = []
    for dictionary in (4096, 64 * 1024 * 1024 + 1, 96 * 1024 * 1024 + 1,
                       1024 * 1024 * 1024 + 1, MAX_DICTIONARY - 1, MAX_DICTIONARY):
        property, memory, decoded_dictionary = reference.property(dictionary)
        advertised = (2 | (property & 1)) << (property // 2 + 11)
        require(property <= 37 and advertised >= dictionary and advertised == decoded_dictionary, "large property rounding")
        row = {"dictionary_size": dictionary, "property": property, "advertised_dictionary_size": advertised,
               "reference_decoder_memory": memory}
        if not args.prepare_only:
            for format in ("raw2", "xz"):
                wire, report = probe_call(args, "property-" + str(dictionary) + "-" + format, b"property",
                                          {"format": format, "dictionary_size": dictionary, "chunk_size": MAX_CHUNK})
                require(report["resolved"]["dictionary_size"] == dictionary, "dictionary setting not reported")
                if format == "xz":
                    require(envelope(wire, format)["blocks"][0]["dictionary_property"] == property, "XZ large dictionary property")
                else:
                    decoded, _ = probe_call(args, "property-decode-" + str(dictionary), wire,
                                             {"format": "raw2", "operation": "decode", "dictionary_property": property,
                                              "expected_size": 8, "input_chunk": 3, "output_chunk": 5})
                    require(decoded == b"property", "large property raw decode")
            if dictionary in (64 * 1024 * 1024 + 1, MAX_DICTIONARY):
                payload = b"known64 " * 8
                wire, _ = probe_call(args, "alone-" + str(dictionary), payload,
                                     {"format": "alone", "dictionary_size": dictionary, "size_mode": "known"})
                require(int.from_bytes(wire[1:5], "little") == advertised, "Alone canonical dictionary advertisement")
                require(int.from_bytes(wire[5:13], "little") == len(payload), "Alone size was rewritten")
                limited = reference.budgeted(wire, payload, 5, 8 * 1024 * 1024)
                require(limited["status"] == "MEMLIMIT_ERROR", ("large Alone auto acceptance", limited))
                row["auto_limited"] = limited
                row["auto_limited_scope"] = "original-container header acceptance only; decoding stopped at memory limit"
                if dictionary == MAX_DICTIONARY and args.large_dictionary_budget >= limited["memory_needed"]:
                    full = reference.budgeted(wire, payload, 5, args.large_dictionary_budget)
                    require(full["status"] == "OK", ("budgeted large dictionary decode", full))
                    row["auto_full_decode"] = full
                else:
                    row["auto_full_decode"] = {"status": "NOT_RUN", "reason": "explicit budget below original-container decoder estimate"}
        rows.append(row)
    invalid = reference.budgeted(b"not a recognized container", b"", 5, 64 * 1024 * 1024)
    require(invalid["status"] == "FORMAT_ERROR", "FORMAT and MEMLIMIT must be distinguished")
    return rows, invalid


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--probe", type=Path)
    parser.add_argument("--legacy-prepared", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--case-timeout", type=int, default=120)
    parser.add_argument("--large-dictionary-budget", type=int, default=64 * 1024 * 1024,
                        help="explicit byte budget; full original maximum-dictionary decode runs only when sufficient")
    args = parser.parse_args()
    require(args.prepare_only or args.probe is not None, "--probe required for campaign")
    args.output_dir = args.output_dir.resolve()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    if args.probe:
        args.probe = args.probe.resolve()
    if args.legacy_prepared:
        args.legacy_prepared = args.legacy_prepared.resolve()
    parser_self_test()
    reference = LargeReference(args.reference)
    source_paths = [ROOT / "build.zig", ROOT / "build.zig.zon", ROOT / "src/root.zig", ROOT / "src/core.zig",
                    ROOT / "src/lzma.zig", ROOT / "src/xz.zig",
                    *sorted((ROOT / "src/lzma").rglob("*.zig")), *sorted((ROOT / "src/xz").rglob("*.zig")),
                    *sorted((ROOT / "tools/lzma").glob("encode_controls*")),
                    ROOT / "tools/lzma/large_blocks_reference.c", Path(__file__)]
    source_before = {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in source_paths if path.is_file()}
    baseline = legacy_rows(args)
    dictionaries, invalid = dictionary_campaign(args, reference)
    rows = [] if args.prepare_only else campaign(args, reference)
    source_after = {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in source_paths if path.is_file()}
    require(source_before == source_after, "source changed during large-block campaign")
    report = {"schema": "vort-lzma2-large-blocks-v1", "status": "prepared" if args.prepare_only else "ok",
              "utc": datetime.now(timezone.utc).isoformat(), "reference": {"version": reference.version,
              "header_version": reference.header_version, "runtime_version": reference.runtime_version,
              "helper_sha256": digest(reference.path.read_bytes()), "runtime_library": str(reference.runtime_path),
              "runtime_library_sha256": digest(reference.runtime_path.read_bytes())}, "baseline": baseline,
              "large_dictionary_budget": args.large_dictionary_budget, "dictionary_rows": dictionaries,
              "invalid_format_reference": invalid, "rows": rows,
              "source_sha256": source_before, "source_after_sha256": source_after,
              "probe_sha256": digest(args.probe.read_bytes()) if args.probe else None}
    destination = args.output_dir / "report.json"
    destination.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "rows": len(rows), "dictionary_rows": len(dictionaries),
                      "legacy_rows": len(baseline["rows"]) if baseline else 0, "report": str(destination)}))


if __name__ == "__main__":
    main()
