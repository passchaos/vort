#!/usr/bin/env python3
"""Gate zlib relaxed decode options report budgets."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REPORT = ROOT / "zig-out" / "vort-zlib-relaxed-report.json"


def int_field(data: dict[str, Any], key: str) -> int | None:
    value = data.get(key)
    return value if isinstance(value, int) else None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--summary", type=Path)
    args = parser.parse_args()

    report = json.loads(args.report.read_text())
    if report.get("schema") != "vort.zlib_relaxed_report":
        raise SystemExit(f"unexpected report schema: {report.get('schema')}")
    checks = {
        "strict_rejections": int_field(report, "strict_rejections") == 2,
        "relaxed_successes": int_field(report, "relaxed_successes") >= 5,
        "dictionary_successes": int_field(report, "dictionary_successes") == 2,
        "zlib_concatenated_successes": int_field(report, "zlib_concatenated_successes") >= 3,
        "limited_rejections": int_field(report, "limited_rejections") == 1,
        "gzip_strict_rejections": int_field(report, "gzip_strict_rejections") == 3,
        "gzip_relaxed_successes": int_field(report, "gzip_relaxed_successes") >= 6,
        "gzip_concatenated_successes": int_field(report, "gzip_concatenated_successes") == 2,
        "gzip_decoder_successes": int_field(report, "gzip_decoder_successes") == 4,
        "gzip_limited_rejections": int_field(report, "gzip_limited_rejections") == 1,
    }
    ok = all(checks.values())
    summary = {
        "schema": "vort.zlib_relaxed_report_gate",
        "schema_version": 1,
        "ok": ok,
        "report": str(args.report),
        "checks": checks,
    }
    if args.summary:
        args.summary.parent.mkdir(parents=True, exist_ok=True)
        args.summary.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    if not ok:
        failed = ",".join(name for name, passed in checks.items() if not passed)
        print(f"zlib_relaxed_report_gate=failed checks={failed}", file=sys.stderr)
        return 1
    print("zlib_relaxed_report_gate=ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
