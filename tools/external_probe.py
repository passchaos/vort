#!/usr/bin/env python3
import pathlib
import shutil

ROOT = pathlib.Path(__file__).resolve().parents[1]
CHECKS = [
    ("gzip", shutil.which("gzip")),
    ("python-zlib", "builtin"),
    ("zlib-ng-flate", shutil.which("zlib-ng-flate") or shutil.which("zlib-flate")),
    ("zlib-rs checkout", pathlib.Path.home() / "Work" / "zlib-rs"),
    ("zlib-ng checkout", pathlib.Path.home() / "Work" / "zlib-ng"),
    ("zstd", shutil.which("zstd")),
    ("zstd checkout", pathlib.Path.home() / "Work" / "zstd"),
]

print("external compression probe:")
for name, value in CHECKS:
    if isinstance(value, pathlib.Path):
        status = str(value) if value.exists() else "missing"
    else:
        status = value or "missing"
    print(f"- {name}: {status}")
