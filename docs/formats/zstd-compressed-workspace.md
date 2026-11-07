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
bound caller capacity.

This is an ownership and memory-bound feature, not a claim that every Zstd
compressed block can produce output before its end arrives. Sequence and
Huffman payloads use reverse bitstreams; forward input must reach the final
marker before the decoder can initialize the corresponding cursors. The block
stream still retains one complete compressed payload, but its storage is now
explicitly caller-owned instead of grown through the decoder allocator.

## Lifetime and state

- Binding is supported only for `.block_stream`; `.prevalidated_frame` needs
  complete-frame storage and is rejected transactionally.
- The required prefix is derived from the decoder's configured
  `max_window_size`. A larger slice lends only its required prefix; the default
  unlimited-window configuration still requires 131,072 bytes.
- The workspace must remain stable, exclusive and unmodified until clear or
  decoder deinitialization. The decoder's backing allocator must not allocate
  from the same memory.
- `reset`, `resetAll`, `nextStream` and a compatible `resetWithOptions` retain
  the binding. Increasing `max_window_size` beyond its capacity makes
  `resetWithOptions` fail transactionally, leaving the old options and binding
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

## Validation

Native, x86 and wasm32-wasi tests cover zero/small/large-window requirement
queries, exact/N-1 binding, aliases, maximum 128 KiB compressed blocks,
sequence-bearing tiny I/O, transactional window growth, multiblock reuse,
stopped-member continuation, requested-heap exact-minus-one and zero-owned-heap
stable or ordinary caller-history output. Sequence-bearing tests also require
zero published output before the compressed block's final reverse-payload byte
arrives; this remains block-tail-dependent, not sub-block progressive decode.
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
