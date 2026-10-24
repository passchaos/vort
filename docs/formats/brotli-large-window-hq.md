# Brotli Large Window HQ encoding

The implementation and its small- and large-data validation are recorded in
the [functional baseline](../performance/brotli-large-window-functional-baseline.md).
Standard-format output remains the default.

`PlannedEncodeOptions.large_window` and
`PlannedStreamChunksOptions.large_window` explicitly select the Large Window
extension. This document describes its HQ quality 10/11 path; the
[general Large Window contract](brotli-general-large-window.md) covers the
subsequent q0...q11, legacy and stored expansion. Standard windows remain
10...24; Large Window accepts 10...30. Enabling the extension at a width below
25 still emits the extension and uses its distance format. The container's
existing default window does not change.

## Header and distance alphabets

The extension header contains fourteen bits, least-significant bit first:
`((window_bits & 63) << 8) | 0x11`. Decoders must enable Large Window handling
before reading it. Vort uses `DecodeOptions.allow_large_window`; the Brotli
reference uses `BROTLI_DECODER_PARAM_LARGE_WINDOW` with value one. The library's
existing shared-dictionary decoding policy also remains applicable.

The standard distance wire alphabet is
`16 + NDIRECT + (24 << (NPOSTFIX + 1))`. The Large Window wire alphabet is
`16 + NDIRECT + (62 << (NPOSTFIX + 1))`, through 1128 symbols. The theoretical
62-bit range determines simple Huffman symbol widths; the supported encoder
does not emit arbitrary 62-bit physical distances.

The effective distance alphabet retains only complete code groups within the
signed-safe physical bound `0x7FFFFFFC`. Its maximum capacity is 544. Costs,
frequencies and complex-tree construction use this active prefix. Simple-tree
symbol literals use the full wire alphabet: the maximum shape needs eleven
symbol bits, even though its active symbols fit in ten.

`HqDistanceFormat` distinguishes `standard` and `large_window`.
`HqDistanceParameters.wireAlphabetSize`, `activeAlphabetSize` and
`maximumDistanceForFormat` expose the corresponding values. Existing methods
retain their standard-format behavior. `Resolved`, `Source`, plans, models and
exact command encodings carry the selected format to the actual wire writer.

The safe global bound is not the maximum encodable regular distance for every
shape. For `(NPOSTFIX=0, ndirect_high=0)`, the active alphabet has 74 symbols and
reaches 2147483644. Changing `ndirect_high` to one still gives 74 symbols but
reduces the maximum to 1610612733. The largest shape `(3,15)` has 544 active
symbols and reaches 1610612824. The encoder and decoder validate the complete
group boundary, symbol and extra bits for each shape.

Recent-distance selectors can legally refer to a cached physical distance above
that shape's regular maximum, while staying within the global safe bound. Each
alias remains distinct. Semantic distance zero, including an explicitly emitted
zero, leaves the recent cache unchanged. Static dictionary commands never push
the cache.

## History, dictionaries and budgets

Ordinary history is bounded by `2^window_bits - 16`; input meta-blocks remain
bounded through 16 MiB. The persistent tree retains its complete available
history, stitches pending tails across input boundaries, and uses checked
epoch-relative node coordinates with u64 absolute positions. Selecting width
30 for a tiny input does not preallocate one GiB of history. Large requested
allocations that cannot fit the target or caller budget are rejected before
allocation; the encoder does not silently reduce the advertised window.

Compound and static dictionary distances are computed separately from retained
ordinary history. With history reach `h`, compound size `c` and logical address
`a`, compound distance is `h+c-a`, while static distance is `h+c+a+1`.
Checked arithmetic and format-aware distance choices filter unrepresentable
candidates. A large dictionary can still provide reachable words near its tail;
an oversized sum does not justify rejecting every address.

The existing HQ workspace cap and the whole-encoder
[`max_total_working_memory` cap](brotli-total-encode-memory.md) remain independent.
History, tree growth/forks, parser plans and simultaneously live candidate wires
are included in their respective scopes. Requested allocation bytes do not
measure page rounding, allocator bookkeeping, internal backing-remap transients
or process RSS.

## APIs and validation

One-shot, reusable, chunks and incremental paths share the same explicit format.
Stored fallback preserves that format. Whole q11 comparison retains the complete
corresponding q10 wire. Standard-header legacy candidates are not eligible for
a Large Window request. Reset and `nextStream` replace the format rather than
leaking it into a subsequent standard stream.

The CLI uses `--large-window` alongside `--hq` and quality 10 or 11. The dedicated
`test-br-large-window` target covers small format, parameter, resource and
transaction contracts. `test-br-large-window-tree` separately exercises large
history and fork allocations, so ordinary test runs do not repeat that memory
graph. `run-br-large-window-diff` and `test-br-large-window-cli` use explicit
reference decoder opt-in and check that strict decoding rejects the extension.
`test-br-large-window-far` is the explicit ReleaseFast public-history campaign;
`test-br-large-window-extra` uses an actual RAW dictionary beyond the standard
regular-distance range. Neither large-data campaign is part of the ordinary
codec test root. `test-br-large-window-wasm` runs the real public extension APIs
in WebAssembly.

This format support does not establish reference encoder parity, global model
optimality, corpus ratio, throughput or memory leadership. Broader quality
planning and reproducible competitor measurements remain separate work.
