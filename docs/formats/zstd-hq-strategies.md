# Zstandard HQ strategies

Vort exposes explicit high-quality strategies alongside its existing auto,
fast, double-fast, greedy, lazy and bounded-optimal policies. Existing auto
configuration keeps its established positive-level selection and output. The
new controls describe actual Zig-native search and parsing behavior; names do
not promise byte-identical libzstd output, equal compression ratios or matching
throughput.

The reference `dfast` family is exposed under Vort's established
`double_fast` name.

| Strategy | Search and parsing |
| --- | --- |
| lazy2 | Hash-chain candidates with second-order delayed-match decisions |
| btlazy2 | Binary-tree candidates with second-order delayed-match decisions |
| btopt | Binary-tree candidates and frequency-derived integer costs |
| btultra | Wider state search, fractional costs and more match-length alternatives |
| btultra2 | The ultra parser with conditional first-block statistical training and a second parse |

The existing `.optimal` remains its original bounded fixed-price parser. It is
distinct from `.btopt`, which uses the HQ binary-tree and entropy-price path.

## Options

`FrameOptions` and `NativeFrameOptions` accept optional `hq` settings for the
five HQ strategies:

```zig
const frame = try vort.zstd.encodeFrameWithLevelAndOptionsAlloc(
    allocator,
    input,
    18,
    .{
        .strategy = .btultra,
        .hq = .{
            .search_depth = 256,
            .nice_len = 512,
            .min_match = 3,
            .max_working_memory = 64 * 1024 * 1024,
        },
    },
);
defer allocator.free(frame);
```

Depth accepts 1...65536. It bounds visited main-search nodes, including failed
prefix comparisons. Nice length accepts the selected minimum through 131072;
it is a search stopping threshold, not a maximum output match length.
Minimum match accepts 3...7. A zero memory cap is valid and can reject actual
nonempty work before allocation.

Explicit HQ settings override the concrete configuration. When omitted, HQ
defaults depend on the selected strategy and frame level; direct native calls
use level 3. These effort defaults are Vort policies. They do not imply
libzstd preset parameter parity. The library exposes resolved settings so
tools do not duplicate the default table.

An independent canonical parameter query is available through
`resolveCanonicalCompressionParameters(level, source_size_hint, dictionary_size)`.
It reproduces the versioned Zstd 1.6.0 level table and source/dictionary size
refinement, including canonical level zero meaning default level three.
Zero or the maximum u64 source hint means unknown. The existing Vort level-zero
raw/RLE encoding API retains its behavior. Queries reject levels outside
-131072...22 and overflowing logical size hints.

The returned parameters include window, hash, chain and search logs, minimum
match, target length and strategy. `hqOptions()` transfers the available deep
search controls; hash and chain logs remain reference metadata and do not
claim the same index layout. Negative Fast targets expose their acceleration
through `fastAcceleration()`.

HQ settings require an HQ strategy. Conflicting fast acceleration, legacy
match budgets, rep-beam switches, raw/literal-only selection, level zero and
negative levels are rejected before output publication. Native HQ calls retain
the legacy budget field at its default value and use dedicated HQ depth.

## Matching, costs and state

Binary-tree search indexes the entire retained dictionary/history prefix and
the current block. Bounded cyclic nodes verify absolute generations before
following links, and source arithmetic is checked before accessing bytes.
The tree shares immutable virtual spans with the scalar matcher; it does not
allocate a combined dictionary/history/block buffer.

HQ costs include literal, literal-length, match-length and offset symbols plus
format extra bits. Standard dictionary entropy tables and successfully
selected previous-block state provide costs where available. Every candidate
path preserves pending literal length and all three repeated offsets.

LL greater than zero uses rep0/rep1/rep2 selectors. LL equal to zero uses
rep1/rep2/rep0-minus-one; zero distance is invalid. Ordinary distances use
`distance + 3`. A sequence record retains the exact selected offset value so
the wire writer cannot silently choose another selector with a different cost
or future repeated-offset state.

Statistical training only updates committed HQ state. Failed sequence
candidates and raw/Huffman fallbacks keep the corresponding prior state.
The first btultra2 training pass is temporary: it collects statistics while
leaving published sequences, initial repetitions and input history intact.
The second parse starts from the original source and repeated offsets.
Cold first blocks without a dictionary or prefix, with more than eight input
bytes, can train; dictionary and later-history paths use one ultra parse.

## Resources and diagnostics

Caller allocators and `max_working_memory` make search/parser ownership
explicit. Resource failures remain errors rather than switching strategy,
skipping candidates or reducing search quality silently. Requested heap peaks
are distinct from process RSS, caller input/output, fixed codec state and OS
overhead.

`EncoderControlProfile` records tree and byte comparisons, prices, parsing and
refinement passes, seed reuse and working peaks. Work accumulates through
attempts; emitted block/reference counts only describe published wire and roll
back with failed emission. Disabling diagnostics preserves encoded bytes.
Independent seekable entries use private state and deterministic profile
reduction.
