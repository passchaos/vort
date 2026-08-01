#!/usr/bin/env python3
"""Run native LZ4/Zstd library probes and retain audit artifacts."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True

OK_RE = re.compile(r"^(?P<name>[a-z0-9_]+)_ok cases=(?P<cases>[0-9]+)$")


def run_probe(label: str, exe: str) -> dict[str, object]:
    completed = subprocess.run(
        [exe],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    output = completed.stdout
    cases: int | None = None
    marker: str | None = None
    for line in output.splitlines():
        match = OK_RE.match(line.strip())
        if match:
            marker = match.group("name")
            cases = int(match.group("cases"))
            break
    ok = completed.returncode == 0 and cases is not None
    return {
        "label": label,
        "executable": exe,
        "ok": ok,
        "returncode": completed.returncode,
        "cases": cases,
        "marker": marker or "",
        "output": output,
    }


def write_markdown(path: Path, summary: dict[str, object]) -> None:
    lines = [
        "# Native codec probes",
        "",
        f"- ok: `{str(summary['ok']).lower()}`",
        f"- total cases: `{summary['total_cases']}`",
        "",
        "| probe | ok | cases | returncode |",
        "| --- | --- | ---: | ---: |",
    ]
    for probe in summary["probes"]:  # type: ignore[index]
        lines.append(
            "| {label} | `{ok}` | {cases} | {returncode} |".format(
                label=probe["label"],
                ok=str(probe["ok"]).lower(),
                cases=probe["cases"] if probe["cases"] is not None else "",
                returncode=probe["returncode"],
            )
        )
    lines.append("")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", required=True, type=Path)
    parser.add_argument("--markdown", required=True, type=Path)
    parser.add_argument("lz4_probe")
    parser.add_argument("lz4_dictionary_probe")
    parser.add_argument("zstd_frame_probe")
    parser.add_argument("zstd_dictionary_probe")
    args = parser.parse_args()

    probes = [
        run_probe("lz4-native-probe", args.lz4_probe),
        run_probe("lz4-native-dictionary-probe", args.lz4_dictionary_probe),
        run_probe("zstd-native-frame-probe", args.zstd_frame_probe),
        run_probe("zstd-native-dictionary-probe", args.zstd_dictionary_probe),
    ]
    summary: dict[str, object] = {
        "schema": "vort.native_codec_probes",
        "ok": all(bool(probe["ok"]) for probe in probes),
        "probe_count": len(probes),
        "total_cases": sum(int(probe["cases"] or 0) for probe in probes),
        "probes": probes,
    }

    args.json.parent.mkdir(parents=True, exist_ok=True)
    args.json.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    write_markdown(args.markdown, summary)
    print(
        "native_codec_probes_dashboard=ok" if summary["ok"] else "native_codec_probes_dashboard=failed",
        f"probes={summary['probe_count']}",
        f"cases={summary['total_cases']}",
    )
    return 0 if summary["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
