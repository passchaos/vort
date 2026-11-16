# Zstd level-1 wide-executor state localization, 2026-11-16

## Why this package exists

The 2026-11-16 full-Silesia sweep measured zstd decode at the reference
bench's default **level 1**, while the earlier serial-entropy-wall profile used
level-19 64 KiB prefixes. A fresh `perf` instruction sample on level-1
`dickens` shows the dominant path is
`zstd.tryDecodeAllFseSplitWideHuffmanSequences`, and that Vort executes about
159 instructions per sequence there versus about 117 for libzstd 1.6.0 on the
same libzstd-produced wire. The executor was **instruction-throughput bound**,
not stalled on the FSE recurrence.

The wide executor kept the caller-owned output cursor, the three FSE states
and the repeated offsets in `SequenceDecodeState`, so every sequence reloaded
and stored them through a pointer that match/literal copies can alias. The
compact and medium executors already localized the cursor and states and
measured a gain (see `zstd-downloads-corpus.md`); the wide executor had not
received the same treatment.

## Change

`src/zstd.zig`, `decodeAllFseSplitHuffmanSequences`:

- keep `output_cursor` in a local with `defer written.* = output_cursor;`, so
  the per-sequence helpers receive `&output_cursor` instead of the caller
  pointer that can alias output memory;
- keep `ll_state`, `ml_state` and `of_state` in locals and commit them once
  after a successful block;
- leave `state.reader`/`state.remaining` handling unchanged.

`state.repeated_offsets` localization was tested and **rejected**: alone it
measured 0.5685 versus a 0.7272 baseline ratio on `dickens` (about 21.6%
slower), because taking the address of the local array added stack traffic and
register pressure. The shipped change does not touch repeated offsets.

Both production instantiations of this function (`use_wide_copies` for the
wide path and `use_long_match_wildcopy` for the dense path) use
`use_grouped_fields = true`, so the same locals serve both.

## Method

`run-zstd-reference-bench` on all twelve Silesia files at level 1, 20
iterations, one round, one-shot single-thread decode, ReleaseFast on the
i7-10700K. The bench encodes once with the selected libzstd and both decoders
consume that **same wire**, so this is a decoder-only comparison. Each run is
paired (Vort/libzstd) with five alternating rounds and the minimum retained
per side; the ratio is the reported metric.

Baseline: `../wire-zstd-1.6.0-current-20261116/` (libzstd 1.6.0, SHA-pinned).
After: `comparison.csv` and the twelve per-file CSVs in this directory.

## Results

`speedup` is `after_ratio / before_ratio`; both ratios are Vort/libzstd 1.6.0
throughput, so greater than 1 is a Vort improvement.

| file | before | after | speedup |
| --- | ---: | ---: | ---: |
| dickens | 0.7333 | 0.8064 | 1.0997 |
| mozilla | 0.7706 | 0.7983 | 1.0359 |
| mr | 0.6026 | 0.6144 | 1.0196 |
| nci | 0.7874 | 0.7876 | 1.0003 |
| ooffice | 0.7731 | 0.7933 | 1.0261 |
| osdb | 0.7595 | 0.8030 | 1.0573 |
| reymont | 0.7130 | 0.7990 | 1.1206 |
| samba | 0.7582 | 0.7908 | 1.0430 |
| sao | 0.7951 | 0.8187 | 1.0297 |
| webster | 0.7653 | 0.8331 | 1.0886 |
| xml | 0.7606 | 0.7774 | 1.0221 |
| x-ray | 0.3264 | 0.3364 | 1.0306 |

Twelve of twelve rows improve. Geometric mean speedup **1.0472**; median ratio
0.7606 to 0.7983. The gain is largest on text (reymont, dickens, webster) and
smallest on `nci`, which routes through a different executor.

## Mechanism verification

A repeated `perf record -e instructions` run on the same 300-iteration
`dickens` workload confirms the mechanism:

| | before | after |
| --- | ---: | ---: |
| total instructions (approx.) | 603.7B | 582.3B |
| wide-executor share | 56.09% | 54.88% |
| wide-executor instructions per sequence | 158.6 | 149.7 |

The executor executes 5.6% fewer instructions per sequence; the whole-decode
gain is larger (about 10% on `dickens`) because removing the caller-pointer
alias barrier also frees scheduling and memory-disambiguation work that does
not appear as a raw instruction count.

## Validation

- `zig build test-zstd` passes.
- `zig build test-zstd-huffman-x2` passes.
- `zig build test-zstd-decode-memory` passes 44/44.
- `zig build test-zstd-source-reverse` and
  `zig build test-zstd-compressed-workspace` are recorded separately below.
- `test-zstd-decode-memory-wasm` compiles but its node gate exits 201 on the
  **unmodified baseline as well**, so that gate is a pre-existing
  environment/runtime condition, not a regression from this change.

## Scope limits

Single host, one-shot decode, 20 iterations, no CPU pinning. The paired
libzstd ratio controls host drift; absolute throughput moved slightly between
the baseline and after runs. No encoder, streaming-throughput, RSS or other
platform claim is made. The rejected repeated-offset localization is kept as
evidence so a future session does not retry it as an assumed win.
