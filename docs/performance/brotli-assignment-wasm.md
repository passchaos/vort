# Grouped assignment correctness on Wasm

Context assignment uses a transposed `[symbol][tree]u16` cost matrix and
evaluates four adjacent trees with integer `u64` lanes. The native exhaustive
`prune=false` oracle retains its original tree-major layout and scalar loop.

The implementation prepares only active symbols and requested trees. Four-lane
loads require `tree + 4 <= tree_count`; the scalar remainder reads only active
tail trees. Costs remain frozen through each assignment round; context moves
update histograms for the next round. Ascending tree order and strict `<`
preserve the earliest tree on ties. Products widen before multiplication, and
the maximum tested sum is bounded by
`256 * maxInt(u32) * maxInt(u16) < 2^56`. Counters retain logical context/tree
evaluations, independent of SIMD instructions.

The [correctness package](data/brotli-assignment-wasm-20261028/) preserves actual
wasm32-wasi ReleaseFast unit-test modules for generic and `+simd128` targets.
Both execute the independent scalar comparison across tree counts 1–64,
empty/sparse/dense supports, maximum frequencies/costs, strict ties and inactive
cells left undefined. Emitted `target_features` confirms SIMD128 only on the
second kernel module.

The combined public q8 gate also passes against its frozen full-wire baseline
with the original 8 MiB stack. Both outputs remain 14,362 bytes, SHA-256
`b6eb2991d9848de02c4079a698b23328d122550b2af0dc119326219da6f96762`.
Its 64 KiB fixture retains 1,299 commands, 88 active command entries, one complex
command tree, 152 recent copies and two reusable candidate groups. Ordinary /
profile wire equality, Zig and Node native decoding, and wide Key checks pass.

The owner observed explicit exit 0 for the combined 9/9 Wasm gate and the
82/82 focused native literal-context gate. Logs are compressed and include that
completion evidence. Kernel/source overlays, helper/build SHA values, frozen
modules and cache paths are recorded in `evidence.json`; other source dependencies
are referenced by `c507a5c1d10dabfb4cbe9f933b9b486677c8cd04`.

`replay.py` verifies and restores artifacts without running gates by default.
Use `--execute` to run frozen modules or `--rebuild --repo REPO` to rebuild from
the dependency commit and source overlays. `SHA256SUMS` checks the package.
This records correctness evidence; ordinary performance results are maintained
separately.
