#!/usr/bin/env python3
"""Independent offline verification of the frozen c2/V7 performance campaign.

Exit 0 means valid evidence, even when acceptance gates fail. Missing, malformed
or inconsistent evidence exits 1. No argv is executed, no codec is loaded, and
no timing is performed. --expected-summary compares this verifier's stable JSON
exactly; Root's summary.json/control-summary.json are checked numerically with
relative tolerance 1e-10 and absolute tolerance 1e-12.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import re
import sys

OLD, NEW = "old_exact", "current"
ORDER = (OLD, NEW)
CONTROLS = {"q4": 100, "q11": 1, "ratio": 1}
BASE_REV = "c2c8f250302ca2f223740076482dd95b1788eeb1"
CURRENT_REV = "b199db72+paired-search-histogram-proposals-v7"
BOOTSTRAPS = 20000
WEAK = {"dickens", "mozilla", "nci"}
GOLDEN = {
    "dickens": (22367, "6db3970cd1981290ca64a47f00e4fe30e28443eb19625e703e42525b960241c0"),
    "nci": (4206, "5e82ff1682e22f8b9e9bbe0f06f49e43b6679bcc736f691a24261295a1d13615"),
    "mozilla": (13924, "29686649968e0dadd3dec91675d545298aa37fbbb58c00e3b6277881f9a6d2eb"),
}
HEX = re.compile(r"[0-9a-f]{64}\Z")


class InvalidEvidence(Exception):
    pass


def require(condition, message):
    if not condition:
        raise InvalidEvidence(message)


def natural(value, label, positive=False):
    require(type(value) is int and value >= (1 if positive else 0), label + ": invalid integer")
    return value


def hash_text(value, label):
    require(isinstance(value, str) and HEX.fullmatch(value), label + ": invalid SHA256")
    return value


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def normalized(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)


def unique(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "duplicate JSON key: " + key)
        result[key] = value
    return result


def load(path):
    def reject(value):
        raise InvalidEvidence("nonfinite JSON value: " + value)
    return json.loads(path.read_text(), object_pairs_hook=unique, parse_constant=reject)


def close(actual, expected, label):
    require(type(actual) in (int, float) and type(expected) in (int, float), label + ": nonnumeric statistic")
    require(math.isfinite(actual) and math.isfinite(expected) and math.isclose(actual, expected, rel_tol=1e-10, abs_tol=1e-12), label + ": statistic mismatch")


def vector_close(actual, expected, label):
    require(isinstance(actual, list) and len(actual) == len(expected), label + ": invalid interval")
    for a, b in zip(actual, expected):
        close(a, b, label)


def gm(values):
    values = list(values)
    require(values and all(v > 0 and math.isfinite(v) for v in values), "invalid geometric sample")
    return math.exp(math.fsum(math.log(v) for v in values) / len(values))


def median(values):
    ordered = sorted(values)
    middle = len(ordered) // 2
    return ordered[middle] if len(ordered) % 2 else (ordered[middle - 1] + ordered[middle]) / 2


def percentile(draws):
    draws.sort()
    return [draws[int((len(draws) - 1) * fraction)] for fraction in (.025, .975)]


def stratified_ci(pairs, seed, names):
    groups = [[math.log(p["ratio"]) for p in pairs if p["order"][0] == name] for name in names]
    require(all(groups) and len(groups[0]) == len(groups[1]), "unbalanced AB/BA bootstrap groups")
    rng = random.Random(seed)
    draws = []
    for _ in range(BOOTSTRAPS):
        logs = [group[rng.randrange(len(group))] for group in groups for _ in group]
        draws.append(math.exp(math.fsum(logs) / len(logs)))
    return percentile(draws)


def matrix_ci(rows):
    # Independent factorization: each shared round contributes its 12-row
    # mean log-ratio. Six resampled round means equal the original 72 logs.
    means = [math.fsum(math.log(row["pairs"][index]["ratio"]) for row in rows) / len(rows) for index in range(6)]
    rng = random.Random("matrix-explicit16")
    draws = []
    for _ in range(BOOTSTRAPS):
        indices = [rng.randrange(3) * 2 for _ in range(3)] + [rng.randrange(3) * 2 + 1 for _ in range(3)]
        draws.append(math.exp(math.fsum(means[index] for index in indices) / 6))
    return percentile(draws)


def flag(argv, name):
    indices = [index for index, value in enumerate(argv) if value == name]
    require(len(indices) == 1 and indices[0] + 1 < len(argv), "missing/duplicate command flag: " + name)
    return argv[indices[0] + 1]


def percent_argument(argument):
    safe = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._/:="
    return "".join(chr(byte) if byte in safe else "%" + format(byte, "02X") for byte in argument.encode())


def command(metadata, label, build=False):
    require(type(metadata.get("exit_code")) is int and metadata["exit_code"] == 0, label + ": command did not exit 0")
    argv = metadata.get("argv", metadata.get("command"))
    require(isinstance(argv, list) and argv and all(isinstance(v, str) for v in argv), label + ": invalid argv")
    if build:
        for option, expected in (("-O", "ReleaseFast"), ("-target", "x86_64-linux-gnu"), ("-mcpu", "skylake+pku+sgx")):
            indices = [i for i, value in enumerate(argv) if value == option]
            require(indices and all(i + 1 < len(argv) and argv[i + 1] == expected for i in indices), label + ": build mode/features differ")
    else:
        require(argv[:3] == ["taskset", "-c", "2"], label + ": sampling CPU is not 2")
    return argv


def file_identity(path, digest, length=None):
    hash_text(digest, path.name)
    if length is not None:
        require(path.stat().st_size == natural(length, path.name + " bytes"), path.name + ": size mismatch")
    require(sha(path) == digest, path.name + ": SHA256 mismatch")


def source_and_builds(root, settings):
    manifest_path = root / "all-src-sha256.json"
    manifest = load(manifest_path)
    require(isinstance(manifest, dict) and len(manifest) >= 2000, "incomplete all-source manifest")
    require({"src/br.zig", "src/br/encoder/literal_context_split.zig", "src/br/encoder/literal_context_profile.zig"} <= set(manifest), "source manifest lacks codec entry points")
    trees = [root / "source", root / "Source" / "current", root / "Source"]
    tree = next((path for path in trees if (path / "src" / "br.zig").is_file()), None)
    for name, expected in manifest.items():
        require(not Path(name).is_absolute() and ".." not in Path(name).parts, "invalid source manifest path")
        hash_text(expected, "source " + name)
        if tree is not None:
            file_identity(tree / name, expected)
    manifest_sha = sha(manifest_path)
    builds = load(root / "build-results.json")
    require(set(builds) == set(ORDER), "main build slots differ")
    for name in ORDER:
        built = builds[name]
        require(built["success"] is True and built["revision"] == settings["variants"][name], "main build source/revision mismatch")
        file_identity(root / "bin" / name, built["executable_sha256"])
        for stage in built.get("stages", []):
            command(stage, "main build " + name, build=True)
    require(builds[NEW]["source_manifest_sha256"] == manifest_sha, "main current build/source IID mismatch")
    file_identity(root / "build" / "current-record.o", builds[NEW]["record_object_sha256"])
    controls = load(root / "controls" / "build-results.json")
    require(set(controls) == {"baseline", NEW}, "control build slots differ")
    for name in ("baseline", NEW):
        command(controls[name], "control build " + name, build=True)
        require(controls[name]["source_revision"] == settings["variants"][OLD if name == "baseline" else NEW], "control source revision mismatch")
        file_identity(root / "controls" / "bin" / name, controls[name]["executable_sha256"])
    require(controls[NEW]["source_manifest_sha256"] == manifest_sha, "control current source IID mismatch")
    return builds, controls, {"files": len(manifest), "manifest_sha256": manifest_sha}


def process(root, relative, variant, fixture, iterations, builds, control=None):
    path = root / relative
    report = load(path)
    argv = command(load(path.with_suffix(".command.json")), str(relative))
    require(Path(argv[3]).name == variant, str(relative) + ": executable slot differs")
    require(flag(argv, "--input") == fixture["path"] and Path(flag(argv, "--output")).name == path.name, str(relative) + ": input/output argv mismatch")
    revision = BASE_REV if variant in (OLD, "baseline") else CURRENT_REV
    require(report["source_revision"] == revision == flag(argv, "--source-revision"), str(relative) + ": source IID differs")
    require(flag(argv, "--iterations") == str(iterations) and flag(argv, "--window") == "16", str(relative) + ": lifecycle/window argv differs")
    require(report["input_path"] == fixture["path"] and report["input_bytes"] == fixture["bytes"] and report["input_sha256"] == fixture["sha256"], str(relative) + ": input identity differs")
    require(report["allocator"] == "std.process.Init.gpa" and report["warmup_owned_encode_free_calls"] == 1 and report["iterations"] == iterations, str(relative) + ": lifecycle differs")
    require(report["mode"] == "generic" and report["requested_window_bits"] == 16, str(relative) + ": options differ")
    info = report["provenance"]
    required = {"provenance_version": 1, "optimize": "ReleaseFast", "target_arch": "x86_64", "target_os": "linux", "target_abi": "gnu", "target_cpu": "skylake+pku+sgx", "cpu_affinity": "2", "affinity_cpu_count": 1, "benchmark_threads": 1, "codec_thread_policy": "single", "executable_sha256": builds[variant]["executable_sha256"]}
    for field, expected in required.items():
        require(info[field] == expected and type(info[field]) is type(expected), str(relative) + ": provenance mismatch: " + field)
    require(isinstance(info["cpu_model"], str) and info["cpu_model"] != "unavailable" and info["zig_version"].startswith("0.16."), str(relative) + ": missing CPU/Zig provenance")
    require(info["command"] == " ".join(percent_argument(arg) for arg in argv[3:]), str(relative) + ": argv/provenance binding mismatch")
    if control is None:
        require(report["schema"] == "vort.q8-source-history-ab.process.v1" and report["quality"] == 8, str(relative) + ": main process schema/quality differs")
    else:
        require(report["schema"] == "vort.modeled-single.public-controls.process.v1" and report["control"] == control == flag(argv, "--control"), str(relative) + ": control schema differs")
        options = report["actual_options"]
        require(options["window_bits"] == 16 and options["mode"] == "generic" and report["quality"] == options["quality"], "control options mismatch")
        if control == "q11":
            require(options["quality"] == 11 and options["command_state_max_input_kib"] == 8 and report["command_state_limit_explicit"] is True, "q11 explicit 8 KiB cap missing")
        elif control == "q4":
            require(options["quality"] == 4, "q4 quality mismatch")
        else:
            require(options["quality"] is None and options["level"] == "ratio", "ratio policy mismatch")
    warm = natural(report["warm_wire_bytes"], "warm wire bytes", True)
    hash_text(report["warm_wire_sha256"], "warm wire SHA")
    samples = report["samples"]
    require(isinstance(samples, list) and len(samples) == iterations, "raw per-child sample count differs")
    times = []
    for index, sample in enumerate(samples):
        require(type(sample["index"]) is int and sample["index"] == index and sample["wire_bytes"] == warm and sample["mix"] == (index + 1) * warm, "timed length/mix identity differs")
        times.append(natural(sample["owned_encode_free_ns"], "owned encode/free ns", True))
    require(report["wire_identity_scope"] == "initial_wire_only; timed outputs check lengths/mix, not complete SHA256", "unexpected timed identity scope")
    path.with_suffix(".stdout").read_bytes()
    path.with_suffix(".stderr").read_bytes()
    wire = None
    if iterations == 0 or control is not None:
        require(Path(flag(argv, "--wire-output")).name == path.with_suffix(".br").name, "initial wire argv mismatch")
        wire = path.with_suffix(".br").read_bytes()
        require(len(wire) == warm and hashlib.sha256(wire).hexdigest() == report["warm_wire_sha256"], "complete initial wire identity differs")
        require(wire and wire[0] & 1 == 0, "initial wire is not standard window16")
    return report, times, wire


def preflight(root, fixtures, builds):
    report = load(root / "preflight-summary.json")
    require(report["lanes"] == ["explicit16"] and len(report["rows"]) == 24, "preflight lanes/row count differs")
    binding = load(root / "decoder-binding.json")
    require(binding["version"] == "1.2.0" and binding["version_number"] == 0x1002000 and len(binding["files"]) == 2, "pinned decoder receipt differs")
    for library in binding["files"]:
        file_identity(root / "references" / Path(library["path"]).name, library["sha256"], library["bytes"])
    require(binding["mapped_libraries"] and all("/references/" in line for line in binding["mapped_libraries"]), "decoder binding reports a mixed closure")
    keys = {(row["case"], row["variant"]) for row in report["rows"]}
    require(keys == {(case, variant) for case in fixtures for variant in ORDER}, "preflight rows are not unique/exhaustive")
    frozen = {}
    for case, fixture in fixtures.items():
        wires = []
        for variant in ORDER:
            value, _, wire = process(root, Path("preflight") / f"explicit16-{case}-{variant}.json", variant, fixture, 0, builds)
            row = next(row for row in report["rows"] if row["case"] == case and row["variant"] == variant)
            require(row["lane"] == "explicit16" and row["pinned_decode_verified"] is True and row["actual_window_bits"] == 16, "preflight decode/window receipt differs")
            for field, expected in (("input_bytes", fixture["bytes"]), ("input_sha256", fixture["sha256"]), ("wire_bytes", len(wire)), ("wire_sha256", value["warm_wire_sha256"])):
                require(row[field] == expected, "preflight summary identity mismatch: " + case)
            if variant == OLD and case in GOLDEN:
                require((len(wire), value["warm_wire_sha256"]) == GOLDEN[case] and row["historical_golden_match"] is True, "c2 golden mismatch: " + case)
            wires.append(wire)
        require(wires[0] == wires[1], "complete initial c2/current bytes differ: " + case)
        frozen[case] = (len(wires[0]), hashlib.sha256(wires[0]).hexdigest())
    return frozen


def main_matrix(root, settings, fixtures, builds, frozen):
    manifest = load(root / "run-manifest.json")
    require(manifest["schema"] == "vort.q8-histogram-proposals-ab.campaign.v1" and "completed" in manifest, "main campaign incomplete")
    require(normalized(manifest["settings"]) == normalized(settings), "main campaign settings drift")
    pairs = manifest["pairs"]
    expected = {(case, index) for case in fixtures for index in range(12 if case in WEAK else 6)}
    require(len(pairs) == 90 and {(p["case"], p["round"]) for p in pairs} == expected, "main campaign must have exactly ninety unique balanced pairs")
    grouped = {case: [] for case in fixtures}
    for pair in pairs:
        case, index = pair["case"], natural(pair["round"], "round")
        require(pair["lane"] == "explicit16" and pair["order"] == list(ORDER if index % 2 == 0 else reversed(ORDER)), "main AB/BA order differs")
        require(set(pair["processes"]) == set(ORDER), "main process slots differ")
        times = {}
        for variant in ORDER:
            relative = Path("runs") / f"explicit16-{index:02d}-{case}-{variant}.json"
            require(Path(pair["processes"][variant]["path"]).name == relative.name, "main raw path mapping differs")
            value, raw, _ = process(root, relative, variant, fixtures[case], 1, builds)
            manifest_raw = pair["processes"][variant]["raw_ns"]
            require(isinstance(manifest_raw, list) and all(type(v) is int for v in manifest_raw) and raw == manifest_raw, "manifest/raw sample differs")
            require((value["warm_wire_bytes"], value["warm_wire_sha256"]) == frozen[case], "initial wire drift in timed process")
            times[variant] = raw[0]
        grouped[case].append({"round": index, "order": pair["order"], "old_ns": times[OLD], "current_ns": times[NEW], "ratio": times[NEW] / times[OLD]})
    rows = []
    for case in sorted(grouped):
        raw = sorted(grouped[case], key=lambda p: p["round"])
        ratios = [pair["ratio"] for pair in raw]
        primary = gm(ratios[:6])
        elapsed = gm(ratios)
        rows.append({"case": case, "pairs": raw, "pair_count": len(raw), "primary_elapsed_ratio": primary, "primary_throughput_ratio": 1 / primary, "all_round_elapsed_ratio": elapsed, "all_round_throughput_ratio": 1 / elapsed, "all_round_elapsed_ci95": stratified_ci(raw, case + "explicit16", ORDER), "old_median_ns": median([p["old_ns"] for p in raw]), "current_median_ns": median([p["current_ns"] for p in raw]), "input_sha256": fixtures[case]["sha256"], "wire_bytes": frozen[case][0], "wire_sha256": frozen[case][1]})
    aggregate = gm(row["primary_elapsed_ratio"] for row in rows)
    return rows, {"elapsed_ratio": aggregate, "throughput_ratio": 1 / aggregate, "elapsed_ci95": matrix_ci(rows), "primary_rounds": 6, "row_count": 12}


def public_controls(root, settings, fixtures, builds):
    manifest = load(root / "control-manifest.json")
    require(manifest["schema"] == "vort.modeled-single.public-controls.campaign.v1" and "completed_unix" in manifest, "controls incomplete")
    mozilla = fixtures["mozilla"]
    require(manifest["input_path"] == mozilla["path"] and manifest["input_sha256"] == mozilla["sha256"] and manifest["iterations"] == CONTROLS and manifest["rounds"] == 6, "control input/settings drift")
    pairs = manifest["pairs"]
    require(len(pairs) == 18 and {(p["control"], p["round"]) for p in pairs} == {(c, i) for c in CONTROLS for i in range(6)}, "expected eighteen unique public control pairs")
    grouped = {control: [] for control in CONTROLS}
    frozen = {}
    for pair in pairs:
        control, index = pair["control"], natural(pair["round"], "control round")
        names = ("baseline", NEW)
        require(pair["order"] == list(names if index % 2 == 0 else reversed(names)) and set(pair["processes"]) == set(names), "control AB/BA order differs")
        means, wires = {}, []
        for variant in names:
            relative = Path("control-runs") / f"{index:02d}-{control}-{variant}.json"
            slot = pair["processes"][variant]
            require(Path(slot["report"]).name == relative.name and Path(slot["wire"]).name == relative.with_suffix(".br").name, "control artifact mapping differs")
            report, raw, wire = process(root, relative, variant, mozilla, CONTROLS[control], builds, control)
            means[variant] = math.fsum(raw) / len(raw)
            close(slot["per_call_mean_ns"], means[variant], "control child all-samples mean")
            digest = report["warm_wire_sha256"]
            require(digest == manifest["initial_wire_sha256"][control], "control initial SHA changed")
            if control in frozen:
                require(wire == frozen[control], "control complete initial bytes changed across rounds")
            frozen[control] = wire
            wires.append(wire)
        require(wires[0] == wires[1], "control source wire regression")
        ratio = means[NEW] / means["baseline"]
        close(pair["time_ratio"], ratio, "control pair ratio")
        grouped[control].append({"round": index, "order": pair["order"], "ratio": ratio})
    rows = []
    for control in sorted(CONTROLS):
        raw = sorted(grouped[control], key=lambda p: p["round"])
        ratio = gm(p["ratio"] for p in raw)
        interval = stratified_ci(raw, "control-" + control, ("baseline", NEW))
        rows.append({"control": control, "pair_count": 6, "iterations_per_child": CONTROLS[control], "elapsed_ratio": ratio, "throughput_ratio": 1 / ratio, "elapsed_ci95": interval, "throughput_ci95": [1 / interval[1], 1 / interval[0]], "passes_floor": 1 / ratio >= .98, "wire_bytes": len(frozen[control]), "wire_sha256": hashlib.sha256(frozen[control]).hexdigest()})
    return rows


def root_summaries(root, settings, rows, matrix, controls):
    summary = load(root / "summary.json")
    require(summary["schema"] == "vort.q8-source-history-ab.summary.v1", "Root summary schema differs")
    require(summary["source_revisions"] == settings["variants"] and summary["total_pairs"] == 90 and summary["total_timed_calls"] == 180, "Root summary source/count mismatch")
    require(len(summary["matrix"]) == 1 and len(summary["rows"]) == 12, "Root matrix shape differs")
    reported_matrix = summary["matrix"][0]
    require(reported_matrix["lane"] == "explicit16" and reported_matrix["rows"] == 12 and reported_matrix["primary_rounds"] == 6, "Root matrix policy differs")
    close(reported_matrix["paired_geomean_ns_current_over_old"], matrix["elapsed_ratio"], "Root matrix GM")
    vector_close(reported_matrix["paired_round_block_bootstrap_95pct_ci"], matrix["elapsed_ci95"], "Root matrix round-block CI")
    close(reported_matrix["geomean_encoded_bytes_current_over_old"], 1, "Root matrix wire ratio")
    by_case = {row["case"]: row for row in summary["rows"]}
    require(set(by_case) == {row["case"] for row in rows}, "Root row case mismatch")
    for row in rows:
        reported = by_case[row["case"]]
        require(reported["pairs"] == row["pair_count"] and reported["lane"] == "explicit16", "Root row pair count differs")
        fields = {"primary_six_round_paired_geomean": row["primary_elapsed_ratio"], "paired_geomean_ns_current_over_old": row["all_round_elapsed_ratio"], "old_per_call_median_ns": row["old_median_ns"], "current_per_call_median_ns": row["current_median_ns"]}
        for field, expected in fields.items():
            close(reported[field], expected, "Root row " + row["case"] + " " + field)
        vector_close(reported["paired_ratio_bootstrap_95pct_ci"], row["all_round_elapsed_ci95"], "Root row stratified CI")
        require(len(reported["raw_pairs"]) == row["pair_count"], "Root raw pair count differs")
        for actual, expected in zip(reported["raw_pairs"], row["pairs"]):
            require(all(actual[field] == expected[field] for field in ("round", "order", "old_ns", "current_ns")), "Root raw pair samples differ")
            close(actual["current_over_old_ns_ratio"], expected["ratio"], "Root raw pair ratio")
        for field in ("old_encoded_bytes", "current_encoded_bytes"):
            require(reported[field] == row["wire_bytes"], "Root row initial wire length differs")
        for field in ("old_wire_sha256", "current_wire_sha256"):
            require(reported[field] == row["wire_sha256"], "Root row initial wire SHA differs")
    control_summary = load(root / "control-summary.json")
    require(len(control_summary["rows"]) == 3, "Root control summary count differs")
    by_control = {row["control"]: row for row in control_summary["rows"]}
    for row in controls:
        reported = by_control[row["control"]]
        close(reported["candidate_over_baseline_time"], row["elapsed_ratio"], "Root control GM")
        close(reported["throughput_ratio"], row["throughput_ratio"], "Root control throughput")
        vector_close(reported["time_95pct_ci"], row["elapsed_ci95"], "Root control elapsed CI")
        vector_close(reported["throughput_95pct_ci"], row["throughput_ci95"], "Root control throughput CI")
        require(reported["pairs"] == 6 and reported["passes_control_floor"] is row["passes_floor"], "Root control floor differs")
    require(control_summary["all_controls_pass"] is all(row["passes_floor"] for row in controls), "Root aggregate control gate differs")


def verify(root):
    analyzer = (root / "analyze.py").read_text()
    sampling = (root / "control_sampling.py").read_text()
    require('BOOTSTRAPS = 20000' in analyzer and 'random.Random("matrix-" + lane)' in analyzer and 'pair_ci(pairs, case + lane)' in analyzer, "analyze.py bootstrap contract changed")
    require('range(20000)' in sampling and 'ci(pairs, "control-" + control)' in sampling, "control sampling bootstrap contract changed")
    settings = load(root / "settings.json")
    require(settings["variants"] == {OLD: BASE_REV, NEW: CURRENT_REV}, "legacy slots are not c2/current V7")
    require(settings["primary_options"] == {"quality": 8, "mode": "generic", "window_bits": 16} and settings["sampling_cpu"] == 2 and settings["codec_threads"] == 1 and settings["rounds"] == 6 and settings["weak_rows_additional_rounds"] == 6, "predeclared settings differ")
    require(settings["gates"]["aggregate_throughput_min"] == 1.03 and settings["gates"]["nci_throughput_min"] == 1.20 and settings["gates"]["all_rows_floor"] == .98 and settings["gates"]["public_controls_floor"] == .98 and settings["gates"]["aggregate_ci_excludes_parity"] is True, "acceptance thresholds changed")
    fixture_list = load(root / "fixtures.json")
    require(len(fixture_list) == 12, "expected twelve input fixtures")
    fixtures = {item["case"]: item for item in fixture_list}
    require(len(fixtures) == 12 and WEAK <= set(fixtures), "fixture cases missing/duplicated")
    for case, fixture in fixtures.items():
        require(isinstance(case, str) and case == Path(case).name and fixture["bytes"] == 65536, "input case/size differs")
        file_identity(root / "fixtures" / Path(fixture["path"]).name, fixture["sha256"], fixture["bytes"])
    builds, control_builds, source = source_and_builds(root, settings)
    frozen = preflight(root, fixtures, builds)
    rows, matrix = main_matrix(root, settings, fixtures, builds, frozen)
    controls = public_controls(root, settings, fixtures, control_builds)
    root_summaries(root, settings, rows, matrix, controls)
    nci = next(row for row in rows if row["case"] == "nci")
    failures = []
    if matrix["throughput_ratio"] < 1.03:
        failures.append("aggregate_throughput_below_1.03")
    if matrix["elapsed_ci95"][1] >= 1:
        failures.append("aggregate_elapsed_ci_upper_not_below_1")
    if nci["all_round_throughput_ratio"] < 1.20:
        failures.append("nci_twelve_round_throughput_below_1.20")
    failures += ["primary_row_below_0.98:" + row["case"] for row in rows if row["primary_throughput_ratio"] < .98]
    failures += ["public_control_below_0.98:" + row["control"] for row in controls if not row["passes_floor"]]
    output_rows = [{key: value for key, value in row.items() if key != "pairs"} for row in rows]
    return {
        "schema": "vort.q8-histogram-proposals-performance-verification.v1", "data_valid": True,
        "source_revisions": settings["variants"], "source_identity": source,
        "script_sha256": {name: sha(root / name) for name in ("run.py", "analyze.py", "control_sampling.py")},
        "main_executable_sha256": {name: builds[name]["executable_sha256"] for name in ORDER},
        "control_executable_sha256": {name: control_builds[name]["executable_sha256"] for name in ("baseline", NEW)},
        "bootstrap_draws": BOOTSTRAPS, "main_pairs": 90, "main_timed_calls": 180,
        "main_initial_complete_wires": 24, "control_pairs": 18, "control_processes": 36, "control_timed_calls": 1224,
        "matrix": matrix, "rows": output_rows, "controls": controls,
        "nci_gate_rounds": 12, "all_gates_passed": not failures, "failed_gates": failures,
        "statistics_scope": "Primary matrix and every primary-row floor use rounds0..5. NCI gate retains the existing all12-round row statistic. Matrix CI resamples shared even/odd round blocks; row/control CIs stratify by AB/BA. Fixed seeds and 20000 percentile draws match analyze.py/control_sampling.py with independently factored log means.",
        "wire_scope": "Initial complete bytes, hashes, windows and pinned decode receipts verified offline; timed output identity is length/mix only. No decoder is executed.",
        "source_scope": "Complete source hashes rechecked if a complete source tree is present. Frozen main c2 baseline has a success/revision/ELF stamp without an original per-stage build exit receipt; all saved actual process/build commands must exit0.",
        "acceptance_scope": "Declared operation-specific throughput/CI/control gates only; no industry ranking, codec memory or RSS inference.",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--expected-summary", type=Path)
    args = parser.parse_args()
    try:
        summary = verify(args.root)
        if args.expected_summary is not None:
            require(normalized(summary) == normalized(load(args.expected_summary)), "expected independent summary differs")
        print(json.dumps(summary, indent=2, sort_keys=True, allow_nan=False))
    except (InvalidEvidence, OSError, ValueError, KeyError, TypeError, IndexError, ZeroDivisionError, OverflowError) as error:
        print("verification failed: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
