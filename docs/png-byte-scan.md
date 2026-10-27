# Exact backwards LZ77 candidate scanning for PNG

The PNG dependency branch adds a bounded backwards byte-search module to the
existing scalar-window match finder. It probes the newest byte first and then
uses portable 32-byte vector comparisons to skip impossible first-byte anchors.
After selecting an anchor it spends the historical candidate-budget slot before
rejecting an unequal two-byte minimum prefix. Candidate order, budgets, overlap,
minimum-match clamping and newest-distance ties retain the scalar contract.

The helper owns no heap allocation and reads only complete vectors within the
explicit history range. Its scalar tail retains empty, short and unaligned
ranges. It is separate from hash-chain, dictionary and streaming match finders.

Validation on the exact published source includes exhaustive backwards search
against a scalar oracle for every byte and unaligned range, full-window repeated
and missing anchors, match-budget and tie-decision comparisons, all 89 LZ77
ReleaseFast tests and focused Debug comparisons. Baseline x86_64 and big-endian
PowerPC compile the same controls. The imx normal root passes all 87 bounded PNG
tests in Debug and ReleaseFast.

Fifteen unchanged original normalized rasters, numeric levels 1/6/9 and
Adaptive/Up yield 90 complete before/after/Rust PNG cases. All native output
bytes and untimed requested allocator records match the previous dependency.
Both unchanged image-png and system libpng independently decode every native
and Rust case, reproducing every original pixel in 360 complete checks. This
establishes compatibility for that matrix; measured acceleration and compression
ratio comparisons are recorded separately by the imx consumer.

Reproduce core controls with:

```sh
zig test src/lz77.zig -O Debug --test-filter scan
zig test src/lz77.zig -O ReleaseFast
zig test src/deflate.zig -O ReleaseFast --test-filter level --test-filter 'runtime deflate parameters'
```

The optimization preserves the existing compression choices. Wider corpus,
levels, complete runtime behavior and performance comparisons remain ongoing;
this increment does not establish compression-library leadership.
