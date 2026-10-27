# Brotli reserved bit-field writes

Date: 2026-10-28. Baseline: `905a4640`. The compression-library industry-best
functionality and performance goal remains incomplete.

The former private writer and its tests are separate modules under
`src/br/encoder/bit_writer*.zig`. General fields whose complete output span
already fits caller-owned capacity now use little-endian word stores. The old
partial byte is merged into the value before writing; 63-bit fields at an
initial offset can use a ninth spill byte. Fields that need capacity growth
still use the original byte loop, so allocation requests and partial failure
state keep their original behavior. Huffman fields retain the original narrow
writer; the measured replacement did not justify changing that path.

Independent scalar tests compare all offsets 0–7, widths 0–63, values including
the highest input bits, exact and insufficient capacities, complete backing
buffers, and growth/failing-allocator ledgers. Huffman checks cover every width
1–15 and bounded failure progress. The focused Debug filter passes 26/26.
An [actual Wasm consumer](brotli-bit-writer-wasm.md) compares successful reserved
writes against a separate bit-by-bit reference and checks logical-output guard
bytes. Public Wasm and Node interoperability checks also pass.

## Ordinary before/after results

All twelve Silesia files at 4/16/64 KiB produce 36 cases. The public benchmark
uses three reversed-order process sweeps and five Vort/reference alternating
rounds of three calls each. Per-case medians yield these geometric time ratios:

| Implementation / baseline | q8 time ratio |
| --- | ---: |
| General plus Huffman, restore old byte after word store (withdrawn) | 1.004613 |
| General only, restore old byte after store (superseded) | 0.994404 |
| General plus Huffman, merge old byte before store (withdrawn) | 0.999721 |
| Retained general only, merge before store | 0.996839 |

The retained implementation's separate q3 matrix measures 0.998432. Every
matrix preserves input, Vort/reference wire hashes, sizes and settings across
versions, with actual q8 or q3/generic/windows 16/16. The small final points
(about 0.32% for q8, 0.16% for q3) do not establish statistical significance
or a gain on every input. No Huffman speed claim is retained. The tested
storage/error behavior and module boundary are also useful foundations for
further preparation reuse.

Measurements run on an Intel i7-10700K, one thread pinned to CPU 2, Zig 0.16.0
ReleaseFast, native x86_64 `skylake+pku+sgx`. The reference is the local Brotli
1.2.0 checkout `558fc64`, compiled with GCC `-O3 -DNDEBUG -march=native`;
compiler work excludes CPU 2 and sibling 10. These point comparisons do not
close the previously measured large q8 throughput gap.

[Raw rounds, rejected-source snapshots and source identities](data/brotli-bit-writer-reserved-20261028/)
retain all measured variants. The next writer work should share immutable
command/distance preparation within the preferred literal-context group,
keeping final byte-length ties and the full candidate policy. A later exact
counting pass must handle simple-code widths, trace allocation identities and
live plan lifetimes explicitly.

The full native/Wasm compile gate passes 210/210 steps. After remote rebase,
the unchanged source completes the scalar tests and actual Wasm kernel probe
in 8/8 steps, with 26/26 scalar tests and both independent method case counts.
CLI help also completes. Full logs and explicit exits are retained alongside
the measured source variants.
