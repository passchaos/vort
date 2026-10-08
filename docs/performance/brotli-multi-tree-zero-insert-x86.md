# Brotli multi-tree zero-insert command lookup on x86-64

Date: 2026-10-01

## Motivation

The 1 MiB `clustered_q8` reference stream is Vort's lowest current Brotli
decode row on this x86-64 host. Its 16,818 commands include 11,086 zero-insert
commands (65.9%), while only the narrower zero-extra-bit subset could use the
existing 16-bit fused command root. The stream has 52 literal context trees,
three command block types, 17 distance trees, and 16,741 literal bytes. Its
copy distribution is also command-heavy: 14,713 copies are at most 16 bytes,
806 are 17--64 bytes, and 1,299 are longer.

The retained path extends the large flat-literal executor only when a standard
meta-block has at most four command trees and at most 64 distance trees. It
builds one existing 32-bit single-command lookup per command tree and reuses
the existing external distance lookup representation. A zero-insert root hit
contains the copy base, copy extra-bit width, and implicit-distance flag, so
the payload loop reads the copy extra bits directly. Non-zero-insert entries,
long Huffman codes, command block switches, and unsupported table shapes keep
the established compact/canonical fallbacks. Command-block progress is
decremented exactly once on every path.

## Frozen paired result

The baseline is clean revision `52fb2bf9`. Separate ReleaseFast binaries were
frozen before measurement and run on CPU 2 in alternating process order. Both
used the local `/home/passchaos/Work/brotli` checkout at
`558fc647cdaf391228d614ca85f711e02e4e583b` (`v1.2.0-169-g558fc64`) through
`LD_LIBRARY_PATH=/tmp/vort-brotli-upstream-build`.

The exact command shape was:

```sh
taskset -c 2 env LD_LIBRARY_PATH=/tmp/vort-brotli-upstream-build \
  BINARY --case clustered_q8 --iterations 500 --csv OUTPUT
```

Across 15 independent pairs:

| metric | result |
| --- | ---: |
| direct median speedup | 1.0152x |
| direct geometric-mean speedup | 1.0210x |
| direct wins | 14 / 15 |
| direct range | 0.9809x--1.0808x |
| libbrotli-normalized median speedup | 1.0197x |
| libbrotli-normalized geometric-mean speedup | 1.0150x |
| candidate/libbrotli median | 0.8450x |
| candidate/libbrotli geometric mean | 0.8455x |

This is a repeatable improvement for the measured multi-command-tree shape,
not overall Brotli leadership. The target remains about 15.5% below local
libbrotli by the median throughput ratio.

## Controls

A seven-pair complete 13-row matrix had a 1.0031x geometric mean across row
medians. `clustered_q8` improved by 1.0201x median / 1.0272x geometric mean
with 7/7 wins and a 1.0010x minimum. The shortest rows were noisy, so longer
10,000-iteration controls were run separately:

| control | pairs | median | geometric mean | wins |
| --- | ---: | ---: | ---: | ---: |
| `structured` | 21 | 0.9915x | 0.9930x | 5 / 21 |
| `structured_q11` | 21 | 1.0031x | 1.0024x | 11 / 21 |
| `repetitive_q11` | 21 | 0.9970x | 0.9963x | 7 / 21 |

Fifteen repository-source q1 pairs were neutral at 0.9984x median / 0.9987x
geometric mean; every candidate run still exceeded libbrotli, with a 1.0066x
median candidate/reference ratio. The retained specialization therefore
accepts a measured sub-1% cost on the small `structured` control in exchange
for the stable `clustered_q8` gain, while leaving the existing single-tree q1
lead intact.

A compact-tail literal-block run-batching precursor was rejected: 15 target
pairs measured only 0.9815x median / 0.9799x geometric mean with 0/15 wins.

## Rejected follow-ups

Nine follow-ups were measured against the frozen retained binary after this
change. None met the complete-frame retention threshold, and all production
code was removed:

- Restricting the route to two or more command block types was neutral on the
  unchanged three-type target at 1.0000x median / 0.9986x geometric mean over
  15 pairs. Three 21-pair long single-type controls ranged from 0.9998x to
  1.0029x geometrically, and a seven-pair full matrix reached only 0.9993x
  across row medians. The narrower gate therefore did not recover a stable
  control cost.
- Using that stronger route invariant to remove the command-countdown guard
  reached only 0.9983x median with 5/15 wins. Removing the per-command
  block-type comparison reached 1.0006x median / 0.9986x geometric mean with
  8/15 wins. Neither branch change justified a separate executor shape.
- Constructing literal, command, and distance lookups directly in their final
  arrays reduced the multi-tree setup helper from `0xb19` to `0x459` bytes and
  its stack frame from `0x17ca0` to `0x14078`, but complete target decode fell
  to 0.9901x median / 0.9894x geometric mean with 2/15 wins. Lookup setup is not
  the limiting stage, and the smaller generated function did not improve the
  complete frame.
- Materializing non-identity dictionary transforms directly in caller output
  avoided a scratch copy for most of the 4,255 dictionary commands, but the
  larger hot executor measured 0.9946x median / 0.9954x geometric mean with
  2/15 wins.
- Expanding the 32-bit root from zero-insert commands to every command whose
  insert length has no extra bits measured 0.9868x median / 0.9883x geometric
  mean with 1/15 wins. Non-zero inserts remain faster through the compact
  metadata path.
- Caching the active literal context-map base and mode across the four literal
  block types measured 0.9937x median / 0.9898x geometric mean with 4/15 wins.
  Its extra live state costs more than the avoided indexing on this
  low-literal workload.
- Carrying the command LUT's two-bit distance context through
  `InsertCopyLengths` removed the per-distance copy-length comparison and
  shortened the multi-tree executor by 22 bytes. The larger returned state was
  much more expensive: 15/15 target pairs lost, at 0.9756x median / 0.9747x
  geometric mean.
- Outlining static-dictionary transform and copy handling shortened the same
  executor from `0x11a6` to `0x10de` bytes, but its 4,255 dictionary commands
  made the call boundary hot. All 15 target pairs lost, at 0.9296x median /
  0.9299x geometric mean.

These results rule out more local state, broader 32-bit command entries,
setup-only shrinking, and outlining the dictionary path for this stream. A
credible next step needs to reduce actual distance/copy work without expanding
returned state or adding a hot call boundary.

A later x86-64 follow-up used the cached-distance audit's 16,663 explicit
distances and only 17 distance-block switches to test the local countdown
before `block_type_count`. The selected multi-tree instance kept the same
address and size, but all seven clean clustered-q8 pairs lost at `0.9911x`
median / `0.9910x` geometric throughput. The change was removed; exact samples
are in
[brotli-flat-distance-followup-x86-20261006.json](data/brotli-flat-distance-followup-x86-20261006.json).

## Distance and copy shape audit

A second non-timing parse examined every copy before changing the copy
kernels. Only 24 of 12,563 LZ77 copies overlap. Among short copies, lengths
5/6/7/8 occur 3,098/1,974/1,594/1,142 times, respectively. The 1,299 copies
above 64 bytes are even more concentrated:

| length | count | decoded bytes |
| ---: | ---: | ---: |
| 193 | 92 | 17,756 |
| 292 | 258 | 75,336 |
| 732 | 260 | 190,320 |
| 979 | 540 | 528,660 |

Those four exact lengths account for 1,150 copies and 812,072 output bytes.
The static dictionary is similarly concentrated: transform zero accounts for
3,749 of 4,255 commands, while output lengths 4--8 account for 3,378 commands.

Six fixed-copy follow-ups were nevertheless slower and were removed:

- An 8/16-byte LZ77 copy tier measured 0.9836x median / 0.9883x geometric
  mean with 2/15 wins. The extra length branch costs more than reducing the
  speculative store from 16 to eight bytes.
- Removing the redundant-looking nonzero-length test measured 0.9952x median /
  0.9964x geometric mean with 1/15 wins; the resulting global layout change
  outweighed the deleted comparison.
- Packing 4--8-byte dictionary output into one bounded eight-byte store
  measured 0.9872x / 0.9870x with 2/15 wins. Exact 4/5/6/8-byte stores were
  worse at 0.9773x / 0.9747x with 0/15 wins.
- A load-first 128-byte vector loop for non-overlapping copies of at least 128
  bytes measured 0.9423x / 0.9421x with 0/15 wins. The system memcpy/ERMSB path
  is substantially faster on this host.
- A constant-size `memcpy` only for the 540 length-979 copies measured 0.9884x
  / 0.9845x with 0/15 wins. Giving LLVM the exact length expanded the hot
  executor without beating the dynamic memcpy path.

The retained 16-byte short-copy move and dynamic large-copy memcpy are the
measured best x86 paths. Further work should not add another copy-size branch
without a different execution model or hardware-specific evidence.

## Cached context-three distance tree

The distance audit found 155 implicit-distance commands and 16,663 explicit
distance symbols. Context three accounts for 15,997 explicit distances
(96.0%); contexts zero through two account for only 78, 183, and 405. The
stream switches distance block type only 17 times. Regular symbols are spread
across the alphabet, with symbols 42/44/41/40/38 occurring
2,211/1,542/1,283/1,093/1,050 times, while short symbol one occurs 1,835
times. Extra-bit widths 14/13/15/12/11 account for
3,004/2,376/2,068/1,812/1,525 regular distances.

The retained executor now caches only the context-three tree index for the
active distance block and refreshes that byte on a block switch. Other
contexts still load the parsed context map, every selected index retains its
tree-count check, and the existing external lookup/canonical fallback remains
authoritative. This avoids the four-pointer cache previously rejected while
removing the dominant context-map load. The ReleaseFast multi-tree executor
shrinks from `0x11a6` to `0x119e` bytes.

Against frozen `a74d1d1b...`, 21 fixed-CPU-2 pairs with 1,000 requested
iterations improve `clustered_q8` by 1.0039x median / 1.0050x geometric mean,
with 17/21 wins and a 0.9949x--1.0161x range. Simultaneous libbrotli
normalization is 1.0076x median / 1.0140x geometric mean. Candidate throughput
reaches 0.8570x median / 0.8620x geometric local libbrotli 1.2.0-dev, so the
remaining parity gap is still substantial.

A seven-pair full matrix keeps the target positive at 1.0033x median / 1.0080x
geometric with 7/7 wins. Short rows remain noisy. Longer controls recover
`structured` to 1.0069x median and `text_q3` to 1.0027x median / 1.0030x
geometric; repository source q1 is neutral at 1.0014x median / 0.9984x
geometric and remains above libbrotli at a 1.0038x median ratio.

Two recent-distance follow-ups were rejected. Short symbols zero through three
occur 1,960 times, including 1,835 symbol-one hits, but directly indexing the
recent-distance ring for all four symbols measured only 0.9985x median with
5/15 wins. Specializing symbol one alone measured 0.9994x median with 6/15
wins; one 1.53x host outlier made its geometric mean unusable. Both variants
expanded the hot executor by more than 100 bytes and were removed. The compact
noinline short-distance resolver remains the measured best layout.

Caching the context-three external lookup pointer in addition to its one-byte
tree index was also rejected. It grew the executor from `0x119e` to `0x11da`
and measured 0.9863x median / 0.9889x geometric mean with 2/15 wins. Even one
extra long-lived pointer recreates the register-pressure cost seen in the
earlier four-pointer cache; the retained implementation caches only the index.

## Identity transform dispatch follow-up

The current stream uses 4,255 static-dictionary commands, including 3,749
transform-zero identities. Upstream libbrotli handles its identity transform
without entering the complete transform routine. A focused Vort candidate
therefore inlined only the checked transform-zero address resolution in the
flat multi-tree executor; the other 506 commands retained the canonical
121-transform dispatcher. This is narrower than the previously rejected full
transform inline and direct-output candidates.

GDB proved the frozen workload entered the changed `anon_51097` instance, and
disassembly showed identity success constructing the borrowed dictionary slice
without calling `static_dictionary.transform`. The complete transform function
remained `0x28b` bytes, but the hot executor grew `0x10d5 -> 0x1184` (+175 B),
while the other three flat instances and all Brotli custom-section sizes stayed
unchanged.

Seven clean, alternating, pre-encoded CPU-2 pairs rejected the candidate:

| Metric | Result |
| --- | ---: |
| paired median | 0.98815x |
| paired geometric mean | 0.98835x |
| wins | 0/7 |
| range | 0.98678x--0.99145x |

Every pair decoded 500 frames with identical checksums. A preceding complete
15-pair campaign was discarded without inspection after its 20-millisecond
monitor observed an external Zig process. The clean screen is decisive: saving
the identity call does not repay the larger executor, so the source was fully
restored. Exact nanoseconds, executable/fixture/CSV hashes, monitoring data,
and shape evidence are in
[brotli-flat-identity-fast-x86-20261008.json](data/brotli-flat-identity-fast-x86-20261008.json).

## Command-root working-set follow-ups

The flat workload's prepared roots occupy about 55 KiB before canonical-tree
fallback state: 52 eight-bit literal roots use 26 KiB, three direct 32-bit
command roots use 12 KiB, and 17 nine-bit distance roots use 17 KiB. The three
command trees contain 78, 208, and 129 active symbols, so two compact forms
were tested without changing lookup width or zero-insert coverage.

The first form used 16-bit roots that indexed a dense 24-bit metadata palette.
It reduced each command lookup from 4,096 to 2,816 bytes but added a dependent
palette load on every root hit. Three clean fixed-CPU pairs were decisive:
the candidate reached only `0.88243x` median / `0.88214x` geometric throughput
with 0/3 wins. It was removed.

The second form stored the complete command metadata directly in three bytes.
Command symbols need at most ten bits and zero-insert copy bases fit twelve, so
the representation retained all fields without a palette. A one-byte pad made
the final unaligned u32 load bounded. Each lookup used 3,073 bytes; ordinary
`.text` shrank by 912 bytes, rodata stayed unchanged, and the target executor
grew only `0x10d5 -> 0x10e7` (+18 B). Its hot difference was an `index * 3`
address calculation plus an unaligned u32 load instead of the baseline's
scale-four aligned load.

For the longer direct-root campaign, the user authorized physical-core
separation: Vort ran on CPU 2 while its SMT sibling CPU 10 was also excluded
from the live Spectra process group, which was restricted to CPUs
`4-7,12-15`. Fifteen alternating pairs observed no Zig process allowed on the
reserved core and all checksums matched:

| Metric | Result |
| --- | ---: |
| paired median | 0.99251x |
| paired geometric mean | 0.99258x |
| wins | 0/15 |
| range | 0.98818x--0.99706x |

The three-byte stride still costs more than the smaller working set saves.
Both forms were removed, retaining aligned 32-bit direct roots. Future
working-set work must avoid both a dependent lookup and a non-power-of-two hot
stride. Raw nanoseconds, CSV and executable hashes, affinity evidence, shape
counts, and discarded-campaign notes are in
[brotli-flat-command-root-working-set-x86-20261008.json](data/brotli-flat-command-root-working-set-x86-20261008.json).

An aligned single-load follow-up retained the 32-bit fused metadata and only
reduced the root width from ten to nine bits. This cut the three active command
roots from 12 to 6 KiB without changing rodata or any flat executor size; the
ordinary text section also shrank by 576 bytes. Long command codes now fall
back after nine bits instead of ten.

Fifteen physical-core-isolated pairs still lost 15/15 at `0.99013x` median /
`0.98995x` geometric throughput, ranging from `0.98625x` to `0.99330x`.
The additional long-code work costs more than the 6 KiB footprint reduction,
so production retains the ten-bit fused root. Exact samples and hashes are in
[brotli-flat-fused-command9-x86-20261008.json](data/brotli-flat-fused-command9-x86-20261008.json).

## Literal-root working-set follow-up

The same workload actively indexes 52 eight-bit literal roots. The canonical
external representation stores `(symbol + 1, bit_count)` in one aligned u16,
using 512 bytes per tree and 32 KiB for the 64-tree flat capacity. A compact
candidate split each root into a 256-byte symbol plane and a packed 128-byte
encoded-length plane. Both planes retained power-of-two tree strides and used
the same root index, so their loads were independent rather than palette
dependent. Encoding `bit_count + 1` left zero as the long-code sentinel while
preserving literal zero, literal 255, and zero-bit single-symbol trees.

The representation reduced each tree from 512 to 384 bytes, the full flat
allocation from 32 to 24 KiB, and the target's 52 active roots from 26 to
19.5 KiB. Ordinary `.text` grew only 32 bytes and rodata four bytes; the target
executor grew `0x10d5 -> 0x1106` (+49 B). Exhaustive eight-bit-root, literal
255, single-symbol, bit-progress, and atomic-fallback oracles passed.

The same user-authorized physical-core isolation was used: Vort ran on CPU 2,
its sibling CPU 10 was reserved, and the live Spectra process group was pinned
to `4-7,12-15`. Fifteen alternating pairs saw no Zig process allowed on the
reserved core and preserved every checksum:

| Metric | Result |
| --- | ---: |
| paired median | 0.98172x |
| paired geometric mean | 0.98180x |
| wins | 0/15 |
| range | 0.97680x--0.98659x |

The second independent load plus nibble extraction costs more than the 25%
root reduction saves. The candidate was removed, retaining the single aligned
u16 literal-root load. Exact samples, hashes, affinities, generated sizes, and
oracle coverage are in
[brotli-flat-literal-root-working-set-x86-20261008.json](data/brotli-flat-literal-root-working-set-x86-20261008.json).

## Correctness evidence

The focused lookup test checks zero-insert copy-extra decoding and exact
command-block countdown. The complete direct Brotli ReleaseFast suite passes
all 541 tests. The local libbrotli reference gate passes all 13 rows. The
upstream multi-block differential passes 98 core cases, 7,056 one-shot cases,
7,056 progressive cases, 1,401 fragmentation cases, 64 high-tree truncation
cases, and seven Large Window decode cases, with zero unsupported summaries.
The real-corpus differential passes four files across four categories in 16
one-shot and 16 progressive configurations. `zig build check -j1` also passes.

The formerly source-self-referential allocating-summary regression fixture was
also made deterministic. It now creates a 32 KiB match at the exact legal
17-bit distance limit (131,056 bytes), followed by literal context, so source
layout changes cannot silently remove the history-exhaustion condition being
tested.

Exact binary/library hashes, commands, target observations, matrix summaries,
and control summaries are recorded in
[brotli-multi-tree-zero-insert-x86-20261001.json](data/brotli-multi-tree-zero-insert-x86-20261001.json).
