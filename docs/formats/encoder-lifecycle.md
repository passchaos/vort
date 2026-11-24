# Incremental encoder lifecycle contracts

Brotli accepts a metadata request as part of the current stream. Calling
`finish()` immediately after successful `writeMetadata()` preserves that
request: buffered plaintext is written as a non-final block, the metadata
follows, and the final marker closes the stream. The caller keeps the metadata
alive until `need_input`, or until `done` if finish follows the request.
Completion clears the pending request. Stored, planned and static-dictionary
encoders share this behavior across input/output backpressure and empty input.

An explicit Brotli `flush()` publishes enough bytes for a streaming decoder
with available output space to reproduce all plaintext accepted before the
request, without waiting for another write or for `finish()`. Call
`step(&.{}, output)` until it acknowledges with `need_input`; the stream is
still open. A partial final byte is sealed by an empty metadata meta-block.
This carries no user metadata or plaintext, but may be visible to a decoder
that reports empty metadata blocks. An aligned boundary needs no padding.
This padding applies to explicit flushes, not implicit one-shot chunk
boundaries used to preserve the existing wire.

`writeMetadata` admits the requested bytes before publishing the request.
Metadata must stay outside the encoder object, its complete owned capacities
and active observers. A conflict returns `InvalidBlockPlan` with state and
caller bytes unchanged, allowing independent storage to be retried without
reset. Empty spans and immutable read borrows may overlap each other.

Brotli `nextStream` admits the prospective stream metadata, dictionaries and
observers before activation or reset. Completed external dictionaries and HQ
observer storage can be reused when the next configuration releases that role.
An actual budget observer still written during activation remains protected,
even if the next options omit it; explicitly detach that memory profile before
reusing its bytes as metadata.

Zstd next-frame transitions validate the prospective options and dictionary or
prefix before allocator/profile publication or state reset. New immutable
content, standard-dictionary backing and prepared state must be independent of
the next frame's mutable observers and encoder-owned storage. A conflict returns
`InvalidBlockPlan` with caller bytes and state unchanged; independent storage
can be supplied on the same completed encoder.

A completed frame releases its old prefix read before a new observer is bound.
An observer removed during a successful transition can become the new prefix.
Parallel transitions publish the committed next-frame options after resetting
the frame, preserving the ended frame's final profile bytes. Shared allocator
leases keep their parent observer lifetime and must protect that binding.

These rules cover `nextFrameWithPresetDictionary` and its exact-size variant,
including explicit `.dictionary_usage = .prefix`, on both serial and persistent
parallel Zstd encoders. Existing prefix metadata validation remains deferred to
encoding where that is the documented policy.

Zstd `setPrefix`, `setPrefixWithDictionary`, `setDictionary` and binding clear
operations check the new borrow against current observers and owned storage
before changing the binding. Current observer lifetimes remain active during
these setters. A conflict leaves the previous binding intact and can be retried
with independent storage; obvious busy states retain `InvalidStreamState`.
Parallel stable-object checks precede queue locking.

Both Zstd incremental encoders reject a call whose offered input would exceed
the current frame's exact-size pledge. `stepWithDirective(..., .end)` must offer
exactly the remaining pledged bytes; on output backpressure, reoffer only the
unconsumed suffix. A mismatch is `SizeMismatch` with zero accepted or delivered
bytes, no pending wire drain, and no change to an idle or active prefix. Supply
a corrected slice on the same encoder. In parallel mode `failedProgress()`
reports zero progress for that call. This does not undo an explicit `finish()`:
a short pledge detected while draining `finish()` cannot accept more input and
requires a reset. The refusal itself does not publish pending wire bytes.

Zstd `writeSkippable` borrows payload only during the call and validates it
before prefix activation, profile publication or output growth. Receiver,
complete owned capacities and current observers must be independent of the
payload. Read-only dictionary storage may also supply payload bytes. After
successful return, the caller may release or overwrite that payload.

Parallel skippable requests check the complete eight-byte header plus payload
against the pending-output limit before accepting the request. A rejected new
request preserves the idle boundary for retry. Output already accepted before
a later limit reduction keeps its resumable drain behavior.

The zlib `nextStream`/exact-size and gzip `nextMember`/options/exact-size families
check the new dictionary or header metadata before resetting the old member.
The old immutable configuration can be replaced, and shared independent
old/new read storage is allowed. Receiver and complete owned capacity remain
protected, including spare bytes left by the completed encoder. A refusal
preserves the done boundary so a caller can retry without reset.

Gzip member transitions validate filename/comment terminators and extra-field
length before changing the header or resetting the raw encoder. An embedded
NUL returns `BadGzipHeader`; an extra field longer than 65,535 bytes returns
`IntegerOverflow`. Borrow admission precedes reading the header fields.

Zlib and gzip exact-size transitions reject a new input pledge above the new
raw `max_input_len` with `OutputLimitExceeded`. Header-only gzip exact-size
transitions use the active raw input cap. These refusals preserve the complete
done receiver, retained storage, caller bytes and allocator counts. Empty
members with a zero pledge and cap remain supported. See the
[wrapper transition evidence](../performance/deflate-wrapper-transition-options-20261120.md).

Run the shared public contracts through:

```sh
zig build -j2 check-encoder-lifecycle
zig build -j2 test-encoder-lifecycle
zig build -j2 test-encoder-lifecycle-x86
zig build -j2 test-encoder-lifecycle-wasm
```

The WASI test gate executes the Zig test runner and writes
`zig-out/encoder-lifecycle-wasm.json`. Brotli's flush contracts in this gate
cover the flushed prefix without finalization, zero- and one-byte output
buffers, repeated flush, explicit metadata, and unaligned-tail retry after
allocator or quota failure. The Brotli filter passed 50 tests each on native,
Linux x86 and executed wasm32-wasi. Independently, libbrotlidec 1.0.9
recovered all 121 plaintext bytes from the 48-byte quality-4 flushed prefix
alone, consuming the prefix without needing `finish()` or following data.
`check-wasm` compiles these regression artifacts. `check-library-tests` compiles the entire library test suite without
starting a second test execution.

See the [functional evidence](../performance/incremental-encoder-lifecycle-20261120.md)
for observed failures, exact-wire controls, portability and current validation.
