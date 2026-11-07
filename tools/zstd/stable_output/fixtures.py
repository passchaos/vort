#!/usr/bin/env python3
"""Frozen sequence fixture plus independently C-produced stable-output frames."""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import struct

_path = Path(__file__).with_name("reference.py")
_spec = importlib.util.spec_from_file_location("_stable_output_fixture_reference", _path)
_reference = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_reference)
Library = _reference.Library


def artifact(path, data):
    path.write_bytes(data)
    return {"path": str(path.resolve()), "size": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def generate(root, library=None):
    root = Path(root).expanduser().resolve()
    root.mkdir(parents=True, exist_ok=True)
    library = Library() if library is None else library
    repo = Path(__file__).resolve().parents[3]
    archive_path = repo / "src/zstd/testdata/libzstd-numbered-json.frame.hex"
    archived_wire = bytes.fromhex(archive_path.read_text())
    payload = library.decode(archived_wire)
    large = payload * 112
    payloads = {"numbered-json": artifact(root / "numbered-json.payload", payload),
                "multi-block": artifact(root / "multi-block.payload", large),
                "empty": artifact(root / "empty.payload", b"")}
    cases = []

    def add(name, wire, data, payload_name, format="standard", producer="libzstd streaming C encoder", frozen=None, dictionary=None, dictionary_path=None):
        frames = _reference.inspect_stream(wire, format)
        data_frames = [frame for frame in frames if not frame["skippable"]]
        proof = {"compressed_blocks": sum(block["block_type"] == 2 for frame in data_frames for block in frame["blocks"]),
                 "sequence_count": sum(frame["sequence_count"] for frame in data_frames),
                 "data_frames": len(data_frames), "skippable_frames": len(frames) - len(data_frames)}
        if data and not proof["sequence_count"]:
            raise AssertionError("Nonempty fixture has no actual compressed sequences: " + name)
        decoded, stable = library.decode_stable(wire, len(data), format=format, input_chunk_size=3, dictionary=dictionary)
        if decoded != data:
            raise AssertionError("C stable decoder did not reproduce " + name)
        ordinary = library.observe(wire, len(data), format=format, stable=False, input_chunk_size=7, dictionary=dictionary)
        if ordinary["error"] or ordinary["output_sha256"] != hashlib.sha256(data).hexdigest():
            raise AssertionError("C buffered decoder disagreed on " + name)
        known = all(frame["header"]["content_size"] is not None for frame in data_frames)
        checksum = any(frame["header"]["checksum"] for frame in data_frames)
        preflight = {"exact_full_stable": stable, "buffered_output": ordinary}
        if len(data_frames) == 1 and checksum:
            footer = library.observe(wire, len(data), format=format, chunks=[len(wire) - 4, 0, 4], dictionary=dictionary)
            if (footer["error"] or footer["output_sha256"] != stable["output_sha256"] or
                    footer["calls"][-1]["input_read"] != 4 or footer["calls"][-1]["output_available_before"] != 0):
                raise AssertionError("Exact-full checksum footer could not complete: " + name)
            preflight["full_output_zero_quantum_footer"] = footer
        if data:
            small = library.observe(wire, len(data) - 1, format=format, input_chunk_size=5, dictionary=dictionary)
            if small["error"] is None:
                raise AssertionError("Undersized stable destination accepted " + name)
            preflight["short_destination"] = small
        wire_artifact = artifact(root / (name + ".zst"), wire)
        cases.append({"name": name, "payload_path": payloads[payload_name]["path"],
                      "wire_path": wire_artifact["path"], "payload": payloads[payload_name], "wire": wire_artifact,
                      "format": format, "known_size": known, "checksum": checksum,
                      "dictionary_path": dictionary_path,
                      "header": data_frames[0]["header"], "frames": frames, "sequences": proof,
                      "producer": producer, "frozen": frozen, "preflight": preflight})

    add("frozen-numbered-json", archived_wire, payload, "numbered-json", producer="Archived independent libzstd frame",
        frozen={"hex_path": str(archive_path), "hex_sha256": _reference.sha256(archive_path),
                "recipe": "Read fixed archived frame; independently decode exact payload"})
    produced = {}
    for known in (True, False):
        for checksum in (True, False):
            for format in ("standard", "magicless"):
                name = f"numbered-json-{'known' if known else 'unknown'}-{'crc' if checksum else 'no-crc'}-{format}"
                wire = library.encode(payload, known_size=known, checksum=checksum, format=format, input_chunk_size=31)
                produced[(known, checksum, format)] = wire
                add(name, wire, payload, "numbered-json", format)
    for known in (True, False):
        wire = library.encode(large, known_size=known, checksum=True, input_chunk_size=4093)
        add(f"multi-block-{'known' if known else 'unknown'}-crc-standard", wire, large, "multi-block")
    skip_body = b"vort stable-output skippable witness"
    skippable = struct.pack("<II", 0x184d2a50, len(skip_body)) + skip_body
    stream = skippable + produced[(True, True, "standard")] + skippable + produced[(False, True, "standard")]
    combined = payload * 2
    payloads["concatenated"] = artifact(root / "concatenated.payload", combined)
    add("concatenated-skippable-standard", stream, combined, "concatenated")
    empty_wire = library.encode(b"", known_size=True, checksum=True)
    add("empty-crc-standard", empty_wire, b"", "empty")
    dictionary_hex = repo / "src/zstd/testdata/libzstd-trained-repeat.dict.hex"
    dictionary_frame_hex = repo / "src/zstd/testdata/libzstd-trained-repeat.frame.hex"
    dictionary = bytes.fromhex(dictionary_hex.read_text())
    dictionary_artifact = artifact(root / "full-dictionary.zdict", dictionary)
    dictionary_wire = bytes.fromhex(dictionary_frame_hex.read_text())
    dictionary_payload = library.decode(dictionary_wire, dictionary=dictionary)
    payloads["full-dictionary"] = artifact(root / "full-dictionary.payload", dictionary_payload)
    add("frozen-full-dictionary", dictionary_wire, dictionary_payload, "full-dictionary",
        producer="Archived independent libzstd full-dictionary frame", dictionary=dictionary,
        dictionary_path=dictionary_artifact["path"],
        frozen={"hex_path": str(dictionary_frame_hex), "hex_sha256": _reference.sha256(dictionary_frame_hex),
                "dictionary_hex_path": str(dictionary_hex), "dictionary_hex_sha256": _reference.sha256(dictionary_hex)})
    # Start with only three magic bytes so every mutation occurs while a frame
    # is active rather than at the next-frame boundary, where C permits rebinding.
    mutation_wire = produced[(True, True, "standard")]
    mutations = {kind: library.observe(mutation_wire, len(payload), input_chunk_size=3, mutation=kind)
                 for kind in ("dst", "size", "pos")}
    if any(value["error"] != "Destination buffer is wrong" for value in mutations.values()):
        raise AssertionError("Stable caller-buffer mutation preflight disagreed")
    negative = {}
    corrupt = bytearray(mutation_wire)
    corrupt[-1] ^= 0x80
    negative["corrupt_checksum"] = {"wire": artifact(root / "corrupt-checksum.zst", bytes(corrupt)),
                                    "observation": library.observe(corrupt, len(payload)),
                                    "ignore_checksum_observation": library.observe(corrupt, len(payload), ignore_checksum=True)}
    negative["truncated_footer"] = {"wire": artifact(root / "truncated-footer.zst", mutation_wire[:-1]),
                                    "observation": library.observe(mutation_wire[:-1], len(payload)),
                                    "ignore_checksum_observation": library.observe(mutation_wire[:-1], len(payload), ignore_checksum=True)}
    if any(value["observation"]["error"] is None for value in negative.values()):
        raise AssertionError("Malformed-frame preflight accepted corruption")
    if (negative["corrupt_checksum"]["ignore_checksum_observation"]["error"] is not None or
            negative["corrupt_checksum"]["ignore_checksum_observation"]["output_sha256"] != hashlib.sha256(payload).hexdigest() or
            negative["truncated_footer"]["ignore_checksum_observation"]["error"] is None):
        raise AssertionError("Ignoring checksum must preserve complete-footer requirements")
    receipt = {"schema": "vort.zstd.stable_output.fixtures.v1", "reference": library.provenance(),
               "source_path": str(Path(__file__).resolve()), "source_sha256": _reference.sha256(Path(__file__)),
               "payloads": payloads, "dictionary": dictionary_artifact, "cases": cases, "mutations": mutations, "negative": negative,
               "counters": {"cases": len(cases), "actual_sequence_count": sum(case["sequences"]["sequence_count"] for case in cases),
                            "exact_full_decodes": len(cases), "known_fcs": sum(case["known_size"] for case in cases),
                            "unknown_fcs": sum(not case["known_size"] for case in cases),
                            "zero_output_checksum_footer_cases": sum("full_output_zero_quantum_footer" in case["preflight"] for case in cases),
                            "buffer_identity_refusals": len(mutations), "malformed_refusals": len(negative),
                            "ignore_checksum_decodes": 1, "ignore_checksum_truncated_refusals": 1}}
    receipt["receipt_path"] = str(root / "receipt.json")
    (root / "receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n")
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--library", type=Path)
    parser.add_argument("--header", type=Path)
    args = parser.parse_args()
    receipt = generate(args.output, Library(args.library, header=args.header))
    print(json.dumps({"receipt_path": receipt["receipt_path"], "reference": receipt["reference"], "counters": receipt["counters"]}, sort_keys=True))


if __name__ == "__main__":
    main()
