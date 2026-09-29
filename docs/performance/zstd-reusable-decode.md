# Matched reusable Zstd decode comparison

The reusable reference benchmark now compares
`NativeFrameDecoder.decodeIntoSlice` with `ZSTD_decompressDCtx`. Previously it
compared a warmed Vort decoder with repeated `ZSTD_decompress` calls, which
include reference context creation/destruction. That overstated Vort's advantage
on small frames and did not establish equivalent reusable-API performance.

Both contexts are now created outside timing, warmed, and validated against the
original input. Five samples alternate codec order, retaining the fastest sample
per codec as before; complete output is checked again after timing. The
allocation benchmark still measures the separate one-shot allocating Vort API.
CSV rows identify `vort_api` and `reference_api` explicitly. Old reusable CSVs
must not be mixed with this series.

```sh
zig build -Doptimize=ReleaseFast run-zstd-reference-bench -j1 -- \
  --reusable --iterations 5000 --csv /tmp/zstd-reusable.csv
zig build -Doptimize=ReleaseFast run-zstd-reusable-reference-bench-gate -j1
zig build -Doptimize=ReleaseFast run-zstd-reference-bench-path-smoke -j1
```

The gate validates API pairing and the complete 13-case matrix. Its reusable
smoke floors are separate from the existing one-shot floors; neither proves
industry leadership. To require a 1.20x minimum on every measured row:

```sh
python3 tools/zstd/reference_bench_gate.py --api-mode reusable \
  --csv /tmp/zstd-reusable.csv --minimum-ratio 1.20
```

The initial matched matrix on Apple M1 Pro (Zig 0.16.0 ReleaseFast, Homebrew
libzstd 1.5.7, one codec thread) puts `numbered_json` at 1.0423x and `raw256k`
at 1.0298x. The small JSON row was slower than Vort's one-shot path despite
hitting its table caches: it still used the generic sequence executor.

The candidate shares the small predefined-LL/compressed-OF/predefined-ML Huffman
executor between the one-shot route and eligible terminal blocks in the reusable
route (2--256 sequences and Huffman widths of at most seven bits). The one-shot wrapper builds its offset table as before; the reusable
caller borrows the table from its cache without copying the 4 KiB offset-table
slot. Selection occurs at the block entry; the generic reusable sequence
executor retains its original source and branch structure. The common
executor keeps bounded grouped bit reads, direct single-literal lookup, exact
short-match copies, and the existing output/history checks. Blocks requiring
continued sequence state, dictionaries, larger Huffman alphabets, or other mode
combinations retain the existing executor.

## Paired measurements

Frozen baseline and candidate binaries run in alternating order. The
[recorded observations](data/zstd-reusable-small-m1-20260929.json) include all
45 pairs, input hashes, executable hashes, API identities, and iteration counts.
The baseline includes the corrected DCtx benchmark and the preceding raw-copy
change, so the speedup compares identical APIs and measurement code.

| Case / API | Iterations/sample | Candidate/baseline median | Geometric mean | Wins |
| --- | ---: | ---: | ---: | ---: |
| `numbered_json`, reusable | 50,000 | 1.8151x | 1.8132x | 15/15 |
| `numbered_json`, one-shot | 50,000 | 0.9992x | 0.9997x | 7/15 |
| `large_json`, reusable | 500 | 1.0017x | 0.9975x | 8/15 |

The optimized reusable JSON row reaches 1.8870x median versus
`ZSTD_decompressDCtx`, with a 1.8632x minimum. Every run clears 1.20x. The
one-shot control is 1.3180x median versus `ZSTD_decompress`; the large reusable
JSON control is 1.2356x versus DCtx. Host background activity remained present,
so sub-percent control movements are treated as noise. No agent builds ran
during the paired campaigns.

The first implementation inserted selection inside the generic sequence
executor. It improved reusable JSON by 1.6715x but reduced large reusable JSON
to 0.9822x (only 2/11 wins), so its campaign was stopped and that layout was
removed. Selecting at the block entry and borrowing the cached table restores
the control while improving the target further.

The overall decode objective remains open; a single-case improvement is not
evidence that the whole format, corpus, API, and platform surface leads. The
raw row remains below 1.20x. The user accepted that bandwidth-bound gap and
authorized private/Downloads corpus testing without requiring the synthetic
raw row to clear 1.20x first.

## Validation

The targeted ReleaseSafe oracle verifies warmed Huffman and FSE cache hits,
requires the specialized literal/match paths, and compares bit mutations of
every sequence-description/payload byte with the generic block decoder. It
checks exact error types, output guards, and recovery to the original frame
after cache entries have changed. All 670 direct ReleaseFast Zstd tests pass.

The benchmark path smoke covers both API modes on generated compressed frames
and supplied raw frames. Wrong/mixed API pairs, invalid input arguments, and
non-finite/non-positive explicit throughput floors are rejected. Applying the
1.20x floor to the current complete one-shot matrix correctly fails on raw256k.

The 276-case libzstd compatibility probe and all nine upstream decodecorpus
campaigns pass: 9,900 frames, all 64 sequence-mode combinations, and real
reusable table hits on compressed campaigns.

`zig build check -j1`, both 13-row reference gates, and the five-row decode
profile gate pass on the final candidate. Both final reference matrices carry
the same executable SHA-256 as the paired experiment. Their `raw256k` ratios
are 1.1185x for one-shot and 1.0086x for reusable decoding; the explicit
1.20x per-row check correctly rejects both matrices.
