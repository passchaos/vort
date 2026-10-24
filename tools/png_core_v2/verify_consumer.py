#!/usr/bin/env python3
"""Focused owning, actual-root public and independent PNG ultrafast proofs."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path('/nav_env/project-z/imx-next-aa3ad3c3-png-row-performance')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vort-root", type=Path, default=ROOT.parent / "vort-published")
    parser.add_argument("--spectra-root", type=Path, default=ROOT.parent / "spectra")
    parser.add_argument("--output-dir", type=Path, default=Path("/nav_env/Temp/vort-png-core-v2/consumer-proof"))
    args = parser.parse_args()
    output = args.output_dir.resolve()
    if not output.is_relative_to(Path("/nav_env/Temp").resolve()):
        raise ValueError("proof artifacts must remain in Temp")
    output.mkdir(parents=True, exist_ok=True)
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
        print(f"imx_ultrafast_proof={name} pass", flush=True)
    for mode in ("Debug", "ReleaseFast"):
        run("owning-" + mode, ["zig", "test", "-O", mode, "--dep", "vort",
            "-Mroot=" + str(ROOT / "src/test_png_encode.zig"), "-O", mode,
            "--dep", "vail_archive_crypto", "-Mvort=" + str(args.vort_root.resolve() / "src/root.zig"), "-O", mode, "-Mvail_archive_crypto=/nav_env/project-z/vail/archive_crypto/src/root.zig",
            "--test-filter", "PNG foundation", "--test-filter", "PNG bounded row", "--test-filter", "png adam7", *cache])
        for name, source in (("public", "src/contracts/png_stream_encode.zig"), ("produce", "tools/png_ultrafast_encode/produce.zig")):
            binary = output / (name + "-" + mode)
            run("compile-" + name + "-" + mode, ["zig", "build-exe", "-O", mode, "--dep", "imx",
                "-Mroot=" + str(ROOT / source), "-O", mode, "--dep", "vort", "--dep", "spectra", "--dep", "meridian",
                "-Mimx=" + str(ROOT / "src/root.zig"), "-O", mode,
                "--dep", "vail_archive_crypto", "-Mvort=" + str(args.vort_root.resolve() / "src/root.zig"), "-O", mode, "-Mvail_archive_crypto=/nav_env/project-z/vail/archive_crypto/src/root.zig", "-O", mode,
                "-Mspectra=" + str(args.spectra_root.resolve() / "src/root.zig"), "-O", mode, "-Mmeridian=/nav_env/project-z/meridian/src/root.zig", "-lc", "-femit-bin=" + str(binary), *cache])
            if name == "public":
                run("run-public-" + mode, [binary])
            else:
                run("independent-" + mode, [sys.executable, ROOT / "tools/png_stream_encode_reference/run.py",
                    "--producer", binary, "--output-dir", output / ("reference-" + mode)])
    manifest = {"schema": "imx.png_incremental_ultrafast_proof.v1", "steps": steps,
        "HEAD": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "zig": subprocess.check_output(["zig", "version"], text=True).strip(),
        "compression": "actual PNG ultrafast for all 30 producer cases; independent source author/decoder scripts unchanged",
        "vort_root": str(args.vort_root.resolve())}
    (output / "proof.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("imx_png_ultrafast=pass proof=" + str(output / "proof.json"))

if __name__ == "__main__":
    main()
