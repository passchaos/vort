# Resumable Brotli compressed-header parsing, 2026-11-03

The incremental Brotli decoder retains compressed-header bytes and re-parses
the complete accumulated prefix after each input batch. Large context maps and
many Huffman trees therefore re-read completed work whenever the header spans
several small input chunks.

`CompressedHeaderParseProgress` now records the compressed-header sub-parser
stage, the next literal/command/distance tree index and an absolute bit offset.
`parseCompressedHeaderWithProgress` keeps completed block switches, context
maps and trees in the destination header. On `TruncatedFrame`, the progress
stays at the failed unit; appending bytes resumes there instead of re-reading
the whole prefix. Complex Huffman-tree descriptions now also resume inside the
tree: the 18-symbol code-length-code phase restarts from its saved start bit,
while the much longer symbol-length phase keeps decoded lengths, repeat runs and
the next symbol index in `HuffmanTreeProgress`.

The incremental copy decoder stores this progress, resets it for each new
compressed meta-block and uses the progress hook when the codec provides one.
Codecs without the hook retain the previous parse-from-prefix route. Standard
and large-window compressed headers share the same orchestrator.

## Validation

The incremental Brotli filter passes 217/217 tests. A new contract encodes the
`br/dictionary.bin` ratio stream and decodes it twice: once with the complete
input and once with one-byte input chunks. Both paths produce identical output.
The split path reports 752 progress resumes, 46 mid-tree symbol resumes and
both paths complete the same 19 header Huffman trees; re-parsing the prefix per
byte would repeat those completed trees thousands of times. Focused Debug,
ReleaseSafe and ReleaseFast runs pass. The complete ReleaseFast Brotli suite passes 1,533 tests with one
existing platform skip out of 1,534 and exit zero.

## Fragmented measurement

`tools/br/header_progress_probe.zig` encodes the 122,784-byte
`br/dictionary.bin` ratio stream (54,887 wire bytes) and decodes it at several
input chunk sizes. Three rounds per row give:

| Input chunk | Decode average | Header attempts | Resumes | Completed trees | Tree attempts | Symbol resumes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 byte | 2.277 ms | 762 | 752 | 19 | 738 | 46 |
| 16 bytes | 1.322 ms | 49 | 47 | 19 | 64 | 3 |
| 256 bytes | 1.194 ms | 4 | 2 | 19 | 21 | 0 |
| 4096 bytes | 1.198 ms | 2 | 0 | 19 | 19 | 0 |
| Complete | 1.218 ms | 2 | 0 | 19 | 19 | 0 |

Completed trees stay at 19 for every split, proving that retries retain
finished trees instead of re-reading the prefix. The one-byte row improved from
2.886 ms to 2.277 ms (about 21%) with 46 mid-tree symbol resumes; the 16-byte
row improved about 11%. The one-byte row still pays per-step overhead for
54,887 calls, so its total decode time is not a header-only ratio.

## Rejected retry lower-bound

A lower-bound retry gate recorded the bits consumed by the failed tree and
skipped retries with fewer available bits. With one-byte chunks the prefix
grows by eight bits per call, so the `consumed + 1` bound almost never skipped
a retry: tree attempts stayed at 738 and decode time remained within noise.
The gate was reverted.

```sh
zig build build-br-header-progress-probe
zig-out/bin/vort-br-header-progress-probe src/br/dictionary.bin 1 3
```

This establishes sub-parser and tree-boundary resumability. It does not yet
resume in the middle of a Huffman-tree description, nor provide a whole-file
streaming or memory comparison.
