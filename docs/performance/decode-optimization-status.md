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
