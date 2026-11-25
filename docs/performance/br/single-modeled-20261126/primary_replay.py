"""Bind the primary records and replay the original pure statistics reducer."""
import gzip
import hashlib
from pathlib import Path

from archive_io import command_options, load, require, sha
import screening


def verify_sources(primary, controls):
    registry = load(primary, "all-src-sha256.json")
    actual = {name.removeprefix("source/"): sha(data) for name, data in primary.items()
              if name.startswith("source/src/")}
    require(actual == registry and len(actual) == 2196, "Full v5 source registry differs")
    declared = load(primary, "candidate-source-sha256.json")
    require(len(declared) == 9 and all(actual[name] == digest for name, digest in declared.items()),
            "Nine-source v5 identity differs")
    require(load(controls, "v5-all-src-sha256.json") == registry and
            load(controls, "candidate-source-sha256.json") == declared, "Control source identity differs")
    blobs = load(primary, "baseline-src-blobs.json")
    require(blobs == load(controls, "baseline-src-blobs.json") and len(blobs) == 2189,
            "Baseline blob registry differs")
    reconstructed = {}
    for name, expected in blobs.items():
        data = primary.get("baseline-delta/" + name, primary.get("source/" + name))
        require(data is not None, "Baseline source is absent: " + name)
        digest = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
        require(digest == expected, "Reconstructed baseline Git blob differs: " + name)
        reconstructed[name] = sha(data)
    return {"candidate_files": len(actual), "candidate_changed_or_new_declared_files": len(declared),
            "baseline_git_blobs_reconstructed": len(reconstructed),
            "baseline_source_reconstruction": "Full v5 filesystem for equal c2 blobs plus explicit c2 delta; Git not invoked",
            "candidate_registry_sha256": sha(primary["all-src-sha256.json"]),
            "candidate_nine_registry_sha256": sha(primary["candidate-source-sha256.json"])}, registry, declared


def verify(primary):
    builds = load(primary, "build-results.json")
    aliases = {"v5/" + name: data for name, data in primary.items()}
    aliases["common/baseline.elf.gz"] = gzip.compress(primary["bin/old_exact"], mtime=0)
    aliases["v5/candidate.elf.gz"] = gzip.compress(primary["bin/current"], mtime=0)
    for name, data in primary.items():
        if name.startswith(("fixtures/", "references/")):
            aliases["common/" + name] = data
    result = screening.verify_stage(aliases, "v5", {
        "baseline_elf_sha256": builds["old_exact"]["executable_sha256"],
        "candidate_elf_sha256": builds["current"]["executable_sha256"]})
    settings = load(primary, "settings.json")
    require(load(primary, "run-manifest.json")["settings"] == settings, "Campaign settings differ")
    for stage in builds["current"]["stages"]:
        require(stage["exit_code"] == 0, "Candidate build stage receipt failed")
    require(sha(primary["build/current-record.o"]) == builds["current"]["record_object_sha256"],
            "Primary reused object identity differs")
    for pair in load(primary, "run-manifest.json")["pairs"]:
        for variant, record in pair["processes"].items():
            name = "runs/" + Path(record["path"]).name
            require(name == f'runs/explicit16-{pair["round"]:02d}-{pair["case"]}-{variant}.json',
                    "Primary process filename differs")
            process = load(primary, name)
            command = load(primary, name.removesuffix(".json") + ".command.json")
            argv, options = command_options(command)
            require(Path(argv[3]).name == variant and options["--source-revision"] == settings["variants"][variant]
                    and options["--iterations"] == "1" and options["--window"] == "16"
                    and Path(options["--output"]).name == Path(name).name
                    and Path(options["--input"]).name == pair["case"] + ".65536.plain", "Primary argv binding differs")
            info = process["provenance"]
            require(info["target_arch"] == "x86_64" and info["target_os"] == "linux" and
                    info["benchmark_threads"] == 1 and info["zig_version"] == "0.16.0", "Primary platform differs")
            require(process["samples"][0]["owned_encode_free_ns"] > 0, "Nonpositive primary sample")
    initial = load(primary, "preflight-summary.json")
    for row in initial["rows"]:
        stem = "preflight/explicit16-" + row["case"] + "-" + row["variant"]
        report, command = load(primary, stem + ".json"), load(primary, stem + ".command.json")
        _, options = command_options(command)
        require(command["exit_code"] == 0 and report["iterations"] == 0 and report["samples"] == []
                and options["--iterations"] == "0", "Initial primary process was timed or failed")
        require(report["provenance"]["executable_sha256"] == builds[row["variant"]]["executable_sha256"]
                and report["source_revision"] == settings["variants"][row["variant"]]
                and report["warm_wire_sha256"] == row["wire_sha256"], "Initial primary source identity differs")
    expected_reports = {Path(record["path"]).name for pair in load(primary, "run-manifest.json")["pairs"]
                        for record in pair["processes"].values()}
    archived_reports = {Path(name).name for name in primary if name.startswith("runs/") and name.endswith(".json")
                        and not name.endswith(".command.json")}
    require(expected_reports == archived_reports and len(archived_reports) == 180, "Primary raw report inventory differs")
    result["scope"] = ("Reserved fixed development-host c2 versus unmerged frozen v5; 90 matched AB/BA pairs. "
                       "Original reducer prose retained raw; reservation receipts determine the actual window. "
                       "Initial complete wires and recorded pinned-decode receipts verified offline; "
                       "timed outputs have length/mix checks only. No codec is executed by this verifier.")
    result["normal_elf_sha256"] = {variant: build["executable_sha256"] for variant, build in builds.items()}
    matrix = result["full_summary"]["matrix"][0]
    result["matrix_throughput_ratio"] = 1 / matrix["paired_geomean_ns_current_over_old"]
    ci = matrix["paired_round_block_bootstrap_95pct_ci"]
    result["matrix_throughput_95pct_ci"] = [1 / ci[1], 1 / ci[0]]
    result["row_median_throughput_mib_per_second"] = {
        row["case"]: {"baseline": row["input_bytes"] * 1e9 / row["old_per_call_median_ns"] / (1024 * 1024),
                      "candidate": row["input_bytes"] * 1e9 / row["current_per_call_median_ns"] / (1024 * 1024)}
        for row in result["full_summary"]["rows"]}
    return result
