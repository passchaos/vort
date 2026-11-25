# Deflate copy-before-prefetch screen, 2026-11-25

This experiment starts at main `eb9a65a9b203c0bfc6b06905fc5055afec130e31`.
The [current-main profile](../../decode-hotspots-main-20261125/README.md)
places the main `mr` 64 KiB/L9 cost inside the semantic linear decoder. The
[completed-match descriptor trial](../completed-match-codegen-20261112.md)
failed to remove live scalar parameters across next-entry preload/refill.
This candidate changes execution order instead of table representation.

## Candidate and constraints

Only the ordinary match path in `decodeDynamicBlockIntoLinearMode` changes:
consume the same match bits, validate and copy the match, increment the output
cursor, then perform the unchanged next-entry lookup/refill branch. Lookup
still precedes refill when enough bits are already staged, and follows refill
otherwise. It runs even when the copied match makes the next fast-loop guard
fail. Mid-token refill, match validation, pause-before-consumption, literal
chains, RLE1, RLE258, tail handling and output copies retain their source.

For admitted non-overlapping input/output, the moved code has no public
effect on successful execution: the same local reservoir is committed. Copy
errors discard local state before reader publication in both versions.
The production patch is seven removed and seven added lines; no workspace,
lookup entry, allocator or CPU dispatch change is involved.

## Static observations

| Complete aligned symbol | Baseline | Candidate |
| --- | ---: | ---: |
| Symbol bytes | 3,659 | 3,643 |
| Prologue stack reservation | 296 B | 296 B |
| Instruction lines, including padding | 897 | 900 |
| Negative-RBP operand references | 131 | 126 |
| `shrx` / `shlx` / `bzhi` / `call` counts | 11 / 16 / 4 / 8 | 11 / 16 / 4 / 8 |

Those complete-symbol counts include errors, tails and padding. They do not
prove fewer dynamic spills or faster decoding. The two original bounded
`objdump` outputs, source hashes, comparator hashes and exact build command
are archived. The baseline executable is the frozen `83bb442c` comparator;
its Deflate decoder source matches this round's main revision. Later main
commits did not change production codecs.

## Functional validation

The original source was copied byte-for-byte from the base Git revision into
an independent module. The standalone test root builds both decoders against
identical canonical trees and compares six modes: ordinary, single-distance,
non-overlap, window, single-distance window and non-overlap window.

Debug, ReleaseSafe and ReleaseFast each pass the same **25,092 cases** and
**25,113 paired calls** (including continuations), with **6,996 pauses** and
**11,183 error returns**. Every pair agrees on result/error, complete reader
state including consumed bits, and every byte of output backing and guards.
Cases cover the 48-bit token at the last wide refill, physical truncation and
padding, invalid-history/error priority, packed literals, exact-full output
followed by EOB, and pause/resume. Each Zig run reports **two tests**, one
aggregate differential and the imported `bitstream.test_0`. The 10,707
recorded fast-loop admissions are initial-state guard projections, not
instrumented execution counts.

The existing complete native ReleaseSafe Deflate suite passes **831/831**.
The native wide-counter/checkpoint suite passes **63/63**, and the actual
WASI runner passes **63/63**. Builds and the Debug/Safe differential runs
finished before timing; the ReleaseFast differential ran after timing.

## Timing and disposition

The target is `mr` 64 KiB/L9, with a 20% cliff-repair target, at least 3%
geomean gain over the twelve selected rows, and no control below 0.98x.
The fixed rows include `mr` 64 KiB/L6, 1 MiB/L9 and full/L9; NCI, XML and
Reymont weak/control conditions; and X-ray 64 KiB/L9. Each row retains six
outer baseline/candidate process pairs (three in each order), with shuffled
row order per sweep. Each child retains two measured and two warmup paired
Vort/libdeflate batches, using 100/20/1 decodes at 64 KiB/1 MiB/full. The
reported candidate/baseline throughput is the geometric mean of baseline
Vort / candidate Vort batch medians; reference durations do not normalize it.
Fixed-row intervals use 4,000 outer-pair bootstrap resamples stratified by
process order, not variation across machines.

Intel i7-10700K, logical CPU 15, one codec thread, Linux 6.8.0-79, Zig 0.16.0
ReleaseFast, `x86_64-linux-gnu`, `skylake+pku+sgx`, intel_pstate powersave with
turbo enabled. Reference libdeflate 1.26 is the existing frozen GCC 11.4.0
`-O3 -DNDEBUG -march=skylake` binary. Each child validates full output, exact
compressed consumption, guard bytes and unmodified input. This is a
development-host screen, not dedicated-host acceptance or an encoding test.

**Rejected.** The target improves **1.03382x** (95% CI 1.00697–1.06747x),
below the 20% repair bar. The twelve-row geomean is **0.97856x** (95% CI
0.97380–0.98319x), a regression; six controls are below 0.98x.

| Selected row | Candidate / baseline throughput |
| --- | ---: |
| `mr` 64 KiB L9, target | 1.03382x |
| `mr` 64 KiB L6 | 1.01785x |
| `mr` 1 MiB L9 | 0.97520x |
| NCI 64 KiB L6 | 0.93971x |
| NCI 64 KiB L9 | 0.96219x |
| XML 64 KiB L6 | 0.95136x |
| XML 64 KiB L9 | 0.95252x |
| NCI 1 MiB L9 | 0.94213x |

All **144** timed children validate full output, exact consumption, guards
and input immutability. `summary.json` retains all twelve rows and their
intervals. No samples were removed, and no full-matrix adoption run followed.
Smaller code and fewer static stack references did not produce a whole-call
win. The experiment changes live ranges, scheduling and code layout; it does
not isolate an independent spill cost or prove why a particular row loses.
No production codec source is adopted.

Retain the original pre-copy prefetch ordering. Rather than another match
carrier or instruction reordering, the next performance evidence should
refresh the complete encoding speed/size tradeoff with current code and
matched modern references, where existing historical high-quality gaps are
larger. This decode diagnostic does not close the broad performance goal.

## Reproduction

Offline validation from the repository root:

```sh
epoch="$PWD/docs/performance/deflate/copy-handoff-20261125"
(cd "$epoch" && sha256sum -c SHA256SUMS)
export PYTHONPATH="$PWD/tools/decode" PYTHONDONTWRITEBYTECODE=1
scratch=$(mktemp -d)
tar -xzf "$epoch/timed-rows.tar.gz" -C "$scratch"
python3 "$epoch/screen.py" verify "$scratch/screen-raw"
python3 "$epoch/verify.py" "$epoch" "$scratch/screen-raw"
```

For fresh timing, restore the frozen files and reference binaries from the
[matched refresh](../../modern-decode-refresh-20261125/README.md#artifacts-and-reproduction).
Use a clean worktree at the base revision, apply `candidate.patch.gz`, and
build with the command in `source.json`. The configured sibling
`vail/archive_crypto` dependency was at `43fb07b4`. Once all builds and
correctness runs have completed, run from the baseline checkout:

```sh
taskset -c 0,15 python3 "$epoch/screen.py" run --output "$scratch/screen-raw" \
  --frozen-manifest "$frozen_manifest" --baseline "$baseline_probe" \
  --candidate "$candidate_probe" --patch "$candidate_patch"
```

Probe paths and nanoseconds in a new campaign may differ; output contracts,
fixture hashes, selected rows and the balanced sampling design must agree.
