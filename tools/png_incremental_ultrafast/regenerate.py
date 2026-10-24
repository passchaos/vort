#!/usr/bin/env python3
"""Reproduce pinned fdeflate vectors and RFC framing in their owned Temp path."""
from pathlib import Path
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
TARGET = Path("/nav_env/Temp/vort-png-incremental-ultrafast-reference")
TARGET.mkdir(parents=True, exist_ok=True)
for path in (HERE / "reference").rglob("*"):
    if path.is_file():
        relative = path.relative_to(HERE / "reference")
        (TARGET / relative).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, TARGET / relative)
for name in ("generate.py", "convert_stream.py"):
    subprocess.run([sys.executable, str(TARGET / name)], cwd=TARGET, check=True)
