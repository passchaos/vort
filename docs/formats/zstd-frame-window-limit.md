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
it. Options-less APIs continue to use the unlimited policy. For indexed
range reads, see the separate [seekable window control](zstd-seekable-window-limit.md).

Use `zig build check-zstd-source-reverse` to execute native, Linux x86 and
WASI window admission regressions alongside the source decoder contracts. An
independent libzstd 1.4.8 streaming probe rejected a 2,048-byte declaration
under a 1,024-byte window cap before producing output, and accepted it at an
exact 2,048-byte cap. Vort's option is in bytes, not log2 units.

## Incremental admission retry

Set `NativeIncrementalFrameDecoder.Options.retry_frame_admission_limits` to
retain a complete data header when admission returns `OutputLimitExceeded`
for the window, frame count or declared content size. The default keeps the
existing sticky-error behavior. A paused decoder reports
`snapshot().frame_admission_paused` and preserves prior output, progress,
buffered bytes and the pending or selected dictionary. `step` and `finish`
return `OutputLimitExceeded` while paused; a further `step` makes no progress.

Call `retryFrameAdmission(.{ .max_window_size = new_limit })` to rearm the
header. Optional overrides also cover `max_frames`, `max_output_len` and
`max_decoded_buffer_len`; omitted limits stay unchanged. Incompatible bound
workspaces or invalid options leave the pause and previous limits intact.
The next `step` rechecks the header using only input not already reported as
accepted, which can be empty if prevalidated lookahead retained the suffix.
There is no need to replay a header or any other accepted bytes. A dictionary
request after retry uses the ordinary `provideDictionary` contract. A
block-stream decoder with insufficient compressed workspace can use
[`retryFrameAdmissionWithCompressedBlockWorkspace`](zstd-compressed-workspace.md#replacing-the-workspace-on-admission-retry)
to move accepted bytes and change the limits together.

Skippable admission, unknown-size payload limits, heap failures and malformed
frames are not made resumable by this option. A frame that still exceeds a
limit can pause again. Reset discards the pause with the rest of the frame.

## CLI

The five native Zstd decode and size commands accept `--max-window-size=BYTES`
(or `--max-window-size BYTES`) after their required arguments. The optional
`max_output` positional argument still works and can appear before or after
the window option. For example:

```sh
vort decode-zstd-native-file-to data.zst data.out --max-window-size=8388608
vort size-zstd-native-file data.zst 1048576 --max-window-size 8388608
```

The cap checks decode admission, not the CLI's separate input-file read limit.
On `OutputLimitExceeded` with a window option, stderr reports
`zstd_decode_limit_exceeded` and the configured window and output limits. It
does not infer which of the two limits caused the refusal. The `file-to`
command finishes decoding before opening the output file, so refusals and
other decode errors leave existing destinations intact and do not create a
new one. Omitting the option keeps the legacy decode and size paths.

`zig build test-zstd-decode-window-cli` runs the same black-box cases against
the native CLI and the shared dispatcher in an actual wasm32-wasi process.
