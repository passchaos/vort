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

PROBE_CAPABILITIES = {
    "lz4-native-probe": {
        "block",
        "bounded-limits",
        "checksum",
        "chunked",
        "dictionary",
        "dictionary-set",
        "incremental",
        "lib-generated",
        "malformed",
        "native-generated",
        "skippable",
    },
    "lz4-native-dictionary-probe": {
        "bounded-limits",
        "checksum",
        "chunked",
        "dictionary",
        "dictionary-set",
        "incremental",
        "malformed",
    },
    "zstd-native-frame-probe": {
        "bounded-limits",
        "checksum",
        "chunked",
        "huffman",
        "incremental",
        "lib-generated",
        "malformed",
        "native-generated",
        "sequence-tables",
        "skippable",
    },
    "zstd-native-dictionary-probe": {
        "bounded-limits",
        "checksum",
        "chunked",
        "dictionary",
        "dictionary-set",
        "incremental",
        "malformed",
        "sequence-tables",
    },
}

CAPABILITY_ORDER = (
    "lib-generated",
    "native-generated",
    "incremental",
    "chunked",
    "dictionary",
    "dictionary-set",
    "skippable",
    "malformed",
    "checksum",
    "bounded-limits",
    "huffman",
    "sequence-tables",
    "block",
)


def probe_category(label: str) -> tuple[str, str]:
    if label.startswith("lz4-"):
        codec = "lz4"
    elif label.startswith("zstd-"):
        codec = "zstd"
    else:
        raise ValueError(f"unknown native codec probe label: {label}")
    surface = "dictionary" if "dictionary" in label else "frame"
    return codec, surface


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


def coverage_summary(probes: list[dict[str, object]]) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for codec in ("lz4", "zstd"):
        for surface in ("frame", "dictionary"):
            matching = [probe for probe in probes if probe_category(str(probe["label"])) == (codec, surface)]
            cases = sum(int(probe["cases"] or 0) for probe in matching)
            ok_count = sum(1 for probe in matching if bool(probe["ok"]))
            rows.append(
                {
                    "codec": codec,
                    "surface": surface,
                    "present": len(matching) != 0,
                    "ok": len(matching) != 0 and ok_count == len(matching),
                    "probe_count": len(matching),
                    "ok_probe_count": ok_count,
                    "cases": cases,
                }
            )
    return rows




def capability_summary(probes: list[dict[str, object]]) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for capability in CAPABILITY_ORDER:
        matching = [
            probe
            for probe in probes
            if capability in PROBE_CAPABILITIES.get(str(probe["label"]), set())
        ]
        cases = sum(int(probe["cases"] or 0) for probe in matching)
        ok_count = sum(1 for probe in matching if bool(probe["ok"]))
        rows.append(
            {
                "capability": capability,
                "present": len(matching) != 0,
                "ok": len(matching) != 0 and ok_count == len(matching),
                "probe_count": len(matching),
                "ok_probe_count": ok_count,
                "cases": cases,
            }
        )
    return rows

def write_markdown(path: Path, summary: dict[str, object]) -> None:
    lines = [
        "# Native codec probes",
        "",
        f"- ok: `{str(summary['ok']).lower()}`",
        f"- total cases: `{summary['total_cases']}`",
        "",
        "## Coverage",
        "",
        "| codec | surface | present | ok | probes | cases |",
        "| --- | --- | --- | --- | ---: | ---: |",
    ]
    for row in summary["coverage"]:  # type: ignore[index]
        lines.append(
            "| {codec} | {surface} | `{present}` | `{ok}` | {ok_probe_count}/{probe_count} | {cases} |".format(
                codec=row["codec"],
                surface=row["surface"],
                present=str(row["present"]).lower(),
                ok=str(row["ok"]).lower(),
                ok_probe_count=row["ok_probe_count"],
                probe_count=row["probe_count"],
                cases=row["cases"],
            )
        )
    lines.extend(
        [
            "",
            "## Capabilities",
            "",
            "| capability | present | ok | probes | cases |",
            "| --- | --- | --- | ---: | ---: |",
        ]
    )
    for row in summary["capabilities"]:  # type: ignore[index]
        lines.append(
            "| {capability} | `{present}` | `{ok}` | {ok_probe_count}/{probe_count} | {cases} |".format(
                capability=row["capability"],
                present=str(row["present"]).lower(),
                ok=str(row["ok"]).lower(),
                ok_probe_count=row["ok_probe_count"],
                probe_count=row["probe_count"],
                cases=row["cases"],
            )
        )
    lines.extend(
        [
            "",
            "## Probes",
            "",
            "| probe | ok | cases | returncode |",
            "| --- | --- | ---: | ---: |",
        ]
    )
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
    coverage = coverage_summary(probes)
    capabilities = capability_summary(probes)
    summary: dict[str, object] = {
        "schema": "vort.native_codec_probes",
        "schema_version": 1,
        "ok": all(bool(probe["ok"]) for probe in probes),
        "capabilities": capabilities,
        "capability_count": len(capabilities),
        "coverage": coverage,
        "coverage_count": len(coverage),
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
