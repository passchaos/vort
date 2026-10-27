# Actual fixed-Huffman costs and exact sliding optimal length minima

Fixed cost planning now charges the emitted fixed-code-plus-extra sizes for
length symbols 280 through 284: lengths 115–130 cost 12 bits and 131–257 cost
13 bits. Length 258 remains the eight-bit code 285. Dynamic coding plans use
the same actual bit counts without the historical one-bit subtraction. This
corrects fixed/dynamic size selection and capacity planning.

An independent test measures BitWriter's actual emitted positions for every
length 3–258 and eight distance boundaries. The previous implementation first
fails with actual 35 bits versus predicted 34; the corrected implementation
passes every case. Round-trip and level tests cover complete stream validity.

The fixed-cost optimal parser groups equal length costs into eight ranges.
Bounded monotonic queues maintain suffix minima as positions move backwards,
including partial ranges, configured minimum/maximum lengths and EOF cuts.
Equal-cost positions retain the longest-length tie. Queue state stays below
9 KiB and adds no heap allocation. Caller-supplied entropy models retain their
full generic path.

Validated three-byte prefixes let dominated candidates spend their original
budget without full extension. A four-byte end probe rejects lengths covered
at an equal-or-cheaper distance. The complete scalar parser remains available
as a test reference. Arbitrary suffix costs and parser comparisons verify all
costs, steps and reconstructed tokens across clipped length ranges and ties.

Current validation passes 102 LZ77 ReleaseFast tests, 23 selected DEFLATE tests,
17 optimized-parser Debug tests, 10 fixed-cost/dynamic-stat Debug tests, and
all 87 imx bounded PNG tests in Debug/ReleaseFast. Baseline x86_64 and big-endian
PowerPC compile the optimal controls.

All 90 original-corpus candidate outputs pass 180 fresh image-png/libpng full
pixel checks, with zero counted live heap after destruction. Fourteen encoded
outputs change after cost correction; total level-9 bytes increase by 161
across 35.7 MB, while levels 1 and 6 remain unchanged on this corpus. This is a
functional cost-model change, so compatibility evidence uses complete decoded
pixels and actual size records.

Thirty-six paired complete-encoder CPU cases give a level-9 geomean/aggregate
gain of 1.936234x/2.285492x against the published indexed-scanner snapshot.
Wider reference measurements remain ongoing; numeric high-level throughput
and complete PNG/JXL leadership still have explicit gaps. Commands:

```sh
zig test src/lz77.zig -O ReleaseFast
zig test src/lz77.zig -O Debug --test-filter optimal
zig test src/deflate.zig -O ReleaseFast --test-filter 'fixed bit planning' --test-filter level
```

Sources, complete outputs, independent raw comparisons, source/binary hashes,
paired samples and the retained previous cost mismatch are under the imx
consumer's /nav_env/Temp/imx-png-index/ evidence directory.
