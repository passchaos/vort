# AArch64 Adler byte-column kernel

The compiled Adler backend now selects NEON when the little-endian AArch64
target guarantees that feature. Portable and AVX2 implementations retain
their existing paths; other targets, including big-endian AArch64, use the
established fallback. The public backend classifier adds `neon`; checksum
state, digest and update signatures retain their existing geometry.

The kernel processes 32-byte blocks within floor(NMAX/32)*32 = 5,536-byte
chunks. Four u16 byte-column vectors accumulate at most 173*255 = 44,115 per
lane. Prefix and weighted u32 sums retain zlib's NMAX overflow bound. Pairwise
widening, column addition and multiply-accumulate use small target-gated NEON
primitives, then reduce horizontally only at a chunk boundary. Short updates
below 32 bytes retain the previous scalar path. No heap allocation is added.

Cached simd-adler32 0.3.10's NEON implementation provided the column/prefix
strategy reference. The Zig implementation is checked against the independent
scalar recurrence and system zlib. A generic-vector candidate was rejected
after LLVM scalarized pair shuffles into lane moves and reduced throughput
to about 0.47x on long buffers. The final fused primitives measure about 4.8x on
1.2-KiB through 1-MiB standalone buffers, with small-fragment controls retained.

The normal imx PNG consumer provides the complete acceptance evidence.
Fifteen strict decode cases improve, with 1.159922x throughput geomean and
1.129142x aggregate. Current strict throughput changes from 683.116 to
771.336 MiB/s, remaining 0.961271x the fresh image-png peer. No-Adler controls
are neutral at 0.997257x aggregate. Every full pixel buffer and requested-heap
record remains exact. All 120 encoded PNGs and allocation records retain the
frozen token-run baseline bytes. This does not establish complete PNG/JXL
performance or resource leadership.

Twelve Adaptive encoder controls at levels 1/6/9 give 1.034722x geomean and
1.009925x aggregate, retaining three small regressions and a 0.992499x
minimum. The independent simd-adler32 0.3.10 NEON worker is near parity on
large buffers; its 1-MiB native/reference ratio is 1.004332x and the 5,552-byte
boundary ratio is 0.985862x. The outside reference's actual NEON selection is
checked before timing.

ReleaseSafe scalar/basis/fragment controls and the no-NEON fallback execute
successfully. The checksum suite passes 21 tests, zlib/Adler 107 and bounded
PNG 87. x86 baseline, AVX2 and big-endian AArch64 compile checks pass. Thirty-six
valid/bad-Adler/bad-CRC PNG controls preserve acceptance, errors and all
accepted pixels; disabling Adler does not disable CRC validation.

The [owning imx report](https://github.com/passchaos/imx/blob/main/docs/evidence/png-adler-neon.md)
records frozen sources, executables, all samples, independent oracles and
actual heap/RSS. Builds use one job with a 4-GiB address-space limit; runtime
measurements remain serial under a 1-GiB limit. Remaining work includes
per-fixture PNG inflate/reconstruction costs and broader JXL functionality,
quality, ratio, speed and memory coverage.
