# Prepared standard Zstd decode dictionary, 2026-11-03

Standard full Zstd dictionaries carry a Huffman literal tree, three sequence
FSE tables and three repeat offsets before their history content. The decoder
used to validate and reconstruct that entropy state on every frame through
`initialSequenceFrameState` and `parseStandardDictionaryState`, even when the
same dictionary decoded many frames.

The new `PreparedDecodeDictionary` validates the dictionary once and stores an
immutable `PreparedDecodeState` snapshot: dictionary ID, borrowed content
identity and the complete initial `SequenceFrameState`. `handle()` returns a
borrowed `NativeDictionary` carrying a pointer to that snapshot. Existing
frame decode entry points already accept `NativeDictionary`, so they reuse the
snapshot without a new options field. `initialSequenceFrameState` copies the
snapshot into the mutable per-frame state and never mutates the prepared owner.

Ownership is explicit: the prepared owner must stay alive and unmodified while
any handle decodes, and it must not move after a handle is published because
the handle points into its state. Raw-content dictionaries prepare an empty
entropy snapshot and keep their existing history behavior. A handle whose ID
or content slice no longer matches the snapshot is rejected with
`error.InvalidDictionaryMetadata` before any entropy work; a mismatched frame
dictionary ID still returns `error.NeedDictionary`.

## Validation

The trained libzstd repeat-dictionary fixture (`libzstd-trained-repeat.dict.hex`)
and its 2,304-byte frame exercise the real Huffman/FSE path. The prepared
handle decodes the same bytes and CRC-32 as the ordinary dictionary, and the
test-only entropy-parse counter stays at zero across the prepared decode while
the ordinary path increments it. A shortened content slice fails with
`InvalidDictionaryMetadata` and performs no parse; a changed ID fails with
`NeedDictionary`; a raw dictionary handle carries no entropy pointer. Focused
prepared-dictionary and decoder-layout tests pass in Debug, ReleaseSafe and
ReleaseFast. The complete ReleaseSafe and ReleaseFast Zstd suites each pass
1,270/1,270 tests with exit zero.

## Reuse measurement

`tools/zstd/prepared_dictionary_probe.zig` decodes the 702-byte trained frame
into a preallocated 2,304-byte output with either the ordinary dictionary or
one prepared handle. Five 20,000-decode rounds on the host give median totals
371.5 ms versus 58.9 ms (ratio 0.157, about 6.3 times less time). Both paths
return the same CRC-32 `1658167111` and the same output. The frame is
intentionally tiny, so dictionary entropy reconstruction dominates; larger
frames dilute this ratio. This is a per-frame reuse microbenchmark, not a
whole-file or memory comparison.

```sh
zig build build-zstd-prepared-dictionary-probe
zig-out/bin/vort-zstd-prepared-dictionary-probe \
  src/zstd/testdata/libzstd-trained-repeat.dict.hex \
  src/zstd/testdata/libzstd-trained-repeat.frame.hex 20000
```

This establishes the reuse and ownership contract. It does not yet provide a
whole-file/dictionary streaming comparison, avoid the per-frame table copy, or
establish a memory/RSS lead over libzstd's DDict.
