# Codec history error and metadata compatibility contracts

The Brotli owned incremental decoder now preserves `InvalidMatch` for malformed
zero distances, invalid static dictionary addresses and RAW compound-dictionary
overruns when `max_history_len` limits its history ring. Previously every
`InvalidMatch` in capped-history mode became `OutputLimitExceeded`, incorrectly
classifying malformed input as resource exhaustion.

The caller-history decoder records a distinct internal history-capacity cause
only when a valid history distance exceeds the supplied ring. Its existing
public `InvalidMatch` behavior is retained. The owned facade maps that cause to
`OutputLimitExceeded`; it leaves other errors intact. Reset/reconfiguration and
next-frame initialization rebuild the cause alongside the rest of frame state.
No new public error or allocation is introduced.

Two dedicated regression groups use actual RFC headers and singleton/two-symbol
Huffman trees. They cover a two-byte static dictionary word request, a copy past
a one-byte RAW prefix, and short distance code four after installing distance
one (resolving to the invalid distance zero). Contiguous and one-byte schedules
compare capped/uncapped owned and caller-history errors, published prefixes,
failed-call progress, offsets, sentinel bytes and sticky retries. Valid history
exhaustion, both plain and RAW-dictionary history paths, retains the resource
error. Reset, next-frame reuse and a larger-ring retry are also checked.

The new tests fail before the production fix: Debug reports 22/24 passing, with
both new groups expecting `InvalidMatch` and receiving `OutputLimitExceeded`.
After the fix, Debug and ReleaseSafe each pass 24/24. Existing Brotli stream
contracts pass 45/45 in Debug; owned-counter contracts pass 28/28 after their
synthetic decoder is updated to model the internal failure cause.

The system libbrotlidec 1.0.9 independently rejects the no-dictionary static-word
and zero-distance wires. Exact bytes and the requested library's version/hash
are saved in
[the reference receipt](data/codec-history-errors-20261123/brotli-reference.json).
The receipt proves rejection, not a cross-library match of partial output or
error enum values. The older system reference has no RAW dictionary attachment
API, so compound-dictionary error classification is covered by Vort's public
decoder comparisons and the checked dictionary bounds.

Deflate gains a separate regression for the existing smaller-CINFO tolerance.
The focused Debug and ReleaseSafe runs each pass all nine selected tests.
An independent fixed-Huffman fixture advertises a 256-byte window while its
payload explicitly uses a length-257/distance-257 match. Python zlib 1.2.11
accepts the fixture, as does Vort's established one-shot contract. The new
incremental tests cover both the zlib decoder and the zlib/gzip autodetect
decoder, header/footer splits, one-byte output, exact cumulative counts,
truncation, strict Adler checking, strict/permissive trailing data and reset.
Fixture bytes, generator and provenance live in
[`src/deflate/zlib/fixtures`](../../src/deflate/zlib/fixtures/README.md).
This adds validated coverage; it does not change window acceptance policy.

## Reproduction

```sh
zig build -j2 test-br -Dbr-test-filter='Brotli history errors'
zig build -j2 test-br -Dbr-test-filter='Brotli history errors' -Doptimize=ReleaseSafe
zig build -j2 test-br -Dbr-test-filter='Brotli stream contracts'
zig build -j2 test-br -Dbr-test-filter='Brotli owned counters'
zig test src/deflate.zig --test-filter 'zlib incremental advertised window'
zig test src/deflate.zig --test-filter 'zlib incremental advertised window' -O ReleaseSafe
zig build -j2 test check check-wasm --summary all
```

The broader industry-best objective remains active. These changes strengthen
functional error contracts and interoperability coverage; they make no new
throughput, compression-ratio or RSS claim.
