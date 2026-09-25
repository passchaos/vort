# Brotli external literal lookup

This note records the 2026-09-25 optimization of large standard Brotli streams
whose literal trees are too dense to store an in-table lookup. The measurements
use Zig 0.16.0 ReleaseFast on an Intel Core i9-13900K and libbrotli 1.1.0 as
the reference. Measurements through the 64-tree change pinned one codec thread
to CPU 8; the packed-tree-tier follow-up pinned it to CPU 5.

## Motivation and implementation

The existing fast path stores an 8-bit lookup in the unused tail of each
canonical Huffman table. That works well for sparse, highly clustered streams,
but a dense 256-symbol tree has no spare entries. Such a tree fell back to a
bit-at-a-time canonical scan for every literal. A `perf` profile of an
anonymized private PDF input, compressed by libbrotli at quality 5, attributed
71.64% of samples to that scalar 256-symbol decoder. Vort reached
only 17.71 MiB/s, or 0.0476x libbrotli throughput.

Large meta-blocks with at most 16 literal trees now build separate packed
10-bit lookup tables. Each slot is one `u16` containing the decoded symbol and
code length. Short codes decode in one indexed load; longer codes retain the
canonical fallback and the same truncation checks. The route is limited to
meta-blocks of at least 64 KiB so small streams do not pay the setup or stack
cost. Existing in-table lookup routing remains unchanged for larger sparse tree
sets.

The generic `PackedLookup` has a direct dense-table, long-code-fallback, cursor,
and truncated-input oracle. A Brotli production test also requires the new
large-meta-block route to execute while round-tripping a two-tree entropy-split
stream.

## Private corpus evidence

The baseline and candidate executables were frozen and alternated in each
pair. Every invocation regenerated the Brotli frame through libbrotli and
verified Vort's complete output before entering five best-of timing rounds.

| Input / quality | Pairs won | Median speedup |
| --- | ---: | ---: |
| private-pdf-a, q1 | 5/5 | 9.3776x |
| private-pdf-a, q5 | 7/7 | 7.8520x |
| private-pdf-a, q9 | 5/5 | 8.6144x |
| private-log, q5 | 7/7 | 1.1103x |
| private-json, q5 | 7/7 | 1.0734x |

A longer same-process q5 comparison on private-pdf-a measured Vort at
154.55 MiB/s and libbrotli at 375.41 MiB/s, a 0.4117x ratio. This is a large
improvement over the 17.71 MiB/s / 0.0476x baseline, but it is not yet a claim
of Brotli decode parity or industry leadership.

An 11-bit lookup was rejected after seven alternating comparisons: it lost all
seven by about 0.07% median while doubling lookup storage. A forced-inline bit
reader experiment was also rejected after losing the stable-frequency pairs by
about 0.8%. Expanding the external lookup from 16 to 32 trees was effectively
neutral while doubling its maximum stack footprint, so the smaller bound was
retained.

## Reproduction

```sh
taskset -c 8 zig build -Doptimize=ReleaseFast run-br-reference-bench -- \
  --input "$VORT_PRIVATE_INPUT" \
  --name private_pdf_a_q5 --quality 5 --iterations 8
```

The built-in reference gate and upstream multi-block differential remain the
broader compatibility checks for this path.

## Deferred canonical-tree access follow-up

The first external-lookup implementation still resolved the large canonical
`PrefixCode(256)` object and checked its single-symbol tag before every lookup,
even when the packed root table contained the answer. The lookup now represents
single-symbol trees directly and exposes separate fast-hit and long-code
fallback operations. The payload loop touches the original canonical tree only
after a root-table miss.

Against the first 10-bit implementation, fixed-CPU interleaved measurements on
the same private corpus produced:

| Input / quality | Pairs won | Median speedup |
| --- | ---: | ---: |
| private-pdf-a, q1 | 5/5 | 1.1385x |
| private-pdf-a, q5 | 9/9 | 1.1181x |
| private-pdf-a, q9 | 5/5 | 1.1161x |
| private-log, q5 | 6/7 | 1.0075x |
| private-json, q5 | 7/7 | 1.0212x |

The longer PDF q5 comparison now measures 173.49 MiB/s, or 0.4589x of
libbrotli 1.1.0. The remaining profile is dominated by the context-dependent
literal loop and bit-reservoir refill rather than canonical-tree scans.

## Local output cursor

The external-lookup executor now keeps its output position in a local cursor
for the full meta-block and commits it through `defer`, including error exits.
This removes a caller-pointer load and store from every decoded literal without
changing partial-progress behavior.

Eleven alternating q5 runs on private-pdf-a all improved, with a 1.0329x
median. The private-pdf-b, private-log, and private-json controls remained
neutral to slightly positive by median at 1.0016x,
1.0004x, and 1.0020x. A longer same-process comparison measured 179.10 MiB/s,
or 0.4778x libbrotli 1.1.0. An attempted literal-block-run cache was rejected
because it regressed the trace control.

## Full inline-tree coverage

The original 16-tree cap left most of private-pdf-b on the scalar decoder; its
quality-5 stream reaches 78 context trees overall and decoded at
only 11.59 MiB/s, or 0.0388x libbrotli. Raising the external lookup capacity to
the decoder's complete 64-tree inline tier covers more of those meta-blocks
without changing the packed-tree fallback.

Seven alternating comparisons improve this second PDF by 2.4731x median with
7/7 wins. The resulting same-process measurement is 41.63 MiB/s, or 0.1203x
libbrotli 1.1.0. The first PDF is neutral at 0.9994x median because all its
blocks were already covered. The 63 MiB log has a positive but noisy 1.0163x
median, while the 31 MiB trace is effectively neutral at 0.9983x. An initial
128-tree prototype was rejected because it crossed the 64-entry inline-tree
boundary without reconstructing the packed trees. The retained 64-tree bound
is tied directly to `inline_literal_tree_count` and guarded at compile time;
the safe packed-tree design is described below.

## Packed-tree lookup tiers

The 64-tree limit still left meta-blocks in two private inputs on the scalar
literal decoder: private-pdf-b reaches 78 literal context trees and private-json
reaches 169. Reserving a 256-entry lookup array in the common path made
low-tree streams slower through its larger stack frame and code layout.

The decoder therefore keeps three separately compiled stack tiers. Streams
with at most 64 trees retain the original inline-tree path, streams with 65 to
128 trees use a 128-entry wrapper, and streams with 129 to 256 trees use a
256-entry wrapper. For the latter two tiers, compact packed trees are expanded
once while their external 10-bit lookup is built. Root-table hits then avoid
the expanded tree; a code longer than 10 bits uses the existing cached
canonical decoder. This fallback is important for correctness and is covered,
together with packed dense and packed single-symbol trees, by a direct unit
test.

The final comparison rebuilt the baseline from commit `c55d7bad` in a clean
temporary checkout. Seven baseline/candidate pairs were alternated on CPU 5;
each invocation regenerated a quality-5 frame from the corresponding private input,
verified both Vort and libbrotli output, and measured three decodes in each of
five best-of timing rounds.

| Input / quality | Peak literal trees | Pairs won | Median speedup | Candidate MiB/s | Candidate / libbrotli |
| --- | ---: | ---: | ---: | ---: | ---: |
| private-pdf-a, q5 | 16 | 0/7 | 0.9913x | 177.46 | 0.4740x |
| private-pdf-b, q5 | 78 | 7/7 | 4.1923x | 177.04 | 0.5132x |
| private-log, q5 | 26 | 2/7 | 0.9984x | 1468.96 | 0.7117x |
| private-json, q5 | 169 | 7/7 | 1.8296x | 1717.46 | 0.7078x |

The two newly covered high-tree streams improve decisively. The 26-tree log is
effectively neutral, while the 16-tree PDF has a repeatable 0.9% code-layout
regression despite retaining the same 64-entry stack tier. An explicit
64-byte alignment experiment failed to recover that loss and regressed the
log and trace by about 1.9% and 1.0%, so it was rejected. The remaining
libbrotli gap also means these results are an incremental decoder improvement,
not an industry-leadership claim.

## Distance-result writeback

A CPU-sampling profile of the committed tiered decoder placed 19.35% of the
trace workload in `readMinimalDistanceTailLookup`. That helper returned an
error union containing a two-field distance result, then called another
error-union helper even for the implicit last-distance symbol used directly by
many Brotli commands.

The tail-lookup helper now writes its distance and ring-update flag into
caller-owned storage and returns only an error. The implicit symbol-zero case
copies the newest ring entry directly, while explicit short and regular
distances keep the existing validation and bit consumption. The decoder,
external-lookup, wide-lookup, and summary loops all use the same helper. A
focused oracle covers implicit symbol zero, an explicit short distance, and a
regular distance with extra bits.

Against commit `8f95429b`, seven alternating q5 pairs on CPU 5 produced:

| Input / quality | Pairs won | Median speedup | Candidate MiB/s | Candidate / libbrotli |
| --- | ---: | ---: | ---: | ---: |
| private-pdf-a, q5 | 7/7 | 1.0058x | 178.70 | 0.4730x |
| private-pdf-b, q5 | 6/7 | 1.0057x | 176.71 | 0.5124x |
| private-log, q5 | 7/7 | 1.0107x | 1487.12 | 0.7203x |
| private-json, q5 | 7/7 | 1.0149x | 1743.78 | 0.7209x |

Two more aggressive variants were rejected early. An 8-bit lookup for only
the wide tiers reduced table footprint but dropped private-pdf-b to 145.81
MiB/s because of extra canonical fallbacks. Copying the four-entry distance
ring into each payload function regressed all four files by roughly
1.2%--2.6%; force-inlining the implicit-symbol branch likewise regressed the
log and trace by about 1.6% and 1.1%.

## Validated external lookup indexing

The external-literal executors no longer repeat a bounds check for every
decoded literal. `readContextMap` rejects every encoded tree index outside the
declared literal-tree count, including before inverse move-to-front expansion,
and the two lookup builders reject a tree count beyond their complete prepared
capacity. The hot loops therefore use the already-proven index through the
lookup slice pointer. Generic and non-prepared literal paths retain their local
checks.

Against commit `646a48bb`, seven alternating quality-5 pairs pinned to CPU 5
produced:

| Input | Pairs won | Median candidate/baseline | Candidate MiB/s | Candidate/libbrotli |
| --- | ---: | ---: | ---: | ---: |
| private-pdf-a | 7/7 | 1.0291x | 183.67 | 0.4885x |
| private-pdf-b | 7/7 | 1.0293x | 182.57 | 0.5329x |
| private-log | 7/15 | 0.9997x | 1483.90 | 0.7195x |
| private-json | 7/7 | 1.0035x | 1720.45 | 0.7101x |

The longer log run has a `1.0003x` geometric mean and is treated as neutral.
ReleaseSafe context-map and external-lookup tests, the 13-row reference gate,
and the upstream differential all pass; the latter covers 100 base cases,
7,056 one-shot cases, 7,056 progressive cases, 1,401 progress-matrix runs, and
32 one-shot plus 32 progressive cases from the repository corpus and four
private inputs. These results improve the PDF bottleneck but do not establish
overall Brotli decode leadership.

## Context-independent literal maps

The external lookup path now recognizes meta-blocks where every literal block
type maps all 64 contexts to one tree. The check runs once per meta-block. Each
command then either uses a short context-free literal loop or the established
UTF-8/generic context loop; the high-tree wide executor remains unchanged. A
focused invariant test covers multiple uniform block types and a single-entry
rejection.

Against commit `4a9efbc3`, fixed-CPU-5 quality-5 runs measured:

| Input | Pairs | Median candidate/baseline | Candidate MiB/s | Candidate/libbrotli |
| --- | ---: | ---: | ---: | ---: |
| private-pdf-a | 7 | 1.3648x | 248.52 | 0.6646x |
| private-pdf-b | 7 | 1.2110x | 221.36 | 0.6414x |
| private-log | 15 | 0.9975x | 1484.90 | 0.7197x |
| private-json | 15 | 0.9981x | 1729.88 | 0.7134x |

The two non-independent controls remain within 0.3% of baseline. Five-pair
cross-quality checks improve all four quality-1 rows by
1.1152x/1.1168x/1.0264x/1.0104x. At quality 9 the two PDFs improve by
1.3395x/1.1929x, the log is positive at 1.0025x, and the trace remains within
noise at 0.9980x. The specialization materially closes the PDF gap without
claiming overall parity: quality-5 Vort remains at 0.6646x/0.6414x of
libbrotli on the two PDF files.

## Literal-block run batching

Both external-lookup loops now resolve literal block switches once per
contiguous block run instead of once per byte. The context-independent path
also resolves its tree and lookup once per run; the context-dependent path
keeps per-byte context selection but hoists its block type, context mode, map
base, and remaining-count update. A branch-layout hint keeps the established
context-dependent loop as the fall-through path.

Against commit `6843f8c4`, independent ReleaseFast binaries were alternated on
CPU 5. Quality-5 results were:

| Input | Wins | Median | Geometric mean | Candidate MiB/s | Candidate/libbrotli |
| --- | ---: | ---: | ---: | ---: | ---: |
| private-pdf-a | 7/7 | 1.0303x | 1.0307x | 257.57 | 0.6865x |
| private-pdf-b | 7/7 | 1.0263x | 1.0262x | 226.89 | 0.6594x |
| private-log | 7/15 | 0.9998x | 1.0003x | 1482.47 | 0.7190x |
| private-json | 9/15 | 1.0001x | 0.9995x | 1705.92 | 0.7237x |

Five-pair cross-quality checks improve every quality-1 input by
1.0235x--1.0458x. At quality 9 the PDFs improve by 1.0374x/1.0257x, while the
log and JSON controls remain within 0.2% of baseline at 0.9987x/0.9981x by
median. The quality-5 controls are neutral by both median and geometric mean.
The remaining absolute reference gap means broad Brotli leadership is still
open.
