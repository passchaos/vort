"""Recompute public-control process means and exact order-stratified CIs."""
import math
from pathlib import Path
import random
import statistics

from archive_io import command_options, load, require, sha

CONTROLS = {"q4": 100, "q11": 1, "ratio": 1}
ORDER = ("baseline", "v5")


def geometric(values):
    return math.exp(statistics.mean(math.log(value) for value in values))


def interval(pairs, seed):
    groups = [[pair for pair in pairs if pair["order"][0] == name] for name in ORDER]
    require([len(group) for group in groups] == [3, 3], "Control order groups differ")
    generator = random.Random(seed)
    samples = sorted(geometric([generator.choice(group)["time_ratio"] for group in groups for _ in group])
                     for _ in range(20000))
    return [samples[int((len(samples) - 1) * .025)], samples[int((len(samples) - 1) * .975)]]


def options_match(report, control):
    options = report["actual_options"]
    require(options["window_bits"] == 16 and options["mode"] == "generic", "Control common options differ")
    if control == "q11":
        require(options["quality"] == 11 and options["command_state_max_input_kib"] == 8 and
                report["command_state_limit_explicit"], "q11 explicit cap differs")
    elif control == "q4":
        require(options["quality"] == 4, "q4 quality differs")
    else:
        require(options["quality"] is None and options["level"] == "ratio", "Ratio public options differ")


def timer_body(data):
    start = data.index(b"    for (0..iterations) |index| {\n")
    end = data.index(b"    if (!std.mem.eql(u8, &input_sha", start)
    return data[start:end]


def verify(primary, controls):
    builds = load(controls, "build-results.json")
    identity = load(controls, "frozen-identity.json")
    extension = load(controls, "probe-extension-identity.json")
    require(sha(controls["probe.zig"]) == extension["control_probe_sha256"] and
            sha(controls["primary-probe.zig"]) == extension["primary_sha256"] and
            controls["primary-probe.zig"] == primary["probe.zig"], "Control/primary probe identity differs")
    require(timer_body(controls["probe.zig"]) == timer_body(primary["probe.zig"]) and
            sha(timer_body(controls["probe.zig"])) == extension["continuous_timed_body_sha256"] and
            identity["control_probe"] == extension, "Continuous control timer differs")
    for variant in ORDER:
        build = builds[variant]
        require(build["exit_code"] == 0 and sha(controls["bin/" + variant]) == build["executable_sha256"] and
                sha(controls["build/" + variant + "-record.o"]) == build["reused_record_object_sha256"] and
                identity["builds"][variant] == build, "Control build/ELF/object differs")
    for group in ("fixtures", "references"):
        for name, record in identity[group].items():
            data = controls[group + "/" + name]
            require(len(data) == record["bytes"] and sha(data) == record["sha256"], "Control dependency differs")
            require(data == primary[group + "/" + name], "Primary/control dependency differs")
    validation = load(controls, "validation-receipt.json")
    settings = load(primary, "settings.json")
    revisions = {"baseline": settings["variants"]["old_exact"], "v5": settings["variants"]["current"]}
    require(len(validation["rows"]) == 3 and validation["timed_samples_executed"] == 0 and
            validation["shared_common_runtime_hit_confirmed"] is False, "Untimed control scope differs")
    for row in validation["rows"]:
        require(row["source_wires_equal"] and row["input_bytes"] == 65536, "Untimed control wire receipt differs")
        peers = []
        for variant, receipt in row["sources"].items():
            stem = "validation/" + row["control"] + "-" + row["case"] + "-" + variant
            report = load(controls, stem + ".json")
            command = load(controls, stem + ".command.json")
            wire = controls[stem + ".br"]
            options_match(report, row["control"])
            require(report["source_revision"] == revisions[variant] and
                    report["provenance"]["executable_sha256"] == builds[variant]["executable_sha256"] and
                    report["actual_options"] == receipt["actual_options"] and
                    report["input_sha256"] == row["input_sha256"], "Untimed control source/options binding differs")
            require(command["exit_code"] == receipt["encode_exit_code"] == 0 and report["iterations"] == 0 and
                    report["samples"] == [] and receipt["decode_status"] == 1 and receipt["decoded_bytes"] == 65536,
                    "Untimed encode/decode receipt differs")
            require(len(wire) == receipt["wire_bytes"] == report["warm_wire_bytes"] and
                    sha(wire) == receipt["wire_sha256"] == report["warm_wire_sha256"], "Untimed control bytes differ")
            peers.append(wire)
        require(len(peers) == 2 and peers[0] == peers[1], "Untimed control sources differ")
    manifest, plan = load(primary, "control-manifest.json"), load(primary, "control-plan.json")
    require(manifest["iterations"] == CONTROLS and manifest["rounds"] == plan["rounds"] == 6 and
            "completed_unix" in manifest and sha(primary["control_sampling.py"]) == plan["script_sha256"],
            "Timed control plan differs")
    require(manifest["input_sha256"] == sha(controls["fixtures/mozilla.65536.plain"]), "Control input differs")
    pairs, raw, seen = [], [], set()
    for pair in manifest["pairs"]:
        key = pair["control"], pair["round"]
        require(key not in seen and pair["control"] in CONTROLS and 0 <= pair["round"] < 6, "Duplicate/unexpected control pair")
        seen.add(key)
        require(pair["order"] == (list(ORDER) if pair["round"] % 2 == 0 else list(reversed(ORDER))) and
                set(pair["processes"]) == set(ORDER), "Timed control pair/order differs")
        means, wires = {}, []
        for variant in ORDER:
            record = pair["processes"][variant]
            stem = "timed/" + Path(record["report"]).stem
            require(stem == f'timed/{pair["round"]:02d}-{pair["control"]}-{variant}', "Timed control filename differs")
            report, command = load(controls, stem + ".json"), load(controls, stem + ".command.json")
            argv, options = command_options(command)
            require(command["exit_code"] == 0 and argv[:3] == ["taskset", "-c", "2"] and
                    Path(argv[3]).name == variant and options["--source-revision"] == revisions[variant] and
                    options["--iterations"] == str(CONTROLS[pair["control"]]) and options["--window"] == "16" and
                    options["--control"] == pair["control"] and Path(options["--output"]).stem == Path(stem).name,
                    "Timed control argv differs")
            require(report["schema"] == "vort.modeled-single.public-controls.process.v1" and
                    report["control"] == pair["control"] and report["source_revision"] == revisions[variant] and
                    report["input_sha256"] == manifest["input_sha256"], "Timed control report differs")
            info = report["provenance"]
            expected = {"executable_sha256": builds[variant]["executable_sha256"], "cpu_affinity": "2",
                        "affinity_cpu_count": 1, "target_cpu": "skylake+pku+sgx", "target_abi": "gnu",
                        "target_arch": "x86_64", "target_os": "linux", "optimize": "ReleaseFast", "benchmark_threads": 1}
            require(all(info[k] == v for k, v in expected.items()), "Timed control target/ELF differs")
            options_match(report, pair["control"])
            samples = report["samples"]
            require(report["iterations"] == len(samples) == CONTROLS[pair["control"]] and
                    report["warmup_owned_encode_free_calls"] == 1, "Control call count differs")
            for index, sample in enumerate(samples):
                require(sample["index"] == index and sample["owned_encode_free_ns"] > 0 and
                        sample["wire_bytes"] == report["warm_wire_bytes"] and
                        sample["mix"] == (index + 1) * report["warm_wire_bytes"], "Control per-call data differs")
                raw.append({"control": pair["control"], "round": pair["round"], "order": "/".join(pair["order"]),
                            "variant": variant, "index": index, **sample})
            wire = controls[stem + ".br"]
            require(len(wire) == report["warm_wire_bytes"] and sha(wire) == report["warm_wire_sha256"] ==
                    manifest["initial_wire_sha256"][pair["control"]], "Timed control initial wire differs")
            wires.append(wire)
            means[variant] = statistics.mean(sample["owned_encode_free_ns"] for sample in samples)
            require(means[variant] == record["per_call_mean_ns"], "Control recorded process mean differs")
        require(wires[0] == wires[1], "Timed control source wires differ")
        ratio = means["v5"] / means["baseline"]
        require(ratio == pair["time_ratio"], "Control pair ratio differs")
        pairs.append({"control": pair["control"], "round": pair["round"], "order": pair["order"], "time_ratio": ratio})
    require(seen == {(control, round_index) for control in CONTROLS for round_index in range(6)} and
            len(raw) == 1224, "Timed control campaign incomplete")
    archived_reports = {name for name in controls if name.startswith("timed/") and name.endswith(".json")
                        and not name.endswith(".command.json")}
    expected_reports = {f'timed/{round_index:02d}-{control}-{variant}.json'
                        for round_index in range(6) for control in CONTROLS for variant in ORDER}
    require(archived_reports == expected_reports, "Control raw report inventory differs")
    rows = []
    for control in CONTROLS:
        selected = [pair for pair in pairs if pair["control"] == control]
        ratio, ci = geometric(pair["time_ratio"] for pair in selected), interval(selected, "control-" + control)
        rows.append({"control": control, "pairs": 6, "candidate_over_baseline_time": ratio, "time_95pct_ci": ci,
                     "throughput_ratio": 1 / ratio, "throughput_95pct_ci": [1 / ci[1], 1 / ci[0]],
                     "passes_control_floor": 1 / ratio >= .98})
    saved = load(primary, "control-summary.json")
    require(rows == saved["rows"] and saved["all_controls_pass"] == all(row["passes_control_floor"] for row in rows),
            "Recomputed control bootstrap differs")
    route = load(controls, "legacy-route-scope.json")
    require(route["runtime_shared_common_hit_confirmed"] is False, "Unconfirmed legacy runtime route misclassified")
    return {"rows": rows, "verified_pairs": 18, "verified_processes": 36, "verified_timed_calls": 1224,
            "untimed_decode_receipts": 6, "runtime_shared_common_hit_confirmed": False,
            "elf_sha256": {variant: builds[variant]["executable_sha256"] for variant in ORDER},
            "scope": "All per-call raw ns retained; arithmetic process means; six paired ratios per control; 20000 order-stratified draws. Initial wires only; no decoder run offline."}, raw
