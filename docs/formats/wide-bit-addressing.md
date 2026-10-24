# Whole-input bit addressing

`BitCount`, exported by `vort` and `bitstream`, represents a whole-input bit
address. It is `u64` on 32-bit targets and retains `usize` on 64-bit targets.
Physical byte indices, local read widths, reservoir counts and allocation sizes
remain local integers. Widening occurs before byte-to-bit multiplication.

The scalar, buffered and both chunked shared readers use this domain for bit
positions and availability. Brotli's fast reader uses it for staged endpoints
and synchronization. Byte offsets are obtained by dividing first and checking
physical representability. Rounded byte lengths use quotient and remainder,
avoiding overflow in `bits + 7`.

On 32-bit targets every representable contiguous byte length has a representable
bit length. On 64-bit targets the existing bit-address domain remains bounded
by `maxInt(usize) / 8` bytes. Checked geometry APIs reject overflow. Reader
constructors without an error result require that geometry to be representable;
they do not silently saturate input length.

## Logical tails and wide fields

The scalar reader's `initBitLength` may limit a final partial byte. Padded peeks
return zero beyond that logical endpoint even when the backing byte has nonzero
synthetic high bits. The fast Brotli reader masks partial source bytes before
placing them in its reservoir, preserving the same boundary.

A 64-bit reservoir cannot always stage a nonaligned 57–63-bit field using only
whole bytes. Shared readers use a bounded split path for these field widths;
ordinary narrower reads retain their existing fast paths. Checked reads leave
the cursor unchanged on truncation, and peeks do not consume future bytes.

## Brotli bounds and consumers

Complete Brotli parsing, summaries, size queries and header profiling retain
wide bit positions. Header positions over the whole input are wide; the size
of a bounded incremental header remains a checked local quantity. Profile bit
totals preserve wide counts. Existing local benchmark checksums explicitly
retain their wrapping fingerprint behavior.

Stored and planned chunk bounds accumulate whole-output bit lengths in the
same domain, then check the final local byte size. Repeated stored blocks use
exact first-block, full-block and tail geometry, avoiding an input-sized loop
for a bounds query. Actual block writers and resource policies retain their
existing wire and ownership semantics.

Deflate fused-reader state preserves the wide consumed-bit address; metadata
for its bounded first header is checked before narrowing. ZOO termination
checks also preserve wide bit lengths before byte indexing. Other consumers
using only local read/byte-offset APIs retain those interfaces.

These changes do not make a contiguous allocation larger than the platform's
address space. Complete chunked Brotli convenience APIs still join input where
their contract requires a contiguous scratch. True incremental APIs continue
to use bounded headers and caller buffers independently of whole-input bit
addressing.

## Evidence

Numeric tests cover the byte positions around 512 MiB and the maximum 32-bit
byte index without fabricating input slices or loading nonexistent memory.
Independent small bit recurrences verify mixed widths, dirty partial tails,
alignment, cursor synchronization and failure progress. Native field-layout
checks preserve the original 64-bit interface.

The separate large-input gate maps real sparse Brotli metadata files and reads
a valid compressed tail after the 512 MiB boundary. It records the mapped
length, materialized pages, actual public API results and reference-decoder
receipts. Numeric geometry or a declared input length alone is not a large-input
decode result. Functional durations and allocation checks do not establish
competitor performance leadership.
