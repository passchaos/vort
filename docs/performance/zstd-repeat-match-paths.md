# Zstd repeat-match lookup and mismatch-location screens

Four isolated prototypes were screened against the retained `b3c40946` codec.
They preserve compressed output but do not establish a broad enough ordinary
encoding improvement to adopt. None changes the production codec or public
profile fields. The [evidence package](data/zstd-repeat-match-paths-20261029/)
retains exact source, raw clocks, input/wire bytes, work accounting, compiler
output and independent contracts for future work.

## Per-position full-associative reuse

Each beam row has at most 16 nodes and three repeat distances per node, so a
48-entry result cache can hold every distinct legal repeat probe at one
position. Both prototypes store initialized nonzero distance keys and exact
lengths, including zero-length matches. They borrow one immutable source,
position and maximum, and are reset for each new row/pass/root call.

Lookup compares groups of sixteen `u32` keys. Unused distance cells are zero,
which cannot match a legal probe; complete allocated vectors are safe to read
even in a partially filled group. The first prototype uses `std.simd.firstTrue`
to select the lane. The second uses a little-endian boolean mask and ctz, with
the original firstTrue path retained on big-endian targets. It removes the
long lane-selection reduction seen in the first binary. The capacity is
derived from maximum beam width and the repeat-array size.

On hits, the node still processes every original candidate edge and price
admission. Only matching work is reused. In these private prototypes,
`rep_probes` counts actual misses, `rep_match_reuses` counts exact hits and
`byte_comparisons` records only executed comparisons. Old byte counts are
never replayed. Every other profile field, including requested heap peak,
remains identical. The private hit counter is not added to the production API.

The cache occupies 464 bytes on this x86_64 target and clears 192 distance
bytes per row. Generated DP stack frames increase by 560 bytes for firstTrue
and 544 bytes for mask selection; the requested heap cap does not change.
The reuse rate is 65.7%-81.9%, avoiding about 2.10-11.97 million comparison
bytes in the six 4 KiB configurations.

| Silesia 4 KiB / strategy | FirstTrue cache time ratio | Lane-mask cache time ratio |
| --- | ---: | ---: |
| Dickens btopt | 1.0168 | 1.1616 |
| Dickens btultra2 | 1.0034 | 0.9582 |
| Mozilla btopt | 1.0235 | 1.0115 |
| Mozilla btultra2 | 0.9978 | 1.0806 |
| MR btopt | 0.9913 | 0.9955 |
| MR btultra2 | 0.9860 | 0.9577 |

Each ratio is median candidate time divided by median baseline time across
two balanced AB/BA rounds. The first cache is largely near parity. The mask
cache has mixed results and unusually slow calls in Dickens btopt/Mozilla
btultra2; raw ordinary and diagnostic clocks are retained. Cache work counts
are identical between the two shapes. Fewer executed bytes and shorter
lane-selection code do not by themselves prove improved encoder throughput.
Neither cache was expanded to a larger performance matrix after this screen.

## Vector32 mismatch location

A separate matching-kernel prototype converts the existing 32-byte comparison
to a boolean bit mask and uses ctz to identify the first differing byte on
little-endian targets. Big-endian targets keep the original firstTrue path.
The compared bytes, access limits and full profile are unchanged. Generated
native match-length code shrinks from 583 to 485 bytes and its min-reduction
sequence disappears.

| Silesia 4 KiB | btopt time ratio | btultra2 time ratio |
| --- | ---: | ---: |
| Dickens | 0.9831 | 0.9910 |
| Mozilla | 0.9917 | 0.9849 |
| MR | 0.9967 | 0.9744 |

Two paired directions are mixed, and improvements are small. A separate
single-round larger/trained matrix has ratios 0.9688/0.9834 for Dickens,
1.0087/0.9812 for Mozilla and 1.2419/1.0109 for the dictionary input. The
trained btopt candidate's ordinary and diagnostic calls are both slower than
baseline. That 24% point remains visible; its cause is not established. This
kernel is not adopted from the limited matrix.

## Four-byte prefix rejection

The last prototype keeps the original SIMD/scalar mismatch locator. At each
source span with at least 32 available bytes, it first compares the exact
initial four bytes using a little-endian word read. A mismatch returns its
byte offset immediately; an equal prefix continues through the old matching
path. The little-endian read makes the ctz byte position independent of host
endianness. All accesses remain within the known available span.

Actual comparison accounting changes: the precheck adds four bytes; a mismatch
there charges four, while an equal prefix also pays the existing 32-byte and
scalar comparisons. This is validated by an independent scalar/span ledger,
including rechecking the prefix on a new dictionary/history/block span.
Every other profile field, sequence and heap peak remains identical.

| Input | btopt time ratio | btultra2 time ratio |
| --- | ---: | ---: |
| Dickens 4 KiB | 0.9905 | 0.9466 |
| Mozilla 4 KiB | 0.9933 | 0.9862 |
| MR 4 KiB | 0.9569 | 0.9866 |
| Dickens 16 KiB | 0.9744 | 0.9691 |
| Mozilla 16 KiB | 0.9946 | 0.9824 |
| Trained dictionary input 8 KiB | 0.9854 | 1.0158 |

The 4 KiB matrix has two rounds; larger rows have one separate balanced round.
Most points improve slightly, but small-input directions are mixed and trained
btultra2 is slower. Its subsequent diagnostic call is near parity, while
Mozilla diagnostic calls can be slower despite improved ordinary times. All
original observations remain; no favorable additional round is added. This
candidate also stays out of production. The generated matching function grows
from 583 to 666 bytes, and comparison-byte reductions are not timing claims.

## Validation and scope

Each cache completes 24 ordinary encodes and 48 native decodes. Each independent
matching kernel completes 36 ordinary encodes and 72 native decodes across
small and larger matrices. All 120 ordinary wires decode exactly through local
libzstd 1.6.0 with the appropriate dictionary, and every complete wire agrees
with its baseline. Profile comparison accounts only for the explicitly changed
executed work fields; all other fields and allocation peaks agree.

Full-associative contracts pass 24/24 in native Debug/ReleaseFast/x86 Debug.
The lane-mask version passes 25/25 on the same targets, adding all 65,536
possible lane patterns. Each slot has its own expected length 0...47 so wrong
lane selection cannot hide behind identical values. The suite verifies partial
groups, capacity, resets, failure accounting, quota prefixes, complete plans,
working-memory bounds and a freshly frozen current public frame.

Vector32 and prefix contracts each pass 5/5 on those three targets. The first
has 779,712 geometric checks; the second has 779,714. Frozen resources and
independent scalar `Source.match` oracles cover alignment, every lane and
prefix block, multiple mismatches, overlapping copies, noncontiguous spans,
window/maximum limits, malformed distances/positions, null profiles and
saturating counters. The prefix ledger derives actual charges without copying
word loads or vector code. Vector32's big-endian fallback is compiled as a
PowerPC64 object; it is not executed. Earlier temporary vector32 properties
also execute in WASI, separately from the final grouped native contracts.

All ordinary matrices use one codec thread, CPU 2, Zig 0.16.0 LLVM ReleaseFast
and Skylake code generation. Compiler processes start on CPUs 4/6. Background
load remains recorded and whole-host isolation is not claimed. Ordinary timers
exclude input preparation, returned-frame free, decode and the later independent
profile encode. No benchmark used profiled encode time as ordinary time.

The results leave the current validated codec unchanged and route future work
toward more substantial state/edge costs or wider codec improvements. The full
deflate/zstd/brotli/lz4/xz/zip/rar/tar/bzip2/snappy objective remains active.
