# Decode first-edge price components once, 2026-11-03

The local-frontier first edge now uses one full LL/ML/OF symbol decoding to
obtain its sequence total and literal/match components. Previously it priced
the complete sequence, decoded the same LL again to close the unfinished
literal run, and decoded the same ML again to prepare the LL/OF base.
`sequenceCosts` exposes those components while retaining the original total
expression and LL→ML→OF validation order. The existing `sequencePrice` body
and later-edge replay implementation remain independent and unchanged.

A successful complete sequence already proves its LL is real, at most 131071.
Its literal component therefore equals the previous virtual-capable LL helper
at that length. LL131072 still fails before ML/OF validation; trailing literal
handling retains its separate virtual clamp. Valid immutable model prices bound
the new components at 20480 and the total at 71424, so component calculations
do not introduce new arithmetic errors.

The first edge still admits its quota, records work, validates the full price,
checks `node.cost−literal`, checks the sequence addition, calculates LL0 and
checks final cost before publishing a preparation. No error check, candidate,
length, repeat alias, insertion tie or quota prefix is removed. There is no
new allocation or persistent state. The executable first helper shrinks from
1255 to 922 bytes; replay and interval code sizes remain unchanged. Code size
is a mechanism observation, not a throughput measurement.

## Independent validation

Three valid price models cover 1983 component comparisons: all LL/ML/OF
boundaries, zero/maximum prices, long-offset penalties, twelve strategy-rounding
cases, invalid values and immutable model fields. Total matches both the frozen
old implementation and the existing full-price function; literal/match terms
match independently decoded old symbols. Comptime use requires no allocator.

The frozen original first/replay oracle adds short ML3…10, all LL buckets,
first-only, one replay and failed first followed by a fresh attempt. Its 15662
first calls and 15218 replays include 7804 error observations, with complete
nodes, counters, quota/publication state and immutable inputs compared. The
previous 1463-interval/1294-quota-prefix oracle and 36 synthetic plans continue
checking every committed node, exact errors and independent content replay.

The unified root filter passes 26 tests in ReleaseSafe. Actual x8632 ReleaseSafe
and WASI ReleaseFast also pass 26, including the same price/error oracles. The
public HQ Wasm gate executes default local-optimal, quota/retry and preserved
beam safeguards with all seven build steps successful. Remaining complete
family/build outcomes and final timing are bound separately to the fixed source.
The complete native ReleaseSafe Zstd suite passes 1269/1269 with exit zero.
Unified native Debug/ReleaseFast frontier filters each pass 26 tests too.
The complete default native/Wasm build gate passes 212/212 steps with exit zero.
Formal timers begin only after every original compiler/validation job finishes.

## Evidence scope

Baseline is the preceding shipping commit `f97403c0`. The initial 28-case
selected-input screen verifies 168 processes, with unchanged complete wires,
requested parameters and every profile counter, including the three preparation
counters. Its real-input geometric time ratio is 0.99322, with stronger 1 MiB
points and retained individual regressions. It is a candidate screen, not final
full-corpus evidence.

Artifacts under `zig-out/zstd-first-components-20261103` retain the pristine
baseline source, pinned objects, before/after build identities, independent
oracles, raw timing and executed native/Wasm outputs. Timed work uses the same
public allocating native-frame API and complete frame release. Input setup,
hashes, diagnostic encoding and both decoder directions are outside timers.
Final ordinary campaigns wait for compiler/verification jobs to finish.

The host is i7-10700K, one codec thread pinned to CPU2, Zig0.16.0 LLVM
ReleaseFast, GNU x86-64, `skylake+pku+sgx`. Reference libzstd1.6.0 is the pinned
clean `01b7154f` local build, object SHA
`c76f4c4457df67a5e0c7bb6bb4f58b9857cf4f2cdd7925bfb9345daac4e6b83e`.
Requested btopt/btultra2, window17, depth64, nice64, minimum3, content/checksum
and worker controls agree. Reference unspecified hash/chain values keep level3
defaults; algorithms and actual search work remain different.

The full Deflate/Zstd/Brotli industry-best objective remains active. Component
reuse addresses first-edge work; broader matching/model, full-file/dictionary/
streaming, resource and platform improvements remain required.

## Final ordinary matrix

Three alternating sweeps cover twelve Silesia sources at 4/64/128 KiB with
btopt/btultra2, three real 1 MiB multi-block inputs, a trained dictionary and
periodic/random/repetitive controls: 82 configurations, 492 processes and five
raw timing rounds per process. Real/dictionary rounds encode once; periodic
and random batch twenty calls, repetition one hundred. Every input/native/
reference wire hash, requested setting and profile field matches the baseline.
That includes the previous preparation/replay counters and parser working
memory peaks. Timers run after all compiler and independent test jobs finish.

| Real scope | Strategy | Geometric paired time ratio | Faster row medians |
| --- | --- | ---: | ---: |
| Twelve 4 KiB files | btopt | 0.99345 | 9/12 |
| Twelve 64 KiB files | btopt | 0.99550 | 9/12 |
| Twelve 128 KiB files | btopt | 0.99633 | 8/12 |
| Twelve 4 KiB files | btultra2 | 0.99134 | 11/12 |
| Twelve 64 KiB files | btultra2 | 0.99498 | 8/12 |
| Twelve 128 KiB files | btultra2 | 0.99912 | 8/12 |
| Three 1 MiB files | btultra2 | 0.99881 | 2/3 |

Small-file group latency improves about 0.65–0.87%; 64 KiB groups about
0.45–0.50%. Larger groups are near neutral to modestly better. These are
geometric means of per-row median paired process ratios, not quotients of
independent medians. The [CSV](first-price-components-20261103.csv) retains
all raw-derived row medians, wins and unchanged work counts.

Weaker real rows include OOOffice 4 KiB btopt 1.01789, OOOffice 128 KiB
btultra2 1.01579, SAO 128 KiB btopt 1.01512 and MR 64 KiB btopt 1.01029.
Trained dictionary ratio is 0.99612. Periodic btopt/btultra2 ratios are
1.01194/0.99845, random 1.00862/1.00808 and repetition 0.98713/1.00041.
Those synthetic groups have zero preparation/replay work and their variation
cannot be attributed to removed first-edge symbol decoding. Negative controls
remain visible; the increment does not establish an input-independent win.

The distinct current-source btultra2 reference time ratios are
3.01224/3.06648/4.49712 for twelve 64/128 KiB and three 1 MiB inputs, at
unchanged size ratios 1.00480/1.00514/0.99280. The preceding epoch's gains
are not multiplied into this independent reference comparison.

Seven longer alternating pairs preserve complete wires/settings/counters in
112 processes. Real/dictionary rounds encode three times; controls fifty.

| Input, btultra2 | Median paired ratio | Geometric paired ratio | Wins |
| --- | ---: | ---: | ---: |
| Dickens 64 KiB | 1.00034 | 1.01158 | 3/7 |
| Mozilla 64 KiB | 0.99832 | 0.99590 | 5/7 |
| MR 64 KiB | 1.01351 | 1.00788 | 3/7 |
| Mozilla 1 MiB | 0.99826 | 0.99650 | 6/7 |
| MR 1 MiB | 0.99883 | 0.99880 | 4/7 |
| Trained dictionary | 0.99246 | 0.99555 | 5/7 |
| Random 4 KiB | 1.01167 | 1.01095 | 2/7 |
| Repetitive 4 KiB | 0.99498 | 0.99828 | 4/7 |

The longer target comparisons are mostly near neutral. MR 64 KiB retains
about 1.35% slower median latency and the zero-price-work random control
about 1.17%. First-function size and source-level sharing do not establish a
speedup on every input. Wider matching/model work remains a much larger gap.

Five further pairs verify forty processes on the matrix's weaker rows. Median
ratios are OOOffice 4 KiB btopt 0.99931, OOOffice 128 KiB btultra2 0.99702,
SAO 128 KiB btopt 1.00117 and MR 64 KiB btopt 1.00203. Their larger initial
regressions do not persist in that follow-up, but near-neutral negative points
remain. The small group gain is reported alongside the longer negative control
results, not as general throughput leadership.

```sh
python3 zig-out/zstd-first-components-20261103/compare.py \
  --scope matrix --sweeps 3 --candidate bench-final --output matrix-final
python3 zig-out/zstd-first-components-20261103/long.py bench-final
python3 zig-out/zstd-first-components-20261103/long-weak.py bench-final
zig build -j2 test-zstd -Doptimize=ReleaseSafe --summary all -- --test-timeout 900s
zig build -j4 check check-wasm --summary all
zig build test-zstd-hq-search-wasm --summary all
```

Execute measurement scripts sequentially on CPU2. The source archive and
build JSON retain exact compiler/object arguments. `archive.py` binds inputs,
raw records, executed binaries and validation with `SHA256SUMS`.

| Binding | SHA-256 |
| --- | --- |
| Baseline benchmark | `0314a2b99985bf9001026aa5fc496fd39f997d4bd0649fde711742f2deaea39d` |
| Final benchmark | `adb2793f961b2a7191b9f08f3a39fb7a0cb136d622de276e73c3ff2d8969f577` |
| Final matrix | `a5f4fdba90d98bacad2d347d867be1ab3a67ff9157f7cd65ee68574d11937b7e` |
