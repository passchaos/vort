"""Small metadata helpers; no codec, build or implicit heavy operation."""
import json
from pathlib import Path

PACKAGE = Path(__file__).resolve().parents[1]


def read_json(path):
    return json.loads(Path(path).read_text())


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + "\n")


def exit_value(path):
    path = Path(path)
    if not path.exists():
        return None
    payload = read_json(path)
    values = [payload[key] for key in ("exit_code", "returncode") if key in payload]
    if not values or any(not isinstance(value, int) for value in values):
        raise ValueError(f"No actual integer exit in {path}")
    if len(set(values)) != 1:
        raise ValueError(f"Conflicting actual exits in {path}")
    return values[0]


def validate_release(release, require_original_record=True):
    if release.get("schema") != "vort.original-command-split-plans.archive-release.v1":
        raise ValueError("Wrong Root release schema")
    if release.get("issued_by") != "/root":
        raise ValueError("Archive release must be issued by Root")
    if release.get("archive_released") is not True:
        raise ValueError("Archive has not been released")
    if release.get("timing_window_closed") is not True:
        raise ValueError("Timing window is not closed")
    verdict = release.get("final_verdict", {})
    if verdict.get("status") not in ("accepted", "rejected", "partial"):
        raise ValueError("Root final verdict remains pending")
    if not verdict.get("record") or (require_original_record and not Path(verdict["record"]).is_file()):
        raise ValueError("Final verdict must reference an existing frozen record")
    return release


def require_release(path):
    return validate_release(read_json(path))


def require_terminal_final_gates(plan):
    exits = []
    for group in plan["groups"]:
        root = Path(group["root"])
        for relative in group.get("final_exits", []):
            path = root / relative
            value = exit_value(path)
            if value is None:
                raise ValueError(f"Gate still pending; no actual exit: {path}")
            exits.append({"group": group["id"], "receipt": str(path), "actual_exit": value})
    return exits
