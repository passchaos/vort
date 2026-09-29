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

## Specialized 10-bit reservoir peek

The external literal tables always use a 10-bit root lookup, but the fast bit
reader previously handled that operation through its dynamic-width padded-peek
entry point. A dedicated 10-bit entry point lets the compiler fold the width
tests and variable mask while retaining the same refill implementation,
staged-bit validation, long-code fallback, and cursor accounting. A focused
oracle compares the specialized and generic readers across every starting bit
offset, short tails, and varying cursor advances.

Against commit `524e0716`, fixed-CPU-5 quality-5 runs measured:

| Input | Wins | Median | Geometric mean | Candidate MiB/s | Candidate/libbrotli |
| --- | ---: | ---: | ---: | ---: | ---: |
| private-pdf-a | 7/7 | 1.0593x | 1.0595x | 272.57 | 0.7308x |
| private-pdf-b | 7/7 | 1.0486x | 1.0485x | 236.79 | 0.6939x |
| private-log | 5/15 | 0.9984x | 0.9987x | 1479.33 | 0.7243x |
| private-json | 13/15 | 1.0043x | 1.0048x | 1720.64 | 0.7255x |

At quality 1 the two PDFs and log improve by 1.0658x, 1.0687x, and 1.0052x;
the JSON control measures 0.9966x. At quality 9 the PDFs and JSON improve by
1.0603x, 1.0475x, and 1.0027x; a 15-pair log confirmation measures 0.9940x
median / 0.9958x geometric mean. These sub-percent negative controls are kept
explicit rather than presented as gains. A wider 7-byte refill was rejected
after losing about 1.8% on both PDF targets relative to this implementation.

## Derived fast-reader cursor

The fast payload reader no longer stores and updates a separate absolute
`consumed_bits` counter for every decoded symbol. Its exact cursor is derived
when needed as the clipped end of staged input minus the number of unread
staged bits. This identity also covers a non-byte-aligned start and a final
partial byte. Existing mixed-read, truncated-tail, synchronization, and
specialized-peek oracles compare the derived cursor against the scalar reader.

Against commit `890a53e5`, fixed-CPU-5 quality-5 runs measured:

| Input | Wins | Median | Geometric mean | Candidate MiB/s | Candidate/libbrotli |
| --- | ---: | ---: | ---: | ---: | ---: |
| private-pdf-a | 7/7 | 1.0149x | 1.0147x | 277.09 | 0.7376x |
| private-pdf-b | 7/7 | 1.0103x | 1.0104x | 240.56 | 0.6966x |
| private-log | 15/15 | 1.0291x | 1.0292x | 1523.51 | 0.7432x |
| private-json | 15/15 | 1.0206x | 1.0197x | 1775.89 | 0.7476x |

Quality-1 medians are 1.0088x/1.0095x/1.0023x/1.0158x across the two PDFs,
log, and JSON; the log confirmation wins 14/15 pairs with a 1.0026x geometric
mean. Quality-9 improves all four rows by
1.0117x/1.0097x/1.0354x/1.0200x. This is a broad hot-path gain, although the
absolute results remain below libbrotli.

## Tail-lookup output cursor

The high-literal-tree tail-lookup executor now keeps its output cursor in a
local value for the duration of the meta-block and writes it back on exit.
Literal history, distance validation, dictionary copies, exact output bounds,
and match-copy behavior are unchanged. This removes repeated pointer-backed
loads and stores from the per-literal loop while preserving partial progress
on every error return through the deferred write-back.

Against commit `546a5721`, independently built ReleaseFast binaries were
alternated on CPU 5. The table reports candidate/baseline medians; PDF labels
are anonymous and the private file mapping remains outside version control.

| Quality | PDF-A | PDF-B | Log | JSON |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 0.9992x | 1.0001x | 1.0015x | 1.0000x |
| 5 | 1.0003x | 0.9993x | 1.0160x | 1.0013x |
| 9 | 1.0024x | 1.0000x | 1.0093x | 1.0068x |

The quality-5 target log wins 7/7 pairs with a 1.0168x geometric mean; both
quality-9 non-PDF inputs win 5/5. All PDF and quality-1 controls remain within
0.1% of baseline except the positive quality-9 PDF-A median. This is a bounded
hot-path improvement and does not establish overall Brotli decode leadership.

## Prepared tail-tree indexing

The tail-lookup executor now indexes the prepared inline literal tree directly.
The context-map parser already rejects indexes outside the declared tree count,
and `prepareLiteralTailLookups` admits this executor only when the complete
declared set fits the 64-tree inline tier. Removing the repeated general-purpose
tree resolver and its two bounds branches leaves malformed-map rejection at the
parser boundary and does not affect non-tail or wide-tree paths.

Against commit `1f63d49b`, independent ReleaseFast binaries were alternated on
CPU 5. Values are candidate/baseline medians over five pairs unless noted.

| Quality | PDF-A | PDF-B | Log | JSON |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 1.0003x | 1.0005x | 0.9999x | 1.0006x |
| 5 | 1.0016x | 1.0001x | 1.0054x | 1.0032x |
| 9 | 1.0007x | 0.9990x | 1.0011x | 0.9996x |

The quality-5 log/JSON confirmations use eleven pairs, win 11/11 and 8/11,
and have 1.0052x/1.0027x geometric means. The quality-9 JSON control also uses
eleven pairs; its 0.9992x geometric mean and 0.9996x median remain within one
tenth of one percent of baseline. The remaining rows are neutral to positive
at this scale.

## Inlined auxiliary command lookup

The auxiliary-tail path now forces its compact command-symbol decoder into the
payload executors. This removes the error-union call boundary and lets the
compiler retain the fast reader and command block state across the immediately
following insert/copy-length decode. The generic command decoder and all paths
without prepared auxiliary tables are unchanged.

Against commit `775368c6`, independent ReleaseFast binaries were alternated on
CPU 5. Values are candidate/baseline medians over five pairs, with seven pairs
for the quality-5 log and JSON confirmation.

| Quality | PDF-A | PDF-B | Log | JSON |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 1.0059x | 1.0037x | 1.0496x | 1.0524x |
| 5 | 0.9980x | 1.0036x | 1.0160x | 1.0297x |
| 9 | 0.9987x | 1.0020x | 1.0204x | 1.0280x |

Both quality-5 non-PDF inputs win 7/7 pairs; all four quality-1 rows and the
quality-9 log/JSON rows win 5/5. The first PDF gives up 0.20% at quality 5 and
0.13% at quality 9, while the other PDF improves at those qualities. These
small control costs are retained explicitly because the multi-percent log and
JSON gains materially improve the overall tradeoff without establishing
libbrotli parity.

## Inlined auxiliary distance lookup

The prepared auxiliary distance decoder now follows upstream Brotli's hot-path
shape and is forced inline beside command execution. This removes its error
return call boundary while retaining the output-parameter result, which proved
faster than a packed scalar return in separate screening. Distance block
switches, tree bounds, short-distance validation, extra-bit reads, and ring
updates are unchanged.

Against commit `b14cb65f`, independent ReleaseFast binaries were alternated on
CPU 5. Values are candidate/baseline medians; the two confirmed negative rows
use eleven higher-iteration pairs.

| Quality | PDF-A | PDF-B | Log | JSON |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 1.0009x | 1.0019x | 0.9978x | 0.9940x |
| 5 | 1.0028x | 0.9967x | 1.0218x | 1.0237x |
| 9 | 1.0035x | 0.9980x | 1.0144x | 1.0244x |

Quality-5 log/JSON win 7/7 pairs. Quality-9 JSON wins 5/5; its smallest pair
is 1.0194x. The q1 JSON and q5 PDF-B controls give up 0.60% and 0.33%,
respectively, and are retained explicitly as the cost of the broader
multi-percent improvement.

## Prepared distance parameters

The standard-window decoder now follows the upstream Brotli
`CalculateDistanceLut` design: each compressed meta-block prepares the extra-bit
width and zero-extra offset for its distance alphabet once. Direct and regular
distance codes then share a compact lookup in the command loop instead of
rebuilding the RFC distance formula for every copy. Large Window decoding keeps
its separately bounded 32-bit path.

An exhaustive oracle compares the prepared result with the reference formula
for all 64 legal `NPOSTFIX` / encoded-`NDIRECT` combinations and every active
distance symbol. Existing tail-path tests cover implicit, short, regular,
invalid, underflowing, and maximum-distance cases.

Against commit `ef4d4a86`, independently built ReleaseFast binaries were
alternated on CPU 5. Values are candidate/baseline medians; the q1 PDF-B row
uses 15 higher-iteration pairs, while the other rows use five or seven pairs.

| Quality | PDF-A | PDF-B | Log | JSON |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 1.0003x | 0.9997x | 1.0134x | 1.0154x |
| 5 | 1.0014x | 1.0037x | 1.0059x | 1.0116x |
| 9 | 1.0005x | 1.0037x | 1.0046x | 1.0132x |

The extended q1 PDF-B control has a 1.0006x geometric mean and spans
0.9977x--1.0068x, so its 0.9997x median is treated as neutral. Two closer C
translations were rejected: group-at-a-time table construction regressed the
q9 PDF-A control to 0.9937x, while retaining the old direct-distance branch
regressed q9 JSON to 0.9946x. This keeps the upstream invariant but selects the
layout that is consistently better under Zig's generated code. It is another
incremental improvement, not a claim of overall libbrotli leadership.

## Tail-lookup long-code continuation

The in-table 9-bit Huffman decoder now preserves the already-read prefix when a
slot misses. If at least nine bits are available and the tree contains longer
codes, an out-of-line fallback consumes that prefix once and continues one bit
at a time from width 10. Short inputs and trees whose maximum width fits the
lookup retain the original compact decoder, preserving exact truncation and
invalid-code progress.

This avoids both rejected extremes: restarting at bit 1 repeats nine reads,
while peeking the complete prefix again at every larger width adds expensive
variable-width reservoir work. Fast/scalar equivalence covers a complete
384-symbol tree with 10-bit codes, and a dedicated truncated-long-code oracle
checks the error and final bit position.

Against commit `d4246691`, independent ReleaseFast binaries were alternated on
CPU 5. Values are candidate/baseline medians.

| Quality | PDF-A | PDF-B | Log | JSON |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 1.0019x | 1.0041x | 0.9984x | 0.9999x |
| 5 | 1.0163x | 1.0280x | 1.0519x | 1.0213x |
| 9 | 1.0289x | 1.0320x | 1.0563x | 1.0149x |

Every q5/q9 row wins all five or seven pairs. The q1 Log/JSON controls remain
within 0.2% of baseline. Same-process q5 Log/JSON throughput reaches
1,696.61/1,954.45 MiB/s, or 0.8245x/0.7994x libbrotli 1.1.0; q9 reaches
1,771.61/2,148.04 MiB/s, or 0.8302x/0.8190x. The improvement substantially
reduces the long-code penalty but does not establish overall leadership.

## Pairwise long-code bucket scan

The out-of-line tail-lookup fallback now checks two adjacent canonical entries
per loop iteration. Entries remain grouped by code width and are read in their
existing sequential order, preserving cache locality while halving the loop
control on command-heavy long-code buckets. An odd final entry is handled by a
single bounded tail check; reader and error semantics are unchanged.

Against commit `edd58f51`, independent ReleaseFast binaries were alternated on
CPU 5. Values are candidate/baseline medians.

| Quality | PDF-A | PDF-B | Log | JSON |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 1.0014x | 0.9999x | 1.0005x | 1.0008x |
| 5 | 1.0042x | 1.0021x | 1.0083x | 1.0112x |
| 9 | 1.0066x | 1.0012x | 1.0133x | 1.0090x |

All q5/q9 rows win at least five of seven or all five measured pairs; q1 stays
within 0.1%. Same-process q9 throughput reaches 1,802.29 MiB/s on Log and
2,139.19 MiB/s on JSON, or 0.8424x/0.8374x libbrotli 1.1.0. This retains the
successful one-prefix continuation while avoiding the poor locality and branch
dependence measured for binary-search and secondary-table alternatives.

## Fixed-width auxiliary tail peeks

A q9 Log hardware profile after the two-entry long-code scan placed 39.13% of
cycles in the tail-lookup payload executor. The generic bit reader used by its
9-bit command and distance tables accounted for another 6.39% in
`peekBitsPadded`, including checks and mask construction that are constant for
these prepared tables. The fast reader now exposes a fixed 9-bit peek, and the
Huffman decoder selects it only for prepared auxiliary lookups.

The specialization follows the existing fixed 10-bit literal lookup design but
is deliberately tiered. Tail and small external executors use it, as does the
full >128-tree external executor; the 65--128-tree middle executor retains the
generic lookup. The wide external function is aligned to 64 bytes so emitting
the additional specialization cannot displace the unchanged middle tier onto
an unfavorable instruction-cache boundary.

Against commit `f9815650`, independent ReleaseFast binaries were alternated on
CPU 5. Values are candidate/baseline medians; Log/JSON use seven pairs, PDF-A
uses five except for the 25-pair q5 confirmation, and PDF-B uses five except
for the 23-pair q5/q9 confirmations.

| Quality | PDF-A | PDF-B | Log | JSON |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 0.9999x | 0.9994x | 1.0280x | 1.0394x |
| 5 | 0.9980x | 0.9984x | 1.0249x | 1.0242x |
| 9 | 1.0010x | 0.9986x | 1.0229x | 1.0202x |

The extended PDF controls remain within 0.2% of baseline, while every Log/JSON
row wins all measured pairs. Same-process candidate
throughput reaches 1,758.09/1,984.57 MiB/s on q5 Log/JSON and
1,831.89/2,184.38 MiB/s on q9, respectively 0.8620x/0.8491x libbrotli 1.1.0
for the latter pair. The reader/Huffman oracles, upstream 7,056 one-shot plus
7,056 progressive matrix, four-category real corpus, full test/check graph,
and 13-row reference gate pass. Brotli decode leadership remains open.

## Staged-first payload bit reads

After the fixed 9-bit auxiliary lookup, a fresh q9 Log profile still attributed
7.40% of cycles to the general fast-reader `readBits` function. Command and
distance extra fields immediately follow a Huffman lookup, so their bits are
usually already resident in the reader's reservoir. A new at-most-24-bit
primitive handles that staged case inline and calls the existing reader only
when refill or truncation handling is required. It is restricted to the same
executor tiers selected for fixed 9-bit auxiliary lookup, avoiding the code
growth of the previously rejected fully inlined 24-bit reader.

Against commit `6ec3a13e`, independent ReleaseFast binaries were alternated on
CPU 5 for seven Log/JSON pairs and five PDF pairs at every quality:

| Quality | PDF-A | PDF-B | Log | JSON |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 1.0062x | 1.0075x | 1.0286x | 1.0409x |
| 5 | 1.0030x | 1.0056x | 1.0201x | 1.0295x |
| 9 | 1.0068x | 1.0046x | 1.0199x | 1.0250x |

All twelve rows are positive and every pair wins. Same-process candidate
throughput reaches 1,797.10/2,072.03 MiB/s on q5 Log/JSON and
1,879.24/2,260.71 MiB/s on q9, respectively 0.8783x/0.8674x libbrotli 1.1.0
for the latter pair. Mixed-width, refill, truncation, cursor, insert/copy, and
distance oracles pass, together with the upstream 7,056 one-shot plus 7,056
progressive matrix, four-category real corpus, full test/check graph, and
13-row reference gate. The remaining Brotli decode gap is smaller but still
measurable.

## Packed short-distance deltas

The short-distance resolver now follows the compact indexing invariant used by
upstream Brotli's ring-buffer path. Symbols 0 through 3 index the four-entry
history directly; symbols 4 through 15 select one of two history entries and
extract a signed delta from a packed immediate. Vort retains its explicit
invalid-symbol, negative-distance, and positive-overflow errors rather than
adopting upstream's caller assumptions. In the measured ReleaseFast binary,
the resolver shrank from `0x199` to `0x80` bytes and no longer contains an
indirect jump table.

Against commit `e7a87933`, independent ReleaseFast binaries were alternated on
CPU 5. Values are candidate/baseline ratios; Log/JSON use seven pairs except
the 17-pair q1 Log confirmation, while PDF rows use five pairs except the
15-pair q5 PDF-B confirmation.

| Quality | Input | Wins | Median | Geometric mean |
| ---: | --- | ---: | ---: | ---: |
| 1 | PDF-A | 3/5 | 1.0018x | 1.0006x |
| 1 | PDF-B | 3/5 | 1.0008x | 1.0004x |
| 1 | Log | 4/17 | 0.9972x | 0.9979x |
| 1 | JSON | 4/7 | 1.0007x | 1.0009x |
| 5 | PDF-A | 4/5 | 1.0020x | 1.0021x |
| 5 | PDF-B | 8/15 | 1.0003x | 1.0000x |
| 5 | Log | 7/7 | 1.0117x | 1.0105x |
| 5 | JSON | 6/7 | 1.0175x | 1.0161x |
| 9 | PDF-A | 3/5 | 1.0019x | 1.0008x |
| 9 | PDF-B | 4/5 | 1.0008x | 1.0002x |
| 9 | Log | 6/7 | 1.0078x | 1.0058x |
| 9 | JSON | 6/7 | 1.0092x | 1.0085x |

The q1 Log control gives up 0.28% at the median, while every q5/q9 Log and
JSON row improves and the PDF controls are neutral to slightly positive. The
RFC short-distance oracle, implicit/explicit tail-distance oracle, full
test/check graph, upstream 7,056 one-shot plus 7,056 progressive matrix,
four-category real corpus, and 13-row reference gate pass. This is an
incremental upstream-informed improvement; Vort still does not claim overall
Brotli decode leadership.

## Compact literal-root plane

The standard-window tail executor previously selected a context tree and then
indexed its full `PrefixCode(256)` object for every literal. A q9 Log profile
attributed 5.69% of the executor's samples to the corresponding address-scale
operation and another 5.26% to its single-symbol branch. A direct 64-entry
tree-pointer cache removed the multiply but regressed the same workload, so it
was rejected.

The retained design follows the decoding invariant in libbrotli 1.2.0 rather
than copying its representation. Upstream `DecodeSymbol` uses an 8-bit root
table, forwards long roots to a second-level table, and keeps the short-input
decoder out of line. Vort now builds a contiguous 256-entry `u16` root lookup
for each eligible literal tree, encodes single-symbol trees as zero-bit entries,
and reuses its authoritative pairwise canonical continuation only after an
8-bit miss. Unlike upstream's four-byte entries and per-tree secondary tables,
the Vort root plane occupies 512 bytes per tree and at most 32 KiB for the
64-tree inline tier.

Preparation first proves that every tree is eligible and only then writes the
plane, so failure is atomic. A separate noinline wrapper owns the fixed-size
plane; meta-blocks outside the 16--64-tree tier never acquire its stack frame.
The `>64` route also bypasses the wrapper before allocation. This isolation was
required in practice: placing the plane in the common caller regressed q1
streams even when they never used the new lookup. In the final ReleaseFast
binary, the large-meta-block dispatcher shrinks from `0x9a1` to `0x5fa` bytes,
the two tail specializations shrink from `0x77c`/`0xda0` to
`0x6d3`/`0xc82`, and the hot per-literal `imul $0x658` remains only in the
cold long-code fallback.

Against commit `3234bcc7`, independent ReleaseFast binaries were alternated on
CPU 5 using the same anonymous inputs. Values are candidate/baseline ratios;
rows use five pairs except the marked eleven-pair controls.

| Quality | Input | Pairs | Median | Geometric mean |
| ---: | --- | ---: | ---: | ---: |
| 1 | PDF-A | 5 | 0.999552x | 0.999379x |
| 1 | PDF-B | 5 | 1.000571x | 1.000187x |
| 1 | Log | 5 | 1.004980x | 1.004251x |
| 1 | JSON | 5 | 1.003456x | 1.003911x |
| 5 | PDF-A | 5 | 0.998816x | 0.998575x |
| 5 | PDF-B | 5 | 0.999118x | 0.998721x |
| 5 | Log | 5 | 1.009446x | 1.008893x |
| 5 | JSON | 5 | 1.007154x | 1.007738x |
| 9 | PDF-A | 11 | 1.000287x | 1.000252x |
| 9 | PDF-B | 5 | 0.999731x | 1.000218x |
| 9 | Log | 5 | 1.007616x | 1.005408x |
| 9 | JSON | 11 | 1.000056x | 1.002538x |

The final q9 candidate reaches 1905.82 MiB/s on Log and 2258.91 MiB/s on
JSON, respectively 0.8937x and 0.8810x the benchmark's libbrotli 1.1.0.
Focused dense/single/long-code and atomic-preparation tests pass, as do the
7,056-case upstream one-shot and progressive matrices, 1,401 progress-matrix
runs, four-category real-corpus one-shot/progressive differential, full
test/check graph, and 13-row reference gate. The compact plane improves the
dominant multi-tree workloads without hiding the remaining libbrotli gap.

## Tail-only packed command metadata

The same libbrotli 1.2.0 source audit found that upstream's command LUT uses an
eight-byte `CmdLutElement`: four byte-sized control fields followed by two
16-bit length bases. Vort's general-purpose Zig entry occupies 12 bytes. The
compact-tail specialization now reads a separate eight-byte packed `u64`
entry, placing both bases and the bit-count flags in one load before extracting
them in registers. All other decoder tiers keep the established table and code
shape; this avoids the q9 JSON regression measured when the smaller entry was
made global.

The compact table is generated at compile time from the authoritative 704-entry
table. A compile-time size assertion fixes its eight-byte representation, an
exhaustive oracle compares every field of all 704 entries, and the staged
high-extra-bit test compares decoded lengths and reader position with the
general table.

Against commit `deb72111`, independent ReleaseFast binaries were alternated on
CPU 5. Values are candidate/baseline ratios; rows use five pairs except the
seven-pair q9 JSON control.

| Quality | Input | Wins | Median | Geometric mean |
| ---: | --- | ---: | ---: | ---: |
| 1 | PDF-A | 2/5 | 0.999672x | 0.998806x |
| 1 | PDF-B | 5/5 | 1.000648x | 1.000830x |
| 1 | Log | 1/5 | 0.998352x | 0.998520x |
| 1 | JSON | 3/5 | 1.000264x | 0.999935x |
| 5 | PDF-A | 3/5 | 1.000097x | 1.000465x |
| 5 | PDF-B | 2/5 | 0.999950x | 0.999956x |
| 5 | Log | 5/5 | 1.005540x | 1.006269x |
| 5 | JSON | 3/5 | 1.000742x | 1.002316x |
| 9 | PDF-A | 3/5 | 1.001626x | 1.000182x |
| 9 | PDF-B | 2/5 | 0.999799x | 0.998733x |
| 9 | Log | 5/5 | 1.005846x | 1.005242x |
| 9 | JSON | 3/7 | 0.998791x | 0.999264x |

The unweighted geometric mean of the twelve row-level geometric means is
1.000874x. The largest retained control cost is 0.15% on q1 Log, while the two
directly affected Log rows improve by 0.63% at q5 and 0.52% at q9. A q9 Log
counter run reduces core cycles by about 0.75%; the packed extraction raises
retired instructions by about 0.79%, so the win comes from a shorter dependency
and denser lookup rather than lower instruction count.

Final higher-iteration q9 measurements reach 1903.04 MiB/s on Log and
2250.20 MiB/s on JSON, or 0.8946x and 0.8819x libbrotli 1.1.0. The upstream,
real-corpus, full test/check, and 13-row reference gates remain green. This is
another measured step toward parity, not an industry-best claim.

## Wide literal-block run batching

The packed 65--256-tree executor now resolves a literal block switch only at a
block boundary and decodes the complete block-local portion of an insert run
with one cached context mode and one cached context-map base. Previously those
values were reloaded and the switch condition was evaluated for every literal.
The compact and single-tree executors are unchanged.

Against committed baseline `db1eb637`, 15 alternating ReleaseFast pairs on
fixed libbrotli 1.2.0 streams produced:

| workload | median speedup | geometric mean | wins |
| --- | ---: | ---: | ---: |
| repository documentation q5 | 1.0148x | 1.0199x | 14/15 |
| repository documentation q9 | 1.0234x | 1.0211x | 14/15 |
| repository source q5 | 1.0173x | 1.0138x | 12/15 |
| repository source q9 | 1.0144x | 1.0132x | 12/15 |

Fifteen absolute candidate/reference runs reach 0.6573x, 0.6378x, 0.6426x,
and 0.6461x respectively. The committed `clustered_q8` route remains neutral
at 1.0000x median over 15 control pairs. The reference gate, upstream
differential, and real-corpus driver smoke pass; wide literal-rich decode still
has a substantial parity gap.

A closer libbrotli-style 8-bit root plus bounded secondary-table experiment
was also implemented and removed. Unlike the earlier 8-bit-root-only trial, it
decoded every long code through a second-level table and retained the existing
10-bit implementation as an atomic capacity fallback. Even so, 15 alternating
pairs regressed documentation q5/q9 to 0.9831x/0.9807x median and source q5/q9
to 0.9779x/0.9819x, with only 0--2 wins per row. The smaller table working set
did not repay the 15-bit peek, root-marker branch, and second-level index on
Apple M1 Pro, so the complete trial was removed.
