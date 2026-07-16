#!/usr/bin/env python3
import os
import pathlib
import platform
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
ZLIB_NG_MINIGZIP = pathlib.Path(os.environ.get("VORT_ZLIB_NG_MINIGZIP", pathlib.Path.home() / "Work" / "zlib-ng" / "build" / "minigzip"))
ZLIB_RS_COMPRESS = pathlib.Path(os.environ.get("VORT_ZLIB_RS_COMPRESS", pathlib.Path.home() / "Work" / "zlib-rs" / "target" / "debug" / "examples" / "compress"))
SILESIA = pathlib.Path(os.environ.get("VORT_SILESIA_PATH", pathlib.Path.home() / "Work" / "zlib-rs" / "silesia-small.tar"))
CORPORA_DIR = pathlib.Path(os.environ.get("VORT_CORPORA_DIR", pathlib.Path.home() / "Work" / "corpora"))
STANDARD_CORPUS_CANDIDATES = [
    SILESIA,
    CORPORA_DIR / "calgary.tar",
    CORPORA_DIR / "canterbury.tar",
    CORPORA_DIR / "large-canterbury.tar",
    CORPORA_DIR / "enwik8",
]
SMOKE_LIMIT = 128 * 1024
HEADER = "corpus,input_bytes,vort_zlib_fastest_bytes,vort_ms,vort_decode_ms,vort_zlib_default_bytes,vort_default_ms,vort_default_decode_ms,gzip_bytes,gzip_ms,gzip_decode_ms,zlib_ng_gzip_bytes,zlib_ng_ms,zlib_ng_decode_ms,zlib_rs_zlib_bytes,zlib_rs_ms,zlib_rs_decode_ms,zstd_bytes,zstd_ms,zstd_decode_ms"
COLUMNS = HEADER.split(",")


def time_call(fn):
    start = time.perf_counter()
    result = fn()
    return result, time.perf_counter() - start


def run_case(label: str, data: bytes, root: pathlib.Path, index: int) -> str:
    case_dir = root / f"case-{index:03d}"
    case_dir.mkdir()
    sample = case_dir / "sample.bin"
    sample.write_bytes(data)

    vort_fastest_path = case_dir / "sample.vort.fastest.zlib"
    vort_default_path = case_dir / "sample.vort.default.zlib"

    def vort_run(level: str, output_path: pathlib.Path):
        if not CLI:
            return b""
        subprocess.run([str(CLI), "encode-zlib-best-file", str(sample), str(output_path), level], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE)
        return output_path.read_bytes()

    def vort_decode_run(frame_path: pathlib.Path):
        if not CLI or not frame_path.exists():
            return b""
        out = case_dir / f"{frame_path.stem}.out"
        subprocess.run([str(CLI), "decode-zlib-file", str(frame_path), str(out)], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE)
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

    vort_data, vort_s = time_call(lambda: vort_run("fastest", vort_fastest_path))
    vort_default_data, vort_default_s = time_call(lambda: vort_run("default", vort_default_path))
    gzip_data, gzip_s = time_call(gzip_run)
    zlib_ng_data, zlib_ng_s = time_call(zlib_ng_run)
    zlib_rs_data, zlib_rs_s = time_call(zlib_rs_run)
    zstd_data, zstd_s = time_call(zstd_run)
    vort_decoded, vort_decode_s = time_call(lambda: vort_decode_run(vort_fastest_path))
    vort_default_decoded, vort_default_decode_s = time_call(lambda: vort_decode_run(vort_default_path))

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
    if vort_default_data:
        assert zlib.decompress(vort_default_data) == data
    if vort_decoded:
        assert vort_decoded == data
    if vort_default_decoded:
        assert vort_default_decoded == data
    if gzip_data:
        assert gzip_decoded == data
    if zlib_ng_data:
        assert zlib_ng_decoded == data
    if zlib_rs_data:
        assert zlib_rs_decoded == data
    if zstd_data:
        assert zstd_decoded == data
    return f"{label},{len(data)},{len(vort_data)},{vort_s*1000:.3f},{vort_decode_s*1000:.3f},{len(vort_default_data)},{vort_default_s*1000:.3f},{vort_default_decode_s*1000:.3f},{len(gzip_data)},{gzip_s*1000:.3f},{gzip_decode_s*1000:.3f},{len(zlib_ng_data)},{zlib_ng_s*1000:.3f},{zlib_ng_decode_s*1000:.3f},{len(zlib_rs_data)},{zlib_rs_s*1000:.3f},{zlib_rs_decode_s*1000:.3f},{len(zstd_data)},{zstd_s*1000:.3f},{zstd_decode_s*1000:.3f}"


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


def discover_standard_corpora() -> list[pathlib.Path]:
    found: list[pathlib.Path] = []
    seen: set[pathlib.Path] = set()
    for path in STANDARD_CORPUS_CANDIDATES:
        if path.exists() and path not in seen:
            found.append(path)
            seen.add(path)
    return found


def load_path_cases(paths: list[pathlib.Path], full: bool) -> list[tuple[str, bytes]]:
    cases: list[tuple[str, bytes]] = []
    for path in paths:
        if path.is_dir():
            for child in sorted(p for p in path.rglob("*") if p.is_file()):
                data = child.read_bytes()
                label = str(child.relative_to(path.parent))
                if not full:
                    data = data[:SMOKE_LIMIT]
                    label = f"{label}-128k"
                cases.append((label, data))
        elif tarfile.is_tarfile(path):
            with tarfile.open(path, "r:*") as tar:
                for member in tar.getmembers():
                    if not member.isfile():
                        continue
                    extracted = tar.extractfile(member)
                    if extracted is None:
                        continue
                    data = extracted.read()
                    label = f"{path.name}:{member.name}"
                    if not full:
                        data = data[:SMOKE_LIMIT]
                        label = f"{label}-128k"
                    cases.append((label, data))
        else:
            data = path.read_bytes()
            label = path.name
            if not full:
                data = data[:SMOKE_LIMIT]
                label = f"{label}-128k"
            cases.append((label, data))
    return cases


def format_paths(paths: list[pathlib.Path]) -> str:
    return ", ".join(str(path) for path in paths) if paths else "none"


def row_to_dict(row: str) -> dict[str, str]:
    values = row.split(",")
    return dict(zip(COLUMNS, values))


def summarize_codecs(records: list[dict[str, str]]) -> list[dict[str, object]]:
    codecs = [
        ("vort-fastest", "vort_zlib_fastest_bytes", "vort_ms", "vort_decode_ms"),
        ("vort-default", "vort_zlib_default_bytes", "vort_default_ms", "vort_default_decode_ms"),
        ("gzip", "gzip_bytes", "gzip_ms", "gzip_decode_ms"),
        ("zlib-ng", "zlib_ng_gzip_bytes", "zlib_ng_ms", "zlib_ng_decode_ms"),
        ("zlib-rs", "zlib_rs_zlib_bytes", "zlib_rs_ms", "zlib_rs_decode_ms"),
        ("zstd", "zstd_bytes", "zstd_ms", "zstd_decode_ms"),
    ]
    summaries: list[dict[str, object]] = []
    for name, bytes_col, encode_col, decode_col in codecs:
        total_input = 0
        total_compressed = 0
        total_encode_ms = 0.0
        total_decode_ms = 0.0
        files = 0
        for rec in records:
            compressed = int(rec[bytes_col])
            if compressed == 0:
                continue
            files += 1
            total_input += int(rec["input_bytes"])
            total_compressed += compressed
            total_encode_ms += float(rec[encode_col])
            total_decode_ms += float(rec[decode_col])
        input_mib = total_input / (1024.0 * 1024.0)
        encode_s = total_encode_ms / 1000.0
        decode_s = total_decode_ms / 1000.0
        summaries.append({
            "codec": name,
            "files": files,
            "input_bytes": total_input,
            "compressed_bytes": total_compressed,
            "ratio": 0.0 if total_input == 0 else total_compressed / total_input,
            "encode_ms": total_encode_ms,
            "decode_ms": total_decode_ms,
            "encode_mib_s": 0.0 if encode_s == 0 else input_mib / encode_s,
            "decode_mib_s": 0.0 if decode_s == 0 else input_mib / decode_s,
        })
    return summaries


def capture_metadata() -> dict[str, str]:
    meta: dict[str, str] = {}
    try:
        meta["git_commit"] = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True, check=True
        ).stdout.strip()[:12]
    except Exception:
        meta["git_commit"] = "unknown"
    try:
        meta["git_branch"] = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=ROOT, capture_output=True, text=True, check=True
        ).stdout.strip()
    except Exception:
        meta["git_branch"] = "unknown"
    meta["host"] = platform.node()
    meta["cpu"] = platform.processor() or platform.machine()
    meta["os"] = f"{platform.system()} {platform.release()}"
    meta["python"] = sys.version.split()[0]
    if CLI:
        try:
            result = subprocess.run(
                [str(CLI), "--version"], cwd=ROOT, capture_output=True, text=True
            )
            version = result.stdout.strip() if result.returncode == 0 else ""
            meta["vort_version"] = version.splitlines()[0] if version else "unknown"
        except Exception:
            meta["vort_version"] = "unknown"
    else:
        meta["vort_version"] = "missing"
    if GZIP:
        try:
            result = subprocess.run([GZIP, "--version"], capture_output=True, text=True)
            meta["gzip_version"] = result.stdout.splitlines()[0] if result.stdout else "unknown"
        except Exception:
            meta["gzip_version"] = "unknown"
    else:
        meta["gzip_version"] = "missing"
    if ZSTD:
        try:
            result = subprocess.run([ZSTD, "--version"], capture_output=True, text=True)
            meta["zstd_version"] = result.stdout.strip() if result.stdout else "unknown"
        except Exception:
            meta["zstd_version"] = "unknown"
    else:
        meta["zstd_version"] = "missing"
    meta["zlib_version"] = zlib.ZLIB_VERSION
    return meta


def write_markdown(rows: list[str], path: pathlib.Path, suite: bool, full: bool, external_paths: bool = False, sources: list[pathlib.Path] | None = None, case_limit: int | None = None) -> None:
    records = [row_to_dict(row) for row in rows]
    title = "External corpus benchmark suite" if external_paths else ("Silesia per-file benchmark suite" if suite else "Silesia benchmark smoke")
    mode = "full" if full else "bounded-128KiB"
    meta = capture_metadata()
    lines = [
        f"# {title}",
        "",
        f"- mode: `{mode}`",
        f"- rows: {len(records)}",
        f"- generated: {time.strftime('%Y-%m-%d %H:%M:%S %Z')}",
        f"- host: `{meta['host']}`",
        f"- cpu: `{meta['cpu']}`",
        f"- os: `{meta['os']}`",
        f"- git commit: `{meta['git_commit']}` ({meta['git_branch']})",
        f"- vort: `{meta['vort_version']}`",
        f"- gzip: `{meta['gzip_version']}`",
        f"- zstd: `{meta['zstd_version']}`",
        f"- python zlib: `{meta['zlib_version']}`",
        f"- zlib-ng minigzip: `{ZLIB_NG_MINIGZIP if ZLIB_NG_MINIGZIP.exists() else 'missing'}`",
        f"- zlib-rs compress: `{ZLIB_RS_COMPRESS if ZLIB_RS_COMPRESS.exists() else 'missing'}`",
        f"- sources: `{format_paths(sources or [])}`",
        f"- limit: `{case_limit if case_limit is not None else 'none'}`",
        "",
        "## Summary by codec",
        "",
        "| codec | files | total input | compressed bytes | ratio | encode ms | encode MiB/s | decode ms | decode MiB/s |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for summary in summarize_codecs(records):
        lines.append(
            "| {codec} | {files} | {input_bytes} | {compressed_bytes} | {ratio:.4f} | {encode_ms:.3f} | {encode_mib_s:.2f} | {decode_ms:.3f} | {decode_mib_s:.2f} |".format(**summary)
        )
    lines.extend([
        "",
        "## Rows",
        "",
        "| corpus | input | Vort fastest bytes | Vort fastest ms | Vort fastest dec ms | Vort default bytes | Vort default ms | Vort default dec ms | gzip bytes | gzip ms | zlib-ng bytes | zlib-rs bytes | zstd bytes |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ])
    for rec in records:
        lines.append(
            "| {corpus} | {input_bytes} | {vort_zlib_fastest_bytes} | {vort_ms} | {vort_decode_ms} | {vort_zlib_default_bytes} | {vort_default_ms} | {vort_default_decode_ms} | {gzip_bytes} | {gzip_ms} | {zlib_ng_gzip_bytes} | {zlib_rs_zlib_bytes} | {zstd_bytes} |".format(**rec)
        )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n")


def main() -> int:
    full = "--full" in sys.argv[1:]
    suite = "--suite" in sys.argv[1:]
    standard_suite = "--standard-suite" in sys.argv[1:]
    markdown_path = None
    case_limit: int | None = None
    corpus_paths: list[pathlib.Path] = []
    source_paths: list[pathlib.Path] = []
    for index, arg in enumerate(sys.argv):
        if arg == "--markdown" and index + 1 < len(sys.argv):
            markdown_path = pathlib.Path(sys.argv[index + 1])
        if arg == "--limit" and index + 1 < len(sys.argv):
            case_limit = int(sys.argv[index + 1])
        if arg == "--paths":
            for value in sys.argv[index + 1 :]:
                if value.startswith("--"):
                    break
                corpus_paths.append(pathlib.Path(value))
    if corpus_paths:
        source_paths = corpus_paths
        cases = load_path_cases(corpus_paths, full)
    elif standard_suite:
        discovered = discover_standard_corpora()
        if not discovered:
            print("standard corpus report: no standard corpora discovered")
            return 0
        source_paths = discovered
        cases = load_path_cases(discovered, full)
    else:
        if not SILESIA.exists():
            print("standard corpus report: missing silesia-small.tar")
            return 0
        source_paths = [SILESIA]
        cases = load_cases(full, suite)
    if case_limit is not None:
        cases = cases[:case_limit]
    rows: list[str] = []
    with tempfile.TemporaryDirectory() as td:
        root = pathlib.Path(td)
        print(HEADER)
        for index, (label, data) in enumerate(cases):
            row = run_case(label, data, root, index)
            rows.append(row)
            print(row)
    if markdown_path is not None:
        write_markdown(rows, markdown_path, suite or standard_suite, full, len(corpus_paths) != 0 or standard_suite, source_paths, case_limit)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
