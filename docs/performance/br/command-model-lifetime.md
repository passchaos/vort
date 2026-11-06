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

Switching the mixer to the complete-transform index raised webster from 397 to
467 copies (2,487 bytes), but the wires moved only 21,322 -> 21,305 for webster
and 20,757 -> 20,725 for samba (17 and 32 bytes). The complete index is
also expensive to build for tracked allocators, so the change was rejected.
The limit is the mixer's literal-run scope, not transform coverage: it can only
replace bytes between existing LZ copies, while the reference chooses
dictionary words inside the parse. Dictionary-aware parsing is the required
next step.

## Modeled-stream static dictionary mixing, 2026-11-04

The optimal candidate now also mixes the static dictionary into the
entropy-refined command stream, not only the seed plan. On 64 KiB q11 prefixes:

| File | Seed only | Seed + modeled | Size ratio |
| --- | ---: | ---: | ---: |
| webster | 21,322 | 21,142 | 1.1123 -> 1.0978 |
| samba | 20,757 | 20,586 | 1.1288 -> 1.1138 |
| dickens | 24,501 | 24,238 | 1.1073 -> 1.0955 |
| reymont | 17,150 | 17,140 | 1.0262 -> 1.0256 |
| xml | 4,093 | 4,093 | 1.0412 (command-state wire wins) |
| mozilla | 14,185 | 14,185 | 1.1473 (binary, no matches) |

Text gains 1.07-1.32% over the seed-only mixer (1.30-1.32% over the pre-static
baseline). Encode time rises about 35% on dickens (172 -> 239 ms) and about 15%
on webster (196 -> 226 ms) because the mixer runs on both command streams. The
remaining gap is still dictionary-aware parsing: the mixer can only replace
bytes inside literal runs, while the reference chooses dictionary words inside
the parse and covers 13-16 KB of webster/samba.

## Dictionary-aware optimal parsing, 2026-11-04

The optimal parser now accepts an external static-dictionary candidate
provider. At every position it may emit a dictionary copy priced at a flat
proxy cost; `command_plan.buildAlloc` revalidates the transform and emits a
`.static` command, and `entropy_feedback` includes static commands in the
literal, copy-code and command-symbol histograms. `Token.Match` carries an
explicit `is_dictionary` flag because dictionary address zero is a valid word.

On 64 KiB q11 prefixes, versus the committed pre-parse state:

| File | Before | After | Size ratio |
| --- | ---: | ---: | ---: |
| webster | 21,142 | 19,603 | 1.0978 -> 1.0179 |
| samba | 20,586 | 18,741 | 1.1138 -> 1.0140 |
| dickens | 24,238 | 22,416 | 1.0955 -> 1.0131 |
| reymont | 17,140 | 17,132 | 1.0256 -> 1.0251 |
| xml | 4,093 | 4,082 | 1.0412 -> 1.0384 |
| mozilla | 14,185 | 14,185 | 1.1473 |

Dictionary-rich English text gains 7.2-9.0% over the committed state and
8.5-10.2% over the pre-static baseline; XML improves 11 bytes, reymont is
neutral, and binary mozilla is unchanged. The proxy cost was tuned on the same
matrix: 12 bits overused dictionary matches (webster 20,375, reymont 17,192,
xml 4,096), 16 bits gave 19,817/17,158/4,093, and 20-24 bits converged near
19,60x/18,74x/22,4xx with 22 selected as the best aggregate. The compact
canonical index is used; the complete-transform index may add more but is
expensive for tracked allocators. Encode time rises roughly 30-50%. The full
Brotli suite passes 1539/1540 with one platform skip.

After this increment, the webster wire structure is close to the reference:
1,449 static copies covering 13,516 bytes versus 1,482 covering 13,202, and
45,555 LZ copy bytes versus 45,762. The remaining 345-byte gap is distance
coding: Vort emits 28 implicit + 186 short + 74 direct + 5,826 regular
distances, while the reference emits 155 implicit + 417 short + 0 direct +
5,510 regular. A corrected two-type adaptive-distance split (halving the
explicit-distance count, which passes the plan validator) did not change the
webster wire, so an arbitrary block split is not the reference's four-context
distance map. The candidate is eligible and runs on mozilla (about 3,600
explicit distances) but also loses, leaving mozilla at 14,185 bytes versus the
reference's 12,364. There the reference uses nine command block types and four
distance block types while Vort keeps one, so the next lever for binary data is
the block-split planner's cost model, not distance contexts. The next lever is repcode-aware dictionary parsing: the
command-state parser tracks the four-distance cache but does not yet accept
dictionary candidates, while the dictionary-aware optimal parser does not
track repcodes.

Adding dictionary transitions to the command-state parser was also rejected.
With a wider `unique*2` content gate that admits webster, the command-state
candidate ran but the wire stayed at 19,603 bytes while encode time rose from
299 to 439 ms (47%). The beam-2 search is too weak to beat the dictionary-aware
optimal parse even with repcode tracking; closing the remaining 1.8% requires
repcode state inside the optimal parser itself, not a second weaker parser.

Lowering the adaptive command split's `min_symbols` from 2,048 to 512 did not
change mozilla (14,185) or webster (19,603) wires, so the splitter's cost
estimate, not its block-size floor, rejects the splits. A fabricated two-type
command plan caused a segfault and was abandoned; the split plans must come
from the validated splitter. The binary gap therefore needs a better
splitter cost model rather than a different budget or a forced plan.

## Large-input quality boundary, 2026-11-04

The 64 KiB gains do not carry to larger inputs because the quality path's
optimal parser is capped at 64 KiB (q10) and 32 KiB (q11); larger inputs fall
back to the lazy parser plus post-hoc mixing. On the 1 MiB webster prefix,
q11 measures 288,310 bytes versus the reference's 239,314 (1.2047) at 385 ms,
while the same file is 1.0179 at 64 KiB. Raising q11's optimal input ceiling
to 1 MiB made even 64 KiB inputs fail with `error.InvalidBlockPlan`; the
schedule validator caps `max_input_len` at 64 KiB. Raising it to the allowed
64 KiB lets q11 run its own deeper optimal parse on 64 KiB inputs, but the
webster wire moves only 19,603 -> 19,583 (20 bytes) while encode time rises
about 74% (300 -> 521 ms). Larger inputs therefore need multi-block quality
planning with cross-block history, not a bigger single-block cap. This 20%
large-input gap is now the largest remaining Brotli quality target.

Post-hoc mixing is also insufficient at this size. With the quality dictionary
gate opened to 16 MiB, the lazy-stream mixer finds only 334 dictionary words
on the 1 MiB webster prefix even at a 65,535-probe budget (3,072 probes found
the same 334), and the mixed wire loses to the baseline. A 64 KiB chunked
encode produces 292,787 bytes with zero static copies, worse than the
288,310-byte one-shot. The reference covers 5,765 words / 57,495 bytes, so
large-input quality needs dictionary-aware parsing inside the multi-block
planner rather than more probes or post-hoc replacement.

That incremental-planner integration was then measured and rejected. Adding
dictionary-aware optimal parsing to `considerPlannedMetaBlock` (32 KiB blocks)
raised the selected stream's static copies from 0 to 3,972 (36,381 bytes), but
the 1 MiB webster stream is 292,366 bytes across 33 meta-blocks, still 22%
behind the reference and slightly worse than the 288,310-byte one-shot path.
Per-block headers and the near-absent repcode use (3 short distances versus
the reference's 4,054) dominate. Large-input quality therefore needs a
single-block large-window optimal parse with repcode state, not a chunked
planner.

## Large-input optimal ceiling, 2026-11-04

Raising q11's `max_input_len` to 1 MiB (and the schedule validator cap) lets
the dictionary-aware optimal parser cover the whole block. On 1 MiB prefixes:

| File | Before | After | Size ratio | Vort time | Reference time |
| --- | ---: | ---: | ---: | ---: | ---: |
| webster | 288,310 | 263,711 | 1.2047 -> 1.1019 | 2.53 s | 1.21 s |
| samba | - | 306,387 | 1.0845 | - | - |
| dickens | - | 342,678 | 1.1226 | - | - |

Static coverage rises to 15,292 copies / 142,703 bytes on webster (the
reference uses 5,765 / 57,495). q11 skips its second parse for inputs up to
64 KiB, where the inherited q10 winner already covers them, so the 64 KiB
wires and times stay unchanged. The remaining 1 MiB gap is distance coding
(393 implicit + 2,284 short versus 1,432 + 4,054) and block/context types
(1 versus 2 command / 7 distance / 11 context trees). The large-input
quality ratio is now 1.08-1.12 rather than 1.20.

Raising the adaptive split ceilings to 128K symbols for q10/q11 was also
rejected. On 1 MiB webster it produced eight distance block/context trees
(was one), but the wire moved only 263,711 -> 263,663 (48 bytes) while encode
time rose from about 3.5 s to 53 s. Command block types stayed at one. The
remaining large-input gap is repcode-aware parsing, not split availability.

A seed-recent-distance discount in the modeled DP was also rejected. A 4-bit
Bloom-mask hint over the seed plan's four-distance cache changed the 1 MiB
webster wire from 263,711 to 268,414 bytes (worse) and raised encode time from
3.5 s to 52 s, while static copies rose to 25,819. The approximation interacts
poorly with the prefix bound and the dictionary candidate; repcode-aware
parsing needs real cache state, not a seed hint.

## Token growth side effects, 2026-11-04

Adding optional static-dictionary fields to `lz77.Token.Match` grew the shared
token from 6 to 16 bytes and the Zstd rep-beam state from 16 to 28 bytes. Two
Zstd-side pins had to be updated: `single_beam.zig`'s comptime size assert and
the allocation oracle's geometry predicate and 16 KiB pinned total (897,583 ->
1,548,869 bytes). The full Zstd ReleaseFast suite passes 1276/1276. A separate
pre-existing wasm32 compile failure (`bitPosition()` u64 to `usize` in the
resumable compressed-header path) was fixed with explicit casts, and
`zig build check` now passes 212/212.

The token was then repacked: dictionary output length (6 bits), copy length
minus four (5 bits) and RFC address (18 bits) share one u32 field on
`Token.Match`, with `initDictionary`/`dictionaryOutputLen`/`dictionaryCopyLen`/
`dictionaryAddress` helpers. `Token` shrinks 16 -> 12 bytes and the Zstd beam
state 28 -> 20 bytes, with unchanged Brotli wires (webster 64 KiB stays 19,603
bytes) and Zstd 1276/1276. The allocation-oracle pinned total is unchanged
because power-of-two growth lands in the same request buckets. A separate
`.dictionary` union variant would reach 9-10 bytes, but it requires updating
every generic token switch (LZMA consumes the same generic encoder), so the
u32 field is the smaller-risk structure.

## Binary quality gap is parse cost, 2026-11-04

A 12-file 64 KiB q11 screen leaves x-ray (1.1645), mozilla (1.1473), mr
(1.1201), ooffice (1.0639), nci (1.0541) and sao (1.0518) as the weakest rows;
text rows are 1.0140-1.0394. Wire inspection shows the binary gap is not split
capacity:

| File | Vort commands | Vort copy bytes | Reference commands | Reference copy bytes |
| --- | ---: | ---: | ---: | ---: |
| x-ray | 13,237 | 45,122 | 6,306 | 23,336 |
| mozilla | 4,277 | 59,512 | 4,188 | 56,987 |
| mr | 5,850 | 61,066 | 4,658 | 54,234 |

Vort emits roughly twice as many commands on x-ray and matches 22 KB more,
while the reference leaves much more as literals compressed by 35 literal
trees. Raising the adaptive literal splitter from 8 to 16 types with a 1,024
symbol floor, and the joint literal context splitter from 8 to 16 block types
with four iterations, changed no binary wire at all while raising encode time
2-3x. Both were reverted. The limiter is the optimal parser's cost model,
which prices literals with a flat histogram and therefore over-selects short
matches; the next functional step is context-aware literal pricing inside the
parse.

## Context-aware literal pricing, 2026-11-04

The modeled optimal parser now prices literals by the previous byte's class
(letter / digit / whitespace / other, four classes) instead of one flat
histogram. `entropy_feedback` builds four class histograms from the seed
commands, clamps each price to at most the flat price plus two bits so sparse
classes cannot overprice, and `lz77.OptimalCostModel.literal_context` is
optional so Deflate and fixed parses are unchanged.

On 64 KiB q11 prefixes, versus the flat model:

| File | Flat | Context | Size ratio |
| --- | ---: | ---: | ---: |
| webster | 19,603 | 19,548 | 1.0179 -> 1.0151 |
| dickens | 22,416 | 22,381 | 1.0131 -> 1.0115 |
| osdb | 25,473 | 25,433 | 1.0394 -> 1.0378 |
| samba | 18,741 | 18,738 | 1.0140 -> 1.0139 |
| reymont | 17,132 | 17,133 | 1.0251 -> 1.0252 |
| xml / nci / sao | unchanged | unchanged | - |
| x-ray / mozilla / mr / ooffice | unchanged | unchanged | - |

Three iterations on webster and mozilla measure the same encode time as the
flat model (898.3 vs 898.4 ms and 883.1 vs 884.0 ms), so the gain is free. The
binary rows are unchanged because their literals are overwhelmingly class 3,
where the class price converges to the flat price. Closing their 6-16% gap
needs finer contexts (for example previous-byte identity or UTF-8 context
modes) inside the parse, not just byte classes.

## Why binary rows ignore optimal-parser changes, 2026-11-04

Candidate instrumentation on x-ray shows the optimal candidate is 42,695 bytes
for both the seed and the entropy-feedback parse, while the selected wire is
42,574 bytes from the lazy command stream plus entropy block splitting. Every
optimal-parser improvement therefore leaves the binary rows unchanged: the
optimal candidate never wins there.

Two targeted sweeps confirm the winning path is the limiter:

- A 16-class (previous-byte high nibble) literal model moved ooffice 30,883 ->
  30,858 but regressed webster 19,548 -> 19,564 and dickens 22,381 -> 22,433,
  so the four-class model remains.
- Raising the q11 lazy `min_gain` from 1 to 3 moved mozilla 14,185 -> 14,132
  but ooffice 30,883 -> 30,886; x-ray and mr were unchanged.

Both were reverted. Improving binary rows requires a better lazy parse or
literal-context-aware wire selection, not further optimal-parser tuning.

A second content-gated lazy candidate (gain floor +2, binary blocks only) was
also rejected. On mozilla its own wire is 14,256-14,261 bytes and beats the
primary lazy wire (14,302-14,306), but a later stage fed by the primary
command stream still reaches 14,185 and wins. The whole-pipeline gain of the
higher gain floor (14,132) comes from later stages using the shifted stream,
so capturing it requires routing the alternative stream through the distance
parameter search and static mixing as well. At 53 bytes (0.37%) that is not
worth doubling the binary quality pipeline; the larger lever remains
literal-context-aware wire selection.

## Recent-distance repacking, 2026-11-04

`command_plan.repackRecentDistancesAlloc` walks an LZ command stream while
simulating the four-entry recent-distance cache. For each copy with a literal
insert before it, it resolves symbols 0-15 against the cache and rewrites the
copy onto the first cached distance that still reproduces every byte. The
rewritten stream is re-simulated byte-for-byte against the input before use, so
an incorrect rewrite is rejected rather than emitted.

On 64 KiB q11 prefixes:

| File | Before | After | Size ratio |
| --- | ---: | ---: | ---: |
| ooffice | 30,883 | 30,639 | 1.0639 -> 1.0555 |
| x-ray | 42,574 | 42,455 | 1.1645 -> 1.1612 |
| mozilla | 14,185 | 14,071 | 1.1473 -> 1.1381 |
| mr / sao / nci | unchanged | unchanged | - |
| webster / dickens / xml / osdb / reymont / samba | unchanged | unchanged | - |

The repack adds about 10-15% encode time on the blocks where it changes the
wire. It also fixed a real trailing-insert bug found by the byte-level
validation: the first version dropped a terminal literal run and produced a
truncated stream, which the validation now prevents.

The repack already applies at 1 MiB: webster falls 263,711 -> 262,671
(1.1019 -> 1.0976), samba 306,387 -> 306,022 (1.0845 -> 1.0832) and dickens
342,678 -> 341,942 (1.1226 -> 1.1202). Allowing a cached distance to replace a
copy that is up to two bytes longer (turning the surplus into literals) was
also tested and rejected: it never beat the exact-coverage candidate on the
64 KiB binary rows or on the 1 MiB text rows, and it regressed ooffice
30,639 -> 30,883 when used alone. The exact-only repack remains.

## q10 versus q11 at 64 KiB, 2026-11-04

A full 64 KiB q10 screen against libbrotli 1.0.9 shows Vort's q10 is already
competitive on text:

| File | q10 ratio | q11 ratio | File | q10 ratio | q11 ratio |
| --- | ---: | ---: | --- | ---: | ---: |
| dickens | 0.9862 | 1.0115 | samba | 0.9878 | 1.0139 |
| XML | 0.9803 | 1.0384 | webster | 0.9991 | 1.0151 |
| nci | 1.0033 | 1.0541 | sao | 1.0049 | 1.0518 |
| reymont | 1.0052 | 1.0252 | osdb | 1.0298 | 1.0378 |
| ooffice | 1.0334 | 1.0555 | mozilla | 1.0777 | 1.1381 |
| mr | 1.1329 | 1.1201 | x-ray | 1.1735 | 1.1612 |

Vort's q11 produces the same wire as q10 for inputs up to 64 KiB: the q11
candidate inherits the complete q10 winner and its own deeper parse loses
(webster 19,583 versus 19,548 at +74% time). libbrotli's q11 instead gains
2.1-5.3% over its own q10, which is exactly the remaining text gap. So the
q11 target is a genuinely stronger parse or cost model, not more search: deeper
chains, larger candidate sets, a bigger block, and a second feedback pass were
all neutral. Binary q11 also exceeds its q10 ratio (mozilla 1.1381 versus
1.0777) because the reference's q11 improves more there.

## q1 block and anchor policy, 2026-11-04

q1 previously encoded 32 KiB blocks and used a four-byte anchor for its
64 KiB-table fragment parser, so a 64 KiB input could not match across the
block boundary. Two changes close most of that gap:

- q1 now uses 64 KiB stream blocks (the same as q2-q5/q8-q10);
- the fragment anchor is chosen by content: six bytes for text-like blocks
  (printable ASCII at least 90% of a 16 KiB sample), four bytes otherwise.

64 KiB q1 versus libbrotli 1.0.9, before -> after:

| File | Before | After | Size ratio |
| --- | ---: | ---: | ---: |
| XML | 9,075 | 7,129 | 1.2613 -> 0.9908 |
| osdb | 36,460 | 31,460 | 1.2671 -> 1.0933 |
| mozilla | 20,110 | 18,192 | 1.1398 -> 1.0311 |
| webster | 27,565 | 26,381 | 1.0568 -> 1.0114 |
| dickens | 30,566 | 29,431 | 1.0510 -> 1.0120 |
| ooffice | 38,051 | 37,407 | 1.0170 -> 0.9998 |
| x-ray | 64,269 | 61,697 | 1.2003 -> 1.1522 |
| sao | 53,596 | 52,925 | 0.9258 -> 0.9142 |
| mr | 18,340 | 18,441 | 1.0037 -> 1.0092 |

XML, ooffice, nci and sao now match or beat the reference at q1. The `mr`
regression is 101 bytes (0.55%); every other row improves. The block-size
contract test was updated from 32 KiB to 64 KiB for q1.

q0 keeps its 16 KiB blocks. Widening q0 to 64 KiB regressed text badly
(dickens 31,255 -> 38,915, webster 28,414 -> 34,047, samba 26,288 -> 32,092)
because its one-pass entropy writer needs small blocks for adaptivity, even
though binary rows improved. Instead, q0's anchor is now content-gated: five
bytes for text-like fragments and four for binary ones. Binary rows improve
with unchanged text output:

| File | Before | After | Size ratio |
| --- | ---: | ---: | ---: |
| ooffice | 41,916 | 34,463 | 1.1083 -> 0.9112 |
| x-ray | 65,495 | 56,412 | 1.1955 -> 1.0297 |
| osdb | 42,938 | 37,699 | 1.4103 -> 1.2382 |
| sao | 58,665 | 52,308 | 1.0217 -> 0.9110 |
| mozilla | 21,280 | 18,029 | 1.1389 -> 0.9649 |
| mr | 18,905 | 17,470 | 0.9269 -> 0.8566 |

Text rows (webster, dickens, XML, nci) are byte-identical. The frozen legacy
q0 wires are text, so they are unchanged; the fragment anchor tests now assert
four bytes for binary q0/q1 and five/six bytes for text q0/q1.

Widening q6/q7 streaming blocks from 32 to 64 KiB was rejected: the chunked
probe measures XML 5,030 -> 5,012 and ooffice 31,193 -> 31,138, but dickens
regresses 25,536 -> 26,142. One-shot q6/q7 output is unchanged because those
qualities encode a single meta-block regardless of the streaming block size.
The 32 KiB streaming policy remains.

Intermediate-quality screening found no structural outlier: at 64 KiB, q5/q6/q7
XML are 1.0737/1.0404/1.0350, q8 is 1.0064 and q10 is 0.9803, while q8 already
beats the reference on dickens (0.9031) and x-ray (0.8949).

Applying the recent-distance repack to the optimal and entropy-refined command
streams, not only the lazy one, changed no text wire (webster 19,548, dickens
22,381, XML 4,082, samba 18,738, reymont 17,133, osdb 25,433) while adding
about 10% encode time. The optimal parse's distances rarely coincide with an
exact cached distance, so post-hoc rewriting cannot close the text repcode
gap; the parser itself must prefer cached distances. Reverted.

Raising the command-state parser's beam from 2 to 4 or 8 (with up to 16
candidates) also leaves webster at 19,548 bytes, at 468 ms and 561 ms
respectively. Even a wider beam cannot beat the dictionary-aware optimal parse
on this input, so the command-state parser is not the route to a stronger q11
text parse. Beam and candidate caps were restored.

q0 streaming blocks were also tried at 32 KiB: XML 10,033 -> 9,676, nci
8,846 -> 8,613, x-ray 56,412 -> 52,955 and osdb 37,699 -> 32,405 improve, but
dickens regresses 31,255 -> 36,737 and webster 28,414 -> 32,988 because the
one-pass entropy writer loses adaptivity on prose. A per-content block-size
gate would need per-block content classification in the chunked encoder; the
16 KiB policy remains for now.

## q5 gains a bounded optimal parse, 2026-11-04

q5 was the only mid preset without an optimal parser, which left it unusually
weak: its 64 KiB XML ratio (1.0737) was worse than q4's (0.9605) relative to
the reference. q5 now enables a bounded optimal pass (chain 48, nice 112, 12
candidates, 64 KiB input ceiling). 64 KiB results versus libbrotli 1.0.9:

| File | Before | After | Size ratio |
| --- | ---: | ---: | ---: |
| XML | 5,247 | 5,105 | 1.0737 -> 1.0446 |
| dickens | 26,306 | 25,380 | 1.0337 -> 0.9973 |
| webster | 22,930 | 22,232 | 1.0296 -> 0.9983 |
| nci | 4,794 | 4,564 | 1.1201 -> 1.0664 |
| samba | 22,167 | 21,544 | 1.0318 -> 1.0028 |
| reymont | 19,054 | 18,284 | 1.0088 -> 0.9680 |
| osdb | 26,786 | 26,750 | 1.0225 -> 1.0211 |
| mr | 16,105 | 15,972 | 1.0372 -> 1.0287 |
| ooffice / x-ray / mozilla / sao | unchanged | unchanged | - |

q5 now beats the reference on dickens, webster, reymont, sao and x-ray. Encode
time rises about 4.6x on XML (2.2 -> 10.2 ms) and about 1.5x on dickens, which
is the expected cost of the added parse.

q6 and q7 had the same latent limit: their optimal parser stopped at 32 KiB, so
a 64 KiB one-shot input never used it. Raising both to 64 KiB gives large
gains:

| File | q6 before | q6 after | q7 before | q7 after |
| --- | ---: | ---: | ---: | ---: |
| dickens | 26,144 | 25,260 | 25,765 | 22,816 |
| webster | 22,810 | 22,157 | 22,576 | 19,906 |
| XML | 4,996 | 4,996 | 4,856 | 4,795 |
| nci | - | 4,545 | - | 4,434 |
| ooffice | 31,057 | 31,057 | 30,651 | 30,651 |
| x-ray | 43,290 | 43,290 | 42,488 | 42,488 |

q6 now measures 0.9986 on dickens and 0.9928 on ooffice; q7 measures 0.9042
(dickens), 0.9007 (webster) and 0.8949 (x-ray). The schedule monotonicity test
also required q6/q7 to reach the same 64 KiB ceiling as q5.

q3 and q4 then received the same treatment with smaller budgets (24/40 chain,
8/10 candidates, all 64 KiB). 64 KiB results:

| File | q3 | q4 |
| --- | ---: | ---: |
| XML | 0.7986 | 0.8998 |
| dickens | 0.9582 | 0.9569 |
| webster | 0.9423 | 0.9545 |
| nci | 0.9410 | 0.9461 |
| samba | 0.9485 | 0.9571 |
| reymont | 0.9125 | 0.9139 |
| sao | 0.9304 | 0.9122 |
| ooffice | 0.9374 | 0.9361 |
| x-ray | 0.8616 | 0.9040 |
| mr | 0.9411 | 0.9734 |
| mozilla | 0.9353 | 0.9391 |

Both beat libbrotli 1.0.9 on every measured row. q3 XML falls from 5,772 to
5,210 bytes and q4 XML from 5,454 to 5,109.

q2 was also measured with an optimal parse (XML 0.6843, dickens 0.9737) but
was reverted: the incremental q2 contract requires a warmed second encode to
allocate nothing, and the optimal parser allocates per block. Keeping q2
lazy-only preserves that streaming guarantee; q3-q7 carry the ratio gains.

q8 and q9 previously ran the optimal parser without entropy feedback, leaving
them about 1.6% above q10 in absolute bytes. Enabling feedback on both closes
most of that:

| File | q8 before | q8 after | q9 before | q9 after |
| --- | ---: | ---: | ---: | ---: |
| XML | 4,711 | 4,539 | 4,662 | 4,505 |
| dickens | 22,766 | 22,412 | 22,742 | 22,387 |
| webster | 19,858 | 19,574 | 19,838 | 19,556 |
| nci | 4,388 | 4,238 | 4,347 | 4,203 |
| x-ray | 42,488 | 42,488 | 42,488 | 42,455 |
| ooffice | 30,647 | 30,647 | 30,648 | 30,648 |

q8/q9 XML now measure 0.9697/0.9705 and dickens 0.8890/0.8881. Encode time
rises to 65-253 ms on the affected text rows. Because q8/q9 now enable entropy
feedback, `applyCommandStateLimit` gates the explicit command-state override on
the quality tag (q10/q11) rather than on feedback alone, preserving the
existing rejection contract for q8/q9.

## Why q10/q11 binary rows stay flat, 2026-11-05

x-ray is the clearest case: q9, q10 and q11 all produce 42,455 bytes while
libbrotli drops from 47,088 (q9) to 36,177 (q10). Two experiments show the
optimal parser is not the winning candidate there:

- Raising q10's optimal search from 256/128 to 1,024/512 chains/candidates
  changes x-ray and mozilla not at all and gains only 13 bytes on XML and 34 on
  dickens, at roughly 1.5-2x time.
- Adding a per-match surcharge of 1, 3 or 6 bits leaves x-ray, mozilla and XML
  byte-identical and only regresses dickens (22,381 -> 22,376 -> 22,484 ->
  22,747).

So the q10 binary winner is the lazy command stream plus entropy splitting, and
the remaining gap is structural: the reference q10 x-ray emits 2,918 copies
covering 12,029 bytes and compresses 53,503 literal bytes with 39 literal
trees, while Vort emits 13,236 copies covering 45,122 bytes with 10 trees. Its
parser deliberately prefers context-modelled literals, which needs
context-aware literal pricing plus a much finer literal split, not deeper match
search. Both experiments were reverted.

Further bounded probes on the same plateau, all reverted:

- Pricing literals from the complete input instead of only the seed plan's
  literal positions regressed XML (4,082 -> 4,247), dickens (22,381 -> 22,458)
  and webster (19,548 -> 19,621) with no binary change.
- A 64-context (previous byte top six bits) literal price table left x-ray,
  mozilla, XML, nci and ooffice unchanged and regressed dickens/webster.
- Requiring lazy matches to save at least 4/8/16 bits moved x-ray by at most
  four bytes, helped mozilla at 4 bits (14,071 -> 14,027) and hurt it at 8/16,
  and left XML/dickens unchanged.

The q10/q11 binary gap therefore needs an encoder that deliberately parses
toward context-modelled literals and builds many literal trees, not parameter
tuning of the current matcher or price tables.

## Second modeled pass for large inputs, 2026-11-05

Large one-shot inputs now run the entropy-feedback parse a second time, with
the model rebuilt from the first modeled plan, plus a repcode-bonus model built
from the same plan. The extra candidates are kept only when the complete wire
is smaller. On 1 MiB prefixes:

| File | Before | After | Size ratio |
| --- | ---: | ---: | ---: |
| webster | 262,671 | 262,209 | 1.0976 -> 1.0956 |
| samba | 306,022 | 305,801 | 1.0832 -> 1.0824 |
| dickens | 341,942 | 341,020 | 1.1202 -> 1.1172 |

The gain is 0.18-0.27%, paid for by a third parse on large inputs. The 1 MiB
gap remains dominated by distance coding and block/context typing.

The same two candidates now also run for inputs of exactly 64 KiB. The
model2 pass supplies most of the text gains and the repcode-bonus pass supplies
x-ray:

| File | Before | After |
| --- | ---: | ---: |
| x-ray | 39,317 | 39,279 |
| dickens | 22,373 | 22,363 |
| webster | 19,548 | 19,540 |
| osdb | 25,433 | 25,428 |
| samba | 18,734 | 18,725 |

nci, sao, mozilla, ooffice, mr and XML keep their previous wires. Running only
the bonus pass leaves dickens/webster/osdb/samba unchanged; running only model2
leaves x-ray at 39,316. Both passes therefore stay. Encode time rises about
18-23% on the eleven 64 KiB q11 rows, which is the price of two additional
optimal parses at the 64 KiB boundary.

Raising the joint literal/context splitter to 16 block types and four
iterations (the call site previously used its 8-type, three-iteration default)
also changes no wire: x-ray 42,455, mozilla 14,071, ooffice 30,644, XML 4,082
and dickens 22,381 are identical, while encode time rises 20-40%. The splitter
already finds no further profitable partition on these inputs, so the literal
tree count follows from how many literals the parse leaves, not from the
splitter budget. Reverted.

## Literal split ceiling, 2026-11-05

The adaptive literal splitter refused blocks with more than 32 KiB of literal
bytes, so a literal-heavy binary block could not be partitioned even when its
candidate wire was built from ~20 KiB of literals. Raising the ceiling to
128 KiB (and the splitter's `max_symbols` and scratch budget to match) is a
large win exactly where the reference leads:

| File | Before | After | Size ratio |
| --- | ---: | ---: | ---: |
| x-ray q10 | 42,455 | 39,317 | 1.1735 -> 1.0868 |
| x-ray q11 | 42,455 | 39,317 | 1.1612 -> 1.0754 |
| mozilla / ooffice / XML / dickens / webster / sao / mr / osdb / nci | unchanged | unchanged | - |

A literal-only probe explains why: x-ray's all-literal wire is 43,245 bytes,
only 1.6% above the matched wire, so its size is dominated by literal coding;
the extra split headroom recovers 3,138 bytes there. mozilla's literal-only
wire is 26,366 versus a 14,302 matched wire, so matches remain essential and
the change is neutral for it.

Raising the same ceiling to 1 MiB extends the win to large inputs:

| Input | 128 KiB ceiling | 1 MiB ceiling | Size ratio |
| --- | ---: | ---: | ---: |
| x-ray 1 MiB | 622,024 | 590,922 | 1.0798 -> 1.0255 |
| samba 1 MiB | 305,801 | 301,653 | 1.0824 -> 1.0675 |
| webster 1 MiB | 262,209 | 262,209 | unchanged |
| dickens 1 MiB | 341,020 | 341,020 | unchanged |

A 32-type splitter budget for literal volumes above 128 KiB was also tested and
rejected: x-ray 1 MiB returns to 622,024, so the eight-type budget remains.


## Full 1 MiB q11 matrix, 2026-11-05

After the 1 MiB literal ceiling and the second modeled pass, the 1 MiB q11
matrix versus libbrotli 1.0.9 is:

| File | Vort bytes | Reference bytes | Size ratio |
| --- | ---: | ---: | ---: |
| x-ray | 590,922 | 576,209 | 1.0255 |
| mozilla | 651,928 | 635,440 | 1.0260 |
| samba | 301,653 | 282,533 | 1.0675 |
| sao | 721,932 | 674,615 | 1.0701 |
| mr | 291,417 | 271,989 | 1.0714 |
| osdb | 340,934 | 312,387 | 1.0914 |
| webster | 262,153 | 239,314 | 1.0954 |
| ooffice | 542,522 | 488,479 | 1.1106 |
| dickens | 340,861 | 305,265 | 1.1166 |
| reymont | 260,088 | 228,207 | 1.1396 |
| nci | 84,382 | 65,459 | 1.2891 |

nci is the worst row: Vort emits 3,885 implicit + 5,527 short distances against
the reference's 9,882 + 4,095, and 17,191 regular distances against 9,026. The
1 MiB gap is therefore dominated by repcode share and distance/context block
typing, the same structural items as the 64 KiB binary rows. The sao, nci,
osdb, ooffice and mozilla values above include the later distance-parameter
split re-encoding and repcode-frequency bonus epochs; mr, webster, ooffice and
dickens also include the large-input adaptive block split epoch. The remaining
rows stay at their earlier measured wires.

A repcode-first greedy parser was implemented and rejected. It probes the four
cached distances before the hash chain, keeps the longest match and breaks ties
toward the most recent slot. On 1 MiB nci it emits 111,108 bytes with 47,142
matches against the current 84,867 bytes with 25,509 matches: greedy matching
without lazy deferral loses far more than the repcode share gains. Iterating
the recent-distance repack up to three passes also changes nothing (nci stays
84,867), so the remaining regular distances genuinely are not cache-resident.
Repcode preference must be added inside the lazy parser, not as a separate
greedy candidate.

The lazy parser now also probes the four-entry recent-distance cache: when a
cached distance matches at least as long as the hash candidate, it wins the
tie and the cache is updated exactly like the wire writer. This is the first
incremental step of repcode-aware parsing that stays inside the lazy path.

| Input | Before | After |
| --- | ---: | ---: |
| sao 64 KiB | 47,125 | 47,096 |
| sao 1 MiB | 728,703 | 728,376 |
| nci / mr / x-ray / webster / XML / dickens | unchanged | unchanged |

The probe costs no measurable time (XML 807 vs 841 ms, sao 1,365 vs 1,384 ms
over three iterations) because cached distances usually fail on the first
byte. nci does not improve because its 1 MiB winner is the optimal parse, and a
backward DP cannot know the forward cache state.

Injecting the seed plan's exact per-position recent-distance cache into the
modeled DP (each cached distance as an extra match candidate priced at a flat
two bits) was rejected. It leaves nci (3,916), sao (47,096), mr (15,314), XML
(4,082) and x-ray (39,317) unchanged and regresses webster 19,548 -> 19,588 and
dickens 22,381 -> 22,446. The backward DP's cache comes from the seed path, so
the injected repcodes often do not match the path being built, and text pays
for the distortion. Reverted; the lazy parser's tie-preference remains.

Disabling q11's optimal parse leaves nci (3,916) and sao (47,096) unchanged, so
both are won by the lazy path, not the optimal parse. That makes the lazy
parser the right place to add repcode preference, but allowing a cached
distance to win with a 2/4/8-byte length deficit does not help nci at all and
regresses sao (47,096 -> 47,652/47,676). nci's repeats use many distinct
distances, so a four-entry local cache rarely covers the match a position
needs; the reference reaches 9,882 implicit distances by choosing distances
that repeat across long ranges, which needs a different parser rather than a
local slack rule. Reverted.

## Forward recent-distance beam, 2026-11-05

A forward beam parser carried the exact four-entry recent-distance state in
each search state, so a cached distance could be priced at its repcode cost
before the path was fixed. It used a 32 KiB token window, beam width four,
`max_chain = min(lazy.max_chain, 64)`, one matcher candidate per position and
a four-byte minimum match, then emitted the winning path through the existing
lazy command encoder. On q11 64 KiB it lost to the current best on every
measured row:

| File | Beam bytes | Current best | Difference |
| --- | ---: | ---: | ---: |
| nci | 3,951 | 3,916 | +35 |
| sao | 47,604 | 47,096 | +508 |
| x-ray | 40,128 | 39,317 | +811 |
| mr | 15,428 | 15,314 | +114 |
| webster | 21,619 | 19,548 | +2,071 |
| XML | 4,358 | 4,082 | +276 |

The same ordering holds below 64 KiB: nci 8/12/16 KiB is 846/1,119/1,410
against 837/1,088/1,376. The beam keeps more repcodes but pays for them with
shorter or worse-placed matches; its local fixed-cost model cannot value the
future match opportunities that the lazy and optimal paths preserve. The
experiment was reverted.

The first 16 KiB run also exposed a Zig type-inference hazard in the
implementation: `const window = @min(bro_beam_window, input.len - base)`
inferred a narrow integer, so `window * bro_beam_width` wrapped to zero and the
final state was read from slot zero. Any future windowed parser should annotate
the window as `usize` explicitly rather than relying on `@min` peer
resolution.

## Distance-parameter split re-encoding, 2026-11-05

The distance-parameter search selected a profitable `NPOSTFIX`/`NDIRECT`
alternative, but encoded it through the unsplit command path. The entropy
splitter therefore never saw the parameter set that actually won on binary
blocks. The search now re-encodes the winning parameter set through the lazy
command path with forced recent-distance state, so command, distance and
literal block types are evaluated against the same wire. The established
parameter-only candidate remains as a floor, and complete-wire arbitration
still chooses the smallest result.

On the Silesia binary rows this lowers q11 `sao` from 47,096 to 46,617 bytes at
64 KiB (size ratio 1.0404 versus libbrotli 1.0.9) and from 728,703 to 721,932
bytes at 1 MiB (1.0701). q9 `x-ray` at 64 KiB falls from 42,475 to 41,180
bytes. The measured q8/q11 `x-ray`, `nci`, `mr`, `webster`, `XML`, `dickens`,
`mozilla` and `ooffice` rows are unchanged, and the q8 `x-ray` floor remains
42,503 bytes. The serialized-dictionary fixture updates its baseline frame
from 3,513 to 3,512 bytes and total savings from 705 to 704 bytes; these are
the same complete-wire improvements observed through the public encoder.

Combining the winning joint literal plan with the adaptive distance plan was
also measured and rejected. On q10 x-ray the combined candidate runs, but the
complete wire stays 39,317 bytes; the adaptive distance plan saves only about
146 bytes on the lazy plan, far less than the literal split's contribution.
Pairing the joint literal plan with an adaptive command plan is rejected by the
current writer validation, so no complete wire exists for that combination yet.
The next attempt should either add writer support for joint literal plus
adaptive command types or move the repcode/distance-cost work into the optimal
parser, rather than layering more split candidates on the lazy plan.

Building the entropy model from the lazy seed plan (which probes the recent
distance cache) and re-planning the optimal parse with that model was also
rejected. It leaves x-ray q11 at 39,317 bytes, sao at 46,617 bytes and nci
1 MiB at 84,867 bytes. The lazy seed's distance histogram does not describe the
optimal path's match opportunities, so the extra parse only adds latency.
Reverted.

## Repcode-frequency distance bonus, 2026-11-05

The backward optimal DP cannot track Brotli's four-entry recent-distance
cache. For inputs above 64 KiB, the entropy model now also gets a bounded
repcode-frequency bonus: a distance that was used as a repcode in the seed
plan costs up to three bits less, capped by its observed frequency. The normal
model candidate and its modeled pass remain in the candidate set, so 64 KiB
rows and other 1 MiB rows keep their previous wires; complete-wire arbitration
only accepts the bonus result when it is smaller.

nci 1 MiB falls from 84,867 to 84,382 bytes (size ratio 1.2891 versus
libbrotli 1.0.9), with implicit distances rising 3,187 -> 3,885, short
distances 4,241 -> 5,527 and regular distances 17,959 -> 17,191. sao 1 MiB
stays 721,932 and x-ray 1 MiB stays 590,922. Applying the bonus only to the
first model, or only to the second modeled pass, is weaker; the accepted wire
comes from the bonus model built over the modeled commands. The extra large
input pass is a latency cost and remains a target for later performance work.

## Large-input adaptive block splits, 2026-11-05

The adaptive Viterbi splitter was capped at 32 KiB symbols, so 1 MiB optimal
plans with 80,000-143,000 commands never reached command or distance block
typing. The adaptive path now accepts up to 256 KiB symbols with a 16 MiB
scratch budget; the legacy fixed-grid proposal search keeps its 32 KiB u16
limit. Complete-wire arbitration still chooses the smaller result.

| File | Before | After | Size ratio |
| --- | ---: | ---: | ---: |
| mr 1 MiB | 295,511 | 291,417 | 1.0865 -> 1.0714 |
| ooffice 1 MiB | 542,854 | 542,522 | 1.1113 -> 1.1106 |
| dickens 1 MiB | 341,020 | 340,861 | 1.1172 -> 1.1166 |
| webster 1 MiB | 262,209 | 262,153 | 1.0956 -> 1.0954 |

nci, sao, osdb, mozilla, samba, x-ray and reymont 1 MiB keep their previous
wires. mr is the largest gain: it now emits eight command and eight distance
block types where the previous wire kept one. The larger split search adds
latency on 1 MiB inputs and is a later performance target.

Raising the adaptive type count from eight to twelve or sixteen was measured
and rejected as a single candidate: ooffice improves by 4/134 bytes, but
dickens regresses by 75/159 bytes. The eight-type plan remains the best
single-candidate compromise. Running both eight- and sixteen-type candidates
would capture both results but doubles the split search; it is deferred until
the large-input latency budget is addressed.

Clamping learned short-distance symbol costs to four bits was also measured
and rejected. It leaves x-ray 64 KiB at 39,317 bytes and nci 1 MiB at 84,382
bytes, so the optimal parser's distance choices are not limited by unseen
short-symbol prices. The remaining repcode gap needs state-aware parsing or
different block/distance parameters, not a cheaper short-symbol prior.

An explicit 32-tree literal context candidate between the existing `up_to_16`
and `full` proposals was also measured and rejected. It leaves x-ray (39,317),
mr (15,314) and nci (3,916) unchanged at 64 KiB; the extra clustering work
does not produce a smaller complete wire.

The remaining x-ray binary gap is now a writer feature: the reference wire has
one distance block type but three distance context trees, while Vort emits one
distance tree because `adaptive_distance_split` only writes a distance context
map when at least two distance block types exist.

## Single-block-type distance context trees, 2026-11-05

The planned writer now emits an unsplit compressed meta-block with one distance
block type and one to four distance context trees. Explicit distance symbols
are partitioned by `distanceContext(copy_len)` into four histograms, then a
restricted-growth-string search evaluates every partition of those contexts
and keeps the plan with the lowest estimated map-plus-tree cost. The identity
four-tree plan is one of the candidates. The chosen context map is written only
when more than one tree remains, and the distance encoder is selected per
command through that map. The candidate is fully encoded and compared with the
baseline wire, so the counting and prepared-command caches are bypassed rather
than taught a multi-tree shape. It runs only for q10/q11, standard windows,
empty metadata and no command or distance block split.

Measured on frozen 64 KiB Silesia prefixes with ReleaseFast, one codec thread,
`run-br-planned-encode-bench --limit 65536 --planned-quality 11 --iterations 1`,
A/B with the candidate gate disabled:

| File | Before | After |
| --- | ---: | ---: |
| sao | 46,617 | 46,581 |
| dickens | 22,381 | 22,373 |
| samba | 18,738 | 18,734 |
| x-ray / nci / mozilla / ooffice / webster / mr / osdb / XML | unchanged | unchanged |

The dynamic partition search saves a further 2 bytes on sao and 4 on dickens
over the identity four-tree plan, and adds samba to the winning set. The win is
small because the complete-wire arbitration already keeps the joint
literal/context candidate on most inputs. Combining distance context trees with
that joint literal plan was also measured and rejected: it grows x-ray from
39,431 to 39,455 bytes and from 39,317 to 39,340 bytes. Combining the joint
literal plan with the adaptive command and distance block plans was likewise
measured and rejected: all eleven 64 KiB q11 wires stay byte-identical while
encode time rises roughly 8-10%. The remaining x-ray gap is literal modeling,
not distance context typing or symbol block typing.

The candidate adds one full encode on unsplit q10/q11 plans. Observed encode
times rose by roughly 2-4% on the eleven 64 KiB rows, within single-iteration
noise; the larger q10/q11 latency budget remains a separate performance task.

## Repcode command-state beam widths, 2026-11-06

The repcode-aware command-state candidate retained two forward states per input
position. A four-state plan recovers measurable text bytes, but a wider beam is
not monotone in real wire size: on a synthetic 16 KiB XML fixture the four-state
plan ties the pre-candidate wire while the two-state plan wins by 27 bytes.
The four-state plan is therefore a second complete candidate, and both plans are
encoded and arbitrated against the baseline wire instead of replacing the narrow
one.

| Input | Narrow only | Narrow + wide |
| --- | ---: | ---: |
| XML 16 KiB | 1,558 | 1,550 |
| nci 16 KiB | 1,376 | 1,365 |
| XML 32 KiB | 2,418 | 2,397 |
| nci 32 KiB | 2,415 | 2,389 |
| XML 64 KiB | 4,082 | 4,040 |
| nci 64 KiB | 3,916 | 3,868 |

q10 produces the same 64 KiB numbers because q11 inherits the complete q10
winner below 64 KiB. Binary rows and 1 MiB inputs are unchanged, since the
command-state candidate is gated to text-like blocks up to 64 KiB. The gate
skips inputs of exactly 8 KiB and below, so those sizes are unaffected.

Above 32 KiB the wide beam also prices repcode reuse from a bonus model
learned from the modeled plan, while the narrow beam keeps the seed model. That
prior is a measured win at 32/64 KiB and not monotone below it, so inputs of
8/16 KiB keep the plain model for both beams. The gated bonus model adds:

| Input | Plain wide | Bonus wide |
| --- | ---: | ---: |
| XML 32 KiB | 2,397 | 2,375 |
| nci 32 KiB | 2,389 | 2,370 |
| XML 64 KiB | 4,040 | 4,021 |
| nci 64 KiB | 3,868 | 3,852 |

The command-state parser's candidate budget rose from eight to 32
near-chain distances. Eight candidates were the binding limit on repetitive
text, not the beam width:

| Input | 8 candidates | 32 candidates |
| --- | ---: | ---: |
| XML 16 KiB | 1,550 | 1,544 |
| nci 16 KiB | 1,365 | 1,361 |
| XML 32 KiB | 2,375 | 2,369 |
| nci 32 KiB | 2,370 | 2,360 |
| XML 64 KiB | 4,021 | 4,001 |
| nci 64 KiB | 3,852 | 3,816 |

Other text and binary rows are unchanged. Sixty-four candidates measured
another 4-5 bytes on the two 64 KiB rows but raised nci time further, so 32 is
retained. Encode time on the affected 64 KiB rows is about 2% higher for XML
and 10% for nci. One 4 KiB synthetic fixture loses a single byte because the
wide-beam plan ties instead of winning there; the real-text gains above are
kept only through complete-wire arbitration.

The beam's worst-slot cache that drives pruning previously compared only slots
zero and one, which was correct solely for a two-wide beam. It now scans the
whole retained set; beam two keeps identical behavior. The wide candidate also
encodes its compact and complete wires, matching the narrow candidate's two
wire forms.

The one-shot ceiling now follows the same rule as the chunked path: the default
sentinel extends to 64 KiB for text-like blocks or the binary opt-in, while an
explicit `command_state_max_input_kib` value (including zero, which disables
the candidate) is respected. Previously the text gate silently overrode an
explicit limit, so a 64 KiB text block with `0` still ran the candidate. A
public-API test covers zero and a 16 KiB ceiling on a 64 KiB text block.

The cost is transient memory and time: each state is 72 bytes, so the wide
array is `(input_len + 1) * 4 * 72` bytes, about 19 MiB at the 64 KiB gate
(narrow is 9.4 MiB, and the two plans do not overlap). Both parses run
sequentially, so peak memory is unchanged from the wide-only experiment.
Encode time on the affected 64 KiB rows rises about 45% (XML 412 -> 615 ms,
nci 380 -> 546 ms) because the command-state parse roughly doubles. The full
Brotli suite and the exact requested-heap contracts pass unchanged.

## Eight-state text beam, 2026-11-06

Text blocks of at least 32 KiB now use an eight-state wide beam; smaller text
blocks keep four states because their gain does not pay for the extra parse.
The binary opt-in keeps four states: its measured binary wins used that width,
and an eight-state plan lost the smallest synthetic fixture outright.

| Input | Four states | Eight states |
| --- | ---: | ---: |
| XML 16 KiB | 1,544 | 1,544 |
| XML 32 KiB | 2,369 | 2,368 |
| nci 32 KiB | 2,360 | 2,345 |
| XML 64 KiB | 4,001 | 3,971 |
| nci 64 KiB | 3,816 | 3,784 |

All other rows are unchanged. The extra states cost encode time: 64 KiB XML
596 -> 725 ms and nci 594 -> 754 ms; 32 KiB XML 190 -> 278 ms and nci 208 ->
331 ms. The state array is `(input_len + 1) * 8 * 72` bytes, about 37 MiB at
the 64 KiB gate. The full Brotli suite passes unchanged.

A sixteen-state text beam was also measured and rejected as the default: XML
64 KiB 3,971 -> 3,955 and nci 3,784 -> 3,754, but encode time rises to 1,100 /
1,206 ms and the state array doubles to about 75 MiB. Eight states remain the
ratio/latency balance.

## Large-window distance context trees, 2026-11-06

The distance-context candidate was limited to standard windows. It now also
runs for opt-in Large Window q10/q11 wires through window 30, using the
large-distance alphabet and header format. On 65,535-byte q11 prefixes with
`large_window=true, window_bits=17` the complete-wire arbitration shrinks
sao 46,619 -> 46,583 and dickens 22,384 -> 22,376; x-ray (39,415), nci (3,786)
and XML (3,973) are unchanged. Windows 25 and 30 produce the same sizes as
window 17 on these inputs, and every encoded wire round-trips through the
Vort decoder with `allow_large_window`. Two direct tests cover the large
command-plan header path and a 64 KiB quality wire.

## Rejected 64 KiB optimal search window, 2026-11-06

The q10/q11 optimal seed and modeled passes cap their search window at the
shared 32 KiB deflate limit. Raising that cap to the Brotli 16-bit window was
measured end to end: the fixed distance table was extended to 65,535 entries,
the entropy-feedback window check, the command-state parser and the fixed
optimal guard were all lifted, and both the seed and modeled passes searched
the full 65,520-byte window.

The result regressed the main binary row: x-ray 64 KiB q11 grew from 39,279 to
40,177 bytes (+898), while sao stayed at 46,581. A hash-chain index with a
3-byte anchor and a 512-node chain budget floods with collisions once the
window doubles, so the candidates that matter fall outside the bounded chain
and the parse prefers worse far matches over the nearer ones it used before.
Widening the window therefore needs a better far-match index (a binary tree or
a separate long-distance pass), not a larger chain bound. The experiment was
reverted; the 32 KiB cap remains until such an index is available.

The bounded alternative was also measured and rejected. A mid-distance
augmentation reuses the long-distance pass with a band starting just above the
shared 32 KiB window (32,769...65,520) and inserts its matches into literal
runs of the modeled plan, with complete-wire arbitration. At minimum matches of
16, 8 and 4 bytes it changed no wire on x-ray, sao, dickens, nci or XML at
64 KiB. The missing bytes on x-ray are therefore not reachable mid-distance
copies alone; they need a repcode-aware parse, not another far-match pass.

A wider functional limit was also confirmed: a 200 KiB unique block followed by
an exact copy (400 KiB input) encodes to 409,605 bytes with Vort and 204,855
with libbrotli. The shared LZ77 layer stores distances in 16 bits, so nothing
beyond 65,535 bytes is reachable even though Brotli can advertise a larger
window. Lifting that needs a wider command-distance representation, which is
separate work from the window experiment above.

## Binary command-state wide beam, 2026-11-06

The command-state candidate is gated to text-like blocks, so binary rows never
see the wide beam. Removing that gate (running only the wide beam on binary
blocks, always encoding its complete wire) does win on three 64 KiB q11 rows:

| File | Gated (current) | Wide beam on binary |
| --- | ---: | ---: |
| x-ray | 39,279 | 39,217 |
| ooffice | 30,674 | 30,542 |
| mr | 15,314 | 15,140 |

sao, mozilla, dickens, webster, osdb, samba, nci, XML and reymont keep their
wires. The cost is large: encode time rises 13-47% on binary rows (mozilla
680 -> 1,002 ms, sao 920 -> 1,061 ms), including rows with no size gain. The
compact wire is a poor predictor for binary (x-ray's compact is 49,680 while
its complete wire wins), and the measured short-distance share does not
separate winners from losers (ooffice wins at 26% short distances while sao
loses at 0.08%). Reducing the binary candidate budget from 32 to 8 keeps
ooffice's win but loses x-ray's and most of mr's, and does not lower the
latency materially.

The binary opt-in also raises its near-chain budget from 64 to 256 distances;
the wider chain is what recovers the ooffice and mr bytes, while x-ray saturates
earlier. At the time of that measurement the default kept the text-only gate,
and the binary behaviour was exposed as the explicit
`PlannedEncodeOptions.binary_command_state` opt-in (mirrored by
`PlannedStreamChunksOptions`) for quality 10/11 blocks up to 64 KiB. Removing
the gate entirely was also measured: the same binary wins appear plus osdb
25,428 -> 25,358, but encode time rises 13-100% on rows that do not win
(mozilla 680 -> 1,254 ms). The later increment below enables this behaviour by
default above the 8 KiB floor.

Lowering the command-state parser's minimum match from four to three was also
tried and rejected on ratio, not on a plan/writer failure: the candidate
encodes correctly (the 4 KiB synthetic binary fixture falls 231 -> 230 bytes)
but loses 9 bytes on nci (3,784 -> 3,793) and ties the other measured 64 KiB
rows. Allowing three-byte matches only at cached recent distances still leaves
nci at 3,789, so the short-copy model lacks the observations needed to price
that shape. The four-byte minimum remains.

## Default binary command-state, 2026-11-06

The repcode-aware command-state candidate now runs for q10/q11 blocks of 8 KiB
to 64 KiB regardless of content. Text-like blocks keep the narrow plus wide
beams; other blocks run only the wide beam with the 256-distance near chain.
The candidate still arbitrates its complete wire against every other
candidate, so the selected stream can never grow. The chunked path uses the
same ceiling and the same 256-distance chain for binary blocks.

| File (64 KiB q11) | Before | Default binary | libbrotli 1.0.9 |
| --- | ---: | ---: | ---: |
| x-ray | 39,279 | 39,217 | 52,196 |
| ooffice | 30,674 | 30,542 | 33,883 |
| osdb | 25,428 | 25,388 | 27,614 |
| mr | 15,314 | 15,140 | 16,919 |
| sao | 46,581 | 46,581 | 52,928 |
| dickens | 22,363 | 22,363 | 27,052 |
| samba | 18,725 | 18,725 | 23,224 |
| webster | 19,540 | 19,540 | 24,045 |
| reymont | 17,072 | 17,072 | 20,555 |
| mozilla | 13,906 | 13,906 | 15,745 |
| nci | 3,784 | 3,784 | 5,017 |
| XML | 3,971 | 3,971 | 6,524 |

q10 produces the same four winning wires because q11 inherits the complete q10
winner below 64 KiB. Non-winning binary rows pay 15-31% encode time for the
attempt (sao 0.93 -> 1.09 s, samba 0.72 -> 0.94 s); text rows and nci are
unchanged. The zero `command_state_max_input_kib` ceiling remains the explicit
opt-out, and `binary_command_state` now only forces the wide beam on binary
blocks at or below the 8 KiB floor.

The earlier "dozens of frozen assertions" estimate did not hold at the current
revision: no existing frozen wire or requested-heap expectation changed, and
the full Brotli suite passes 1548 with one platform skip. Public-API tests
cover the automatic one-shot and chunked wide-beam attempts, the no-growth
contract, the small-block force flag, the zero opt-out and rejection outside
quality 10/11. The binary attempt remains a later latency target on rows where
it does not win.

## Default-window far-copy reach, 2026-11-06

Default quality schedules advertise a 16-bit window, and the shared near
matcher caps at 65,520 bytes. The quality path's long-distance pass previously
ran only for explicit 17...24-bit windows, so default q6...q11 one-shot streams
could not reach copies beyond the near window at all. A 200 KiB unique block
followed by its exact copy (400 KiB input) therefore encoded to 409,605 bytes
at q11 while libbrotli 1.0.9 produced 204,822.

The default q6...q11 one-shot path now runs one bounded far-match candidate for
inputs through 1 MiB. It augments the lazy command plan and the literal-only
alternate, then advertises only the smallest RFC window that the winning plan
actually uses (17...20 bits). Complete-wire arbitration retains the original
16-bit stream whenever the far pass does not pay for itself, and an explicit
`window_bits` request remains an exact opt-out. The command proposal keeps a
64-node predecessor chain; the literal-only proposal uses 16 nodes because it
only needs to recover a complete far copy across incidental near matches.

| Input | Before | After | libbrotli 1.0.9 |
| --- | ---: | ---: | ---: |
| 400 KiB far copy (200 KiB distance), q11 | 409,605 | 204,822 | 204,822 |
| 1 MiB far copy (512 KiB distance), q8 | 1,048,581 | 526,444 | 524,310 |
| mr 1 MiB, q8 | 304,319 | 292,289 | - |
| webster 1 MiB, q11 | 261,978 | 261,978 | 239,314 |
| webster 1 MiB, q8 | 290,189 | 290,189 | 264,969 |
| dickens 1 MiB, q8 | 372,410 | 372,410 | - |

The far-copy wires advertise window 18 and 20 respectively, matching the
smallest RFC window their farthest copies need. A wider decoder window must
buy more than a tie, so the auto candidate must beat the 16-bit incumbent by at
least 64 bytes or 0.1%. Dickens' two-byte far win is therefore rejected; mr's 12,030
bytes are kept. Webster keeps its 16-bit winner; the extra pass costs about
4-8% at q11 on four 1 MiB rows (webster 8.64 -> 9.36 s, x-ray 7.26 -> 7.52 s,
sao 7.73 -> 8.03 s, nci 5.49 -> 5.80 s) and about 25% at q8 on webster
(0.68 -> 0.85 s). A single-proposal pass with a 32-node chain left 207,466
bytes, so the literal-only proposal and its 16-node chain are retained.
Work is bounded to one MiB; larger inputs and the chunked/incremental APIs
retain their explicit-window behavior. The candidate's predecessor ring is
transient, allocator-owned and charged to any whole-operation memory lease
(at most about 4 MiB at the 1 MiB gate).

`tools/br/planned_encode_bench.zig` now exposes `--window-bits`, so default and
explicit-window paths can be compared directly. `long_distance` also exposes
`windowBitsForInput`, `windowBitsForDistance`, `farthestLz77Distance` and a
caller-selected chain budget for this candidate. A default q6 encode of a 128
KiB repeated-random fixture asserts a wider wire and full round-trip, while an
explicit 16-bit request keeps the narrow wire.
