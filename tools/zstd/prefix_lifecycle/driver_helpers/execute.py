"""Execute independent probe scripts and retain physical result receipts."""
from __future__ import annotations
import copy
import json
from pathlib import Path
import subprocess
from .common import artifact, require, write_json
from .validation import validate_case


def run_case(root: Path, target: str, executable: Path, original: dict, library, receipt, expected_executable: dict):
    case = copy.deepcopy(original)
    directory = root / target / case["name"]
    directory.mkdir(parents=True, exist_ok=True)
    for index, stage in enumerate(case["config"]["stages"]):
        stage["output_path"] = str((directory / f"stage-{index:02d}.output").resolve())
    config_path = directory / "config.json"
    config_artifact = write_json(config_path, case["config"])
    stdout_path, stderr_path = directory / "probe.json", directory / "stderr.log"
    result = {"name": case["name"], "target": target, "api": case["config"]["api"],
              "entry": case["config"]["entry"], "config": config_artifact,
              "reference_recipe_names": case["reference_recipe_names"], "adapters": case["adapters"],
              "equivalence_group": case.get("equivalence_group")}
    command = [str(executable.resolve()), str(config_path)]
    result["command"] = command
    result["expected_executable"] = expected_executable
    try:
        require(target in ("native", "x86"), "Unknown executable target")
        actual_executable = artifact(executable)
        require(actual_executable == expected_executable, "Executed binary path/size/SHA differs from this target's manifest")
        require(command[0] == expected_executable["path"], "Command executable differs from this target's manifest")
        with executable.open("rb") as binary:
            elf = binary.read(64)
        expected_class, expected_machine = (2, 62) if target == "native" else (1, 3)
        require(elf[:4] == b"\x7fELF" and len(elf) >= 20 and elf[4] == expected_class and elf[5] == 1
                and int.from_bytes(elf[18:20], "little") == expected_machine,
                "Expected an actual x86_64 ELF64 native binary or x86 ELF32 target binary")
        result["executed_binary"] = actual_executable
        result["command_manifest_matches"] = True
        with stdout_path.open("w") as stdout, stderr_path.open("w") as stderr:
            completed = subprocess.run(command, stdout=stdout, stderr=stderr, timeout=45)
        result["exit_code"] = completed.returncode
        result["probe"] = artifact(stdout_path)
        result["stderr"] = artifact(stderr_path)
        require(completed.returncode == 0, f"Probe process exited {completed.returncode}; see {stderr_path}")
        report = json.loads(stdout_path.read_text())
        require(report.get("schema") == "vort.zstd.prefix-lifecycle.probe.v1", "Unexpected prefix probe schema")
        expected_arch, expected_bits = ("x86_64", 64) if target == "native" else ("x86", 32)
        require(report.get("target") == expected_arch and report.get("pointer_bits") == expected_bits,
                f"The {target} probe must report its actual {expected_arch} target and {expected_bits}-bit pointers")
        require(command[0] == expected_executable["path"], "Probe command was changed during execution")
        for key, value in case["config"].items():
            if key != "stages":
                require(report["config"].get(key) == value, f"Probe did not retain requested config {key}")
        result["runtime"] = {name: report.get(name) for name in ("target", "pointer_bits", "cpu_model", "build_mode", "zig_version")}
        result["validation"] = validate_case(case, report, library, receipt)
        result["passed"] = True
        if case.get("prepared_reference"):
            result["prepared_reference"] = case["prepared_reference"]
    except Exception as error:
        result["passed"] = False
        result["failure"] = {"type": type(error).__name__, "message": str(error)}
        if stdout_path.is_file():
            result["probe"] = artifact(stdout_path)
        if stderr_path.is_file():
            result["stderr"] = artifact(stderr_path)
    result["receipt"] = write_json(directory / "validation.json", result)
    return result


def equivalence_checks(results):
    groups = {}
    for result in results:
        if result["passed"] and result.get("equivalence_group"):
            hashes = [stage["artifact"]["sha256"] for stage in result["validation"]["stages"] if "encoded" in stage["validation"]]
            groups.setdefault((result["target"], result["equivalence_group"]), []).append((result["name"], hashes))
    checks = []
    for (target, group), values in sorted(groups.items()):
        hashes = [digest for _, items in values for digest in items]
        checks.append({"target": target, "group": group, "cases": [name for name, _ in values],
                       "observed_frame_hashes": hashes, "passed": len(values) == 2 and len(hashes) == 4 and len(set(hashes)) == 1})
    return checks
