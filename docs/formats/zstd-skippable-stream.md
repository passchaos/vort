# Streamed skippable encoding

`NativeIncrementalFrameEncoder` and `NativeIncrementalParallelFrameEncoder`
can write a standard Zstd skippable frame without staging its body. Call
`beginSkippable(id, payload_len)` with the four-bit ID and the declared `u32`
body length, then drive `stepSkippable(input, output)` until `.done`. The
existing `writeSkippable` method, which queues the whole frame, is unchanged.

- `beginSkippable` accepts the same boundaries as `writeSkippable`: a fully
  drained frame or a fresh encoder configured for prefix use. It rejects
  magicless mode, and neither borrows nor allocates body storage.
- The first eight encoded bytes are the inline magic and little-endian
  length. Body bytes then copy from the supplied input directly into output.
  `progress.input_read` is the number of body bytes consumed; output progress
  includes both header and body. Only the consumed input prefix may be
  released; no input is held beyond the call. Input and output must be
  disjoint and independent of the encoder's owned and borrowed storage.
- Reoffer unconsumed input after `.need_output`. `.need_input` requests
  additional body bytes. A body offer larger than the declared remainder
  returns `SizeMismatch` before consuming input or delivering wire, even
  when the output is empty. Empty bodies still require the header to drain.
- While this frame is active, ordinary plaintext steps return
  `InvalidStreamState`, and `flush()`/`finish()` do not interrupt it. An
  explicit session reset abandons it. After `.done`, the encoder can accept
  another skippable frame or `nextFrame` for a data frame. Skippable bodies
  do not count as data plaintext, cannot use the data history, and do not
  increment data-frame count; header and body both count toward wire output.
- A snapshot reports `skippable_streaming` and `skippable_remaining` while
  active. `pending_output` includes only the undrained eight-byte header,
  not body bytes that the caller has yet to provide.

In the parallel encoder, `max_pending_output_len` admits just the inline
header, so a limit of eight bytes can support every `u32` body length. The
cumulative `max_output_len` still applies during delivery. As with ordinary
parallel output, a capped call may deliver a prefix before reporting
`OutputLimitExceeded`; use `failedProgress()` to account for that prefix
before raising the limit or retrying. A delivered prefix never needs to be
re-encoded. The skip never starts worker jobs or allocates pending body storage.

Use the [skippable observer](zstd-skippable-observer.md) to consume paired
streamed metadata without buffering it during incremental decoding.

`check-encoder-lifecycle` runs these contracts on native, Linux x86 and
executed wasm32-wasi, including a maximum-length (`0xffffffff`) header and
retries at both the header and body output caps. The native worker case
checks skippable output between completed parallel data frames with no
increase in jobs or requested heap. In a separate libzstd 1.4.8 probe,
serial and parallel-fallback outputs each used 304 wire bytes; the reference
CLI decoded `ABC` and `ZSTD_findFrameCompressedSize` confirmed both the empty
and 259-byte skippable frames and their exact payloads.
