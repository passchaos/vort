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
the whole prefix. The failed Huffman tree itself restarts from its saved
start bit, so the completed-tree work is retained while mid-tree continuation
remains future work.

The incremental copy decoder stores this progress, resets it for each new
compressed meta-block and uses the progress hook when the codec provides one.
Codecs without the hook retain the previous parse-from-prefix route. Standard
and large-window compressed headers share the same orchestrator.

## Validation

The incremental Brotli filter passes 217/217 tests. A new contract encodes the
`br/dictionary.bin` ratio stream and decodes it twice: once with the complete
input and once with one-byte input chunks. Both paths produce identical output.
The split path reports 752 progress resumes, and both paths complete the same
19 header Huffman trees; re-parsing the prefix per byte would repeat those
completed trees thousands of times. Focused Debug, ReleaseSafe and ReleaseFast
runs pass. The complete ReleaseFast Brotli suite passes 1,533 tests with one
existing platform skip out of 1,534 and exit zero.

This establishes sub-parser and tree-boundary resumability. It does not yet
resume in the middle of a Huffman-tree description, nor provide a whole-file
streaming or memory comparison.
