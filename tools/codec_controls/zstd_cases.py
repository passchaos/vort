"""Bounded Zstd control fixtures independently checked with an existing libzstd."""
from __future__ import annotations

from dataclasses import dataclass
import hashlib
from pathlib import Path
import random

try:
    from .zstd_reference import Library, MAGIC
except ImportError:
    from zstd_reference import Library, MAGIC


PUBLIC_APIS = (
    "alloc", "into", "append", "reuse_alloc", "reuse_into", "reuse_append",
    "reuse_scratch", "incremental_block", "incremental_direct", "incremental_prevalidated",
)
CONTEXT_APIS = ("alloc", "into", "reuse_scratch", "incremental_block", "incremental_prevalidated")
VARIANTS = (
    ("valid", False, None),
    ("bad_crc_strict", False, "ChecksumMismatch"),
    ("bad_crc_ignore", True, None),
    ("truncated_footer_ignore", True, "TruncatedFrame"),
)


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def _digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


@dataclass(frozen=True)
class _Fixture:
    name: str
    payload: bytes
    frames: tuple[bytes, ...]
    dictionary: bytes | None = None
    magicless: bool = False

    @property
    def wire(self) -> bytes:
        return b"".join(frame[4:] if self.magicless else frame for frame in self.frames)


def _fixtures(library: Library) -> tuple[_Fixture, ...]:
    # The repeated records demand sequence copies rather than only literal
    # entropy coding. The raw history prefix also forces external references.
    record = b'{"service":"codec-controls","kind":"zstd-sequence","status":"verified"}\n'
    prefix = bytes(range(32, 127)) * 4
    payload = prefix + record * 32 + prefix + record * 8
    dictionary = random.Random(0x1002).randbytes(4096)
    dictionary_payload = dictionary[-1024:] + record * 24 + dictionary[-1024:]
    second = prefix[::-1] + record.replace(b"verified", b"second-frame") * 20 + prefix[::-1]
    frame = library.encode(payload)
    dictionary_frame = library.encode(dictionary_payload, dictionary)
    second_frame = library.encode(second)
    for name, content, encoded in (("standard", payload, frame),
                                   ("raw_dictionary", dictionary_payload, dictionary_frame),
                                   ("concat_second", second, second_frame)):
        _require(encoded.startswith(MAGIC) and encoded[4] & 4, f"{name}: checksum frame required")
        _require(len(encoded) * 3 < len(content), f"{name}: sequence-rich compression required")
    # A successful dictionary-free decode would fail to exercise raw history.
    for api in ("streaming", "one_shot"):
        library.expect_error(dictionary_frame, api=api)
    return (
        _Fixture("standard", payload, (frame,)),
        _Fixture("magicless", payload, (frame,), magicless=True),
        _Fixture("raw_dictionary", dictionary_payload, (dictionary_frame,), dictionary=dictionary),
        _Fixture("concat_two_frames", payload + second, (frame, second_frame)),
    )


def _verify(library: Library, wire: bytes, fixture: _Fixture, ignore: bool,
            expected_error: str | None) -> list[dict]:
    receipts = []
    for api in ("streaming", "one_shot"):
        if expected_error is not None:
            error = library.expect_error(wire, fixture.dictionary, ignore, fixture.magicless, api=api)
            if expected_error == "ChecksumMismatch":
                _require("checksum" in error.lower(), "Strict bad footer must fail checksum validation")
            receipts.append({"api": api, "refused": True, "error": error, "verified": True})
        else:
            decoded = library.decode(wire, fixture.dictionary, ignore, fixture.magicless, api=api)
            _require(decoded == fixture.payload, f"{fixture.name}: {api} reference content mismatch")
            receipts.append({"api": api, "refused": False, "decoded_bytes": len(decoded),
                             "decoded_sha256": _digest(decoded), "verified": True})
    return receipts


def cases(output_dir: Path, library: Library) -> list[dict]:
    """Write shared small fixtures and return 100 JSON-compatible probe configs.

    Ten root public paths exercise standard frames. Three further contexts each
    cover five key paths. Each context has valid, strict bad checksum, ignored
    bad checksum and ignored truncated footer cases. Only checksum corruption
    and removal of a footer byte mutate the real reference-produced frames.
    """
    output_dir = Path(output_dir).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    result = []
    standard_payload_path = output_dir / "zstd-standard.payload"
    for fixture in _fixtures(library):
        stem = f"zstd-{fixture.name}"
        payload_path = standard_payload_path if fixture.magicless else output_dir / f"{stem}.payload"
        payload_path.write_bytes(fixture.payload)
        dictionary_path = None
        if fixture.dictionary is not None:
            dictionary_path = output_dir / f"{stem}.dictionary"
            dictionary_path.write_bytes(fixture.dictionary)
        good = fixture.wire
        bad_crc = good[:-1] + bytes([good[-1] ^ 0x80])
        truncated = good[:-1]
        wires = {"valid": good, "bad_crc_strict": bad_crc,
                 "bad_crc_ignore": bad_crc, "truncated_footer_ignore": truncated}
        good_path = output_dir / f"{stem}.valid.frame"
        bad_path = output_dir / f"{stem}.bad-crc.frame"
        truncated_path = output_dir / f"{stem}.truncated-footer.frame"
        for path, wire in ((good_path, good), (bad_path, bad_crc), (truncated_path, truncated)):
            path.write_bytes(wire)
        frame_paths = {"valid": good_path, "bad_crc_strict": bad_path,
                       "bad_crc_ignore": bad_path, "truncated_footer_ignore": truncated_path}
        apis = PUBLIC_APIS if fixture.name == "standard" else CONTEXT_APIS
        for api in apis:
            for variant, ignore, expected_error in VARIANTS:
                wire = wires[variant]
                # Every config is checked independently, even when its on-disk
                # fixture is shared with another public API configuration.
                reference = _verify(library, wire, fixture, ignore, expected_error)
                config = {"family": "zstd", "api": api, "payload_path": str(payload_path),
                          "frame_path": str(frame_paths[variant]), "warm_frame_path": str(good_path),
                          "dictionary_path": str(dictionary_path) if dictionary_path else None,
                          "ignore_content_checksum": ignore, "magicless": fixture.magicless,
                          "expected_error": expected_error, "input_chunk": 3, "output_chunk": 3}
                oracle = {"verified": True, "expected_error": expected_error,
                          "expected_bytes": len(fixture.payload) if expected_error is None else None,
                          "decoded_sha256": _digest(fixture.payload) if expected_error is None else None,
                          "payload_bytes": len(fixture.payload), "payload_sha256": _digest(fixture.payload),
                          "frame_bytes": len(wire), "frame_sha256": _digest(wire),
                          "max_frame_bytes": max(len(frame) - (4 if fixture.magicless else 0) for frame in fixture.frames),
                          "warm_frame_sha256": _digest(good), "frame_count": len(fixture.frames),
                          "dictionary_sha256": _digest(fixture.dictionary) if fixture.dictionary is not None else None,
                          "flags": {"content_checksum": True, "ignore_content_checksum": ignore,
                                    "magicless": fixture.magicless, "raw_dictionary": fixture.dictionary is not None,
                                    "checksum_corrupted": variant.startswith("bad_crc"),
                                    "footer_truncated": variant == "truncated_footer_ignore"},
                          "reference": reference}
                result.append({"name": f"{stem}-{api}-{variant}", "config": config, "oracle": oracle})
    _require(len(result) == 100 and len({case["name"] for case in result}) == 100,
             "Zstd control matrix must contain 100 distinct configs")
    return result
