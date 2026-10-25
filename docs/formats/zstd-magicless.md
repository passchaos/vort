# Explicit Zstd magicless frames

Updated 2026-10-26: core integration and its final core/reference/family checks
are complete, including bounded old-standard wire parity and final build checks.
Verification retains its actual source scope in the
[functional baseline](../performance/zstd-magicless-functional-baseline.md).

`ZstdFrameFormat` selects `.standard` or `.magicless`. `FrameOptions.format`
and `NativeFrameOptions.format` default to `.standard`, preserving established
wire behavior. Magicless data frames omit the initial four-byte Zstd magic;
their descriptor, window, content size, dictionary ID, blocks and checksum
retain the ordinary format. Options-aware header bounds omit exactly those four
bytes per data frame, without changing block costs.

The format must be selected explicitly for decoding. There is no automatic
sniffing or fallback. Consecutive magicless data frames are decoded in the same
mode using actual block/checksum boundaries, not by searching for magic bytes.
An empty frame still has its descriptor and final block. Known/unknown content
sizes and checksum/dictionary errors keep their existing meaning.

## Decode options and publication

`ZstdFrameDecodeOptions` contains `format`, optional `dictionary` or
`dictionary_set`, `max_output_len` and `expected_output_len`. Dictionary choices
are mutually exclusive; an expected size above the maximum is invalid.

```zig
const decoded = try vort.zstdDecodeFrameAllocWithOptions(allocator, encoded, .{
    .format = .magicless,
    .max_output_len = 64 * 1024 * 1024,
});
defer allocator.free(decoded);

const written = try vort.zstdDecodeFrameIntoWithOptions(allocator, encoded, output, .{
    .format = .magicless,
    .expected_output_len = expected_size,
    .max_output_len = expected_size,
});
```

The new Into API takes an explicit allocator first. It validates the complete
decoded stream in temporary decoded storage before copying to caller output,
preserving atomic publication on corrupt, truncated or too-small output. It
does not clone compressed input or prepend a synthetic magic buffer. Decoded
staging is still a real allocation, so this Into variant is not allocation-free.
Alloc, Append and decoded-size WithOptions routes use the same explicit format
and constraints. Existing option-free routes retain standard-format behavior.

Reusable decoders accept `initWithOptions`; ordinary methods honor stored
format/limits/dictionary choices, and per-operation WithOptions methods expose
explicit overrides. Incremental decoder `Options.format` applies to block-stream
and prevalidated-frame paths, dictionary resume, first-frame stop and trailing
input. Encoders carry the format through one-shot, level/native, reusable and
incremental headers. Header/block inspection WithFormat reports offsets in the
actual input: the data descriptor starts at zero for magicless and four for
standard data frames.

## Skippable and container boundaries

Skippable frames retain their four-byte identifier and four-byte size; there is
no magicless skippable form. Magicless decoding does not recognize skippable
identifiers or switch to standard mode when one appears. Consequently a mixed
magicless/skippable stream is not an upstream-compatible concatenated mode.
Incremental `writeSkippable` rejects magicless with `InvalidBlockPlan` before
state mutation or allocator binding.

Seekable encoding rejects magicless options because its seek table uses the
standard skippable-frame convention. ZIP, TAR and CPIO Zstd compression also
reject magicless configuration before publishing a container. These consumers
must retain standard Zstd framing rather than accidentally inherit a core option
that creates an incompatible archive.

ZFS-Zstd deliberately uses magicless framing. Its eight-byte big-endian true
payload length and level/version header are unchanged. Encoding explicitly
disables content-size and checksum fields; decoding borrows exactly the declared
compressed payload and applies expected/max output limits. The new core path
removes the former whole compressed-input copy used to prepend magic, while the
allocating API still returns caller-owned decoded output.

## Limits and evidence

Wrong-mode failures are not required to be symmetric: standard mode generally
rejects a magicless prefix, while magicless mode treats ordinary magic as a frame
descriptor and may report a descriptor error. Truncation and corruption are
checked according to the selected grammar. This mode is explicit framing, not a
new compression algorithm, dictionary format or C ABI compatibility layer.

Three configurations each pass 130/130 core/layout plus consumer/root
executions. Final native/x86 reference matrices each pass 609/609 and the
complete Zstd family passes 1104/1104. Bounded legacy standard output matches in
96/96 comparisons with 192 independent full-content decodes, without a format
backport. Final build checks pass 185/185 on the feature source. The increment does not refresh earlier codec
benchmarks or establish throughput, RSS, all-quality/platform or industry-best
leadership.

Bounded XZ parallel encoding is the next functional slice; it needs independent
ownership and compatibility verification before performance tuning.
