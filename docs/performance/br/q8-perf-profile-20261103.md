# Brotli q8 perf profile and rejected ring experiment, 2026-11-03

`perf record` on the public planned encode bench with the 8 MiB XML prefix
attributes 41.94% of process cycles to the q8 planned route. The single hottest
self symbol is `lz77.findBestHashMatchWithLayout`: 46.24% of the complete
process, about 19.5% inside q8 and 21.9% inside the ratio route.

Within q8, the children are:

| Path | Share of process |
| --- | ---: |
| `lz77.lazyGreedyPlanAlloc` | 20.36% |
| `lz77.findBestHashMatchWithLayout` under it | 18.54% |
| `encodeLazyCommandPlanAllocRecorded` | 11.51% |
| `context_candidate_group.encodeCore` | 9.72% |
| physical `encodeCommandPlanWithOptionsAllocRecorded` | 4.05% |
| counted `prepareCommandPlanWithOptionsRecorded` | 3.50% |
| prepared emission | 2.03% |
| `parameter_pair.against` | 9.26% |
| `chooseDistanceParameterAlternativeAlloc` | 5.67% |

The matcher, distance chooser and context candidate group are the next q8
targets. The profile is diagnostic; it is not an ordinary throughput sample.

## Rejected ring predecessor experiment

A window-sized `prev` ring for the lazy parser would keep the hash chain in
cache and shrink the predecessor table from one entry per input byte to 64 Ki
entries. The experiment preserved wire bytes exactly on the six-file q8 screen
but was slower: geometric time ratio **1.0216** (about 2.2% slower), with
dickens +4.2%, sao +2.6%, xml +2.8%, ooffice +2.3%, osdb +1.0% and x-ray
+0.04%. The full-input predecessor table remains the adopted layout; the ring
was reverted and is not part of the production source.

[Raw ring rows](q8-ring-rejected-20261103.csv) retain the paired timings and
wire equality.

## Rejected counted plain baseline

The context group's plain baseline was prepared with the counted path and
emitted only when it won, instead of always materializing it. Wire bytes stayed
identical, but the six-file screen measured geometric time ratio **1.0102**
(about 1.0% slower); only XML improved (0.9955). Plain counting costs roughly
the same as its physical emission, and when plain wins the counted path adds a
second emission pass. The experiment was reverted.

[Raw counted-plain rows](q8-counted-plain-rejected-20261103.csv) retain the
paired timings and wire equality.

## Rejected tree-score cache growth

Doubling the literal tree-score cache from 128 to 256 entries reduced reported
conflict misses but reclassified the same total misses as cold misses (for
example, XML lazy stayed at 244 total misses). Cluster-score time moved only
within noise, and the three-slice outer times were mixed (XML −1.8%, Dickens
−0.4%, x-ray +0.6%). The capacity change was reverted.

## Rejected maximum-distance precheck

Supplying the largest semantic distance so parameter shapes could reject
unrepresentable distances before scanning their frequencies preserved wire
bytes but measured geometric time ratio **1.0007** (about 0.07% slower); x-ray
was 0.38% slower. The existing per-distance failure path is already cheap
enough. The experiment was reverted.

[Raw maximum-distance rows](q8-max-distance-rejected-20261103.csv) retain the
paired timings and wire equality.
