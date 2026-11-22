# Current-source codec functional differential campaign, 2026-11-20

The current Deflate, Zstd and Brotli source passed a deterministic deep
structure-aware campaign after the incremental borrow and lifecycle fixes.
The raw directory preserves an immutable source hash snapshot, executable
identity, command, runtime reference probe and terminal receipt.

```sh
zig build -j2 -Doptimize=ReleaseFast run-codec-differential-fuzz \
  --summary all -- --deep --seed=0x20261120
```

The native tool uses runtime zlib 1.2.11, libzstd 1.4.8 and libbrotli 1.0.9.
This complements the separate pinned libzstd 1.6.0 incremental interoperability
campaign. The run occurred alongside full-library verification and supplies
functional evidence only.

## Observed results

ReleaseFast and a same-seed Debug rerun each exited zero with all 7/7 build
steps succeeding. Their aggregate counters agree exactly. Each generated 14,684
valid streams, including 9,835 format-feature variants. All 14,684 Vort
round-trip and exact-size checks passed. Cases span eight content patterns,
fixed boundaries through 64 KiB and independent random sizes, dictionaries,
optional gzip headers, concatenated/skippable Zstd, concatenated gzip,
Brotli metadata and explicit Large Window encoding.

All 408,571 truncation comparisons passed their applicable agreement rules:
401,698 rejected prefixes and 6,873 accepted prefixes with matching output.
The campaign applied 498,324 mutation operations: 220,260 XOR, 73,420 bit flips,
102,618 overwrites, 33,758 double overwrites, 34,206 insertions and 34,062
deletions. It observed no failing output-agreement assertion or parser panic.

The existing tool's `reference_interop` counter also includes Vort-only RAW or
serialized Brotli dictionary and magicless Zstd contracts. Its value of 14,684
is therefore a decode-contract total rather than an external-reference count.
The mutation `one_sided_divergence` total of 12,108 likewise combines external
one-sided acceptance with content changes in variants lacking a system
reference. These results do not establish complete malformed-stream acceptance
parity. The [classified reporting increment](codec-differential-reporting-20261120.md)
now separates those directions and saves bounded replayable samples. It also
identifies a dynamic Deflate distance-tree admission gap requiring a separate
functional repair.

[Raw evidence](data/codec-functional-differential-current-20261120/) includes
the complete outputs and terminal receipts for both build modes. Full library
execution and native/WASM build checks also completed: 406/406 build steps,
5,825 passed tests and two skipped, including 5,732 root-library passes. Those
results bind the frozen source before the later reporting and dynamic Huffman
admission work. Earlier complete Debug/ReleaseSafe snapshots retain their
distinct identities. No ratio, throughput, peak-memory or industry-leadership
claim follows from this functional campaign.
