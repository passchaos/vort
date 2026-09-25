# Zstd private mixed-corpus comparison

This report covers 25 regular files from an anonymized private corpus measured
on 2026-09-24, totaling approximately 452 MiB. The corpus intentionally mixes
already-compressed archives, images, video, PDFs, executables, and two text
files. It is useful for exposing raw-block throughput, block setup overhead,
literal-heavy compressed blocks, and dense sequence execution, but it is not a
balanced standard compression corpus. Exact local paths, names, sizes, and the
alias mapping are intentionally kept outside version control.

The current benchmark uses the small-block raw/all-FSE routing candidate based
on `ac4ef4ae`, Zig 0.16.0 ReleaseFast on Apple M1 Pro, one codec thread, and
Homebrew libzstd 1.5.7. Each source is compressed once by libzstd level 1, then
decoded through both caller-owned implementations. Before timing, the harness
checks both decoded outputs byte-for-byte against the source. Timed iterations
target at least 128 MiB per file, are capped at 20,000, and each reported row is
the best of five rounds. The input cap is 256 MiB, so every corpus member is
included. Per-file rows remain in the ignored local benchmark record; the
tracked report retains only aggregate evidence.

The one-shot matrix has 4/25 rows above libzstd, a 0.9379x median ratio, a
0.9180x geometric mean, and a time-aggregated 0.8878x ratio. The reusable
matrix has 7/25 rows above libzstd, a 0.9689x median, a 0.9542x geometric mean,
and a 0.8903x aggregate ratio. Absolute ratios move with host load even though
each Vort/libzstd pair ran in one process; use the independent-binary A/B
figures for claims about the routing change itself.

Every file was also validated with libzstd levels 3 and 9 through the one-shot
path. Those runs use the same byte-for-byte output checks and a 128 MiB target
per file:

| Compression level/API | Files | Vort wins | Median ratio | Geometric mean | Time-aggregated ratio |
| --- | ---: | ---: | ---: | ---: | ---: |
| level 1 one-shot | 25 | 4 | 0.9379x | 0.9180x | 0.8878x |
| level 1 reusable | 25 | 7 | 0.9689x | 0.9542x | 0.8903x |
| level 3 one-shot | 25 | 9 | 0.9729x | 0.8851x | 0.7956x |
| level 9 one-shot | 25 | 5 | 0.9273x | 0.8894x | 0.7040x |

Thus the matrix validates 100 file/mode combinations: all 25 files in both
level-1 APIs and all 25 files at each additional compression level. All source
hash and decoded-byte comparisons passed.

The raw/all-FSE grouped executor and bounded match-copy specialization raised
the first follow-up's level-1 one-shot/reusable aggregate ratios from
0.7321x/0.8056x to 0.8803x/0.9173x. The subsequent small-block routing change
uses independent-binary A/B for its performance claim because the absolute
libzstd ratios vary with host load; its current full-matrix ratios are shown
above. The remaining worst cases are tiny inputs dominated by fixed frame
setup and level-3/9 PDFs whose blocks still fall outside the optimized
raw/all-FSE shape. Those paths, followed by the remaining private-binary-a
Huffman and sequence loops, are the next optimization targets.
