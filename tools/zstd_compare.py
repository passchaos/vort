#!/usr/bin/env python3
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
ZSTD = shutil.which("zstd")
CLI = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 and pathlib.Path(sys.argv[1]).exists() else None
arg_offset = 2 if CLI else 1

if not ZSTD:
    print("zstd compare: zstd=missing")
    raise SystemExit(0)

if len(sys.argv) <= arg_offset:
    paths = [ROOT / "README.md", ROOT / "docs" / "roadmap.md"]
else:
    paths = [pathlib.Path(p) for p in sys.argv[arg_offset:]]

print("path,input_bytes,zstd_bytes,vort_raw_fixed_bytes")
for path in paths:
    data = path.read_bytes()
    with tempfile.NamedTemporaryFile() as out:
        subprocess.run([ZSTD, "-q", "-f", "-1", "-o", out.name, str(path)], check=True)
        zstd_size = pathlib.Path(out.name).stat().st_size
    if CLI:
        # CLI command accepts text payloads; decode as UTF-8 for documentation/source corpora.
        hex_out = subprocess.run([str(CLI), "encode-raw-fixed-hex", data.decode("utf-8")], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE).stdout.strip()
        vort_size = len(bytes.fromhex(hex_out))
    else:
        vort_size = -1
    print(f"{path},{len(data)},{zstd_size},{vort_size}")
