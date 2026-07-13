#!/usr/bin/env python3
import pathlib
import shutil
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
CHECKS = [
    ("gzip", shutil.which("gzip")),
    ("python-zlib", "builtin"),
    ("zlib-ng-flate", shutil.which("zlib-ng-flate") or shutil.which("zlib-flate")),
    ("zlib-rs checkout", pathlib.Path.home() / "Work" / "zlib-rs"),
    ("zlib-ng checkout", pathlib.Path.home() / "Work" / "zlib-ng"),
    ("fdeflate checkout", pathlib.Path.home() / "Work" / "fdeflate"),
    ("miniz_oxide checkout", pathlib.Path.home() / "Work" / "miniz_oxide"),
    ("zstd", shutil.which("zstd")),
    ("zstd checkout", pathlib.Path.home() / "Work" / "zstd"),
]

print("external compression probe:")
for name, value in CHECKS:
    if isinstance(value, pathlib.Path):
        if value.exists():
            status = str(value)
            try:
                rev = subprocess.run(
                    ["git", "-C", str(value), "rev-parse", "--short", "HEAD"],
                    check=True,
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL,
                ).stdout.strip()
                if rev:
                    status = f"{status} (git {rev})"
            except (subprocess.CalledProcessError, FileNotFoundError):
                pass
        else:
            status = "missing"
    else:
        status = value or "missing"
    print(f"- {name}: {status}")
