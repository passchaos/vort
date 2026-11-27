"""New-round acceptance: only six common paired rounds define formal primary."""
import math
import random
import statistics

BOOTSTRAPS = 20000


def geometric(values):
    return math.exp(statistics.mean(math.log(x) for x in values))


def interval(draws):
    ordered = sorted(draws)
    return [ordered[int((len(ordered) - 1) * .025)], ordered[int((len(ordered) - 1) * .975)]]


def paired_rows(pairs, case_order, baseline="baseline", candidate="candidate"):
    rows = {}
    for case in case_order:
        selected = [p for p in pairs if p["case"] == case]
        for pair in selected:
            expected_order = [baseline, candidate] if pair["round"] % 2 == 0 else [candidate, baseline]
            if pair["order"] != expected_order:
                raise ValueError("Actual pair order differs from fixed AB/BA schedule")
            if any(len(pair["processes"][v]["raw_ns"]) != 1 for v in (baseline, candidate)):
                raise ValueError("Main pilot/formal require one timed call per process")
        rows[case] = {p["round"]: statistics.mean(p["processes"][baseline]["raw_ns"]) / statistics.mean(p["processes"][candidate]["raw_ns"]) for p in selected}
        if len(rows[case]) != len(selected):
            raise ValueError("Duplicate case/round; never replace or retry a pair")
    return rows


def point_summary(rows, common_rounds):
    primary_rows = {case: geometric([values[r] for r in range(common_rounds)]) for case, values in rows.items()}
    primary = geometric(primary_rows.values())
    secondary = geometric([geometric(values.values()) for values in rows.values()])
    return {"primary_GM": primary, "primary_row_GMs": primary_rows, "all_primary_row_point_floors_pass": all(x >= .98 for x in primary_rows.values()), "all_sample_equal_row_GM_secondary": secondary, "secondary_can_enable_acceptance": False}


def row_ci(values, seed):
    groups = [[x for r, x in values.items() if r % 2 == parity] for parity in (0, 1)]
    if any(not group for group in groups):
        raise ValueError("Both AB/BA strata required")
    rng = random.Random(seed)
    return interval([geometric([rng.choice(group) for group in groups for _ in group]) for _ in range(BOOTSTRAPS)])


def formal_summary(pairs, case_order, weak_cases, baseline="baseline", candidate="candidate"):
    rows = paired_rows(pairs, case_order, baseline, candidate)
    if len(case_order) != 12 or len(pairs) != 90:
        raise ValueError("Formal requires12 rows/90 complete pairs")
    for case, values in rows.items():
        if set(values) != set(range(12 if case in weak_cases else 6)):
            raise ValueError("Fixed six common rounds plus six weak-only extras required")
    result = point_summary(rows, 6)
    rng = random.Random("round4ctx-primary-six-common-blocks")
    draws = []
    for _ in range(BOOTSTRAPS):
        common = [rng.choice((0, 2, 4)) for _ in range(3)] + [rng.choice((1, 3, 5)) for _ in range(3)]
        draws.append(geometric([geometric([values[r] for r in common]) for values in rows.values()]))
    primary_ci = interval(draws)
    result.update({"primary_common_rounds": 6, "primary_pairs": 72, "primary_95pct_CI": primary_ci, "weak_extra_pairs": 18, "weak_row_CIs_independent_of_primary": {case: {"all12_paired_CI": row_ci(rows[case], case + ":all12"), "extra6_only_paired_CI": row_ci({r: x for r, x in rows[case].items() if r >= 6}, case + ":extra6"), "extra6_GM": geometric([x for r, x in rows[case].items() if r >= 6])} for case in weak_cases}, "target_gate_pass": result["primary_GM"] >= 1.03 and primary_ci[0] > 1 and result["all_primary_row_point_floors_pass"], "adoption_allowed": False})
    return result


def pilot_summary(pairs, case_order, baseline="baseline", candidate="candidate"):
    rows = paired_rows(pairs, case_order, baseline, candidate)
    if len(pairs) != 24 or len(case_order) != 12 or any(set(x) != {0, 1} for x in rows.values()):
        raise ValueError("Pilot requires12 rows ×2 AB/BA pairs")
    result = point_summary(rows, 2)
    result.update({"CI": None, "point_screen_pass": result["primary_GM"] >= 1.03 and result["all_primary_row_point_floors_pass"], "adoption_allowed": False})
    return result
