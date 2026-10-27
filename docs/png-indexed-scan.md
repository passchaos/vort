# Bounded exact indexed scanning for PNG

The scan-selected lazy parser retains the original scalar-window matching
semantics with three sources: backwards scanning for tiny/low-budget inputs,
a first-byte chain from 2048 bytes, and a prefix/ordinal chain from 8192 bytes.
Indexed paths require a window of at least 64 bytes and at least eight chain
slots. The same parser loop owns token growth, lazy lookahead and match acceptance.

First-byte chains use absolute heads and 16-bit ring deltas. Prefix chains
combine a 4096-bucket three-byte index with modulo first-byte ordinals, allowing
failed prefixes to be skipped while spending exactly the original budget.
Physical windows cap at 32768 bytes, so ordinal differences remain unambiguous.
Absolute heads reject anchors older than complete position cycles. Hash
collisions with other first bytes remain free; same-byte false prefixes still
consume budget. Closest-distance and longest-match ties remain unchanged.

The sources own bounded stack state: 67 KiB maximum for first-byte indexing and
161 KiB maximum for prefix indexing on supported pointer widths. They add no
heap allocation and retain the existing token owner. Complete homogeneous spans
batch sixteen anchors with eighteen-byte source lookahead, scalar tails and
ring/end boundaries. Every head, delta, rank and count matches a scalar control.

Validation on the actual dependency passes 100 LZ77 ReleaseFast tests, 19
DEFLATE level/parameter tests, 13 optimized Debug controls, and all 87 bounded
imx PNG tests in Debug/ReleaseFast. Baseline x86_64 and big-endian PowerPC compile
the same indexed controls. Tests cover all normalized budgets/ties, every
vector source ending, ownership failures, independent reuse, hash collisions,
full-window endpoints and u16 ordinal/position cycles.

Ninety original-corpus complete outputs at levels 1/6/9 and Adaptive/Up match
all saved native PNG bytes and requested allocator records. Image-png and libpng
independently reproduce every original pixel in 180 fresh candidate checks.
Thirty-six paired complete-encoder CPU cases give 18.356x aggregate level-6
improvement against the previous c148740 dependency and 1.201x level-6
throughput against the same native image-png reference. This selected scope does
not establish whole-codec leadership; wider reference timing remains ongoing.
Level 9 still has substantial optimal-parsing and match-extension costs.

Core modules and their tests live under src/lz77/scan/. Reproduce with:

```sh
zig test src/lz77.zig -O ReleaseFast
zig test src/lz77.zig -O Debug --test-filter indexed --test-filter 'prefix scan'
zig test src/deflate.zig -O ReleaseFast --test-filter level --test-filter 'runtime deflate parameters'
```

Full before/after PNGs, counters, source and binary fingerprints, sample records
and the separate level-9 profile are retained by the imx consumer under
/nav_env/Temp/imx-png-index/. Resource claims refer to requested heap plus the
explicit bounded index state; process RSS and total call-stack peaks have their
own measurement scope.
