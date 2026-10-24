#!/usr/bin/env python3
"""Focused Debug/ReleaseFast public and independent incremental PNG proofs."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=Path("/nav_env/Temp/vort-png-ultrafast-final-proof"))
    args = parser.parse_args()
    output = args.output_dir.resolve()
    if not output.is_relative_to(Path("/nav_env/Temp").resolve()):
        raise ValueError("proof artifacts must remain in Temp")
    output.mkdir(parents=True, exist_ok=True)
    source_link = output / "src"
    if not source_link.exists():
        source_link.symlink_to(ROOT / "src", target_is_directory=True)
    if source_link.resolve() != ROOT / "src":
        raise ValueError("proof source belongs to another checkout")
    harness = output / "root.zig"
    harness.write_text('test { _ = @import("src/deflate/incremental/encoder/png_ultrafast/root.zig"); _ = @import("src/png_ultrafast.zig"); }\n')
    cache = ["--cache-dir", str(output / "cache"), "--global-cache-dir", "/nav_env/Temp/zig-global-cache"]
    steps = []
    def run(name, argv):
        result = subprocess.run([str(x) for x in argv], cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        (output / (name + ".log")).write_bytes(result.stdout)
        steps.append({"name": name, "command": [str(x) for x in argv], "exit_code": result.returncode,
                      "log_sha256": hashlib.sha256(result.stdout).hexdigest()})
        if result.returncode:
            sys.stderr.buffer.write(result.stdout)
            raise SystemExit(result.returncode)
        print(f"vort_ultrafast_proof={name} pass", flush=True)
    for mode in ("Debug", "ReleaseFast"):
        run("owning-" + mode, ["zig", "test", harness, "-O", mode, "--test-filter", "PNG ultrafast", *cache])
        binary = output / ("produce-" + mode)
        run("compile-public-" + mode, ["zig", "build-exe", "-O", mode, "--dep", "vort",
            "-Mroot=" + str(ROOT / "tools/png_incremental_ultrafast/produce.zig"), "-O", mode,
            "-Mvort=" + str(ROOT / "src/root.zig"), "-femit-bin=" + str(binary), *cache])
        run("independent-" + mode, [sys.executable, ROOT / "tools/png_incremental_ultrafast/verify.py",
            "--producer", binary, "--output-dir", output / ("reference-" + mode)])
    manifest = {"schema": "vort.png_incremental_ultrafast_proof.v1", "steps": steps,
        "HEAD": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "zig": subprocess.check_output(["zig", "version"], text=True).strip()}
    (output / "proof.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("vort_png_incremental_ultrafast=pass proof=" + str(output / "proof.json"))

if __name__ == "__main__":
    main()
