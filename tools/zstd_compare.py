#!/usr/bin/env python3
import argparse
import csv
import pathlib
import shutil
import subprocess
import tempfile
from typing import Any

ROOT = pathlib.Path(__file__).resolve().parents[1]
ZSTD = shutil.which("zstd")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("items", nargs="*", help="optional vort CLI artifact followed by paths")
    parser.add_argument("--csv", type=pathlib.Path)
    parser.add_argument("--markdown", type=pathlib.Path)
    parser.add_argument("--optimize", default="unknown")
    return parser.parse_args()


def zstd_version() -> str:
    if not ZSTD:
        return "missing"
    proc = subprocess.run([ZSTD, "--version"], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    return proc.stdout.strip()


def command_output(args: list[str]) -> str:
    proc = subprocess.run(args, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    return proc.stdout.strip() if proc.returncode == 0 else "unknown"


def cpu_model() -> str:
    cpuinfo = pathlib.Path("/proc/cpuinfo")
    if cpuinfo.exists():
        for line in cpuinfo.read_text(errors="ignore").splitlines():
            if line.startswith("model name"):
                return line.split(":", 1)[1].strip()
    return "unknown"


def metadata(optimize: str) -> dict[str, str]:
    return {
        "zstd_version": zstd_version(),
        "vort_commit": command_output(["git", "rev-parse", "--short", "HEAD"]),
        "zig_version": command_output(["zig", "version"]),
        "cpu_model": cpu_model(),
        "optimize": optimize,
    }


def write_outputs(args: argparse.Namespace, rows: list[dict[str, Any]], meta: dict[str, str]) -> None:
    if args.csv:
        args.csv.parent.mkdir(parents=True, exist_ok=True)
        with args.csv.open("w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=["path", "input_bytes", "zstd_bytes", "vort_raw_fixed_bytes", "vort_over_zstd", "zstd_version", "vort_commit", "zig_version", "cpu_model", "optimize"])
            writer.writeheader()
            writer.writerows(rows)

    if args.markdown:
        args.markdown.parent.mkdir(parents=True, exist_ok=True)
        lines = [
            "# Vort vs zstd size smoke",
            "",
            f"- zstd: `{meta['zstd_version']}`",
            f"- Vort commit: `{meta['vort_commit']}`",
            f"- Zig version: `{meta['zig_version']}`",
            f"- CPU: `{meta['cpu_model']}`",
            f"- Optimize: `{meta['optimize']}`",
            "- zstd command: `zstd -q -f -1 -o <tmp> <path>`",
            "- Vort command: `vort encode-raw-fixed-hex <utf8 text>`",
            "",
            "| path | input bytes | zstd bytes | Vort raw fixed bytes | Vort / zstd |",
            "| --- | ---: | ---: | ---: | ---: |",
        ]
        for row in rows:
            ratio = row["vort_over_zstd"]
            ratio_text = "n/a" if not isinstance(ratio, float) or ratio < 0 else f"{ratio:.4f}"
            lines.append(
                f"| `{row['path']}` | {row['input_bytes']} | {row['zstd_bytes']} | {row['vort_raw_fixed_bytes']} | {ratio_text} |"
            )
        args.markdown.write_text("\n".join(lines) + "\n")


def main() -> int:
    args = parse_args()
    if not ZSTD:
        print("zstd compare: zstd=missing")
        write_outputs(args, [], metadata(args.optimize))
        return 0

    cli = pathlib.Path(args.items[0]) if args.items and pathlib.Path(args.items[0]).exists() else None
    path_args = args.items[1:] if cli else args.items
    paths = [ROOT / "README.md", ROOT / "docs" / "roadmap.md"] if not path_args else [pathlib.Path(p) for p in path_args]

    rows: list[dict[str, Any]] = []
    meta = metadata(args.optimize)
    print("path,input_bytes,zstd_bytes,vort_raw_fixed_bytes")
    for path in paths:
        data = path.read_bytes()
        with tempfile.NamedTemporaryFile() as out:
            subprocess.run([ZSTD, "-q", "-f", "-1", "-o", out.name, str(path)], check=True)
            zstd_size = pathlib.Path(out.name).stat().st_size
        if cli:
            # CLI command accepts text payloads; decode as UTF-8 for documentation/source corpora.
            hex_out = subprocess.run(
                [str(cli), "encode-raw-fixed-hex", data.decode("utf-8")],
                cwd=ROOT,
                check=True,
                text=True,
                stdout=subprocess.PIPE,
            ).stdout.strip()
            vort_size = len(bytes.fromhex(hex_out))
        else:
            vort_size = -1
        ratio = (vort_size / zstd_size) if zstd_size and vort_size >= 0 else -1.0
        rows.append(
            {
                "path": str(path),
                "input_bytes": len(data),
                "zstd_bytes": zstd_size,
                "vort_raw_fixed_bytes": vort_size,
                "vort_over_zstd": ratio,
                **meta,
            }
        )
        print(f"{path},{len(data)},{zstd_size},{vort_size}")

    write_outputs(args, rows, meta)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
