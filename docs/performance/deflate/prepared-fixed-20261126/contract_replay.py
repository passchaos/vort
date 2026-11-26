"""Prepared-only contract checks. Functions are not run until packed evidence exists."""
import json
import posixpath

from package_io import load, require, sha
import probe_contract


def verify_preflight(files, manifest):
    preflight, summary = load(files, "preflight.json"), load(files, "preflight-summary.json")
    require(preflight["schema"] == "vort.deflate.prepared-fixed-preflight.v1" and
            summary["schema"] == "vort.deflate.prepared-fixed-C-preflight.v1" and summary["untimed"] and summary["all_decoded"],
            "Preflight schema or recorded status differs")
    require(len(preflight["rows"]) == summary["rows"] == 33 and summary["wires"] == 99 and
            summary["codec_old_and_current_decode_processes"] == 198 and summary["python_zlib_decode_checks"] == 99,
            "Recorded preflight counts differ")
    rows = {row["id"]: row for row in manifest["rows"]}
    require([row["row"] for row in preflight["rows"]] == [row["id"] for row in manifest["rows"]], "Preflight row order differs")
    for row in preflight["rows"]:
        spec = rows[row["row"]]
        content = files["inputs/" + posixpath.basename(spec["input"])]
        require(len(content) == spec["size"] and sha(content) == spec["sha256"] == row["input_sha256"], "Input bytes differ")
        require(row["wire_equal"] and [(wire["which"], wire["mode"]) for wire in row["wires"]] ==
                [("old", "legacy"), ("current", "legacy"), ("current", "prepared")], "Preflight three-side contract differs")
        encoded = []
        for wire in row["wires"]:
            data = files["wires/" + posixpath.basename(wire["path"])]
            require(len(data) == wire["bytes"] and sha(data) == wire["sha256"], "Saved wire identity differs")
            encoded.append(data)
        require(encoded[0] == encoded[1] == encoded[2], "Exact old/current/prepared wire differs")
    require(preflight["zlib_compile_version"] == preflight["zlib_runtime_version"] == "1.2.11" and
            summary["C_zlib_compile_versions"] == summary["C_zlib_runtime_versions"] == ["1.2.11"], "Recorded reference version differs")
    require(sha(files["refs/raw_inflate"]) == summary["reference_elf_sha256"], "Recorded C decoder ELF differs")
    reference_map = load(files, "refs/reference-map.json")
    references = preflight["reference_hashes"] + load(files, "refs/c-build-provenance.json")["references"]
    for record in references:
        mapped = reference_map[record["path"]]
        content = files[mapped["member"]]
        require(len(content) == mapped["size"] == record["size"] and sha(content) == mapped["sha256"] == record["sha256"],
                "Packaged Python/C/header/shared-library reference differs")
    chronology = [json.loads(line) for line in files["chronology.jsonl"].splitlines() if line]
    wires = [record for record in chronology if record["phase"] == "untimed-wire"]
    decodes = [record for record in chronology if record["phase"] == "untimed-codec-decode"]
    require(len(wires) == 99 and len(decodes) == 198 and all(record["returncode"] == 0 for record in wires + decodes),
            "Actual preflight wire/decode chronology differs")
    builds = {which: load(files, "build/" + which + "-build.json") for which in ("old", "current")}
    expected_wires, expected_decodes = [], []
    for row in preflight["rows"]:
        for wire in row["wires"]:
            expected_wires.append((row["row"], wire["which"], wire["mode"], wire["path"]))
            expected_decodes.extend((row["row"], which, wire["path"]) for which in ("old", "current"))
    for record, (row, which, mode, path) in zip(wires, expected_wires):
        probe = probe_contract.check(record, manifest, rows[row], which, mode, 0, builds, path)
        require(probe["wire_sha256"] == sha(files["wires/" + posixpath.basename(path)]), "Actual preflight encode wire differs")
    for record, (row, which, path) in zip(decodes, expected_decodes):
        probe = probe_contract.check(record, manifest, rows[row], which, "verify", 0, builds, path, True)
        require(probe["wire_sha256"] == sha(files["wires/" + posixpath.basename(path)]), "Actual public decoder consumed wire differs")
    c_records = [json.loads(line) for line in files["refs/cdecode.jsonl"].splitlines() if line]
    require(len(c_records) == 99, "C decoder raw receipt count differs")
    for record, (row, which, mode, path) in zip(c_records, expected_wires):
        spec = rows[row]
        wire = files["wires/" + posixpath.basename(path)]
        reference = record["reference"]
        require(record["row"] == row and record["which"] == which and record["mode"] == mode and
                record["argv"] == [manifest["base"] + "/refs/raw_inflate", spec["input"], path] and record["returncode"] == 0 and
                record["untimed"] and record["input_sha256"] == spec["sha256"] and record["wire_sha256"] == sha(wire),
                "Individual C decoder row/source/argv/exit differs")
        require(json.loads(record["stdout"]) == reference and reference["schema"] == "vort.deflate.prepared-fixed-c-libz-verify.v1" and
                reference["status"] == "ok" and reference["untimed"] and reference["input_consumed"] == reference["wire_bytes"] == len(wire) and
                reference["output_produced"] == reference["output_bytes"] == spec["size"] and
                reference["zlib_compile_version"] == reference["zlib_runtime_version"] == "1.2.11" and
                probe_contract.utc(record["completed_utc"]) >= probe_contract.utc(record["started_utc"]), "C full-consumption/output/version/interval differs")
    return {"saved_wire_bytes_verified": 99, "exact_three_side_rows": 33, "codec_decode_exit_records_verified": 198,
            "python_decode_checks_recorded": 99, "C_decode_summary_recorded": True,
            "reference_scope": "Recorded Python/C raw inflate version1.2.11 and public old/current decode; no decoder executed offline",
            "C_individual_decode_exit_records_verified": 99,
            "C_individual_decode_semantics": "All recorded C full input/output counts and terminal status replayed; no C binary executed"}


def verify_sampling_records(files, manifest):
    require(manifest["pairs"] == 6 and manifest["orders"] == ["AB", "BA", "AB", "BA", "AB", "BA"],
            "Sampling pair plan differs")
    records = [json.loads(line) for line in files["samples/raw.jsonl"].splitlines() if line]
    row_lookup = {row["id"]: row for row in manifest["rows"]}
    expected = []
    for pair, order in enumerate(manifest["orders"]):
        for family, ids in (("prepared", list(row_lookup)), ("legacy", manifest["legacy_control_rows"])):
            for row in ids:
                expected.extend((pair, family, row, side) for side in order)
    require([(record["pair"], record["family"], record["row"], record["side"]) for record in records] == expected and
            len(records) == 540, "Raw pair/family/order matrix incomplete")
    builds = {which: load(files, "build/" + which + "-build.json") for which in ("old", "current")}
    chronology = [json.loads(line) for line in files["chronology.jsonl"].splitlines() if line]
    timed_chronology = [record for record in chronology if record["phase"] == "timed-public-append"]
    require(len(timed_chronology) == len(records), "Timed chronology/raw count differs")
    for record, chronological in zip(records, timed_chronology):
        require({key: value for key, value in record.items() if key not in ("family", "pair", "order", "side")} == chronological,
                "Raw record differs from its original pre-enrichment chronology")
        which = "old" if record["side"] == "A" else "current"
        mode = "prepared" if record["family"] == "prepared" and record["side"] == "B" else "legacy"
        spec = row_lookup[record["row"]]
        iterations = manifest["iterations_by_row"][record["row"]]
        require(record["which"] == which and record["mode"] == mode and record["phase"] == "timed-public-append" and
                record["order"] == manifest["orders"][record["pair"]] and
                record["returncode"] == 0 and record["elf_sha256"] == builds[which]["elf_sha256"], "Raw source/mode/order/exit/ELF differs")
        probe_contract.check(record, manifest, spec, which, mode, iterations, builds)
        require(json.loads(record["stdout"]) == record["probe"], "Raw stdout/probe differs")
        probe = record["probe"]
        wire_name = "wires/" + record["row"] + "." + which + "." + mode + ".raw"
        require(probe["input_bytes"] == spec["size"] and probe["input_sha256"] == spec["sha256"] and
                probe["iterations"] == iterations and probe["sample"]["length_mix"] == probe["wire_bytes"] * iterations and
                probe["wire_sha256"] == sha(files[wire_name]) and probe["sample"]["elapsed_ns"] > 0,
                "Raw input/iterations/lengthmix/wire/ns differs")
        require(record["monotonic_end_ns"] - record["monotonic_start_ns"] == record["wall_ns"] and
                record["wall_ns"] >= probe["sample"]["elapsed_ns"], "Recorded wall/timed interval differs")
    return records


def verify_latest_wasi_receipt(files):
    actual = load(files, "latest-wasi-exit.json")
    older = load(files, "focused-native-wasi-exit.json")
    require(actual["exit_code"] == 0 and actual["actual_wasi_test_counts"] == [11, 7, 29], "Latest WASI actual receipt differs")
    require(older["exit_code"] == 0 and older["wasi_gate_tests"] == [27, 6, 11], "Earlier focused/WASI epoch differs")
    require("-Doptimize=ReleaseSafe" in actual["argv"], "Latest WASI build mode differs")
    return {"latest_actual_execution_order": [11, 7, 29], "latest_exit_code": 0, "latest_build_mode": "ReleaseSafe",
            "older_execution_order": [27, 6, 11], "scope": "Separate source epochs; latest full build/sample terminal remains independent"}


def verify_latest_native_records(files):
    results = {}
    for suite, count in (("prepared", 29), ("matcher", 7), ("budget", 11)):
        stem = "latest-native-" + suite
        command, exit_record = load(files, stem + ".command.json"), load(files, stem + ".exit.json")
        argv = command.get("codec_test_argv", command["argv"])
        require(argv[:2] == ["zig", "test"] and not any(argument.startswith("-O") for argument in argv) and
                exit_record["exit_code"] == 0, "Latest actual default-Debug native command/exit differs")
        stdout, stderr = files[stem + ".stdout"], files.get(stem + ".stderr", b"")
        require(("All " + str(count) + " tests passed.").encode() in stdout + stderr, "Latest actual native test count differs")
        if suite == "prepared":
            require(len(stdout) == exit_record["stdout_bytes"] and len(stderr) == exit_record["stderr_bytes"] and
                    command["reexecuted"] is False and exit_record["reexecuted"] is False, "Prepared recorded event capture differs")
            capture_scope = "Exact completed event stdout/stderr fields"
        else:
            capture_scope = "Combined original tool output; .stdout filename does not prove pipe attribution and empty .stderr is a placeholder"
            if suite == "matcher":
                require(stdout.decode() == exit_record["original_tool_result"]["output"] and command["reexecuted"] is False,
                        "Matcher completed tool-result transcription differs")
            else:
                original = exit_record.get("original_tool_result")
                if original is None:
                    original = load(files, "latest-native-budget.original-tool-result.json")
                require(original["exit_code"] == 0 and original["chunk_id"] == exit_record["chunk_id"] and
                        stdout.decode() == original["output"], "Budget completed original combined output differs")
        results[suite] = {"actual_tests": count, "exit_code": 0, "build_mode": "Debug (zig test default; no -O)",
                          "capture_scope": capture_scope, "reexecuted": False}
    return results
