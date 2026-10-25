# Exact Brotli literal alphabet ordering

Date: 2026-10-25. Baseline: `d689a411`. The objective of industry-best
functionality and performance remains incomplete.

After the dense Huffman increment, actual q8 context profiles identify alphabet
ordering as the largest remaining tree-score child on Mozilla, Office and SAO.
SAO lazy/optimal alphabet medians are11.365/11.285ms; source is0.585/0.630ms.
The prior `buildTreeAlphabet` fuses supported-symbol collection with insertion
sorting, so dense unrelated frequencies cause quadratic comparisons and
movement. This increment retains exact supported frequencies, ranks and all
scoring/search behavior while replacing only that ordering work.

## Pure ranking module and reference

`literal_alphabet.zig` owns supported-symbol collection and rank construction.
Its `build/reference` calls accept the original frequency array, an ascending
unique parent support and fixed alphabet/tree-symbol outputs. It reads only
frequencies addressed by support or already-filtered live symbols; unsupported
frequency slots may remain undefined, as in the existing sparse suffix scorer.
It resets both lengths and writes only active output prefixes. Zero live
symbols retain `InvalidBlockPlan`. No allocator, raw input or scorer is retained.

Support below64 uses the original fused insertion policy. Larger support first
collects live tree symbols in ascending-symbol order. If live frequencies
already descend, the alphabet is copied directly in that same order. Otherwise
live counts below64 use insertion and larger live sets use stable radix.
The threshold selects an exact sorting implementation, not a compression level,
search budget or candidate gate.

Each key is `(u64(~frequency) << 8) | symbol`: full32-bit unsigned frequency
is widened before shifting, and the low byte retains the unique byte symbol.
Four stable frequency-byte passes at shifts8/16/24/32 order complemented
frequencies ascending. The initial ascending symbol order gives the exact tie
without sorting its low byte separately. OR-XOR variation permits skipping
only uniform digits, whose stable ordering is the identity. An executed pass
flips source/destination; a skipped pass does not. Odd pass counts copy back,
while even counts finish in the key array.

Counts, positions and cumulative offset are u16 and can represent256. Used
scatter indexes stay within0...255; an empty bucket can have offset256 but
has no element to scatter. Temporary storage is initialized for its entire
active range before it becomes input to another pass. Full-frequency tests
cover high-bit values and skip/pass parity without clamping frequencies.

The original fused body remains an exact reference. Existing independent
support/dense scoring tests compare full alphabet ranks, ascending tree symbols,
length arrays and tree bit costs; normal and profiled searches consume the
same actual result. The CLI/profile tools do not search a second time solely
for diagnostics. Candidate loops, parsers, budgets, cache scope, Huffman
construction and exact-wire arbitration remain unchanged.

## Rejected generic sort and retained radix

An initial complete40-bit-key PDQ comparison sort passed exact outputs but
was slower on most measured pools. Threshold64/medium96/boundary128 ratios
were0.401656x/0.476636x/0.527122x versus insertion; dense mixed was0.789268x.
Worst insertion order and already-ordered ties improved, but those controls
did not justify publishing that candidate. It was rejected before public
encoding measurements. Its source, executable and raw samples are retained.

The replacement stable radix uses the same eight32-slot pools and identical
input hashes, preserving input generation, preflight and timed scope. All
frequency bytes remain represented; low-range datasets simply have uniform
high digits that can be skipped. The change does not truncate frequencies
for a faster result.

## Independent tests and validation

The pure module contract passes in native Debug, native ReleaseFast and actual
32-bit x86. Its independent O(n²) selection oracle picks maximum frequency and
minimum symbol, rather than sharing packed keys or radix logic. It compares
both complete valid output arrays and their lengths against production and
original insertion. Cases include empty/zero, dynamic threshold boundaries,
63/64/65 and128/129, full255/256 live sets, equal weights, all-u32-max, high
unsigned values, full-range random frequencies, holes, unsupported larger
frequencies, and explicitly undefined unsupported slots. Guard/tail sentinels
and supported input frequencies remain unchanged. One-, two-, three- and
four-frequency-byte variations cover skipped digits and odd/even buffers.

Integrated context/q8 contracts pass76/76 in native Debug and actual x86
ReleaseFast. The complete native ReleaseFast Brotli family passes1424 tests
with one skip and no failure. Build checks pass175/175, legacy profile/gate
smoke10/10 and CLI help7/7; successful source snapshots are stable. These are
correctness/resource/compile checks, not competitor performance claims.

## Complete collection and ordering microbenchmark

Intel i7-10700K, CPU8, Zig0.16.0 ReleaseFast, `skylake+pku+sgx`.
`zig build run-br-literal-alphabet-bench -- 50000` uses eight deterministic
32-slot pools. Full rank/ascending-symbol arrays and both lengths are compared
before timing. Both loops reset the same runtime pool-selection seed and call
a noinline complete collection/order function plus the same checksum of both
active outputs. The five raw rounds alternate old/new order. Input preparation,
provenance, validation and serialization occur outside those timers.

| Pool | Original ns/call | Radix candidate ns/call | Point speedup |
| --- | ---: | ---: | ---: |
| Small16 | 74.970 | 80.392 | 0.932553x |
| Threshold64 | 836.203 | 370.124 | 2.25925x |
| Medium96 | 1629.067 | 481.623 | 3.38246x |
| Boundary128 | 2619.315 | 604.630 | 4.33209x |
| Dense mixed256 | 8120.026 | 1068.308 | 7.60083x |
| Dense equal-frequency ties | 465.370 | 363.480 | 1.28032x |
| Ascending frequencies | 14782.995 | 1427.145 | 10.3584x |
| Sparse full support | 1406.963 | 525.607 | 2.67684x |

Tie slots are identical inputs, not32 distinct histograms. Their result measures
the already-ordered shortcut. Sparse support has256 entries but85/86 live
symbols. Small16 retains insertion policy yet has a small negative point
difference; it is preserved, without attributing significance. Local ratios
include checksum/call work and do not establish ordinary compression speed.
No compiler process is observed during accepted timing; executable/source and
input identities stay fixed. Pool hashes use initialized frequency bytes and
valid support in the recorded target endianness, not undefined padding.

## Ordinary public q8 evidence

Old/candidate public interfaces encode14 frozen64KiB inputs, q8/generic with
unchanged default window16. Each version runs five alternating Vort/reference
rounds per input on CPU8 after all known builds/tests finish. The explicit
reference files are experimental Release libbrotli1.2.0-dev encoder/decoder/
common from checkout`558fc647`, with lgwin22. Quality numbering/window policies
are retained and do not imply equivalent algorithms. Hashes bind requested
library files, not full loader dependency closure.

| Ordinary median | Old | Candidate | Version point speedup |
| --- | ---: | ---: | ---: |
| Mozilla | 59.792ms | 52.176ms | 1.14596x |
| Office | 79.850ms | 70.976ms | 1.12504x |
| OSDB | 65.369ms | 58.407ms | 1.11921x |
| SAO | 92.753ms | 74.498ms | 1.24503x |
| Source | 36.564ms | 35.196ms | 1.03887x |

Initial fourteen-row version throughput geometric speedup is1.060756x with
11/14 positive median points. Dickens/Reymont/NCI ratios are0.999098x,
0.998364x and0.981048x; small/negative differences remain visible.
Three supplemental alternating old/candidate process pairs give geometric
ratios 1.064995x/1.052964x/1.068392x, aggregating to1.062096x
over all42 input/pair points. Mozilla ratios range1.137...1.187x, SAO
1.218...1.239x; source remains1.021...1.032x. Small negative individual
points on Dickens/Reymont/XML/schema remain in raw data. These comparisons
do not assign statistical significance or all-corpus/platform leadership.
Every Vort/reference wire hash and setting is unchanged. Vort total output
remains288091/296445 reference bytes, with nine smaller frames. An independent
sample gate checks frozen input, raw samples, CSV, executable and requested
references. Compiler observations are zero during accepted measurements.
Candidate/reference throughput geometric ratio is0.0344372x with zero wins;
this increment narrows the gap without establishing industry-best performance.

Seventy actual profile calls match previous and ordinary wires and pass the
independent event/timing gate. Ordered common wire/configuration/selection
semantics match the previous profile. Every non-time detail field, including
proposal shape, suffix/cluster/assignment/tree work, construction counters,
cache scope/mode and prefix tokens, is unchanged. This shows the same actual
search and scoring model uses a faster ordering operation.

| Instrumented alphabet stage median | Old | Candidate |
| --- | ---: | ---: |
| Mozilla lazy | 4.984ms | 1.361ms |
| Mozilla optimal | 5.292ms | 1.691ms |
| SAO lazy | 11.365ms | 1.719ms |
| SAO optimal | 11.285ms | 1.759ms |
| Source lazy | 0.584796ms | 0.295514ms |
| Source optimal | 0.629856ms | 0.331832ms |

Mozilla instrumented outer/context medians are57.669/27.940ms; SAO
83.642/45.041ms. Separate stage medians are nonadditive and contain observer
cost. They do not replace ordinary competitor throughput or CPU-time claims.

## Machine code and boundaries

Pinned ordinary ELF confirms support<64 takes inline insertion and larger
support enters the outline helper. After filtering, an already-ordered set
copies directly; otherwise live<64 uses insertion and live>=64 invokes radix.
NOT/u64 shift form the complete-frequency key, and four actual byte-pass skip
gates remain. Frequency loads address support/filtered-symbol indexes. The
observed count/prefix/stable scatter is scalar; no SIMD ordering claim is made.
The ascending/unique support contract is not revalidated as arbitrary malicious
support input in ReleaseFast.

Declared scratch is5120 bytes (keys/temporary/counts/positions). The helper's
explicit reservation is5656 bytes plus saved registers, with an additional
compiler count copy. Larger support reserves that frame even for fewer than64
live symbols. These values do not establish full call-chain stack, RSS or
cross-library memory ranking. The kernel has no heap, hidden global observer
or raw-input ownership.

The [evidence package](data/brotli-literal-alphabet-20261025/artifact-manifest.json)
retains rejected PDQ and retained radix source epochs, exact
outputs, quiet raw ordinary/micro/profile/process-pair samples, machine-code
reviews and final handoff checks. Next investigate remaining cluster assignment,
context-prefix and wire coding costs without removing candidates, then expand
quality/streaming/platform and cross-library memory comparisons.
