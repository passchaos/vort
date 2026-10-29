#!/usr/bin/env python3
import hashlib
import json
import pathlib
import subprocess
import sys
import zlib


def sha256(data):
    return hashlib.sha256(data).hexdigest()


root = pathlib.Path(sys.argv[1])
inputs = pathlib.Path(sys.argv[2])
output = pathlib.Path(sys.argv[3])
wires = root / "wires"
wires.mkdir(exist_ok=True)
results = []
wrapper_bits = {"raw": -15, "zlib": 15, "gzip": 31}
for input_path in sorted(inputs.iterdir()):
    plain = input_path.read_bytes()
    for level in (8, 9):
        for wrapper, wbits in wrapper_bits.items():
            wire_path = wires / f"{input_path.name}-l{level}.{wrapper}"
            argv = [str(root / "wire-candidate"), str(input_path), str(wire_path), str(level), wrapper]
            subprocess.run(argv, check=True)
            wire = wire_path.read_bytes()
            decoded = zlib.decompress(wire, wbits=wbits)
            if decoded != plain:
                raise RuntimeError(f"decode mismatch: {wire_path}")
            reference_obj = zlib.compressobj(level=level, wbits=wbits)
            reference = reference_obj.compress(plain) + reference_obj.flush()
            results.append({
                "input": input_path.name,
                "input_bytes": len(plain),
                "input_sha256": sha256(plain),
                "level": level,
                "wrapper": wrapper,
                "wire": wire_path.name,
                "wire_bytes": len(wire),
                "wire_sha256": sha256(wire),
                "reference_bytes": len(reference),
                "decoded_sha256": sha256(decoded),
            })
output.write_text(json.dumps({
    "python_zlib_version": zlib.ZLIB_VERSION,
    "python_zlib_runtime_version": zlib.ZLIB_RUNTIME_VERSION,
    "checks": len(results),
    "results": results,
}, indent=2, sort_keys=True) + "\n")
print(json.dumps({"checks": len(results), "all_decoded": True}, sort_keys=True))
