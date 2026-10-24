# Zstd levels, match strategies and work profiles

Vort accepts compression levels `-131072...22`. Default level 1 and the
established level 0...22 automatic policy retain their existing behavior.
Level 0 selects raw/RLE output. Negative levels select the new fast matcher;
their magnitude is the acceleration, so `-13` uses acceleration 13.

Use the central resolver when selecting a level for a native, incremental or
seekable encoder:

```zig
var profile: vort.ZstdEncoderControlProfile = .{};
const options = try vort.resolveZstdFrameOptionsForLevel(-8, .{
    .strategy = .double_fast,
    .content_checksum = true,
    .control_profile = &profile,
});
const result = try vort.zstdEncodeNativeFrameWithOptionsAlloc(
    allocator,
    input,
    options,
);
defer allocator.free(result.frame);
```

`FrameOptions` and `NativeFrameOptions` expose `strategy`, optional
`fast_acceleration`, and optional caller-owned `control_profile`. The strategy
is independent of the selection policy that chooses raw/RLE, literal-only,
automatic or fast-compressed output.

| Strategy | Implemented matching policy |
| --- | --- |
| `auto` | Preserve the established automatic candidate arbitration. An explicit acceleration selects `fast`. |
| `fast` | One four-byte hash table, recent-distance probes, and acceleration-controlled seed/miss sampling. |
| `double_fast` | Separate four-/eight-byte tables and a long-match lookahead, with acceleration-controlled sampling. |
| `greedy` | Bounded hash-chain and recent-distance search, choosing a current match. |
| `lazy` | Actual one-byte lookahead that can defer a current match for a better next match. |
| `optimal` | A bounded four-state search using fixed symbol-cost estimates and recent-distance state, over blocks of at most 32 KiB. |

These are Vort-native policies. Their names and level numbers do not promise
libzstd's corresponding algorithm, ratio or throughput. In particular, the
bounded optimal parser does not claim full binary-tree/HQ or globally optimal
wire-size parsing. Prefix sampling and candidate budgets bound encoder work.

All controlled matchers read the permitted dictionary suffix and completed
frame history, honoring the selected window and history budget. Match records
preserve wide distances rather than passing through a 16-bit DEFLATE token.
The shared Zstd sequence writer remains responsible for recent-offset coding,
entropy table state and compatible wire output. Normal large `optimal` input is
split into smaller blocks; frame bounds and incremental block planning use the
same effective block-size limit.

Acceleration accepts `1...131072` and applies to `fast`/`double_fast`.
A negative level and an explicit acceleration must agree. Level 0 cannot
combine with active matcher controls. Explicit raw/RLE or literal-only
selection/subset APIs reject active matcher controls. Search strategies use
`NativeFrameOptions.match_search_budget` in `0...512`; fast strategies require
the standard budget value, and unsupported legacy repeat-beam combinations are
rejected rather than ignored.

The profile records actual positions, hash/rep probes, sampling, candidate and
optimal work, plus committed raw/RLE/compressed blocks and dictionary/history
references. Work performed by a rejected candidate remains work; emitted
reference counters exclude that candidate. A failed complete encoding call
restores emission counters while retaining performed work. Counters saturate.
Automatic legacy paths are not instrumented by this profile: consult
`available` and `controls_used` before interpreting zero counters.

Profiles are caller-owned and accumulate until `reset()`. Keep their storage
alive through encoding and any reusable encoder configuration that retains
the pointer. Seekable parallel encoding collects private profiles and merges
them in frame order, preserving the serial wire and aggregate counters.

The CLI's four native encode commands accept named `--level`, `--strategy`,
and `--fast-acceleration` options in addition to the existing selection,
checksum and content-size position arguments. Existing calls without new
controls preserve their wire. Examples:

```sh
vort encode-zstd-native-file input.bin output.zst --level=-8
vort encode-zstd-native-file input.bin output.zst --level=3 --strategy=lazy
vort encode-zstd-native-file input.bin output.zst --strategy=double-fast --fast-acceleration=13
```

CHD's explicit Zstd compression hint accepts native signed levels. Its mixed
automatic and zlib policies retain their own nonnegative limits. OpenZFS Zstd
accepts only its representable signed FAST levels: `-1...-10`, `-20...-100`
in tens, `-500`, and `-1000`. Their on-disk metadata remains the standard
unsigned FAST enum `103...123`; it is not a signed level stored directly.
