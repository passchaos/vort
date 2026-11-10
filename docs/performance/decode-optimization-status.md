# Decoder optimization status

This note consolidates the 2026-11-01/02 decoder-performance session so the
next work does not repeat rejected experiments. Raw evidence stays in
`docs/performance/` and `/tmp/vort-decode-priority-20261031/`.

## Current gaps

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
