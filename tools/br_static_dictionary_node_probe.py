#!/usr/bin/env python3
"""Probe Brotli static-dictionary candidates against Node and Vort."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CANDIDATES = ROOT / "zig-out" / "vort-br-static-dictionary-candidates.json"


def run(args: list[str], *, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(args, check=check, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def node_compress(payload: bytes, quality: int, lgwin: int) -> bytes:
    script = (
        "const z=require('zlib');"
        "const payload=Buffer.from(process.argv[1], 'hex');"
        "const quality=Number(process.argv[2]);"
        "const lgwin=Number(process.argv[3]);"
        "const out=z.brotliCompressSync(payload,{params:{"
        "[z.constants.BROTLI_PARAM_QUALITY]:quality,"
        "[z.constants.BROTLI_PARAM_LGWIN]:lgwin"
        "}});"
        "process.stdout.write(out);"
    )
    return run(["node", "-e", script, payload.hex(), str(quality), str(lgwin)]).stdout


def node_decode(payload: bytes) -> bytes:
    script = (
        "const z=require('zlib');"
        "const payload=Buffer.from(process.argv[1], 'hex');"
        "process.stdout.write(z.brotliDecompressSync(payload));"
    )
    return run(["node", "-e", script, payload.hex()]).stdout


def load_candidates(path: Path) -> dict[str, Any]:
    report = json.loads(path.read_text())
    if report.get("schema") != "vort.br_static_dictionary_candidate_report":
        raise AssertionError("unexpected candidate report schema")
    candidates = report.get("candidates")
    if not isinstance(candidates, list):
        raise AssertionError("candidate report candidates must be a list")
    return report


def decode_with_vort(cli: Path, compressed: bytes, expected: bytes, root: Path) -> tuple[bool, str]:
    with tempfile.TemporaryDirectory(prefix="vort-br-node-probe-") as td:
        tmp = Path(td)
        br_path = tmp / "candidate.br"
        out_path = tmp / "candidate.out"
        br_path.write_bytes(compressed)
        result = subprocess.run(
            [str(cli), "decode-br-file-to", str(br_path), str(out_path), str(len(expected))],
            cwd=root,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        if result.returncode != 0:
            return False, result.stdout.decode(errors="replace").splitlines()[0] if result.stdout else "vort decode failed"
        actual = out_path.read_bytes()
        if actual != expected:
            return False, "vort output mismatch"
        return True, ""


def probe_candidates(cli: Path, report: dict[str, Any], limit: int, quality: int, lgwin: int) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    candidates = report["candidates"][:limit]
    for index, candidate in enumerate(candidates):
        expected = candidate["transformed_word"].encode()
        compressed = node_compress(expected, quality, lgwin)
        decoded_by_node = node_decode(compressed)
        if decoded_by_node != expected:
            classification = "node_output_mismatch"
            vort_ok = False
            error = "node output mismatch"
        else:
            vort_ok, error = decode_with_vort(cli, compressed, expected, ROOT)
            classification = "vort_accepts_node_frame" if vort_ok else "vort_rejects_node_frame"
        rows.append(
            {
                "index": index,
                "transform": candidate["transform"],
                "copy_len": candidate["copy_len"],
                "word_index": candidate["word_index"],
                "raw_word": candidate["raw_word"],
                "candidate_word": candidate["transformed_word"],
                "transform_kind": candidate["transform_kind"],
                "quality": quality,
                "lgwin": lgwin,
                "br_bytes": len(compressed),
                "br_hex": compressed.hex(),
                "node_ok": decoded_by_node == expected,
                "vort_ok": vort_ok,
                "classification": classification,
                "error": error,
            }
        )
    return rows


def build_report(candidate_report: dict[str, Any], rows: list[dict[str, Any]], limit: int, quality: int, lgwin: int) -> dict[str, Any]:
    return {
        "schema": "vort.br_static_dictionary_node_probe",
        "schema_version": 1,
        "ok": all(row["node_ok"] for row in rows),
        "candidate_count": candidate_report["candidate_count"],
        "all_candidates": len(rows) == candidate_report["candidate_count"],
        "limit": limit,
        "quality": quality,
        "lgwin": lgwin,
        "probed_count": len(rows),
        "node_decode_successes": sum(1 for row in rows if row["node_ok"]),
        "vort_decode_successes": sum(1 for row in rows if row["vort_ok"]),
        "vort_decode_failures": sum(1 for row in rows if not row["vort_ok"]),
        "rows": rows,
    }


def write_json(path: Path, report: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")


def write_markdown(path: Path, report: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Brotli static dictionary Node probe",
        "",
        f"- Candidate entries: {report['candidate_count']}",
        f"- Probed entries: {report['probed_count']}",
        f"- Node decode successes: {report['node_decode_successes']}",
        f"- Vort decode successes: {report['vort_decode_successes']}",
        f"- Vort decode failures: {report['vort_decode_failures']}",
        "",
        "| # | Transform | Copy length | Word index | Candidate | Brotli bytes | Classification | Error |",
        "| ---: | ---: | ---: | ---: | --- | ---: | --- | --- |",
    ]
    for row in report["rows"]:
        lines.append(
            f"| {row['index']} | {row['transform']} | {row['copy_len']} | {row['word_index']} | `{row['candidate_word']}` | {row['br_bytes']} | `{row['classification']}` | `{row['error']}` |"
        )
    path.write_text("\n".join(lines) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("cli", type=Path, help="built Vort CLI executable")
    parser.add_argument("--candidates", type=Path, default=DEFAULT_CANDIDATES)
    parser.add_argument("--json", type=Path)
    parser.add_argument("--markdown", type=Path)
    parser.add_argument("--limit", type=int, default=48)
    parser.add_argument("--all-candidates", action="store_true", help="probe every candidate in the candidate report")
    parser.add_argument("--quality", type=int, default=5)
    parser.add_argument("--lgwin", type=int, default=10)
    parser.add_argument("--require-vort-ok", action="store_true", help="fail if any probed Node frame is not accepted by Vort")
    args = parser.parse_args()

    candidate_report = load_candidates(args.candidates)
    limit = candidate_report["candidate_count"] if args.all_candidates else args.limit
    rows = probe_candidates(args.cli.resolve(), candidate_report, limit, args.quality, args.lgwin)
    report = build_report(candidate_report, rows, limit, args.quality, args.lgwin)
    if args.json is not None:
        write_json(args.json, report)
    if args.markdown is not None:
        write_markdown(args.markdown, report)
    status = "ok"
    returncode = 0
    if args.require_vort_ok and report["vort_decode_failures"] != 0:
        status = "fail"
        returncode = 1
    print(
        f"br_static_dictionary_node_probe={status} "
        f"probed={report['probed_count']} vort_ok={report['vort_decode_successes']} "
        f"vort_fail={report['vort_decode_failures']}"
    )
    return returncode


if __name__ == "__main__":
    raise SystemExit(main())
