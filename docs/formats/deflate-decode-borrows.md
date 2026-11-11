# Contiguous Raw Deflate decode borrows

Caller-buffer Raw Deflate decoding requires the complete writable output
slice to be disjoint from compressed input and the provided preset dictionary.
These APIs borrow their source bytes for the whole operation. They do not
allocate a snapshot to support in-place decompression.

The contract applies to `decodeRawDeflate`/`decodeRawDeflateWithDictionary`
at the package root, `deflate.decodeRawAuto`/`decodeRawAutoWithDictionary`,
the specialized `deflate.decodeRawFixed`/`decodeRawStored` facades, and
`decodeRawDeflateAfterSync`. The package root's `decodeRawStoredDeflate`
alias uses the same specialized stored facade.

An overlapping nonempty output slice returns `InvalidBlockPlan` before any
output, compressed input or dictionary bytes are modified. The check covers
the entire caller-provided output slice, including unused tail capacity. It
also covers all provided dictionary bytes, not just the next match's source.
Adjacent disjoint ranges are allowed. Compressed input and dictionary may
overlap each other because both are read-only borrows.

Empty ranges do not overlap. A zero-length output retains the ordinary
decoder behavior: an empty decoded stream can succeed; a nonempty stream
returns its existing `OutputTooSmall`/format error. Empty compressed input
retains `TruncatedFrame`. Sync recovery still reports
`DeflateSyncPointNotFound` when no marker exists. After finding a marker,
the sync facade protects the full original input, including the prefix
before the resume offset, before decoding its suffix.

Other malformed/truncated input or output-capacity failures retain their
existing validation timing and partial-output behavior. The no-write rule
here is the alias admission rule, not a new transactional decode API.
Allocating/append, chunk-joining, zlib/gzip wrapper and incremental APIs have
separate ownership surfaces and require their own borrow validation gates.
The legacy coalescing chunk facades now define their additional scratch,
append and state admission in [Deflate chunk borrows](deflate-chunk-borrows.md).

## Why individual copy checks are insufficient

A two-block stored stream with payloads `abc` then `def` is 16 input bytes.
Place it in a 19-byte backing buffer and pass bytes 13 through 18 as output.
The first copy writes `abc` over the second block's unread `def` payload.
Each individual copy can have disjoint source/destination ranges, so a memcpy
overlap check alone cannot protect the operation. The decoder must reject the
whole borrowed-range conflict before its first copy.

A dictionary-backed stream can emit an initial literal and then read preset
history. If output aliases dictionary storage, the first literal changes the
history and a later match can both read wrong bytes and invoke overlapping
memcpy. The whole-operation dictionary admission check prevents both cases.

`src/deflate/decoder/output_alias.zig` owns the range check. It compares
half-open ranges by subtracting the smaller address from the larger one,
avoiding address-plus-length overflow. The facades invoke it before their
first write; the integration tests live in
`src/deflate/decoder/output_alias_tests.zig`.

## Focused validation

```sh
zig test -ODebug src/deflate.zig \
  --test-filter 'Deflate raw decode buffer alias contracts'
zig test -OReleaseSafe src/deflate.zig \
  --test-filter 'Deflate raw decode buffer alias contracts'
zig test src/deflate.zig -target wasm32-wasi -OReleaseSafe -fsingle-threaded \
  --test-filter 'Deflate raw decode buffer alias contracts' --test-no-exec \
  --stack 8388608 -femit-bin=/tmp/vort-raw-output-alias-20261111.wasm
node tools/deflate/clone/wasm_gate.js \
  --output /tmp/vort-raw-output-alias-20261111-wasi.json \
  /tmp/vort-raw-output-alias-20261111.wasm
```
