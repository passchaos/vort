#!/usr/bin/env python3
"""Portable offline evidence verification. Never imports producer or loads codecs."""
import argparse
import collections
import hashlib
import json
import math
import tarfile
from pathlib import Path


def need(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for data in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(data)
    return digest.hexdigest()


def geometric(values):
    values = list(values)
    return math.exp(math.fsum(math.log(v) for v in values) / len(values))


def close(a, b):
    return math.isclose(a, b, rel_tol=1e-13, abs_tol=1e-13)


def archive_hashes(path):
    result = {}
    with tarfile.open(path, "r:xz") as archive:
        for member in archive:
            need(member.isfile() and not member.name.startswith("/") and ".." not in Path(member.name).parts, "unsafe/non-file archive member")
            need(member.name not in result, "duplicate archive member")
            stream = archive.extractfile(member)
            h = hashlib.sha256()
            for data in iter(lambda: stream.read(1024 * 1024), b""):
                h.update(data)
            result[member.name] = h.hexdigest()
    return result


def verify(root, old_package=None):
    js = lambda path: json.loads((root / path).read_text())
    manifest = js("file-manifest.json")
    for name, item in manifest["files"].items():
        file = root / name
        need(file.is_file() and file.stat().st_size == item["bytes"] and sha(file) == item["sha256"], "package file changed: " + name)
    layout = js("source-layout.json")
    epoch = root / "raw/epoch"
    read = lambda path: json.loads((epoch / path).read_text())
    def local(original):
        path = Path(original)
        for recorded, folder in ((layout["recorded_epoch_root"], epoch), (layout["recorded_legacy_root"], root / "raw/legacy")):
            try:
                return folder / path.relative_to(recorded)
            except ValueError:
                pass
        raise ValueError("unmapped raw evidence path: " + original)
    candidate = archive_hashes(root / layout["candidate_archive"])
    registry = read("candidate-source-files.json")
    need(candidate == registry and len(candidate) == 2226, "complete candidate source closure mismatch")
    baseline = read("baseline46d-source-files.json")
    for path, checksum in baseline.items():
        actual = sha(root / "raw/baseline-overrides" / path) if path in layout["baseline_overrides"] else candidate.get(path)
        need(actual == checksum, "reconstructed Git46d source mismatch: " + path)
    need(len(baseline) == 2222 and len(layout["baseline_overrides"]) == 4, "baseline inventory mismatch")
    rejection = js("raw/root-rejection/receipt.json")
    need(sha(root / "raw/root-rejection/candidate.patch") == rejection["patch_sha256"], "original patch changed")
    for path, checksum in rejection["source_sha256"].items():
        need(candidate[path] == checksum == sha(root / "raw/root-rejection" / path), "seven saved source bytes differ")
    runtime = archive_hashes(root / layout["runtime_archive"])
    builds = read("build-results.json")
    ready = read("BUILD_SOURCE_READY.json")
    need(builds["completed"] and builds["success"] and len(builds["stages"]) == 4, "four builds not complete")
    for build in builds["stages"]:
        need(build["actual_exit_code"] == 0, "build exit changed")
        relative = str(Path(build["output"]).relative_to(layout["recorded_epoch_root"]))
        need(runtime[relative] == build["output_sha256"], "new ELF/object changed")
        for field in ("stdout", "stderr"):
            need(sha(local(build[field])) == build[field + "_sha256"], "build stream changed")
        for field in ("source_before", "source_after"):
            need(build[field]["candidate_source_manifest_sha256"] == ready["candidate_source_manifest_sha256"], "build source identity changed")
    baseline_build = next(b for b in builds["stages"] if b["stage"] == "baseline-controls")
    need("-Mvort_br=" + ready["baseline_actual_git_export_tree"] + "/src/br.zig" in baseline_build["argv"], "generic baseline did not use actual Git46d src")
    pf = read("preflight-results.json")
    need(pf["completed"] and pf["success"] and len(pf["attempts"]) == len(pf["rows"]) == pf["processes"] == 84, "preflight84 incomplete")
    need(collections.Counter(x["family"] for x in pf["rows"]) == {"main": 24, "public": 36, "small": 24}, "preflight scope counts differ")
    cells = collections.defaultdict(dict)
    for attempt in pf["attempts"]:
        need(attempt["actual_exit_code"] == 0, "untimed exit changed")
        value = json.loads(local(attempt["output"]).read_text())
        need(value["iterations"] == 0 and value["samples"] == [] and value["warmup_owned_encode_free_calls"] == 1, "preflight contained timing")
        for field in ("stdout", "stderr"):
            need(sha(local(attempt[field])) == attempt[field + "_sha256"], "untimed stream changed")
    for row in pf["rows"]:
        file = local(row["wire_path"])
        need(sha(file) == row["wire_sha256"] and file.stat().st_size == row["wire_bytes"] and row["complete_external_decode"], "initial wire/decode receipt changed")
        cells[row["family"], row["case"], row["control"]][row["variant"]] = row
    for _, values in cells.items():
        need(local(values["baseline"]["wire_path"]).read_bytes() == local(values["candidate"]["wire_path"]).read_bytes(), "complete initial wire memcmp differs")
        need(values["baseline"]["actual_options"] == values["candidate"]["actual_options"], "actual public options differ")
    for row in pf["rows"]:
        if row["family"] == "public" and row["control"] in ("q10-default", "q11-default"):
            need(row["actual_options"]["command_state_max_input_kib"] == 255, "q10/q11 public default setting changed")
    protocol = read("protocols/main-pilot.json")
    raw = read("pilot/run-manifest.json")
    release = read("pilot-release.json")
    report = read("pilot-summary.json")
    need(raw["release"] == release and raw["release_sha256"] == sha(epoch / "pilot-release.json"), "actual Root release changed")
    need(raw["protocol"] == protocol and release["protocol_sha256"] == sha(epoch / "protocols/main-pilot.json") and release["sampler_sha256"] == sha(epoch / "pilot-only.py"), "registered producer/protocol changed")
    need(release["released"] and release["purpose"] == "diagnostic-only" and not release["full_gate_passed"], "release was not diagnostic-only")
    cases = protocol["case_order"]
    need(len(cases) == 12 and len(raw["pairs"]) == 24 and len(raw["attempts"]) == 48, "fixed pilot count differs")
    need([(p["round"], p["case"]) for p in raw["pairs"]] == [(r, c) for r in range(2) for c in cases], "schedule changed/retry/drop")
    need(len(list((epoch / "pilot/runs").iterdir())) == 144, "unexpected raw sidecar inventory")
    attempts = iter(raw["attempts"])
    ratios = {c: [] for c in cases}
    # Find baseline by origin, independent of linkage entry order.
    baseline_sha = next(a["sha256"] for a in js("old-package-link.json")["exact_members"] if a["origin_path"] == protocol["baseline_ELF"])
    for pair in raw["pairs"]:
        order = ["baseline", "candidate"] if pair["round"] == 0 else ["candidate", "baseline"]
        need(pair["order"] == order, "AB/BA actual order changed")
        times = {}
        for variant in order:
            attempt = next(attempts)
            need((attempt["round"], attempt["case"], attempt["variant"], attempt["actual_exit_code"]) == (pair["round"], pair["case"], variant, 0), "actual process/exit order changed")
            value = json.loads(local(attempt["output"]).read_text())
            need(value["iterations"] == 1 and len(value["samples"]) == 1 and value["warmup_owned_encode_free_calls"] == 1, "owning warm1/timed1 changed")
            need((value["quality"], value["mode"], value["requested_window_bits"], value["input_bytes"], value["allocator"]) == (8, "generic", 16, 65536, "std.process.Init.gpa"), "public encode lifecycle/options changed")
            sample = value["samples"][0]
            t = sample["owned_encode_free_ns"]
            need(type(t) is int and t > 0 and pair["processes"][variant]["raw_ns"] == [t], "raw ns differs from manifest")
            frozen = cells["main", pair["case"], None][variant]
            need(value["warm_wire_sha256"] == frozen["wire_sha256"] and value["warm_wire_bytes"] == sample["wire_bytes"] == sample["mix"] == frozen["wire_bytes"], "timed warm wire/length/mix drift")
            need(value["provenance"]["executable_sha256"] == (baseline_sha if variant == "baseline" else runtime["bin/candidate"]), "recorded actual ELF changed")
            need(value["provenance"]["target_cpu"] == "skylake+pku+sgx" and value["provenance"]["cpu_affinity"] == "2", "target/affinity changed")
            times[variant] = t
        ratios[pair["case"]].append(times["baseline"] / times["candidate"])
    rows = {c: geometric(v) for c, v in ratios.items()}
    gm = geometric(rows.values())
    need(all(close(v, report["primary_row_GMs"][c]) for c, v in rows.items()) and close(gm, report["primary_GM"]), "independently recomputed point differs")
    need(all(v < .98 for v in rows.values()) and gm < 1.03 and report["CI"] is None and not report["point_screen_pass"] and not report["full_gate_passed"], "first pilot was not rejected")
    audit = js("raw/independent/receipt.json")
    need(close(gm, audit["GM"]) and audit["verification"] == "pass" and audit["rows_below_point_floor"] == 12, "independent audit receipt differs")
    need(all("not released" in value for key, value in js("remaining-phases.json").items() if key in ("formal", "public_controls_timed", "small_controls_timed", "historical_direct", "reference_direct")), "unreleased phase changed")
    need(rejection["patch_apply_check_exit_code"] == 0 and rejection["restored_compilation_inputs_diff_exit_code"] == 0 and not rejection["full_gate_passed"], "Root restoration/patch facts differ")
    if old_package:
        link = js("old-package-link.json")
        joined = hashlib.sha256()
        for part in link["parts"]:
            file = old_package / part["path"]
            need(file.stat().st_size == part["bytes"] and sha(file) == part["sha256"], "linked old part changed")
            with file.open("rb") as stream:
                for data in iter(lambda: stream.read(1024 * 1024), b""):
                    joined.update(data)
        need(joined.hexdigest() == link["joined_archive_sha256"], "linked old joined archive changed")
    return {"verified": True, "candidate_source_files": 2226, "baseline_source_files_reconstructed": 2222, "build_stages": 4, "preflight_processes": 84, "pilot_pairs": 24, "pilot_processes": 48, "primary_GM": gm, "candidate_over_baseline_elapsed_GM": 1 / gm, "rows_below_0_98": 12, "CI": None, "point_screen_pass": False, "full_gate_passed": False, "no_retry_or_drop": True, "old_package_hash_checked": bool(old_package), "codec_build_or_producer_execution": False}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--old-package", type=Path)
    args = parser.parse_args()
    print(json.dumps(verify(args.package.resolve(), args.old_package), indent=2, sort_keys=True))
