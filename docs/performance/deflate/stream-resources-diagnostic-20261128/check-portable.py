#!/usr/bin/env python3
"""Verify archived data while denying all host /tmp file reads."""
import builtins
import importlib.util
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("portable_diagnostic_verifier", ROOT / "verify-evidence.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
original_open = builtins.open


def guarded_open(file, *args, **kwargs):
    if isinstance(file, (str, bytes, Path)):
        name = file.decode() if isinstance(file, bytes) else str(file)
        if name == "/tmp" or name.startswith("/tmp/"):
            raise AssertionError("Original host path access denied: " + name)
    return original_open(file, *args, **kwargs)


builtins.open = guarded_open
result = module.verify(ROOT)
print(json.dumps({"original_tmp_reads_denied": True, "equal_row_GM": result["equal_row_GM"],
                  "weak_row_count": result["weak_row_count"], "archive_members": result["archive_members"],
                  "portable_without_original_tmp": result["portable_without_original_tmp"],
                  "new_codec_or_build_or_sampling_or_RSS_executed": False}, indent=2, sort_keys=True))
