#!/usr/bin/env python3
"""Generate deterministic positive and inactive raw Deflate controls."""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import platform
import random
import zlib


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=pathlib.Path, required=True)
    args = parser.parse_args()
    folder = args.output_dir.resolve()
    folder.mkdir(parents=True, exist_ok=True)
    rows = []
    seed = 0x2AFE441C
    for name in ("random", "periodic", "overlap", "mixed"):
        rng = random.Random(seed)
        if name == "random":
            data = rng.randbytes(1048576)
        elif name == "periodic":
            data = (b"periodic-control-17" + b"ABCDEFG" * 17) * 8000
        elif name == "overlap":
            data = (b"A" * 32769 + b"BCD" * 10923 + b"DE" * 16384) * 11
        else:
            chunks = []
            for _ in range(16):
                chunks.append(rng.randbytes(32768))
                chunks.append((b'{"ts":1700000000,"message":"server-side compression control","status":200}\n' * 500)[:32768])
            data = b"".join(chunks)
        for scope, size in (("64k", 65536), ("1m", 1048576)):
            plain = data[:size]
            if len(plain) != size:
                raise SystemExit("short control")
            path = folder / f"{name}.{scope}.bin"
            path.write_bytes(plain)
            for level in (6, 9):
                compressor = zlib.compressobj(level, zlib.DEFLATED, -15, 8, zlib.Z_DEFAULT_STRATEGY)
                wire = compressor.compress(plain) + compressor.flush(zlib.Z_FINISH)
                if zlib.decompress(wire, -15) != plain:
                    raise SystemExit("reference round trip failed")
                wire_path = folder / f"{name}.{scope}.l{level}.deflate"
                wire_path.write_bytes(wire)
                rows.append({"id": f"{name}.{scope}.rawdeflate.{level}", "family": "rawdeflate",
                             "source": name, "scope": scope, "level": level,
                             "input_path": str(path), "wire_path": str(wire_path),
                             "input_bytes": len(plain), "wire_bytes": len(wire),
                             "input_sha256": hashlib.sha256(plain).hexdigest(),
                             "wire_sha256": hashlib.sha256(wire).hexdigest()})
    manifest = {"seed": seed, "python": platform.python_version(),
                "zlib_compile_version": zlib.ZLIB_VERSION,
                "zlib_runtime_version": zlib.ZLIB_RUNTIME_VERSION,
                "window_bits": -15, "mem_level": 8, "strategy": "Z_DEFAULT_STRATEGY",
                "flush": "Z_FINISH", "rows": rows}
    (folder / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"bound {len(rows)} controls using zlib {zlib.ZLIB_RUNTIME_VERSION}")


if __name__ == "__main__":
    main()
