# Stable output C reference

The verified existing oracle is local libzstd **1.6.0**. No reference library is
built by these tools. The library path, loaded-symbol origin, matching header
version, artifact hashes, resolved parameter values and live set/get preflight
are recorded in each generated receipt.

`ZSTD_d_stableOutBuffer` is read from the matching `zstd.h` macro alias, which
resolves to `ZSTD_d_experimentalParam2 = 1001` in this build. Its live parameter
bounds are `[0, 1]`; setting and reading both values succeeds.

## Actual C contracts

The local header (`zstd.h`, lines 2501 onward) requires an unchanged destination
pointer and size, and an output position modified only by libzstd. Decoded bytes
before `pos` must remain intact because later matches can refer to them.
`ZSTD_checkOutBuffer` in `lib/decompress/zstd_decompress.c` compares all three
fields while a frame is active. The three observed mutation failures are
`Destination buffer is wrong`. At the C `zdss_init` frame boundary a new buffer
is allowed; a mid-frame mutation does not model this boundary.

Known content size is checked against the remaining stable destination before
decoding the body. Unknown content size is enforced while decoding blocks.
The caller destination can be exactly the decompressed size. An internal output
buffer is unnecessary, although C may still allocate compressed input storage.
These observations make no RSS, custom-allocator, Vort requested-heap or heap
quota comparison.

For checksummed frames, the fixture preflight supplies the complete frame except
the final four bytes, then an empty input call, then the checksum. The final C
call has no available output space, reads four input bytes, writes zero output
bytes and finishes successfully. This tests actual footer progress without
changing the stable C destination size. Vort's per-call output quantum is a
separate API contract, not a mirror of `ZSTD_outBuffer.size`.

The matching `ZSTD_d_forceIgnoreChecksum` macro resolves to parameter 1002.
The additional C malformed preflight proves that a complete corrupt checksum
decodes correctly when this flag is enabled, while a truncated checksum remains
incomplete. Ignoring comparison does not remove the checksum footer.

## Corpus and API

The primary frozen artifact is
`src/zstd/testdata/libzstd-numbered-json.frame.hex`: its 183-byte frame decodes
to 1290 bytes and contains **39 actual sequences** in a compressed block.
The receipt preserves the archived hex SHA, decoded payload SHA, frame header,
block lengths, literal type, sequence counts and table modes. The fixture
generator also calls the existing C streaming encoder for known/unknown content
size, checksum/no-checksum and standard/magicless variants. Larger repeated
payloads exercise multiple compressed blocks; a concatenated stream includes
two data frames and two real skippable frames. Empty output is covered separately.

`Library(path=None, header=None)` prefers the local checkout. Its APIs are:

- `encode(payload, known_size=True, checksum=True, format="standard", ...)`.
- `decode_stable(wire, expected_output_len, ...) -> (payload, receipt)`.
- `decode(wire, expected_output_len=None, ...) -> payload`.
- `observe(wire, output_size, stable=True, input_chunk_size=3, chunks=None,
  mutation=None, ...) -> receipt` without raising decode failures.
- `provenance()` with matching library/header and parameter hashes.

An explicit `chunks` schedule must span the compressed wire and may contain
zero-size calls. Traces retain input offered/consumed, output position before
and after, actual bytes written, available destination space, return hint and
C error. Mutation controls (`dst`, `size`, `pos`) run while a frame is active.

`fixtures.generate(root, library) -> receipt` writes absolute artifact paths
and a `receipt.json`. Cases provide `payload_path`, `wire_path`, `format`,
`known_size`, `checksum`, `header`, `frames`, `sequences`, artifact hashes and
actual stable/buffered/short-output preflight observations. A separate archived
full dictionary/frame pair provides a 57-sequence recovery fixture and is loaded
with the matching C `fullDict=2` control. The verified corpus has
**14 cases, 608 sequences, 14 exact-full decodes, 7 zero-output footer
controls, 3 identity refusals and 2 malformed-input refusals**.

Prefix attachment and prefix/output alias controls belong to the separate
`prefix_lifecycle` reference. Stable output consumer ownership and moving
allocators are measured by the Vort probe's requested-allocation tracker.
