# Brotli metadata meta-blocks

Updated 2026-10-26. The full-range metadata behavior and completed functional,
reference and build checks are recorded in the
[functional baseline](../performance/brotli-metadata-functional-baseline.md).

The public constants `br.max_metadata_meta_block_len` and
`vort.BrotliMaxMetadataMetaBlockLen` are equal. The encoder accepts one metadata
body from zero through 16,777,216 bytes, inclusive. The body is opaque metadata:
it adds encoded bytes but no decompressed plaintext, match history or plaintext
position. It does not establish a content dictionary or reset history.

## Header and empty-value semantics

The shared header plan uses RFC 7932 metadata identity (`ISLAST=0`, `MNIBBLES=3`),
zero reserved bits, the minimal `MSKIPBYTES` width, and zero alignment padding.
Nonempty lengths store `body.len - 1` in one, two or three bytes. A multi-byte
length has a nonzero high byte; the maximum body uses all 24 length bits.

| Metadata body bytes | MSKIPBYTES | Encoded length bits |
| --- | ---: | ---: |
| 0 | 0 | 0 |
| 1...256 | 1 | 8 |
| 257...65,536 | 2 | 16 |
| 65,537...16,777,216 | 3 | 24 |

An empty `.metadata` option omits metadata emission. An explicit incremental
`writeMetadata("")` requests an empty metadata block instead. This distinction
allows an explicit control event without changing the default wire.

Bodies larger than the single-block maximum return `InvalidBlockPlan` before
reading the body or committing a setter request. The setter leaves its snapshot
unchanged on rejection. There is no automatic splitting into several metadata
blocks; a caller may explicitly issue several admitted events if appropriate.

## Encoding surfaces and ownership

The same header geometry is used by stored and planned encoders, quality
q0...q11, static-dictionary and HQ paths, and their one-shot, chunked, reusable
and incremental surfaces. Header writing and exact stored-stream bounds use
the same plan, including the current bit offset and alignment; a three-byte
length cannot be priced as the previous two-byte header.

An incremental `writeMetadata` event is ordered after previously accepted
plaintext. The caller keeps the borrowed metadata alive and unchanged until
the encoder completes the event and returns `need_input`. The existing
implementation builds the admitted complete metadata block in pending output
before draining it through caller slices. A 16 MiB body can therefore require
metadata-sized pending storage in addition to caller-owned body memory; the
small fixed header plan does not make emission constant-memory.

Stored/planned requested-heap limits continue to govern their actual codec
allocations. Reusable encoding protects overlapping metadata, input chunks and
their descriptor array before clearing or resetting output. This includes
aliases anywhere in the old output allocation's capacity. A pre-clear snapshot
allocation failure preserves the old output and encoder state. After the
operation, temporary metadata option pointers are cleared before the snapshot
is released; later failures follow the encoder's existing progress/publication
contract rather than an all-errors rollback guarantee.

The static-dictionary reusable path required a real lifecycle fix: Zig 0.16
`ArrayList.clearRetainingCapacity` can fill old bytes with `undefined` in Debug.
Copying aliased metadata into pending output after that clear was too late.
The new snapshot occurs before clear, covering metadata-only, chunk-source and
descriptor aliases. It uses the existing caller allocator; this increment does
not add a new static-dictionary total-heap budget API. These ownership rules are
separate from metadata's exclusion from plaintext/history counters.

Metadata emission allocation failure retains the existing pending-output
checkpoint and retry contract. This increment does not turn Brotli step errors
into Deflate64-style sticky failures. A caller must use the encoder's reported
progress/snapshot and preserve the event body across retry; already accepted
plaintext or delivered output is not rolled back by an entire-call guarantee.

## Streamed body encoding

Stored, planned and static-dictionary incremental encoders also support
`beginMetadata(len)` followed by `stepMetadata(body, output)`. Use this for
known-length metadata that is produced or delivered in pieces. The request
first emits any earlier plaintext and the same aligned metadata header as
`writeMetadata`. Then the encoder copies each consumed body prefix directly
into caller output. It borrows nothing across calls and does not allocate or
stage a metadata-sized body. Ordinary block and header workspace may still
be allocated under the existing encoder policy.

- Admit one block of 0 to 16 MiB. `beginMetadata` only declares the length;
  even an empty block must be driven through `stepMetadata` to emit its wire.
- Use `progress.input_read` to release or reoffer the body prefix, and
  `progress.output_written` to deliver wire bytes. A call may report
  `need_output` after draining preceding wire or the header, even with spare
  capacity; the next call resumes without replay. `need_input` may mean more
  body is required. The request is complete when `metadata_pending` clears;
  while pending, `metadata_bytes` is the remaining body length.
- The offered body must not exceed that remaining length (`SizeMismatch`).
  Body and output must be disjoint and independent of encoder storage.
  `step` and `finish` refuse an active streamed request with
  `InvalidStreamState`; complete it first, then continue plaintext or finish.
  `reset` abandons the current stream, including an unfinished request;
  previously emitted bytes cannot be withdrawn.
- Snapshot source totals and `max_input_len` still count only plaintext.
  Encoded totals include header and body. Keep legacy `writeMetadata` when
  the complete body is available and its existing drain/finish behavior is
  desired.

`check-encoder-lifecycle` exercises legacy wire equality at the metadata
length-width transitions, tiny output slices, and quota/backing-allocation
refusal and retry. All three encoders pass a full 16 MiB body through reused
4 KiB input with a 4 KiB allocator and a zero plaintext quota. The independent
libbrotli 1.2.0 decoder described below consumed a 271-byte wire from the new
stored-encoder path on three input partitions, recovering an empty metadata
event, all 257 bytes of the second metadata event, and `ABC` plaintext.

## Incremental decode observation

`IncrementalStreamDecoder`, `IncrementalCopyStreamDecoder`,
`IncrementalLiteralStreamDecoder` and `IncrementalStoredStreamDecoder` offer
`Options.metadata_observer`. It can be used alone or alongside fixed
`metadata_output` and `metadata_block_lengths` captures. Those captures keep
their existing capacity and truncation semantics. The observer sees all
accepted metadata bytes even when a capture is absent or full.

```zig
var decoder = br.IncrementalCopyStreamDecoder.initWithOptions(history, .{
    .metadata_observer = .{ .context = &collector, .on_event = Collector.onMetadata },
});
```

The callback signature is `fn (?*anyopaque, Decoder.MetadataEvent) void`.
A `.start` event announces the metadata block index, declared body length and
`final` flag after header and padding validation. Empty blocks emit only that
event. A nonempty block follows with one or more `.chunk` events containing
the same index, a byte offset within the body and a transient read-only slice.
Chunk boundaries may vary with input fragmentation. The block has arrived in
full when its chunks cover the announced length; a truncated block can emit
a start and an incomplete prefix. An event does not certify later stream
bytes or the stream's decoded-size check. A Huffman lookup in a preceding
compressed meta-block can already have accepted a whole aligned byte. The
copy/progressive decoder delivers such body bytes in order before reading new
input, without charging them again to input progress. An empty metadata block
preserves any retained bytes for the next meta-block.

Metadata delivery does not use plaintext output space or quotas and does not
retain the body or allocate memory for it. It observes the decoder's normal
wire order: an earlier plaintext block may still require output space before
the decoder reaches subsequent metadata. Callback state is caller-owned and
must remain independent of the decoder and all active input, output, history,
scratch and capture storage. Callbacks must not reenter the decoder or mutate
that storage. Copy any chunk bytes needed after the callback. The observer
is retained with the options; resetting with the same options keeps it, and
reconfiguring or starting a next stream with new options may replace it.
Metadata indices restart at zero for each stream.

`max_metadata_bytes` and `max_metadata_blocks` independently bound metadata
body bytes and block count per Brotli stream. Both default to unlimited. The
full declared body length is checked against the remaining quota after header
and alignment validation, before its observer start, body read, or fixed capture. An
empty block uses one block credit and zero body bytes. These limits also apply
when metadata is being discarded and do not consume plaintext output quota.
A refused block returns `OutputLimitExceeded`; previously delivered plaintext
and metadata remain committed. Reset or next-stream/frame starts new counters
with the applicable stream options.

The decoder tests send the full 16 MiB metadata limit through one reused
8 KiB input slice for each of the four decoders. The owned metadata-only case
runs with a zero requested-heap limit and reports zero peak working bytes.
The native, x86 and actual WASI cases run through the three
`test-codec-member-boundaries` variants. A separate libbrotli 1.2.0 callback
probe observed three metadata blocks (5,130 bytes), including empty and final
blocks, and exactly three plaintext bytes on four input partitions. Nonzero
alignment padding produced no event. The reference used the local decoder
build with SHA-256 `3acf45976e96498b954bb104b06ef5b8e1cd08b5e0d8d6826c233ed1f07c0469`
and matching common library `3e05a68ce8782d4b7bc6137d5e89cae758fa9c0a1e139075e29c91b3c4307739`.

## Evidence scope

The initial 64 KiB encoder policy and its dated benchmark outputs remain attached
to their source revisions. The full single-block range is a functionality and
header/accounting increment, not a throughput, RSS or complete-window matching
claim. The three configurations each pass 130/130 executions: 30 filtered
metadata tests plus 100 public-root tests, not 130 independent metadata cases.
Native/x86 reference campaigns each verify 194 target encodes and 18 upstream
metadata streams, with identical target wire/header/progress records. Broader
encoder quality, retained history and performance remain separate work.

A separate old/new gate compares 384 complete streams byte-for-byte, 192 per
target, within the previous 0...65,536-byte supported range. Both sides of each
comparison pass independent full-content decoding. Its representative qualities
and bounded API matrix do not establish identical output for every possible
input or quality. Final codec and test-only source revisions remain distinct in
the evidence. The complete native ReleaseFast family reports 1430 passed and
one skipped out of 1431. That skipped overflow gate is specific to 32-bit hosts
and is outside the x86 metadata/public-root filter. A separate actual x86
ReleaseFast run of that named gate passes 20/20 executions, including imports;
this is not 20 distinct overflow tests. The final build check passes 180/180 on
the test-only revision after the obsolete oversized-length fixture was corrected.
