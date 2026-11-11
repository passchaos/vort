# Decoder optimization status

This note consolidates the 2026-11-01/02 decoder-performance session so the
next work does not repeat rejected experiments. Raw evidence stays in
`docs/performance/` and `/tmp/vort-decode-priority-20261031/`.

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
