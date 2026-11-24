# Zstd caller-owned compressed-block workspace

`NativeIncrementalFrameDecoder` can borrow one fixed caller buffer for encoded
compressed blocks:

```zig
const max_window_size = 1024;
const workspace_len = vort.zstdNativeIncrementalCompressedBlockWorkspaceRequiredLen(max_window_size);
var workspace: [workspace_len]u8 = undefined;
var decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
    .input_policy = .block_stream,
    .max_window_size = max_window_size,
});
defer decoder.deinit();
try decoder.bindCompressedBlockWorkspace(&workspace);
```

`requiredCompressedBlockWorkspaceLenForWindow(max_window_size)` and the root
`zstdNativeIncrementalCompressedBlockWorkspaceRequiredLen` export return

```text
max(control-prefix minimum, min(max_window_size, 128 KiB))
```

The current control-prefix minimum is 18 bytes. It keeps enough storage for
framing state even when the admitted window is zero. The legacy
`compressed_block_workspace_len`, `requiredCompressedBlockWorkspaceLen()` and
root `zstdNativeIncrementalCompressedBlockWorkspaceLen` surfaces still return
131,072 bytes, so callers that do not opt into a finite maximum window keep the
existing behavior. `compressedBlockWorkspaceCapacity()` reports the actual
bound caller capacity. With an explicit block limit, use
`requiredCompressedBlockWorkspaceLenForLimits(max_window_size, max_block_size)`
(or `zstdNativeIncrementalCompressedBlockWorkspaceRequiredLenForLimits` from
`vort`). The result is `max(18, min(max_window_size, max_block_size, 128 KiB))`.
This changes compressed scratch, not the required history window.

## Optional per-block limit

Set `NativeIncrementalFrameDecoder.Options.max_block_size` to a byte limit
from 1 through 128 KiB (the default). It limits both the declared block length
and the bytes a compressed block may regenerate. A raw or RLE block that is too
large, or a compressed block whose serialized length is too large, is refused
as soon as its block header is available in block-stream mode. Compressed
output size is checked after the complete compressed block is available and
before any of that block's output is written. Malformed wire that exceeds the
frame's own block maximum is still `CorruptFrame`; exceeding only the caller
policy returns `OutputLimitExceeded`. Earlier blocks may already be published
in block-stream mode. Complete-frame preflight applies both checks before
publishing the frame when it fits the compressed-input limit.

This limit does not change frame or skippable admission, checksums, or match
history. A block refusal is not a retryable frame-header refusal.

This is an ownership and memory-bound feature, not a claim that every Zstd
compressed block can produce output before its end arrives. Sequence and
Huffman payloads use reverse bitstreams; forward input must reach the final
marker before the decoder can initialize the corresponding cursors. The block
stream still retains one complete compressed payload, but its storage is now
explicitly caller-owned instead of grown through the decoder allocator.

## Lifetime and state

- Binding is supported only for `.block_stream`; `.prevalidated_frame` needs
  complete-frame storage and is rejected transactionally.
- The required prefix is derived from `max_window_size` and `max_block_size`.
  A larger slice lends only its required prefix; the default configuration
  still requires 131,072 bytes.
- The workspace must remain stable, exclusive and unmodified until clear or
  decoder deinitialization. The decoder's backing allocator must not allocate
  from the same memory.
- `reset`, `resetAll`, `nextStream` and a compatible `resetWithOptions` retain
  the binding. If increasing either limit requires more compressed storage,
  `resetWithOptions` fails transactionally, leaving the old options and binding
  usable. `clearCompressedBlockWorkspace` returns to lazy decoder-owned
  buffering. Bind, clear and rebind require an idle header state.
- Deinitialization never frees caller storage. The workspace is excluded from
  `workingMemoryBytes` and `peakWorkingMemoryBytes`.
- `max_compressed_buffer_len` remains an independent logical cap. A physical
  workspace does not authorize the decoder to accept more bytes than the
  configured policy limit.

Input, ordinary output, stable output, dictionary content/full-dictionary
bytes/prepared state, dictionary catalogs and skippable capture storage may not
overlap the workspace. Failed alias and lifecycle operations do not advance
stream counters or publish output.

With caller-owned stable output, frames whose remaining decode state is fixed
size can run with `max_working_memory = 0`: caller output supplies match history
and the compressed workspace supplies reverse-bitstream retention. Ordinary
chunked output can instead bind the separate
[caller-owned rolling history](zstd-history-workspace.md); otherwise its exact
decoder-owned requested-heap boundary remains enforced independently.

## Replacing the workspace on admission retry

With opt-in [frame admission retry](zstd-frame-window-limit.md#incremental-admission-retry),
`retryFrameAdmissionWithCompressedBlockWorkspace(limits, workspace)` can raise
the window limit and bind a larger buffer in one call while a data header is
paused. It is available only to `.block_stream` decoders. It copies retained
compressed bytes into the new workspace, whether the old storage was owned
or borrowed, and rearms decoding without requiring input replay. A new caller
slice may overlap the old caller workspace, for example when enlarging the
slice over the same allocation. When the bindings are disjoint, the old
caller bytes remain unchanged.

Geometry and alias checks (including the existing history binding) finish
before any copy or ownership change. On refusal the old limits, pause, and
storage remain intact. On success, the new workspace stays borrowed and the
next `step` takes only the unaccepted input suffix.

If the history ring also needs to grow, call
`retryFrameAdmissionWithWorkspaces(limits, compressed, history)`. The two new
workspaces must be disjoint, but either may reuse previous caller storage,
including swapping the old roles. Only accepted compressed bytes
are copied. The new history ring starts empty at the new frame; previous
plaintext already delivered to callers is unaffected. This form is for
ordinary output, not stable-output bindings. Both geometries and all borrow
checks are validated together before either binding or the limits change.

## Validation

Native, x86 and wasm32-wasi tests cover zero/small/large-window requirement
queries, exact/N-1 binding, aliases, maximum 128 KiB compressed blocks,
sequence-bearing tiny I/O, transactional window growth, multiblock reuse,
stopped-member continuation, requested-heap exact-minus-one and zero-owned-heap
stable or ordinary caller-history output. Sequence-bearing tests also require
zero published output before the compressed block's final reverse-payload byte
arrives; this remains block-tail-dependent, not sub-block progressive decode.
The block-limit regression includes a 32-byte frame generated by libzstd
1.6.0 with `ZSTD_c_maxBlockSize=2048`. Both decoders reject it at 1024 bytes
without publishing plaintext and recover the same 2048 bytes at the exact cap.
The upstream zstd 1.6.0 decodecorpus campaign additionally sends 500 generated
compressed frames through the caller-workspace path and covers all 64 LL/OF/ML
table-mode tuples with no decoder-owned allocation.

```sh
zig build -j2 test-zstd-compressed-workspace
zig build -j2 test-zstd-compressed-workspace-x86
zig build -j2 test-zstd-compressed-workspace-wasm
zig build -Doptimize=ReleaseSafe -j2 run-zstd-decodecorpus-gate -- \
  --campaign compressed-16b-67867979 \
  --decodecorpus ~/Work/zstd/tests/decodecorpus \
  --decodecorpus-source ~/Work/zstd \
  --libzstd ~/Work/zstd/lib/libzstd.so.1.6.0
```
