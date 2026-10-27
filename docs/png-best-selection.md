# Best-parser selection and initial optimal storage

The default optimal one-shot encoder now evaluates both eligible fallback
parsers and keeps the smallest complete raw, zlib or gzip result. It no longer
returns immediately when the default parser first beats the optimal result,
which could hide a smaller filtered result. Strict length ties retain the
earlier candidate, and every losing buffer is freed through the caller allocator.

Fallback options retain the caller's block-selection rule and constrain
lookback, match lengths, chain/candidate work, savings and split-planning
settings. Dictionary-aware raw/zlib wrappers pass the same dictionary to every
candidate. A requested 64-byte window therefore cannot silently become the
default preset's 32-KiB window, and stored/fixed-only encoding cannot emit a
dynamic block through its fallback.

The cohesive `src/deflate/best_candidates.zig` module owns option derivation
and buffer arbitration. `best_encoding.zig` owns nonrecursive candidate
production for the three wire formats and dictionary variants. Complete wire
and allocation regressions live beside them under `src/deflate/tests/best_selection.zig`.

## Rejected frequency shortcut

An uncommitted proposal chose filtered parsing directly from dominant-byte
frequencies and skipped other complete candidates based on input size/ratio.
Thirty-two structured inputs disprove that shortcut. A 4096-byte input with
short paired repeats produces 2,568 raw bytes through the shortcut, against
2,356 from the default parser. The corresponding valid 4096x1 grayscale PNG
is 2,631 bytes, versus 2,420 at level 6 and 2,336 through complete best selection.
Both image-png and libpng decode every synthetic PNG back to its original pixels.

That proposal is archived under `/nav_env/Temp/imx-png-selection-20261027/` and
is removed from the active source path. It is not part of the released baseline
used for the current compression/memory/timing comparison.

## Exact initial allocation

New optimal owners know the full input geometry before search. Their cost,
decision and compact-index arrays now reserve exactly that first length, rather
than immediately adding geometric growth slack. Existing owners retain capacity
and use the established growth policy when later inputs need more storage.

`src/lz77/optimal/storage.zig` keeps this reservation rule separate from match
search and dynamic-programming arithmetic. Costs, steps, tokens, candidate
budgets, tie order and prefix-jump ordinals remain unchanged. A repeated-input
test succeeds with an allocator set to fail on its very first allocation,
proving the retained owners still reuse their storage.

On the normalized 3840x2160 RGB Exoplanet input, level 8/9 adaptive encoding
reduces peak requested heap from 807,768,116 to 583,733,830 bytes while retaining
the complete PNG buffer. These are allocator requests, not process RSS or a
whole-library memory claim.

The rarest-anchor scan carries only the winning gap and offset through its
loop, then reads the final predecessor once. This avoids a repeatedly spilled
third field after the initial-capacity change, while preserving the original
predecessor on ties and immediate missing-prefix returns. The original scalar
loop remains a test oracle.

## Verification and remaining work

The ReleaseFast LZ77 root passes 111 tests, including complete scalar-DP state,
candidate-budget, wide-position, custom-cost, reuse and allocation-failure
controls. The selected DEFLATE best/optimal/numeric/dictionary gates pass
112 tests after pulling; focused best-selection gates pass 13 in Debug. The
owning imx bounded PNG encoder passes 87 tests in both modes. Baseline x86_64 and big-endian
PowerPC64 compile optimal controls. System zlib 1.3 independently decodes raw,
zlib, gzip and limited-dictionary results.

```sh
zig test src/lz77.zig -OReleaseFast
zig test src/deflate.zig -OReleaseFast --test-filter best --test-filter optimal --test-filter dictionary --test-filter numeric
zig test src/deflate.zig --test-filter 'best selection'
```

The imx evidence records the original 15-raster matrix, explicit levels,
independent observers and paired complete-encoder timing. Compression
throughput, optimal-state storage beyond initial slack, entropy-model costs and
broader format/API performance remain under the active goal.

Final imx complete-encoder timing covers sixty original-raster level-8/9 cases.
The current/released throughput ratio is 0.969219x geomean and
0.983153x aggregate, minimum 0.725477x. Lohengrin/Up
spends additional CPU comparing the filtered candidate while reducing size by
about 4.22%. Current aggregate throughput remains 0.124370x
image-png. Initial requested-heap savings and candidate-quality correctness
do not establish numeric-level throughput leadership.
