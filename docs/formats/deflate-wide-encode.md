# Wide incremental Deflate encoding

Incremental raw stored, fixed and best encoders; zlib/gzip fixed and best
wrappers; and the PNG ultrafast zlib encoder use `core.StreamCount` for logical
stream quantities. It is `u64` on 32-bit targets and `usize` on 64-bit targets.
This removes the 32-bit 4 GiB cumulative limit without requiring a large caller
buffer. A one-shot slice is still limited by its physical address space.

The widened public quantities are accepted input, published output, exact-size
pledges and input caps, snapshot cumulative totals, wrapper stream/member counts
and indices, and runtime parameter-change counts. The persistent rolling match
finder uses the same type for absolute positions and head/previous-chain nodes.
PNG zero/closing runs can span the complete logical stream.

Per-step `core.Progress`, slices, buffer and token capacities, block lengths,
history sizes, queue/carry positions and ring slots stay `usize`. Raw stored LEN
stays 16-bit; RFC1951 distances and length codes retain their wire bounds. Gzip
ISIZE remains the low 32 bits of the member's full input count. Zlib Adler and
gzip CRC cover each physically accepted source byte.

## Checked admission and publication

Encoders check full offered input against the cumulative counter, hard input
cap and exact pledge before accepting it. Block-planned encoders also check
matcher advancement before changing history or committing a block's wire bytes.
Wrapper lifetime input and output are checked separately from each member's
counts. Starting a new wrapper member preserves lifetime totals and checks its
member-count capacity; reset returns cumulative counts to zero.

Raw and wrapper output drains bound the entire caller window by the remaining
count capacity. A final representable prefix returns ordinary `need_output`
progress. A later drain at `StreamCount` maximum refuses pending output with
`IntegerOverflow` before copying or advancing its queue offset. Already
published progress remains committed. Parameter and completed-member counts
use checked advancement. PNG additionally checks queued bytes and reservoir
serialization before changing bit state and bounds each run token before
narrowing its length.

Normal matcher candidate order and no-flush wire determinism are preserved.
The rolling matcher retains its original `min(block.len, 4096)` initial token
reservation policy. If later token growth fails, it restores the absolute
position and invalidates the partially changed index. A retry reseeds from
unchanged caller history and can select different valid matches after that
allocation failure.

64-bit counter types and encoder layouts remain unchanged. The PNG encoder's
32-bit context grows from 220 to 244 bytes; its 128-byte queue, 8-byte carry and
zero requested heap workspace remain unchanged. Wider rolling-match nodes
increase its bounded 32-bit table storage; capacity remains fixed by the parser
window and hash-table policy.

## Validation entrypoints

```sh
zig build -j2 test-deflate-wide-encode
zig build -j2 test-deflate-wide-encode-x86
zig build -j2 test-deflate-wide-encode-wasm
zig build -j2 run-deflate-wide-encode-diff
zig build -j2 run-deflate-wide-encode-long-diff
```

The public boundary contracts run unchanged on native, actual x86 and WASI.
They first encode and verify a lawful repeated prefix, translate its logical
position across the 32-bit boundary, then encode and independently decode every
physical suffix byte. Internal matcher contracts inspect actual chain links and
compare translated greedy/lazy plans. Counter-maximum tests check guard bytes,
checksums, pending offsets, input/history admission and member transitions.

The long oracle separately replays real inputs larger than 4 GiB through bounded
caller buffers. Python/libz verifies the generated source, all decoded bytes,
checksums, stream end and wrapper footers, and compares input/output receipts
with the encoder's wide snapshots. Native and x86 probes report pointer and
logical-count widths and provenance. PNG includes both an all-zero run and a
nonzero byte after a run crossing 2^32. Stored output also crosses 4 GiB.
Reports record actual replay independently of the boundary-state models.

The validated native and x86 full Deflate suites each pass 660 tests; each
native/x86/WASI wide encoder gate passes 10 tests. The small and long oracle
matrices each pass 18 cases against libz 1.2.11. Every long case physically
accepts 4,294,967,313 bytes, and all nine native/x86 wire SHA-256 pairs match.
Stored wire reaches 4,295,295,003 bytes. PNG zero/dirty runs reach
4,294,967,312 bytes with zero encoder heap requests; all cases release their
requested heap after deinit. Reproducible receipts and binary/source provenance
are written to `zig-out/deflate-wide-encode-{smoke,long}/report.json`.

Counter-maximum PNG controls also validate a 32-byte remaining output budget:
16 source bytes produce a 24-byte prefix and return `need_output`; retrying the
unrepresentable word returns `IntegerOverflow` with unchanged checksum, bit
state, carry, snapshot and caller guards. Run, held-word and closing-framing
budgets are checked before their corresponding state changes. The WASI gate
also exercises the public one-shot decoder oracle through an ordinary function
entry; native semantic decode retains its 64-byte function alignment.
