# Brotli dense Huffman construction

Date: 2026-10-25. Baseline: `f642d0d8`. The industry-best functionality and
performance objective remains incomplete.

Actual q8 context diagnostics identify 796/830 dense (>128-symbol)
package-merge calls for Mozilla's lazy/optimal plans, with code-length stage
medians 20.440/22.244ms. Source has no dense calls. The ordinary tree-cache
helper is already inlined, so this increment optimizes dense code-length
construction rather than attributing cost to a missing helper inline.

## Exact construction and safe fallback

`PrefixAlphabetFor` already orders live symbols by descending frequency and
stable symbol ties. The new 129...256 path gathers frequencies in those same
compact ranks and builds a natural Huffman tree with two ordered queues.
Equal-weight leaves precede parents, and parents retain creation order. On a
successful tree every rank's length is scattered through the original symbol
mapping. It retains the same 15-bit cap and original fallback; no candidate,
quality, matcher, context clustering or wire-selection limits change.

The existing compact `small_huffman.zig` kernel now supports 256 symbols with
u16 leaf/node/parent indexes, covering all 511 nodes. Capacities64/128 retain
their original byte-index representations. Weights remain u64: even all256
u32-max frequencies sum below2^40. The kernel reads only the initialized active
frequency prefix and owns fixed stack storage without an allocator or raw
input pointer. The new branch rejects an empty/nonpositive dense active set.

Reverse depth propagation now rejects the first depth16 before storing it or
visiting descendants. Every stored parent depth is at most15, so the next u5
addition is at most16. This also fixes the old narrow-kernel overflow: the
exact ordinary function prefix from `f642d0d8` with a sorted34-Fibonacci input
(maximum frequency5702887, natural depth33) actually panics at the old u5
addition in Debug. The first attempted direct module probe fails compilation
because test imports cross its module boundary; the succeeding reproducer
compiles the byte-identical ordinary prefix with tests excluded, and its full
source/extracted-prefix hashes are retained. The new64/128 tests return false
safely and the caller uses the unchanged bounded package merge. No invalid
length is clamped or published.

`codeLengthsReference` retains the complete old dense package-merge path for
validation and measurement. Only the new129...256 attempt is disabled in that
reference; <=128 dispatch remains shared, including the safety fix. The old
fallback body, frequency sorting and scatter methods match the baseline
byte-for-byte. Equal weighted cost alone is insufficient: validation compares
complete per-rank lengths with the old serial-tied package-merge output.

## Independent correctness and tools

Native Debug, native ReleaseFast and actual32-bit x86 each pass the focused
filter21/21. The new kernel tests cover129/130/159/192/255/256 active symbols,
equal/near-equal weights, all-u32-max totals, deterministic random distributions,
Fibonacci skew, untouched output suffixes and input preservation. A separate
O(n²) minimum-node scan and per-leaf parent walk establish natural depths,
without sharing the new queue or reverse-depth implementation. Every accepted
array is compared against the old256-rank package merge, not just cost.

PrefixAlphabet integration tests cover byte-symbol holes, ranked gather,
full scatter, profiled/ordinary equality and genuine >15-bit fallback.
Two initial outer-test assumptions were corrected: arbitrary random weights
need not produce <=15-bit trees, and adding many unit frequencies changes a
Fibonacci tree's maximum depth. The independent depth checks, exact successful
array comparison, dense >15 fallback and fixed34-Fibonacci depth33 check remain.
Original failures and corrected source hashes are retained.

The complete native ReleaseFast Brotli family passes1423 tests with one skip
and no failures. Build checks pass174/174, CLI help7/7 and the legacy context
profile/gate smoke10/10. All successful validations have stable full
src/tools/build snapshots. The legacy gate includes dense natural attempts in
small-Huffman calls and counts package merge only for actual failed attempts.

A narrow `src/br_prefix_bench.zig` wrapper roots the benchmark module at src,
keeping codec-relative imports inside their normal boundary without compiling
the complete library root. The tool first compares reference, ordinary and
profiled full256 output arrays outside each timer and verifies real dispatch
counts. The input-pool digest covers initialized frequency bytes in target
endianness; target and executable provenance are recorded.

## Complete PrefixAlphabet microbenchmark

Intel i7-10700K, CPU8, Zig0.16.0 ReleaseFast, `skylake+pku+sgx`.
`zig build run-br-dense-huffman-bench -- 20000` runs four deterministic32-input
pools, five alternating reference/candidate rounds and untimed warmups.
No compiler process is observed in the accepted timing run. Both timed loops
use runtime pool indexes and noinline complete PrefixAlphabet calls, including
rank-frequency gather and length scatter. Both consume all256 returned lengths
in the same checksum. These are whole PrefixAlphabet samples, not exclusive
queue-construction times or public compression throughput.

| Pool | Package/reference ns/call | Candidate ns/call | Point speedup | Fallback inputs |
| --- | ---: | ---: | ---: | ---: |
| Dense ties | 16774.002 | 1026.531 | 16.3405x | 0/32 |
| Dense mixed | 19836.780 | 2328.681 | 8.51846x | 1/32 |
| Deep skew | 16690.247 | 17396.331 | 0.959412x | 32/32 |
| Medium control (65...122 active) | 675.383 | 686.863 | 0.983286x | 0/32 |

Failed natural attempts add work before the original package merge. That
slower path is retained explicitly; the change does not accelerate every
histogram. Medium control uses the same <=128 implementation on both sides,
and its point difference is not assigned statistical significance. The first
smoke incorrectly required all mixed inputs to avoid fallback; the corrected
tool records the real mixed count, without changing inputs or relaxing the
length cap. An iterations1 smoke is only functional evidence.

## Ordinary q8 and actual context evidence

Old and candidate public APIs encode14 frozen64KiB inputs with five alternating
Vort/reference rounds each, q8/generic/default window16. The explicit reference
is the local experimental Release libbrotli1.2.0-dev encoder/decoder/common
from checkout `558fc647`, with lgwin22. Quality numbers and window defaults do
not imply equivalent algorithms. Source, input, executable and requested
reference-file identities remain stable; compiler observations are zero.
Reference-file hashes do not verify the entire loader dependency closure.

| Ordinary public median | Old | Candidate | Version point speedup |
| --- | ---: | ---: | ---: |
| Mozilla | 100.170ms | 59.873ms | 1.67306x |
| Office | 132.428ms | 80.019ms | 1.65495x |
| OSDB | 107.557ms | 65.537ms | 1.64115x |
| SAO | 158.804ms | 92.543ms | 1.71600x |
| Source | 37.981ms | 35.750ms | 1.06239x |

The initial fourteen-row ordinary throughput geometric speedup is1.230503x;
all14 initial median point estimates improve. Three supplemental alternating
old/candidate version process pairs give geometric ratios of 1.217449x/1.209855x/1.216459x.
Their combined fourteen-row geometric ratio is1.214583x. Mozilla and SAO
remain approximately1.67...1.75x and1.67...1.71x respectively across those
pairs. Webster has two small negative pair points; smaller differences are
not assigned statistical significance. All Vort/reference wire hashes and
settings remain unchanged. Vort output remains288091/296445 reference bytes,
with nine smaller frames. An independent sample gate checks frozen input,
raw timing summaries, CSV, executable and requested reference files.
The candidate/reference throughput geometric ratio is0.0329771x, with zero
competitor throughput wins. The remaining gap is substantial.

Seventy actual profiled calls match ordinary and previous wires and pass the
independent event/timing gate. Ordered common wire configurations, lengths and
selection decisions match the old profile, as do suffix/cluster/assignment
work, tree requests, active buckets and uncached counts. Only Huffman
construction dispatch changes. Mozilla natural attempts replace all796/830
dense package calls without failure, while source remains nondense.

| Instrumented code-length stage median | Old | Candidate |
| --- | ---: | ---: |
| Mozilla lazy | 20.440ms | 2.193ms |
| Mozilla optimal | 22.244ms | 2.416ms |
| Source lazy | 0.505578ms | 0.529187ms |
| Source optimal | 0.549230ms | 0.575979ms |

New Mozilla instrumented outer/context medians are63.707/34.748ms. Nested
stage medians are nonadditive; instrumentation costs and clock observations
prevent interpreting those values as ordinary competitor throughput. Source's
nondense local-stage slowdown remains visible alongside its ordinary point
improvement. Broader workloads and targets require independent measurement.

Pinned public ELF verifies the actual ordinary scorer calls the dense
PrefixAlphabet branch, invokes the256 two-queue kernel, scatters on success
and invokes the unchanged package merge on failure. Its u16 indexes and u64
weights, stable leaf/parent comparison and bounded-depth failure branch are
visible. The named kernel has6016 bytes of explicit stack reservation and
also uses observed stack red-zone storage; that instruction is not its full
frame size. This audit does not claim complete call-chain stack, RSS or
competitor memory leadership.

The [evidence package](data/brotli-dense-huffman-20261025/artifact-manifest.json)
retains raw rounds, old/current source identities,
independent tests, unsuccessful attempts, corrected assertions, dispatch and
ELF reviews, public/profile comparisons and final handoff validation. The next
step is to examine remaining context/entropy coding cost on the current
ordinary API, while extending quality, streaming, platform and memory coverage.
