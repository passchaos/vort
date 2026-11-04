# Reuse command models across candidate families, 2026-11-03

An immutable ordinary Brotli command plan now keeps its common preparation
alive from preferred context selection through its entropy split candidates.
Previously the preferred group released that stack scope, then adaptive
literal and adaptive distance each rebuilt the same unsplit command model.
The new cohesive group owns the existing fixed descriptor for the synchronous
call and exposes borrowed views to the later preparations. It allocates no
new retained command stream or cache.

Adaptive literal borrows the command/distance alphabets, lengths, encoders,
frequencies and extra-bit total. It still validates input geometry and the
complete split, builds its own per-type literal trees and owned split code,
counts the real header and payload, and emits only a strictly smaller wire.
Adaptive distance borrows only command-model fields. Its command projection,
recent-distance simulation, extras, per-type distance histograms, trees,
symbol streams and split artifacts remain independently prepared and owned.
The unsplit distance tree is not substituted for any split tree.

The first supported lifetime is standard windows 10–24, 8–64 KiB inputs,
bounded ordinary commands, recent distances and clustered context search with
an adaptive split family enabled. Short-match alternatives and exact commands
retain the original controller. A borrowed helper requires a published
matching key and standard distance parameters `(0,15)`; all other legal cases
retain the owned route. The key includes command identity, window, distance
parameters, compound dictionary size, starting output position, distance ring
and the requested same-last flag. Recent distances disable effective same-last
recoding, preserving the original model decisions.

The owner must remain alive and immutable throughout the borrowed preparation.
Each helper owns only its original allocations, and deinit never releases the
borrowed model. Readiness and keys are checked again before output. Inline
model storage is not read when the pointer-backed view is selected. The public
controller does not return a preparation or pointer beyond the group scope.

## Actual work and independent validation

Public q8 fixtures at 8/16/64 KiB execute two separate lazy/optimal groups.
They borrow adaptive literal models 1/2/2 times. Successful common captures
fall 2→1, 4→2 and 4→2 respectively. The 64 KiB fixture also borrows the adaptive
distance command model twice, reducing its independent command-model builds
2→0 while retaining complete command scans and distance-tree construction.
Every complete wire, summary and decoded input agrees with the original
independent-preparation controller.

Seventeen real adaptive-literal configurations compare complete models,
header/payload costs, wire, stats and decoding against owned preparation and
the original full writer. They cover small/complex alphabets, types 2–8 and
more than 128 commands. Poisoning unused inline common storage proves the
real serializer and stats use the borrowed model. Four alternating plans reuse
one unchanged owner. Twenty initialization refusals and three stale-owner
output refusals cover readiness, keys, options, plan geometry and overflow.
Both actual initialization allocation sites and the output allocation fail
cleanly in independent OOM sweeps. Debug/ReleaseSafe/ReleaseFast each pass the
22-test production filter.

The adaptive-distance module compares 18 model configurations, complete
projected symbols and lengths, all owned distance data, split/map fields,
active encoders, actual writer output and counted size. Thirteen key refusals,
18 owner-revocation cases and all reached allocation failures preserve
borrowed data and ownership. Debug/ReleaseSafe/ReleaseFast each pass three
tests, including the old owned options without a same-last field. Sparse
encoder inactive slots are deliberately excluded: production initializes and
reads only its active support, while complete length arrays and emitted wires
remain fully compared.
The module writer tests use a deterministic model-probe header; the public
group tests separately compare complete Brotli frames and native decoding.

The public group filter passes 31 tests in ReleaseSafe, including twelve
fallback/resource cases. Metadata, Large Window, small/oversized input,
low-quality/no-context and no-copy random cases preserve original wires and
decode. Requested-heap peaks are unchanged on the tested 8 KiB structured
fixture (490,516 bytes) and Mozilla 64 KiB (2,658,114 bytes). Their exact peak
limits pass; one byte below is rejected with zero final live bytes. These
results establish the tested allocator contracts, not stack/RSS or competitor
memory leadership.

Actual 32-bit x86 ReleaseSafe public execution also passes 31 tests with the
same model-work reductions. Its structured 8 KiB requested peak stays
458,292 bytes, with the same exact-limit and one-below behavior. The public
prepared-command Wasm gate passes all five steps, frozen full output and
Zig/Node decoding. These platform results establish the exercised functionality;
ordinary performance is measured separately on x86-64.

The final complete ReleaseSafe Brotli suite passes 1,526 tests with one
existing platform skip out of 1,527, with exit zero. Narrow and complete
results bind the same fixed source; a focused pass is not used to infer the
status of any still-running broader build.
The final default native/Wasm `check check-wasm` gate completes 212/212
steps with exit zero. Its original process is observed to completion.

## Evidence scope

Baseline source is `0e0d1541`. The first selected-input screen verifies 66
processes with unchanged full wires. It is retained separately from the final
39-input matrix. The initial profile build fails its all-source stability
check when new independent tests change; it is not accepted as a final build.
After every test file is fixed, final benchmark/profile builds bind the same
1,807 source/build/tool identities and a complete source archive.

## Final ordinary q8 matrix

The public quality API runs q8/generic/actual window16 with matching reference
quality, mode and window. Twelve Silesia sources at 4/16/64 KiB and random
16/64 KiB plus repetitive 64 KiB controls give 39 inputs. Three alternating
outer sweeps verify 234 processes; each retains five timing rounds at three
encodes per round. All input and complete Vort/reference wire identities agree.

Host: Intel Core i7-10700K, CPU2, one codec thread. Vort uses Zig 0.16.0
LLVM ReleaseFast, GNU x86-64, `skylake+pku+sgx`. Reference Brotli 1.2.0
is clean source `558fc647cdaf391228d614ca85f711e02e4e583b`, CMake Release,
`-O3 -march=skylake`, with the pinned closure from the interval-cost epoch.
A separate encoder-first loader probe confirms all three libraries; ordinary
sample metadata hashes requested paths without inspecting loaded objects.
Vort has a primary warmup and reference lifecycle is recorded by the harness.
Allocation/free is timed; file reading, metadata and output checks are outside.

| Real-input scope | Geometric paired time ratio | Faster row medians |
| --- | ---: | ---: |
| 4 KiB | 1.00074 | 4/12 |
| 16 KiB | 1.00003 | 8/12 |
| 64 KiB | 0.97767 | 11/12 |
| All 36 real inputs | 0.99276 | 23/36 |

Real-input geometric latency improves about 0.72%, including about 2.23%
at 64 KiB. The 4/16 KiB groups remain near neutral. Weaker real rows are
Webster 16 KiB 1.02830, SAO 4 KiB 1.00599 and SAO 64 KiB 1.00460. Random
16/64 KiB ratios are 0.99801/1.03085 and the repetitive control is 1.00421.
The [complete row CSV](command-model-lifetime-20261103.csv) retains independent
medians and paired statistics, whose quotient need not equal the paired ratio.
This increment does not claim a win on every input.

The independent reference epoch records 30.09 times Brotli encoding latency
geometrically at size 0.99556 times reference. Earlier gains/epochs are not
multiplied into that comparison. Nine final diagnostic rounds preserve all
558 non-time event records, including candidate configs, exact sizes, decisions
and existing work counts. The new model-build counters are separate actual
public tests; profile clocks are not ordinary throughput evidence.

Eleven longer alternating pairs at seven encodes per round verify another
132 processes with all complete wire identities unchanged:

| Input | Median paired ratio | Geometric paired ratio | Wins |
| --- | ---: | ---: | ---: |
| Mozilla 64 KiB | 0.98474 | 0.98425 | 11/11 |
| MR 64 KiB | 0.97970 | 0.98513 | 9/11 |
| Dickens 64 KiB | 0.96606 | 0.96093 | 11/11 |
| Dickens 4 KiB | 0.99457 | 0.99754 | 8/11 |
| NCI 64 KiB | 0.99403 | 0.99660 | 7/11 |
| Repetitive 64 KiB | 1.00444 | 1.00024 | 5/11 |

The three larger targets improve about 1.5–3.4% in the longer median
comparison. The repetitive control keeps about a 0.44% median regression
with a near-neutral geometric ratio. Broader row results and negative
controls remain visible; no whole-corpus universal benefit is asserted.

Seven further alternating pairs verify 56 processes on the weaker/control
rows. Median ratios are Webster 16 KiB 1.00026, SAO 4 KiB 0.99978, SAO 64 KiB
1.00143 and random 64 KiB 1.00121. The larger first-matrix regressions do not
persist in this longer comparison, but near-neutral negative points remain.
No candidate discovery, quality or parser branch is disabled to improve them.

Artifacts live under `zig-out/br-command-model-lifetime-20261103`, including
raw timing rounds, source/build/binary hashes, public model-work counters,
independent ownership tests, exact-limit checks and terminal gate logs.
Instrumentation clocks identify work only. Ordinary performance uses matched
public quality/mode/window, complete wire identities and serial CPU2 campaigns.

```sh
python3 zig-out/br-command-model-lifetime-20261103/matrix-final.py
python3 zig-out/br-command-model-lifetime-20261103/run-profile-final.py
python3 zig-out/br-command-model-lifetime-20261103/long-final.py
python3 zig-out/br-command-model-lifetime-20261103/long-weak-final.py
zig build -j2 test-br -Doptimize=ReleaseSafe --summary all -- --test-timeout 900s
zig build -j4 check check-wasm --summary all
zig build test-br-prepared-command-wasm --summary all
```

Execute CPU2 measurements sequentially. `build-final.py` records the complete
compiler commands, reused `record.o` hash and source identities; replay against
the saved source for this epoch. `archive.py` creates `SHA256SUMS` over source,
binaries, inputs, raw comparisons and terminal validation logs.

| Binding | SHA-256 |
| --- | --- |
| Baseline benchmark | `de5e23b4e6a2586bb618811e8e165f787dd01473b9be2d379ec2d631b09838c3` |
| Final benchmark | `a376f64d12ddde145336893459946b485736eeab21a28cea59a368b39b4a0018` |
| Final matrix | `08bb4cfffe8833a5868c12b463365d6636d1aa9a44ac475ea1622269e423b53b` |

The full Deflate/Zstd/Brotli industry-best objective stays active. Further
opportunities include reusing split-planner symbol projections, parser/model
quality and broader full-file/dictionary/streaming/resource/platform matrices;
none is implied by this command-model lifetime increment.

## q10/q11 command-state input override

The existing `command_state_max_input_kib` override can extend q10's
command-state candidate from the 8 KiB default through the 64 KiB optimal
ceiling. On the 64 KiB XML prefix, `--command-state-max-input-kib 64` reduces
the wire from 4,556 to 4,093 bytes (10.2%, size ratio 0.9832 versus the
4,163-byte reference) at 202.6 ms versus 80.4 ms (about 2.5x encode time).
Dickens and x-ray keep identical 64 KiB wires under the same override while
paying the higher time, so the 8 KiB default remains the latency policy and the
larger ceiling stays an explicit opt-in.

The same 64 KiB ceiling is now accepted for q11 instead of being capped at
q11's 32 KiB optimal-input limit. With `--command-state-max-input-kib 64`, the
64 KiB XML prefix also falls from 4,556 to 4,093 bytes (size ratio 1.0412
versus the 3,931-byte reference) at 207.7 ms versus 83.9 ms; the default q11
wire stays 4,556 bytes. Dickens and x-ray again keep identical wires, so both
qualities retain the 8 KiB default and expose 64 KiB only as an opt-in.

An adaptive auto-gate was explored but not adopted. Over 16 KiB prefixes the
unique 4-gram ratios are about 0.105/0.43/0.95 for XML/dickens/x-ray, and a
16 KiB q10 encode shows the extended command-state candidate winning only on
XML (1,644 -> 1,560 bytes); 8 KiB prefixes show no difference. Two prefix
encodes cost more than the direct opt-in for XML and add roughly 60% time for
non-XML inputs, so the explicit 64 KiB opt-in remains the interface.

## q11 preset versus the full HQ parser

The default q11 preset does not run the full HQ parser. It uses the bounded
command-state candidate (`hq_command_parser`, beam 2, at most eight
candidates), while `PlannedEncodeOptions.hq` selects the separate whole-block
DP parser (`hq_parser`). The 64 KiB XML prefix measures 4,556 bytes versus
3,931 reference bytes (1.1590) at 84.2 ms versus 64.1 ms, so the preset is
already close on time and 15.9% behind on size.

The full parser route is not a drop-in replacement. With the quality
schedule's search depth 512, nice length 258, beam 16 and two iterations it
did not finish the benchmark's repeated encode calls within a 12-minute CPU
window. A reduced depth-16, nice-64, beam-2, one-iteration configuration still
did not complete the ten HQ encode calls within 300 seconds after a warm build,
while the same 1 KiB input encodes successfully at 350 versus 337 reference
bytes. The whole-block DP and candidate enumeration therefore need an
algorithmic speed fix before the q11 preset can adopt them.

## q11 cross-content gap

The q11 preset gap is not XML-specific. On 64 KiB prefixes it measures:

| File | Vort bytes | libbrotli q11 | Size ratio | Vort ns |
| --- | ---: | ---: | ---: | ---: |
| dickens | 24,501 | 22,126 | 1.1073 | 172.4M |
| x-ray | 42,574 | 36,561 | 1.1645 | 182.7M |
| xml | 4,556 | 3,931 | 1.1590 | 84.8M |

Text and binary both trail by 10.7-16.5%, and the preset is also 1.26-2.59x
slower than the reference (dickens 2.59x, x-ray 1.26x, xml 1.32x). This is an
algorithmic deficit in the quality path, not a content-specific tuning gap.

## Why the full HQ parser is slow

`tools/br/hq_encode_probe.zig` times one explicit-HQ encode and prints the
parser counters. On the 8 KiB XML prefix with the resolved q11 defaults
(block 8 KiB, beam 16, two iterations, depth 64, nice 128) it produced 1,050
bytes in 76.2 seconds with 306,018 tree nodes, 2,883,817 match probes and
280,364,866 admitted price evaluations over six passes. The dominant cost is
structural: every beam node at every position evaluates the sampled length set
(2..64 plus code boundaries) for every match candidate and every rep choice.
With a 16-wide beam that multiplies to roughly 34,000 price evaluations per
input byte. The quality-only q11 path avoids this by using the bounded
command-state parser and a single optimal parse, which is why it runs in
milliseconds and why adopting the full parser needs the candidate/length work
reduced first, not merely a smaller beam.

The planned encode bench now exposes `--hq`, `--hq-beam-width`,
`--hq-iterations`, `--hq-block-len`, `--hq-search-depth` and `--hq-nice-len`
so this comparison stays reproducible. The preset default and its wires are
unchanged; the full parser remains explicit.

Two q11 search-policy experiments were rejected on the 64 KiB XML prefix.
Raising the block and optimal-input ceiling from 32 to 64 KiB (so the whole
prefix is one optimal block) produced 4,528 bytes, only 28 bytes (0.6%) below
4,556, while encode time rose from 84.6 to 176.9 ms. Raising the optimal
`max_chain` from 512 to 1,024 and `max_candidates` from 256 to 512 changed
neither the wire (4,556 bytes) nor the measured time (84.8 ms), so the existing
search is already saturated on this input. The remaining 15.9% gap is therefore
in entropy/context modeling and cost estimation, not match-search breadth;
larger blocks and deeper chains are not the next lever.

A second entropy-feedback pass was also neutral. Rebuilding the cost model from
the first modeled commands and parsing again left the 32 KiB wire at 2,617
bytes (59.5 ms) and the 64 KiB wire at 4,556 bytes (85.9 ms), matching the
single-pass result. The refined model is a fixed point on this input, so
repeating the current feedback loop does not recover the reference's q10-to-q11
gain. The next q11 work must change the cost model or entropy/context
decisions rather than add search or iteration depth.

## Gated repcode-aware command-state extension, 2026-11-04

The q10/q11 quality path now extends the repcode-aware command-state parser
from the 8 KiB policy to the whole meta-block (up to 64 KiB) when a cheap
content gate classifies the block as text-like. Binary and high-entropy blocks
keep the 8 KiB policy. The gate samples the first 16 KiB, hashes 4-grams into a
64 KiB bitset and accepts when `unique*5 <= grams`. A wider `unique*3` gate
also admitted reymont, samba, mozilla and mr, which paid the extended
command-state time without changing their wires; the tighter threshold keeps
XML (effective gate ratio 0.104) and nci (0.063) and excludes those four
(0.237-0.319). nci runs the extended candidate cheaply but does not select it,
so its wire and time stay unchanged.

| Prefix | Before | After | Size ratio vs libbrotli | Time |
| --- | ---: | ---: | ---: | ---: |
| XML 32 KiB | 2,617 | 2,414 | 1.1275 -> 1.0401 | 60.5 -> 150.6 ms |
| XML 64 KiB | 4,556 | 4,093 | 1.1590 -> 1.0412 | 84.8 -> 203.5 ms |
| dickens 64 KiB | 24,501 | 24,501 | 1.1073 | 172.4 -> 172.7 ms |
| x-ray 64 KiB | 42,574 | 42,574 | 1.1645 | 182.7 -> 183.4 ms |

The selected XML wire now uses 247 implicit and 498 short distances (was 54
and 234) and 358 regular distances, matching the reference's 358. This
identifies the earlier gap as repcode-unaware parsing, not entropy coding: the
separable optimal parser never modeled the four-distance cache, while the
command-state parser does. The remaining 4.1% XML gap is mostly the 44
static-dictionary copies libbrotli uses, which the optimal parser still does not
consider.

The gate rejects dickens and x-ray, so their wires and times are unchanged
within measurement noise; only the cheap 16 KiB scan is added. This is a
quality-first default; the command-state extension costs about 2.4-2.5x encode
time on the blocks where it runs.

Post-hoc static-dictionary mixing into the winning command-state stream was
rejected. On the 64 KiB XML prefix it produced 42 static copies covering 218
bytes, but the complete wire fell only 4,093 -> 4,089 bytes because the extra
command and distance symbols offset the literal savings. The reference's 44
copies save more because dictionary matches are priced inside the parse and
entropy model rather than inserted afterwards. Closing the remaining 4.1%
requires dictionary-aware parsing, not a second replacement pass.

## Dictionary and distance-tree gap on text, 2026-11-04

`run-br-quality-compare-probe` on the 64 KiB q11 prefix shows the remaining
text gap is dominated by two structural differences:

| File | Vort bytes | libbrotli bytes | Vort static copies | libbrotli static copies | Vort distance trees | libbrotli distance trees |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| webster | 21,421 | 19,258 | 0 | 1,482 (13,202 B) | 1 | 3 |
| samba | 20,862 | 18,482 | 0 | 1,771 (16,496 B) | 1 | 4 |
| mozilla | 14,185 | 12,364 | 0 | 186 (1,059 B) | 1 | 5 |

The reference covers 20-25% of the webster/samba input with static-dictionary
words while Vort covers none, and it splits distance coding into 3-5 context
trees while Vort emits one. Raising the post-hoc static probe limit to 64 KiB
changed none of these wires, confirming that the dictionary must be priced
inside the parser. These two items are the concrete next targets for
dictionary-rich text; XML's smaller 4.1% gap is dominated by the static
dictionary alone.

The distance-context family is also unreachable in the current structure.
`useCountedAdaptiveDistanceContexts` requires an adaptive distance split with
two to eight types, but the split planner produces one type for webster, samba
and mozilla, so the candidate is never built. An extra arbitration attempt that
constructed the no-split counted options produced identical wires and times,
confirming the gate rather than the cost model is the blocker. A synthetic
two-type plan (half of the commands per type) was rejected with
`error.InvalidBlockPlan`, so the counted path also validates block-boundary
invariants that a fabricated split does not satisfy. Distance context trees
must be decoupled from block splitting (one block type with four contexts)
before Vort can match the reference's 3-5 trees.

## Optimal-stream static dictionary mixing, 2026-11-04

The q10/q11 optimal candidate now also mixes bounded static-dictionary words
into its literal runs and arbitrates the resulting complete wire. On 64 KiB
prefixes:

| File | Before | After | Size ratio | Static copies |
| --- | ---: | ---: | ---: | ---: |
| webster | 21,421 | 21,322 | 1.1123 -> 1.1072 | 397 (2,160 B) |
| samba | 20,862 | 20,757 | 1.1288 -> 1.1231 | 378 (2,105 B) |
| mozilla | 14,185 | 14,185 | 1.1473 | 0 |
| xml | 4,093 | 4,093 | 1.0412 | 0 (command-state wire wins) |

This is a functional step: Vort now exercises the static dictionary on large
text (0 -> 397/378 copies), but the wire gain is only 0.46-0.50% because the
post-hoc mixer replaces literals without re-pricing the parse; the reference's
1,482-1,771 copies (13-16 KB) come from dictionary-aware parsing. Raising the
probe budget from 4,096 to 32,768 changed nothing, so the matcher's transform
coverage, not the scan budget, limits the copy count. Encode time rises about
16% on webster/samba (168 -> 196/194 ms). The full Brotli suite still passes
1539/1540 with one platform skip.
