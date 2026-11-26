# Next prepared DEFLATE slice: dynamic planning

This is a read-only design follow-up. It does not expand the current frozen
fixed candidate, bypass its acceptance gates or claim a measured improvement.

## First boundary

Support prepared dynamic encoding before adding best selection. Share the
existing prepared greedy/hash token workspace through a small internal module,
while retaining `PreparedRawFixedEncoder`'s public contract. Each dynamic
operation plans the actual input once, prepares one entropy plan, computes its
exact size and emits directly into the caller's output.

The ordinary dynamic path is `planTokensAlloc` followed by
`encodeRawDynamicTokensAlloc` in `src/deflate.zig`. Extract `DynamicCodingPlan`
into `src/deflate/encode/dynamic_plan.zig` behind a small codec adapter. Reuse
its current `init`, `bitCost` and `writeReserved` behavior, including frequency
completion, canonical Huffman construction and code-length RLE order.
Keep `bitCostReference` as an independent per-token cost oracle.

## Capacity and publication

The dynamic alphabets are fixed at 286 literal/length, 30 distance and 19
code-length symbols. Code-length RLE has at most 316 operations. Huffman
construction does not require an allocator, so a fixed-capacity entropy
workspace can be prepared once. If stored in owned heap, it must use the same
stable Controller, update requirements and participate in actual retained
capacity, alias, exact-cap and OOM accounting. Inline/stack storage must remain
explicit in the memory scope.

Validate tokens and prepare canonical encoders before output admission. Use
checked frequency/bit arithmetic and `ceil(bits / 8)` for complete wire size.
All expected rejections occur before writing output; stats are published only
after success. Preserve inherited sticky refusal, per-call profile detachment,
append-prefix preservation and zero backing requests after preparation.

## Best requires a separate proof

Ordinary best already compares exact candidate costs and writes its winner
once. Reuse its existing selector rather than introducing a second candidate
policy. Closed-byte-size ties prefer stored, then fixed, then dynamic. Preserve
stored fast-path admission and the full-hash best dense-Huffman branch, whose
tree and wire may differ from ordinary dynamic initialization.

A stored winner still reads plaintext. The fixed API's input/output overlap
proof relies on all input having become tokens; that proof does not apply to
stored output. Best needs a charged plaintext snapshot or a separately proven
overlap-safe sink. Do not include best in the first dynamic-only increment.

## Required evidence

Compare complete prepared dynamic wire with the unchanged public allocating
oracle, exact size with the per-token cost oracle, and decoded content with an
independent inflater. Cover empty/no-match inputs, sparse and full alphabets,
length/distance extra-bit boundaries and scan/tiny/full matcher routing.

Use varying inputs within one prepared declaration to verify zero backing
requests. Cover exact heap cap/cap-minus-one, OutputTooSmall, failed prepare
preserving the prior configuration, append prefixes, guards and inherited
profiles. Best later adds all three winners, byte ties, 65535/65536 stored
boundaries, dense planning and overlapping input/output.

Run matched whole-operation A/B on a newly frozen source epoch. The current
fixed campaign's samples cannot stand in for dynamic/best acceptance.
