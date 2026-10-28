import collections, hashlib, json, lzma, math, re, statistics
from pathlib import Path

root = Path(__file__).resolve().parent
reuse = json.loads(lzma.decompress((root / "reuse-raw.json.xz").read_bytes()))
summary = json.loads((root / "reuse-summary.json").read_text())
expected = {(r["case"], r["group"], r["scope"]): r for r in summary["rows"]}
for run in reuse["runs"]:
    assert run["exit_code"] == 0
    case = run["case"]
    groups = []
    scope = None
    for line in reuse["logs"][case].splitlines():
        if line.startswith("RLE-BEGIN "):
            groups.append([])
        elif line.startswith("RLE-SCOPE "):
            scope = line.split()[1]
        elif line.startswith("RLE-KEY "):
            key = tuple(map(int, re.findall(r"\d+", line[8:])))
            assert len(key) == 18 and sum(key) <= 256
            groups[-1].append((scope, key))
    profile = reuse["profiles"][case]["rows"][0]["rounds"][0]["profile"]
    assert profile["context_details_truncated"] == 0
    assert len(groups) == len(profile["context_details"])
    for index, requests in enumerate(groups):
        counts = profile["context_details"][index]["profile"]
        assert len(requests) == counts["complex_prefix_calls"]
        assert sum(sum(key) for _, key in requests) == counts["complex_prefix_rle_tokens"]
        assert sum(key[16] for _, key in requests) == counts["complex_prefix_repeat16_tokens"]
        assert sum(key[17] for _, key in requests) == counts["complex_prefix_repeat17_tokens"]
        for eligible in ["cluster", "all"]:
            keys = [key for scope, key in requests if eligible == "all" or scope == "cluster"]
            row = expected[case, index, eligible]
            assert len(keys) == row["requests"]
            assert len(set(keys)) == row["distinct_keys"]
            assert len(keys) - len(set(keys)) == row["unbounded_hits"]
            for capacity in [16, 32, 64, 128, 256]:
                cache = collections.OrderedDict()
                hits = 0
                for key in keys:
                    if key in cache:
                        hits += 1
                        cache.move_to_end(key)
                    else:
                        cache[key] = None
                        if len(cache) > capacity:
                            cache.popitem(last=False)
                assert hits == row["lru"][str(capacity)]["hits"]
raw = json.loads(lzma.decompress((root / "ordinary-raw.json.xz").read_bytes()))
ordinary = json.loads((root / "ordinary-summary.json").read_text())
identities, times = {}, {}
for record in raw["raw"]:
    for row in record["result"]["rows"]:
        key = row["case"], row["input_bytes"]
        identity = row["input_sha256"], row["wires"], row["settings"]
        assert row["settings"]["parameters_match"]
        if key in identities:
            assert identities[key] == identity
        identities[key] = identity
        times.setdefault((key, record["label"]), []).extend(r["vort_ns"] / row["iterations"] for r in row["rounds"])
ratios = [statistics.median(times[key, "candidate"]) / statistics.median(times[key, "baseline"]) for key in identities]
ratio = math.exp(statistics.mean(map(math.log, ratios)))
assert len(identities) == 36
assert math.isclose(ratio, ordinary["geometric_ratio"], rel_tol=1e-14)
manifest = root / "SHA256SUMS"
if manifest.exists():
    for line in manifest.read_text().splitlines():
        digest, name = line.split("  ", 1)
        assert hashlib.sha256((root / name).read_bytes()).hexdigest() == digest
print(json.dumps({"diagnostic_calls": len(reuse["runs"]), "ordinary_cases": len(identities), "time_ratio_recomputed": ratio, "profile_counters_and_capacity_replay_verified": True, "all_input_wire_settings_equal": True}))
