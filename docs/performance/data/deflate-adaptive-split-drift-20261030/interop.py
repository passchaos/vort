#!/usr/bin/env python3
"""Generate and independently decode retained adaptive raw/zlib/gzip wires."""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import zlib
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("probe", type=Path)
    parser.add_argument("inputs", type=Path)
    parser.add_argument("wires", type=Path)
    parser.add_argument("interop_json", type=Path)
    parser.add_argument("reference_json", type=Path)
    args = parser.parse_args()
    args.wires.mkdir(parents=True, exist_ok=True)
    rows = []
    references = []
    for input_path in sorted(args.inputs.glob("*-196608")):
        plain = input_path.read_bytes()
        input_sha256 = hashlib.sha256(plain).hexdigest()
        references.append({
            "case": input_path.stem.removesuffix("-196608"),
            "input_bytes": len(plain),
            "input_sha256": input_sha256,
            "zlib_1_2_11_level6_bytes": len(zlib.compress(plain, 6)),
            "zlib_1_2_11_level9_bytes": len(zlib.compress(plain, 9)),
        })
        for format_name, wbits in (("raw", -15), ("zlib", 15), ("gzip", 31)):
            output = args.wires / f"{input_path.stem}.{format_name}"
            subprocess.run(
                [str(args.probe), format_name, str(input_path), str(output)],
                check=True,
            )
            wire = output.read_bytes()
            decoded = zlib.decompress(wire, wbits)
            assert decoded == plain
            rows.append({
                "case": input_path.stem,
                "format": format_name,
                "input_bytes": len(plain),
                "input_sha256": input_sha256,
                "wire_bytes": len(wire),
                "wire_sha256": hashlib.sha256(wire).hexdigest(),
                "decoded_sha256": hashlib.sha256(decoded).hexdigest(),
            })
    args.interop_json.write_text(json.dumps({
        "probe_sha256": hashlib.sha256(args.probe.read_bytes()).hexdigest(),
        "cases": len(rows),
        "all_system_zlib_decodes": True,
        "rows": rows,
    }, indent=2) + "\n")
    args.reference_json.write_text(json.dumps({
        "zlib_version": zlib.ZLIB_VERSION,
        "runtime_version": zlib.ZLIB_RUNTIME_VERSION,
        "rows": references,
        "level6_total_bytes": sum(row["zlib_1_2_11_level6_bytes"] for row in references),
        "level9_total_bytes": sum(row["zlib_1_2_11_level9_bytes"] for row in references),
    }, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
