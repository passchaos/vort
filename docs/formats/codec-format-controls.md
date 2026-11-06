# Codec format controls

The zlib encoder exposes the RFC 1950 history window independently of generic
DEFLATE search settings. Zstd decoding can explicitly accept a mismatched
content checksum. Both controls retain the established default behavior.

## zlib encoder window

`ZlibEncodeOptions.window_bits` accepts 9 through 15, inclusive, and defaults
to 15. `ZlibFrameEncoder` owns reusable output scratch and accepts these options
at initialization or through `setOptions`. Its `encodeAlloc`, `encodeAppend`,
`encodeInto` and `encodeScratch` methods expose the same encoding modes:
stored, fixed, dynamic, dynamic literals, best, adaptive splitting and the PNG
ultrafast encoder. Stored scatter input has corresponding
`encodeStoredChunks*` methods. The package also exports
`encodeZlibFrameAlloc`, `encodeZlibFrameAppend`, `encodeZlibFrameInto` and
`zlibEncodeOptionsForLevel` for one-shot use and zlib levels 0 through 9.

`dictionary` is borrowed and supported in every mode. `block_len` selects
explicit stored, fixed, dynamic, dynamic-literal or best splitting; adaptive
mode uses `split_options`. A zero block length or a block length supplied to
adaptive/PNG mode returns `InvalidBlockPlan` before encoding. Dynamic-literal
mode emits a dynamic tree with literal-only payload, including dictionary and
split configurations.

`compression.lz77_options.window_len` can further reduce the search window. Every candidate
must respect the smaller of that setting and `2^window_bits`, including best
fallback candidates and adaptive or split-block history. The default fallback
previously restored the full 32 KiB search window; it now retains the caller's
window limit. Header CINFO advertises the selected window, FCHECK satisfies
RFC 1950 and DICTID hashes the complete caller dictionary. Matching retains
only its usable history suffix. An explicit empty one-shot dictionary retains
the existing FDICT=1, DICTID=1 behavior.

Incremental fixed and best zlib encoder options expose the same `window_bits`.
The advertised window locks when header emission begins. Runtime parameter
updates and public raw-option mutations cannot enlarge it. Resetting or
starting the next stream can select a different valid window. Generic raw
encoder window binding constrains effective matching without rewriting the
caller's managed active/requested parameter identity. Incremental empty
dictionaries retain their existing FDICT=0 behavior.

The facade validates windows before initialization or `setOptions` changes
state. Legacy incremental constructors remain infallible; `step`,
`requestParams` and `nextStream` reject invalid windows with
`InvalidZlibWindow` before output or parameter mutation. Window 15 delegates
to the corresponding legacy zlib encoding path
to preserve default wire bytes. The PNG facade adjusts the legal wrapper
header around the existing distance-one encoder.
`ZlibEncodeError` owns the new framing error; generic raw encoders and decoders
retain their existing error set.

## Zstd content checksum policy

`ZstdFrameDecodeOptions.ignore_content_checksum` and
`ZstdNativeIncrementalFrameDecoder.Options.ignore_content_checksum` default
to `false`. Set the flag to `true` to skip the comparison with the frame's
content checksum. A checksummed frame still requires all four footer bytes;
the option preserves frame parsing, content-size checks, dictionary selection,
output limits, cumulative counts and heap quotas.

The flag propagates through one-shot and reusable decoders, caller output and
append destinations, chunks, concatenated frames, dictionary and dictionary-set
selection, standard and magicless frames, source adapters and all incremental
input policies. Incremental footer consumption, frame counts, trailing input,
`nextStream` and reset retain the normal progress contract. Existing entry
points without options remain strict.

## Validation and references

Run the focused codec and package contracts on the three execution targets:

```sh
zig build -j2 test-codec-format-controls
zig build -j2 test-codec-format-controls-x86
zig build -j2 test-codec-format-controls-wasm
zig build -j2 run-codec-format-controls-diff -- \
  --reference-zstd /home/passchaos/Work/zstd/lib/libzstd.so.1.6.0
```

The differential driver uses public package APIs. Its independent Python
DEFLATE parser checks every stored, fixed and dynamic block, reconstructs all
literal and copy output, validates complete dictionary and content checksums,
and checks each copy distance against the declared window. Ordinary system
zlib decompression can accept excessive distances when the caller's output
buffer already contains history; successful decompression alone cannot prove
window compliance. Boundary controls also exercise continuation at a literal
prefix with fresh output storage.

Zstd reference decoding uses an actual library supporting
`ZSTD_d_forceIgnoreChecksum` (parameter 1002), with standard and magicless
frames and strict/ignore policy controls. Reference receipts retain the loaded
library path, version, library/header hashes and supported parameter values.
Malformed structure and incomplete footers must still fail in ignore mode.
These are functional compatibility checks; they establish no throughput or
compression-ratio claim.

The 2026-11-07 frozen-source gates passed 130 tests on each of native, x86 and
WASI: 15 selected DEFLATE tests, 26 selected Zstd tests and 89 package consumer
and import-discovery tests. The native/x86 reference matrix passed all 472
cases (272 zlib and 200 Zstd), using zlib 1.2.11 and local libzstd 1.6.0.
`zig-out/codec-format-controls/report.json` retains the case results and
reference/probe provenance; `events.jsonl` retains the individual receipts.
`zig-out/codec-format-controls-wasm.json` records actual execution and hashes
of all three WASI test artifacts.
