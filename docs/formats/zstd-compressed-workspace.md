# Zstd caller-owned compressed-block workspace

`NativeIncrementalFrameDecoder` can borrow one fixed caller buffer for encoded
compressed blocks:

```zig
var workspace: [vort.zstdNativeIncrementalCompressedBlockWorkspaceLen]u8 = undefined;
var decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
    .input_policy = .block_stream,
});
defer decoder.deinit();
try decoder.bindCompressedBlockWorkspace(&workspace);
```

`requiredCompressedBlockWorkspaceLen()` and the root convenience constant both
return 131,072 bytes, the maximum Zstandard compressed-block payload. Frame and
three-byte block headers are consumed before payload collection and therefore
do not enlarge the workspace requirement.

This is an ownership and memory-bound feature, not a claim that every Zstd
compressed block can produce output before its end arrives. Sequence and
Huffman payloads use reverse bitstreams; forward input must reach the final
marker before the decoder can initialize the corresponding cursors. The block
stream still retains one complete compressed payload, but its storage is now
explicitly caller-owned instead of grown through the decoder allocator.

## Lifetime and state

- Binding is supported only for `.block_stream`; `.prevalidated_frame` needs
  complete-frame storage and is rejected transactionally.
- At least 131,072 bytes are required. A larger slice lends only its first
  131,072 bytes.
- The workspace must remain stable, exclusive and unmodified until clear or
  decoder deinitialization. The decoder's backing allocator must not allocate
  from the same memory.
- `reset`, `resetAll`, `nextStream` and a compatible `resetWithOptions` retain
  the binding. `clearCompressedBlockWorkspace` returns to lazy decoder-owned
  buffering. Bind, clear and rebind require an idle header state.
- Deinitialization never frees caller storage. The workspace is excluded from
  `workingMemoryBytes` and `peakWorkingMemoryBytes`.
- `max_compressed_buffer_len` remains an independent logical cap. A 128 KiB
  physical workspace does not authorize the decoder to accept more bytes than
  the configured policy limit.

Input, ordinary output, stable output, dictionary content/full-dictionary
bytes/prepared state, dictionary catalogs and skippable capture storage may not
overlap the workspace. Failed alias and lifecycle operations do not advance
stream counters or publish output.

With caller-owned stable output, frames whose remaining decode state is fixed
size can run with `max_working_memory = 0`: caller output supplies match history
and the compressed workspace supplies reverse-bitstream retention. Ordinary
chunked output may still require decoder-owned rolling history, and its exact
requested-heap boundary remains enforced independently.

## Validation

Native, x86 and wasm32-wasi tests cover exact/short/unaligned workspace
geometry, aliases, maximum 128 KiB compressed blocks, sequence-bearing tiny
I/O, multiblock reuse, stopped-member continuation, reset/reconfiguration,
requested-heap exact-minus-one and zero-owned-heap stable output. The upstream
zstd 1.6.0 decodecorpus campaign additionally sends 500 generated compressed
frames through the caller-workspace path and covers all 64 LL/OF/ML table-mode
tuples with no decoder-owned allocation.

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
