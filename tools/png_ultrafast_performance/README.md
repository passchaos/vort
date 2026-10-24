# Incremental PNG ultrafast core performance

The implementation batches complete source words, packs up to four literals
per reservoir write, scans zero words without carry copies, and updates Adler
once per accepted batch. Proven all-zero batches use the scalar-equivalent
Adler recurrence. Context size, 128-byte pending queue, eight-byte input carry,
zero heap allocation, static Huffman tree and flush/final framing are unchanged.

Correctness: Debug and ReleaseFast each pass 18 owning tests and ordinary public
544-source / 1727-check fdeflate-bit/zlib verification. The unchanged imx consumer
passes 56 owning tests per mode, ordinary actual-root row/flush/Adam7/budget
checks and all 30 legal PNG cases with image-png/libpng/scalar validation.

The real benchmark uses all 15 immutable images (90,083,998 raw bytes) with both
adaptive and Up filters; source/harness and flags are identical in old/new imx
binaries and only the Vort root differs. Four independent paired rounds reverse
implementation and case order. CPU 13 is exclusively scheduled through the
cooperating row/core workers. Input/decode/SHA/file I/O and allocation measurement
are outside the timer; fresh output/encoder creation, full encode, finish and
destroy are inside. All new PNG outputs are byte-exact to baseline.

| Cases | Geometric speedup | Aggregate speedup | New/Rust geometric speed ratio |
|---|---:|---:|---:|
| All 30 | 1.885x | 1.718x | 0.307 |
| Adaptive 15 | 1.529x | 1.491x | 0.259 |
| Up 15 | 2.324x | 2.367x | 0.362 |

The overall geometric ratio to Rust improves from 0.163
to 0.307; it still trails Rust. This is a core-only
causal change measured through the complete PNG pipeline and does not combine
the separate row-filter optimization. Isolated weak-image core profiles showed
3.12–3.43x gains for Transparency/Exoplanet; full-pipeline gains are smaller.

Evidence files: `/nav_env/Temp/vort-png-ultrafast-performance/full-real/` contains
validation.json, samples.json (360 records) and summary.json; source-binding.json
and perf captures live in the parent directory. `tools/png_ultrafast_performance/run.py`
reproduces the full immutable corpus without reducing the dataset.

Summary SHA-256: `af405e461b8a40e65e65a46dd79778ca80b5ef6457070c443deec195f0ffe933`.
Samples SHA-256: `d84a4ca3d13839c89fc113387694f165ab45f607aa471fb14d64222d42814ac1`.
Validation SHA-256: `c540157b8ac6055a41160abaac1ae2d0bfe3feb1d67dd0dc92bc3002aca1eda1`.
