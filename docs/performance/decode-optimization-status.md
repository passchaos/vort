# Decoder optimization status

This note consolidates the 2026-11-01/02 decoder-performance session so the
next work does not repeat rejected experiments. Raw evidence stays in
`docs/performance/` and `/tmp/vort-decode-priority-20261031/`.

## 2026-11-12 exact-copy full-matrix rejection

The [three exact-copy trials](deflate/exact-copy-interleaved-20261112/README.md)
translate libdeflate's limited-live-value copy technique into exact-span Vort
non-overlap buckets. Aggregate arrays, interleaved16 and interleaved32 remain
isolated prototypes; none is adopted.

The final interleaved32 twelve-row screen reached 1.031290x, but expansion to
all 72 cold rows reaches only **1.005154x** (95% CI 1.003689–1.006631x).
Nine controls fall below 0.98x; weakest x-ray64K/L9 is 0.971265x. Size-group
geomeans are 1.010916x/1.001974x/1.002596x for 64K/1M/full. It fails both the
3% aggregate and control gates. The declared nci64K/L9 and XML64K/L6 rows
improve 1.078267x and 1.075562x, insufficient for a 20% cliff-repair claim.

The expansion retains 576 child events, four balanced AB/BA process sweeps,
**two** measured and two warmup paired batches per child: 1152 measured and
1152 warmup pairs. Each process's complete Vort batches form its median;
baseline/candidate outer pairs feed fixed-row log statistics. Reference timing
does not normalize candidate gains. Ordinary timing and earlier PMU screens
stay separate; the full expansion has no PMU observations.

Final candidate exhaustive copy, protected-page contracts and full Deflate
738/738 tests pass, as do all 72 frozen-wire smokes. Good copy code generation
does not establish a whole-operation win. The current ranking below still
measures committed 21e4a1d0 codec source. Next pursue final execution-table
construction/lifetime from the [reference study](reference-decoder-study-20261112.md),
including exact tails and resource ownership, rather than another copy bucket.

## 2026-11-12 complete current committed decoder matrix

The [current-source refresh](modern-decode-refresh-20261112.md) binds committed
`21e4a1d0` codec source to all360 lifecycle rows/2160measured/720warmup pairs.
All72-row cold throughput Vort/reference is **68.87% / 76.58% / 81.93%** versus
libdeflate1.26/libzstd1.6.0/libbrotli1.2.0. Zstd matched prepared is77.70%.
Weakest cold rows are mr64K/L9 60.35%, mozilla1M/L3 59.91% and fullMozilla/q11
48.46%. Deflate reference-only-prepared is separately labeled; no Brotli
prepared rows are claimed.

Every raw paired observation and stdout/stderr/RSS is retained; frozen wires
are reused and complete output/guards/input immutability/version/loader scope
are checked. CI/order provenance and currentsource/competitor epochs remain
distinct. These dev-host results update the current measured ranking, not
industry leadership or attribution of changes since the November11 epoch.

## 2026-11-12 fused dense preparation screen

The [fused canonical constructor](deflate/owner-dense-construction-20261112.md)
removes the owner-generated list's extra sparse validation/counting scan while
retaining the original scalar and dense oracle source. Corrected-v2 native/
x86 dedicated tests pass90/90, owner96/96, fullDeflate738/738 and smoke72/72.
The original zero-capacity compile failure and corrected empty-metadata oracle
remain separate epochs.

Twelve ordinary cold rows reach 1.016197x (95% CI1.011517–1.020832x), weakest
nci1M L9 0.996796x, below the 3% aggregate adoption bar. The 160 events retain
96 ordinary and64 PMU observations separately. Scalar non-relocation bytes/
relative branches match; caller code/stack still differ. No helper or owner
prototype is adopted. Next target a larger measured preparation/execution
cost, with fresh whole-operation/resource gates.

## 2026-11-12 original scalar owner-preparation control

The [preparation control](deflate/owner-prepare-control-20261112.md) retains
original scalar source and proves full-symbol non-relocation byte consistency:
3659 bytes, stack296, identical direct/real jump-table relative targets, with
all 46 byte differences in call/RIP relocations. Caller text/stack/registers
still differ, and helper bodies are not all compared.

Twelve ordinary cold rows are 1.004636x (95% CI 1.002049–1.007177x), weakest
reymont64K L6 0.989457x; below the 3% adoption gate, so the owner is not adopted.
The 160 events separate 96 ordinary and 64 PMU observations. Constructor Safe
96/96, full Deflate Safe738/738 and all72 ordinary-wire smoke pass. Next test
fused checked dense in-place preparation, avoiding the generated-list sparse
API's extra scan while preserving scalar and incomplete-tree contracts.

## 2026-11-12 Vort-batch PMU diagnosis

The [scoped PMU diagnosis](deflate/pmu-batch-profile-20261112.md) adds optional
three-event groups to the public decoder probe, retaining raw nine-word reads,
IDs and cumulative/full-running kernel times. Reference decoding, clocks and
full validation stay outside counters; PMU wall ratios are explicitly
diagnostic in raw and final summary/CSV outputs.

The new instrumented cohort completes 144 four-row/three-mode child events.
Owner-only nci64K L9 and XML64K L6 instructions remain 0.991871x/1.000266x,
while cycles rise 1.101504x/1.092142x and misses 1.738043x/1.494908x. Four
precise branch recordings place added bounded sample weight at the sixteen-
byte copy-loop cmp/jbe. The 26-byte inner body matches, but the full scalar
entry's register/control flow differs and stack grows 16 bytes. This is not a
preparation-only or layout-only control; no prototype is adopted and no old
timing/code-layout identity is inherited.

Pure Zig contracts pass 13/13, final Python evidence tests 9/9, all comparator
builds and other-codec PMU smoke pass. Next retain the original scalar kernel
while isolating owner preparation, with fresh codegen and operation controls.

## 2026-11-12 mapped owner and handoff rejection

The [mapped owner / normalized handoff screen](deflate/mapped-owner-handoff-20261112.md)
constructs checked canonical/semantic tables in final owner storage and mints
an opaque borrow for a separate u32 match entry. Private generic/window tables
retain full-width behavior; valid incomplete distance trees remain supported.
Codegen materializes the word but carries normalized length separately across
next-entry/refill, increasing the scoped symbol by 70 bytes and local stack
reservation by 16 bytes. It does not achieve a single-value handoff.

Both isolated variants are rejected. Twelve cold public-operation rows and
four AB/BA process pairs per variant/row retain 192 child events: owner + word
is 1.000209x (95% CI 0.996069–1.004467x), target reymont64K L6 1.023978x,
weakest control 0.985289x. Owner-only scalar is 0.969613x, target 1.042355x,
weakest nci64K L9 0.891105x. Neither reaches the 20% target; the scalar control
also fails 0.98x. No prototype codec source or complete-ranking update is
adopted.

Native Debug/Safe and x86 Safe each pass 105 aggregate/import shim tests;
full Deflate Safe passes 738/738 without those new imports. Both variants pass
all 72 frozen wires. The first two fixture failures and corrected short-tail
error expectations retain separate source/log epochs. WASI is compile-only
in this screen, and development-host timing is not dedicated-host acceptance.

## 2026-11-12 missing long-distance secondary correction

The [distance secondary hole correction](deflate/distance-secondary-holes-20261112.md)
closes a public malformed-stream acceptance defect. Allocated incomplete long
distance suffix ranges had undefined holes, and semantic readers did not reject
zero widths. A real two-block fixture returned successful 305-byte consumption
with 143-byte Debug or 131-byte ReleaseFast output; the independent canonical
oracle rejects its missing code. The recorded ReleaseSafe build rejected it,
so that result cannot stand in for all code-generation modes.

The `d31dc389` increment initializes each allocated suffix range and rejects
zero widths in ordinary/window/non-overlap, rolling and sink consumers. Valid
incomplete distance codes retain their existing support. Six public scenarios
and 18 direct modes pass in Debug/ReleaseSafe/ReleaseFast/x86/actual WASI; root
facade tests also pass, and full Deflate ReleaseSafe is 738/738. Filtered 10/92
counts include import tests and repeated public aggregates.

All 72 frozen wires pass full-output/consumption/guard smoke. A 96-child,
twelve-row non-regression pilot is 1.004717x, weakest row 0.995362x, without a
new full-matrix or dedicated-host performance claim. A future prepared-range
proof must include defined hole handling; no mapped-word executor is adopted.

## 2026-11-11 complete refreshed decode comparison

The [complete refresh](modern-decode-refresh-20261111.md) binds the verified
`ea193be2` source to 360 lifecycle rows and 2,160 measured pairs against
libdeflate 1.26, libzstd 1.6.0 and libbrotli 1.2.0. All-72-row cold throughput
Vort/reference is **68.77% / 76.56% / 80.86%**; matched prepared Zstd is
**77.73%**. The weakest cold Brotli row, full mozilla q11, reaches **48.65%**.
These development-host observations do not establish industry leadership.

The later DirectChunk repair and incremental
[step-borrow correction](../formats/deflate-incremental-step-borrows.md) are
functional increments outside that timing epoch. The latter rejects whole-call
unread-input/output/history/state conflicts before progress or pause changes,
preserves inactive second-half storage and admits optional semantic fallback.
No speedup is attributed to either repair. After correctness gates, profile
Deflate's 64 KiB weak rows and Brotli's full mozilla q11 cliff against this
modern complete matrix.

The [incremental proof archive](deflate-incremental-step-borrows-20261111/README.md)
binds `17a8f5a0` to 718 full Deflate tests, 24 focused contracts in
ReleaseSafe/Debug/x86/actual WASI, 112 filtered public-root/object tests, and
394 successful Debug compilation/interop steps. Aggregate root coverage is
filtered to the new contracts; the optimized all-repository CLI attempt was
interrupted and is recorded separately. Source-reverse WASI stderr warnings
are checked against actual successful exits rather than a `failed command`
display label.

The next [Mozilla decode pilot](br/decode-mozilla-profile-plan-20261111.md)
compares full q11 with its near-parity 1 MiB control and attributes the actual
multi-block kernel/header/setup paths. Existing single-final-block clustered
profilers cannot directly attribute that full-file cliff.

The completed [Mozilla pilot and isolated screens](br/decode-mozilla-profile-20261112.md)
keep the clean `5fb4c695` full q11 public-call ratio at **2.0511x** libbrotli
1.2.0. Two four-process-pair screens show about 5.3% for resolved pointer
caching and 4.8% for stable packed nine-bit auxiliary planes on this row;
neither reaches the 20% cliff-repair gate, so neither codec variant is adopted.
The latter adds 512 KiB of bounded lookup storage. All raw pairs and exact
timing sources remain separate from later test variants. The reusable
multi-block header tool is available through `build-br-header-profile` and
`test-br-header-profile`. Existing 16 KiB DWARF stacks do not cross the wide
wrapper's 537,976-byte stack frame, so sampled hotspot shares are explicitly
scoped to the observed payload root rather than the complete public decoder.

The later [actual route/count investigation](br/decode-mozilla-distributions-20261112.md)
shows that seven wide10 generic blocks contain 98.65% of full Mozilla q11
commands, with NPOSTFIX=3 and signed emitted literals. Command density is
about 3.80x its 1 MiB control. Two semantic-root/phase combinations are rejected:
full q11 speedups 0.990488x/0.988713x and q6 0.960493x/0.959690x. Moving large
canonical temporaries out of the hot function reduces stack subtraction from
9,864 to 408 bytes but does not improve whole decoding. The adopted increment
is the shared prepared dispatcher plus bounded per-meta diagnostic replay and
the whole-stream counter tool; no acceleration or new complete ranking is
claimed. Further work should reduce hot live state and measure complete calls.

The [compact context-map screen](br/compact-context-map-20261112/README.md)
retains all six permutations of main/previous/compact across three Mozilla rows,
with 54 successful child events and a separate excluded non-executable attempt.
Packing the four validated distance context bytes into a u32 passes the 23/23
ReleaseSafe oracle, but compact/main throughput is 0.989817x on full q11,
0.999899x on 1 MiB q11 and 0.975281x on full q6. It is rejected; no production
codec acceleration is adopted from this screen.

## 2026-11-12 Zstd generic split known all-FSE screen

The [sao profile and three reader screens](zstd/generic-split-all-fse-20261112/README.md)
bind a clean `093d5b9c` baseline to isolated candidates. The frozen full-file L3
wire has 306 compressed blocks, 4,464,797 Huffman literal bytes and 429,839
sequences; every sequence mode byte is `0xa8`, with no repeat-mode blocks.
The existing generic four-stream literal layout is selected before later
all-FSE executors on this shape. A block-owned proof can therefore remove
repeated mode dispatch without changing the 128 KiB literal staging, thresholds,
literal/match copies, table borrowing or continuation policy.

Each variant runs six cold/prepared rows and four interleaved process pairs per
row, retaining 48 successful child events. Values below are whole public-call
speedups, `baseline Vort time / candidate Vort time`; reference timings are not
used to calculate these candidate speedups.

| sao L3 row | Mode-only | Grouped noinline | Grouped inline |
| --- | ---: | ---: | ---: |
| 64 KiB cold | 1.005951x | 1.008656x | 0.984864x |
| 64 KiB prepared | 1.003452x | 1.005741x | 0.999808x |
| 1 MiB cold | 1.002814x | 1.091796x | 1.120794x |
| 1 MiB prepared | 1.006664x | 1.095120x | 1.119647x |
| Full cold | 0.996572x | 1.096195x | 1.138106x |
| Full prepared | 0.996921x | 1.092837x | 1.116525x |

The grouped reader keeps three checked symbol lookups and commits reverse-bit
progress at each original OF/ML/LL extra and LL/ML/OF transition boundary. The
timing variants group at most 56 requested bits with at least 64 remaining.
Short input and larger total requests retain the checked sequential reader.
Independent oracle tests pass 13/13 in Debug/ReleaseSafe for the original
specialization and 13/13 ReleaseSafe for both grouped variants. Timing and later test-adapter source
epochs remain distinct in the archive.

The later private mapped-entry audit found a limit in the grouped timing
variants:
an individual 33-bit extra field could pass the total-bit group gate and trap
in ReleaseSafe, although public wire mappings never produce that field width.
An isolated proof-only correction widens width aggregation to u16, checks each
group field's bound and retains the generic fallback for private wide entries.
The before probe passes 12 tests and crashes in the new contract; guarded native
Debug/ReleaseSafe and 32-bit x86 ReleaseSafe runs all pass 13/13. New long-suffix
witnesses cover grouped InvalidMatch/end progress and 32-bit arithmetic failures.
Private 33/64/65/255-bit fields exercise the checked fallback. This corrected
source is not benchmarked or adopted; its checks are not backdated to the timing
source.

None is adopted. Mode-only is nearly neutral; grouped noinline improves the
large weak rows by about 9–10% and grouped inline by about 12–14%, both below
the predeclared 20% cliff-repair gate. The inline 64 KiB cold screen contains
substantial process-pair variation. No complete Zstd acceptance matrix or
dedicated-host gate was run. These local gains do not update the complete
76.56% cold or 77.73% prepared modern-reference ranking above.

The same frozen perf recording supports the dispatch diagnosis, with 62 reader
self samples whose physical caller is generic split. The incomplete outer
call chains do not establish a complete public-decoder sampling denominator;
diagnostic sample shares are not throughput gains. Output-tail literal storage
was deferred because it still materializes all literals and copies most literal
runs, with additional output-suffix, alias and padding constraints. It was not
implemented in these candidates.

## 2026-11-12 Deflate public generic contracts and current profile

The later [wide-copy complete-range correction](deflate/wide-copy-contracts-20261112.md)
fixes an internal underflow for lengths 3..15 while preserving lengths 3..258.
The existing production wide-call domain is at least 17; it now uses a
separate validated core while the full facade retains exact short copying.
Final Debug/ReleaseSafe/x86/actual WASI scalar oracles cover 143,712 scenarios,
full Deflate passes 736/736, and 72 frozen wires pass full-output/consumption/
guard smoke. The 12-row functional non-regression pilot is 1.003628x, weakest
row 0.984859x, without a performance-gain or full-ranking claim.

The [paired match-path profiles](deflate/match-path-profiles-20261112.md)
observe higher nci wide-copy weight and a common preload/refill live-state
region. Percentages use the observed physical root's sampled period, with
reference/harness work outside that root; no instruction-cost attribution is
claimed. The new capture's 2048-file registry remains original, with 15 omitted
build modules separately reconstructed from immutable Git for replay.

The [checked completed-match codegen prototype](deflate/completed-match-codegen-20261112.md)
passes 739 complete tests but fails to carry only one word across refill:
LLVM keeps full-width parameters, word/tag and pointers across refill. Static
symbol size 3669→4001 and local stack 296→328 support rejecting this mechanism
before A/B. It changes no mainline entry/refill layout or complete benchmark
ranking; its exact sources and original static output remain archived.

The [public generic contract increment](deflate/public-linear-contracts-20261112.md)
adds real-header LL14 secondary and independently generated LL10 witnesses.
They prove the actual public generic selector and wide-loop preconditions
before checking InvalidMatch, InvalidHuffmanCode, OutputTooSmall, short output
and a real fast-to-tail truncation handoff. The old private/public comparison's
public call selects compact9 and cannot establish this route. All guards and
exact successful output/consumption are checked without forbidding permitted
scratch stores inside caller capacity.

Deflate filtered Debug/ReleaseSafe/x86/actual WASI passes 8/8 each, public-root
Debug/ReleaseSafe/actual WASI passes 90/90, and complete Deflate ReleaseSafe
passes 734/734. These filtered totals include import tests; the new behavioral
scope is 27 public scenarios plus two direct root calls. The independent zlib
oracle covers eight real-header output/error cases. No production decode
behavior or throughput claim changes in this functional increment.

The [fresh current-source profile](deflate/reymont-profile-20261112/README.md)
binds byte-equivalent `8adfb3ba` to the same modern reymont 64 KiB L6 wire.
The whole-process capture records 2,681 samples with no reported loss;
physical semantic-loop weight is 58.02% of the captured child, which also
contains libdeflate and validation. This is a diagnostic share, not a
Vort-only timing or instruction denominator. It continues to favor the
semantic loop over the small duplicate distance-setup cost.

The [two reader dependency screens](deflate/reader-screens-20261112.md) are
rejected despite 734/734 ReleaseSafe correctness. Length-prefix metadata
removes a serial distance-primary shift, but the twelve-row screen is only
1.009984x; target reymont64K L6 is 1.048682x and nci64K L9 is 0.938845x.
Independent OR56 refill normalization has a 0.961166x twelve-row mean, with
nci/xml64K controls 0.839242–0.923285x. Both miss the 20% target and 0.98x
control gates. All 192 successful child events and exact candidate epochs are
retained, without a complete-matrix or dedicated-host acceptance claim.

Machine-code inspection confirms the intended local dependency changes, but
both aligned functions reserve 16 more stack bytes and have changed hot-path
spills. Whole-symbol static counts cannot attribute those control losses.
Independent first-block parsing confirms all six 64K rows select generic11;
the 1 MiB nci first blocks select non-overlap, with later blocks unclassified.
Further work should first reduce measured hot live state or material token
work, rather than infer gains from an isolated arithmetic simplification.

## 2026-11-11 checked dictionary seeding and provision

The later [dictionary seed/provision correction](deflate-dictionary-borrows-20261111/README.md)
binds `7d846abe` to two real before defects: overlap memcpy aborts and compact
pending-match reseeding that reads stale slots in ReleaseFast. Checked seeding
uses memmove and rejects insufficient pending history before state mutation,
while retaining receiver/workspace/second-window sources and benign stopped
states. Its [fallible seed contract](../formats/deflate-dictionary-borrows.md)
requires callers to handle `Error!void`. Full Deflate/Deflate64 passes 733 tests,
native x86/actual WASI contracts pass, and 40 decoder clone events validate
independent history/reset/dictionary ownership against libz. Debug whole-library
compilation passes 380 steps. This is functional evidence outside the frozen
performance epoch; no throughput improvement is claimed.

## 2026-11-11 earlier modern reference epoch

The [new frozen raw-pair matrix](modern-decode-current-20261111.md) executes
360 lifecycle rows against libdeflate 1.26, libzstd 1.6.0 and libbrotli 1.2.0.
Cold-context whole-operation Vort/reference time is 1.457x / 1.312x / 1.211x
over 72 rows per codec (64 KiB, 1 MiB and full files). All measured/warmup pairs,
library closures, source/frame hashes and host settings are retained. This
replaces the older installed-library gap routing below for its declared scope;
reference-only prepared Deflate rows and matched prepared Zstd rows remain
separate. These development-host observations are not an industry-best claim.

## 2026-11-11 Raw Deflate borrow correction and follow-up routing

The later `e0f3cd17` [contiguous wrapper correction](deflate-contiguous-borrows-20261111.md)
extends write admission to zlib/gzip prefixes, Stored/concatenated facades,
complete dictionary sets and scalar reset receivers. The actual checksum-ignore
probe returned successful `abcabc` before the fix; corrected aliases refuse
without writes and independent retries return `abcdef`. Final full Deflate
validation passes 700 tests. The auto-gzip optional dictionary remains ignored
and may safely share output. These are functional results, not a fresh timing
epoch. See [the contract](../formats/deflate-contiguous-wrapper-borrows.md).

The follow-up `b6709ae9` closes the shared legacy chunk-joining borrow boundary
for Raw Deflate/zlib/gzip, including reusable consumers and outer PNG buffers.
The previous join could overwrite an unread payload or dictionary and still
return successful wrong output. Admission now finishes before writes, retains
single-source borrowing, supports identity/current-chunk memmove layouts, and
protects descriptors, dictionaries, complete outputs/append allocations and
receiver/retained storage. Aliased append read borrows stage through the caller
allocator before output growth; real OOM remains an error with cleanup.
See [the contract](../formats/deflate-chunk-borrows.md) and
[the full evidence](deflate-chunk-borrows-20261111.md).

The complete Deflate family passes 698/698 tests, public-root gate 94/94, and
Debug/x86/actual 32-bit WASI shared contracts. The independent compatibility
campaign binds 216 raw/zlib/gzip wires to 1,368 schedule rows, including
fragmentation, packed identity and both safe current-chunk moves. These are
functional checks, not updated throughput or memory-leadership measurements.
Scratch-free direct chunk execution, contiguous dictionary-set and incremental
ownership still require their separate contract audits.

The preceding `f74ca1fe` functional change rejects caller-output overlap with
complete compressed input or preset dictionary storage before any writes.
The old raw stored path could return `abcabc` instead of `abcdef` after
overwriting a later block's unread payload, even when each individual memcpy
was disjoint. See the [borrow contract](../formats/deflate-decode-borrows.md)
and [before/after evidence](deflate-raw-output-alias-20261111.md).

The complete Deflate family passed 695/695 tests, public-root gate 94/94,
focused Debug/ReleaseSafe/x86 and actual 32-bit WASI execution. The 72 frozen
Deflate wires passed a functional/benchmark-executability smoke at one call
per batch. Those smoke timings do not update the preceding source epoch's
throughput figures or establish a performance ratchet.

The [weakest-row entry profile](deflate/entry-profile-20261111/README.md)
attributes about 92.4% of executable-weighted events to the semantic loop.
Duplicate generic/semantic distance setup exists, but its removable cost was
not isolated and no A/B variant was attempted. Preserve current singleton,
empty/incomplete-distance and malformed-input error order before any lazy
setup experiment.

A separate [Brotli exact-64-KiB model-reuse plan](br/repcode-model-reuse-plan-20261111.md)
identifies identical repcode-bonus model construction for bonus DP and the
later wide command-state parser. It remains planned, with exact-wire,
requested-peak/OOM and whole-operation gates. The next functionality slice
should audit chunk joining and zlib/gzip/incremental borrow surfaces before
advancing that encoding optimization.

## Historical 2026-11-01/02 gaps

Latest 1,296-process epoch (`industry-aln64-comparison.json`), current/reference
against libdeflate, libzstd 1.6.0 and libbrotli 1.2.0:

| Codec / level | 64 KiB | 1 MiB | full |
| --- | ---: | ---: | ---: |
| Deflate 6 | 1.5586 | 1.4702 | 1.4759 |
| Deflate 9 | 1.5515 | 1.4636 | 1.4660 |
| Zstd 3 | 1.5000 | 1.4753 | 1.4501 |
| Zstd 19 | 1.4817 | 1.4999 | 1.5040 |
| Brotli 6 | 1.4798 | 1.1445 | 1.2170 |
| Brotli 11 | 1.3920 | 1.1274 | 1.2251 |

Relative to the frozen baseline the current source is 15–28% faster. `perf
stat` shows both Deflate and Zstd are instruction-bound at the reference IPC
(Deflate 2.57 vs 2.52 with 77% more retired instructions; Zstd 3.51 vs 3.57
with 49% more).

## Adopted in this session

- Deflate live-range work: litlen width scoped to its token, reservoir-derived
  bit position, one packed `length_entry`, one packed `distance_entry`
  (about 13.5–14% on the 48-row screen).
- Deflate 64-byte entry alignment for the generic semantic loop (about 0.3%).
- Zstd plain offset adds on 64-bit targets and the folded wildcopy literal
  bound (about 3.5%).
- Brotli incremental short-span copy threshold and inline history-copy
  decision (about 7% on the streaming screen).

## Rejected directions (do not retry without new evidence)

- Table shape: 8/9/10/11/12-bit primaries, single-literal entries, pair caps,
  distance-table widening, prepared-lookup widening.
- Speculation: chain depth 2/3/5, deferred fourth load, recomputed bit sums.
- Cursors and checks: pointer cursors, precomputed fast-loop limits, hoisted
  limits, per-match check removal with wide headroom, `outputEnd` inlining,
  branch hints, `distance == 1` reorder.
- Storage: merged 16-bit literal-pair store, 32/64-byte copy tiers, pair
  variants.
- Layout: dedicated sections, alignment on the non-overlap wrapper, Brotli
  payload and incremental `step`, Zstd X2 wide policy, non-overlap selection
  threshold.
- Brotli tables: prepared-lookup zeroing skip, single-symbol folding, staged
  extra-bit routing, literal-run history batching.
- Zstd: cursor local promotion, short-match branch-first, X2 wide decoder.

## Later 2026-11-02 findings

- Adopted after the first consolidation: the Deflate semantic loop now
  preloads the next literal entry before the reservoir refill (about 4–5%),
  and the incremental Brotli literal-run batching was rejected (fast but
  truncation-unsafe; every correct variant is slower).
- The 24% stack reload in the full-file Brotli tail-lookup payload is a stall
  sample, not extra work: converting the wide copy entry points to a by-value
  cursor made the 48-row screen 1.5–2.2% slower.
- Zstd grouped extra-bit reads, paired state reads, `ShiftingGroup` on the
  main path, and an early sequence-container load are all neutral.
- Any correct truncation guard that places a non-inlinable call inside the
  incremental literal loop costs more than the check it removes.

## Later 2026-11-09 finding

- Zstd split-loop repeated-offset local promotion was rejected. Copying
  `state.repeated_offsets` into a local array with a `defer` commit made the
  64 KiB level-3 `nci` and `xml` rows 17.5% and 19.4% slower in a five-round
  alternating A/B; `mozilla` improved 1.6% and `dickens` was neutral. The
  address-taken local and the exit commit interfere with the split loop's
  register allocation. Do not retry this shape without a different escape
  analysis.
- Zstd `wide_copy_sequence_min` 2048 -> 1024 was adopted. Blocks with
  `literal_bytes <= 4096`, `sequence_count <= 4096` and sequence counts in
  `[1024, 2048)` now use the dense four-stream executor. A 36-row paired
  matrix (64 KiB focus plus all twelve 1 MiB sources at levels 3/19) measures
  a `0.968166` geometric mean, `0.6711`/`0.6723` on the target `nci`/`xml`
  64 KiB level-3 rows and a worst control of `1.0039`. See
  [the evidence](zstd-small-copy-policy-20261109.md).
- Zstd `split_sequence_min` 1024 -> 512 was rejected. A 48-row paired screen
  (twelve sources, 64 KiB/1 MiB, levels 3/19, five rounds) measures a
  `1.0006` geometric mean, no row more than 2% faster and `xml` 64 KiB
  level 3 3.3% slower. Keep 1024.
- Zstd `wide_copy_sequence_min` 1024 -> 512 was rejected. The same 48-row
  paired screen measures a `0.9992` geometric mean, only `nci`/`ooffice`
  64 KiB level 3 about 2% faster, and `mozilla` 1 MiB level 3 1.6% slower.
  The 1024 threshold already captures the large `nci`/`xml` wins.

## 2026-11-09 Zstd decode session

- Adopted: split-executor short-match routing, single-vector match kernels,
  single-branch grouped field reads, one combined transition read
  (`sequence_transition_group.read`), and an out-of-line ungrouped fallback
  shared by the medium, dense, wide, raw all-FSE and Huffman-sequence
  executors. Paired 48-row A/B against the session start: field-group increment
  `0.9396` (-6.04%, 95% CI `[0.9221, 0.9557]`); raw-executor increment neutral
  overall (`0.9975`) but `mozilla.1m` L19 -9.5% and `sao.1m` L19 -5.0%. The
  absolute reference/Vort decode ratio moved from `0.7067` to `0.7562`.
  See [sequence executors](zstd-decode-sequence-executors-20261109.md),
  [field groups](zstd-decode-field-groups-20261109.md), and
  [raw executors](zstd-decode-raw-field-groups-20261109.md).
- Rejected: 4x16 unrolled 64-byte match wildcopy in the dense executor.
  Gating at `match_len > 16` and `offset >= 64` gave `xml.64k` L19 -2.43% in an
  8-round A/B but `dickens.64k` L3 +0.66%, `reymont.1m` L19 +0.99% and
  `xml.64k` L3 +0.34%; gating at `match_len >= 64` regressed `dickens.64k` L3
  +7.1% and `reymont.1m` L19 +6.9% from loop codegen alone. The added branch and
  over-copy stores outweigh the target-row gain.

## 2026-11-09 Deflate and Brotli decode baselines

- Current-source Deflate one-shot decode vs libdeflate 1.10 on zlib-1.3 level
  6/9 frames: 48-row reference/Vort geometric mean `0.9131` (Vort 1.10x
  slower), 64 KiB rows 1.12x and 1 MiB rows 1.06-1.07x. `nci.1m` is 14% faster
  than libdeflate. The 2026-11-01/02 table's 1.47x Deflate row is stale. See
  [the Deflate matrix](deflate-decode-current-20261109.md).
- Current-source Brotli one-shot decode vs libbrotli 1.0.9 at qualities 6/11:
  48-row reference/Vort geometric mean `0.7154` (Vort 1.40x slower); 64 KiB
  rows are 1.51-1.67x and 1 MiB rows 1.22-1.24x. `nci.64k` q6 is 2.9x slower.
  See [the Brotli matrix](brotli-decode-current-20261109.md).
- Adopted in Brotli decode: inline the per-symbol command/literal/distance tree
  lookups and `readCommandSymbol`. 48-row `--vort-only` A/B `0.9949` (-0.51%,
  95% CI `[-0.98%, -0.09%]`), with the weakest 64 KiB rows 3-5% faster and two
  1 MiB rows about 2% slower. Below the default bar but above the 0.98x control
  floor.
- Rejected: inlining only `ensureLiteralBlock` and `literalContext` (neutral to
  +1.35%); inlining only `readCommandSymbol` (neutral).
- Adopted: cache resolved tree pointers per block type in the generic
  prepared-lookup payload. The command tree pointer and (inside the inline
  tiers) the 64 literal-context and four distance-context tree pointers are
  resolved on block switches instead of per symbol. 48-row five-round
  `--vort-only` A/B `0.9916` (-0.84%, 95% CI `[-1.27%, -0.45%]`); command-dense
  64 KiB rows improve 3-5%, worst control +0.98%. Gating the literal/distance
  caches to frames with at most 64 trees was required: the ungated optional
  pointer variant regressed `x-ray.1m` q11 +2.12%. See
  [the Brotli matrix](brotli-decode-current-20261109.md).
- Adopted: select the wider prepared/tail-lookup Brotli kernels by decoded
  meta-block length instead of compressed stream size. Highly compressible
  64 KiB inputs (for example `nci.64k` q6 at 4,214 wire bytes) had been locked
  out of the fast kernels by the 16 KiB wire threshold. The one-shot minimal
  path shares the large-frame dispatch (inline, gated against caller
  dictionaries and meta blocks below 64 KiB). 48-row five-round A/B `0.9536`
  (-4.64%, 95% CI `[-7.80%, -1.77%]`); command-dense 64 KiB rows improve
  16-32% (`mozilla`/`mr`/`xml`/`nci`), worst control `xml.1m` q11 +1.94%.
- After the three Brotli increments the current-source libbrotli 1.0.9
  reference/Vort 48-row geomean moved from `0.7154` to `0.7594` (Vort now
  1.32x slower overall instead of 1.40x); 64 KiB q6 from 0.5989 to 0.6888,
  64 KiB q11 from 0.6602 to 0.7287. After seven increments (through the
  direct-indexed Huffman long-code fallback) the geomean is `0.7843` (Vort
  1.28x slower): 64 KiB q6 0.7206, 1 MiB q6 0.8331, 64 KiB q11 0.7509,
  1 MiB q11 0.8392; `sao.1m` q6 1.0745 and `mozilla.1m` q11 1.0377 beat
  libbrotli.
- Adopted: pin the active literal block's context map/mode, tree index,
  external 10-bit lookup and canonical table in locals inside the 10-bit
  external-literal payload, refreshing them only at explicit block switches.
  48-row five-round A/B `0.9898` (-1.02%, 95% CI `[-1.32%, -0.72%]`); every
  group improves 0.9-1.2%, worst control `x-ray.64k` q6 +0.89%. A
  branch-scoped-locals variant regressed +0.54% and was rejected.
- Adopted: pin the active distance block's four context trees and map in
  the npostfix-zero auxiliary 10-bit payload, refreshing only on distance
  block switches and selecting the cached instantiation comptime per meta
  block. 48-row five-round A/B `0.9948` (-0.52%, 95% CI `[-0.84%, -0.21%]`).
  Gating was required: the ungated cache regressed npostfix-2 rows about
  +1% (`mozilla.1m` q11 +2.14%), and a runtime gate still measured
  +0.43% overall; only comptime selection keeps the npostfix-0 gains.
- Adopted (shared `src/huffman.zig`, benefits all codecs): direct-indexed
  Huffman long-code fallback. Table construction records the unreversed
  first canonical code per width; the fallback converts the reversed peek
  to canonical and indexes the band entry in O(max_bits) instead of linear
  scanning every symbol. Brotli 48-row five-round A/B `0.9800` (-2.00%,
  95% CI `[-2.55%, -1.48%]`); `nci.64k` q6 -8.11%, nci.64k q11 -6.80%.
  No wider fast-lookup table, so it avoids the quality-11 regression of the
  rejected 10-bit command tail lookup. Verified with huffman/br/zstd and
  deflate (670) test suites.   Cross-codec check is neutral: Deflate 48-row geomean 1.0006 and Zstd
  0.9989 (libdeflate L6/L9, libzstd L3/L19), every row above the 0.98x
  floor.
- Rejected: ten-bit fused external command lookup inside the 10-bit literal
  payload. The external-distance pairing failed `InvalidHuffmanCode` on the
  command-dense rows; the correct command-10-only variant regressed the
  48-row geomean +0.75% (q11 1 MiB +1.50%) with no target-row gain.
- Rejected (Brotli auxiliary payload micro-fusions, 2026-11-10): cached
  distance `single_symbol` (1.0007), combined extra-bit extraction
  (1.0342), split block-count/remaining branch (1.0000) and cached command
  `single_symbol` (0.9965 five-round but +0.94% to +1.31% on 1 MiB rows in
  ten-round rechecks). The payload is now structurally bound; further gain
  needs a full libbrotli-style phase-machine fusion, not local caching.
- Design boundary recorded for the Brotli phase-machine fusion
  milestone: [brotli-phase-machine-fusion-design](brotli-phase-machine-fusion-design.md).
  Compares the libbrotli `BrotliRunningState` suspend/resume enum with
  Vort's single-loop three-phase payload, scopes an internal phase enum
  behind the existing one-shot wrapper, and sets the 48-row A/B and
  differential correctness gates. Not scheduled for micro-commits; the
  prior four rejected fusions show isolated caching cannot win without
  the split.
- Adopted (Deflate decode): inline fixed-width vector copies for
  non-overlapping matches up to 258 bytes instead of runtime-length
  compiler-rt memcpy (`shortcopy.copyWide`, bounded by the linear loop's
  258-byte headroom). 48-row three-round A/B `0.9838` (-1.62%, 95% CI
  `[-2.82%, -0.68%]`); 64 KiB groups -2.51%/-2.88%. The libdeflate 1.10
  reference/Vort matrix moves 0.9131 -> 0.9261; `nci.64k` L9 0.8208 ->
  0.9287. deflate.zig tests 670/670.
- Adopted (Deflate decode): `@branchHint(.unlikely)` on the literal
  exceptional-flag and distance secondary-table branches in the semantic
  linear loop, identified by a branch-miss profile. 48-row five-round
  A/B `0.9817` (-1.83%, 95% CI `[-2.35%, -1.32%]`); all four groups
  -1.68% to -2.12%, worst control +0.87%. A semantic-table base-pinning
  experiment measured 0.9998 and was rejected. The libdeflate 1.10
  reference/Vort matrix moves 0.9261 -> 0.9437 overall; `nci.64k` L9
  reaches 0.9930 (near parity, 0.8208 at session start).
- Zstd decode matrix rerun at current head (2026-11-10, libzstd 1.4.8):
  reference/Vort 48-row geomean 0.7067 -> 0.7573 (Vort 1.32x slower);
  L3 64 KiB 0.7815, L3 1 MiB 0.7665, L19 64 KiB 0.7366, L19 1 MiB
  0.7454; strongest `x-ray.64k` L3 0.9832. Weak-row profile shows the
  split-dense FSE sequence executor at 43% plus 9.5% FSE table build;
  IPC 3.29 and branch-miss 0.65% leave no branch-hint headroom, and
  wider wildcopy tiers remain rejected. Next gain needs executor
  fusion or FSE build scatter reduction; see
  [zstd-decode-current-20261110](zstd-decode-current-20261110.md).

## Remaining structural options

1. Deflate fastloop rewrite with libdeflate entry semantics (low byte = total
   bits, single destructive consume, extras from the saved buffer). Measured
   evidence says the extraction counts are equivalent, so the expected gain is
   uncertain; it needs a new loop plus differential tests before any switch.
2. Split the Deflate loop into a literal-run loop and a match loop to cut the
   register set per body; the current loop is register-starved (about 11% of
   instructions on four stack slots). Analysis 2026-11-02: the inner literal
   loop would need the same input-availability and output-headroom checks
   before each group (a refill advances the input cursor and two groups can
   exhaust the sixteen-byte headroom), so the split re-creates the outer
   condition and adds no savings. Do not implement it as described.
3. Brotli payload state-machine fusion (goto style) to remove the per-command
   phase/branch dispatch; the payload function is flat at about 1–5% per
   instruction, so only a restructure can move it.
4. Zstd field-decode consolidation (one bit-container read per sequence with
   three compact slices) and a precomputed safe-bound wildcopy predicate.

## Tooling notes

- 48-row screens: `measure-matchbits.py` (Deflate), `measure-zstdbranch.py`
  (Zstd), `measure-oneshot-brotli.py` (Brotli), `measure-stream-*.py`
  (incremental) under `/tmp/vort-decode-priority-20261031/` and
  `/tmp/vort-br-lookup-20261101/`.
- Industry epoch: `measure-industry-*.py`, 1,296 processes, two alternating
  sweeps, pinned CPU2.
- `zig build test` compiles the aggregate `vort-tests` module for over an hour
  at 100% CPU in this environment; use `test-br`, `test-zstd`, and
  `zig test src/deflate.zig` instead.
- The repository `.zig-cache` reached 73 GB and corrupted compiler state once;
  clearing it restored builds (disk use dropped from 92% to 76%).

## 2026-11-16 local-lever exhaustion and A/B methodology

A dedicated pass tried to convert the measured hotspots into concrete changes
and established that no isolated micro-edit clears the 3% geomean bar. Full
evidence: `brotli-payload-fusion-20261116/` and `zstd-fse-explore-20261116/`.

Brotli (one-shot `processTailLookupCompressedPayload`, two perf runs confirm
the ranking):

- `Sha2x32` 8.4% is benchmark-harness provenance, not a decoder symbol (no
  `Sha2*` under `src/br`).
- Cross-meta-block table reuse cannot fire: the 1 MiB benchmark frame has one
  meta-block (limit 16 MiB); memset is mandatory one-time per-frame table
  initialization, already minimized by three `HuffmanTable.Decoder.init` tiers.
- Two implemented candidates failed paired A/B (two baselines each) and were
  reverted: nine-bit peek specialization (+0.24%, noise) and block-switch guard
  loop hoist (-0.81% geomean, control through 0.98).
- match-copy, prepared-lookup caching, ring masking, and the previous-byte
  slide are already optimal or correctness-mandated.
- The earlier "goto payload fusion" idea does not apply to the one-shot path:
  `perf annotate` shows it is already a single fused loop with flat dispersed
  instructions (top 3.85%), i.e. intrinsic Huffman/copy work, not removable
  dispatch. It only remains a separate question for the incremental
  `copy_decoder`, which the reference bench does not profile.

Zstd (Silesia 64K nci/xml L19 baselines added; Vort 1.42-1.47x slower):

- The 2026-11-10 frame-state memcpy candidate is already resolved
  (`initialSequenceFrameState` returns `.{}` with no dictionary; default
  `SequenceFrameState = .{}` at 67 sites).
- Lowering the FSE dense-run `probability >= 192` gate is high-risk and capped
  by the build's 9.5% profile share, so it cannot alone clear 3%.
- The 43% sequence-executor hotspot needs an architecture-level
  executor/table-representation fusion (a table layout the executor consumes
  directly), matching prior rejections of cursor promotion, branch-first, and
  wider wildcopy.

Net: further throughput progress on both codecs is structural/algorithmic
(SIMD Huffman gather for Brotli; executor/table fusion for Zstd), not local.
Any such project must keep wire output byte-identical, retain portable/WASM
parity, and pass the paired two-baseline A/B with the 3% geomean / 95% CI /
0.98x control floor.

## WASM/portable prerequisite verified (2026-11-16)

Before any future architecture-level SIMD/executor work, the portable build
path was re-verified healthy on this branch:

- `zig build check-wasm`: 64/64 steps succeeded (all wasm32-wasi targets
  compile, including the brotli portable twin and zstd huffman object).
- `zig build test-deflate-wide-decode-wasm`: 3/3 steps succeeded (32-bit WASI
  behavioral test runs, not just compiles).

So the portable/WASM parity requirement that gates native SIMD changes is
currently satisfiable; a structural optimization can land only if it keeps
these WASM gates green alongside the native paired A/B adoption bar.

## Final disposition of the structural options (2026-11-16)

The four "Remaining structural options" above were all revisited and closed
with evidence this session:

1. Deflate fastloop rewrite: left unimplemented; the measured equivalence of
   extraction counts still gives no positive expected value, and the deflate
   gap is the smallest of the three (~1.08x on nci 64K).
2. Deflate literal/match loop split: confirmed "do not implement" as analyzed;
   the split re-creates the outer availability/headroom checks.
3. Brotli goto phase fusion: ruled out on both paths. The one-shot
   `processTailLookupCompressedPayload` is already a single fused loop (perf
   annotate: flat, top 3.85%), and the incremental copy_decoder needs its
   explicit phase machine for 26 partial-buffer resume points.
4. Zstd field-decode consolidation: the executor already consumes single-word
   field groups (`readBranchless` is an alias of `read`); only a full
   pipeline/representation redesign could change the 46% executor, which is a
   research-scale project, not a local edit.

Additionally, two implemented micro-candidates (nine-bit peek, block-switch
hoist) failed paired A/B and were reverted; SIMD Huffman gather is impossible
under the serial prefix-code dependency; and table-width/dense-run tweaks have
measured ceilings below the 3% bar. No open local or structural decode
optimization with positive expected value remains in the current architecture.

## Why the wall is the wire format, and where the next lever lives (2026-11-16)

A source-grounded follow-up proves the zstd executor ceiling is the FSE
load-use recurrence itself, not a removable inefficiency. In
`sequence/raw_mixed.zig` `read()`, the next `ll/ml/of_state` is
`entry.next_state + readField(..., entry.state_bits)`: the next table index
needs the current dependent table load plus a data-width bit read, so
iterations cannot be gathered or pipelined. The entry is already one packed
8-byte word (`fse_table.zig:26-30`), the three ~2 KiB tables are L1-resident,
and a sequence's bits already load in one 8-byte group with shift extraction
(`field_group.zig:26-47`, where `readBranchless` is a `read` alias). Repacking,
widening, SIMD gather, and phase-machine flattening therefore have no positive
expected value; the incremental phase machine is mandated by partial-buffer
resume.

Full mechanism, the ILP argument, and the gated remit are in
[zstd-serial-entropy-wall-20261116](zstd-serial-entropy-wall-20261116.md). The
only legal wall-breaker is a deliberately decode-parallel entropy stage in the
native `vort` format: native v0 still compresses via store/deflate/RLE/
dictionary-patch/LDM, and "future ANS/FSE-style entropy" remains an unbuilt
goal (`docs/native-format.md:8-10,97-99`). That is a separate feature
milestone requiring golden vectors, format versioning, fuzzing, WASM parity,
and the paired two-baseline 3% / 95% CI / 0.98x A/B — not a local edit.

## Current three-codec decode baseline vs installed libraries (2026-11-16)

The provenance-tagged reference benches were run on Silesia `xml`/`nci`/
`mozilla`; full CSVs and a normalized summary are in
[data/wire-reference-baseline-20261116](data/wire-reference-baseline-20261116/README.md).
One-shot, single-thread, ReleaseFast on an i7-10700K; `>1` means Vort faster:

| codec | reference | xml | nci | mozilla |
| --- | --- | ---: | ---: | ---: |
| Deflate | libdeflate 1.10 | 1.017 | 1.150 | 0.936 |
| zstd | libzstd 1.4.8 | 0.783 | 0.840 | 0.821 |
| Brotli | libbrotli 1.0.9 | 0.926 | 0.930 | 0.927 |

zstd is the consistent 16-22% gap and Brotli a steady ~7%; Deflate is near
parity and file-dependent. The zstd/Brotli references are old (2020/2016), so
these are lower bounds on the competitive distance, not parity evidence, and
the run is a single-host diagnostic rather than an adoption gate. It
re-confirms the FSE serial wall above as the structural zstd decode ceiling;
no production code changed. **This three-file read is superseded by the
twelve-file sections below**, which correct both the Deflate and Brotli
characterizations and replace the old-libzstd zstd number with a current 1.6.0
measurement; keep this paragraph as the historical small-sample record only.

## Full-Silesia sweep and the x-ray Huffman-gate weak row (2026-11-16)

A perf hotspot location for the flat ~6% deflate common-path deficit is in
[deflate-common-path-hotspot-20261116](deflate-common-path-hotspot-20261116.md):
on `mozilla`, 45.9% of self-time sits in the serial
`deflate.semantic.linear_entry.aligned` loop (table build only ~1%), and the
remaining unnamed inlined samples resolve to the same region. The prior
exhaustive A/B screen already rejected every local lever on this path (table
shape, speculation, cursors, checks, storage, layout), so the gap is the
irreducible per-symbol critical path and needs structural work, not another
local edit.

The twelve-file sweep
([data/wire-full-silesia-20261116](data/wire-full-silesia-20261116/README.md))
corrects the small-sample read: Deflate is slower on 9/12 files vs libdeflate
1.10 (median 0.940), and zstd is behind on 12/12 vs libzstd 1.4.8 (median
0.799). The worst row, `x-ray` at 0.550, is a distinct mechanism from the FSE
wall: it is 99.85% literals with ~28 sequences/block, all 65 Huffman sections
are four-stream, but zero blocks pass any X2 entry gate (sparse needs 1536-2048
sequences; the ratio is ~80% vs a 66% main gate), so every block uses the
scalar four-stream fallback. A reversible local experiment then relaxed the
66% ratio gate: x-ray deterministically regressed ~4.6% (0.550 -> 0.525) while
a compressible control improved slightly, proving X2 engages but is slower for
long-coded near-incompressible symbols. The gate is correctly tuned and the
widening lever is falsified, not open. Full mechanism and the experiment are in
[zstd-xray-huffman-gate-20261116](zstd-xray-huffman-gate-20261116.md).

The Brotli sweep was completed to all twelve files in the same package and
corrected a second small-sample error: it is not a steady ~0.93x but a
file-dependent 0.747-1.466 (median 0.957), with Vort faster on 5/12 and slower
on 7/12. Vort leads strongly on near-incompressible literal-heavy files (`sao`
1.466, `x-ray` 1.324) — the opposite of zstd on the same inputs — and trails
most on `mr` (0.747). These leads are provisional pending a current libbrotli
measurement, since the installed 1.0.9 is from 2016.

## zstd measured against current libzstd 1.6.0 (2026-11-16)

The old-reference caveat is now resolved for zstd using the locally built,
SHA-pinned libzstd 1.6.0 (the same identity the differential gate pins). Full
twelve-file data is in
[data/wire-zstd-1.6.0-current-20261116](data/wire-zstd-1.6.0-current-20261116/README.md).
The median Vort/reference ratio drops from 0.799 vs 1.4.8 to **0.760 vs 1.6.0**
(12/12 behind); `x-ray` collapses from 0.550 to **0.326** as upstream improved
its near-incompressible Huffman path, and `mr` falls to 0.603. The 1.4.8 numbers
were indeed only a lower bound; the structural conclusion (FSE serial wall and
Huffman X2 gating, both requiring non-local work) is unchanged and reinforced.

## Brotli measured against current libbrotli 1.2.0 (2026-11-16)

Using a locally cmake-built libbrotli 1.2.0 via the new runtime library
override, the median Vort/reference ratio moves from 0.957 vs the distro 1.0.9
to **1.017 vs a fairly-tuned 1.2.0 build** (`-O3 -march=native -flto`; Vort
faster on 7/12), with near-incompressible leads persisting (`sao` 1.462,
`x-ray` 1.323) and a weak spot at `mr` (0.790). A generic-Release 1.2.0 build
gave a slightly optimistic 1.040; both are recorded with library SHAs in
[data/wire-brotli-1.2.0-current-20261116](data/wire-brotli-1.2.0-current-20261116/README.md).
Vort's absolute speed is unchanged across runs, so the defensible statement is
rough parity with current libbrotli on decode plus a structural edge on
high-ratio literal-heavy inputs — not an adoption-gate-grade lead.

## Zstd level-1 wide-executor state localization (2026-11-16)

The full-Silesia reference sweep decodes level-1 frames, not the level-19
prefixes used by the serial-entropy-wall profile. A fresh instruction sample on
level-1 `dickens` puts the dominant path in
`tryDecodeAllFseSplitWideHuffmanSequences`, where Vort executed about 159
instructions per sequence versus about 117 for libzstd 1.6.0 on the **same
libzstd-produced wire**: an instruction-throughput gap, not a stall on the FSE
recurrence. The wide executor was the only split executor still reading the
output cursor and LL/ML/OF states through the caller-owned
`SequenceDecodeState` on every sequence. Keeping the cursor in a local
(`defer` commit) and the three states in locals, matching the compact and
medium executors, moves the twelve-file level-1 geometric ratio from 0.6957 to
**0.7286** (geomean speedup **1.0472**, 12/12 wins; median 0.7606 -> 0.7983).
Repeated-offset localization was tested and rejected: alone it regressed
`dickens` from 0.7272 to 0.5685, so it is not part of the change. Evidence:
[data/zstd-wide-state-localization-20261116](data/zstd-wide-state-localization-20261116/README.md).
Native `test-zstd`, `test-zstd-huffman-x2` and 44/44 decode-memory contracts
pass; the `test-zstd-decode-memory-wasm` node gate exits 201 on the unmodified
baseline too, so it is a pre-existing environment condition.

## Zstd single-sequence Huffman literal decode (2026-11-16)

After the wide-executor localization, `x-ray` remained the worst level-1 row at
0.3364. An LBR call graph resolves the hot chain to
`decodeLiteralOnlyCompressedBlockIntoBuffer -> decodeSinglePredefinedSequence
-> copyHuffmanLiteralsFromSection -> HuffmanLiteralCursor.readSymbol`: a
single-sequence block decoded its Huffman literal section **twice from the
start**, once per literal run, through the checked per-symbol loop.
`decodeSinglePredefinedSequence` now decodes a four-stream section once with
the reservoir loop directly into the output, slides the trailing literals
right by the match length, and emits the match into the gap; smaller and
single-stream shapes keep one stateful cursor as a fallback. `x-ray` moves from
0.3364 to **0.7811** (2.32x in this increment, 2.39x versus the original 1.6.0
baseline). The twelve-file geometric ratio improves from 0.7286 to **0.7835**
(geomean speedup **1.0754**, 9/12 wins, lowest control row 0.9927). The
stateful-only intermediate measured 0.3889 and is retained only as fallback;
lowering the literal-only fast-path threshold from 16 KiB to 4 KiB regressed
x-ray to 0.3282 and was rejected. Evidence:
[data/zstd-single-sequence-huffman-20261116](data/zstd-single-sequence-huffman-20261116/README.md).
Filtered `predefined` (49/49), `stream counters` (42/42) and `literal`
(162/162) tests pass; focused and WASM gates are recorded with this increment.

## Zstd compressed-literal split threshold (2026-11-16)

After the single-sequence fix, `mr` remained the weakest level-1 row at 0.6210.
Its blocks are all-compressed with about 700-1000 sequences and 17-19 KiB of
literals, which failed `preferSplit` (`sequence_count >= 1024` or
`literal_bytes >= 32 KiB`) and fell to `tryDecodeGenericSplitHuffmanSequences`,
whose `readModeSequence` switches on the mode for every symbol. Lowering
`split_literal_min` to 16 KiB routes those blocks to the specialized wide split
executor; decoupling `raw_all_fse_literal_min` at 32 KiB keeps raw-literal
routing unchanged. `mr` moves to **0.7560** (+21.7% in the increment, 25.5%
cumulatively), and the twelve-file geometric ratio moves from 0.7835 to
**0.7973** (geomean speedup **1.0176**, lowest control row 0.9929). Sequence
threshold variants (256/128) also fixed `mr` but emptied the
`preferHuffmanMatchWildcopy` range and failed the policy consistency test; the
literal-threshold change keeps every policy invariant. Evidence:
[data/zstd-split-literal-threshold-20261116](data/zstd-split-literal-threshold-20261116/README.md).
Focused `predefined` (49/49), `literal` (162/162), `stream counters` (42/42) and
decode-memory/source-reverse/compressed-workspace (228/228) tests pass; full
`test-zstd` and `check-wasm` results are recorded with this increment.

## Brotli mr long-code scan: 11-bit lookup rejected (2026-11-16)

A level-1 `mr` profile against the tuned libbrotli 1.2.0 build places the decode
hot path in `processSingleTreeExternalLookupCompressedPayload` (35%) and the
256-symbol Huffman decode (22.6%). Annotating the processor shows about 21% of
profile samples in the canonical long-code scan loop (16-bit compare at a
6-byte stride) after the 10-bit packed lookup misses.

Widening `ExternalLiteralLookup` from 10 to 11 bits did **not** improve Vort's
absolute decode throughput: 359 MiB/s baseline versus 357 MiB/s with the wider
table. The apparent paired-ratio move from 0.790 to 0.841 was reference-side
drift; a baseline re-run immediately after measured 0.790 again with Vort at
359 MiB/s. The change was reverted. The scan covers codes of 12 bits and wider,
so an 11-bit root cannot remove it. A 12-bit root was then tested on the same
`mr` row: Vort's absolute throughput stayed at 357.7 MiB/s versus 359.2 MiB/s
baseline, so the wider table did not speed up the decode either; the paired
ratio moved only because the reference side drifted (282 versus 454 MiB/s in
the two runs). Both root-widening attempts were reverted. A two-level literal table (10-bit
root plus direct secondary blocks for 11-15 bit codes) was then implemented for
the single-tree path and validated against the canonical decoder, including a
bit-order bug that the full stream test missed and the benchmark caught. The
single-tree tests passed 35/35, but Vort's absolute throughput stayed at
357.1 MiB/s versus 359.2 MiB/s baseline, so the scan removal did not pay for
the larger table and build cost. It was reverted as well. The apparent paired
ratio moves in all three experiments were reference-side drift; the `mr` scan
is not a removable local lever with these table designs.

## Zstd compact executor routing check (2026-11-16)

`preferSmallCopies` (literal bytes <= 4 KiB and sequence count < 1024) is
checked inside the `preferSplit` branch (sequence count >= 1024 or literal
bytes >= 16 KiB), so the two conditions are disjoint and
`tryDecodeAllFseSplitHuffmanSequences` is unreachable in the production
one-shot dispatch; only the profile helper calls it directly. Enabling the
union on the twelve-file level-1 sweep measured geometric **1.0002** (xml
-1.0%, x-ray +1.2%, nci +0.8%, webster +0.7%), no adoption; reverted. The
generic loop is competitive for that shape. Separately, skipping the 16-byte
literal wildcopy for zero-length runs measured neutral on nci (0.7864 versus
0.7875) and was reverted. Both are closed local levers.

The dense pair fast path was also offered to the wide executor by changing its
gate from `!use_wide_copies` to `(use_wide_copies or use_long_match_wildcopy)`.
On `dickens` it regressed the level-1 ratio from 0.8067 to **0.7386** (-8.4%),
so the pair path is correctly dense-specific; the gate stays.

## Structural decode frontier (2026-11-16)

The local, policy and table-shape levers for the three codecs are now measured
and closed. The remaining zstd (~20% median), Deflate (~6%) and Brotli `mr`
gaps need structural work. The consolidated state, closed-lever list and the
three structural candidates (zstd executor representation v2, Deflate token
two-phase, Brotli single-tree literal reservoir) are in
[structural-decode-frontier-20261116](structural-decode-frontier-20261116.md).

## Deflate incremental decode vs zlib-ng and CRC short-update slices (2026-11-16)

With zlib-ng 2.3.90 built locally as a zlib-compatible static library, the
reusable incremental gzip decode bench fills the audit's missing modern
streaming matrix. Vort is behind zlib-ng on the small and fragmented rows
(http-4k full 0.29x, fragmented 0.31-0.37x; json-32k full 0.42x) and close on
text-64k (0.91x). A profile attributes 8.5% of cycles to
`crc32Slice32Update`; 31-byte streaming chunks fell through the 32-byte slice
loop to the serial byte loop. Adding 8- and 4-byte slice loops improves the
fragmented rows **1.25x** (http-4k) and **1.32x** (json-32k) in an alternating
three-run A/B, with the full rows unchanged within host variance. Evidence:
[data/deflate-incremental-crc-20261116](data/deflate-incremental-crc-20261116/README.md).
The checksum oracle passes 19/19; focused deflate/zip test steps and
`check-wasm` are recorded with the increment.

An admission-result cache for the step-invariant semantic alias pairs was
tried next: cache the workspace/scratch versus decoder-state/history checks in
a per-attachment optional field and check only the caller's input/output per
step. It regressed the fragmented rows (http-4k 0.816x, json-32k 0.757x
against the CRC-only binary), likely from the added optional field and the
resulting decoder layout change on the hot step path. Reverted. The admission
checks are not a simple next lever; the fixed-block bulk decode or the zstd
asm kernels are the remaining candidates.

A literal-run output budget in `decodeSymbolRun` hoisted the per-literal
max/expected checks into one budget per run. The alternating three-run A/B
measured a **1.017** geometric mean over the eight bench rows (binary full
1.042x, text fragmented 1.035x, http fragmented 1.031x, json full 0.985x),
below the 3% adoption bar and overlapping host noise. Reverted. The streaming
gap needs the fixed-block bulk path or a broader state-machine change, not
per-literal check hoisting.

The `PackedLookup` long-code fallback was then switched from the linear
per-symbol scan to the same canonical direct-index algorithm already used by
`HuffmanTable.decodeValueLongAfterLookup`. Vort's absolute `mr` throughput was
unchanged (359.47 versus 359.21 MiB/s), so the linear scan was not the measured
bottleneck on this path; the paired-ratio move was reference-side drift again.
Reverted. The brotli `mr` long-code fallback is not a portable-scan lever.

## Zstd levels 1-2 speed-first policy landed (2026-11-16)

The public level policy now resolves levels 1-2 to one `fast_compressed`
primary frame with no adaptive split ladder and no per-call
`std.Thread.spawn` in the one-shot, reusable, append, into-slice, bound,
dictionary, dictionary-set, diagnostics, and FastCover scoring paths. Explicit
strategies, accelerations, HQ requests, and encode controls still take
precedence; the quality ladder remains at level 3 and above.

On the 128 KiB `dickens` prefix level 1 moved from 7.56 MiB/s at 50,404 bytes
to 77.11 MiB/s at 63,414 bytes and level 2 from 1.58 MiB/s at 50,325 bytes to
76.02 MiB/s at 63,414 bytes (13-18% larger than libzstd 1.6.0, about 4.1x
slower). Evidence:
[data/zstd-level12-fast-20261116](data/zstd-level12-fast-20261116/README.md).

The migration re-froze the level-1/2 golden wire, updated the default-level
FastCover auto wires and score expectations, narrowed the coordinator overlap
to level 3, and added a cross-surface test asserting alloc/append/into-slice/
bound/reusable/dictionary level-1/2 wires are byte-identical. `test-zstd`
passes 1431/1431; `run-zstd-encode-bench-gate` records the new level-1 JSON
694-byte and multiblock 34,228-byte ceilings. The level-3+ ladder still spawns
per-call threads, which remains a separate architecture-rule violation.

## Zstd level ladder goes serial (2026-11-17)

The level 3+ adaptive ladder spawned up to three `std.Thread` workers per
encode call to evaluate full-frame block-size candidates. That is the per-call
thread creation the architecture rules classify as a P0 problem. The
candidates are now evaluated serially in the same deterministic order with the
same candidate set and arbitration; the `LockedAllocator` wrapper and the
level-3 coordinator overlap are gone, and single-threaded targets use the same
richer arbitration instead of the legacy simple fallback.

A/B on twelve 128 KiB Silesia files at level 3 produced byte-identical
`vort_bytes` on every file. Repeated 3-iteration/7-round runs on xml, dickens
and samba measured serial/parallel medians of 6.645/6.659, 3.771/3.817 and
5.832/5.814 MiB/s (0.998x, 0.988x, 1.003x), so removing the workers cost no
measurable throughput. `test-zstd` passes 1430/1430,
`run-zstd-encode-bench-gate` passes, and `check-wasm` completes 64/64 steps.
The mixed-candidate block search at level 9+ and the parallel seekable encoder
still spawn per call; the mixed search is the next thread-rule target.

Level 9 on the same 128 KiB `dickens` prefix measures **0.0049 MiB/s**
(25.7 s per encode), which is a separate quality-ladder cliff rather than a
threading problem.

## Zstd wide-block mixed search removed (2026-11-17)

Profiling level 9 on the 128 KiB `dickens` prefix attributed **84.8%** of
cycles to the recursive mixed duplicate/repeated lookahead
(`searchMixedCandidateLookaheadPlans` -> `candidatesAt` ->
`findBestDuplicateMatchIn` -> `singleBestSequencePayloadLen`). It took
**25.6 s** per encode and returned the same **50,325-byte** frame as level 3.

The per-call mixed worker is removed. The mixed search now runs only for
low-alphabet structured blocks (`preferSerialMixedSearch`), serially, through
the existing decisive-beam/dominance arbitration; wide-alphabet blocks skip it
and use the checked non-mixed selector. Level 9 drops to **0.508 MiB/s**
(246 ms) with the same frame, levels 4-22 drop from about 25.6 s to about
0.25 s, and twelve 128 KiB Silesia prefixes keep their level-3 sizes. The
locked encode gate is unchanged (JSON level 9 640 B, multiblock 27,363 B,
binary 8,607 B, level3_tradeoff 2,037 B). Evidence:
[data/zstd-mixed-search-20261117](data/zstd-mixed-search-20261117/README.md).

The explicit parallel seekable encoder remains the only thread-spawning
boundary in the zstd encode path.

## Zstd multi-duplicate cap (2026-11-17)

The multi-duplicate planner rescanned each block suffix for up to 128
global-best matches. On the 128 KiB `dickens` prefix the unindexed variant
took **194 ms**, scanned **47.8 MB** of literal histograms, and produced a
75,000-byte candidate that lost to the 50,325-byte beam. After the mixed-search
removal, the indexed variant used by the adaptive split candidates still
consumed about **31%** of level-9 time. Removing the planner entirely
regressed `sao` by about 10% because its early matches tighten the DP upper
bound.

Production now stops after **two** matches for every block, indexed or not;
diagnostic entry points still request the full 128-match budget. Twelve
128 KiB Silesia files keep byte-identical level-9 frames (SHA-256) and gain
about **2.8x** geometric-mean throughput, with 4.1-16.2x on the slow rows and
no control below 1.0x. The locked encode gate is unchanged. Evidence:
[data/zstd-multi-cap-20261117](data/zstd-multi-cap-20261117/README.md).

A follow-up stage screen on the same 128 KiB `dickens` block measured
double_fast 63,405 / greedy 52,591 / lazy 50,808 / optimal **50,316** /
repeated 75,532 bytes. The optimal DP supplies the winning block (50,316 plus
the 9-byte frame header equals the 50,325-byte frame), so its 16 ms is
required; the next level-9 work is DP-internal cost rather than another
candidate skip.

## Zstd optimal candidate budget 7 (2026-11-17)

The optimal DP used eight useful-chain candidates per position. Dropping to
**seven** enables the existing four-byte optimal route for 64-128 KiB blocks
and removes one candidate from every other optimal search. Twelve 128 KiB
Silesia files at level 9 gain **13.4% geometric-mean throughput**; aggregate
size is **+101 bytes** (net), with mozilla and osdb improving and the largest
per-file regression webster +84 bytes (+0.20%). Repeated dickens/xml/reymont
medians confirm 1.17x/1.36x/1.26x. The locked encode gate is unchanged.
Evidence:
[data/zstd-optimal-cand7-20261117](data/zstd-optimal-cand7-20261117/README.md).

A reversible level-9 screen skipped the lazy candidate at high budgets:
10/12 Silesia sizes were unchanged but `xml` grew **+6.0%** (9,712 -> 10,299).
Skipping greedy left 11/12 unchanged but `mr` grew **+3.3%** (32,676 ->
33,766). Both candidates are genuine winners on the retained corpus, so the
level-9 candidate set stays. The next level-9 lever is cheaper candidate
evaluation/emission, not candidate removal.

## Zstd length-only second multi-duplicate match (2026-11-17)

The production two-match multi-duplicate bound still priced every candidate
with a full Huffman literal plan. The second match never feeds emission, so a
length-only indexed finder now ranks it by length/offset only; the first match
keeps exact pricing for the single-duplicate candidate. Twelve 128 KiB
Silesia files keep identical level-9 sizes, and repeated medians measure
dickens 1.15x and samba 1.56x with the other rows neutral (about 6.4%
geometric mean, no control below 0.998x). The locked encode gate is unchanged.
Evidence:
[data/zstd-length-only-bound-20261117](data/zstd-length-only-bound-20261117/README.md).

After the length-only change, the level-9 profile on the 128 KiB `dickens`
prefix is dominated by the parser families: `findBestHashMatchWithLayout`
12.5%, four-byte optimal 11.9%, generic optimal 4.2%; then memset 5.1%,
large-sequence table cost 4.0%, multi-duplicate 3.5% and long Huffman stream
3.3%. Candidate-removal work is exhausted; the next encode lever is
parser-level, otherwise the decode gaps (zstd about 20%, Deflate about 6%)
are the remaining structural frontier.

## Zstd decode baseline and prefetch screen (2026-11-17)

Fresh matched measurement on libzstd 1.6.0 level-9 wires (one-shot, 20
iterations, ReleaseFast): Vort/libzstd throughput is dickens 0.719, x-ray
0.805, mozilla 0.732, xml 0.711, sao 0.816 and mr 0.741. The decode profile
is **61%** in `tryDecodeAllFseSplitDenseHuffmanSequencesNative`; the hottest
instruction is the 16-byte short-match copy load (22.5%), followed by its
store (2.1%).

A match-source prefetch before the literal copy improved dickens by about
2.3% (917 -> 939 MiB/s) but left xml, mr and sao at 0-0.9%; the twelve-file
geometric mean is about 0.7%, below the 3% bar, so it was reverted. The
remaining gap is the copy chain's dependency/cache latency, not entropy or
FSE setup.

A match-first copy reorder in the dense executor was attempted to remove the
short-match load's dependency on the literal store. The literal wildcopy
writes up to 16 bytes past the logical run, so the following match copy must
overwrite that tail; reordering clobbered the match (`SizeMismatch`), and an
exact literal-copy variant faulted. Reverted. The copy-chain work needs a
dedicated exact-copy path with its own tests before it can be measured.

The match-first reorder was retried with an exact 0-16-byte literal copy (no
wildcopy tail). It is correct but slower: `dickens` fell from 917 to 858 MiB/s
(-6.4%) because the literal copy's work was overlapping the match-source
fetch. Reverted; the literal-first order stays.

## Deflate decode profile (2026-11-17)

On the `dickens` level-6 wire, Vort decodes at 783.58 MiB/s versus libdeflate
1.10 at 833.70 (0.940). The profile is **38.6%** in
`decodeSemanticDynamicBlockIntoBufferedReaderNonOverlapInline` plus 2.4% in
`linear_entry.aligned`. The hottest instructions are Huffman table loads
(5.8/3.7/3.3/3.2/3.1%), the 16-byte match copy (6.5% load plus 3.4% store),
and an **8.2% stack spill** of a loop-carried value. The spill points at
register pressure rather than a missing token phase; a two-phase token buffer
would add a write and a read per sequence and is not the next lever. Reducing
the live set or splitting the loop is the concrete next experiment.

The 8.2% spill maps to the literal lookup entry: a hot loop value is stored to
`-0x50(%rbp)` on every literal, and the literal path reloads a table base from
`-0x70(%rbp)` immediately after. The next experiment is therefore to reduce
the live table-base/bit-reservoir set in the semantic loop; adding a token
phase would not address this spill.

The literal path is a four-entry unrolled chain; the spilled value is a
loop-invariant base pointer freed for the chain and then reloaded as the
literal table base. The next experiment is to shrink that chain's register
demand or reload the invariant pointers from `reader` instead of keeping them
live. Compiler spill elimination is otherwise not source-controllable.

Reloading `reader.input` instead of keeping a local slice across the loop
changed nothing (786.6 versus 784.1 MiB/s, +0.3%, within noise). The spilled
base is not the input slice; source-level register-pressure work is closed for
this loop.

## Zstd level-1 fast encode profile (2026-11-17)

A standalone encode probe removes the benchmark's SHA-256 provenance noise.
Level-1 encode on the 128 KiB `dickens` prefix is **33.7%** in
`emitFastSequenceRecordCandidate` (double-fast parser plus token
materialization), 7.9% block emission, 5.7% offset-code choice, 5.0% bit
writer, 4.3% memcpy, 4.2% sequence plan, 3.9% `sequenceCodeForValue`, 3.8%
literal section, 3.7% transition fill and 3.7% long Huffman stream. The fast
parser is the next parser-level target; block/entropy emission is already
spread thin.

The level-1 double-fast parser was inspected for removable duplicate work.
The only repeated rep probe occurs when the previous match consumed
`max_match`, so it is not the common path; the remaining loop is already the
two-table double-fast design with lazy and repcode checks. Further level-1
gains need a parser redesign, not a local edit.

A 12-bit long hash (4,096 entries) in the level-1 double-fast parser reduced
total Silesia size by **2.9%** (osdb -14.6%, webster -3.0%, dickens -2.5%)
at a 1.3% single-run speed gain, but repeated samba/x-ray medians fell 2.2%/
1.8% and the worst row sat at the 0.98 control floor. A 13-bit table gave
larger size wins (osdb -21.7%, dickens -5.6%) but 0.945-0.98x on several
rows. The 11-bit table stays under the speed-first level-1 policy; the
size/speed tradeoff is recorded for a future level-specific policy.

A 10-bit short hash likewise cut about 20 KB over the twelve files but cost
8.6% geometric-mean speed (dickens 0.785x, sao 0.854x); the 8-bit short table
stays. The 8-bit short/11-bit long pair is the measured speed-first point.

Reserving `input.len / 16` records instead of `/64` looked 1.9% faster in the
single-run matrix, but repeated medians were 0.975-0.987x on dickens, mozilla,
mr and webster. The actual match counts are 9,185 (dickens) and 14,712 (mr),
so the list does grow, but the eager 65 KiB reserve costs more than the copies
it avoids. The smaller lazy reserve stays.

Functional-surface check: Deflate zlib preset dictionaries (FDICT/DICTID),
Zstd dictionaries/prefixes and Brotli format controls are already exposed
across one-shot, reusable and streaming APIs. No cheap functional gap remains;
the next work is performance.

## Zstd single-table parser prototype (2026-11-17)

An isolated single-table double-fast prototype (8-byte hash only, no short
table, rep probes or lazy lookahead) parsed the twelve 128 KiB Silesia files
**1.86x** faster in geometric mean, but emitted **7.6%** more bytes in total:
dickens +4.9%, mozilla +24.2%, nci +19.0%, reymont +16.4%; only mr improved
(-0.7%). Not adopted as-is. It sets the speed ceiling for a level-1 parser
redesign; the next variant should keep repcode probes (cheap offset wins)
while dropping the short table/lazy path.

A hybrid single-table parser with a rep0 probe parsed **1.57x** faster but
still emitted **6.2%** more bytes (mozilla +15.3%, reymont +14.4%, nci
+12.2%). The rep probe recovered only 1.4% of the pure prototype's 7.6% size
cost for a 15% speed loss; the gap is dominated by the missing short table/
lazy path, not repcodes. The next variant should keep the short table and
drop only the lazy lookahead, or find a cheaper lazy.

Dropping only the lazy lookahead raised size by 0.31% but slowed the parser
to **0.964x** geometric mean (x-ray 0.940, webster 0.945, xml 0.946): the
lookahead advances past short matches and saves loop iterations, so it is
both a ratio and a speed win. Keep it. The single-table size gap is therefore
dominated by the 4-byte short table, not lazy.

Dropping only the short-table probe gave **1.52x** geometric-mean speed for
**+4.35%** total size (ooffice +8.4%, reymont +12.3%, mozilla +10.3%;
nci/xml/mr neutral or better). Together with the lazy result, the production
parser's short table is the ratio backbone and its removal is the main speed
lever. A product-level "fastest" variant could use it, but level 1 stays at
the current balance.

The parser-redesign screen is consolidated in
[data/zstd-fast-parser-redesign-20261117](data/zstd-fast-parser-redesign-20261117/README.md):
drop-short 1.52x/+4.35%, single-table 1.86x/+7.6%, single-table+rep0
1.57x/+6.2%, drop-lazy 0.964x/+0.31%. Level 1 keeps its current balance; a
product-level fastest variant remains a policy decision.

## Brotli planned encode baseline (2026-11-17)

On the 128 KiB `dickens` prefix: planned q9 emits 48,833 bytes at
**0.49 MiB/s** versus libbrotli 47,947 at 9.48 (1.85% larger, **19x
slower**); planned q11 emits 43,956 at **0.07 MiB/s** versus 42,949 at 0.89
(2.34% larger, 13x slower). The legacy fast path is 21.8 MiB/s at 53,052
bytes (2.3x faster than libbrotli q9, 10.6% larger). The planned profile is
command-plan emission (26%), match finding (8.7%), distance/length coding
(~18%); no duplicate-wire waste is visible at this level. The quality
ladder's speed is the next Brotli target.

The planned-q9 call tree makes the waste concrete: `encodeLazyCommandPlan`
77.8%, final command candidate group 77.7%, command-plan allocation 59.9%,
entropy-split candidate 58.0%, entropy-split wire candidate 51.3%,
command-plan writers 32.7% (standard 27.0%, adaptive 26.9%), preferred
command plan 19.7%. The dominant cost is full-wire materialization for
entropy-split candidates, matching the roadmap's q8+ candidate-graph P0
item. The next experiment is a count-only candidate writer that emits the
winner exactly once.

The counting infrastructure already exists: `counting_writer.Writer`,
`prepareCommandPlanWithOptionsRecorded` (counts a command plan without
writing bytes), and `context_candidate_group.encodePreparedPrimary`. The
remaining full-wire materialization is in the alternate literal-context/
plain-literal loops of
`encodeEntropySplitWireCandidateInternalAllocRecorded` and the
`adaptive_contexts` loop of `encodePreferredCommandPlanAllocRecorded`. The
next change should measure those candidates with the counting writer and emit
only the winner.

The prepared/count path requires `options.prepared_common`, which the
entropy-split alternate-context loop does not currently build. The literal
context only changes the literal tree, so one command/distance common model
can be shared across the alternate contexts. The implementation must build
that shared model once, prepare/measure each alternate with
`prepareCommandPlanWithOptionsRecorded`, and emit only the winner with
`emitPreparedCommandPlanWithOptionsRecorded` (which checks the emitted size
against `state.wire_len`).

Implemented counted adaptive-context selection with the existing counting
writer: the wire stayed identical (48,833 bytes) but speed moved only
0.49 -> 0.50 MiB/s (about 2%, within noise). The writer cost is entropy
planning, not byte storage, so counting alone does not help. Reverted.

The planned-q9 profile is distributed: match finder 8.9%, context group
8.9%, default-window far candidate 8.0%, context core 6.1%, distance encode
6.1%, wide-distance writer 5.0%, literal-context proposals 4.9%, distance
parameter search 4.8%, length code 4.4%, command distance 4.4%. Disabling
`distance-parameter-search` or `adaptive-distance-split` through the bench
flags did not change the dickens q9 wire or speed, so those candidates are
not the active cost on this input. A product-level candidate-reduction
policy is needed before further Brotli q9 speed work.

Skipping `considerDefaultWindowFarCandidate` on the 128 KiB Silesia files
kept every wire identical while raising planned q9 speed 1.12-1.31x
(dickens 0.49 -> 0.55, xml 2.61 -> 3.42, mozilla 1.13 -> 1.41, webster
0.96 -> 1.18; sao neutral). A simple `max_backward_distance <= default
window` guard does not trigger: the ratio stream's default window is 16 bits
while the far window is 17 bits for these inputs. A safe skip needs a cheap
far-match pre-screen (the candidate exists for beyond-window copies), so the
guard was reverted.

The far-candidate skip is now a shipped policy gate rather than a full skip.
Instrumentation showed the near-plan proposal finds no far copy in the small
literal runs of the 128 KiB rows (literal bytes 3.0-7.9 KB), while the
all-literal alternate drops every near match. That alternate starts 5.7-39.4
KB behind the incumbent and its far copies recover only 0.2-13.3 KB, so it
cannot win. The 16-to-17-bit window change is not the cause: the same
all-literal plan is 59,441 bytes at window 16 and 59,442 at window 17
(dickens), and the full near-plan stream is 48,833/48,830 under explicit
`--window-bits 16/17`. The default-window selector
now runs the all-literal alternate only when literals are at least half the
input, which is the same `large_literal_share` policy already used for
>1 MiB blocks. Repeated medians over the six 128 KiB files improved
**1.167x** geometric mean (dickens 1.100x, xml 1.309x, mozilla 1.248x,
mr 1.130x, sao 1.000x, webster 1.242x) with identical wire SHA-256. Wire
identity also held on 12/12 Silesia 128 KiB prefixes, 6/6 1 MiB prefixes,
and 4/4 synthetic far-copy inputs (400 KiB, 1 MiB, 664 KiB mixed, 2 MiB).
Evidence: [data/br-far-candidate-gate-20261117](data/br-far-candidate-gate-20261117/README.md).

The next q9 candidate-reduction step removes two full-wire entropy candidates
that never won. Per-candidate tracing on the 12 Silesia 128 KiB prefixes shows
the legacy split wire and the standalone adaptive command wire never win:
combined adaptive wins on dickens/mr/samba/mozilla/x-ray, adaptive distance
wins on the other rows, and the standalone adaptive command candidate is
subsumed by the combined command+distance candidate. `src/br.zig` now skips
the legacy split wire when both adaptive symbol plans exist, and skips the
standalone adaptive command wire when an adaptive distance plan exists.
Repeated medians over the six 128 KiB files improved **1.259x** geometric
mean (dickens 1.600x, xml 1.207x, mozilla 1.177x, mr 1.218x, sao 1.211x,
webster 1.186x) with identical wire SHA-256 on 12/12 128 KiB, 6/6 1 MiB,
3/3 4 MiB, and 4/4 synthetic far-copy inputs. Combined with the far-candidate
gate, planned q9 is 1.47x geometric mean faster than the 2026-11-17 baseline.
Evidence: [data/br-entropy-split-skip-20261117](data/br-entropy-split-skip-20261117/README.md).

A third q9 candidate-reduction step removes the alternate literal-context
re-encodes inside the combined command+distance split writer. That writer
re-encoded the command plan once per losing baseline context; on the 12
Silesia 128 KiB prefixes those alternates won **0/1096** times (and the
plain-literal variant never appeared). `src/br.zig` now skips the alternate
loop only for the combined candidate (`adaptive_command_split != null and
adaptive_distance_split != null`). The standalone adaptive distance candidate
keeps its alternates because the counted oracle must evaluate the same set;
the first, broader condition failed the
`br counted adaptive distance context contracts` fixture, where an alternate
context wins by 19.7 KB. Repeated medians over the six 128 KiB files improved
**1.164x** geometric mean (dickens 1.273x, xml 1.162x, mozilla 1.133x,
mr 1.142x, sao 1.174x, webster 1.107x) with identical wire SHA-256 on 12/12
128 KiB, 6/6 1 MiB, 3/3 4 MiB, 4/4 synthetic far-copy, and 9/9 built-in bench
cases. Planned q9 is now about 1.70x geometric mean faster than the
2026-11-17 baseline.
Evidence: [data/br-alternate-context-skip-20261117](data/br-alternate-context-skip-20261117/README.md).

A fourth q9 candidate-reduction step gates the distance-parameter search on
its own estimated saving. The selector already computes the estimated bits of
the preferred parameter set; on blocks of at least 64 KiB, a saving below the
64-byte arbitration margin (512 bits) never produced a winning wire on the
measured corpus. Instrumentation showed the separation clearly: dickens/xml/
webster estimated 46/1/14 bits and changed the wire by 0 bytes, while
mozilla/mr/sao estimated 3,350/9,808/25,326 bits and saved 150/501/3,095
bytes. `src/br.zig` now returns no alternative when the estimated saving is
below 512 bits on blocks >= 64 KiB; smaller inputs keep the search because a
few bytes still matter there (the built-in 83-byte `source` case otherwise
regressed by one byte). Repeated medians over the six 128 KiB files improved
**1.128x** geometric mean (dickens 1.321x, xml 1.262x, mozilla 0.995x,
mr 1.000x, sao 1.000x, webster 1.245x) with identical wire SHA-256 on 12/12
128 KiB, 6/6 1 MiB, 3/3 4 MiB, 4/4 synthetic far-copy, and 9/9 built-in bench
cases. Planned q9 is now about 1.93x geometric mean faster than the
2026-11-17 baseline.
Evidence: [data/br-distance-parameter-gate-20261117](data/br-distance-parameter-gate-20261117/README.md).

A fifth q9 step extends the distance-parameter gate to the whole search
candidate. Tracing `best_before` against the split-aware search wire on the
12 Silesia 128 KiB prefixes showed the search candidate never strictly won
when the estimated saving was below the gate: dickens 48,833 vs 48,834,
xml 9,123 vs 9,167, webster 40,534 vs 40,541, ooffice 64,646 vs 64,699,
reymont and samba tied, while mozilla/mr/sao/nci/osdb/x-ray improved and all
had an alternative parameter set. `src/br.zig` now computes
`chooseDistanceParameterAlternativeAlloc` once at the q9 call site when the
block is at least 64 KiB: a null result skips both the parameter-only and
split-aware candidates, and a non-null result is shared by both families
through the new `encodeCommandPlanWithDistanceParametersAllocRecorded`
helper. Smaller inputs keep the original candidate path because the frozen
legacy-wire test has a sample where the forced-recent baseline is the unique
winner; skipping the whole candidate there changed a 57-byte wire. A second
attempt also returned null from the split-aware helper when no alternative
existed; that skipped the baseline on small inputs and changed the UTF-8
shift trainer's baseline_frame_bytes from 3512 to 3513. The helper now still
returns the baseline when no alternative exists; only the large-block q9 call
site skips the whole call. A first
attempt that recomputed the parameters at the call site duplicated the
frequency pass and regressed mozilla/mr to 0.95-0.97x; sharing the choice
restored them to 1.01-1.03x. Repeated medians over the six 128 KiB files
improved **1.236x** geometric mean (dickens 1.473x, xml 1.494x, mozilla
1.032x, mr 1.033x, sao 1.012x, webster 1.497x) with identical wire SHA-256
on 12/12 128 KiB, 6/6 1 MiB, 3/3 4 MiB, 4/4 synthetic far-copy, and 9/9
built-in bench cases. Planned q9 is now about 2.39x geometric mean faster
than the 2026-11-17 baseline.
Evidence: [data/br-distance-search-shared-20261117](data/br-distance-search-shared-20261117/README.md).

A wire-preserving attempt to always count the primary context (instead of
materializing it when every proposal equals the primary) gave no measurable
gain: six-file planned q9 single-run ratios were 0.995-1.008x with identical
wires. The counted pass still pays the entropy planning, so skipping the
primary wire emission is not the bottleneck; the change also invalidated the
context primary count contract. Reverted without a code change.

Carrying the lazy lookahead result into the next hash-lazy iteration (to
avoid re-searching the same chain) looked like 1.000-1.040x in a single
six-file run with identical wires, but repeated medians were only
**1.007x** geometric mean (dickens 1.000x, xml 1.011x, mozilla 1.000x,
mr 1.016x, sao 1.012x, webster 1.003x). The duplicate search is not a
material cost after the first match advances the chain. Reverted without a
code change; the q9 match finder needs a structural change, not this dedup.

A new `distance_parameters` scope around the q9 search block shows the
selection scan itself costs **7.4 ms** on dickens (14% of planned q9) even
when both search candidates are skipped. The scan walks 18k commands,
dedups/sorts the semantic distances (already a radix sort for large inputs),
and scores all 64 RFC 7932 parameter shapes with exact Huffman trees. The
candidate gate removed the wire materialization but not this planning pass.
The next step is a coarse-shape or sampled estimate that decides whether the
full 64-shape search can pay; the exact search should remain the selector
whenever the coarse estimate passes.

The 7.4 ms planning scan now has a coarse-shape gate. Twelve-file tracing
showed the six winning rows select shapes (3,4), (1,1), (3,15), (3,15),
(2,8), (1,14), while the six skipped rows estimate 1-176 bits. A nine-shape
subset `(0,1) (1,1) (1,8) (1,14) (2,4) (2,8) (3,4) (3,8) (3,15)` covers every
winner. `chooseDistanceParameterAlternativeAlloc` now scores that subset
first on blocks >= 64 KiB; if its best cannot clear the 512-bit gate, the
exact 64-shape search is skipped, otherwise the exact search still selects
the parameters. The previously dead `sortDistanceFrequencies` radix sort is
wired into the same path (same ascending order, wire-identical). Repeated
medians over the six 128 KiB files improved **1.047x** geometric mean
(dickens 1.106x, xml 1.077x, mozilla 0.995x, mr 1.000x, sao 1.000x, webster
1.111x) with identical wire SHA-256 on 12/12 128 KiB, 6/6 1 MiB, 3/3 4 MiB,
4/4 synthetic far-copy, and 9/9 built-in bench cases. Planned q9 is now about
2.49x geometric mean faster than the 2026-11-17 baseline.
Evidence: [data/br-distance-coarse-gate-20261117](data/br-distance-coarse-gate-20261117/README.md).

Planned q10/q11 now measure 1.28 MiB/s / 48,747 B (ref 2.22 / 44,029)
and 0.10 MiB/s / 43,956 B (ref 0.89 / 42,949) on the 128 KiB dickens
prefix. The q11 profile is dominated by untraced `other` (612.8 ms): the
first optimal parse is traced at 181.8 ms, but the entropy-modeled second
and third parses are not. Candidate tracing shows the first parse's wire
wins on mr (30,059 vs modeled 30,345) and x-ray (77,220 vs 81,335), while
the modeled wire wins on the other ten files. The third parse wins by only
7-103 bytes on ten files and loses on mr/x-ray, yet costs roughly a quarter
of q11. The next q11 decision is whether to gate the third parse on a model
estimate or a documented small ratio budget; skipping the first parse's wire
unconditionally is not safe.

The q11 refinement trace closes the pruning question. The third parse
improves the incumbent on 8/12 files by 7-103 bytes; the repcode-bonus
fourth parse wins on xml (+163 B), nci (+117 B), and samba (+136 B) but
loses on the other nine. Neither refinement has a cheap win predictor:
the bonus wins on files where the third parse also improved and on files
where it did not. Dropping the third parse would cost up to 103 B and
dropping the bonus up to 163 B (1.9% on xml), while q11 users select the
level for ratio. The refinements stay; the remaining q11 lever is the
optimal parser itself, not candidate pruning.

The q10 ratio gap has a concrete cause: on 128 KiB blocks the q10 optimal
parser is capped at 64 KiB, so the lazy path runs without the static
dictionary. The dickens q10 wire has zero static-dictionary copies, while
libbrotli q10 finds 2,406 copies / 24,190 bytes; q11's optimal path finds
3,021 / 29,434 and is only 2.34% behind its reference. A post-hoc
`mixStaticDictionaryWithCacheProbeLimitAlloc` candidate on the lazy q10
commands was tested and rejected: 48,747 -> 48,662 bytes (only -85 B,
0.17%) for 1.28 -> 0.93 MiB/s (27% slower). The dictionary must be
integrated into the parse (or a bounded optimal parse enabled above
64 KiB), not mixed into the finished lazy plan.

The bounded q10 large-block optimal parse was measured before deciding on
a policy change. With the q10 schedule budget (192/128) dickens moves from
48,747 to 44,852 bytes (-8.0%, now 1.9% behind libbrotli) but slows from
1.28 to 0.37 MiB/s. Reducing the budget to 96/32/192 gives 45,089 bytes at
0.38 MiB/s: the chain/candidate budget is not the cost, the optimal DP
itself is. Across the twelve 128 KiB files the optimal q10 runs at
0.26-1.18 MiB/s and lands 2.4-17.1% above its reference. The ratio win is
real but the 3.5-6x slowdown is not a free product change; the next lever
is optimal-parser speed, not a q10 tier policy switch. Reverted.

A new `run-br-optimal-search-probe` tool isolates one Brotli optimal
parse. At the q11 budget (chain 512 / candidates 256 / nice 258) on the
128 KiB dickens prefix it takes **42.0 ms**: index 0.5 ms, search 41.1 ms,
reconstruct 0.3 ms. The search walks 8.06M chain nodes for 131k positions
(~61 per position): 5.13M prefix rejections, 2.58M bound rejections, only
270k `matchLength` calls. The q11 stage total of 181.8 ms is therefore
about four parses, not one. The probe also documents that the optimal
parser window is capped at `lz77.default_window_len` (32 KiB), so the
32-64 KiB match range is unavailable to q10/q11.

The optimal parser's compact index already used a four-byte hash, but the
non-compact index used by the entropy-modeled parses still used a
three-byte hash. With `min_match = 4`, three-byte-only chain candidates can
never produce an accepted match; they only consume the chain budget.
`HashIndex.buildWithAnchor` now lets the optimal parser build the
non-compact index with `.four` when `minMatch(options) >= 4`; three-byte
parsers keep `.three`. On the 128 KiB dickens q11 prefix the three-round
median moved from 43,956 B @ 0.110 MiB/s to 43,953 B @ 0.120 MiB/s
(**+9.1% speed, -3 B**). q9/q10 lazy wires are unchanged and the compact
optimal path was already four-byte. `zig build test` passes 5666/5668
(2 skipped) and `zig build test-br` passes 1619/1620 (1 skipped).
Evidence: [data/br-optimal-index-anchor-20261117](data/br-optimal-index-anchor-20261117/README.md).

The >64 KiB optimal parser's compact index was still a three-byte hash;
the loop's four-byte prefix check then rejected 5.07M true three-byte
candidates, 63% of all chain nodes. Building the compact index with
`.four` when `minMatch(options) >= 4` drops one parse from 44.6 to
**19.3 ms** (chain nodes 8.06M -> 3.05M, prefix rejections 5.13M ->
114k, same matchLength work). q11 end-to-end moves **1.0195x** with -2
bytes; the parse-level 2.3x is the cost lever for a future q10
large-block optimal policy. The <=64 KiB eligible path already used the
four-chain and is unchanged.
Evidence: [data/br-optimal-compact-anchor-20261117](data/br-optimal-compact-anchor-20261117/README.md).

A four-byte compact index for >64 KiB optimal parses looked strong in the
probe (one parse 44.6 -> 19.3 ms, chain nodes 8.06M -> 3.05M, prefix
rejections 5.13M -> 114k) and improved the q11 wire by 2 bytes, but it
broke `lz77.test.ordinal optimal index preserves original plan and
ownership`: the ordinal four-chain is defined as a filtered view of the
original three-byte chain, so changing the compact hash changes the
reference plan. The change is reverted; the contract is explicit. The
probe histogram (5.07M of 5.13M prefix rejections were true three-byte
matches) stays in the tool for future parser work.

Trace scopes around the entropy-modeled optimal parses close the previous
q11 `other` blind spot. On the 128 KiB dickens prefix the four parses cost
**674.7 ms** (the first fixed parse 42 ms, the three modeled parses about
211 ms each), while `other` drops from 612.8 to 22.8 ms. The modeled parse
is roughly 5x the fixed parse because the prefix bound is disabled for
non-monotonic model costs. Enabling the bound plus the compact four-chain
for the modeled path was slower (q11 ns +8%, wire +3 B) and reverted: the
full per-candidate cost comparison outweighs the bound savings on the
four-byte chain.

Enabling the prefix bound for the modeled parse alone (keeping the
non-compact four-byte chain, no indexed switch) also made q11 8% slower
(1,149,721,651 ns vs 1,062,506,030) and +3 bytes. The bound rejects few
modeled candidates while adding a full cost comparison per candidate.
The modeled parse's ~211 ms is dominated by roughly 3M `matchLength` calls
on the four-byte chain, versus 270k after the fixed parse's bound. The
next step is a profiled modeled parse to locate the exact cost, not
another bound variant.

The optimal-search probe now supports a modeled parse with a uniform cost
model (`optimalPlanAllocWithCostModelProfiled`). On the 128 KiB dickens
prefix it takes **25.4 ms** (3.05M chain nodes, 2.86M matchLength calls,
396k length choices), while the fixed parse with the three-byte compact
index takes 42 ms. The real q11 modeled parse is ~211 ms, so the parser
machinery itself is not the gap; the entropy model's actual cost values or
the q11 context must explain it. A profiled parse with the real model is
the next step.

The q11 optimal parse's real hotspot is the static dictionary probe: every
position calls `findLongest`, and q11 runs four parses over the same input.
Per-parse trace: 182.2 / 165.8 / 166.8 / 166.1 ms; the isolated probe
without the dictionary provider is 25-42 ms. Precomputing the match per
position once and reusing it across the four parses moves q11 on dickens
from 2,166,505,689 ns to 1,303,374,958 ns (**1.662x**) with an identical
43,953-byte wire. The memory cost is
`input.len * @sizeOf(?lz77.DictionaryMatch)`, about 1.5 MB for 128 KiB,
allocated once per q10/q11 optimal candidate.
Evidence: [data/br-precomputed-dictionary-probe-20261117](data/br-precomputed-dictionary-probe-20261117/README.md).

After the precomputed dictionary probe, q11's optimal parse drops from
674.7 to **103.6 ms** (first 39.1 ms, modeled 21.4/21.7/21.4 ms). The
dictionary precompute itself is now the ~140 ms `other` block. The
remaining q11 time is split 188.3 ms, wire 116.2 ms, and evaluate
36.7 ms. The next levers are the static-dictionary `findLongest` pass and
the per-plan split/wire candidate graph.

Extending the static-dictionary suffix pre-check from the whole-word
transforms to the omit/skip transforms was wire-identical but neutral:
q11 measured 670,343,918 ns versus the 651,687,479 ns median (within
noise, slightly slower). The extra per-transform `kept`/suffix work
offsets the pruned base-word comparisons. Reverted.

Preloading the transform metadata into the compile-time prefix groups
(avoiding the runtime `transformMetadata` lookup in the hot loop) was
wire-identical and measured 647,490,621 ns versus the 651,687,479 ns
median: within noise. The compiler already folds the lookup, so the
restructure is not retained.

The static-dictionary matcher's 121 RFC transforms split into 103
whole-word transforms (kind 0/10/11) and 18 omit/skip transforms. The
old loop re-compared the complete base word for every suffix variant, so
one candidate word paid up to 103 identical case-normalized comparisons.
Grouping the compile-time table by `(prefix_len, case)` into whole and
omit lists and hoisting the base-word comparison to once per candidate
moves q11 on 128 KiB dickens from 1,308,173,945 to 1,214,380,116 ns
(**1.0772x**) with an identical 43,953-byte wire; xml is 1.0150x and
samba 1.0307x, **1.0406x** geometric mean, all wires byte-identical.
q9/q10 controls are 0.36% / 0.15% slower, within noise. Whole transforms
always retain at least four bytes, so the non-advancing filter and the
input-length bound collapse into the suffix check; the best-match order
is unchanged because the `(output_len, address)` selection is a total
order. A comptime `prefix_len` specialization measured neutral and was
not retained.
Evidence: [data/br-static-dictionary-whole-group-20261117](data/br-static-dictionary-whole-group-20261117/README.md).

The joint literal-context planner rebuilt a 1.3 KiB sparse view (symbols plus
frequency copies) inside every tree-count/seed/iteration assignment pass: about
35 thousand rescans of all 256 histogram bins per planner call. Building one
`SparseView` per populated context after collection and reading frequencies
from the histogram makes the assignment bit-identical and moves q11 on 128 KiB
dickens from 1,206,015,198 to 1,017,334,905 ns (**1.185x**), samba q11
1.203x, and dickens q10 1.243x (**1.210x** geometric mean), with all twelve
corpus/quality wires byte-identical. q9 stays neutral. The extra scratch is
`context_count * sizeof(SparseView)` and is charged to the existing joint
planner budget.
Evidence: [data/br-joint-sparse-view-20261117](data/br-joint-sparse-view-20261117/README.md).

All 18 RFC omit/skip transforms have an empty prefix and no case transform, so
they only compete at the prefix-zero probe. Flattening them into omit-last and
omit-first metadata tables lets one common-prefix scan replace nine separate
base comparisons for the omit-last family and removes the per-transform
metadata load, empty-prefix check and case switch. q11 on 128 KiB dickens moves
from 1,010,341,333 to 890,502,371 ns (**1.1346x**); webster 1.0698x, samba
1.0438x, xml 1.0274x, **1.0686x** geometric mean, with all twelve
corpus/quality wires byte-identical. q9/q10 are unchanged. The general
`transformedWordMatches` path remains as the complete-index oracle.
Evidence: [data/br-dictionary-omit-flat-20261117](data/br-dictionary-omit-flat-20261117/README.md).

The joint literal-context clustering loop re-aggregated every populated
context on every assignment iteration. Recording `(context, from, to)` moves
and applying only subtract/add for the contexts that changed tree keeps the
counts exact (disjoint sums in the u32-bounded path) and reproduces a full
re-aggregation bit-for-bit; larger populations keep the checked full merge.
q10/q11 rows move 1.0025x-1.0362x, **1.0169x** geometric mean over six
128 KiB corpus/quality rows, with all twelve wires byte-identical. This is
below the default 3% merge bar, retained as an exact work reduction with no
regression; samba weak rows gain 3.3-3.6%.
Evidence: [data/br-joint-incremental-aggregate-20261117](data/br-joint-incremental-aggregate-20261117/README.md).

Current-source q11 encode position (128 KiB Silesia prefixes, libbrotli 1.0.9)
is now recorded across all twelve files. Default-reference totals are
501,109 versus 474,794 bytes (**1.0554x**) with 0.160x-0.516x reference/Vort
speed; matched `lgwin 16` generic rows are 1.020x (dickens), 1.054x (samba),
1.130x (xml) and 1.147x (mozilla) with the same 3-6x speed gap. Weak ratio
rows are binary/structured inputs, not text. A probe of
`considerStaticDictionaryCandidate` shows it winning inside its own group by
1-145 bytes on dickens/samba and losing on xml, while the global winner on
those corpora is a different candidate; the split graph and the
static-dictionary re-encode remain the largest q11 costs. This is a position
baseline, not a leadership claim.
Evidence: [data/br-q11-full-matrix-20261118](data/br-q11-full-matrix-20261118/README.md).

Routing the binary ratio rows through the explicit HQ encoder is not viable.
`run-br-hq-encode-probe` with its default controls (q11, block 65536, beam 16,
two iterations, depth 64, nice 128) did not finish a 64 KiB mozilla prefix
within 300 s, and the 128 KiB prefix exceeded 12 minutes before being killed;
the planned q11 path encodes the same 64 KiB in well under a second. The HQ
engine stays an opt-in for tiny inputs. Closing the 1.11x-1.15x binary ratio
gap must come from the planned pipeline's literal/context and command
modeling, not from switching engines.

A wire-structure comparison against libbrotli 1.0.9 on 128 KiB prefixes
locates the binary ratio gap. On mozilla (18,676 vs 16,232 bytes) Vort's final
wire has 1 command block type, 1 distance block type, 1 distance-context tree
and 4 literal trees, while the reference uses 13 command types, 5 distance
types, 6 distance-context trees and 9 literal trees; the split and
distance-context candidates are evaluated but lose the size arbitration. The
same rows also show far fewer implicit/recent-distance copies (mozilla 862 vs
2,631; xml 218 vs 627; dickens 5 vs 95) and more explicit regular distances,
so the optimal parse is not preferring ring-buffer distances even though the
encoder can code them cheaply. Text rows are structurally closer. The next
ratio work should therefore target (1) ring-buffer-aware distance pricing in
the optimal parse and (2) block-type/context split quality on
binary/structured inputs, not window size or the static dictionary.

The repcode-bonus magnitude was screened as a cheap way to raise recent-distance
usage in the modeled parses. Doubling the cap from 3 to 6 Q8 bits shrinks xml
q11 by 37 bytes (8,401 -> 8,364) but grows samba by 131 bytes (40,937 ->
41,068) and leaves dickens unchanged (43,953); the change is reverted. A fixed
global bonus cannot represent the path-dependent ring-buffer saving, so the
next ratio step is a parse that carries the four recent distances (or a
bounded beam over them) instead of another static price tweak.

The position-aware last-distance pricing was screened as a stronger form of
the repcode prior: the seed plan records its last distance per segment, and
the backward DP prices a match at that distance with the recent-distance
symbol cost. Replacing the static repcode bonus with this pricing worsened
xml q11 by 158 bytes (8,401 -> 8,559) and samba by 131 bytes (40,937 ->
41,068), leaving mozilla (18,676) and dickens (43,953) unchanged; reverted.
The seed path's last distance is too stale for the new parse, and pricing it
at the distance-symbol cost ignores the command-symbol change, so the parser
over-prefers it. A correct recent-distance gain needs the ring state inside
the parse (or a bounded beam over it), not another seed-derived price.

Split-candidate probes on the binary rows show the primary split wire saving
only 154 bytes on a 19,422-byte mozilla group (19,268) and 53 bytes on xml
(9,260 -> 9,207), while the final q11 winners are 18,676 and 8,401 and come
from groups whose split phase does not improve on the baseline. The
distance-context candidate similarly wins 20-30 bytes inside losing groups and
nothing in the winning group. Vort's mozilla wire also carries fewer literal
bytes than the reference (7,567 vs 9,151) and more copy bytes, yet is 2,444
bytes larger, so the gap is dominated by base command/literal entropy
modeling (1 command/distance type, 4 literal trees) rather than by a missing
split proposal. Next entropy work should target the base context/tree
selection, not a larger split search.

Current-source Zstd level 3 on five 128 KiB Silesia prefixes measures
0.9589x the libzstd 1.4.8 bytes (141,027 versus 147,068) at 2.2-9.1 MiB/s
versus 170-872 MiB/s (0.003x-0.031x). Mozilla is the weak row: 7.4% larger
and 78x slower. This refreshes the stale 2026-10-25 level-3 baseline; the
default level remains 1 (speed-first) and levels 1-2 were already aligned by
user choice. Changing level 3 to a speed-first policy is a product decision,
not an internal optimization, because it trades away the measured ratio gain.
Evidence: [data/zstd-level3-current-20261118](data/zstd-level3-current-20261118/README.md).

The dirty-row prepare experiment rebuilt joint tree cost rows only for trees
whose counts changed during the incremental move pass. It is wire-identical
but neutral to slightly slower: dickens q11 median 891,210,581 versus
890,145,478 ns and samba 1,302,316,414 versus 1,292,575,983 ns (0.75%
slower, all three candidate runs above all three baseline runs). The prepare
cost is dominated by the first full build and the row writes rather than
repeated cost-model computation, so the dirty tracking does not pay for
itself. Reverted.

Lowering the split proposal thresholds does not recover binary ratio. The
command-split savings gates were reduced fourfold (2048 -> 512 bits, with the
entropy gate at 3/4) and the distance-split gates from 2200/2250 to
512/600 bits; q11 wires on mozilla (18,676), xml (8,401), dickens (43,953)
and samba (40,937) stayed byte-identical. The proposals either remain below
even the lower entropy bar or lose the complete-wire arbitration, confirming
that the binary gap is split-proposal quality and base entropy modeling, not
a conservative threshold.

## Zstd level semantics aligned with zstd (2026-11-18)

The user directed the public level semantics to follow zstd. The default level
is now 3; levels 1/2/3 resolve to the legacy fast-compressed primary, the
controlled fast parser with acceleration 2, and the controlled greedy parser.
Levels 4-22 keep the existing quality ladder. Level 3 uses greedy instead of
double-fast because double-fast inverted the ladder on mr (+6.7%) and nci
(+1.4%); greedy is strictly smaller than level 2 on all 12 Silesia files and
on 10/12 beats libzstd 1.4.8 level 3 (dickens +0.07%, osdb +1.35%). Explicit
strategies, accelerations, HQ requests and encode controls still win, and the
reusable `LevelFrameEncoder` path now applies the same 1-3 policy. On five
128 KiB Silesia prefixes the ladder sizes are 1.011-1.152x (L1),
0.970-1.032x (L2) and 0.902-1.001x (L3) of libzstd at 3.6-4.7x, 6.7-9.6x and
12.0-20.5x slower respectively; level 3 moves from 2.2-9.1 MiB/s
(32-399x slower, 0.81-1.07x size) to 10.2-50.8 MiB/s, trading roughly 2.3-2.8x
speed versus double-fast for a strictly monotone ladder. Golden wires for the
controls/HQ helpers, the large-history default, the encode gate and the root
default-level assertion were re-frozen. `test-zstd` passes 1430/1430, the
encode gate passes, and the full `test check check-wasm` gate finishes
389/389 steps with 5756/5758 tests passing (2 skipped).
Evidence: [data/zstd-level-semantics-aligned-20261118](data/zstd-level-semantics-aligned-20261118/README.md).

## Zstd greedy search kernel speedup (2026-11-18)

The controlled greedy/lazy/optimal search kernel now locates mismatches with a
direct bool-vector bitcast plus `@ctz` instead of `std.simd.firstTrue`'s
portable iota/blend/min reduction, compares the first 8/16 bytes as `u64`
words before the 32-byte vector loop, caches the incumbent sequence price in
`findBest`, and skips the prefix hash when there is no dictionary/history
prefix. On 12 Silesia 128 KiB prefixes at level 3 the interleaved A/B speedup
is 1.152x geometric mean (min 1.046x, max 1.217x); full-file dickens and xml
improve 1.187x and 1.135x. Every compared frame is byte-identical, and L1/L9/
L22 controls stay within noise (L1 xml 1.002x, L9 0.998x, L22 0.999x).
`test-zstd` passes 1430/1430 and the encode gate passes; the full
`test check check-wasm` gate finishes 389/389 steps with 5756/5758 tests
passing (2 skipped).
Evidence: [data/zstd-greedy-search-kernel-20261118](data/zstd-greedy-search-kernel-20261118/README.md).

## Zstd wide-candidate emission order (2026-11-18)

Strict wide-match levels now prove double-fast and rep-beam token equality
before emitting the complete candidate wire. The losing candidate is no longer
materialized and discarded. On 12 Silesia 128 KiB prefixes the interleaved A/B
speedup is 1.033x geometric mean at level 9 (min 0.998x) and 1.036x at level 22
(min 0.998x); every compared frame is byte-identical, and L1 controls stay
within noise (dickens 0.995x, xml 0.999x). `test-zstd` passes 1430/1430, the
encode gate passes, and the full `test check check-wasm` gate finishes 389/389
steps with 5756/5758 tests passing (2 skipped).
Evidence: [data/zstd-wide-candidate-order-20261118](data/zstd-wide-candidate-order-20261118/README.md).

## Brotli q11 static dictionary usage screen (2026-11-19)

A diagnostic summary of the selected q11 wire on the xml 128 KiB prefix shows
57 static-dictionary copies covering 332 bytes (wire 8,401 bytes; libbrotli
7,441, +12.9%). The q11 schedule enables 4,096 dictionary probes, but
`considerStaticDictionaryCandidate` only mixes dictionary copies into literal
runs of the lazy command plan. The lazy plan's LZ77 copies cover most
positions, so dictionary use stays at 332 bytes; libbrotli chooses dictionary
copies jointly with LZ77. The legacy literal-run `mixStaticDictionary*`
helpers remain test-only. The next functional target is a dictionary-first
greedy re-plan that may replace LZ77 copies (same decoded output), emitted as
an additional candidate with shortest-wire arbitration. No production code
was changed in this screen.

A follow-up prototype merged the lazy/optimal command plan with a
dictionary-only plan through a position-based cursor that can split literals
and LZ77 copies. It hit `InvalidBlockPlan` on static-copy partial overlaps
(a one-byte literal segment advanced past the start of an eight-byte static
copy) and was reverted before producing a wire. Static dictionary copies are
atomic and cannot be split like LZ77 copies, so a correct joint planner must
integrate dictionary candidates into the parser/DP instead of merging two
finished plans.

A flat-cost sweep of `quality_dictionary_cost_bits` is mixed: 12 bits grows
xml to 8,515 and dickens to 46,674; 24 bits gives xml 8,400 and dickens 44,109;
28 bits gives xml 8,389 and dickens 44,408; the default 22 bits keeps xml
8,401 and dickens 43,953. No fixed proxy improves both corpora, so the next
step is per-command exact dictionary pricing inside the optimal DP, not a
constant retune.

A per-copy-length discount (slope 1/2 eighths of a bit per copy byte) is also
marginal: slope 1 keeps xml 8,401 and dickens 43,950 (3 bytes better); slope 2
gives xml 8,400 and dickens 43,955. The q11 gap therefore requires a stateful
optimal DP that prices insert length, command symbol, distance code and extra
bits per candidate, not a scalar proxy. The benchmark infrastructure gates
(native library, planned encode, planned chunks, Brotli reference) all pass.
Running the literal-run dictionary mix on the lazy q11 command plan is
byte-identical on xml/dickens/x-ray (8,401/43,953/77,220), confirming the lazy
literal runs are too short for the static dictionary.

## Brotli q11 stateful DP dense-candidate screen (2026-11-19)

The forward `(position, insert_bucket)` DP now consumes a dense per-position
hash chain (`lz77.collectHashMatchesAlloc` inserts every position instead of
skipping match interiors) and prices edges with `entropy_feedback.Model`
(command symbol plus insert/copy extra bits plus distance). On 12 Silesia
128 KiB prefixes at q11 the single-best-candidate DP changes only two rows:
mr 30,036 -> 29,639 (-397, -1.32%) and x-ray 77,220 -> 76,963 (-257, -0.33%);
the other ten sizes are unchanged. q11 encode time rises 11.3% (xml),
16.0% (dickens) and 17.9% (x-ray) on the measured rows. The 12-row geometric
mean ratio gain is about 0.14%, below the 3% merge bar, so the DP stays out of
the production default path and remains a tested prototype. A same-distance
length ladder (4/8/16/32/64/128/max) is worse (mr 29,699, x-ray back to
77,220), so the next slice needs a per-position Pareto candidate frontier and
repcode-aware command pricing rather than more length choices.
Evidence: [brotli-q11-ratio-frontier.md](brotli-q11-ratio-frontier.md).

## Brotli q11 Pareto frontier DP screen (2026-11-19)

`lz77.collectHashFrontierAlloc` records a bounded nearest-first Pareto
frontier per position (increasing length, non-decreasing distance) and
`stride == 1` is verified equal to `collectHashMatchesAlloc`. Feeding a
4-wide frontier to the stateful DP changes the 12-file q11 screen to mr
30,036 -> 29,559 (-477, -1.59%) and x-ray 77,220 -> 76,971 (-249, -0.32%)
with the other ten sizes unchanged. Relative to the single-candidate DP, mr
gains 80 bytes and x-ray loses 8. Encode time on xml/dickens/x-ray is
+13.2%/+18.1%/+19.3% over baseline, and the 12-row geometric-mean ratio gain
is about 0.16%, still far below the 3% merge bar. The frontier is therefore
not wired to the production default path. Since wider candidates do not move
the text rows, the remaining q11 lever is model-to-wire convergence (rebuild
the entropy model from the DP plan and iterate) or a stronger candidate
structure such as a binary-tree search, not more frontier width.
Evidence: [brotli-q11-ratio-frontier.md](brotli-q11-ratio-frontier.md).

## Brotli q11 match-window probe and 64 KiB optimal window (2026-11-19)

A new `run-br-window-probe` diagnostic compares the longest hash-chain match
at every position for a 32 KiB and a 65,520-byte search window. All twelve
Silesia 128 KiB prefixes gain coverage at 65,520: mozilla +645,009 matched
bytes (5,801 positions with at least 8 extra bytes), xml +200,562 (3,291),
nci +112,572 (2,863), reymont +76,987, webster +71,443, osdb +70,890, and
dickens +56,673, among others. Temporarily lifting the quality-scheduled
optimal window to the 16-bit wire window and extending the lz77 fixed
distance table to 65,535 changes q11 to dickens -695, osdb -873, webster
-606, reymont -530, ooffice -225, nci -101, mr -91, samba -29 and xml -24
bytes, with mozilla/sao unchanged and x-ray +138. The 12-row geometric mean
gain is about 0.73% at xml/dickens encode-time costs of +24.7%/+14.2%, below
the 3% merge bar and with one size regression, so the production window cap
stays at 32 KiB and the q11 output returns to baseline. The lz77 capability
and the corrected 64 KiB fixed distance table remain: the lazy q11 parser
already searched 65,520 bytes, so the old table was an out-of-bounds read
for accepted matches beyond 32 KiB. Reaching libbrotli's lgwin=22 behavior
would require wider token distances and larger wire window bits.
Evidence: [brotli-q11-ratio-frontier.md](brotli-q11-ratio-frontier.md).

## Brotli q11 literal-context ablation and wire-structure screen (2026-11-19)

`run-br-planned-encode-bench --no-literal-context-modeling` isolates the
literal context contribution at q11 on 128 KiB prefixes: dickens +1,405
bytes (3.20%), xml +367 (4.37%), x-ray +7,989 (10.35%), mr +426 (1.42%),
mozilla +202 (1.08%), nci +168 (1.90%). Context modeling is therefore not
the main gap on the worst rows. `run-br-quality-compare-probe` shows the
structural difference instead: libbrotli emits implicit (last-distance)
commands for 48.0% of mozilla copies versus Vort's 14.9%, 45.3% versus
16.5% on nci, 14.7% versus 1.0% on mr, and 26.7% versus 9.8% on xml. The
reference also uses multiple command/distance block types on mozilla
(13/5 versus 1/1), mr (4/4), dickens (2/3) and x-ray (2/4), while Vort's
adaptive splitters produce one type. Upstream's Zopfli parser stores a
4-entry distance cache per DP node and keeps an 8-entry queue of distinct
cache start positions; Vort's optimal DP has no cache state. The next q11
increment should add repcode-aware parsing (per-node distance cache or the
bounded start-position queue), with command/distance block splitting as the
secondary lever.
Evidence: [brotli-q11-ratio-frontier.md](brotli-q11-ratio-frontier.md).

## Brotli q11 repcode-aware beam parser screen (2026-11-19)

`src/br/encoder/rep_optimal.zig` is a forward beam DP that carries Brotli's
four-entry distance cache and the exact insert length in every state, with
hash-frontier and cached-distance candidates priced through implicit, short
and regular distance codes. At beam 8 / frontier 4 on q11 128 KiB prefixes
it changes only the binary rows: mr 30,036 -> 29,565 (-471, -1.57%) and
x-ray 77,220 -> 77,092 (-128, -0.17%); dickens, mozilla, nci and xml are
size-identical. Encode time rises 28-50% (dickens 581 ms, mozilla 662 ms,
mr 938 ms, xml 480 ms). Pricing implicit commands with the explicit symbol
as a proxy and widening the beam to 16 / frontier to 8 still leaves every
text row unchanged. The parser is kept as a tested prototype but not wired
to the production default path. Together with the frontier-DP screen this
shows the text gap is not caused by the absence of cache state alone; the
remaining levers are candidate quality and model-to-wire convergence.
Evidence: [brotli-q11-ratio-frontier.md](brotli-q11-ratio-frontier.md).

## Brotli q11 command/distance block-split diagnostic (2026-11-19)

The reference q11 wire uses multiple command/distance block types on several
rows (mozilla 13/5, mr 4/4, x-ray 2/4) while Vort emits one type. Temporary
instrumentation showed the adaptive command/distance plans exist on every
measured row (type_count 8/8, x-ray command 5), but the combined adaptive
command+distance candidate was never materialized: the candidate if/else
chain selects the adaptive literal candidate first, and encodes command-only
when both symbol plans exist. Materializing the combined candidate leaves
every q9 and q11 size unchanged because its complete wire is larger:
mozilla 18,903 vs 18,676, mr 30,146-30,339 vs 30,036, x-ray 86,157 vs
85,848, dickens 44,337 vs 44,061, xml 8,682 vs 8,588 and nci 9,300 vs 8,989
on the winning parses. q9 sizes are identical with and without the candidate
at +3-8% encode time, so the change was reverted. The block splitter's
`estimated_bits` covers only the command/distance symbol payload (mozilla
about 6.6 KB) versus an 18.9 KB complete wire, so its proposals cannot see
tree/type-map and literal costs. The next splitter step is to include those
costs in the proposal search or to increase its type/iteration budget.
Evidence: [brotli-q11-ratio-frontier.md](brotli-q11-ratio-frontier.md).

## Brotli q11 symbol-split search gating (2026-11-19)

`run-br-quality-stage-probe` (new, traced one-shot quality encode) shows the
q11 stage split on the 128 KiB dickens prefix: optimal_parse 22.4%, wire
24.9%, split_planning 19.5%, lazy_parse 7.3%, evaluate 7.6%,
context_proposals 6.2%, other 10.6%, with 60 complete wire attempts. The
complete-wire screen never retains a command block split at q11 (every
winning wire has one command type), while distance splits win only on very
large plans (ooffice keeps eight distance types). q11 now skips the command
split search entirely and runs the distance split search only for plans with
at least 16K commands. On the twelve 128 KiB Silesia prefixes all sizes are
unchanged (dickens 43,953, mozilla 18,676, mr 30,036, nci 8,859, ooffice
64,634, osdb 46,778, reymont 33,363, samba 40,937, sao 92,145, webster
36,107, xml 8,401, x-ray 77,220). A paired five-iteration A/B measures a
**6.6% geometric-mean encode speedup** (per-row 1.02x-1.16x; ooffice and
x-ray gain most). `test-br` passes 1636/1637 (1 skipped). The distance
threshold is calibrated on this corpus; the planned encode gate covers the
built-in cases.
Evidence: [brotli-q11-ratio-frontier.md](brotli-q11-ratio-frontier.md).

## Brotli q11 q10-inheritance and literal-split cost screen (2026-11-19)

q11 runs the complete q10 pipeline first and retains its wire to guarantee
`q11 <= q10`. Skipping that inheritance for 128 KiB inputs leaves all twelve
Silesia sizes unchanged while cutting encode time by roughly 17-35% on the
measured rows (dickens 354.6 vs 430 ms, mozilla 399.6 vs 510, ooffice 355.5
vs 460, osdb 387.9 vs 590, sao 479.9 vs 740, x-ray 328.0 vs 505). The
inheritance is a deliberate public size-monotonicity contract, so the
experiment was reverted; removing it needs an explicit contract change or a
cheaper proof. Disabling the adaptive literal split is not viable either:
dickens +26, osdb +26, reymont +25, samba +867, sao +54, webster +10 and
x-ray +3,872 bytes. The remaining literal split planning is therefore
productive, unlike the command/distance searches removed by the previous
increment.
Evidence: [brotli-q11-ratio-frontier.md](brotli-q11-ratio-frontier.md).

## Zstd level-1 fast-parser acceleration screen (2026-11-19)

The 64-128 KiB fast sequence parser scans every position. A Zstd-style
growing miss stride was screened against the current source on the twelve
128 KiB Silesia prefixes (level 1, system libzstd 1.4.8 reference). The
ungated stride (step grows every 64 misses) improves x-ray 1.69x and sao
1.04x but slows ten rows by 1-3% (mozilla 0.969x, webster 0.970x, mr
0.975x, xml 0.973x): 3.3% geometric mean with four control rows below the
0.98x floor. A content-gated variant (text-like blocks keep the plain scan)
still slowed text rows by 1-5% because the 16 KiB classifier runs per
block, and sao regressed 6.7%. A branchless 256-miss stride improved x-ray
only 1.03x and slowed the rest. The simple acceleration lever is rejected;
closing the remaining level-1 gap (dickens 76.5 vs 276 MiB/s, xml 226 vs
998, x-ray 130 vs 935) needs a deeper libzstd-style two-position loop with
fewer per-position probes, not a stride on the current loop.

## Brotli q11 modeled2 and Zstd level-1 rep-probe screens (2026-11-19)

Skipping q11's second modeled optimal parse (>=64 KiB) regresses dickens
+82, nci +130, reymont +96, samba +211, webster +83 and xml +187 bytes, so
the second iteration stays. Removing the fast sequence parser's extra
rep1/rep2 probes (the `repeatRank == 3` loop) changes level-1 sizes by
+8 to +348 bytes (nci +2.8%, mozilla +1.4%, xml +1.2%) with mixed and
mostly negative speed deltas (x-ray 0.93x), so it is reverted as well.
Together with the acceleration screen this confirms the level-1 gap needs
a structural two-position loop rewrite rather than trimming the current
parser's heuristics.

## Zstd level-1 fast hash-table sizing (2026-11-19)

The 64-128 KiB fast sequence parser used an 11-bit long-match table (2K
entries). Widening it to 13 bits (8K entries, 32 KiB stack) on the twelve
128 KiB Silesia prefixes reduces level-1 output by 1-22%: dickens 63,414 ->
59,878 (-5.6%), mozilla 25,151 -> 24,399 (-3.0%), mr 37,918 -> 36,827
(-2.9%), osdb 78,042 -> 61,098 (-21.7%), reymont 47,564 -> 43,617 (-8.3%),
webster 51,345 -> 48,838 (-4.9%), xml 12,556 -> 12,323 (-1.9%), with ooffice
and xml now smaller than libzstd 1.4.8 and ten of twelve rows within 0.4-6.4%
of it. The geometric-mean size gain is 4.75%; paired five-iteration A/B
speed is -1.4% geometric mean (mr +6.8%, reymont +4.5%, xml +1.1% faster;
samba 0.945x, x-ray 0.935x, mozilla 0.954x slower). A 14-bit table buys
another ~1.5% size for a further ~3.7% speed loss and is rejected; 12 bits
loses most of the ratio gain. `test-zstd` passes 1434/1434.

## Zstd level-1 short hash-table screen (2026-11-19)

With the 13-bit long table in place, widening the 4-byte short table from 8
bits (256 entries) to 10 bits (1K entries) changes level-1 sizes by -3.8%
to +1.3% (nci +1.3% and xml +0.7% regress; sao -3.8%, osdb -3.6%, dickens
-3.0%) while slowing the encoder by 2.5-18% on most rows (dickens 0.82x,
sao 0.85x, samba 0.88x, webster 0.87x). The 1K-entry table hurts cache
locality more than the collisions it removes, so the 8-bit short table is
kept.

## Zstd level-1 libzstd-style parser prototype (2026-11-19)

A standalone prototype replaced the double-fast sequence parser with a
libzstd-shaped loop for 64-128 KiB blocks: one 8-byte hash table, a rep0
check plus one hash candidate per position, backward extension, jump to the
match end, and an immediate rep loop. On the twelve 128 KiB Silesia
prefixes it is **1.5x geometric-mean faster** (dickens 78 -> 134 MiB/s,
mr 73 -> 141, sao 102 -> 172, x-ray 126 -> 167) but outputs 3-9% more bytes
(dickens +2.8%, mozilla +8.9%, reymont +9.1%), leaving level 1 at +0.6% to
+21.7% versus libzstd 1.4.8. Adding the 4-byte short table back gives +12%
geometric-mean speed for +1.9% size; adding the adjacent-position probe
costs 5% speed for no measurable size gain. The prototype is not adopted:
it diverges from the token-parser differential oracle and trades ratio for
speed at the ratio-first level-1 preset boundary. The measured tradeoff is
recorded as the design basis for a future two-parser level policy (for
example speed-first level 1 and ratio-first level 2).

## Brotli q11 lazy-seeded model screen (2026-11-19)

Seeding the q11 entropy model from the lazy command plan and skipping the
unmodeled optimal parse (the first of three optimal passes) is not viable:
dickens +92, nci +20, reymont +29, samba +140, webster +82, xml +10 bytes
and, decisively, x-ray +3,783 bytes (+4.9%). The unmodeled optimal plan is
load-bearing as both a candidate wire and the model seed, especially on
binary content, so all three optimal passes stay.

## Brotli q11 candidate pre-screen boundary (2026-11-19)

Skipping literal/context/split planning when a candidate's base wire is far
above the incumbent was measured with 10% and 5% slack. At 10% all twelve
sizes stay identical and q11 speeds up ~1.8% geometric mean (mozilla -10%),
below the 3% bar. At 5% x-ray regresses by 3,872 bytes (+4.9%): its winning
candidate's base wire sits more than 5% above the lazy incumbent and the
context/split pass recovers 4.9%, so the earlier "gains stay below two
percent" assumption does not hold. The pre-screen was reverted; a safe
threshold is at least 10%, where the measured benefit does not justify the
latent ratio risk.

## Deflate decode corpus probe and current hot loop (2026-11-19)

Added `run-deflate-decode-corpus-probe`, which repeatedly decodes one
raw-deflate corpus prefix into a preallocated buffer so sampling profilers
see only the decoder. On the dickens 128 KiB L6 wire (50,649 bytes) Vort
decodes at 752.9 MiB/s; `perf` attributes 86.4% of the time to
`decodeSemanticDynamicBlockIntoBufferedReaderNonOverlapInline`, with the
remaining cost spread over table loads (literal primary/secondary),
sixteen-byte match copies and bit-buffer shifts. This matches the
2026-11-16 structural frontier: the semantic loop is already fused
(four-literal batches, packed entries, secondary lookups), so the next
deflate decode lever is the high-risk two-phase token buffer rather than
another local table or copy edit.

A follow-up read of the semantic loop confirms why local edits are
exhausted: the next literal entry is already loaded before each match
copy, short non-overlapping matches use a single sixteen-byte vector
store, longer ones use the bounded `copyWide` path, and four-literal
batches are decoded speculatively. A two-phase token buffer would add a
token write and read per symbol to the same fused chain, so its expected
value stays at the documented 5-8% upper bound with high implementation
risk; no prototype was started without that budget.

## Zstd level-3 match-search budget sweep (2026-11-19)

The zstd encode bench now accepts `--match-search-budget`. With an explicit
fast-compressed/greedy selection on the 128 KiB prefixes, the default level-3
output is reproduced exactly at budget 64 (dickens 51,971, xml 10,748, x-ray
93,086, mozilla 20,112), so the effective level-3 chain depth is 64 even
though the native default option is 512. Sweep (dickens/xml/x-ray/mozilla):

| budget | dickens | xml | x-ray | mozilla | speed vs default |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 4 | 62,279 | 19,369 | 93,583 | 21,439 | +0-30% |
| 16 | 54,177 | 11,315 | 93,293 | 20,232 | +10-53% |
| 32 | 52,716 | 10,958 | 93,138 | 20,143 | +2-34% |
| 64 (default) | 51,971 | 10,748 | 93,086 | 20,112 | 1.00x |
| 512 | 51,252 | 10,614 | 93,093 | 20,118 | -46% on dickens |

Budget 16 trades +0.2-5.3% size for 1.1-1.5x speed while staying smaller than
libzstd 1.4.8 on xml, x-ray and mozilla; budget 32 trades +0.06-2.0% size for
+2-34% speed and remains smaller than libzstd on three of four rows; budget 4
loses too much ratio and 512 halves speed for ~1% size. The default stays at
64; adopting 16 or 32 is a level-3 policy decision.

## Zstd wide fast parser regression guard (2026-11-19)

Added `src/tests/zstd_wide_fast_regression.zig`, a deterministic text-like
128 KiB payload (LCG-sampled windows of repeated prose) that fills exactly
one maximum-size block. It freezes the compact plan produced by
`zstd/match/double_fast/sequence_parser.zig` (4,292 matches, 1,121 literals,
129,951 matched bytes, plus the record-buffer growth past the
one-record-per-64-bytes reservation) and adds frame-level round-trip and
one-sided size ceilings at level 1 (11,339 bytes) and level 3 (7,140 bytes).
Ablation: flipping `long_hash_bits` from 13 to 11 moves the plan to 4,374
matches / 1,309 literals and the level-1 wire to 11,619 bytes (+2.47%),
while level 3 stays at 7,140 because its wide probe uses the separate 11-bit
double-fast candidate. The guard therefore fails on the exact table-width
regression it was added for, and any future size improvement may lower the
ceilings without editing the plan lock.

## Zstd level-1 fast sequence bitstream writer (2026-11-19)

A flat `perf` profile of the 128 KiB dickens level-1 encode against libzstd
1.6.0 (Vort 78.1 MiB/s at 59,878 bytes, libzstd 331.8 MiB/s at 56,148)
attributed 5.4% of cycles to `ReverseBitstreamWriter.addBits` and 1.6% to the
per-field `ensureUnusedCapacity` check: every sequence flushed full bytes and
rechecked capacity four times. The fast large-sequence emitter now reserves
16 bytes per sequence plus one spare word (worst-case fields stay below 90
bits) and uses `addBitsReserved`, which flushes only when the next field
cannot fit; the checked writer still emits the three initial states after a
full-byte flush, and a differential unit test pins both writers to identical
bytes including a full-word field.

Twelve 128 KiB Silesia prefixes, level 1, one-shot, ReleaseFast, interleaved
Vort-first/reference-first rounds (`--iterations 1 --rounds 5`): geometric-mean
Vort encode speed **1.0672x** (per row 1.025-1.106), all twelve output sizes
byte-identical. The weakest row is ooffice at +2.5%, above the 0.98x control
floor. Evidence:
[data/zstd-fast-reserved-writer-20261119](data/zstd-fast-reserved-writer-20261119/README.md).

A deferred predefined-table viability walk was prototyped in the same session.
Literal and match codes include predefined states with mixed transition widths
(LL 1, LL 17, ML 2), so only the offset kind could be deferred; writer-only
measured 1.0760x geometric mean versus 1.0752x with the deferral, i.e. no gain.
The deferral was removed. The remaining level-1 profile is parser-bound
(~34%), then predefined planning (~6%), emission orchestration (~6%) and
literal Huffman (~5.7%); the next structural lever is either the parser policy
(single-table fast parser) or fusing plan and emission passes.

## Zstd level-1 rep0 probe caching screen (2026-11-19)

The wide fast parser probes rep0 at the anchor to choose the one-byte
lookahead position and probes the same distance again during candidate
arbitration. Caching the first `Match` in a local and reusing it removes one
`matchAtDistance` per iteration but keeps a 24-byte struct live across the
whole candidate search. On the twelve 128 KiB level-1 prefixes it measured
**0.9616x** geometric mean (worst row 0.89x) with byte-identical output, so
recomputing the probe is cheaper than the added register and stack pressure.
The cache was reverted.

## Deflate encode baseline and level-6 search-depth sweep (2026-11-19)

The repository had matched Deflate decode evidence but no encode comparison.
`run-deflate-encode-bench` now encodes the same 128 KiB prefix with Vort
`encodeRawLevelAlloc`, zlib 1.2.11 and libdeflate 1.10, verifies every wire
with both Vort and libdeflate, and times the allocating one-shot APIs in
rotating order. On the twelve Silesia prefixes at level 6, Vort reaches
**0.2825x** libdeflate throughput and **0.7086x** zlib throughput with mixed
sizes (six rows smaller than libdeflate; samba +7.1%, mr +4.1% are the worst).
Flat `perf` attributes 42.67% of the encode to the hash-chain match finder,
4.47% to `lazyGreedyPlanAlloc` and 2.01% to `matchLength`.

The default preset searches `max_chain = 160`, deeper than zlib's 128 and far
deeper than libdeflate level 6's 35. A Vort-only sweep measured chain 64 at
**1.2985x** speed for +0.73% geometric-mean size (worst row +2.0%, no speed
row below 1.015x), chain 96 at 1.1547x for +0.34%, and chain 35 at 1.5393x for
+1.41% size (one row 0.970x). Chain 64 is the cleanest knee, but changing the
preset also changes the zlib level-6 and archive defaults, so this increment
only adds the benchmark and evidence. Evidence:
[data/deflate-encode-baseline-20261119](data/deflate-encode-baseline-20261119/README.md).

## Deflate hash-chain early node load (2026-11-19)

The deflate hash-chain finder loaded the next `prev[candidate]` only after
the prefix screen and match scan. The next node is independent of the scan,
so the load now issues before both, overlapping its latency with the
candidate comparison and `matchLength`. Traversal order and match selection
are unchanged. On the twelve 128 KiB level-6 prefixes the geometric-mean
encode speed is **1.0367x** (per row 0.9905-1.1324) and every output is
byte-identical; level 1 and level 9 spot checks keep their sizes and speed.
Evidence:
[data/deflate-encode-early-chain-20261119](data/deflate-encode-early-chain-20261119/README.md).
The shared finder also serves the zstd hash parsers, so adoption is gated on
the full `test`/`check`/`check-wasm` run.

## Deflate match-finder prefetch and lazy ring screens (2026-11-20)

Two wire-identical follow-ups to the early chain-node load were measured on
the twelve 128 KiB level-6 prefixes and rejected:

- Prefetching the chain node after `next_candidate`: **0.8996x** geometric
  mean (min row 0.856x) with identical sizes. The extra prefetch traffic and
  cache pollution outweigh any latency hiding.
- A ring-sized lazy-planner predecessor table (`hashPrevTableLen`, u32 x 32 KiB
  instead of u32 x input length): **0.9745x** geometric mean (text rows
  0.905-0.962x, x-ray 1.081x, webster 1.066x) with identical sizes. The
  per-candidate `earliest` check and mask arithmetic cost more than the
  smaller footprint saves.

Both were reverted; the early chain-node load remains the accepted increment.

## Deflate level-6 default search depth 160 -> 64 (2026-11-20)

`optionsForLevel(.default)` now uses `max_chain = 64` instead of 160. This
preset drives zlib/gzip level 6 and the archive defaults. The flat profile put
42.7% of level-6 encode in the hash-chain finder, and chain 160 was deeper than
zlib's 128 and far deeper than libdeflate level 6's 35. Twelve 128 KiB Silesia
prefixes, one-shot ReleaseFast, interleaved rounds: **1.2816x** geometric-mean
encode speed for **+0.73%** geometric-mean size (worst row xml +1.97%). x-ray
is the only sub-parity row in that matrix at 0.975x; a separate three-run
re-measurement gave 32.67/32.78/33.01 MiB/s versus 32.56 before, so it is run
noise. Combined with the earlier chain-node load, the current source is
**1.3286x** the pre-2026-11-19 level-6 speed for +0.73% size, and the
Vort/libdeflate speed ratio improves from 0.2825 to 0.3756. The full
`test`/`check`/`check-wasm` gate passed (389/389 steps, 5775/5777 tests,
2 skipped) without re-freezing golden wires. Evidence:
[data/deflate-chain64-default-20261120](data/deflate-chain64-default-20261120/README.md).

## Deflate level-6 encode against libdeflate 1.26 (2026-11-20)

The encode bench now takes `-Ddeflate-reference-dir` and
`-Ddeflate-reference-include`, so it can link and load a non-system libdeflate
and report the matching header version. Against the locally built 1.26 on the
twelve 128 KiB level-6 prefixes, Vort's current source (chain-64 default plus
the chain-node early load) reaches **0.3467x** libdeflate throughput, versus
0.3756x against the system 1.10; 1.26 is about 8% faster overall. Vort is
smaller on sao, xml and x-ray, and larger on the other nine rows (worst samba
+7.3%, mr +4.6%). Evidence:
[data/deflate-encode-libdeflate-126-20261120](data/deflate-encode-libdeflate-126-20261120/README.md).

## Deflate decode literal pair-store screen (2026-11-20)

The fused semantic loop wrote literals with two byte stores in the one-shot
non-pause path, while the pair writer used by the pause/rle modes performs one
u16 store. Using the pair writer unconditionally measured **750.0 MiB/s**
versus **747.7 MiB/s** on the dickens 128 KiB probe (three runs each, within
run noise) with identical output, so the two byte stores are not a bottleneck;
the change was reverted. Instruction annotation of the same loop puts the
16-byte match copy load/store at ~10.6% and Huffman table loads at ~15%, which
bounds the two-phase token-buffer upside after token write/read overhead.

## Zstd level-3 block-only match fast path (2026-11-20)

A flat profile of the level-3 default on the 128 KiB dickens prefix attributes
68.7% of encode to the controlled search (`matchAt` 31.2%, `findBest` 30.6%,
`planReuse` 6.8%). `matchAt` selected a dictionary, prefix-history or block
span on every 32-byte comparison chunk even though one-shot frames have no
dictionary or history. A block-only fast path now skips the per-chunk span
selection and bound; the word/vector comparison, window check and match result
are unchanged. Twelve 128 KiB level-3 prefixes: **1.065x** geometric-mean
speed (per row 1.039-1.090), all twelve sizes byte-identical. Level 1 keeps
its 59,878-byte wire (the compact parser does not use this path); level 9
keeps its 50,404-byte wire. Evidence:
[data/zstd-level3-block-matchat-20261120](data/zstd-level3-block-matchat-20261120/README.md).

## Zstd controlled-search out-of-window break screen (2026-11-20)

After the block-only `matchAt` fast path, `findBest` is 37.6% of level-3
encode and its dominant instruction is the `block_previous[...]` chain load
(30.6% of cycles). Hash chains are ordered newest first, so replacing the
out-of-window `continue` with `break` looks like it should skip the tail.
Measured on the twelve 128 KiB level-3 prefixes it is **0.9879x** geometric
mean (per row 0.968-1.004) with byte-identical sizes, so the out-of-window
tail is not a real cost and the branch/loop-shape change regressed the common
path. The screen was reverted; the chain load itself is the next target
(prefetch or a smaller index representation).

## Zstd controlled-search chain-load screens (2026-11-20)

After the block-only `matchAt` fast path, `findBest` is 37.6% of level-3
encode and its dominant instruction is the scattered
`block_previous[...]` chain load (30.6% of cycles) over a 512 KiB u32 array.
Two further wire-identical attempts were measured on the twelve 128 KiB
level-3 prefixes and rejected:

- Prefetching the node after `next_block`: **0.9638x** geometric mean
  (0.953-0.975) with identical sizes. The extra prefetch traffic outweighs
  the latency it hides.
- Marking `matchAt` inline: **0.9797x** (0.964-0.998) with identical sizes.
  The expanded caller increases code pressure without improving the chain
  load.

Together with the earlier out-of-window `break` screen (0.9879x), this closes
the cheap chain-walk surface: the load is a cache-bound 128K-entry index, and
a smaller representation needs a smaller window or a different index layout,
not a local edit.

## Zstd controlled-search index-build screens (2026-11-20)

Two further wire-identical attempts on the level-3 chain index were measured
on the twelve 128 KiB prefixes and rejected:

- Dropping the `block_previous` clear and guarding `Cursor.init` with
  `position % acceleration`: **0.9786x** (0.961-1.014). The runtime modulo in
  every query costs more than the 512 KiB clear it removes.
- Fusing the block-chain build into the parse (insert positions as the parser
  advances, keep the clear): **0.9583x** (0.913-0.997) with byte-identical
  sizes. The sequential full-block build is cache-friendly; interleaving
  random chain queries with insertion competes for the same cache and loses
  more than the removed pass saves.

Together with the break (0.9879x), prefetch (0.9638x) and inline (0.9797x)
screens, this closes the controlled-search index surface for local edits. The
accepted level-3 increment remains the block-only `matchAt` fast path.
