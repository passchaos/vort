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
arg_offset = 2 if CLI else 1
GZIP = shutil.which("gzip")
ZSTD = shutil.which("zstd")

if len(sys.argv) <= arg_offset:
    paths = [ROOT / "README.md", ROOT / "docs" / "roadmap.md"]
else:
    paths = [pathlib.Path(p) for p in sys.argv[arg_offset:]]


def time_call(fn):
    start = time.perf_counter()
    result = fn()
    return result, time.perf_counter() - start


def vort_best(data: bytes):
    if not CLI:
        return None, 0.0
    def run():
        hex_out = subprocess.run([str(CLI), "encode-zlib-fixed-hex", data.decode("utf-8"), "optimal"], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE).stdout.strip()
        return bytes.fromhex(hex_out)
    return time_call(run)


def gzip_one(path: pathlib.Path):
    if not GZIP:
        return None, 0.0
    def run():
        with tempfile.NamedTemporaryFile() as out:
            subprocess.run([GZIP, "-n", "-1", "-c", str(path)], check=True, stdout=out)
            out.flush()
            return pathlib.Path(out.name).read_bytes()
    return time_call(run)


def zstd_one(path: pathlib.Path):
    if not ZSTD:
        return None, 0.0
    def run():
        with tempfile.NamedTemporaryFile() as out:
            subprocess.run([ZSTD, "-q", "-f", "-1", "-o", out.name, str(path)], check=True)
            return pathlib.Path(out.name).read_bytes()
    return time_call(run)

print("path,input_bytes,vort_zlib_fixed_bytes,vort_ms,gzip_bytes,gzip_ms,zstd_bytes,zstd_ms")
for path in paths:
    data = path.read_bytes()
    vort_data, vort_s = vort_best(data)
    gzip_data, gzip_s = gzip_one(path)
    zstd_data, zstd_s = zstd_one(path)
    if vort_data is not None:
        assert zlib.decompress(vort_data) == data
    if gzip_data is not None:
        assert zlib.decompress(gzip_data, 31) == data
    print(
        f"{path},{len(data)},"
        f"{len(vort_data) if vort_data is not None else -1},{vort_s*1000:.3f},"
        f"{len(gzip_data) if gzip_data is not None else -1},{gzip_s*1000:.3f},"
        f"{len(zstd_data) if zstd_data is not None else -1},{zstd_s*1000:.3f}"
    )
