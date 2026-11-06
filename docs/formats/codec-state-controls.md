# Codec state and dictionary controls

These controls add caller choices that exist in the reference libraries while
preserving Vort's default wire behavior and allocator ownership.

## Deflate stream copies

The seven raw stored/fixed/best and zlib/gzip fixed/best incremental encoder
types expose `clone(allocator)`. A clone copies owned buffer capacities and
contents, matching indexes, retained history, pending output and partial bits.
Both branches keep the same accepted-input and delivered-output counts and can
then continue, flush, reset and deinitialize independently. Previously delivered
output is shared stream prefix data; callers retain it when assembling the two
complete streams. Allocation failure leaves the source unchanged and cleans up
all partially constructed owned storage.

The general raw incremental decoder and its zlib/gzip wrappers expose
`cloneInto(destination, storage)`. The destination has a stable address.
`CloneStorage.history` supplies independent caller-owned history with at least
the geometry reported by `cloneHistoryLen()`. When the source has an attached
semantic workspace, supply a separate workspace of the same type through
`CloneStorage.semantic_workspace`. The copy retains partial headers, symbols,
matches, pending semantic output, table generations, checksums and wide counts,
and rebinds compact Huffman pointers to the destination's tables. The stored
decoder also exposes a state-only `cloneInto(destination)`.

`DeflateCloneError` is separate from the general codec error set. Invalid
storage geometry and overlapping source, destination or workspace ranges are
rejected before modifying caller storage. Decoder state and attached workspace
addresses remain stable during their use.

Immutable preset dictionary bytes, gzip metadata and explicitly borrowed
configuration remain borrowed. Keep those bytes alive while either branch
needs them. Owned buffers and mutable decoder history/workspaces are independent.

## Brotli literal context policy

`BrotliPlannedEncodeOptions`, `BrotliPlannedStreamChunksOptions` and
`BrotliHqOptions` expose `disable_literal_context_modeling`, defaulting to
`false`. The outer option or nested HQ option can disable the feature. The
policy applies through q0...q11, legacy levels, one-shot, chunks, reusable and
incremental frontends, standard and Large Window formats, and dictionary paths.

With the option enabled, all 64 literal contexts within each literal block
type map to one Huffman tree. Literal block splitting, distance context trees,
recent-distance commands and contextual static/shared-dictionary choices remain
available. Candidate scoring, prepared/grouped alternatives, compact command
state, HQ and final emission use the same policy. The reference parameter is
`BROTLI_PARAM_DISABLE_LITERAL_CONTEXT_MODELING` (4).

The resolved HQ policy adds eight bytes to the caller-owned `HqProfile`
layout. The option preserves HQ working-heap accounting. Current default/false
wire controls and heap invariants are checked separately.

## Zstd dictionary ID policy

`ZstdFrameOptions` and `ZstdNativeFrameOptions` expose
`include_dictionary_id`, defaulting to `true`. Setting it to `false` omits the
Dictionary_ID field from the frame header. The selected dictionary keeps its
real identity, full standard-dictionary entropy tables and history. Header-size
and encoded-bound calculations use the resulting wire ID; dictionary selection
and prepared state use the real ID.

The option propagates through level resolution, one-shot, chunks, reusable,
known/unknown-size incremental, persistent parallel, seekable, standard/magicless
and ZIP consumer paths. The corresponding reference parameter is
`ZSTD_c_dictIDFlag` (202). To decode an ID-less frame that depends on a full
dictionary, select that dictionary explicitly. A dictionary catalog cannot infer
its identity from an absent frame ID.

## Reproducible validation

Each feature has native, x86 and actual WASI contract gates:

```sh
zig build -j2 test-deflate-clone
zig build -j2 test-br-literal-context-control
zig build -j2 test-zstd-dictionary-id-control
# Append -x86 or -wasm to each test step for those execution targets.
zig build -j2 run-deflate-clone-preflight-diff
zig build -j2 run-br-literal-context-control-preflight-diff
zig build -j2 run-zstd-dictionary-id-control-preflight-diff
# Remove -preflight for the complete bounded reference matrix.
```

Deflate validation assembles and decodes actual common-prefix/forked-tail
streams, compares copy behavior with `deflateCopy`/`inflateCopy`, and checks
independent destruction, pending bits/output, semantic generations, overlapping
storage and allocation failure. Wide-count models are identified as models.
Brotli validation observes complete context maps from an independent decoder
and verifies that an enabled-context control actually uses the feature. Zstd
validation uses full standard dictionaries with the loaded reference library;
raw-content substitution does not establish entropy-table preservation.

Reference tools retain per-case commands, decoded bytes, actual probe/library
and matching header/source hashes. WASI receipts are installed as
`zig-out/deflate-clone-wasm.json`,
`zig-out/br-literal-context-control-wasm.json` and
`zig-out/zstd-dictionary-id-control-wasm.json`.

The 2026-11-07 reference campaign passed 171 native/x86/WASI Deflate fork
cases and 37 host zlib 1.2.11 copy cases, decoding 15,787,296 actual bytes.
The counter-base cases identify their `2^32` coordinates as logical models.
The Brotli native/x86 matrix passed 390 cases, checking 53,376 context-map
entries across 834 compressed meta-blocks, with 92 enabled-context witnesses
and 30 archived default-byte controls. The Zstd native/x86 matrix passed 404
cases with 216 independent full-dictionary decodes and 12 generated
entropy-table witnesses. All 72 default/true pairs are byte-identical; all 72
true/false pairs differ only in the dictionary ID field and its header bits.
The generated witnesses use initial LL repeat tables and reject the same
history supplied as RAW content after successful dictionary loading.
