#!/usr/bin/env python3
import pathlib
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
import zlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
CLI = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 and pathlib.Path(sys.argv[1]).exists() else None
GZIP = shutil.which("gzip")
ZSTD = shutil.which("zstd")
ZLIB_NG_MINIGZIP = pathlib.Path.home() / "Work" / "zlib-ng" / "build" / "minigzip"
ZLIB_RS_COMPRESS = pathlib.Path.home() / "Work" / "zlib-rs" / "target" / "debug" / "examples" / "compress"
SILESIA = pathlib.Path.home() / "Work" / "zlib-rs" / "silesia-small.tar"
SMOKE_LIMIT = 128 * 1024
HEADER = "corpus,input_bytes,vort_zlib_fastest_bytes,vort_ms,vort_decode_ms,gzip_bytes,gzip_ms,gzip_decode_ms,zlib_ng_gzip_bytes,zlib_ng_ms,zlib_ng_decode_ms,zlib_rs_zlib_bytes,zlib_rs_ms,zlib_rs_decode_ms,zstd_bytes,zstd_ms,zstd_decode_ms"


def time_call(fn):
    start = time.perf_counter()
    result = fn()
    return result, time.perf_counter() - start


def run_case(label: str, data: bytes, root: pathlib.Path, index: int) -> str:
    case_dir = root / f"case-{index:03d}"
    case_dir.mkdir()
    sample = case_dir / "sample.bin"
    sample.write_bytes(data)

    vort_path = case_dir / "sample.vort.zlib"

    def vort_run():
        if not CLI:
            return b""
        subprocess.run([str(CLI), "encode-zlib-best-file", str(sample), str(vort_path), "fastest"], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE)
        return vort_path.read_bytes()

    def vort_decode_run():
        if not CLI or not vort_path.exists():
            return b""
        out = case_dir / "sample.vort.out"
        subprocess.run([str(CLI), "decode-zlib-file", str(vort_path), str(out)], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE)
        return out.read_bytes()

    def gzip_run():
        if not GZIP:
            return b""
        return subprocess.run([GZIP, "-n", "-1", "-c", str(sample)], check=True, stdout=subprocess.PIPE).stdout

    def zlib_ng_run():
        if not ZLIB_NG_MINIGZIP.exists():
            return b""
        work = case_dir / "zlib-ng"
        work.mkdir()
        src = work / "sample.bin"
        sample.write_bytes(data)
        src.write_bytes(data)
        subprocess.run([str(ZLIB_NG_MINIGZIP), str(src)], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return pathlib.Path(str(src) + ".gz").read_bytes()

    def zlib_rs_run():
        if not ZLIB_RS_COMPRESS.exists():
            return b""
        subprocess.run([str(ZLIB_RS_COMPRESS), "1", "rs", str(sample)], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return (pathlib.Path(tempfile.gettempdir()) / "rs.txt").read_bytes()

    def zstd_run():
        if not ZSTD:
            return b""
        out = case_dir / "sample.zst"
        subprocess.run([ZSTD, "-q", "-f", "-1", "-o", str(out), str(sample)], check=True)
        return out.read_bytes()

    vort_data, vort_s = time_call(vort_run)
    gzip_data, gzip_s = time_call(gzip_run)
    zlib_ng_data, zlib_ng_s = time_call(zlib_ng_run)
    zlib_rs_data, zlib_rs_s = time_call(zlib_rs_run)
    zstd_data, zstd_s = time_call(zstd_run)
    vort_decoded, vort_decode_s = time_call(vort_decode_run)

    def gzip_decode_run():
        if not gzip_data or not GZIP:
            return b""
        return subprocess.run([GZIP, "-dc"], input=gzip_data, check=True, stdout=subprocess.PIPE).stdout

    def zlib_ng_decode_run():
        return zlib.decompress(zlib_ng_data, 31) if zlib_ng_data else b""

    def zlib_rs_decode_run():
        return zlib.decompress(zlib_rs_data) if zlib_rs_data else b""

    def zstd_decode_run():
        if not zstd_data or not ZSTD:
            return b""
        return subprocess.run([ZSTD, "-q", "-dc"], input=zstd_data, check=True, stdout=subprocess.PIPE).stdout

    gzip_decoded, gzip_decode_s = time_call(gzip_decode_run)
    zlib_ng_decoded, zlib_ng_decode_s = time_call(zlib_ng_decode_run)
    zlib_rs_decoded, zlib_rs_decode_s = time_call(zlib_rs_decode_run)
    zstd_decoded, zstd_decode_s = time_call(zstd_decode_run)
    if vort_data:
        assert zlib.decompress(vort_data) == data
    if vort_decoded:
        assert vort_decoded == data
    if gzip_data:
        assert gzip_decoded == data
    if zlib_ng_data:
        assert zlib_ng_decoded == data
    if zlib_rs_data:
        assert zlib_rs_decoded == data
    if zstd_data:
        assert zstd_decoded == data
    return f"{label},{len(data)},{len(vort_data)},{vort_s*1000:.3f},{vort_decode_s*1000:.3f},{len(gzip_data)},{gzip_s*1000:.3f},{gzip_decode_s*1000:.3f},{len(zlib_ng_data)},{zlib_ng_s*1000:.3f},{zlib_ng_decode_s*1000:.3f},{len(zlib_rs_data)},{zlib_rs_s*1000:.3f},{zlib_rs_decode_s*1000:.3f},{len(zstd_data)},{zstd_s*1000:.3f},{zstd_decode_s*1000:.3f}"


def load_cases(full: bool, suite: bool) -> list[tuple[str, bytes]]:
    if suite:
        cases: list[tuple[str, bytes]] = []
        with tarfile.open(SILESIA, "r") as tar:
            for member in tar.getmembers():
                if not member.isfile():
                    continue
                extracted = tar.extractfile(member)
                if extracted is None:
                    continue
                data = extracted.read()
                label = member.name.removeprefix("silesia-small/")
                if not full:
                    data = data[:SMOKE_LIMIT]
                    label = f"{label}-128k"
                cases.append((label, data))
        return cases

    source = SILESIA.read_bytes()
    data = source if full else source[:SMOKE_LIMIT]
    label = "silesia-full" if full else "silesia-128k"
    return [(label, data)]


def main() -> int:
    if not SILESIA.exists():
        print("standard corpus report: missing silesia-small.tar")
        return 0
    full = "--full" in sys.argv[1:]
    suite = "--suite" in sys.argv[1:]
    cases = load_cases(full, suite)
    with tempfile.TemporaryDirectory() as td:
        root = pathlib.Path(td)
        print(HEADER)
        for index, (label, data) in enumerate(cases):
            print(run_case(label, data, root, index))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
