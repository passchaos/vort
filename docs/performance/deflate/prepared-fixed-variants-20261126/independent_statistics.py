"""Independent data-only recomputation; never evaluates the producer program."""
import math
import random


def require(condition, message):
    if not condition:
        raise ValueError(message)


def geometric_mean(values):
    require(values and all(value > 0 for value in values), "Nonpositive paired ratio")
    return math.exp(math.fsum(math.log(value) for value in values) / len(values))


def bootstrap(log_values):
    rng = random.Random(261126)
    count = len(log_values)
    estimates = []
    for _ in range(20000):
        selected = [log_values[rng.randrange(count)] for _ in range(count)]
        estimates.append(math.exp(math.fsum(selected) / count))
    estimates.sort()
    bounds = []
    for probability in (0.025, 0.975):
        coordinate = probability * (len(estimates) - 1)
        lower = math.floor(coordinate)
        fraction = coordinate - lower
        bounds.append(estimates[lower] * (1 - fraction) +
                      estimates[min(lower + 1, len(estimates) - 1)] * fraction)
    return bounds


def close(actual, expected, label):
    require(math.isclose(actual, expected, rel_tol=1e-12, abs_tol=1e-12),
            "Independent statistic differs: " + label)


def verify(manifest, records, expected, exact_wire_pass):
    require(manifest["pairs"] == 6 and len(records) == 540, "Incomplete independent matrix")
    rows = {row["id"]: row for row in manifest["rows"]}
    planned = {("prepared", row) for row in rows}
    planned.update(("legacy", row) for row in manifest["legacy_control_rows"])
    require(len(planned) == 45, "Unexpected independent row plan")
    indexed = {}
    for record in records:
        key = (record["family"], record["row"], record["pair"], record["side"])
        require(key not in indexed and key[:2] in planned and
                record["pair"] in range(6) and record["side"] in ("A", "B"),
                "Duplicate or unexpected independent sample")
        require(record["returncode"] == 0, "Failed independent sample")
        probe = record["probe"]
        iterations = manifest["iterations_by_row"][record["row"]]
        require(probe["iterations"] == iterations and
                probe["sample"]["length_mix"] == probe["wire_bytes"] * iterations,
                "Independent timed workload differs")
        elapsed = probe["sample"]["elapsed_ns"]
        require(elapsed > 0, "Nonpositive independent elapsed time")
        indexed[key] = elapsed

    recomputed = {}
    for family, row in sorted(planned):
        ratios = [indexed[family, row, pair, "A"] / indexed[family, row, pair, "B"]
                  for pair in range(6)]
        recomputed[family, row] = {
            "ratios": ratios, "gm": geometric_mean(ratios),
            "ci": bootstrap([math.log(ratio) for ratio in ratios]),
        }
    reported = {(row["family"], row["row"]): row for row in expected["rows"]}
    require(set(reported) == planned and len(expected["rows"]) == 45,
            "Reported independent row inventory differs")
    for key, actual in recomputed.items():
        report = reported[key]
        for observed, saved in zip(actual["ratios"], report["pair_speedups"], strict=True):
            close(observed, saved, "paired ratio")
        close(actual["gm"], report["speedup_geomean"], "row geometric mean")
        for observed, saved in zip(actual["ci"], report["paired_95ci"], strict=True):
            close(observed, saved, "row confidence bound")
        require(report["floor_pass"] == (actual["gm"] >= 0.98), "Independent row floor differs")

    targets = [key for key in sorted(planned)
               if key[0] == "prepared" and rows[key[1]]["role"] == "target"]
    require(len(targets) == 24, "Independent target inventory differs")
    outer_logs = [math.fsum(math.log(recomputed[key]["ratios"][pair]) for key in targets) / 24
                  for pair in range(6)]
    target_gm = math.exp(math.fsum(outer_logs) / 6)
    target_ci = bootstrap(outer_logs)
    close(target_gm, expected["prepared_target_geomean"], "target geometric mean")
    for observed, saved in zip(target_ci, expected["prepared_target_paired_95ci"], strict=True):
        close(observed, saved, "target confidence bound")
    flags = {
        "target_geomean_pass": target_gm >= 1.03,
        "paired_ci_pass": target_ci[0] > 1,
        "all_row_floor_pass": all(row["gm"] >= 0.98 for row in recomputed.values()),
        "exact_wire_pass": exact_wire_pass,
    }
    require(all(expected[key] == value for key, value in flags.items()) and
            expected["accepted"] == all(flags.values()), "Independent acceptance differs")
    return {"records": 540, "rows": 45, "targets": 24,
            "prepared_target_geomean": target_gm, "prepared_target_paired_95ci": target_ci,
            "accepted": all(flags.values()), "flags": flags,
            "scope": "Independent data-only ratios and deterministic paired bootstrap; no producer code evaluated"}
