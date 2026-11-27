#!/usr/bin/env python3
"""Independent pilot raw points/settings/rejection from captured package data only."""
import sys
sys.dont_write_bytecode = True
import argparse
import hashlib
import json
import math
from pathlib import Path
import tarfile


def require(condition, message):
    if not condition: raise ValueError(message)


def geometric(values):
    return math.exp(sum(math.log(value) for value in values) / len(values))


def check(package):
    binding = json.loads((package / "evidence-manifest.json").read_bytes())
    prior = json.loads((package / "verification-original.stdout.json").read_bytes())
    require(prior["inventory_sha_verified"] is True and prior["codec_build_producer_import_or_replay_executed"] is False,
            "Preserved complete archive/source SHA verification required")
    require(binding["selected_phases"] == ["pilot"], "Only original rejected pilot is selected")
    entries = binding["entries"];documents = {}
    wanted = {"pilot/run-manifest.json", "pilot/summary.json", "release-pilot.json", "protocols/pilot.json", "fixtures.json",
              "execution-bindings.json", "root-pilot-terminal.json", "SOURCE_READY.json"}
    wanted.update(name for name in entries if name.startswith("pilot/runs/") and name.endswith(".json"))
    with tarfile.open(package / binding["archive"]["path"], "r:xz") as archive:
        for member in archive:
            if member.name in wanted:
                data = archive.extractfile(member).read()
                require(len(data) == entries[member.name]["bytes"] and hashlib.sha256(data).hexdigest() == entries[member.name]["sha256"],
                        "Original raw JSON SHA changed")
                documents[member.name] = json.loads(data)
    require(set(documents) == wanted, "All original raw48 and protocol/binding documents required")
    raw, summary, protocol = (documents[name] for name in ("pilot/run-manifest.json", "pilot/summary.json", "protocols/pilot.json"))
    require(raw["completed"] is True and raw["terminal"] is True and raw["protocol"] == protocol
            and raw["release"] == documents["release-pilot.json"], "Original phase protocol/release/full matrix drifted")
    terminal = documents["root-pilot-terminal.json"]
    require(terminal["actual_exit_code"] == 0 and terminal["argv"] == ["python3", "-B", binding["original_epoch_root"] + "/sampler.py", "--phase", "pilot", "--release", binding["original_epoch_root"] + "/release-pilot.json"],
            "Original terminal receipt differs")
    require(protocol["rounds"] == 2 and protocol["GM_min"] == 1.03 and protocol["every_row_point_floor"] == .98
            and protocol["no_weak_extra_rounds"] is True and len(raw["pairs"]) == 24 and len(raw["attempts"]) == 48, "Original pilot gates/counts unchanged")
    original = Path(binding["original_epoch_root"])
    def relative(path):
        p = Path(path);require(p.is_absolute() and ".." not in p.parts and p.is_relative_to(original), "Unregistered original path")
        return str(p.relative_to(original))
    fixtures = {row["case"]: row for row in documents["fixtures.json"]}
    cases = protocol["case_order"];require(len(cases) == len(set(cases)) == 12, "Original12 unique rows required")
    require([(pair["round"], pair["case"]) for pair in raw["pairs"]] == [(index, case) for index in range(2) for case in cases], "Original AB/BA full order required")
    attempts = iter(raw["attempts"]);seen = set();ratios = {case: [] for case in cases};common_host = None
    binaries = documents["execution-bindings.json"]
    for pair in raw["pairs"]:
        order = ["baseline", "candidate"] if pair["round"] == 0 else ["candidate", "baseline"]
        require(pair["order"] == order, "AB then BA must retain paired chronology")
        ns = {}
        for variant in order:
            attempt = next(attempts)
            require((attempt["round"], attempt["case"], attempt["variant"], attempt["actual_exit_code"]) == (pair["round"], pair["case"], variant, 0), "Attempt/pair/exit identity differs")
            output = relative(attempt["output"])
            require(output not in seen and output == f"pilot/runs/{pair['round']:02d}-{pair['case']}-{variant}.json", "Unique canonical original raw path required")
            seen.add(output);value = documents[output];fixture = fixtures[pair["case"]];binary = binaries[variant]
            wire = relative(attempt["initial_complete_wire"])
            expected_argv = ["taskset", "-c", "2", binary["ELF"], "--input", fixture["path"], "--output", attempt["output"],
                "--source-revision", binary["revision"], "--iterations", "1", "--level", "3", "--wire-output", attempt["initial_complete_wire"]]
            require(attempt["argv"] == expected_argv, "Actual allocating L3 argv differs")
            require(value["source_revision"] == binary["revision"] and value["input_path"] == fixture["path"]
                    and value["input_sha256"] == fixture["sha256"] and value["input_bytes"] == fixture["bytes"] == 65536
                    and entries[relative(fixture["path"])]["sha256"] == fixture["sha256"], "Original source/input identity differs")
            require(value["api"] == "encodeFrameWithLevelAlloc" and value["level"] == 3
                    and value["public_primary_policy"] == {"strategy": "greedy", "match_search_budget": 24, "rep_beam_search": False, "selection": "fast_compressed"}
                    and value["dictionary_path"] is None and value["dictionary_sha256"] is None
                    and value["allocator"] == "std.process.Init.gpa" and value["iterations"] == 1
                    and value["warmup_owned_encode_free_calls"] == 1 and value["all_raw_samples_retained"] is True,
                    "Common public greedy24/repfalse/warm1 allocating lifecycle differs")
            info = value["provenance"]
            expected_info = {"optimize": "ReleaseFast", "target_arch": "x86_64", "target_os": "linux", "target_abi": "gnu",
                "target_cpu": "skylake+pku+sgx", "cpu_affinity": "2", "affinity_cpu_count": 1,
                "benchmark_threads": 1, "codec_thread_policy": "single", "executable_sha256": binary["sha256"]}
            require(all(info[key] == expected for key, expected in expected_info.items()), "Actual ELF/target/CPU/thread provenance differs")
            host = {key: val for key, val in info.items() if key not in ("command", "executable_sha256")}
            require(common_host is None or common_host == host, "Actual paired host metadata differs");common_host = host
            require(entries[relative(binary["ELF"])]["sha256"] == binary["sha256"], "Captured actual ELF SHA differs")
            require(entries[wire]["sha256"] == value["warm_wire_sha256"] == pair["processes"][variant]["wire_sha256"]
                    and entries[wire]["bytes"] == value["warm_wire_bytes"] == pair["processes"][variant]["wire_bytes"]
                    and value["mix"] == value["warm_wire_bytes"], "Complete initial warm wire/mix differs")
            for key in ("stdout", "stderr"):require(relative(attempt[key]) in entries, "All original streams retained")
            time = value["continuous_owned_encode_mix_free_ns"]
            require(type(time) is int and time > 0 and time == pair["processes"][variant]["ns"], "Every raw ns must equal own pair slot")
            ns[variant] = time
        require(pair["processes"]["baseline"]["wire_sha256"] == pair["processes"]["candidate"]["wire_sha256"], "No initial wire regression allowed")
        ratios[pair["case"]].append(ns["baseline"] / ns["candidate"])
    rows = {case: geometric(ratios[case]) for case in cases};gm = geometric(list(rows.values()))
    require(all(math.isclose(rows[case], summary["row_GMs"][case], rel_tol=1e-13) for case in cases)
            and math.isclose(gm, summary["primary_GM"], rel_tol=1e-13), "Independent points differ from original published summary")
    failed = {case: point for case, point in rows.items() if point < .98}
    accepted = gm >= 1.03 and not failed
    require(not accepted and summary["target_gate_pass"] is False and summary["all_row_point_floors_pass"] is False
            and summary["CI"] is None and summary["adoption_allowed"] is False, "Rejected pilot must not become formal acceptance")
    require(failed.keys() == {"ooffice"}, "Original failing row changed")
    return {"schema": "vort.zstd.literal-fallback-pilot.independent-point-recheck.v1", "pairs": 24, "children": 48,
        "primary_GM": gm, "row_GMs": rows, "raw_pair_ratios": ratios, "failed_rows_below_0_98": failed,
        "target_gate_pass": False, "formal_authorized": False, "performance_acceptance": False,
        "CI": None, "bootstrap_executed": False, "actual_host": common_host,
        "no_samples_filtered_retried_or_added": True, "original_epoch_accessed": False, "codec_or_library_executed": False}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=Path(__file__).resolve().parent)
    args = parser.parse_args()
    print(json.dumps(check(args.package.resolve()), indent=2, sort_keys=True))
