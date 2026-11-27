#!/usr/bin/env python3
"""Portable data-only SHA and raw point recomputation; no producer imports."""
import argparse
import hashlib
import json
import math
import random
import tarfile
from pathlib import Path


def require(condition, label):
    if not condition:
        raise ValueError(label)


def sha(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for data in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(data)
    return digest.hexdigest()


def geometric(values):
    return math.exp(math.fsum(math.log(v) for v in values) / len(values))


def shared_round_ci(ratios, row_order, phase):
    """Independent fixed 20000 shared six-round AB/BA draws, data only."""
    require(phase in ("formal", "reference", "controls"), "six-round Zstd CI phase")
    require(all(set(ratios[row]) == set(range(6)) for row in row_order), "exact six actual common rounds")
    generator = random.Random("zstd-fallback-common-six-" + phase)
    draws = []
    for _ in range(20000):
        indices = [generator.choice((0, 2, 4)) for _ in range(3)] + [generator.choice((1, 3, 5)) for _ in range(3)]
        row_gms = [geometric([ratios[row][index] for index in indices]) for row in row_order]
        draws.append(geometric(row_gms))
    draws.sort()
    return [draws[int(19999 * .025)], draws[int(19999 * .975)]]


def verify(package):
    manifest = json.loads((package / "evidence-manifest.json").read_text())
    require(manifest["schema"] == "vort.codec.final-evidence.v1", "archive schema")
    archive_file = package / manifest["archive"]["path"]
    require(archive_file.stat().st_size == manifest["archive"]["bytes"] and sha(archive_file) == manifest["archive"]["sha256"], "compressed archive SHA")
    require(sha(package / "verify-evidence.py") == manifest["verifier_sha256"], "verifier SHA")
    require(sha(package / "whole-gate-receipt.json") == manifest["whole_gate_receipt_sha256"], "whole gate receipt SHA")
    for name, item in manifest["gate_artifacts"].items():
        require((package / name).stat().st_size == item["bytes"] and sha(package / name) == item["sha256"], "whole gate artifact SHA")
    documents = {}
    inventory = set()
    with tarfile.open(archive_file, "r:xz") as archive:
        for member in archive:
            require(member.isfile() and not member.name.startswith("/") and ".." not in Path(member.name).parts and member.name not in inventory, "safe unique archive member")
            inventory.add(member.name)
            content = archive.extractfile(member).read()
            item = manifest["entries"][member.name]
            require(len(content) == item["bytes"] and hashlib.sha256(content).hexdigest() == item["sha256"], "raw/source/ELF member SHA")
            if member.name.endswith(".json") and not member.name.startswith("sources/"):
                documents[member.name] = json.loads(content)
    require(inventory == set(manifest["entries"]), "complete inventory")
    original = Path(manifest["original_epoch_root"])
    def relative(path):
        return str(Path(path).relative_to(original))
    for variant in ("baseline", "candidate"):
        registry = documents[variant + "-source-manifest.json"]
        for source, checksum in registry.items():
            require(manifest["entries"]["sources/" + variant + "/" + source]["sha256"] == checksum, "complete frozen source registry")
    for binding in documents["execution-bindings.json"].values():
        require(manifest["entries"][relative(binding["ELF"])]["sha256"] == binding["sha256"], "actual frozen ELF identity")
    results = {}
    for phase in manifest["selected_phases"]:
        raw = documents[phase + "/run-manifest.json"]
        require(raw.get("terminal"), "phase is not terminal")
        if not raw.get("completed"):
            results[phase] = {"state": "failed_first_attempt", "point_GM": None, "no_retry_claim_from_completed_matrix": False}
            continue
        protocol = raw.get("protocol") or documents["protocol.json"]
        expected_rows = protocol.get("rows_expected", protocol.get("rows_count"))
        rounds = protocol.get("rounds", protocol.get("diagnostic_rounds"))
        if manifest["codec"] == "deflate":
            row_order = [row["case"] for row in protocol["rows"]]
            require(rounds == 2, "Deflate remains two-round diagnostic only")
        elif phase == "controls":
            row_order = [row["case"] for row in documents["resolved-controls.json"]["rows"]]
        else:
            row_order = protocol["case_order"]
        require(len(row_order) == expected_rows and len(set(row_order)) == expected_rows, "unique predeclared row keys")
        require(len(raw["pairs"]) == expected_rows * rounds and len(raw["attempts"]) == 2 * expected_rows * rounds, "registered pair/process count")
        require([(pair["round"], pair["case"]) for pair in raw["pairs"]] == [(r, case) for r in range(rounds) for case in row_order], "complete registered shared-round row order")
        ratios = {case: {} for case in row_order}
        seen = set()
        attempts = iter(raw["attempts"])
        for pair in raw["pairs"]:
            variants = pair.get("variants", ["baseline", "candidate"])
            require(variants == (["reference", "candidate"] if phase == "reference" else ["baseline", "candidate"]), "actual pair ratio direction")
            order = variants if pair["round"] % 2 == 0 else list(reversed(variants))
            require(pair["order"] == order and (pair["case"], pair["round"]) not in seen, "paired AB/BA order without retry/drop")
            seen.add((pair["case"], pair["round"]))
            times = {}
            for variant in order:
                attempt = next(attempts)
                require((attempt["case"], attempt["round"], attempt["variant"], attempt["actual_exit_code"]) == (pair["case"], pair["round"], variant, 0), "actual child attempt/order/exit")
                value = documents[relative(attempt["output"])]
                ns = value.get("continuous_owned_encode_mix_free_ns", value.get("continuous_complete_owning_stream_ns"))
                require(type(ns) is int and ns > 0 and ns == pair["processes"][variant]["ns"], "all raw ns preserved")
                wire_path = attempt.get("initial_complete_wire", attempt.get("wire"))
                wire = manifest["entries"][relative(wire_path)]
                require(wire["bytes"] == value["warm_wire_bytes"] and wire["sha256"] == value["warm_wire_sha256"] and value["mix"] == value["iterations"] * value["warm_wire_bytes"], "actual full warm wire and timed lengths/mix")
                require(relative(attempt["stdout"]) in inventory and relative(attempt["stderr"]) in inventory, "all child stdout/stderr")
                times[variant] = ns
            ratio = times[variants[0]] / times[variants[1]]
            require(math.isfinite(ratio) and ratio > 0, "positive finite raw paired ratio")
            ratios[pair["case"]][pair["round"]] = ratio
        require(all(set(value) == set(range(rounds)) for value in ratios.values()), "all actual row/round keys")
        rows = {key: geometric([value[r] for r in range(rounds)]) for key, value in ratios.items()}
        point = geometric(list(rows.values()))
        stored = documents[phase + "/summary.json"]
        stored_rows = stored["row_GMs"]
        require(set(stored_rows) == set(row_order), "published complete row key set")
        published_ratios = stored.get("raw_pair_ratios", stored.get("raw_pair_speedups"))
        require(isinstance(published_ratios, dict) and set(published_ratios) == set(row_order), "published raw ratio row keys")
        for case in row_order:
            require(len(published_ratios[case]) == rounds and all(math.isclose(ratios[case][r], published_ratios[case][r], rel_tol=1e-13, abs_tol=1e-13) for r in range(rounds)), "published raw ratio/order differs")
        require(all(math.isclose(value, stored_rows[key], rel_tol=1e-13, abs_tol=1e-13) for key, value in rows.items()), "data-only point replay matches every stored row")
        if manifest["codec"] == "zstd":
            require(isinstance(stored.get("primary_GM"), (float, int)) and math.isfinite(stored["primary_GM"]) and stored["primary_GM"] > 0, "published equal-row primary GM missing/invalid")
            require(math.isclose(point, stored["primary_GM"], rel_tol=1e-13, abs_tol=1e-13), "equal row primary GM")
        if rounds == 2:
            require(stored.get("CI") is None and stored.get("adoption_allowed") is False, "two-round diagnostic is never acceptance")
        recomputed_ci = None
        if manifest["codec"] == "zstd" and rounds == 6:
            recomputed_ci = shared_round_ci(ratios, row_order, phase)
            published_ci = stored.get("CI")
            require(isinstance(published_ci, list) and len(published_ci) == 2 and all(isinstance(v, (float, int)) and math.isfinite(v) and v > 0 for v in published_ci), "published six-round CI missing/invalid")
            require(all(math.isclose(recomputed_ci[i], published_ci[i], rel_tol=1e-13, abs_tol=1e-13) for i in range(2)), "independently recomputed shared-round CI differs")
        results[phase] = {"state": "completed", "pairs": len(raw["pairs"]), "processes": len(raw["attempts"]), "point_GM": point, "row_GMs": rows, "all_row_point_floor_0_98": all(v >= .98 for v in rows.values()) if phase != "reference" else None, "recorded_CI": stored.get("CI"), "recomputed_CI": recomputed_ci, "CI_independently_recomputed": recomputed_ci is not None, "bootstrap_draws": 20000 if recomputed_ci is not None else 0, "adoption_allowed": False, "no_retry_or_filtered_sample": True}
        if phase == "reference":
            results[phase]["candidate_over_reference_elapsed_GM"] = 1 / point
            results[phase]["candidate_over_reference_wire_size"] = {p["case"]: p["processes"]["candidate"]["wire_bytes"] / p["processes"]["reference"]["wire_bytes"] for p in raw["pairs"]}
    gate = json.loads((package / "whole-gate-receipt.json").read_text())
    ready = documents["SOURCE_READY.json"]
    source_matches = gate.get("source_manifest_sha256") == ready["candidate_source_manifest_sha256"] and ready.get("source_current") is True
    full_passed = gate["state"] == "passed" and gate.get("actual_exit_code") == 0 and gate.get("test_check_check_wasm_all_accepted") is True and source_matches
    require(manifest["full_gate_passed"] == full_passed, "pending/unrun/failed gate was promoted")
    return {"schema": "vort.codec.final-evidence-verification.v1", "inventory_sha_verified": True, "portable_without_original_tmp": True, "phase_states": manifest["phase_states"], "data_only_statistics": results, "whole_gate_state": gate["state"], "full_gate_passed": full_passed, "Deflate_diagnostic_cannot_enable_merge": manifest["codec"] == "deflate", "codec_build_producer_import_or_replay_executed": False}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=Path(__file__).resolve().parent)
    args = parser.parse_args()
    print(json.dumps(verify(args.package.resolve()), indent=2, sort_keys=True))
