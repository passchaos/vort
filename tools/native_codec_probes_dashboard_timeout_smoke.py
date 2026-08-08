#!/usr/bin/env python3
"""Smoke-test native codec probe dashboard timeout handling."""

from __future__ import annotations

import json
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DASHBOARD = ROOT / "tools" / "native_codec_probes_dashboard.py"


def write_probe(path: Path, marker: str, cases: int, capabilities: list[str], *, sleep_seconds: float = 0.0) -> None:
    lines = [
        "#!/usr/bin/env python3",
        "import time",
        f"time.sleep({sleep_seconds!r})",
        f"print('{marker}_ok cases={cases}')",
    ]
    for capability in capabilities:
        lines.append(f"print('{marker}_coverage capability={capability} cases={cases}')")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="vort-native-codec-timeout-") as tmpdir:
        root = Path(tmpdir)
        fast = root / "fast.py"
        slow = root / "slow.py"
        write_probe(fast, "lz4_native_probe", 1, ["block", "bounded-limits"])
        write_probe(slow, "zstd_native_frame_probe", 1, ["huffman"], sleep_seconds=2.0)
        json_path = root / "summary.json"
        md_path = root / "summary.md"

        completed = subprocess.run(
            [
                sys.executable,
                str(DASHBOARD),
                "--json",
                str(json_path),
                "--markdown",
                str(md_path),
                "--probe-timeout",
                "0.25",
                str(fast),
                str(fast),
                str(slow),
                str(fast),
            ],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )
        if completed.returncode == 0:
            raise AssertionError(f"expected timeout smoke to fail, got stdout={completed.stdout!r}")
        data = json.loads(json_path.read_text())
        assert data["schema"] == "vort.native_codec_probes"
        assert data["ok"] is False
        probes = {probe["label"]: probe for probe in data["probes"]}
        timed_out = probes["zstd-native-frame-probe"]
        assert timed_out["ok"] is False
        assert timed_out["timed_out"] is True
        assert timed_out["returncode"] == -1
        assert timed_out["cases"] is None
        assert "timed out" in timed_out["output"]
        assert probes["lz4-native-probe"]["timed_out"] is False
        markdown = md_path.read_text()
        assert "timed out" in markdown
        print("native_codec_probes_dashboard_timeout_smoke=ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
