#!/usr/bin/env python3
"""Verify frozen three-way raw reports and source reuse offline."""
import argparse
import hashlib
import importlib.util
import itertools
import json
import math
from pathlib import Path
import statistics
import subprocess

HERE = Path(__file__).resolve().parent
ROWS = (("brotli_mozilla_full_11_cold", "brotli/mozilla/full/11", 0.98981748715836, 0.9977163950729292),
        ("brotli_mozilla_1048576_11_cold", "brotli/mozilla/1048576/11", 0.9998991100630439, 1.005779525638996),
        ("brotli_mozilla_full_6_cold", "brotli/mozilla/full/6", 0.9752812702549858, 1.0136873179649009))


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def verify(original=False, git_repo=None, external_fixtures=False):
    reuse = json.loads((HERE / "reuse.json").read_bytes())
    prior = HERE.parent / reuse["prior_package"]
    require(sha((prior / "verify.py").read_bytes()) == reuse["validator_sha256"], "Reused offline validator changed")
    spec = importlib.util.spec_from_file_location("prior_offline", prior / "verify.py")
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    require(sha((prior / "archive-bindings.json").read_bytes()) == reuse["prior_bindings_sha256"], "Prior source/binary binding changed")
    require(sha((prior / "reference-reuse.json").read_bytes()) == reuse["reference_reuse_sha256"], "Reference reuse changed")
    reference = json.loads((prior / "reference-reuse.json").read_bytes())
    repo = prior.parents[3]
    for name in ("modern_manifest", "modern_reference_reuse", "reference_libraries"):
        require(sha((repo / reference[name]["path"]).read_bytes()) == reference[name]["sha256"], "Reused reference/fixture package changed")
    old = {}
    for name, record in reuse["archives"].items():
        require(sha((prior / name).read_bytes()) == record["sha256"], "Prior reused archive changed")
        old[name] = helper.unpack(prior / name)
    binding = json.loads((HERE / "archive-bindings.json").read_bytes())
    groups = {}
    for name, record in binding["archives"].items():
        require(sha((HERE / name).read_bytes()) == record["sha256"], "New archive SHA differs")
        files = helper.unpack(HERE / name)
        require({n: sha(data) for n, data in files.items()} == record["member_sha256"], "Archived member bytes differ")
        require({n: len(data) for n, data in files.items()} == record["member_bytes"], "Archived member lengths differ")
        if original:
            require(all(Path(record["original_paths"][n]).read_bytes() == data for n, data in files.items()), "Original source/report bytes differ")
        groups[name] = files
    screen, sources = groups["screen.tar.gz"], groups["compact-source-probe.tar.gz"]
    manifests = {label: json.loads(screen["screen/" + label + ".manifest.json"]) for label in ("main", "previous", "compact")}
    base = old["baseline-source.tar.gz"]
    previous = {name.removeprefix("cold-fallback-v2/"): data for name, data in old["cold-fallback-v2-source.tar.gz"].items()}
    main = {name.removeprefix("shared-dispatch/"): data for name, data in old["shared-dispatch-source.tar.gz"].items()}
    compact = {name.removeprefix("source/"): data for name, data in sources.items() if name.startswith("source/")}
    require(len(compact) == 8, "Compact source snapshot is not eight files")
    for label, overlay in (("main", main), ("previous", previous), ("compact", compact)):
        source = manifests[label]["source"]
        require(helper.source_digest(source["sha256"]) == source["digest"], "Source digest differs")
        helper.check_sources(source["sha256"], base, overlay)
    require(manifests["main"]["source"]["revision"] == "093d5b9c2793e31a5c23c0913af66ef0c22a5ac5", "Wrong clean main base")
    require(manifests["previous"]["source"]["revision"] == manifests["compact"]["source"]["revision"] == "21952b95e99a6979dd640447f0beebcb16b29f49", "Wrong candidate base")
    binaries = {"main": old["probe-binaries.tar.gz"][reuse["main_binary_member"]],
                "previous": old["probe-binaries.tar.gz"][reuse["previous_binary_member"]], "compact": sources["bin/compact-compare"]}
    for label, data in binaries.items():
        require(sha(data) == manifests[label]["probe_sha256"], "Wrong executable: " + label)
    require(reuse["previous_alias"]["sha256"] == sha(binaries["previous"]) and reuse["previous_alias"]["mode"] == 0o755, "Previous alias identity/mode differs")
    if original:
        alias = Path(reuse["previous_alias"]["path"])
        require(alias.read_bytes() == binaries["previous"] and alias.stat().st_mode & 0o777 == 0o755, "Retained executable alias changed")
    events = json.loads(screen["screen/events.json"])
    require(len(events) == 54, "Expected six permutations x three rows x three executables")
    orders = list(itertools.permutations(("main", "previous", "compact")))
    cursor, summaries = 0, {}
    tasks = {task["fixture"]["key"]: task for task in manifests["main"]["tasks"]}
    for label in ("previous", "compact"):
        require(all(manifests[label][field] == manifests["main"][field] for field in ("references", "config", "environment", "fixtures", "tasks")), "Three-way workload/provenance differs")
    for key, fixture_key, expected_main, expected_previous in ROWS:
        ratios = {"main_over_compact": [], "previous_over_compact": []}
        for pair, order in enumerate(orders):
            values = {}
            for label in order:
                path = "screen/" + key + "." + str(pair) + "." + label
                event = json.loads(screen[path + ".json"])
                require(event == events[cursor], "Combined event differs from original event file")
                cursor += 1
                require(event["order"] == list(order) and event["label"] == label and event["pair"] == pair and event["key"] == key, "Permutation order differs")
                require(event["returncode"] == 0 and event["probe"] == json.loads(screen[path + ".stdout.raw"]), "Raw stdout/returncode differs")
                require(screen[path + ".stderr.raw"] == b"", "Unexpected valid-screen stderr")
                require(not event["before"]["compilers"] and not event["after"]["compilers"], "Compiler observed during screen")
                require(event["argv"][:4] == ["taskset", "-c", "15", manifests[label]["probe"]], "Child command/probe differs")
                helper.validate_probe(event["probe"], tasks[fixture_key], manifests[label])
                values[label] = statistics.median(pair["vort_ns"] for pair in event["probe"]["pairs"])
            for label in ("main", "previous"):
                ratios[label + "_over_compact"].append(values[label] / values["compact"])
        saved = json.loads(screen["screen/" + key + ".summary.json"])
        result = {}
        for field, expected in (("main_over_compact", expected_main), ("previous_over_compact", expected_previous)):
            value = math.exp(statistics.mean(math.log(ratio) for ratio in ratios[field]))
            require(ratios[field] == saved[field]["ratios"] and math.isclose(value, saved[field]["geomean"], abs_tol=1e-15, rel_tol=0), "Summary differs from raw medians")
            require(math.isclose(value, expected, abs_tol=1e-15, rel_tol=0), "Declared candidate ratio differs")
            result[field] = value
        summaries[fixture_key] = result
    initial = groups["initial-noexec.tar.gz"]
    require("initial-noexec/events.json" not in initial, "Initial failed run has final events")
    require(b"Permission denied" in initial["initial-noexec/run.log"] and initial["initial-noexec/brotli_mozilla_full_11_cold.0.previous.stdout.raw"] == b"", "Initial non-executable failure changed")
    require(len([name for name in initial if name.endswith(".json") and ".manifest." not in name]) == 1, "Initial partial event set changed")
    require(b"23/23 tests passed" in groups["runner-builds.tar.gz"]["safe.log"], "Safe correctness proof absent")
    if external_fixtures:
        for _, key, _, _ in ROWS:
            fixture = tasks[key]["fixture"]
            require(sha(Path(fixture["input_path"]).read_bytes()) == fixture["input_sha256"] and sha(Path(fixture["encoded_input_path"]).read_bytes()) == fixture["encoded_sha256"], "Retained fixture bytes changed")
    if git_repo:
        process = subprocess.Popen(["git", "cat-file", "--batch"], cwd=git_repo, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        for name, digest in manifests["main"]["source"]["sha256"].items():
            process.stdin.write((manifests["main"]["source"]["revision"] + ":" + name + "\n").encode()); process.stdin.flush()
            head = process.stdout.readline().split()
            require(len(head) == 3 and head[1] == b"blob", "Clean main Git blob missing")
            data = process.stdout.read(int(head[2])); require(process.stdout.read(1) == b"\n" and sha(data) == digest, "Clean093 main source differs")
        process.stdin.close(); require(process.wait() == 0, "Git blob audit failed")
    return {"schema": "vort.br.compact-context-map-validation.v1", "archives": len(groups),
            "archive_members": sum(map(len, groups.values())), "valid_events": 54, "six_orders_each_row": True,
            "ratios": summaries, "source_registries": {label: len(manifest["source"]["sha256"]) for label, manifest in manifests.items()},
            "initial_noexec_excluded": True, "previous_executable_alias_mode": "0755", "source_reuse_verified": True,
            "original_bytes_checked": original, "immutable093_git_checked": bool(git_repo),
            "external_fixture_bytes_checked": external_fixtures,
            "scope": "Offline raw/source/hash/median/permutation verification only; no codec/test/measurement rerun; candidate rejected; no acceptance or leadership claim"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--original-bytes", action="store_true")
    parser.add_argument("--git-repo", type=Path)
    parser.add_argument("--external-fixtures", action="store_true")
    parser.add_argument("--receipt", type=Path)
    args = parser.parse_args()
    result = json.dumps(verify(args.original_bytes, args.git_repo, args.external_fixtures), indent=2, sort_keys=True) + "\n"
    if args.receipt:
        args.receipt.write_text(result)
    print(result, end="")


if __name__ == "__main__":
    main()
