# Incremental gzip header events

`vort.GzipIncrementalDecoder.stepWithHeaderEvents` is the usual incremental
`step` with a synchronous header observer. `stepToBlockBoundaryWithHeaderEvents`
combines the observer with the existing raw-DEFLATE block-boundary contract.
Neither method buffers a member header or allocates memory for metadata.

```zig
const r = try decoder.stepWithHeaderEvents(input, output, .{
    .context = &collector,
    .on_event = Collector.onHeaderEvent,
});
```

`Collector.onHeaderEvent` has signature
`fn (?*anyopaque, vort.GzipIncrementalDecoder.HeaderEvent) void`. Pass the
observer on every call that may consume header input. It is not retained,
including across clones, resets or later members; skipped events are not
replayed. Callbacks must not reenter or mutate the decoder or its input,
output, history and workspace. They may copy bytes or update independent
caller storage.

- `.start`: the fixed header is recognized; the event gives the member
  index, compressed start offset, FTEXT, MTIME, XFL, OS and presence flags.
- `.field`: a nonempty borrowed slice from the extra field, filename or
  comment. Its offset is relative to that field. XLEN and string terminators
  are excluded. Bytes are opaque, not decoded as text. Presence flags can
  distinguish empty from absent fields. Fragment boundaries may vary with
  caller input splits. A borrowed slice is valid only during its callback.
- `.complete`: the whole header is validated, including FHCRC when present.
  This event includes the absolute compressed offset of the first byte of
  DEFLATE data and occurs before any plaintext from that member is written.
  It does not certify the DEFLATE payload, CRC32 or ISIZE footer.

Header start and field events are provisional until `.complete`. Discard an
uncompleted header if its step or `finish` fails. A step can report the
completion of one header and then fail in that member's body or later
member; already completed headers remain valid. The existing metadata cap
still applies (XLEN for extra data and lengths including the NUL for the
strings). With concatenation enabled, member indices and offsets refer to the
logical stream; trailing non-member data does not generate events.

Run the native, Linux x86 and executed wasm32-wasi contracts with:

```sh
zig build check-gzip-header-events --summary all
zig build -Doptimize=ReleaseFast check-gzip-header-events test-deflate-incremental-relaxed test-zlib-stream
```

The valid-header test fixture includes every optional field. A separate
system zlib 1.2.11 `inflateGetHeader`/`Z_BLOCK` check confirms all fields and
header completion at compressed byte 29 with zero output, then decodes `A`.
Flipping the last FHCRC byte returns `Z_DATA_ERROR` before any output and
without confirming the header.
