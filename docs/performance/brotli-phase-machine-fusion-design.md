# Brotli phase-machine fusion design boundary

## Why this document exists

Eight adopted decode increments took the libbrotli 1.0.9 reference/Vort
48-row geomean from 0.7154 to 0.7843 (2026-11-09/10). Four further
micro-fusions were measured and rejected
([2026-11-10 rejections](brotli-decode-current-20261109.md#rejected-micro-fusions-in-the-auxiliary-payload-2026-11-10)).
The remaining gap is structural: `processExternalLiteralLookupCompressedPayload`
holds 67.8% self time on `nci.64k` q6 with a flat profile, IPC around
2.1, and 3.82% overall branch misses that local caching cannot remove.
This note records the design boundary for the next milestone rather
than attempting the rewrite incrementally.

## Reference structure (libbrotli `dec/dec/decode.c`)

`BrotliDecoderDecompressStream` is one `switch (s->state)` over a
persistent `BrotliRunningState` enum (state.h lines 112-138). The
compressed-body states are:

- `COMMAND_BEGIN` -> `ReadCommand` (insert/copy lengths, block switch)
- `COMMAND_INNER` -> literal Huffman loop, with a preloaded-symbol
  fast sub-loop (`BrotliCopyPreloadedSymbolsToU8`) that computes how
  many iterations skip every block/ring/input check, then a checked
  remainder
- `COMMAND_POST_DECODE_LITERALS` -> implicit-distance ring update or
  `ReadDistance` with its own block switch
- `COMMAND_POST_WRAP_COPY` -> the LZ77/static-dictionary copy
- `COMMAND_INNER_WRITE` / `POST_WRITE_1` / `POST_WRITE_2` -> ring buffer
  flush states that suspend on `NEEDS_MORE_OUTPUT` and resume without
  re-decoding

Every suspension stores the enum state and returns; the next stream
call jumps directly to the matching label. Ring-buffer writes are
separated from symbol decoding, so the hot phase never bounds-checks
the caller output per symbol.

## Vort current structure

`processExternalLiteralLookupCompressedPayload` is one `while` loop over
commands with three inline phases per iteration (command symbol ->
literal run -> distance -> match copy). It writes directly into the
caller-owned output with per-iteration headroom checks, and keeps block
state in cached locals. This is fast for one-shot whole-frame decode but:

1. every phase's branches stay live in the same register-allocated loop
   body (the measured 3.82% branch-miss floor);
2. output headroom is re-derived per command rather than owned by a
   separate write state;
3. there is no suspend/resume representation, so the same logic cannot
   serve bounded-output streaming without a second decoder path.

## Fusion milestone scope (not yet scheduled)

1. Introduce an internal phase enum plus resume labels for the
   auxiliary 10/9-bit payload only, keeping the existing function as the
   terminal one-shot wrapper. Do not change wire behavior or public APIs.
2. Move ring/output writes behind a single write-state object with the
   headroom invariant checked at phase entry instead of per symbol.
3. Split the command/literal/distance phases so each owns only its live
   state; reuse the existing block-local caches (literal lookup,
   distance trees) across phase entries.
4. Preserve every current comptime gate (npostfix distance cache,
   packed-tier fallbacks) and the dictionary-aware wrapper.

## Risks and acceptance gates

- Risk: register pressure regression of the kind observed in the
  rejected command `single_symbol` caching experiment (1 MiB rows
  +0.94% to +1.31%). Mitigation: land phase split behind the existing
  48-row five-round paired A/B with per-row ten-round rechecks for any
  row outside the 0.98x floor.
- Risk: duplicated logic between one-shot and resumable paths.
  Mitigation: the phase enum must be the single implementation; the
  one-shot entry becomes a loop that cannot hit the suspend states
  because it pre-validates full-frame headroom.
- Correctness: full `zig build test-br`, plus the Brotli reference
  matrix rerun and a libbrotli differential sample; no change to
  `InvalidHuffmanCode`/`TruncatedFrame`/`CorruptFrame` boundaries.
- This is a multi-day structural task and should not be split into
  speculative micro-commits: prior evidence shows isolated caching on
  this loop is neutral or regressive without the phase split.
