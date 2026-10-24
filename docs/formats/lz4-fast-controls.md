# Native LZ4 acceleration and search-work controls

`Lz4BlockEncodeOptions` and `Lz4NativeFrameOptions` expose `acceleration`,
`chain_depth` and an optional caller-owned `Lz4FastEncodeProfile`. Raw blocks,
preset prefixes, reusable encoders, native frames and incremental frames use
the same resolved block controls. Incremental encoding accepts fragmented
input and retains the existing linked history and flush semantics.

## Parameter semantics

`acceleration: i32` defaults to one. Nonpositive values normalize to one;
values above 65537 clamp to 65537. `lz4NormalizeFastAcceleration` exposes that
normalization and `lz4FastMaxAcceleration` exposes the maximum.
`BlockEncodeOptions.resolve()` returns the normalized acceleration and the
validated chain depth. Invalid chain depths above sixteen return
`InvalidBlockPlan` before output allocation or publication.

Acceleration one preserves the existing bytewise native hash-chain/lazy parse
and its default wire. Larger values increase the distance between unsuccessful
match searches. Each miss episode first advances one position, then uses the
normalized acceleration for the next 64 advances, increasing the stride by
one after each further group of 64 misses. Finding a match resets the episode.
Advances are clipped to the remaining legal search range. Positions bypassed
after a miss are retained as literals and are not inserted into the hash chain.

`chain_depth: u8` remains an independent candidate-search bound from zero
through sixteen, default sixteen. Zero disables matches. Higher acceleration
changes which positions are searched; lower chain depth changes how many
candidates are inspected at each searched position. The native parser keeps
its one-byte lazy choice, backward extension and matched-region indexing.

The signed domain and speed/size tradeoff resemble liblz4's acceleration API,
but the parsers are different. liblz4 fast uses a single-hash search and also
adapts its stride at acceleration one; Vort retains its established native
default and bounded chains. Matching parameter numbers therefore does not
promise identical bytes, ratios or speed. Increasing acceleration need not
strictly improve speed or increase output size on every input.

The older `encodeFrameWithLevel*` mapping and HC APIs retain their existing
semantics. Explicit acceleration does not reinterpret negative legacy levels
as LZ4F compression levels. The fixed-destination raw `DestSize` API also
retains its existing default policy.

## Public APIs and ownership

The package root exports `Lz4BlockEncodeOptions`, `Lz4FastResolvedOptions` and
`Lz4FastEncodeProfile`. New raw block entrypoints are:

- `lz4EncodeBlockWithOptionsAlloc`, `lz4EncodeBlockWithOptionsAppend` and
  `lz4EncodeBlockIntoSliceWithOptions`;
- `lz4EncodeBlockWithPrefixAndOptionsAlloc`,
  `lz4EncodeBlockWithPrefixAndOptionsAppend` and
  `lz4EncodeBlockWithPrefixIntoSliceAndOptions`.

Options are the final argument. Prefix entrypoints keep input before prefix,
consistent with the older block APIs. `Lz4BlockEncoder` provides corresponding
allocating, append, scratch and caller-buffer methods. Existing native frame,
dictionary and dictionary-set entrypoints accept the new fields through their
existing options argument; `Lz4NativeIncrementalFrameEncoder` uses the same
options at initialization and at the next frame.

The allocator and returned ownership remain explicit. Inputs and effective
prefixes borrowing the output allocation are captured before buffer growth or
scratch replacement; nonoverlapping inputs require no snapshot allocation.
Overlap detection includes unused output capacity. Frame append failure restores
the original list length. Caller-buffer capacity failure preserves the output.
Parser work already attempted remains visible even when output publication
fails. Existing scratch results retain their documented borrowed lifetime.

Raw empty input retains the older Vort API representation of an empty slice.
That is an API convenience convention, not liblz4's canonical one-byte raw
empty block `00`: an upstream raw decoder rejects zero compressed bytes.
Native empty frames remain standard frames. Differential gates distinguish
legacy raw-empty checks from successful external raw decoding, and verify
Vort decoding of independently encoded canonical empty blocks separately.

## Actual work profiles

The profile records attempted work, including rejected output and compressed
candidates later replaced by stored frame blocks:

| Field | Meaning |
| --- | --- |
| `resolved_acceleration`, `resolved_chain_depth` | Last actual parser invocation's resolved controls |
| `positions_inspected` | Actual match-search calls, including one-byte lazy probes |
| `positions_skipped` | Legal search positions bypassed after misses; excludes matched bytes and the mandatory literal tail |
| `chain_candidates` | Actual candidate inspections within the configured depth |
| `history_positions_seeded` | Preset/linked prefix positions inserted into the hash tables |
| `match_positions_seeded` | Matched-region positions inserted after emitting a command |
| `blocks_attempted` | Actual raw parser invocations, including early reservation failures |
| `max_skip_step` | Largest actual clipped miss advance; zero when no advance occurred |

Work counters saturate and merge by addition; the maximum stride merges by
maximum. `reset()` clears work and restores default resolved fields. A profile
is caller-owned, has no hidden global state and does not change output bytes.
These counts are not CPU time, memory peaks or benchmark throughput.
An empty native frame invokes no block parser: its work counters remain zero
and its resolved fields keep their initialized defaults. These are last-parser
fields, not a record of an unexecuted configuration. A raw-empty API call does
invoke the raw parser and can record resolved controls without searching.

## CLI and verification

The native frame, raw block and raw-prefix commands accept
`--acceleration=NUM`, `--chain-depth=NUM` and `--profile`, including separated
values. File controls are validated before reading input. Native frame and raw
block file writers use atomic replacement, including same-path input/output.
The CLI prints a separate `lz4_fast_profile` record only when requested.

```sh
zig build test-lz4-fast-controls -Doptimize=Debug --summary all
zig build test-lz4-fast-controls -Doptimize=ReleaseFast --summary all
zig build test-lz4-fast-controls -Dtarget=x86-linux-musl -Doptimize=ReleaseFast --summary all
zig build test-lz4-full -Doptimize=ReleaseFast --summary all
zig build test-lz4-fast-controls-cli -Doptimize=Debug --summary all
zig build test-lz4-fast-controls-wasm -Doptimize=ReleaseFast --summary all
```

`run-lz4-fast-controls-diff` exercises actual public controls with versioned
raw/continue and frame dictionary APIs. Independent miss-schedule replay,
default-wire captures, prefix/linked history, malformed options, allocation
failure, overlap and retry checks validate behavior. The complete family target
also includes lowercase native tests omitted by the older case-sensitive
focused filter. Current evidence and its bounds are recorded in the
[functional baseline](../performance/lz4-fast-controls-functional-baseline.md).
