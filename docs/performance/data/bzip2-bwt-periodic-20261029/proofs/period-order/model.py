#!/usr/bin/env python3
"""Independent stable-counting BWT model and exact periodic expansion proof."""
from collections import defaultdict
from datetime import datetime, timezone
from itertools import product
from pathlib import Path
import hashlib, json, os, time

ROOT = Path(__file__).resolve().parent

def sha(data):
    return hashlib.sha256(data).hexdigest()

def least_period_naive(data):
    n = len(data)
    for p in range(1, n + 1):
        if n % p == 0 and all(data[i] == data[i % p] for i in range(n)):
            return p
    raise AssertionError("no period")

def least_period_kmp(data):
    pi = [0] * len(data)
    for i in range(1, len(data)):
        j = pi[i - 1]
        while j and data[i] != data[j]:
            j = pi[j - 1]
        if data[i] == data[j]:
            j += 1
        pi[i] = j
    candidate = len(data) - pi[-1]
    return candidate if len(data) % candidate == 0 else len(data)

def stable_count_sort(order, keys, alphabet):
    counts = [0] * alphabet
    for index in order:
        counts[keys[index]] += 1
    offset = 0
    for i, count in enumerate(counts):
        counts[i] = offset
        offset += count
    result = [0] * len(order)
    for index in order:
        result[counts[keys[index]]] = index
        counts[keys[index]] += 1
    return result

def check_ties(order, n, p, cumulative):
    if p == n:
        return 0
    classes = defaultdict(list)
    for index in order:
        classes[index % p].append(index)
    for residue, observed in classes.items():
        expected = sorted(range(residue, n, p), key=lambda index: (index + cumulative) % n)
        assert observed == expected, (n, p, cumulative, residue, observed, expected)
    return p

def old_full_doubling(data, p):
    n = len(data)
    order = stable_count_sort(list(range(n)), data, 256)
    classes = [0] * n
    class_count = 1
    for i in range(1, n):
        if data[order[i]] != data[order[i - 1]]:
            class_count += 1
        classes[order[i]] = class_count - 1
    shift = 1
    cumulative = 0
    rounds = 0
    tie_checks = check_ties(order, n, p, cumulative)
    while shift < n:
        shifted = [(index - shift) % n for index in order]
        order = stable_count_sort(shifted, classes, class_count)
        next_classes = [0] * n
        next_count = 1
        for i in range(1, n):
            a, b = order[i - 1], order[i]
            if (classes[a], classes[(a + shift) % n]) != (classes[b], classes[(b + shift) % n]):
                next_count += 1
            next_classes[b] = next_count - 1
        classes, class_count = next_classes, next_count
        cumulative += shift
        rounds += 1
        tie_checks += check_ties(order, n, p, cumulative)
        shift *= 2
    assert cumulative == (1 << (n - 1).bit_length()) - 1
    assert class_count == p
    return bytes(data[(i - 1) % n] for i in order), order.index(0), order, cumulative, rounds, tie_checks

def primitive_naive_bwt(base):
    rotations = [base[i:] + base[:i] for i in range(len(base))]
    assert len(set(rotations)) == len(base), (base.hex(), "nonprimitive")
    order = sorted(range(len(base)), key=rotations.__getitem__)
    return bytes(base[(i - 1) % len(base)] for i in order), order.index(0), order

def one_case(data, retain=False):
    p = least_period_naive(data)
    assert p == least_period_kmp(data), data.hex()
    n, r = len(data), len(data) // p
    base = data[:p]
    transformed, pointer, order, cumulative, rounds, ties = old_full_doubling(data, p)
    base_bwt, base_pointer, base_order = primitive_naive_bwt(base)
    predicted_bwt = b"".join(bytes([byte]) * r for byte in base_bwt)
    predicted_pointer = base_pointer * r + ((cumulative // p) % r)
    predicted_order = [index for residue in base_order for index in
                       sorted(range(residue, n, p), key=lambda index: (index + cumulative) % n)]
    assert transformed == predicted_bwt, (data.hex(), "bytes")
    assert pointer == predicted_pointer, (data.hex(), "pointer", pointer, predicted_pointer)
    assert order == predicted_order, (data.hex(), "full order", order, predicted_order)
    if retain:
        return {"input_hex": data.hex() if n <= 100 else None, "input_sha256": sha(data), "n": n,
                "p": p, "repetitions": r, "S": cumulative, "full_rounds": rounds,
                "base_hex": base.hex() if p <= 100 else None,
                "base_pointer": base_pointer, "pointer_offset": (cumulative // p) % r,
                "original_pointer": pointer, "transformed_sha256": sha(transformed),
                "tie_class_checks": ties, "exact_bytes_pointer_and_full_order": True}
    return p < n, ties

def main():
    start = time.monotonic()
    assert os.sched_getaffinity(0) == {4}
    counts = []
    checked, periodic, tie_checks = 0, 0, 0
    for n in range(1, 11):
        local_periodic = 0
        for symbols in product(range(3), repeat=n):
            is_periodic, checks = one_case(bytes(symbols))
            checked += 1
            periodic += is_periodic
            local_periodic += is_periodic
            tie_checks += checks
        counts.append({"length": n, "cases": 3 ** n, "proper_periodic_cases": local_periodic})
        print("exhaustive", n, "cases", 3 ** n, "cumulative", checked, "proper_periodic", local_periodic, flush=True)
    assert checked == 88572
    fixtures = []
    specs = [(b"a", [5, 8, 17, 31, 33, 65, 127, 129, 257, 999]),
             (b"ba", [3, 5, 7, 31, 33, 127]),
             (b"baa", [3, 5, 7, 11, 33, 257]),
             (b"abac", [3, 5, 7, 15]),
             (b"caaab", [3, 5, 7, 15, 33]),
             (b"zzxyxxx", [3, 9, 17, 25])]
    for base, repetitions in specs:
        assert least_period_naive(base) == len(base)
        for r in repetitions:
            fixtures.append(one_case(base * r, True))
    for p, repetitions in [(9, [3, 5, 11]), (11, [3, 7, 13]), (17, [3, 5, 15]),
                           (31, [3, 7]), (127, [3]), (257, [3]), (513, [3])]:
        base = b"a" * (p - 1) + b"b"
        for r in repetitions:
            fixtures.append(one_case(base * r, True))
    # Prefix periods which do not divide n are deliberately not whole cyclic
    # periods. The KMP candidate must be rejected in these cases.
    controls = [one_case(data, True) for data in [b"ababa", b"abababa", b"abaabaab", b"abcabcab", b"banana"]]
    for item in controls:
        assert item["p"] == item["n"]
    result = {"status": "ok", "finished_utc": datetime.now(timezone.utc).isoformat(),
              "affinity": sorted(os.sched_getaffinity(0)), "wall_seconds": time.monotonic() - start,
              "exhaustive_alphabet": [0, 1, 2], "exhaustive_lengths": [1, 10],
              "exhaustive_cases": checked, "proper_periodic_exhaustive_cases": periodic,
              "per_length": counts, "intermediate_tie_class_checks": tie_checks,
              "additional_periodic_cases": len(fixtures), "periodic_fixtures": fixtures,
              "non_integral_period_controls": controls,
              "total_cases": checked + len(fixtures) + len(controls),
              "byte_pointer_full_order_equal": True, "least_period_naive_kmp_equal": True,
              "formula": "base_pointer*r + (floor(S/p) % r), S=2^ceilLog2(n)-1",
              "precondition": "p is the least exact whole-string period dividing n; base is primitive",
              "source_hashes": json.loads((ROOT / "source-identities.json").read_text()),
              "script_sha256": sha(Path(__file__).read_bytes())}
    (ROOT / "results.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({key: result[key] for key in ["status", "exhaustive_cases", "proper_periodic_exhaustive_cases", "additional_periodic_cases", "total_cases", "intermediate_tie_class_checks", "wall_seconds"]}, indent=2), flush=True)

if __name__ == "__main__":
    main()
