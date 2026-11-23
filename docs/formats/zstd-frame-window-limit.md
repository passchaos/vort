# Zstd frame decode window limit

`FrameDecodeOptions.max_window_size` (root: `ZstdFrameDecodeOptions`) places an
exact byte limit on every data frame's advertised window. The unlimited
(default) setting preserves the legacy decode policy. This is separate from
`max_output_len` and `max_total_working_memory`: even a frame that generates
little plaintext can declare a large window. In single-segment frames the
window is the content size, so a zero cap admits an empty single segment.

The one-shot size/allocate/into/append routes, prefix wrappers and reusable
`NativeFrameDecoder` apply the same policy as incremental and random-access
source decoding. Standard and magicless formats are supported. A complete
header with a larger window returns `OutputLimitExceeded` before resolving
that frame's dictionary or processing its first block. A truncated or invalid
header is still a wire error. Standard skippable frames do not declare a
window and do not count toward the limit. The cap applies to every data frame
in a concatenated operation, not just the first.

The four chunk facades accept the same options. Their root names are
`zstdDecodeFrameChunksAllocWithOptions`, `zstdDecodeFrameChunksIntoWithOptions`,
`zstdDecodeFrameChunksAppendWithOptions`, and `zstdDecodedFrameChunksSizeWithOptions`.
The reusable decoder also applies its configured cap to its chunk methods.
For a finite cap, these methods walk frame and block headers in the original
slices before coalescing into caller-owned `compressed_scratch`. The scan
bounds body and checksum ranges without reading them. A window refusal leaves
scratch, decoder state, and output untouched. It can therefore precede a
scratch-size error or dictionary/entropy errors that would be discovered during
full decoding. Successful chunk calls still use caller scratch for contiguous
compressed input; keep it disjoint from the chunks, dictionaries and output.
Unlimited calls bypass the extra scan.

Explicit reusable `*WithOptions` calls use the options provided for that
call; normal reusable methods use the configured limit. Existing prefix
rules remain: a direct decode consumes a pending prefix when the call begins,
while size queries and chunk refusals before the decoder call do not consume
it. No new setting is imposed on the options-less or seekable APIs.

Use `zig build check-zstd-source-reverse` to execute native, Linux x86 and
WASI window admission regressions alongside the source decoder contracts. An
independent libzstd 1.4.8 streaming probe rejected a 2,048-byte declaration
under a 1,024-byte window cap before producing output, and accepted it at an
exact 2,048-byte cap. Vort's option is in bytes, not log2 units.
