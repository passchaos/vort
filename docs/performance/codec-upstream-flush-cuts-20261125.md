# Upstream flush checkpoint conformance, 2026-11-25

This is correctness evidence, not a speed measurement. The codec source is
`7859a67b`; only the differential harness changed. The run used Zig 0.16.0
ReleaseFast, system libz 1.2.11, local libzstd 1.6.0 and local libbrotli 1.2.0.
The Brotli and Zstd runtime producers and linked decoders report matching
versions.

```sh
corpus="$HOME/Work/corpora/silesia-20261025/files"
LD_LIBRARY_PATH="$HOME/Work/brotli/build-vort:$HOME/Work/zstd/lib" \
  zig build -Doptimize=ReleaseFast -j3 run-codec-differential-fuzz -- \
  --real-limit=67108864 --real-flush-cuts --real-file="$corpus/xml" \
  --real-file="$corpus/ooffice" --real-file="$corpus/mozilla"
```

These are the same complete files and input hashes as in the
[previous full-file receipt](codec-upstream-real-20261124.md). Upstream flushes
at 64 KiB intervals. The harness records the compressed end of each completed
nonfinal flush and selects the first, middle and last distinct boundaries.
These are the plaintext lengths at those boundaries:

| File | First | Middle | Last |
| --- | ---: | ---: | ---: |
| xml | 65,536 | 2,686,976 | 5,308,416 |
| ooffice | 65,536 | 3,080,192 | 6,094,848 |
| mozilla | 65,536 | 25,624,576 | 51,183,616 |

All 15 raw Deflate, zlib, gzip, Zstd and Brotli wires passed reference, Vort
one-shot and exact-size checks. Both incremental schedules passed (30 runs).
All 15 final-byte cuts were refused by the reference and passed the existing
30 Vort tail replays. The reference also rejected all 45 unfinished flush
prefixes. Both Vort schedules consumed the exact compressed cut and reported
truncation (90 replays, 18 per wire type). No emitted byte differed from known
plaintext. Except for prevalidated Zstd, the published prefix was exactly the
length above; prevalidated Zstd published none of its unfinished frame.

The README smoke produced 30 new checkpoint replays while preserving all five
upstream wire receipts and existing tail counts. Explicit files with zero,
one and two nonfinal flushes produced 0, 10 and 20 schedule replays without
duplicating cuts. This lane does not cover dictionary-backed or arbitrary
inside-block cuts; the existing generated and wide-Brotli modes remain separate.
