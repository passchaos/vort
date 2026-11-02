# Local-optimal choice price preparation, 2026-11-03

The default local-optimal parser now prepares fixed price terms for one
immutable node/offset choice. Its first maximum-length edge still performs
the original full sequence price, literal-run closure and checked node cost.
Only a complete successful edge publishes the fixed LL/OF base, closed cost
and LL0 price. Later lengths price their ML independently, retain each budget
admission and original work counters, and check both cumulative u64 additions.

Intervals with `last - first < 4` and single-edge tails retain the original
scorer. The maximum edge remains first, followed by the original short lengths
and ML endpoints, including duplicates. Candidate discovery, match frontiers,
repeat aliases, insertion ties, parsing states, refinement passes and allocator
limits remain unchanged. New profile fields distinguish successful choice
preparations, admitted replays and unprepared edges. Successful local searches
reconcile their sum with the original price-evaluation count.

The fixed model/node/choice contract lasts only for one interval. Preparation
is reset for each new choice and pass, including cold btultra2's two differently
priced searches. No heap, retained array or cross-block cache is added. The
unfinished literal-run price remains part of node cost; its checked subtraction
cannot be removed by algebraic cancellation because underflow is observable.
LL 131072 is a virtual trailing-literal value, not a legal real sequence LL.

## Independent correctness

The price oracle freezes the original symbol rules and old priced-node formula.
It compares complete nodes, errors, admission and all previous profile fields
across LL/ML/OF boundaries, zero prices, offset aliases, underflow/overflow,
exact u64 limits and zero/N/N−1 price quotas. Its 2,882 first calls and 12,410
replays include 2,368 error observations. Refused edges do not publish a
preparation or increment admitted price counters; successful first publication
does not bypass a later high-ML overflow.

A separate copied interval oracle compares every committed quota prefix,
poisoned and populated rows, initialization progress, target nodes, strict ties
and immutable input models. It covers 1,463 intervals, 167,316 edge prices and
1,294 quota prefixes, including preparation-threshold neighbors. Thirty-six
synthetic matcher plan configurations compare records, offsets, final repeats,
statistics, estimated cost and peak allocator state, then independently replay
content. Three failure prefixes check exact errors and cleanup. Full public
wire comparisons are supplied by the benchmark's cross-decoder checks rather
than treating synthetic matcher output alone as format interoperability.

The registered root frontier filter passes 25 tests in ReleaseSafe and
ReleaseFast. Actual 32-bit x86 ReleaseSafe and WASI ReleaseFast execution also
pass 25 tests each. One initial cross-target diagnostic found that a test-only
cumulative counter used usize for u64 profile totals; widening that counter
preserves the test computation and the production binary. The public HQ Wasm
gate passes seven build steps and exercises the default local-optimal API,
quota refusal/retry and unchanged beam safeguards.
The complete native ReleaseSafe Zstd suite passes 1,268/1,268 tests with exit
zero. The modified test accumulator has the same native width and is separately
checked on 32-bit x86/WASI; those target checks retain their own executed logs.
The final `check check-wasm` build also completes 212/212 steps with exit zero.
Formal performance starts after these compiler/verification processes finish.

## Code-shape experiments

The first fully inlined preparation/replay variant preserves wires, old
settings/counters and errors, but expands the interval from 1,485 to 5,873
executable bytes. Its three-sweep selected-input screen takes 1.69% more
real-input time, so it is rejected. Keeping first and replay as cohesive
out-of-line functions shrinks the interval to 2,733 bytes, with 1,255/576-byte
first/replay helpers. That selected-input epoch improves real time about 2.1%,
while some Dickens/MR rows still regress and remain recorded.

A uniform wider interval threshold of sixteen preserves every edge but has a
near-neutral 0.99937 real-input time ratio. It is rejected in favor of the
original four-length threshold. No branch is disabled based on previous wire
winners or corpus-specific choices. Screen results guide candidate selection;
final-source ordinary results remain a separate epoch.

## Reproduction and scope

Baseline source is `0a673757`. Artifacts under
`zig-out/zstd-frontier-choice-20261103` preserve a pristine Git snapshot,
independent oracles, rejected variants, source-bound final binary, complete
input/wire identities, raw paired rounds and terminal validation. Timed calls
use the public allocating native frame API with control/memory profiling
disabled; separate diagnostic encodes verify the same wire and actual engine.
Allocation and caller frame release are timed. Input setup, hashing and both
decoder directions are outside the interval.

Zig 0.16.0 LLVM ReleaseFast targets GNU x86-64 with `skylake+pku+sgx` on an
Intel i7-10700K, CPU2, one codec thread. The reference is pinned libzstd 1.6.0
at clean source `01b7154f1172432f8abe9b3bb9909e14a1176b7d`, shared-object SHA
`c76f4c4457df67a5e0c7bb6bb4f58b9857cf4f2cdd7925bfb9345daac4e6b83e`.
A separate loaded-object probe confirms the requested file. Requested controls
are btopt/btultra2, window17, depth64, nice64, minimum3, content/checksum flags
enabled and no workers. Reference unspecified hash/chain parameters retain
level-3 defaults; matching controls does not establish equal algorithms.

The three-codec industry-best goal stays active. Match/index lifecycle,
cost-model quality, full-file/dictionary/streaming, memory and broader platform
comparisons remain necessary. Local price reuse does not close those gaps.

## Final ordinary matrix

Three alternating outer sweeps cover twelve Silesia sources at 4/64/128 KiB
with btopt and btultra2, three actual 1 MiB multi-block inputs, a trained
dictionary and periodic/random/repetitive controls: 82 configurations and
492 serial processes. Each process retains five timing rounds. Controls batch
20 or 100 calls; real/dictionary cases use one encode per round. All complete
input/native/reference wire identities and previous settings/work counters
agree. Formal timers have no simultaneous compiler or separate validation job.

| Real-input scope | Strategy | Geometric paired time ratio | Faster row medians |
| --- | --- | ---: | ---: |
| 4 KiB, twelve sources | btopt | 0.95629 | 11/12 |
| 64 KiB, twelve sources | btopt | 0.97523 | 8/12 |
| 128 KiB, twelve sources | btopt | 0.97426 | 7/12 |
| 4 KiB, twelve sources | btultra2 | 0.95705 | 11/12 |
| 64 KiB, twelve sources | btultra2 | 0.97653 | 7/12 |
| 128 KiB, twelve sources | btultra2 | 0.96941 | 7/12 |
| 1 MiB, three sources | btultra2 | 0.98814 | 1/3 |

Per-row ratios are medians of paired candidate/baseline process times. Their
quotients need not equal independent median quotients. Larger real groups
improve about 2.3–3.1%; small real groups improve about 4.3–4.4%. The three
multi-block inputs improve 1.2% geometrically, but only Mozilla improves
individually. The [row CSV](frontier-choice-price-20261103.csv) preserves every
row, count and weaker result.

Weaker real medians include SAO 128 KiB btultra2 1.02646, MR 128 KiB btopt
1.02438, X-ray 128 KiB btultra2 1.02089 and Dickens 1 MiB btultra2 1.01843.
Trained dictionary time is 0.98551. Periodic controls are 1.00200/0.99946
for btopt/btultra2, random controls 0.99203/0.98972, and repetitive controls
0.85227/0.87458. All three synthetic groups have zero prepared replays, so
their point gains cannot be attributed to saved choice prices. No universal
benefit or statistical-significance claim follows.

One diagnostic call per configuration records 77,407,333 unchanged price
evaluations. Of these, 3,856,868 successfully prepare a choice, 48,848,798
reuse it and 24,701,667 retain full pricing. These are actual diagnostic work
counts, not samples of ordinary stage latency. Parser working-memory profile
peaks remain identical; stack/RSS and competitor memory ranking are separate.

The distinct current-source reference epoch gives btultra2 time ratios
3.02637/3.06785 on twelve 64/128 KiB sources and 4.50305 on the three actual
1 MiB inputs, at size ratios 1.00480/1.00514/0.99280. Earlier epochs and
internal gains are not multiplied into these direct comparisons.

Seven longer alternating pairs retain five rounds of three real/dictionary
encodes, or fifty control encodes, per process. All 112 successful processes
preserve wires, settings and previous counters:

| Input, btultra2 | Median paired ratio | Geometric paired ratio | Wins |
| --- | ---: | ---: | ---: |
| Dickens 64 KiB | 1.01581 | 1.01938 | 0/7 |
| Mozilla 64 KiB | 0.94354 | 0.94366 | 7/7 |
| MR 64 KiB | 1.00864 | 1.00477 | 1/7 |
| Mozilla 1 MiB | 0.94531 | 0.94250 | 7/7 |
| MR 1 MiB | 1.01209 | 1.00964 | 1/7 |
| Trained dictionary | 0.98604 | 0.98704 | 6/7 |
| Random 4 KiB | 0.99330 | 0.99352 | 6/7 |
| Repetitive 4 KiB | 0.85031 | 0.85574 | 7/7 |

Mozilla improves about 5.5–5.6% in the longer median comparison; Dickens and
MR retain individual regressions. First-edge preparation and code placement
still have costs on lower-reuse shapes. These negative rows are not hidden
by the broad geometric means or traded away by changing search/output policy.

Five further alternating pairs verify forty processes on weaker real rows.
Median paired ratios are SAO 128 KiB btultra2 1.00712, MR 128 KiB btopt
1.01899, X-ray 128 KiB btultra2 1.01464 and Dickens 1 MiB btultra2 1.00994.
These inputs retain about 0.7–1.9% slower latency in longer comparisons. The
overall gain has a clear lower-reuse limitation; improving first-edge cost
and remaining matching/model work remains necessary.

```sh
python3 zig-out/zstd-frontier-choice-20261103/compare.py \
  --scope matrix --sweeps 3 --candidate bench-final --output matrix-final
python3 zig-out/zstd-frontier-choice-20261103/long.py bench-final
python3 zig-out/zstd-frontier-choice-20261103/long-weak.py bench-final
zig build -j2 test-zstd -Doptimize=ReleaseSafe --summary all -- --test-timeout 900s
zig build -j4 check check-wasm --summary all
zig build test-zstd-hq-search-wasm --summary all
```

Run CPU2 measurement scripts sequentially. `build-variant.py` records exact
compiler arguments and source/object hashes; replay against the saved source
archive. `archive.py` binds complete raw rounds, executed binaries and test
logs with `SHA256SUMS`.

| Binding | SHA-256 |
| --- | --- |
| Final benchmark | `0314a2b99985bf9001026aa5fc496fd39f997d4bd0649fde711742f2deaea39d` |
| Final matrix | `64815438972e18577a10c73749b3ea5e044fd3ab4077555da47cb3dbd7af93a8` |
