#!/usr/bin/env python3
"""Prepare an archived full-dictionary witness and an independent RAW control.

The RAW decoder loads exactly the same history with rawContent=1. Only ID-less
frames can prove initial entropy dependence: tagged RAW rejection is a normal
dictionary-ID mismatch and is explicitly excluded from the evidence counter.
"""
from __future__ import annotations

import argparse
import ctypes as C
import hashlib
import importlib.util
import json
from pathlib import Path
import re

_reference_path = Path(__file__).with_name("reference.py")
_reference_spec = importlib.util.spec_from_file_location("_entropy_witness_reference", _reference_path)
_reference = importlib.util.module_from_spec(_reference_spec)
_reference_spec.loader.exec_module(_reference)
Library = _reference.Library
frame_header, entropy_modes = _reference.frame_header, _reference.entropy_modes


class RawDecodeError(RuntimeError):
    """RAW control failed, with a stage distinguishing load from decode."""

    def __init__(self, stage: str, message: str):
        self.stage = stage
        super().__init__(f"{stage}: {message}")


class _Buffer(C.Structure):
    _fields_ = [("data", C.c_void_p), ("size", C.c_size_t), ("pos", C.c_size_t)]


def _hash(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _artifact(path: Path, data: bytes) -> dict:
    path.write_bytes(data)
    return {"path": str(path.resolve()), "size": len(data), "sha256": _hash(data)}


def decode_raw(wire: bytes, history: bytes, *, library: Library,
               format: str = "standard", input_chunk_size: int = 3) -> bytes:
    """Decode with a fresh, independently bound DCtx and forced RAW history.

    This function never invokes the full-dictionary loader. Dictionary-looking
    history is also forced RAW, so it cannot accidentally seed entropy tables.
    The library and parameter definitions come from the verified Library pair.
    """
    wire, history = bytes(wire), bytes(history)
    if not wire or input_chunk_size <= 0 or format not in ("standard", "magicless"):
        raise ValueError("Invalid RAW decoder input or format")
    header = library.header_path.read_text()
    raw = re.search(r"\bZSTD_dct_rawContent\s*=\s*(\d+)\b", header)
    if raw is None or int(raw.group(1)) != 1:
        raise RuntimeError("Matching header does not declare rawContent=1")
    lib = C.CDLL(str(library.path))
    # Drivers load reference.py under separate importlib module names. Derive
    # from the exact passed Library's error class so both its ZstdError handler
    # and this module's stage-aware RawDecodeError handler work correctly.
    error_base = library._check.__func__.__globals__["ZstdError"]
    bound_error = type("BoundRawDecodeError", (RawDecodeError, error_base), {})

    def bind(name, result, *arguments):
        function = getattr(lib, name)
        function.restype, function.argtypes = result, arguments
        return function

    ptr, size, integer = C.c_void_p, C.c_size_t, C.c_int
    create = bind("ZSTD_createDCtx", ptr)
    free = bind("ZSTD_freeDCtx", size, ptr)
    set_parameter = bind("ZSTD_DCtx_setParameter", size, ptr, integer, integer)
    load = bind("ZSTD_DCtx_loadDictionary_advanced", size, ptr, ptr, size, integer, integer)
    stream = bind("ZSTD_decompressStream", size, ptr, C.POINTER(_Buffer), C.POINTER(_Buffer))
    is_error = bind("ZSTD_isError", C.c_uint, size)
    error_name = bind("ZSTD_getErrorName", C.c_char_p, size)

    def check(result, stage):
        if is_error(result):
            raise bound_error(stage, error_name(result).decode())
        return result

    context = create()
    if not context:
        raise bound_error("create raw context", "allocation failed")
    try:
        format_value = library.parameters["ZSTD_f_zstd1_magicless" if format == "magicless" else "ZSTD_f_zstd1"]
        check(set_parameter(context, library.parameters["ZSTD_d_format"], format_value), "set raw format")
        check(load(context, history, len(history), library.parameters["ZSTD_dlm_byCopy"], 1), "load raw history")
        output = C.create_string_buffer(library.output_chunk_size)
        chunks, total, hint = [], 0, 1
        for start in range(0, len(wire), input_chunk_size):
            part = wire[start:start + input_chunk_size]
            source = C.create_string_buffer(part, len(part) + 1)
            input_ = _Buffer(C.addressof(source), len(part), 0)
            while True:
                before = input_.pos
                destination = _Buffer(C.addressof(output), library.output_chunk_size, 0)
                hint = check(stream(context, C.byref(destination), C.byref(input_)), "decode raw history")
                total += destination.pos
                if total > library.max_output_size:
                    raise bound_error("decode raw history", "output exceeds configured limit")
                if destination.pos:
                    chunks.append(output.raw[:destination.pos])
                if input_.pos == input_.size and (hint == 0 or destination.pos < library.output_chunk_size):
                    break
                if input_.pos == before and destination.pos == 0:
                    raise bound_error("decode raw history", "no progress")
        if hint != 0:
            raise bound_error("decode raw history", "incomplete or truncated input")
        return b"".join(chunks)
    finally:
        free(context)


def inspect_generated(wire: bytes, full_dictionary: bytes, library: Library | None = None,
                      *, format: str = "standard", payload: bytes | None = None) -> dict:
    """Inspect public-encoder output and compare FULL against same-history RAW.

    ``dictionary_entropy_used`` requires correct FULL output, a repeated table
    in the FIRST block, equal standard repcodes, an omitted ID, and failure (or
    changed output) AFTER the RAW history loaded successfully. ID mismatches
    are never counted as entropy evidence.
    """
    library = Library() if library is None else library
    wire, full_dictionary = bytes(wire), bytes(full_dictionary)
    header = frame_header(wire, format)
    blocks = entropy_modes(wire, format)
    first = blocks[0]
    header_size = library.dictionary_header_size(full_dictionary)
    history = full_dictionary[header_size:]
    repcodes = [int.from_bytes(full_dictionary[header_size - 12 + index * 4:header_size - 8 + index * 4], "little")
                for index in range(3)]
    decoded = library.decode(wire, full_dictionary, format=format, input_chunk_size=3)
    full = {"accepted": True, "size": len(decoded), "sha256": _hash(decoded),
            "equals_payload": payload is None or decoded == bytes(payload)}
    raw = {"dictionary_type": "raw_content", "dict_content_type": 1,
           "history_size": len(history), "history_sha256": _hash(history)}
    try:
        raw_output = decode_raw(wire, history, library=library, format=format)
        raw.update(accepted=True, load_succeeded=True, equals_full_output=raw_output == decoded,
                   size=len(raw_output), sha256=_hash(raw_output))
    except RawDecodeError as error:
        raw.update(accepted=False, load_succeeded=error.stage == "decode raw history",
                   stage=error.stage, error=str(error))
    repeated_huffman = first.get("literal_type") == 3
    repeated_fse = [name for name, mode in first.get("sequence_modes", {}).items() if mode == 3]
    changed_output = not raw["accepted"] or not raw.get("equals_full_output", False)
    omitted_id = header["dictionary_id_flag"] == 0
    raw_decode_failed = (not raw["accepted"] and raw.get("load_succeeded", False)
                         and "Dictionary mismatch" not in raw.get("error", "")
                         and "configured limit" not in raw.get("error", ""))
    proof = (omitted_id and full["equals_payload"] and repcodes == [1, 4, 8]
             and (repeated_huffman or bool(repeated_fse)) and changed_output
             and (raw["accepted"] or raw_decode_failed))
    return {"header": header, "first_block": first, "blocks": blocks,
            "dictionary_id": library.dictionary_id(full_dictionary),
            "dictionary_header_size": header_size, "dictionary_repcodes": repcodes,
            "raw_repcodes": [1, 4, 8], "first_block_repeated_huffman": repeated_huffman,
            "first_block_repeated_fse": repeated_fse, "full_dictionary": full, "raw_history": raw,
            "dictionary_entropy_used": bool(proof),
            "raw_rejection_is_id_mismatch": (not omitted_id and not raw["accepted"]),
            "tagged_raw_rejection_counts_as_entropy_proof": False}


def _omit_id(wire: bytes) -> bytes:
    header = frame_header(wire)
    id_offset = 5 + int(not header["single_segment"])
    size = header["dictionary_id_size"]
    result = bytearray(wire[:id_offset] + wire[id_offset + size:])
    result[4] &= 0xfc
    return bytes(result)


def _finalize_candidate(root, library, payload, history, dict_id) -> dict:
    # One bounded candidate; variations avoid the all-identical-samples failure.
    samples = [payload[index % 64:] + payload[:index % 64] + index.to_bytes(4, "little")
               for index in range(64)]
    receipt = {"api": "ZDICT_finalizeDictionary", "attempts": 1,
               "sample_recipe": "64 rotations of archived decoded payload with uint32 sample suffix",
               "sample_count": len(samples), "samples_sha256": _hash(b"".join(samples))}
    try:
        candidate = library.finalize_dictionary(samples, history, dict_id=dict_id, level=3)
        wire = library.encode(payload, candidate, include_id=False)
        receipt.update(available=True, dictionary=_artifact(root / "finalized-candidate.zdict", candidate),
                       wire=_artifact(root / "finalized-candidate-id0.zst", wire),
                       inspection=inspect_generated(wire, candidate, library, payload=payload))
    except RuntimeError as error:
        receipt.update(available=False, error=str(error))
    return receipt


def prepare(root: Path | str, library: Library) -> dict:
    """Prepare archive dictionary/payload paths, provenance, and RAW evidence."""
    root = Path(root).expanduser().resolve()
    root.mkdir(parents=True, exist_ok=True)
    repo = Path(__file__).resolve().parents[3]
    dictionary_source = repo / "src/zstd/testdata/libzstd-trained-repeat.dict.hex"
    frame_source = repo / "src/zstd/testdata/libzstd-trained-repeat.frame.hex"
    dictionary = bytes.fromhex(dictionary_source.read_text())
    frame = bytes.fromhex(frame_source.read_text())
    dictionary_id = library.dictionary_id(dictionary)
    if not dictionary_id:
        raise AssertionError("Archived dictionary does not have a positive standard dictionary ID")
    header_size = library.dictionary_header_size(dictionary)
    history = dictionary[header_size:]
    payload = library.decode(frame, dictionary, input_chunk_size=3)
    omitted = _omit_id(frame)
    archived_inspection = inspect_generated(omitted, dictionary, library, payload=payload)
    if not archived_inspection["dictionary_entropy_used"]:
        raise AssertionError("Archived ID-less witness did not prove initial entropy dependence")
    artifacts = {"dictionary": _artifact(root / "archived-full.zdict", dictionary),
                 "history": _artifact(root / "archived-history.bin", history),
                 "payload": _artifact(root / "archived-entropy.payload", payload),
                 "original_frame": _artifact(root / "archived-original.zst", frame),
                 "id_omitted_frame": _artifact(root / "archived-id0.zst", omitted)}
    receipt = {"schema": "vort.zstd.dictionary_id_control.entropy_witness.v1",
               "dictionary_path": artifacts["dictionary"]["path"],
               "history_path": artifacts["history"]["path"],
               "payload_path": artifacts["payload"]["path"], "dictionary_id": dictionary_id,
               "dictionary_header_size": header_size, "history_size": len(history), "payload_size": len(payload),
               "artifacts": artifacts, "reference": library.provenance(),
               "source_path": str(Path(__file__).resolve()), "source_sha256": _reference.sha256(Path(__file__).resolve()),
               "archived": {"description": "Repository libzstd-trained all-Repeat dictionary/frame fixture",
                            "dictionary_hex_path": str(dictionary_source),
                            "dictionary_hex_sha256": _reference.sha256(dictionary_source),
                            "frame_hex_path": str(frame_source), "frame_hex_sha256": _reference.sha256(frame_source),
                            "training_command": "Not retained in the archived fixture files",
                            "id_omitted_variant": "Only Dictionary_ID bytes removed and descriptor low bits cleared; block bytes unchanged",
                            "inspection": archived_inspection},
               "finalized_candidate": _finalize_candidate(root, library, payload, history, dictionary_id + 1)}
    receipt["receipt_path"] = str(root / "entropy-witness.json")
    (root / "entropy-witness.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n")
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--library", type=Path)
    parser.add_argument("--header", type=Path)
    args = parser.parse_args()
    receipt = prepare(args.output, Library(args.library, header=args.header))
    print(json.dumps({"receipt_path": receipt["receipt_path"], "dictionary_path": receipt["dictionary_path"],
                      "payload_path": receipt["payload_path"], "dictionary_id": receipt["dictionary_id"],
                      "archived_entropy_proof": receipt["archived"]["inspection"]["dictionary_entropy_used"],
                      "candidate_available": receipt["finalized_candidate"]["available"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
