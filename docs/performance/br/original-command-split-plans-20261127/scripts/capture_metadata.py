"""Read small receipts only. Never scan source payload or mark a live gate green."""
from pathlib import Path
from datetime import datetime, timezone
from common import PACKAGE, exit_value, read_json, write_json


def main():
    plan = read_json(PACKAGE / "package-plan.json")
    gates = []
    for group in plan["groups"]:
        for relative in group.get("final_exits", []):
            path = Path(group["root"]) / relative
            value = exit_value(path)
            gates.append({"group": group["id"], "path": str(path),
                          "state": "running-or-pending" if value is None else "terminal",
                          "actual_exit": value})
    public = read_json(Path(next(g["root"] for g in plan["groups"] if g["id"] == "public")) / "summary.json")
    performance = read_json(Path(plan["performance"]["root"]) / plan["performance"]["status_receipt"])
    observed = {
        "schema": "vort.original-command-split-plans.metadata-snapshot.v1",
        "captured_utc": datetime.now(timezone.utc).isoformat(),
        "phase": "static-preparation", "HEAVY": 0,
        "final_verdict_claimed": False, "gates": gates,
        "public": {target: {"tests_passed": public[target]["tests_passed"],
                             "sweep": public[target]["sweep"]}
                   for target in ("native", "wasi")},
        "performance_status_receipt": plan["performance"],
        "performance_observed_metadata": performance,
        "source_payload_scanned": False, "archive_compressed": False,
    }
    write_json(PACKAGE / "metadata-snapshot.json", observed)
    print("Small receipt snapshot saved; no final verdict or source identity inferred")


if __name__ == "__main__":
    main()
