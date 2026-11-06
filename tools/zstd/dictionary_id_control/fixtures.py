#!/usr/bin/env python3
"""Generate fixed complete dictionaries and libzstd dictIDFlag control frames.

Usage: fixtures.py OUTPUT_DIRECTORY [--library PATH] [--header PATH]
The receipt includes C encoder controls, independent header inspection,
dictionary entropy/history evidence and hashes of every generated artifact.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

_reference_path = Path(__file__).with_name("reference.py")
_reference_spec = importlib.util.spec_from_file_location("_dictionary_control_reference", _reference_path)
_reference = importlib.util.module_from_spec(_reference_spec)
_reference_spec.loader.exec_module(_reference)
Library, ZstdError = _reference.Library, _reference.ZstdError
frame_header, entropy_modes = _reference.frame_header, _reference.entropy_modes

DICTIONARY_ID = 1180675969
CODEC_LIST = ("zstd_standard", "zstd_magicless")
SAMPLE_RECIPE = "sha256 counter bytes mapped into fixed weighted alphabet v1"
SAMPLE_COUNT = 128
SAMPLE_PREFIX_SIZE = 512
HISTORY_SIZE = 2048
HISTORY_MATCH_OFFSET = 960
HISTORY_MATCH_SIZE = 552
ALPHABET = b"eeeeeeeeeeeeeeeeeeeeeettthhhhiiiisssaaaannnnn0123456789{}:,"


def _bytes(label: bytes, size: int) -> bytes:
    return b"".join(hashlib.sha256(label + index.to_bytes(4, "little")).digest()
                    for index in range((size + 31) // 32))[:size]


def fixed_samples() -> tuple[list[bytes], bytes]:
    """Return byte-stable samples and incompressible custom match history."""
    history = _bytes(b"vort dict-id control history v1", HISTORY_SIZE)
    samples = []
    for index in range(SAMPLE_COUNT):
        source = _bytes(b"vort dict-id control sample v1" + index.to_bytes(4, "little"),
                        SAMPLE_PREFIX_SIZE)
        prefix = bytes(ALPHABET[value % len(ALPHABET)] for value in source)
        offset = (index * 11) % 1300
        samples.append(prefix + history[offset:offset + 96])
    return samples, history


def _artifact(path: Path, data: bytes) -> dict:
    path.write_bytes(data)
    return {"path": str(path.resolve()), "size": len(data),
            "sha256": hashlib.sha256(data).hexdigest()}


def _outcome(library: Library, wire: bytes, dictionary: bytes | None, payload: bytes,
             format: str) -> dict:
    # Callers may load reference.py under a different isolated module name.
    # Catch the passed Library's exact libzstd error class in that case.
    reference_error = library._check.__func__.__globals__["ZstdError"]
    try:
        decoded = library.decode(wire, dictionary, format=format, input_chunk_size=3)
    except reference_error as error:
        return {"accepted": False, "error": str(error)}
    return {"accepted": True, "equals_payload": decoded == payload,
            "size": len(decoded), "sha256": hashlib.sha256(decoded).hexdigest()}


def _must_change(outcome: dict, label: str) -> None:
    if outcome["accepted"] and outcome["equals_payload"]:
        raise AssertionError(f"Fixture did not require the correct dictionary {label}")


def generate(root: Path | str, library: Library | None = None) -> dict:
    """Write dictionary, two small payloads, 24 control frames and receipt.json.

    ``cases`` is a plain list of dictionaries with name, codec, format,
    include_id, streaming, known_size, payload_path, wire_path and
    dictionary_path. Drivers can also use the corresponding artifact records.
    All paths are absolute. The generated directory can be a TemporaryDirectory.
    """
    root = Path(root).expanduser().resolve()
    root.mkdir(parents=True, exist_ok=True)
    library = Library() if library is None else library
    samples, history = fixed_samples()
    dictionary = library.finalize_dictionary(samples, history, dict_id=DICTIONARY_ID)
    dictionary_header_size = library.dictionary_header_size(dictionary)
    if library.dictionary_id(dictionary) <= 0:
        raise AssertionError("Reference dictionary has no positive ID")

    # Keep ID and all entropy bytes identical; only the matched history changes.
    wrong_history = bytearray(dictionary)
    for index in range(HISTORY_MATCH_OFFSET, HISTORY_MATCH_OFFSET + HISTORY_MATCH_SIZE):
        wrong_history[dictionary_header_size + index] ^= 0x40
    wrong_history = bytes(wrong_history)
    if wrong_history[:dictionary_header_size] != dictionary[:dictionary_header_size]:
        raise AssertionError("History mutation altered the dictionary header")

    # This is a second VALID full dictionary, with the same ID and exact history,
    # trained on changed statistics. Rejection cannot be attributed to a corrupt
    # dictionary header or ID mismatch.
    translation = bytes.maketrans(b"ethi", b"zqxw")
    alternative_samples = [sample[:SAMPLE_PREFIX_SIZE].translate(translation) + sample[SAMPLE_PREFIX_SIZE:]
                           for sample in samples]
    wrong_entropy = library.finalize_dictionary(alternative_samples, history, dict_id=DICTIONARY_ID)
    alternative_header_size = library.dictionary_header_size(wrong_entropy)
    if wrong_entropy[alternative_header_size:] != dictionary[dictionary_header_size:]:
        raise AssertionError("Entropy alternative altered dictionary history")
    if wrong_entropy[8:alternative_header_size - 12] == dictionary[8:dictionary_header_size - 12]:
        raise AssertionError("Entropy alternative did not alter entropy tables")
    if library.dictionary_id(wrong_entropy) != DICTIONARY_ID or library.dictionary_id(wrong_history) != DICTIONARY_ID:
        raise AssertionError("Alternative dictionaries changed the ID")

    artifacts = {
        "dictionary": _artifact(root / "complete.zdict", dictionary),
        "history": _artifact(root / "history.bin", history),
        "wrong_history_dictionary": _artifact(root / "same-id-wrong-history.zdict", wrong_history),
        "wrong_entropy_dictionary": _artifact(root / "same-id-wrong-entropy.zdict", wrong_entropy),
        "samples": _artifact(root / "training.samples", b"".join(samples)),
    }
    sizes = (json.dumps([len(sample) for sample in samples], separators=(",", ":")) + "\n").encode()
    artifacts["sample_sizes"] = _artifact(root / "training-sizes.json", sizes)
    matching_history = history[HISTORY_MATCH_OFFSET:HISTORY_MATCH_OFFSET + HISTORY_MATCH_SIZE]
    payloads = {"history": matching_history, "entropy-history": samples[71][:SAMPLE_PREFIX_SIZE] + matching_history}
    payload_artifacts = {name: _artifact(root / f"{name}.payload", payload) for name, payload in payloads.items()}
    cases = []
    for payload_name, payload in payloads.items():
        for api, streaming, known_size in (("one-shot", False, True),
                                           ("stream-known", True, True),
                                           ("stream-unknown", True, False)):
            for include_id in (False, True):
                for format in ("standard", "magicless"):
                    name = f"{payload_name}-{api}-id{int(include_id)}-{format}"
                    wire = library.encode(payload, dictionary, include_id, format=format,
                                          streaming=streaming, known_size=known_size)
                    header = frame_header(wire, format)
                    modes = entropy_modes(wire, format)
                    wire_artifact = _artifact(root / f"{name}.zst", wire)
                    with_dictionary = _outcome(library, wire, dictionary, payload, format)
                    without_dictionary = _outcome(library, wire, None, payload, format)
                    changed_history = _outcome(library, wire, wrong_history, payload, format)
                    changed_entropy = _outcome(library, wire, wrong_entropy, payload, format)
                    if not with_dictionary.get("equals_payload"):
                        raise AssertionError(f"Reference did not decode {name} with the correct dictionary")
                    _must_change(without_dictionary, "presence")
                    _must_change(changed_history, "history")
                    if payload_name == "entropy-history":
                        first = modes[0]
                        if first.get("literal_type") != 3:
                            raise AssertionError(f"{name} did not reuse dictionary Huffman tables in its first block")
                        if first.get("sequence_modes") != {"literal_length": 3, "offset": 3, "match_length": 3}:
                            raise AssertionError(f"{name} did not reuse dictionary FSE tables in its first block")
                        _must_change(changed_entropy, "entropy tables")
                    cases.append({"name": name, "payload_name": payload_name,
                                  "codec": "zstd_" + format, "format": format,
                                  "include_id": include_id, "streaming": streaming, "known_size": known_size,
                                  "dictionary_path": artifacts["dictionary"]["path"],
                                  "payload_path": payload_artifacts[payload_name]["path"],
                                  "wire_path": wire_artifact["path"],
                                  "payload": payload_artifacts[payload_name], "wire": wire_artifact,
                                  "header": header, "blocks": modes,
                                  "with_dictionary": with_dictionary, "without_dictionary": without_dictionary,
                                  "changed_history": changed_history, "changed_entropy": changed_entropy})

    receipt = {"schema": "vort.zstd.dictionary_id_control.fixtures.v1", "root": str(root),
               "codec_list": list(CODEC_LIST), "reference": library.provenance(),
               "fixtures_source_path": str(Path(__file__).resolve()),
               "fixtures_source_sha256": _reference.sha256(Path(__file__).resolve()),
               "producer": {"api": "ZDICT_finalizeDictionary", "recipe": SAMPLE_RECIPE,
                            "dict_id": DICTIONARY_ID, "sample_count": len(samples),
                            "sample_total_size": sum(map(len, samples)), "level": 3,
                            "dictionary_size": len(dictionary), "dictionary_header_size": dictionary_header_size,
                            "history_size": len(history), "history_match_offset": HISTORY_MATCH_OFFSET,
                            "history_match_size": HISTORY_MATCH_SIZE,
                            "alternative_entropy_header_size": alternative_header_size},
               "artifacts": artifacts, "payloads": payload_artifacts, "cases": cases,
               "counters": {"cases": len(cases), "full_dictionary_loads": True,
                            "header_id_checks": len(cases),
                            "known_streams": sum(case["streaming"] and case["known_size"] for case in cases),
                            "unknown_streams": sum(case["streaming"] and not case["known_size"] for case in cases),
                            "without_dictionary_rejections": sum(not case["without_dictionary"]["accepted"] for case in cases),
                            "same_id_history_rejections": sum(not case["changed_history"]["accepted"] for case in cases),
                            "first_block_huffman_and_fse_repeats": sum(case["payload_name"] == "entropy-history" for case in cases),
                            "same_id_entropy_rejections": sum(not case["changed_entropy"]["accepted"] for case in cases)}}
    receipt["receipt_path"] = str(root / "receipt.json")
    (root / "receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n")
    return receipt


def verify_vort_wire(library: Library, wire: bytes, dictionary: bytes, payload: bytes, *,
                     include_id: bool, format: str = "standard") -> dict:
    """Check a future Vort encoder's frame against the independent C decoder."""
    header = frame_header(wire, format)
    expected = library.dictionary_id(dictionary) if include_id else 0
    if header["dictionary_id"] != expected or (not include_id and header["dictionary_id_flag"] != 0):
        raise AssertionError("Vort frame dictionary ID disagrees with include_dictionary_id")
    decoded = library.decode(wire, dictionary, format=format, input_chunk_size=3)
    if decoded != payload:
        raise AssertionError("libzstd did not reproduce the Vort payload with the complete dictionary")
    return {"header": header, "decoded_size": len(decoded),
            "decoded_sha256": hashlib.sha256(decoded).hexdigest()}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--library", type=Path)
    parser.add_argument("--header", type=Path)
    args = parser.parse_args()
    receipt = generate(args.output, Library(args.library, header=args.header))
    print(json.dumps({"receipt_path": receipt["receipt_path"], "reference": receipt["reference"],
                      "producer": receipt["producer"], "counters": receipt["counters"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
