#!/usr/bin/env python3
from collections import Counter
from datetime import datetime, timezone
from itertools import product
from pathlib import Path
import hashlib, importlib.util, json, math, os, random, sys, time
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("frozen_period_model", ROOT / "original_model.py")
model = importlib.util.module_from_spec(spec)
spec.loader.exec_module(model)

def sha(data):
    return hashlib.sha256(data).hexdigest()

def filter_period(data, audit=False):
    n = len(data)
    samples = (0, 1, n // 3, n // 2, n - 1)
    # The proposed sample1 is out of bounds at n=1. Production must preserve
    # generic single-byte handling, or skip/clip that sample explicitly.
    assert n >= 2
    candidates = []
    probes = 0
    d = 1
    while d <= n // d:
        if n % d == 0:
            for p in (d, n // d):
                if p >= n:
                    continue
                candidates.append(p)
                accepted = True
                for index in samples:
                    source = index - p if index >= p else index + n - p
                    assert 0 <= index < n and 0 <= source < n
                    assert source == (index + n - p) % n
                    probes += 1
                    if data[index] != data[source]:
                        accepted = False
                        break
                if accepted:
                    return True, candidates, probes, d
        d += 1
    return False, candidates, probes, d - 1

def divisor_set(n):
    result = []
    d = 1
    while d <= n // d:
        if n % d == 0:
            result += [p for p in (d, n // d) if p < n]
        d += 1
    assert set(result) == {p for p in range(1, n) if n % p == 0}
    return result

def main():
    assert os.sched_getaffinity(0) == {4}
    start = time.monotonic()
    checked = 0
    periodic = 0
    false_positives = 0
    old_exact_cases = 0
    counts = []
    for n in range(1, 11):
        ps = divisor_set(n)
        per_length = Counter()
        for digits in product(range(3), repeat=n):
            data = bytes(digits)
            p = model.least_period_naive(data)
            assert p == model.least_period_kmp(data)
            if n == 1:
                accepted, candidates, probes, iterations = False, [], 0, 0
            else:
                accepted, candidates, probes, iterations = filter_period(data)
            assert iterations <= math.isqrt(n)
            is_periodic = p < n
            assert not is_periodic or accepted, (data.hex(), p, candidates)
            # Any passing divisor only admits KMP, never decides the actual
            # period or enables expansion by itself.
            expanded = accepted and model.least_period_kmp(data) < n
            assert expanded == is_periodic
            if is_periodic:
                model.one_case(data)
                old_exact_cases += 1
            checked += 1
            periodic += is_periodic
            false_positives += accepted and not is_periodic
            per_length["cases"] += 1
            per_length["proper_periodic"] += is_periodic
            per_length["filter_pass"] += accepted
            per_length["false_positives"] += accepted and not is_periodic
        counts.append({"length": n, "divisor_candidates_including_square_duplicates": ps, **per_length})
        print("length", n, dict(per_length), flush=True)
    assert checked == 88572 and periodic == 411 and old_exact_cases == 411
    old = json.loads(Path("/tmp/vort-bzip2-period-proof-20261029.yclgqtbv/results.json").read_text())
    for item in old["periodic_fixtures"]:
        n, p = item["n"], item["p"]
        if item["input_hex"] is not None:
            data = bytes.fromhex(item["input_hex"])
        elif item["base_hex"] is not None:
            data = bytes.fromhex(item["base_hex"]) * item["repetitions"]
        else:
            data = (b"a" * (p - 1) + b"b") * item["repetitions"]
        assert sha(data) == item["input_sha256"]
        accepted, _, _, _ = filter_period(data)
        assert accepted
        model.one_case(data)
        old_exact_cases += 1
    rng = random.Random(0x3A51F927)
    large = [("all_a_900000", b"a" * 900000, 1),
             ("abac_900000", b"abac" * 225000, 4),
             ("two_large_primitive_bases", (b"a" * 449999 + b"b") * 2, 450000),
             ("byte_unique", bytes(range(256)), 256),
             ("random899000", rng.randbytes(899000), 899000),
             ("sample_evasion_single_marker", b"a" * 128571 + b"X" + b"a" * (900000 - 128572), 900000)]
    fixtures = []
    for name, data, p in large:
        accepted, candidates, probes, iterations = filter_period(data)
        assert p == len(data) or accepted
        if name in ["byte_unique", "random899000"]:
            assert not accepted
        if name == "sample_evasion_single_marker":
            assert accepted and candidates[0] == 1
        fixtures.append({"name": name, "length": len(data), "known_exact_period": p,
                         "input_sha256": sha(data), "filter_pass": accepted,
                         "tested_candidates": candidates, "byte_probes": probes,
                         "divisor_loop_iterations": iterations})
    result = {"status": "ok", "finished_utc": datetime.now(timezone.utc).isoformat(),
              "affinity": sorted(os.sched_getaffinity(0)), "wall_seconds": time.monotonic() - start,
              "exhaustive_cases": checked, "proper_periodic_exhaustive_cases": periodic,
              "false_negatives": 0, "false_positive_exhaustive_cases": false_positives,
              "per_length": counts, "additional_prior_periodic_fixtures": len(old["periodic_fixtures"]),
              "full_old_model_exact_periodic_cases": old_exact_cases,
              "large_filter_only_fixtures": fixtures,
              "sqrt_900000_floor": math.isqrt(900000),
              "singleton_handling": "no proper divisor exists; return false without evaluating sample index1",
              "proper_divisor_coverage_complete": True,
              "precheck_never_authorizes_expansion_without_KMP": True,
              "original_model_sha256": sha((ROOT / "original_model.py").read_bytes()),
              "script_sha256": sha(Path(__file__).read_bytes())}
    (ROOT / "results.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({key: result[key] for key in ["status", "exhaustive_cases", "proper_periodic_exhaustive_cases", "false_negatives", "false_positive_exhaustive_cases", "full_old_model_exact_periodic_cases", "sqrt_900000_floor", "wall_seconds"]}, indent=2), flush=True)

if __name__ == "__main__":
    main()
