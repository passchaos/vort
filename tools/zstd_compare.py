#!/usr/bin/env python3
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
ZSTD = shutil.which("zstd")

if not ZSTD:
    print("zstd compare: zstd=missing")
    raise SystemExit(0)

if len(sys.argv) <= 1:
    paths = [ROOT / "README.md", ROOT / "docs" / "roadmap.md"]
else:
    paths = [pathlib.Path(p) for p in sys.argv[1:]]

print("path,input_bytes,zstd_bytes")
for path in paths:
    data = path.read_bytes()
    with tempfile.NamedTemporaryFile() as out:
        subprocess.run([ZSTD, "-q", "-f", "-1", "-o", out.name, str(path)], check=True)
        zstd_size = pathlib.Path(out.name).stat().st_size
    print(f"{path},{len(data)},{zstd_size}")
