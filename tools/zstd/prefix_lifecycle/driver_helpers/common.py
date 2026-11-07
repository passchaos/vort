"""Physical artifacts and source manifests for the prefix lifecycle driver."""
from __future__ import annotations
import hashlib
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]
ROOT = HERE.parents[2]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def artifact(path: Path | str) -> dict:
    path = Path(path).resolve()
    data = path.read_bytes()
    return {"path": str(path), "size": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def write_json(path: Path, value) -> dict:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")
    return artifact(path)


def sources() -> dict:
    files = [item for item in HERE.rglob("*") if item.is_file() and item.suffix in (".py", ".zig", ".md", ".jsonl", ".js")]
    files.extend((ROOT / "src/root.zig", ROOT / "src/zstd.zig", ROOT / "src/core.zig"))
    for relative in ("src/zstd/prefix", "src/zstd/incremental/encoder", "src/zstd/incremental_parallel"):
        files.extend((ROOT / relative).rglob("*.zig"))
    return {str(path.relative_to(ROOT)): artifact(path) for path in sorted(set(files))}


def require(value, detail):
    if not value:
        raise AssertionError(detail)


def materialize(root: Path, name: str, data: bytes) -> str:
    path = root / "prepared" / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return str(path.resolve())
