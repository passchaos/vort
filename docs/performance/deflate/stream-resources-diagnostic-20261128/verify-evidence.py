#!/usr/bin/env python3
"""Independent saved-data replay of the fixed54×2 diagnostic; no producers."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

sys.dont_write_bytecode = True
from package_io import ArchiveStore, equal_files, identity, load, require

PROTOCOL = "9767149ece8d85ed5cdfb955ba9c804efd8161b61fdcd45fc4416917d83506ba"
BASELINE = "1636c421524e522632fe051876ee42d1a19223c59d1f030102aff0252e4d51ef"
CANDIDATE = "beb79f99ed3809717dee3d3a3438247f835c45f012bfbb3aeab6cab6e6b0955f"
SAMPLER_V1 = "7dfec721eac8a666ac09cdc857e6a260da629fcce960dfb5ef2b8e73455e2367"
SAMPLER_V2 = "146a22b6096e22aa355a1a17d2f6c82c73e406f9889c739d74b4d451c9f0300a"
BASELINE_GIT = "d5d9d8aab3d91d34003e25d3e2c6a3fda6b51388"


def geometric(values):
    require(bool(values) and all(type(v) in (int, float) and math.isfinite(v) and v > 0 for v in values),
            "Positive finite diagnostic ratios required")
    return math.exp(math.fsum(math.log(v) for v in values) / len(values))


def exact_json(left, right):
    return json.dumps(left, sort_keys=True) == json.dumps(right, sort_keys=True)


def audit_data(store, binding):
    root = Path(binding["original_epoch_root"])
    data = lambda name: load(store, root / name)
    digest = lambda name: store.identity(str(root / name))["sha256"]
    protocol, pf, initial, exe, ready = (data(name) for name in (
        "protocol.json", "preflight.json", "preflight-results.json", "execution-bindings.json", "SOURCE_READY.json"))
    require(digest("protocol.json") == PROTOCOL and digest("sampler.py") == SAMPLER_V1
            and digest("sampler-v2.py") == SAMPLER_V2, "Original protocol/sampler identity changed")
    rows = protocol["rows"]
    require(len(rows) == len({row["case"] for row in rows}) == 54 and protocol["diagnostic_rounds"] == 2
            and protocol["CI"] is None and protocol["every_applicable_row_point_floor"] == .98
            and protocol["continuous_complete_stream_calls_per_process"] == 100
            and protocol["input_schedule"] == [1, 17, 4096], "Predeclared54×2 diagnostic scope changed")
    require(ready["accepted"] is True and ready["source_current"] is True and ready["actual_whole_exit_code"] == 0
            and ready["full_gate_passed"] is True and ready["all_test_check_check_wasm_accepted"] is True,
            "Independent original whole-library functional gate did not pass")
    source_counts = {}
    for variant, expected in (("baseline", BASELINE), ("candidate", CANDIDATE)):
        require(digest(variant + "-source-manifest.json") == expected, "Complete source registry identity changed")
        registry = data(variant + "-source-manifest.json")
        source_counts[variant] = len(registry)
        for relative, value in registry.items():
            require(digest("sources/" + variant + "/" + relative) == value, "Complete frozen source member differs")
        require(store.identity(exe[variant]["ELF"])["sha256"] == exe[variant]["sha256"], "Native ELF bytes/hash differ")
        header = store.read(exe[variant]["ELF"])[:20]
        require(header[:6] == b"\x7fELF\x02\x01" and header[18:20] == b"\x3e\x00", "Expected actual native x86_64 ELF")
        require(exe[variant]["revision"] == (BASELINE_GIT if variant == "baseline" else CANDIDATE), "Actual revision label differs")
    require(source_counts == {"baseline": 2250, "candidate": 2267}, "Complete frozen source count changed")
    original_whole = ready["original_whole_library"]
    for entry in original_whole.values():
        require(store.identity(entry["path"])["sha256"] == entry["sha256"], "Original five whole artifacts differ")
    whole = load(store, original_whole["receipt"]["path"])
    require(whole["actual_exit_code"] == 0 and whole["source_unchanged"] is True
            and whole["argv"] == ["taskset", "-c", "0-15", "zig", "build", "-j2", "test", "check", "check-wasm",
                                  "-Doptimize=ReleaseSafe", "--summary", "all"], "Original whole actual terminal/command differs")
    before, after = (load(store, original_whole[key]["path"]) for key in ("source_before", "source_after"))
    require(before == after and all(data("candidate-source-manifest.json").get(key) == value for key, value in before.items()),
            "Whole gate source before/after differs from complete candidate")
    require(b"Build Summary: 419/419 steps succeeded; 6108/6110 tests passed (2 skipped)"
            in store.read(original_whole["stderr"]["path"]), "Original whole complete summary missing")
    built = data("build-lengthcheck-results.json")
    require(built["completed"] is True and built["success"] is True and len(built["stages"]) == 2, "Original two builds incomplete")
    for item in built["stages"]:
        variant = item["stage"]
        require(item["actual_exit_code"] == 0 and item["output"] == exe[variant]["ELF"]
                and item["output_sha256"] == exe[variant]["sha256"], "Original build/ELF binding differs")
        require("-Mroot=" + str(root / "harness/probe-lengthcheck.zig") in item["argv"]
                and "-Mvort_deflate=" + str(root / "sources" / variant / "src/deflate.zig") in item["argv"]
                and "-Mprovenance=" + str(root / "harness/provenance.zig") in item["argv"], "Original exact build module paths differ")
        for flag, expected in (("-O", "ReleaseFast"), ("-target", "x86_64-linux-gnu"), ("-mcpu", "skylake+pku+sgx")):
            require(item["argv"].count(flag) == 3 and all(item["argv"][index + 1] == expected
                    for index, value in enumerate(item["argv"]) if value == flag), "Original module target/build mode differs")
        for key in ("stdout", "stderr"):
            require(store.identity(item[key])["sha256"] == item[key + "_sha256"], "Original build log differs")

    def source_snapshot(value):
        require(value["all_frozen_and_live_equal"] is True and value["baseline_manifest_sha256"] == BASELINE
                and value["candidate_manifest_sha256"] == CANDIDATE, "Original warm source snapshot differs")

    def process(value, row, variant, command, wire, iterations):
        require(type(value["iterations"]) is int and value["iterations"] == iterations
                and type(value["warmup_complete_init_feed_finish_drain_deinit_free_calls"]) is int
                and value["warmup_complete_init_feed_finish_drain_deinit_free_calls"] == 1
                and value["input_sha256"] == row["sha256"] and value["input_bytes"] == row["bytes"]
                and value["source_revision"] == exe[variant]["revision"] and value["kind"] == row["kind"]
                and value["encoder"] == row["encoder"] and value["output_quantum"] == row["output_quantum"]
                and value["input_schedule"] == [1, 17, 4096] and value["allocator"] == "std.process.Init.gpa"
                and value["public_options"] == "E.init(allocator) defaults; no block/lookahead/params/budget overrides",
                "Actual default complete process lifecycle/row changed")
        expected = {"executable_sha256": exe[variant]["sha256"], "command": " ".join(command[3:]), "cpu_affinity": "2",
                    "target_cpu": "skylake+pku+sgx", "optimize": "ReleaseFast", "target_arch": "x86_64", "target_os": "linux",
                    "target_abi": "gnu", "affinity_cpu_count": 1, "benchmark_threads": 1, "codec_thread_policy": "single"}
        require(all(value["provenance"].get(key) == expected_value for key, expected_value in expected.items()),
                "Actual process ELF/command/CPU/target/thread provenance differs")
        wire_identity = store.identity(str(wire))
        expected_wire = pf["wires"][row["case"]][variant]
        require(wire_identity == expected_wire and value["warm_wire_bytes"] == expected_wire["bytes"]
                and value["warm_wire_sha256"] == expected_wire["sha256"]
                and value["mix"] == iterations * expected_wire["bytes"], "Complete warm wire/timed length/mix differs")
        require(type(value["warm_step_calls"]) is int and value["warm_step_calls"] > 0
                and type(value["total_timed_step_calls"]) is int
                and value["total_timed_step_calls"] == iterations * value["warm_step_calls"], "Full step-call accounting differs")
        ns = value["continuous_complete_owning_stream_ns"]
        require(ns is None if iterations == 0 else type(ns) is int and ns > 0, "Actual raw timing scope differs")
        return ns

    require(pf["passed"] is True and pf["all_initial_external_decode_passed"] is True
            and pf["baseline_candidate_exact_wire_equal"] is True and "row_definitions" not in pf
            and initial["completed"] is True and initial["passed"] is True and initial["timed_samples"] == 0
            and initial["all_initial_external_decode_passed"] is True and initial["baseline_candidate_exact_wire_equal"] is True,
            "Original retained untimed108 preflight differs")
    warm_order = [(row["case"], variant) for row in rows for variant in ("baseline", "candidate")]
    require(len(initial["rows"]) == len(initial["attempts"]) == 108
            and [(x["case"], x["variant"]) for x in initial["rows"]] == warm_order
            and [(x["case"], x["variant"]) for x in initial["attempts"]] == warm_order, "Original108 warm order/count differs")
    warm_provenance = None
    for index, row in enumerate(rows):
        require(row["iterations"] == 100 and store.identity(row["path"]) == {key: row[key] for key in ("bytes", "sha256")},
                "Original input bytes/SHA/registered100 lifecycle differs")
        wires = []
        for offset, variant in enumerate(("baseline", "candidate")):
            item, saved = initial["attempts"][2 * index + offset], initial["rows"][2 * index + offset]
            stem = root / "preflight/controls" / (row["case"] + "-" + variant)
            paths = {key: str(stem) + suffix for key, suffix in (("output", ".json"), ("wire", ".wire"), ("stdout", ".stdout"), ("stderr", ".stderr"))}
            command = ["taskset", "-c", "2", exe[variant]["ELF"], "--input", row["path"], "--output", paths["output"],
                       "--wire-output", paths["wire"], "--source-revision", exe[variant]["revision"], "--iterations", "0",
                       "--kind", row["kind"], "--encoder", row["encoder"], "--output-quantum", str(row["output_quantum"])]
            require(item["argv"] == command and item["actual_exit_code"] == 0 and all(item[key] == value for key, value in paths.items())
                    and exact_json(saved["input"], row) and saved["external_decode_passed"] is True,
                    "Original warm argv/exit/row/retained external decode differs")
            source_snapshot(item["source_before"]); source_snapshot(item["source_after"])
            value = load(store, item["output"])
            require(exact_json(saved["actual_output"], value), "Embedded warm output differs from raw JSON")
            process(value, row, variant, command, item["wire"], 0)
            environment = {key: value for key, value in value["provenance"].items() if key not in ("executable_sha256", "command")}
            require(warm_provenance is None or warm_provenance == environment, "Original warm environments differ")
            warm_provenance = environment
            require(saved["sha256"] == value["warm_wire_sha256"] and saved["bytes"] == value["warm_wire_bytes"], "Warm row wire differs")
            for key in ("stdout", "stderr"):
                require(store.identity(item[key])["sha256"] == item[key + "_sha256"], "Original warm stream differs")
            wires.append(item["wire"])
        equal_files(store, *wires)

    v1, v2 = (store.read(str(root / name)).decode() for name in ("sampler.py", "sampler-v2.py"))
    start = "    try:\n        for index in range(2):"
    body_v1 = v1[v1.index(start):]
    body_v2 = v2[v2.index(start):].replace('"diagnostic-v2/', '"diagnostic/')
    require(body_v1 == body_v2, "Original timed body/reducer changed beyond v2 output paths")
    require(v1[v1.index("def geometric("):v1.index("def main(")] == v2[v2.index("def geometric("):v2.index("def require(")],
            "Original geometric reducer changed")
    repair = data("row-binding-fix.json")
    require(repair["sampler_v2_sha256"] == SAMPLER_V2 and repair["preflight_sha256"] == digest("preflight.json")
            and repair["preflight_results_sha256"] == digest("preflight-results.json")
            and repair["consumes_original_warm_records"] == len(repair["warm_record_proofs"]) == 108
            and repair["original_PF_row_definitions_added"] is False, "Metadata-only repair receipt differs")
    repair_final = data("row-binding-fix-final-receipt.json")
    require(repair_final["original_files_sha256_before"] == repair_final["original_files_sha256_after"]
            and all(digest(name) == value for name, value in repair_final["original_files_sha256_after"].items()),
            "Original v1/PF/release/failure preservation hashes differ")
    require(repair["timed_body_and_reducer_normalized_sha256"] == hashlib.sha256(body_v1.encode()).hexdigest(),
            "Metadata repair timed-body identity differs")
    status = data("diagnostic-v2/status.json")
    require(status["terminal"] is True and status["HEAVY"] == 0, "Original v2 status is not terminal")
    failure = data("root-diagnostic-terminal.json")
    require(failure["actual_exit_code"] == 1 and b"KeyError: 'row_definitions'" in store.read(str(root / "root-diagnostic-output.log"))
            and binding["original_v1_run_manifest_absent"] is True, "Original pre-codec v1 failure provenance differs")
    terminal = data("root-diagnostic-v2-terminal.json")
    release = data("release-diagnostic-v2.json")
    raw, summary = data("diagnostic-v2/run-manifest.json"), data("diagnostic-v2/summary.json")
    require(terminal["actual_exit_code"] == 0 and terminal["argv"] == ["python3", "-B", str(root / "sampler-v2.py"), "--release", str(root / "release-diagnostic-v2.json")],
            "Actual unique v2 sampler terminal differs")
    require(raw["completed"] is True and raw["terminal"] is True and raw["full_gate_passed"] is False
            and exact_json(raw["release"], release) and raw["release_sha256"] == digest("release-diagnostic-v2.json")
            and raw["protocol_sha256"] == PROTOCOL and len(raw["pairs"]) == 108 and len(raw["attempts"]) == 216,
            "Complete original108 pairs/216 children differs")
    for key, name in (("protocol_sha256", "protocol.json"), ("sampler_sha256", "sampler-v2.py"),
                      ("execution_bindings_sha256", "execution-bindings.json"), ("preflight_sha256", "preflight.json"),
                      ("preflight_results_sha256", "preflight-results.json"), ("row_binding_fix_sha256", "row-binding-fix.json"),
                      ("source_gate_receipt_sha256", "SOURCE_READY.json"), ("decoder_receipt_sha256", "decoder-receipt.json")):
        require(release[key] == digest(name), "Original Root v2 release evidence binding differs: " + key)
    ratios = {row["case"]: [] for row in rows}
    attempts = iter(raw["attempts"])
    common_provenance = None
    for index, pair in enumerate(raw["pairs"]):
        round_index, row = divmod(index, 54)[0], rows[index % 54]
        order = ["baseline", "candidate"] if round_index == 0 else ["candidate", "baseline"]
        require(pair["round"] == round_index and pair["case"] == row["case"] and pair["order"] == order
                and set(pair["processes"]) == {"baseline", "candidate"}, "Original fixed AB/BA pair order differs")
        times = {}
        for variant in order:
            item = next(attempts)
            stem = root / "diagnostic-v2/runs" / f"{round_index:02d}-{row['case']}-{variant}"
            paths = {key: str(stem) + suffix for key, suffix in (("output", ".json"), ("wire", ".wire"), ("stdout", ".stdout"), ("stderr", ".stderr"))}
            command = ["taskset", "-c", "2", exe[variant]["ELF"], "--input", row["path"], "--output", paths["output"],
                       "--wire-output", paths["wire"], "--source-revision", exe[variant]["revision"], "--kind", row["kind"],
                       "--encoder", row["encoder"], "--output-quantum", str(row["output_quantum"]), "--iterations", "100"]
            require((item["case"], item["round"], item["variant"], item["actual_exit_code"]) == (row["case"], round_index, variant, 0)
                    and item["argv"] == command and all(item[key] == value for key, value in paths.items()), "Actual child argv/order/exit/artifact path differs")
            value = load(store, item["output"])
            times[variant] = process(value, row, variant, command, item["wire"], 100)
            equal_files(store, item["wire"], str(root / "preflight/controls" / (row["case"] + "-" + variant)) + ".wire")
            recorded = pair["processes"][variant]
            require(recorded["path"] == item["output"] and recorded["ns"] == times[variant] and recorded["iterations"] == 100
                    and recorded["step_calls"] == value["total_timed_step_calls"], "All raw ns/step calls differ from pair index")
            for key in ("stdout", "stderr"):
                store.identity(item[key])
            environment = {key: value for key, value in value["provenance"].items() if key not in ("executable_sha256", "command")}
            require(common_provenance is None or common_provenance == environment, "Actual process environment differs across variants/rows")
            require(warm_provenance == environment, "Actual timed environment differs from retained warm environment")
            common_provenance = environment
        ratios[row["case"]].append(times["baseline"] / times["candidate"])
    points = {key: geometric(value) for key, value in ratios.items()}
    gm = geometric(list(points.values()))
    require(summary["completed"] is True and summary["pairs"] == 108 and summary["processes"] == 216
            and summary["CI"] is None and summary["adoption_allowed"] is False and summary["full_gate_passed"] is False,
            "Original diagnostic is not complete acceptance")
    require(set(summary["row_GMs"]) == set(points) and set(summary["raw_pair_speedups"]) == set(ratios), "Published row set changed")
    for case in points:
        require(math.isclose(points[case], summary["row_GMs"][case], rel_tol=1e-13)
                and all(math.isclose(a, b, rel_tol=1e-13) for a, b in zip(ratios[case], summary["raw_pair_speedups"][case]))
                and len(summary["raw_pair_speedups"][case]) == 2, "Independent row point/raw paired ratio replay differs")
    weak = [case for case in points if points[case] < .98]
    require(summary["all_row_point_floors_pass"] == (not weak) and len(weak) == 27
            and math.isclose(gm, .9317892012110397, rel_tol=1e-13), "Original refusal result differs")
    return {"schema": "vort.deflate.diagnostic-rejection.data-verification.v1", "rows": 54, "rounds": 2,
            "warm_records": 108, "pairs": 108, "children": 216, "child_actual_exit_codes_all_zero": True,
            "equal_row_GM": gm, "row_GMs": points, "raw_pair_speedups": ratios, "rows_below_0_98": weak,
            "weak_row_count": len(weak), "all_row_point_floors_pass": False, "CI": None, "bootstrap_draws": 0,
            "adoption_allowed": False, "formal_release_allowed": False, "source_counts": source_counts,
            "actual_provenance": common_provenance, "original_timed_body_unchanged_except_output_paths": True,
            "original_v1_precodec_failure_preserved": True, "v2_metadata_only_fix_preserved": True,
            "independent_whole_functional_gate_passed": True, "diagnostic_output_full_gate_passed": False,
            "external_decode_scope": "Original108 retained pass booleans bound to saved wire/input; no new decode or EOF/tail claim",
            "new_codec_or_build_or_sampling_or_RSS_executed": False}


def verify(package):
    package = package.resolve()
    binding = json.loads((package / "evidence-manifest.json").read_text())
    require(binding["schema"] == "vort.deflate.diagnostic-rejection.portable.v1", "Evidence schema differs")
    archive = package / binding["archive"]["path"]
    with archive.open("rb") as stream:
        require(identity(stream) == {key: binding["archive"][key] for key in ("bytes", "sha256")}, "Data archive bytes/SHA differ")
    for name, expected in binding["verification_tools"].items():
        with (package / name).open("rb") as stream:
            require(identity(stream) == expected, "Copied verifier/adapter identity differs")
    store = ArchiveStore(archive, binding["entries"])
    try:
        for original in binding["entries"]:
            store.identity(original)
        result = audit_data(store, binding)
    finally:
        store.close()
    result.update({"archive_members": len(binding["entries"]), "all_archive_member_SHA_verified": True,
                   "portable_without_original_tmp": True, "original_path_fallback_used": False})
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=Path(__file__).resolve().parent)
    args = parser.parse_args()
    print(json.dumps(verify(args.package), indent=2, sort_keys=True))
