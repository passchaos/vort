#!/usr/bin/env python3
import pathlib
import shutil
import subprocess
import sys
import tempfile
import time
import zlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
CLI = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 and pathlib.Path(sys.argv[1]).exists() else None
GZIP = shutil.which("gzip")
ZSTD = shutil.which("zstd")
SILESIA = pathlib.Path.home() / "Work" / "zlib-rs" / "silesia-small.tar"
LIMIT = 128 * 1024


def time_call(fn):
    start = time.perf_counter()
    result = fn()
    return result, time.perf_counter() - start


def main() -> int:
    if not SILESIA.exists():
        print("standard corpus report: missing silesia-small.tar")
        return 0
    data = SILESIA.read_bytes()[:LIMIT]
    with tempfile.TemporaryDirectory() as td:
        sample = pathlib.Path(td) / "silesia-1m.bin"
        sample.write_bytes(data)

        def vort_run():
            if not CLI:
                return b""
            hex_out = subprocess.run([str(CLI), "encode-zlib-best-file-hex", str(sample), "optimal"], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE).stdout.strip()
            return bytes.fromhex(hex_out)

        def gzip_run():
            if not GZIP:
                return b""
            return subprocess.run([GZIP, "-n", "-1", "-c", str(sample)], check=True, stdout=subprocess.PIPE).stdout

        def zstd_run():
            if not ZSTD:
                return b""
            out = pathlib.Path(td) / "sample.zst"
            subprocess.run([ZSTD, "-q", "-f", "-1", "-o", str(out), str(sample)], check=True)
            return out.read_bytes()

        vort_data, vort_s = time_call(vort_run)
        gzip_data, gzip_s = time_call(gzip_run)
        zstd_data, zstd_s = time_call(zstd_run)
        if vort_data:
            assert zlib.decompress(vort_data) == data
        if gzip_data:
            assert zlib.decompress(gzip_data, 31) == data
        print("corpus,input_bytes,vort_zlib_best_bytes,vort_ms,gzip_bytes,gzip_ms,zstd_bytes,zstd_ms")
        print(f"silesia-1m,{len(data)},{len(vort_data)},{vort_s*1000:.3f},{len(gzip_data)},{gzip_s*1000:.3f},{len(zstd_data)},{zstd_s*1000:.3f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
