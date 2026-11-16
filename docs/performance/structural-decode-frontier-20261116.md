# Structural decode frontier after the 2026-11-16 local screens

## Purpose

The 2026-11-16 sessions closed the local, policy and table-shape levers for the
three wire codecs and landed three zstd routing/state increments. This note
records the measured frontier and the structural projects that remain, so the
next session starts from a design rather than another micro-experiment.

## Measured state

Level-1, one-shot, single-thread, ReleaseFast, Silesia corpus, the same
libzstd-1.6.0-produced wire for both decoders, paired min-of-five:

| codec | reference | median V/R | notes |
| --- | --- | ---: | --- |
| Deflate | libdeflate 1.10 | 0.940 | flat ~6% common-path deficit; two high-compressibility wins |
| zstd | libzstd 1.6.0 | ~0.80 | cumulative 0.6957 -> 0.7973 after the three increments |
| Brotli | tuned libbrotli 1.2.0 | 1.017 | parity; `mr` weak row 0.790 |

The zstd increments are `1f667638` (wide-executor cursor/FSE-state
localization), `e80fc15c` (single-sequence literal decode once), and
`ed25d1e5` (16 KiB compressed-literal split threshold). `mr` moved
0.621 -> 0.756 and `x-ray` 0.336 -> 0.781 in the process.

## Closed levers (do not retry without new evidence)

- zstd wide/dense executor: cursor and FSE-state localization (adopted);
  pair path for the wide executor (dickens -8.4%); zero-literal wildcopy skip
  (neutral); compact-executor routing (geomean 1.0002); `readSequenceField`
  in the generic reader (neutral).
- zstd policy: split literal threshold 16 KiB (adopted); sequence thresholds
  256/128 (broke the policy invariant and did not beat the literal threshold).
- Brotli `mr` long-code scan: 11-bit and 12-bit roots and a 10-bit root plus
  direct two-level blocks all left Vort's **absolute** throughput unchanged
  (359 vs 357 MiB/s). Paired-ratio moves in those runs were reference-side
  drift; the tuned libbrotli reference varied by 30-40% on this host.
- Deflate semantic loop: the prior exhaustive screen already rejected table
  shape, speculation, cursors/checks, storage and layout edits.

## Structural candidates

1. **zstd sequence executor representation v2.** The dense/wide executor still
   executes about 1.3x libzstd's instructions per sequence. A reserved-margin
   fast region could drop the per-sequence literal-end and output-capacity
   checks for most of a block while keeping the tail on the checked path; a
   two-phase token/plan representation could separate the FSE chain from the
   copy chain.

   Instruction annotation of the wide executor after state localization
   attributes 9.9% `cmp`, 2.8% `test` and 0.7% `jcc` inside the function; the
   two bounds checks are only a subset of that, while a plan adds a write and
   a read per sequence. The expected value of the plan variant is therefore
   **negative**, and the reserved-margin variant is bounded by the same
   compare share. Do not start either prototype without a cheaper plan
   encoding or a new measured profile.
2. **Deflate token two-phase decode.** The semantic loop is over half of the
   decode time and already fuses four-literal batches, packed entries and
   secondary lookups. A chunked token buffer (decode N tokens, then apply)
   would trade a token write/read for better ILP. Expected 5-8% only if the
   copy work currently extends the Huffman chain; high implementation risk.
3. **Brotli single-tree literal reservoir.** The 256-symbol Huffman lookup is
   the remaining `mr` cost. Root/table widening and two-level tables are
   closed; a local bit reservoir that decodes several literals per reload
   would only remove the reader update, not the lookup. Expected <3%; low
   priority.
4. **Encoder freeze.** Encoder quality/speed parity remains open by policy;
   lifting the freeze needs explicit user authorization.

## Gates for a structural prototype

- Build it as a standalone tool or an isolated function first; never replace
  the production executor before the prototype clears the paired A/B.
- Paired two-baseline A/B on the twelve-file corpus: >=3% geometric mean, 95%
  CI excluding parity, no control below 0.98x, no wire/ratio change.
- Full `test-zstd`/`test-br`/`test-deflate` families plus `check-wasm` before
  adoption; malformed-stream and truncation contracts must stay byte-exact.
- Record the raw samples and the prototype commit in `docs/performance/data/`.

## Reference availability

- Deflate: libdeflate 1.10 and zlib 1.2.11 are installed. zlib-ng 2.3.90
  (`~/Work/zlib-ng/build`, static compat) and libdeflate 1.26
  (`~/Work/libdeflate/build-vort`) are now built locally; the first modern
  streaming matrix is recorded in
  [data/deflate-incremental-crc-20261116](../data/deflate-incremental-crc-20261116/README.md).
- zstd: locally built libzstd 1.6.0 (SHA-pinned) is the decode reference.
- Brotli: locally built tuned libbrotli 1.2.0 (`-O3 -march=native -flto`) is
  the decode reference; the reference side is noisy on this host, so
  single-variant A/B must use Vort's absolute throughput and rerun the
  baseline.

## Disposition

The measured decode gaps are now dominated by intrinsic per-symbol/per-sequence
work rather than removable local structure. The next credible levers are
target-specific assembly kernels (a portability boundary that needs explicit
authorization and a scalar fallback) or encoder quality/speed (frozen by
policy). Neither should be started without the corresponding authorization.

## Zstd public level-1 policy finding (2026-11-16)

`encodeFrameWithLevelAlloc(..., 1)` on the 128 KiB `dickens` prefix measured
**7.56 MiB/s at 50,404 bytes**, while libzstd 1.6.0 level 1 measured
**316.8 MiB/s at 56,148 bytes**. The forced fast selection
(`--native-selection fast_compressed`) measured **76.2 MiB/s at 63,414 bytes**.

The default level policy runs a multi-candidate adaptive split ladder and calls
`std.Thread.spawn` up to three times **per encode call**
(`encodeFrameWithLevelAndOptionsAllocImpl`), which the architecture rules
forbid for per-call work. The ladder buys about 21% smaller output than the
fast selection at roughly 10x the time; Vort's fast selection is still 13%
larger than libzstd level 1 and about 4x slower.

The user chose to align levels 1-2 with the industry speed-first preset
semantics. Levels 1-2 now resolve to one `.fast_compressed` primary frame in
every public level entry point; on the 128 KiB prefix level 1 moved to
**77.11 MiB/s at 63,414 bytes** and level 2 to **76.02 MiB/s at 63,414 bytes**
(13-18% larger than libzstd, about 4.1x slower). Evidence:
[data/zstd-level12-fast-20261116](../data/zstd-level12-fast-20261116/README.md).

The migration also removed the levels 1-2 coordinator overlap, unified alloc,
append, into-slice, bound, dictionary, dictionary-set, and reusable surfaces,
and aligned the FastCover scoring codec with the public policy. Golden level
wires and the default-level FastCover score expectations were re-frozen; the
earlier reusable/one-shot "357 versus 314 bytes" mismatch was a stale test
binary, not a window-policy difference. `test-zstd` is green with the policy
active.

The level-3+ ladder is still ratio-first and slow (3.65 MiB/s on the same
prefix), but its per-call `std.Thread.spawn` fan-out is removed: candidates now
run serially with identical wires and no measurable throughput loss. The
recursive mixed search is now structured-block-only and serial; on wide blocks
it measured no size benefit while taking 25.6 s per 128 KiB encode, so level 9
drops to about 0.25 s. The multi-duplicate planner is capped at two
matches for the same reason: byte-identical level-9 frames on twelve Silesia
files with about 2.8x geometric-mean throughput. The explicit parallel
seekable encoder remains the only thread-spawning boundary.
