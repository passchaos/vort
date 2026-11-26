"""Preserve and recompute all three completed observational pilot matrices."""
import math
import posixpath
import statistics

from archive_io import load, require


def verify(campaign, mapping):
    output = {}
    fixtures = load(campaign, "fixtures.json")
    for prefix, label in (("pilot", "hash-local"), ("bounded-pilot", "bounded"), ("index-pilot", "index")):
        manifest, summary = load(campaign, prefix + "-manifest.json"), load(campaign, prefix + "-summary.json")
        require(manifest["rounds"] == 2 and "ended_unix" in manifest and len(manifest["pairs"]) == 24, "Pilot completion differs")
        require(manifest["executables"]["candidate"] == mapping["variants"][label]["binary_sha256"], "Pilot variant ELF identity differs")
        require([(pair["round"], pair["case"]) for pair in manifest["pairs"]] ==
                [(index, row["case"]) for index in range(2) for row in fixtures], "Pilot raw pair/order matrix differs")
        ratios = {fixture["case"]: [] for fixture in fixtures}
        for pair in manifest["pairs"]:
            require(pair["order"] == (["baseline", "candidate"] if pair["round"] == 0 else ["candidate", "baseline"]), "Pilot AB/BA differs")
            wires, times = [], {}
            for variant in pair["order"]:
                record = pair["processes"][variant]
                name = prefix + "-runs/" + posixpath.basename(record["path"])
                report, command = load(campaign, name), load(campaign, name.removesuffix(".json") + ".command.json")
                row = report["rows"][0]
                require(command["exit_code"] == 0 and report["provenance"]["executable_sha256"] == manifest["executables"][variant] and
                        row["iterations"] == 1 and len(row["rounds"]) == 1 and row["rounds"][0]["vort_ns"] == record["ns"],
                        "Pilot raw timing/ELF/exit differs")
                require(row["rounds"][0]["vort_mix"] == row["wires"]["vort_bytes"] and
                        row["wires"]["vort_bytes"] == record["wire_bytes"] and row["wires"]["vort_sha256"] == record["wire_sha256"],
                        "Pilot initial wire/length mix differs")
                wires.append(row["wires"])
                times[variant] = record["ns"]
            require(wires[0] == wires[1], "Pilot initial wires differ")
            ratios[pair["case"]].append(times["candidate"] / times["baseline"])
        for row in summary["rows"]:
            ratio = math.exp(statistics.mean(math.log(value) for value in ratios[row["case"]]))
            require(row["time_ratio"] == ratio and row["throughput_ratio"] == 1 / ratio, "Pilot point statistics differ")
        require(summary["throughput_geomean"] == math.exp(statistics.mean(math.log(row["throughput_ratio"]) for row in summary["rows"])),
                "Pilot aggregate differs")
        output[prefix] = {"source_variant": label, "full_summary": summary, "verified_pairs": 24, "all_raw_outliers_retained": True,
                          "scope": "Separate two-round pilot epoch; no cross-pilot source causality or acceptance inferred"}
    return output
