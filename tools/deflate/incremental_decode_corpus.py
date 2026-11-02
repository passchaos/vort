#!/usr/bin/env python3
"""Bind Silesia prefixes and zlib-generated raw Deflate comparison streams."""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import zlib


SOURCES = (
    "dickens", "mozilla", "mr", "nci", "ooffice", "osdb",
    "reymont", "samba", "sao", "webster", "x-ray", "xml",
)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=pathlib.Path, required=True)
    parser.add_argument("--output-dir", type=pathlib.Path, required=True)
    args = parser.parse_args()
    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    rows = []
    for name in SOURCES:
        source = (args.source_dir / name).resolve()
        data = source.read_bytes()
        for scope, limit in (("64k", 65536), ("1m", 1048576)):
            plain = data[:limit]
            if len(plain) != limit:
                raise SystemExit(f"{name}: source is smaller than {scope}")
            input_path = output_dir / f"{name}.{scope}.bin"
            input_path.write_bytes(plain)
            for level in (6, 9):
                compressor = zlib.compressobj(level, zlib.DEFLATED, -15, 8, zlib.Z_DEFAULT_STRATEGY)
                wire = compressor.compress(plain) + compressor.flush(zlib.Z_FINISH)
                if zlib.decompress(wire, -15) != plain:
                    raise SystemExit(f"{name}/{scope}/l{level}: reference round trip failed")
                wire_path = output_dir / f"{name}.{scope}.l{level}.deflate"
                wire_path.write_bytes(wire)
                rows.append({
                    "id": f"{name}.{scope}.rawdeflate.{level}",
                    "family": "rawdeflate", "source": name, "scope": scope, "level": level,
                    "source_path": str(source), "source_sha256": digest(data),
                    "input_path": str(input_path), "wire_path": str(wire_path),
                    "input_bytes": len(plain), "wire_bytes": len(wire),
                    "input_sha256": digest(plain), "wire_sha256": digest(wire),
                })
    manifest = {
        "zlib_compile_version": zlib.ZLIB_VERSION,
        "zlib_runtime_version": zlib.ZLIB_RUNTIME_VERSION,
        "options": {"window_bits": -15, "mem_level": 8, "strategy": "Z_DEFAULT_STRATEGY", "flush": "Z_FINISH"},
        "rows": rows,
    }
    (output_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"bound {len(rows)} raw Deflate rows with zlib {zlib.ZLIB_RUNTIME_VERSION}")


if __name__ == "__main__":
    main()
