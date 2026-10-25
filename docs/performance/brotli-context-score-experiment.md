# Brotli q8 context score experiment

Date: 2026-10-25. Baseline: `4098b386`. The objective of industry-best
functionality and performance remains incomplete.

The public q8 encoder's preferred stage contains recent-distance analysis,
context proposals and candidate preparation. This increment separates the
actual recent-distance scan and context proposal call, and records the
proposal search that returns the candidates consumed by the encoder. It also
investigates sharing exact tree scores across a single immutable Analysis.
The shared-cache candidate was withdrawn after public measurements did not
show a speed benefit. The final runtime retains the original mode-local
cluster cache and direct baseline/suffix scores.

## Actual diagnostics and restored policy

`chooseProposalsProfiled` performs one Analysis and returns that call's actual
suffix, up-to-16 and full proposals. Ordinary encoding calls the same core
with observation disabled. q8 retains its original lazy/optimal parse limits,
all four RFC context modes, cutoff/seed/cluster loops, scorer, tie order and
exact final-wire arbitration. No search is repeated solely to report details.

Two new event children, `recent_distance_scan` and `context_proposals`, are
subtracted once from their preferred parent. Eight caller-owned fixed detail
slots link the real context call through event ID, origin, variant and command
count. Internal mode/tree/Huffman/prefix times are inclusive diagnostics and
are not added into the outer exclusive stage totals a second time. Capacity
truncation affects reporting rather than candidate selection.

Final baseline and suffix trees are scored directly. Cluster tree caches and
map caches remain per-mode, with the original 128 tree slots. An extracted
`literal_tree_score_cache.zig` module retains complete frequency equality,
occupancy checks and success-only publication. Its normal layout has no
experimental origin metadata. Direct calls have their own total/scope/mode
counts; they are not represented as lookup misses. Completed samples obey:

```text
cache requests = hits + misses
cache misses = cold misses + conflict misses
tree score calls = cache misses + uncached calls
uncached calls = baseline direct calls + 2 * suffix payload scores
```

The global baseline is one call for a valid Analysis and has no mode. Early
empty/invalid-analysis results have no baseline call. All simple/complex,
active-symbol, Huffman and prefix counters describe actual scorer executions.
These completed-sample identities do not certify partially failed calls.

The old literal-context CSV tool now uses the same uncached accounting and
correct tree parent range (`baseline + suffix + cluster_score`). Historical
hotspot proportions are retained behind `--require-historical-dominance`;
default validation checks evidence consistency and reports the observed
hotspot. The tool reads only its required first 32 KiB of source, avoiding the
old 2 MiB whole-file cap without changing its 4/16/32 KiB input bytes.

## Rejected shared-cache candidate

The candidate shared one 128-slot direct-mapped tree memo across baseline,
suffix, clusters and four modes in one Analysis. Every key compared all 256
initialized u32 frequencies and cached the unchanged exact tree bit cost.
Suffix right keys were completely zero-initialized. The context-map cache
stayed mode-local because its map-only key cannot identify a cross-mode score.
Pure scoring and assignment functions matched the baseline byte-for-byte.

The candidate passed native Debug, native ReleaseFast and actual 32-bit x86
literal-context filters, each 75/75. The complete native Brotli family passed
1421 tests with one skip and no failure. Core/build hashes stayed unchanged;
three known independent legacy diagnostic-tool edits occurred during that
family run and are reported separately. Candidate build checks passed 173/173,
and CLI help passed 7/7. Later tool fixes have their own source epoch.

Fourteen frozen 64 KiB inputs run q8/generic on CPU8, i7-10700K, Zig 0.16.0
ReleaseFast. Five alternating Vort/reference rounds per input use explicit
libbrotli encoder/decoder/common 1.2.0-dev experimental Release files from
checkout `558fc647`. The default-policy comparison retains Vort window16
versus reference lgwin22; equal quality numbers are not algorithm equivalence.
Input, executable, source and requested reference-file identities remain
fixed, and compiler observations are zero during accepted timings. Requested
library-file hashes do not verify complete loader dependency closure.

| Ordinary version comparison | Candidate/old throughput geometric ratio |
| --- | ---: |
| First fourteen-input, five-round screen | 0.992884x |
| Alternating version process pair 1 | 0.998682x |
| Alternating version process pair 2 | 0.993807x |
| Alternating version process pair 3 | 0.993618x |
| Geometric ratio across three pairs and fourteen rows | 0.995366x |

These are point comparisons with all raw samples retained, without a
statistical-significance claim. They do not support a public speed benefit.
All fourteen Vort/reference frame identities and settings stay unchanged;
Vort total output remains 288091/296445 reference bytes, with nine smaller
Vort frames. The first candidate screen loses every reference throughput row,
with a geometric ratio of 0.0271200x. These are candidate-epoch results, not a
new ranking of the restored runtime.

Seventy instrumented calls match ordinary and previous wire identities. Their
ordered wire/selection configurations, lengths and decisions match the prior
profile. Event IDs, parent links and clocks naturally change with new scopes;
the semantic comparison does not compare intermediate wire hashes that were
not recorded. Independent report gates validate each version's own links and
exclusive-time conservation.

| Candidate instrumented stage median | Mozilla 64 KiB | Source 64 KiB |
| --- | ---: | ---: |
| Outer call | 105.606 ms | 38.541 ms |
| Recent-distance scan, exclusive | 0.109829 ms | 0.106108 ms |
| Context proposals, exclusive | 73.876 ms | 8.560 ms |

Separate medians are nonadditive. Deep profiling adds clocks and shape/counter
observations, so differences from the earlier profile cannot be assigned to
pure cache work or ordinary throughput. Mozilla lazy/optimal calls have
1585/1587 actual tree scores, zero cross-mode hits and only 12/7 cross-scope
hits. Source has 636/641 scores and 2/3 cross-mode hits. Same-scope hits already
available to the original cache are not new benefits. Cross-scope and
cross-mode categories can overlap and must not be added as distinct hits.
The Mozilla tree-length stage is the largest measured tree-score component;
its uninstrumented cost needs a separate exact-scorer investigation.

Pinned candidate ELF confirms one shared memo address reaches all four mode
calls, without four simultaneous copies. The normal cache ABI grows from
133168 to 133552 bytes on 64-bit and 133152 to 133536 on x86. Ordinary
hit/miss increments remain in the ELF; timer and origin query/publication do
not. Whole-memo initialization still touches its experimental metadata.
Named function stack reservations describe local compiler allocation only,
not complete call-chain stack or RSS. The shared candidate is therefore
withdrawn rather than accepted on cache hit counts or a hotspot estimate.

## Final validation and evidence

Final restored-runtime verification is recorded separately from the rejected
candidate above. Native Debug and actual x86 ReleaseFast combined context/q8
contracts each pass 76/76. The independent malformed-report smoke passes
14/14. Cache ABI is restored to 133168 bytes on 64-bit and 133152 on x86;
fixed diagnostic Profile storage is 161648/108944 bytes respectively.
Caller-owned diagnostics remain outside the codec requested-heap ledger.
The final native ReleaseFast Brotli family passes 1421 tests with one skip
and no failure under a stable full src/tools/build manifest.
Final ordinary version throughput point ratio is 0.988794x in the initial
screen and 0.986497x across three supplemental alternating process pairs.
The individual pair ratios are 0.989264x, 0.985403x and 0.984829x. This
diagnostic/refactoring increment has no demonstrated speed benefit; the
approximately 1.35% negative aggregate point difference is retained explicitly
without assigning statistical significance or a CPU-time cause. The extracted
ordinary cache helper remains a candidate for examining compiler call overhead
in the next bounded investigation. The restored first-screen reference
throughput geometric ratio is 0.0271625x, with zero reference wins.

Final build checks pass 173/173, and the restored legacy profile/gate smoke
passes 10/10 steps, including 21 negative and four positive evidence cases.
All fourteen ordinary wires/settings and seventy actual profiled wires retain
the old identities and pass the independent report gate. Ordered common wire
candidates and decisions also match the earlier seventy rounds.
A separate pinned restored ELF review confirms direct baseline/suffix scoring,
mode-local cluster memo initialization and absent normal profile clocks. The [evidence package](data/brotli-context-score-20261025/artifact-manifest.json)
preserves both source epochs, failed
QA/tool attempts and their fixes, full-frequency invariants, actual wire and
candidate decisions, raw ordinary/profile/process-pair rounds, source and
executable bindings, and final handoff checks.

The next bounded optimization should measure the unchanged exact tree-length
scorer on actual q8 histograms, then validate any faster kernel against the
reference before evaluating ordinary encoding. Broader Brotli/Zstd level,
streaming, platform and cross-library memory comparisons remain open.
