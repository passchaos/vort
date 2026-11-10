# Chunked Deflate sync-flush input alias contract

`encodeRawFixedSyncFlushChunksAppend` and
`RawFixedSyncFlushEncoder.encodeChunksAppend` accept plaintext slices and a chunk
descriptor array that overlap the caller's output allocation. This includes the
logical prefix and spare capacity. The output's complete `allocatedSlice()` is
the overlap domain, rather than only `items`.

Before output descriptors are rebound or any wire bytes are written, the encoder
checks both plaintext data and the descriptor array. When either overlaps, it
captures the original non-empty physically contiguous runs in scratch metadata.
Every complete original run overlapping output receives an owned scratch copy.
Unrelated runs remain borrowed. Descriptor-only overlap captures all run metadata
even when none of the plaintext bytes require copying.

Those original run boundaries remain authoritative. Adjacent chunks with empty
slices between them still form one original run. Separate original runs do not
merge when their new copies happen to be adjacent, including inside an arena.
Planning and rolling history therefore see the same input bytes and boundaries
as a stable-input call. No generic full-message join is added; an affected run
can cover a complete message when that message was originally contiguous.

The ordinary path has no additional allocation when data and descriptors do not
overlap output. It retains the existing zero-copy run iterator and parser/history
allocation behavior. The independently frozen cold nonalias fixture makes six
parser/history allocations, while a settled reusable arena needs no new heap.
The single-input sync-flush path is unchanged.

Metadata and copies use the existing scratch allocator. One-shot cap/profile
calls charge them to the same whole-operation requested-heap ledger. Reusable
arena calls charge their actual backing nodes, including node headers, through
the existing arena physical ledger. Quota/OOM failures clean up all completed
copies and metadata and restore the original logical output prefix.

Output growth can invalidate caller aliases and descriptor storage, and spare
output bytes can be overwritten after the operation starts. The scratch snapshot
protects this operation. After a failed call that reached emission, retry with
stable original plaintext and rebuilt descriptors rather than stale aliases to
an output allocation that may have moved. Tests use that valid retry to verify
allocator/ledger cleanup and arena reuse.

The regression oracle contains `pre!`, the complete sync-flush wire, and the final
`03 00` fixed block used for strict decoding. Its frozen length is 4360 bytes and
SHA-256 is `7fa2d0aad775da84181dbe95ece8b14a120c776e47d76d59b1845959291bb1fc`.
The earlier alias path returned 4359 bytes and decoded 4096 wrong bytes out of
8192 after the old output was freed and poisoned. Both default and profile-only
paths now match the complete oracle and decode the original 8192 bytes.

`src/deflate/encode/sync_flush_chunks.zig` owns chunk emission;
`sync_flush_chunks/alias_runs.zig` owns overlap preparation and original run
iteration; `sync_flush_chunks/history.zig` owns bounded rolling history.
Independent tests cover moving/poisoning output, no-growth overwrite, first and
future aliases, logical/spare regions, descriptors, contiguous/separate/mixed
runs, one-shot/reusable/default/profile/D/D-1, and every real OOM allocation point.

Narrow native validation:

```sh
zig test -ODebug src/deflate.zig \
  --test-filter 'Deflate sync flush chunk alias contracts'
zig test -OReleaseSafe src/deflate.zig \
  --test-filter 'Deflate sync flush chunk alias contracts'
zig build -j2 test -Droot-test-filter='sync flush' \
  run-deflate-split-history-interop --summary all
zig build -j2 test -Droot-test-filter='Deflate arena' --summary all
```

The same alias contract runs on 32-bit WASI:

```sh
zig test src/deflate.zig -target wasm32-wasi -OReleaseSafe -fsingle-threaded \
  --test-filter 'Deflate sync flush chunk alias contracts' --test-no-exec \
  --stack 8388608 -femit-bin=/tmp/vort-sync-flush-alias-20261110.wasm
node tools/deflate/clone/wasm_gate.js \
  --output /tmp/vort-sync-flush-alias-20261110-wasi.json \
  /tmp/vort-sync-flush-alias-20261110.wasm
```
