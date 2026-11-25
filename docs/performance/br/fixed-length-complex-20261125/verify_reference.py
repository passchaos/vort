#!/usr/bin/env python3
"""Decode the six frozen complete Brotli streams with an explicit reference."""
import argparse
import ctypes
import hashlib
import json
from pathlib import Path


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def validate(library, directory):
    library = library.resolve(strict=True)
    api = ctypes.CDLL(str(library))
    api.BrotliDecoderVersion.restype = ctypes.c_uint32
    decode = api.BrotliDecoderDecompress
    decode.argtypes = [ctypes.c_size_t, ctypes.c_void_p,
                       ctypes.POINTER(ctypes.c_size_t), ctypes.c_void_p]
    decode.restype = ctypes.c_int
    rows = []
    for dimension in ("command", "distance", "literal"):
        for regions in (5, 6):
            case = f"{dimension}-{regions}"
            wire = (directory / f"{case}.br").read_bytes()
            plain = (directory / f"{case}.plain").read_bytes()
            encoded = ctypes.create_string_buffer(wire)
            output = ctypes.create_string_buffer(max(1, len(plain)))
            output_size = ctypes.c_size_t(len(plain))
            result = decode(len(wire), encoded, ctypes.byref(output_size), output)
            if result != 1 or output_size.value != len(plain) or output.raw[:output_size.value] != plain:
                raise ValueError(f"reference decode differs: {case}")
            rows.append({"case": case, "wire_bytes": len(wire),
                         "plain_bytes": len(plain), "wire_sha256": sha256(wire),
                         "plain_sha256": sha256(plain), "result": result})
    return {"reference_path": str(library),
            "reference_sha256": sha256(library.read_bytes()),
            "queried_decoder_version": api.BrotliDecoderVersion(),
            "rows": rows, "complete_output_verified": True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--library", type=Path, required=True)
    parser.add_argument("--fixtures", type=Path,
                        default=Path(__file__).resolve().parent / "fixtures")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = json.dumps(validate(args.library, args.fixtures), indent=2) + "\n"
    if args.output:
        args.output.write_text(result)
    else:
        print(result, end="")


if __name__ == "__main__":
    main()
