# Brotli payload fusion A/B baseline, 2026-11-16

## Purpose

Anchor the performance phase opened by
`incremental-fuzz-closure-20261116.md`. The functional fuzz closure is
complete; the largest measured decode gap is Brotli versus libbrotli, and a
stage profile attributes ~81% of decode time to the payload stage. The
candidate work is a payload state-machine fusion in
`src/br/incremental/copy_decoder.zig`.

## Baseline

`baseline.csv` is the output of the self-contained caller-owned probe, which
measures Vort and the runtime libbrotli 1.0.9 in the same binary, at the
unmodified HEAD before any candidate change:

```sh
zig build run-br-reference-bench -- --iterations 500 --csv \
  docs/performance/data/brotli-payload-fusion-20261116/baseline.csv
```

Key reading: the `vort_over_reference` column is Vort time divided by
libbrotli time (lower is faster Vort). The 1 MiB `clustered_q8` row is the
payload-dominated case (~0.80, the only large frame); the small-frame rows
carry fixed per-call overhead and are insensitive to payload fusion, so do
not use the all-row geometric mean as the payload-candidate metric.

## Candidate protocol

1. Apply one minimal payload restructure at a time behind the existing
   native/portable split; keep wire output byte-identical.
2. Rebuild the same probe to `candidate.csv` with identical iterations.
3. Compare payload-dominated rows (`clustered_q8`, plus any added 64 KiB/1 MiB
   q6/q11 rows) across alternating sweeps; report per-row ratios and a
   geometric mean over those rows with a 95% confidence interval.
4. Adoption bar: at least 3% geometric-mean improvement, no control row below
   the 0.98x floor, and full `test-br` plus differential wire validation
   green. Reject and archive the negative result otherwise, matching the
   prior rejected micro-fusions.

## Static findings that rule out naive tweaks

- `stream_count.ringIndex` already masks power-of-two capacities and must
  keep the modulo path because caller history is not guaranteed power-of-two
  (default `max_history_len` is 2^24 - 16).
- The `previous[2]` two-byte slide in the literal loop is required RFC 7932
  context state, not removable.
- The per-command phase dispatch is flat at ~1-5% per instruction; only a
  structural goto-style fusion can move it, which is why this needs the full
  A/B cycle rather than a local edit.

## perf symbol profile (2026-11-16)

`perf record -g` over `vort-br-reference-bench --iterations 200 --vort-only`
(703 samples); top self-time symbols archived in `perf-top-symbols.txt`.
The bench drives the one-shot `decodeStreamInto` path, which is the surface
the ledger gap measures.

| symbol | self share | note |
| --- | ---: | --- |
| `compiler_rt.memset` | 23.09% | aggregated across header/prefix-code table zeroing in `readMinimalCompressedHeaderInto` and several `readPrefixCodeRuntimeInto`; many small, correctness-required clears rather than one removable fill |
| `processTailLookupCompressedPayload` | 22.02% | the payload command/literal loop; insert loop already keeps `previous`/`second_previous` in registers across the run |
| `Sha2x32.round` | 8.44% | **not a decoder cost**: the call chain is `Io.Writer.Hashing(...).drain` under `reference_bench.main`, i.e. benchmark provenance/CSV checksum inside the harness (`benchmark_provenance`), not the production brotli path. No `Sha2*` symbol exists under `src/br*` outside tests. Exclude it from decoder optimization targets. |
| `memcpyFast` | 5.96% | match/copy spans |
| `readPrefixCodeRuntimeInto` variants | ~8.8% combined | Huffman table build |

Implication: there is no high-confidence local edit that clears the 3%
adoption bar. After correcting the Sha2 attribution, the real decoder
hotspots are only the structural memset (per-block table build) and the
payload loop, which is already register-tight. The candidate work therefore
stays a structural payload fusion or a table-build reuse project, each
requiring its own paired A/B rather than an opportunistic tweak.


## memset root-cause follow-up (2026-11-16)

Deeper source inspection of the 23% memset share shows it is structural
table/state construction, not a removable repeated fill:

- `huffman.HuffmanTable.init` (src/huffman.zig) already keeps a no-memset fast
  path for fully covered tables and only memsets partial-coverage tables; the
  historical double-fill cost was removed.
- `buildTailLookup` memsets at most 256-1024 bytes once per table; uncovered
  slots must be zeroed before selective fills, so it is unavoidable per build.
- `readPrefixCodeRuntimeInto` simple (kind==1) paths only touch a 4-entry
  length array; the cost concentrates in the complex/table-build paths.
- The incremental owned decoder has no cross-meta-block header/tree cache
  today: every meta-block re-parses its header and rebuilds Huffman tables.
  That re-build is the source of the aggregated memset and prefix-code share.

The corresponding structural opportunity is a block-type keyed table reuse
cache (RFC 7932 lets repeated block types share identical trees), but it needs
a correctness design for header identity, retention bounds, and reset
semantics before any A/B. It is a separate project from payload fusion and
must not be attempted as an opportunistic local edit.

## Table-reuse design skeleton for the next session

Target: the 23% memset / ~9% prefix-code build share from rebuilding every
meta-block's Huffman tables. Concrete plan, smallest safe candidate first:

1. Reuse key. RFC 7932 block-type indices reference trees declared once in
   the meta-block header. A table is reusable across meta-blocks only when the
   full serialized tree definition (code lengths / explicit symbols) is
   identical, not merely when the block-type index matches. Start by hashing
   the encoded prefix-code bit range (the exact reader checkpoint span) so
   identity is proven on bytes, avoiding any semantic-equivalence assumptions.
2. Storage. Add an opt-in, bounded cache on the decode workspace (not the
   stack header), keyed by that hash, holding the built `PrefixCode` plus its
   tail-lookup. Cap entry count and total bytes; on overflow fall back to a
   fresh build so memory stays bounded exactly like today.
3. Lifecycle. Scope the cache to one stream/frame; clear on `reset`/
   `nextFrame` and whenever a dictionary or large-window option changes, so
   existing transaction and reset tests stay valid.
4. First candidate. Cache only the literal trees (largest, 256-symbol,
   highest rebuild frequency); leave command/distance trees on the existing
   path to bound blast radius.
5. Verify. Output must stay byte-identical (differential wire validation),
   all `test-br` suites green, then paired A/B on `baseline.csv` with the
   3% geomean / 95% CI / 0.98x control floor. Reject and archive if not met.

Do not start from a block-index-only key: identical indices in different
meta-blocks can carry different trees, which would silently corrupt output.

## Meta-block count measurement (2026-11-16): table reuse does not apply

A direct probe (`br.summarizeStream` on the benchmark's 1 MiB q8 clustered
frame) reports exactly one compressed meta-block:

```
METABLOCKS compressed=1 uncompressed=0 total=1 wire=1049002
```

`max_uncompressed_meta_block_len` is 2^24 (16 MiB), so all current benchmark
frames (max 1 MiB) are single-meta-block. addr2line maps the memset samples to
`readCompressedHeaderCommandTrees` -> the per-frame Huffman table builds in
`readPrefixCodeInto`/`readPrefixCodeRuntimeInto` (src/br.zig 17341-17419).

Consequence: the cross-meta-block table-reuse cache from the earlier design
skeleton cannot fire on these workloads and would not reduce the 23% memset
share. The memset is the one-time, mandatory initialization of each frame's
Huffman lookup tables: `HuffmanTable.Decoder.init` already has three tiers
(no-memset for full coverage, long-prefix-only clear, full memset for partial
coverage), and the partial-coverage memset is required so uncovered lookup
slots hold a known-invalid value. There is no safe local reduction.

Revised direction: do not build the table-reuse cache for this benchmark.
The realistic decoder levers are (a) the payload state-machine fusion on the
22% `processTailLookupCompressedPayload`, which is independent of meta-block
count, or (b) measuring larger-than-16 MiB inputs first if table reuse is ever
revisited, since only they produce multiple meta-blocks.

## Hotspot stability re-check (2026-11-16)

A second `perf record -F 999` run (421 samples) reproduces the same ranking as
the first (703 samples), so the conclusion is not sampling noise:

| symbol | run 1 | run 2 |
| --- | ---: | ---: |
| `compiler_rt.memset` (one-time per-frame table build) | 23.09% | 29.62% |
| `processTailLookupCompressedPayload` | 22.02% | 26.70% |
| `memcpyFast` (match copies) | 5.96% | 4.71% |
| `PrefixCode(256).decodePrepared` | 2.82% | 4.21% |

The literal fast path `HuffmanTable.Decoder.decodeValueFast` (and its fixed
9/10-bit variants) is already a tight inline peek + zero-slot check + staged
advance with branch hints; there is no removable per-symbol overhead. This
reinforces that the only structural decoder lever independent of meta-block
count remains the payload loop fusion, and it must clear the 3% A/B bar to be
adopted rather than landing on intuition.

## Rejected experiment: decodePrepared nine-bit peek specialization

Change: in `PrefixCode.decodePrepared` (src/br.zig), select the dedicated
`fast_bit_reader.Reader.peekBits9Padded` when `lookup_bits == 9` and the reader
exposes it, falling back to the generic `peekBitsPadded` otherwise. Literal and
command trees use nine-bit lookups, so this removes a generic width/mask on the
hottest decode sites. Correctness held (227 incremental + 37 fuzz tests green,
byte-identical).

A/B (two baseline and two candidate 500-iteration runs, paired per-case means):

- first single-baseline comparison looked like +1.7% geomean, but a second
  baseline run showed that was run-to-run drift, not the change;
- paired geomean speedup over the two baselines: **+0.24%**, inside the
  +/-2% noise band; clustered_q8 +0.22%;
- no control row below 0.98 (worst 0.9897), so it is safe but not effective.

Decision: rejected and reverted. LLVM already constant-folds the comptime
`lookup_bits` mask in the generic path, so the specialization has little to
remove. Recorded so the same idea is not retried without new evidence. The
3% adoption bar still stands; payload control-flow fusion remains the open
structural lever.
