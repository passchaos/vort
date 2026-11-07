# Zstd caller-owned rolling history

Ordinary `NativeIncrementalFrameDecoder.step(input, output)` calls may use a
caller-owned circular history instead of decoder-allocated `direct_history`:

```zig
const max_window = 64 * 1024;
const history_len = try vort.zstdNativeIncrementalHistoryWorkspaceRequiredLen(
    max_window,
    dictionary.content.len,
);
const history = try allocator.alloc(u8, history_len);
defer allocator.free(history);

var decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithDictionaryAndOptions(
    allocator,
    dictionary,
    .{ .max_window_size = max_window },
);
defer decoder.deinit();
try decoder.bindHistoryWorkspace(history);
```

`max_window_size` is an independent header-admission limit. After a complete
standard or magicless frame header is available, a larger advertised window is
rejected before the block header, payload or output is consumed. The policy
also applies to prevalidated input and single-segment frames.

## Geometry

Without a dictionary, required history storage is exactly
`max_window_size`. With a dictionary it is:

```text
max_window_size + maximum configured dictionary content length
```

Dictionary bytes remain borrowed and are never copied into the ring. The extra
capacity preserves the Zstandard history coordinate while dictionary bytes are
phased out and frame output replaces them; real libzstd decodecorpus frames use
this extended interval. A dictionary set therefore sizes against its largest
entry. Late `provideDictionary` checks the already-bound capacity and can be
retried with a sufficiently sized workspace.

Within one `step`, committed ring history remains read-only and newly produced
bytes remain in the current caller output slice. A match can read borrowed
dictionary bytes, committed circular history, earlier bytes in the current
slice, and its own overlap prefix. Only the bytes actually published by the
existing progress contract are appended to the ring when the step returns or a
block completes.

## Ownership and lifecycle

- The workspace must be stable, exclusive and disjoint from input, ordinary or
  stable output, compressed workspace, dictionaries/prepared state/catalogs,
  decoder scratch and skippable capture buffers.
- Stable output and history workspace are mutually exclusive; stable output is
  already its own linear history backend.
- `reset`, `resetAll`, `nextStream` and a compatible `resetWithOptions` retain
  the physical binding and clear logical history. Increasing the configured
  maximum beyond capacity fails transactionally.
- Clear/rebind require an idle frame-header state. Deinitialization never frees
  or clears caller memory.
- Caller history is excluded from `workingMemoryBytes`. Pairing it with the
  128 KiB caller compressed-block workspace lets ordinary tiny-output decoding
  run with `max_working_memory = 0`; borrowed dictionary, caller output and the
  fixed decoder value remain external memory and must still be counted by the
  application.

## Validation

Native, x86 and wasm32-wasi gates execute raw, RLE, sequence-bearing,
dictionary and multi-frame tiny-output paths, ring wrap/overlap, aliases,
window-cap timing and zero decoder-owned heap. A zstd 1.6.0 decodecorpus gate
drives ordinary output—not stable output—through caller compressed and history
workspaces for 500 compressed frames covering all 64 LL/OF/ML mode tuples and
for 200 full-dictionary frames.

```sh
zig build -j2 test-zstd-history-workspace
zig build -j2 test-zstd-history-workspace-x86
zig build -j2 test-zstd-history-workspace-wasm
```
