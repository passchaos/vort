# Full-window Brotli modeled refinement screen

The ordinary q10/q11 fixed-price seed uses a 32 KiB distance table. The first
prototype keeps that seed, learns a complete window16 Brotli distance model
and solves with the full legal 65,520-byte window. It preserves the original
narrow complete-wire candidate when the wider solve selects a far edge. If
the wide solve has no selected far edge, independent same-model/same-budget
tests prove that its complete command plan equals the narrow solve. A seed
with no four-byte matches can learn from the already available full-window
lazy command plan instead. Command-state search stays within its original
32 KiB limit.

This candidate is not adopted as the default. The full-window distance model
is valid and improves two corpus streams, but the measured throughput cost is
too high. The retained source change is an independent safety fix:
`lz77.OptimalCostModel.validate` now rejects windows above `max(u16)`, even
when the caller supplies a fully covered nonzero price table. That check
protects allocating, reusable and prepared modeled solves before a distant
token reaches its narrowing cast.

## Ordinary evidence

Zig 0.16.0 LLVM ReleaseFast, Linux x86-64/Skylake, Intel i7-10700K, one codec
thread on CPU 2. Baseline is the preceding grouped joint-context increment,
reconstructed from `fdcc266ede4d36b460fd0d9db3e385146638ac9c` plus the declared
Zstd, LZ77 and Brotli overlays. The public quality API receives q10/q11,
generic mode and default window bits 16. Each process does a startup
encode/decode, one timed allocating encode, then complete-wire compare/free
outside timing. Three serial AB/BA sweeps cover six Silesia 64 KiB prefixes.

| First screen | Candidate / baseline time | Compressed-size ratio |
| --- | ---: | ---: |
| q10 | `1.373308` | `0.998778` |
| q11 | `1.301129` | `0.998778` |

Dickens falls `24501 -> 24462` bytes and NCI `4191 -> 4167`; MR, Mozilla,
OOffice and X-ray do not shrink. Every timing point regresses, with no paired
win in the first 72-process screen. X-ray's reference-size gap is therefore
not resolved by this window proposal.

A separate four-way screen compares the baseline, wide solve, wide solve
with exact command-duplicate suppression, and the original narrow solve with
the same suppression. It covers 144 serial processes.

| Control | q10 time ratio | q11 time ratio |
| --- | ---: | ---: |
| Wide | `1.369045` | `1.300106` |
| Wide, duplicate commands suppressed | `1.372057` | `1.297024` |
| Narrow, duplicate commands suppressed | `0.999730` | `1.002798` |

The wide controls keep the same per-input complete wires and `0.998778` size
ratio. Narrow duplicate suppression preserves the baseline complete wires.
These observations reject both the default full-window proposal and the
standalone duplicate-control change for this increment. No proxy-only gain
or comparison between the two measurement epochs is claimed as an adopted
performance improvement.

## Exactness and safety

Independent modules verify three de Bruijn fixtures whose repeated four-byte
anchors occur only at distances 32,768, 32,769 and 65,520. All anchor
collisions and index reachability are checked before parsing. The wider model
retains byte-identical near-distance costs, validates its nonzero length and
literal terms, and produces tokens that replay to the exact input.

Eight actual learned models across three matching budgets give 24 complete
plan comparisons: 12 owned no-far results and 12 far results. A separate
actual learned null-proposal case checks that both solves remain literal-only.
The no-far equivalence applies to the same frozen model, same candidate
budget and same nearest-first match order; it does not apply to retrained
models or a finite command-state beam.

Native Debug/ReleaseFast, 32-bit x86 Debug and actual wasm32-wasi ReleaseFast
each pass all five independent contracts. Missing/zero prices, fully covered
window=65,536, 32-bit cost representation and all allocation-failure points
are covered. The retained generic window check also has library regressions
for allocating, reusable and prepared APIs at the invalid 65,536 boundary and
valid 65,535 window.

[The evidence package](data/brotli-wide-modeled-screen-20261030/) retains both
raw campaigns, source overlays, immutable inputs, complete contract sources,
actual Wasm modules and a read-only reducer. The native executable bytes are
not archived; their recorded SHA256 identities and build commands are retained.

This work exposed a separate ratio gap: no-LZ-match input was sent directly
to stored output even when a literal Huffman tree could shrink it. Subsequent
work should retain an explicitly budgeted literal-only entropy candidate
across ordinary, streaming, reusable and caller-buffer APIs, with full stored
arbitration and actual resource limits. The full compression goal remains active.
