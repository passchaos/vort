"""Lightweight source, two-round pilot, profile and saved-test replay."""
from collections import Counter
import io
import math
import posixpath
import statistics
import tarfile

from archive_io import load, require, sha


def sources(package, evidence):
    base = {}
    with tarfile.open(fileobj=io.BytesIO(package["base-source.tar"]), mode="r:") as archive:
        head = archive.pax_headers.get("comment")
        for member in archive:
            require(not member.name.startswith("/") and ".." not in member.name.split("/"), "Unsafe base member")
            if member.isfile():
                base[member.name] = archive.extractfile(member).read()
    overlay = {name.removeprefix("overlay/"): data for name, data in package.items() if name.startswith("overlay/")}
    expected = load(package, "source-overlay.json")
    require(sorted(overlay) == expected["overlay_files"] and len(overlay) == 4 and head == load(evidence, "identity.json")["head"],
            "Base commit or combined overlay differs")
    base.update(overlay)
    registry = load(package, "candidate-source.json")
    actual = {name: sha(content) for name, content in base.items() if name.startswith("src/")}
    require(actual == registry and len(actual) == 2201, "Reconstructed candidate source differs")
    identity = load(evidence, "identity.json")
    require(sha(evidence["bin/baseline"]) == identity["baseline_elf_sha256"] and
            load(evidence, "baseline-original-build-receipt.json")["exit_code"] == 0 and
            load(evidence, "build/probe.command.json")["exit_code"] == load(evidence, "build/record.command.json")["exit_code"] == 0,
            "Original baseline or candidate build receipt differs")
    return {"base_head": head, "candidate_source_files": 2201, "overlay_files": sorted(overlay),
            "baseline_elf_sha256": identity["baseline_elf_sha256"], "candidate_elf_sha256": sha(evidence["bin/candidate"]),
            "baseline_stamp_preserved": identity["baseline_stamp_unchanged"],
            "public_code_equivalence": {"producer_statement": identity["public_source_equivalence"], "new_git_diff_executed": False},
            "scope": "Complete base src/build/tools gitarchive plus exact four-file combined overlay; old accepted V7 stamp and receipt preserved, no component attribution"}


def pilot(data):
    manifest, summary, gates = load(data, "pilot-manifest.json"), load(data, "pilot-summary.json"), load(data, "gates.json")
    fixtures = load(data, "fixtures.json")
    require(gates["aggregate_throughput_min"] == 1.03 and gates["nci_throughput_min"] == 1.20 and
            gates["all_rows_floor"] == .98 and gates["primary_rounds"] == 6 and gates["preserve_all_samples"], "Declared gates differ")
    require(manifest["rounds"] == summary["rounds"] == gates["pilot_rounds"] == 2 and len(manifest["pairs"]) == 24 and
            "ended_unix" in manifest and [row["case"] for row in fixtures] == gates["primary_cases"], "Pilot matrix differs")
    reference = manifest["reference_decode_outside_timing"]
    require(reference["version"] == 0x1002000, "Pinned decoder version differs")
    for path, digest in reference["files"].items():
        require(sha(data["references/" + posixpath.basename(path)]) == digest and path in reference["maps"], "Pinned decoder/common hash/maps differ")
    for variant in ("baseline", "candidate"):
        require(sha(data["bin/" + variant]) == manifest["executables"][variant], "Pilot ELF differs")
    require([(pair["round"], pair["case"]) for pair in manifest["pairs"]] ==
            [(index, row["case"]) for index in range(2) for row in fixtures], "Pilot raw ordering differs")
    ratios, records = {row["case"]: [] for row in fixtures}, []
    previous_end = manifest["started_unix"]
    for pair in manifest["pairs"]:
        require(pair["order"] == (["baseline", "candidate"] if pair["round"] == 0 else ["candidate", "baseline"]), "AB/BA pair order differs")
        fixture = next(row for row in fixtures if row["case"] == pair["case"])
        content = data["inputs/" + posixpath.basename(fixture["path"])]
        require(len(content) == fixture["bytes"] == 65536 and sha(content) == fixture["sha256"], "Frozen input differs")
        peers, times = [], {}
        for variant in pair["order"]:
            record = pair["processes"][variant]
            stem = "pilot-runs/" + posixpath.basename(record["path"]).removesuffix(".json")
            report, command = load(data, stem + ".json"), load(data, stem + ".command.json")
            wire = data[stem + ".wire"]
            require(command["exit_code"] == 0 and command["argv"][:3] == ["taskset", "-c", "2"] and
                    manifest["started_unix"] <= previous_end <= command["started_unix"] <= command["ended_unix"] <= manifest["ended_unix"],
                    "Pilot argv/exit/interval differs")
            previous_end = command["ended_unix"]
            options = dict(zip(command["argv"][4::2], command["argv"][5::2]))
            require(posixpath.basename(command["argv"][3]) == variant and options["--input"] == fixture["path"] and
                    options["--window"] == "16" and options["--iterations"] == "1" and
                    report["source_revision"] == options["--source-revision"], "Pilot source/CLI binding differs")
            require(report["provenance"]["executable_sha256"] == manifest["executables"][variant] and
                    report["input_sha256"] == fixture["sha256"] and report["input_bytes"] == 65536 and
                    (report["quality"], report["mode"], report["requested_window_bits"]) ==
                    (8, "generic", 16) and report["iterations"] == len(report["samples"]) == report["warmup_owned_encode_free_calls"] == 1,
                    "Pilot source/ELF/options/lifecycle differs")
            sample = report["samples"][0]
            require(sample["owned_encode_free_ns"] == record["ns"] > 0 and sample["mix"] == sample["wire_bytes"] ==
                    report["warm_wire_bytes"] == record["wire_bytes"] == len(wire) and
                    sha(wire) == report["warm_wire_sha256"] == record["wire_sha256"], "Pilot raw ns/warm wire/mix differs")
            peers.append(wire)
            times[variant] = record["ns"]
            records.append({"case": pair["case"], "round": pair["round"], "order": "/".join(pair["order"]), "variant": variant,
                            "ns": record["ns"], "wire_bytes": len(wire), "wire_sha256": sha(wire),
                            "started_unix": command["started_unix"], "ended_unix": command["ended_unix"]})
        require(peers[0] == peers[1], "Complete baseline/candidate byte equality differs")
        ratios[pair["case"]].append(times["baseline"] / times["candidate"])
    for row in summary["rows"]:
        require(row["paired_throughput_ratios"] == ratios[row["case"]] and row["throughput_ratio"] ==
                math.exp(statistics.mean(math.log(value) for value in ratios[row["case"]])), "Pilot row math differs")
    gm = math.exp(statistics.mean(math.log(row["throughput_ratio"]) for row in summary["rows"]))
    require(gm == summary["throughput_geomean"] and summary["pilot_only"] and not summary["primary_point_gates_pass"], "Pilot aggregate differs")
    return summary, records


def profile_tests(profile, evidence):
    report = load(profile, "line-attribution.json")
    leaves = [line.rsplit(None, 2) for line in profile["leaf-ips.txt"].decode().splitlines()]
    require(len(leaves) == report["samples"] == 3502 and sum(int(row[1]) for row in leaves) == report["total_period"] and
            sum(int(row[1]) for row in leaves if row[0].strip() == "baseline") == report["baseline_period"], "Profile sample/period totals differ")
    rows = report["rows"]
    require(sum(row["cycles"] for row in rows) == report["decoded_target_period"] == sum(report["target_symbol_periods"].values()),
            "Profile source-map total differs")
    require(sum(row["cycles"] for row in rows if row["line"] > 0) == report["positive_line_target_period"] and
            sum(row["cycles"] for row in rows if row["line"] == 0) == report["zero_line_target_period"], "Profile line0/positive coverage differs")
    for row in rows:
        require(math.isclose(row["all_sample_percent"], 100 * row["cycles"] / report["total_period"], rel_tol=1e-12, abs_tol=1e-12),
                "Profile row coverage percentage differs")
    for index in range(10):
        raw, command = load(profile, f"process-{index:02d}.json"), load(profile, f"process-{index:02d}.command.json")
        require(command["exit_code"] == 0 and raw["provenance"]["executable_sha256"] == sha(evidence["bin/baseline"]) and
                raw["iterations"] == len(raw["samples"]) == 3 and raw["warmup_owned_encode_free_calls"] == 1, "Profile child/ELF/lifecycle differs")
        for position, sample in enumerate(raw["samples"]):
            require(sample["index"] == position and sample["wire_bytes"] == raw["warm_wire_bytes"] and
                    sample["mix"] == (position + 1) * raw["warm_wire_bytes"], "Profile raw length mix differs")
    for name in ("build/lanes-native-final.stderr", "build/lanes-wasm-run.stderr"):
        require(b"All 12 tests passed." in evidence[name], "Actual final native/WASI twelve-test log differs")
    wasi = load(evidence, "build/lanes-wasm-run.stdout")
    module = wasi["results"][0]
    require(wasi["status"] == "ok" and module["exit_code"] == 0 and sha(evidence["build/lanes.wasm"]) == module["wasm_sha256"],
            "Actual WASI module/run differs")
    completion = load(evidence, "completion-receipt.json")
    require(completion["pilot_parent_reported_exit_code"] == 0 and completion["pilot_parent_reported_session"] == 98758 and
            completion["profile_addr2line_report_stopped_by_root"] and not completion["addr2line_is_codec_failure"], "Terminal/postprocessing scope differs")
    return {"profiled_variant": "baseline", "profiled_elf_sha256": sha(evidence["bin/baseline"]),
            "samples": 3502, "children": 10, "public_calls": 40, "warmups": 10, "timed_calls": 30,
            "period_totals": {key: report[key] for key in ("total_period", "baseline_period", "decoded_target_period", "positive_line_target_period", "zero_line_target_period")},
            "positive_line_period_percent_all_samples": 100 * report["positive_line_target_period"] / report["total_period"],
            "line0_unattributed": True, "pure_encoder_phase_share": None,
            "scope": "All raw profile/ELF/code/source maps preserved. Inline diagnostic line periods include provenance/SHA/kernel/IO; no regex attribution to disjoint encoder phases. Stopped GNU addr2line report is not a codec failure.",
            "native_final_tests_recorded": 12, "actual_wasi_tests_recorded": 12, "wasi_module_sha256": module["wasm_sha256"]}
