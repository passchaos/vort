"""Observe FULL entropy dependence using ID-less, same-history RAW decoding."""
from __future__ import annotations
import hashlib
import re


def _hash(data):
    return hashlib.sha256(data).hexdigest()


def _observe(library, wire, prefix, kind, payload, format):
    with library.context("D", format=format) as context:
        selected = context.ref_prefix(prefix, kind=kind)
        if selected["error"]:
            result, output, stage = selected, b"", "ref_prefix"
        else:
            result, output = context.drive_decode(wire)
            stage = "decode"
        return {"ref_prefix": {key: value for key, value in selected.items() if key != "snapshot"},
                "result": {key: value for key, value in result.items() if key != "snapshot"},
                "error_stage": stage, "accepted": not result.get("error") and not result.get("incomplete"),
                "equals_payload": output == payload, "output_size": len(output), "output_sha256": _hash(output)}


def observe(library, wire, dictionary, payload, format):
    header_size = library.dictionary_header_size(dictionary)
    history = dictionary[header_size:]
    full_reps = [int.from_bytes(dictionary[header_size - 12 + index * 4:header_size - 8 + index * 4], "little")
                 for index in range(3)]
    raw_reps = [1, 4, 8]
    rep_basis = {"kind": "Zstandard frame-format initial repeated offsets", "values": raw_reps,
                 "private_context_state_queried": False}
    local = library.header_path.parent / "common/zstd_internal.h"
    if local.is_file():
        declaration = re.search(r"repStartValue\s*\[\s*ZSTD_REP_NUM\s*\]\s*=\s*\{([^}]+)\}", local.read_text())
        if declaration:
            values = [int(value) for value in re.findall(r"\d+", declaration.group(1))]
            if values != raw_reps:
                raise RuntimeError("Matching local source does not use the expected RAW initial repcodes")
            rep_basis.update(source_path=str(local.resolve()), source_sha256=_hash(local.read_bytes()),
                             source_declaration=declaration.group(0))
    reset_source = library.header_path.parent / "decompress/zstd_decompress.c"
    if reset_source.is_file():
        rep_basis.update(reset_source_path=str(reset_source.resolve()), reset_source_sha256=_hash(reset_source.read_bytes()),
                         reset_declaration="ZSTD_memcpy(dctx->entropy.rep, repStartValue, sizeof(repStartValue))")
    original_header = library.inspect_header(wire, format)
    if not original_header.get("complete") or original_header.get("frame_type") != "data":
        raise RuntimeError("Entropy control requires a complete data frame header")
    descriptor_offset = 4 if format == "standard" else 0
    descriptor = wire[descriptor_offset]
    id_size = (0, 1, 2, 4)[descriptor & 3]
    id_offset = descriptor_offset + 1 + int(not bool(descriptor & 0x20))
    normalized = bytearray(wire[:id_offset] + wire[id_offset + id_size:])
    normalized[descriptor_offset] &= 0xfc
    normalized = bytes(normalized)
    normalized_header = library.inspect_header(normalized, format)
    normalization = {"method": "Only Dictionary_ID bytes removed and descriptor low bits cleared",
                     "original_wire_size": len(wire), "original_wire_sha256": _hash(wire),
                     "normalized_wire_size": len(normalized), "normalized_wire_sha256": _hash(normalized),
                     "removed_dictionary_id_size": id_size, "descriptor_dictionary_id_flag": normalized[descriptor_offset] & 3}
    full = _observe(library, normalized, dictionary, "full", payload, format)
    raw_type = library.parameters["ZSTD_dct_rawContent"]
    if raw_type != 1:
        raise RuntimeError("Matching header does not declare rawContent=1")
    raw = _observe(library, normalized, history, raw_type, payload, format)
    history_sha = _hash(history)
    raw.update(history_size=len(history), history_sha256=history_sha, prefix_content_type=raw_type)
    raw_error = raw["result"].get("error")
    raw_rejected = (raw["ref_prefix"]["ret"] == 0 and raw["ref_prefix"].get("error") is None
                    and raw["error_stage"] == "decode" and not raw["accepted"]
                    and raw_error in ("Data corruption detected", "Restored data doesn't match checksum"))
    dependency = (normalized_header.get("complete") is True and normalized_header.get("error") is None
                  and normalized_header.get("dictionary_id") == 0 and normalization["descriptor_dictionary_id_flag"] == 0
                  and full["accepted"] and full["equals_payload"] and full_reps == raw_reps and raw_rejected)
    return {"normalization": normalization, "original_header": original_header, "normalized_header": normalized_header,
            "normalized_full_prefix": full, "raw_same_history": raw, "history_size": len(history),
            "history_sha256": history_sha, "full_initial_repcodes": full_reps, "raw_initial_repcodes": raw_reps,
            "repcodes_equal": full_reps == raw_reps, "raw_repcodes_basis": rep_basis,
            "entropy_dependency": bool(dependency), "mode_inspection_used": False}
