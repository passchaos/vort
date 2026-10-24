#!/usr/bin/env python3
"""Small public Zstd HQ search controls and complete-wire safeguards."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import random
import sys

sys.dont_write_bytecode = True
from hq_controls_diff import ROOT, ModernReference, reference_module, reference_encode, require, digest
from hq_search_wire import scan

OLD_REVISION = "97c4ad9956e7d8f4a9ffb1a690bf341ab1fc3ef4"
STRATEGIES = {"btopt": 7, "btultra": 8, "btultra2": 9}


class References:
    def __init__(self, helper):
        self.modern = ModernReference(helper)
        self.system = reference_module.Zstd()

    def verify(self, wire, payload, dictionary=b""):
        self.modern.verify(wire, payload, dictionary)
        self.system.verify(wire, payload, dictionary)

    def encoded(self, payload, strategy, dictionary=b""):
        return [("modern", self.modern.encode(payload, strategy, dictionary)),
                ("system", reference_encode(self.system, payload, strategy=STRATEGIES[strategy], dictionary=dictionary))]

    def provenance(self):
        libraries = {Path(line.split()[-1]).resolve() for line in Path("/proc/self/maps").read_text().splitlines()
                     if "libzstd.so" in line and line.split()[-1].startswith("/")}
        libraries.discard(self.modern.runtime_path)
        require(len(libraries) == 1, "exact system Zstd runtime path")
        path = libraries.pop()
        return {"modern": self.modern.provenance(), "system": {"version": self.system.version,
                "runtime_library": str(path), "runtime_library_sha256": digest(path.read_bytes())}}


def call(probe, directory, name, payload, config, expected_error=None):
    source, output, settings = [directory / (name + suffix) for suffix in (".input", ".wire", ".json")]
    source.write_bytes(payload);output.write_bytes(b"existing output sentinel");settings.write_text(json.dumps(config) + "\n")
    result = reference_module.run(probe, source, output, settings)
    stats = json.loads(result.stdout)
    require(stats["error"] == expected_error, (name, config, stats))
    if expected_error:require(output.read_bytes() == b"existing output sentinel", "failed search changed output")
    event = {"name": name, "expected_error": expected_error, "report": stats}
    with (directory / "search-events.jsonl").open("a") as log:log.write(json.dumps(event) + "\n")
    return output.read_bytes(), stats


def corpus(directory, references):
    text = b"public HQ search controls ABCabcABCabc_xyz\n" * 3
    base = {"mode": "native", "checksum": True, "content_size": True, "window_log": 17, "search_depth": 8,
            "nice_len": 64, "min_match": 3, "block_size": 256, "frame_size": 128,
            "input_chunk": 31, "output_chunk": 47, "max_working_memory": 128 * 1024 * 1024}
    cases = []
    for strategy in STRATEGIES:
        for parse, lengths in (("whole_block", "sampled"), ("bounded", "complete"), ("whole_block", "complete")):
            for api in ("one_shot", "reusable", "incremental", "seekable"):
                cases.append({"name": strategy + "-" + parse + "-" + lengths + "-" + api, "payload": text,
                              "config": {**base, "strategy": strategy, "api": api, "parse_mode": parse, "match_lengths": lengths}, "dictionary": b""})
    raw = random.Random(0x97c4ad99).randbytes(4096)
    raw_path = directory / "raw.dictionary"
    if raw_path.exists():require(raw_path.read_bytes() == raw, "fixed raw prefix changed")
    else:raw_path.write_bytes(raw)
    full_path = directory / "standard.dictionary"
    if full_path.exists():full = full_path.read_bytes()
    else:
        samples = [(text + b"dictionary corpus " + str(index).encode()) * 3 for index in range(96)]
        full = references.modern.train(samples);full_path.write_bytes(full)
    for name, dictionary, path, payload, standard in (("raw", raw, raw_path, raw[-75:] + b"end", False),
                                                   ("standard", full, full_path, text, True)):
        cases.append({"name": "dictionary-" + name, "payload": payload, "dictionary": dictionary,
                      "config": {**base, "strategy": "btultra2", "api": "one_shot", "parse_mode": "whole_block", "match_lengths": "complete",
                                 "dictionary_path": str(path), "full_dictionary": standard, "content_size": False}})
    rng = random.Random(0x131072)
    large = bytearray(rng.randbytes(131072));large[131072 - 96:] = large[64:64 + 96]
    cases.append({"name": "full-128k-position-span", "payload": bytes(large), "dictionary": b"",
                  "config": {**base, "strategy": "btopt", "api": "one_shot", "parse_mode": "whole_block", "match_lengths": "sampled",
                             "block_size": 131072, "search_depth": 4, "nice_len": 32}})
    for length in (69, 75):
        prefix = random.Random(length).randbytes(112)
        payload = prefix + prefix[:length] + b"tail-interior-copy-choice!"
        cases.append({"name": "ordinary-interior-" + str(length), "payload": payload, "dictionary": b"",
                      "config": {**base, "strategy": "btopt", "api": "one_shot", "parse_mode": "whole_block", "match_lengths": "complete"}})
    return cases, base, text


def baseline(args, references, base, text):
    path = args.output_dir / "search-baseline.json"
    if path.exists():
        old = json.loads(path.read_text());require(old["revision"] == OLD_REVISION, "independent old search baseline revision");return old
    require(args.legacy_probe and args.legacy_source, "legacy source/probe required only for initial old wire freeze")
    configs = [{**base, "strategy": strategy, "api": api} for strategy in STRATEGIES for api in ("one_shot", "incremental")]
    configs += [{"mode": "default"}, {"mode": "native-default"}]
    rows = []
    for index, config in enumerate(configs):
        name = "baseline-" + str(index)
        wire, _ = call(args.legacy_probe, args.output_dir, name, text, config)
        references.verify(wire, text)
        rows.append({"name": name, "config": config, "input": name + ".input", "wire": name + ".wire",
                     "input_sha256": digest(text), "wire_sha256": digest(wire)})
    files = [args.legacy_source / "src/root.zig", args.legacy_source / "src/zstd.zig", args.legacy_source / "tools/zstd/hq_controls_probe.zig",
             *sorted((args.legacy_source / "src/zstd").rglob("*"))]
    old = {"schema": "vort-zstd-hq-search-old-wire-v1", "revision": OLD_REVISION, "rows": rows,
           "probe_sha256": digest(args.legacy_probe.read_bytes()), "source_sha256": {str(file.relative_to(args.legacy_source)): digest(file.read_bytes()) for file in files if file.is_file()}}
    path.write_text(json.dumps(old, indent=2) + "\n");return old


def campaign(args, cases, references, old, base, text):
    rows = []
    if not args.case:
        for row in old["rows"]:
            payload, expected = [(args.output_dir / row[field]).read_bytes() for field in ("input", "wire")]
            require(digest(payload) == row["input_sha256"] and digest(expected) == row["wire_sha256"], "frozen old wire hash")
            current, _ = call(args.probe, args.output_dir, "regression-" + row["name"], payload, row["config"])
            require(current == expected, "default bounded sampled wire changed")
    for case in cases:
        name, payload, config, dictionary = case["name"], case["payload"], case["config"], case["dictionary"]
        if args.case and name not in args.case:continue
        baseline_config = {**config, "parse_mode": "bounded", "match_lengths": "sampled"}
        bounded, _ = call(args.probe, args.output_dir, name + "-bounded", payload, baseline_config)
        wire, stats = call(args.probe, args.output_dir, name, payload, config)
        require(stats["resolved"]["parse_mode"] == config["parse_mode"] and stats["resolved"]["match_lengths"] == config["match_lengths"], "requested search controls resolution")
        profile = stats["profile"]
        require(profile["baseline_searches"] > 0, "expanded mode did not execute its safeguard search")
        if config["parse_mode"] == "whole_block":require(profile["whole_block_passes"] > 0, "whole mode ran no actual whole parse")
        if config["match_lengths"] == "complete":require(profile["complete_length_passes"] > 0, "complete mode ran no actual complete length choices")
        if name == "full-128k-position-span":require(profile["max_parse_positions"] == 131072, "whole block failed to search full format-block span")
        if config["api"] != "incremental":
            require(len(wire) <= len(bounded) and profile["guarded_frames"] > 0, "complete frame safeguard wire/counter mismatch")
        off, off_stats = call(args.probe, args.output_dir, name + "-off", payload, {**config, "profile_enabled": False, "total_profile_enabled": False})
        require(off == wire and off_stats["resolved"] == stats["resolved"], "instrumentation changed wire or resolution")
        envelope = scan(wire)
        if config["content_size"]:require(envelope["content_size_sum"] == len(payload), "independent FCS accounting")
        if dictionary:require(profile["dictionary_sequences"] > 0, "dictionary case emitted no dictionary reference")
        references.verify(wire, payload, dictionary)
        result_rows = []
        for layer, independent in references.encoded(payload, config["strategy"], dictionary):
            decoded, _ = call(args.probe, args.output_dir, name + "-reverse-" + layer, independent, {**config, "operation": "decode"})
            require(decoded == payload, "Vort decoded independent reference wire")
            result_rows.append({"layer": layer, "status": "ok", "direction": "bidirectional"})
        rows.append({"name": name, "config": config, "input_bytes": len(payload), "wire_bytes": len(wire), "bounded_wire_bytes": len(bounded),
                     "wire_sha256": digest(wire), "strict_wire_improvement_over_corresponding_current_baseline": len(wire) < len(bounded),
                     "wire_comparison_scope": "separate same-state block safeguard statistics; no standalone legacy full-frame promise" if config["api"] == "incremental" else "complete frame/seekable stream against same-config bounded sampled bytes",
                     "probe": stats, "envelope": envelope, "reference_results": result_rows})
    budget = None
    if not args.case:
        config = {**base, "strategy": "btultra2", "parse_mode": "whole_block", "match_lengths": "complete"}
        wire, measured = call(args.probe, args.output_dir, "budget-measure", text, config)
        peak = measured["profile"]["max_plan_price_evaluations"]
        require(peak > 1, "per-plan budget has no counted choices")
        exact, stats = call(args.probe, args.output_dir, "budget-exact", text, {**config, "max_price_evaluations": peak})
        require(exact == wire and stats["profile"]["max_plan_price_evaluations"] <= peak, "exact independent DP budget changed wire or exceeded cap")
        require(stats["profile"]["price_evaluations"] > peak, "aggregate work did not demonstrate multiple independently capped plans")
        failures = []
        for name, cap in (("budget-below", peak - 1), ("budget-zero", 0)):
            _, failed = call(args.probe, args.output_dir, name, text, {**config, "max_price_evaluations": cap}, "SearchLimitExceeded")
            require(failed["profile"]["max_plan_price_evaluations"] <= cap, "failed plan admitted beyond its cap")
            require(failed["memory_profile"]["live_requested_bytes"] == 0, "price failure left live owned heap")
            failures.append({"limit": cap, "max_plan_price_evaluations": failed["profile"]["max_plan_price_evaluations"], "price_limit_refusals": failed["profile"]["price_limit_refusals"]})
        cap_only = {**base, "strategy": "btopt", "max_price_evaluations": (1 << 64) - 1}
        _, stats_only = call(args.probe, args.output_dir, "cap-only", text, cap_only)
        require(stats_only["profile"]["baseline_searches"] == 0 and stats_only["profile"]["guarded_frames"] == 0, "budget-only controls added a search safeguard")
        call(args.probe, args.output_dir, "unsupported-strategy", text, {**config, "strategy": "lazy2"}, "InvalidBlockPlan")
        call(args.probe, args.output_dir, "invalid-parse-mode", text, {**config, "parse_mode": "invalid"}, "InvalidBlockPlan")
        call(args.probe, args.output_dir, "into-error", text, {**config, "api": "into", "output_capacity": 0}, "OutputTooSmall")
        call(args.probe, args.output_dir, "workspace-zero", text, {**config, "max_working_memory": 0}, "WorkingMemoryLimitExceeded")
        cycle_wire, cycle = call(args.probe, args.output_dir, "reusable-profile-cycle", text,
                                 {**config, "api": "reusable", "max_price_evaluations": peak, "verify_reusable_cycle": True})
        require(cycle_wire == wire and cycle["reusable_cycle_verified"], "reusable accumulation/reset cycle changed exact-budget wire")
        budget = {"per_plan_limit": peak, "actual_max_plan": measured["profile"]["max_plan_price_evaluations"],
                  "aggregate_price_evaluations": stats["profile"]["price_evaluations"], "failures": failures,
                  "reusable_profile_cycle_verified": cycle["reusable_cycle_verified"],
                  "scope": "requested search failure is returned before a wire safeguard; limit applies to each DP plan, not cumulative profile work"}
    return rows, budget


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", type=Path);parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--legacy-probe", type=Path);parser.add_argument("--legacy-source", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True);parser.add_argument("--prepare-only", action="store_true");parser.add_argument("--case", action="append")
    args = parser.parse_args()
    for name in ("probe", "reference", "legacy_probe", "legacy_source", "output_dir"):
        if getattr(args, name):setattr(args, name, getattr(args, name).resolve())
    args.output_dir.mkdir(parents=True, exist_ok=True)
    references = References(args.reference);cases, base, text = corpus(args.output_dir, references)
    if args.case:require(set(args.case) <= {case["name"] for case in cases}, "unknown search stage case")
    old = baseline(args, references, base, text)
    require(args.prepare_only or args.probe, "--probe needed for actual expanded searches")
    files = [ROOT / "build.zig", *sorted((ROOT / "src").rglob("*")), *sorted((ROOT / "tools/zstd").glob("hq_search*"))]
    before = {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in files if path.is_file()}
    rows, budget = ([], None) if args.prepare_only else campaign(args, cases, references, old, base, text)
    after = {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in files if path.is_file()}
    if not args.case:require(before == after, "source changed during final HQ search campaign")
    report = {"schema": "vort-zstd-hq-search-v1", "status": "prepared" if args.prepare_only else "ok", "utc": datetime.now(timezone.utc).isoformat(),
              "rows": rows, "price_budget": budget, "references": references.provenance(), "baseline_rows": len(old["rows"]),
              "baseline_manifest_sha256": digest((args.output_dir / "search-baseline.json").read_bytes()), "stage_cases": args.case,
              "source_sha256": before, "source_after_sha256": after, "source_before_after_equal": before == after,
              "probe_path": str(args.probe) if args.probe else None, "probe_sha256": digest(args.probe.read_bytes()) if args.probe else None,
              "scope": "public search work and actual compatible wires; strict model-cost/offset selection is independently covered by QA, no quality/performance inference from profile counts"}
    path = args.output_dir / "hq-search-report.json";path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "rows": len(rows), "baseline_rows": len(old["rows"]), "report": str(path)}))


if __name__ == "__main__":main()
