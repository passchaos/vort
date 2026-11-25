# Extracted unchanged from tools/decode/evidence.py for candidate/baseline paired statistics.
import math,random,statistics

def bootstrap_log_mean(rows, seed, resamples):
    rng = random.Random(seed)
    # Resample within each row and order so the fixed corpus and AB/BA balance
    # stay unchanged. It estimates sampling uncertainty on this host/matrix.
    strata = [[[(math.log(p["vort_ns"] / p["reference_ns"])) for p in row["pairs"] if p["first"] == order] for order in ("vort", "reference")] for row in rows]
    center = math.exp(statistics.mean(statistics.mean(a + b) for a, b in strata))
    samples = []
    for _ in range(resamples):
        means = []
        for a, b in strata:
            chosen = [rng.choice(a) for _ in a] + [rng.choice(b) for _ in b]
            means.append(statistics.mean(chosen))
        samples.append(math.exp(statistics.mean(means)))
    samples.sort()
    return {"time_ratio_geomean": center, "throughput_ratio_geomean": 1 / center, "ci95": [samples[int(0.025 * resamples)], samples[min(resamples - 1, int(0.975 * resamples))]], "method": "order-stratified paired log-ratio bootstrap; fixed rows", "seed": seed, "resamples": resamples}
