# Exact adaptive literal preparation, 2026-11-03

Ordinary Brotli adaptive literal candidates now prepare their entropy state
and compute their complete byte length before emission. A candidate that
cannot beat the current wire avoids output allocation and symbol emission.
The candidate search, order and strict byte-length ties remain unchanged.
Preparation and emission share the same alphabets, block code, context map
and command/distance state in a cohesive 195-line module.

This also fixes valid adaptive literal blocks with two, three or four active
symbols. The previous writer supplied zero code lengths for every small
alphabet, while its literal encoder requires real lengths except for a
singleton. The legal insert-only `ABABCDCD` stream, split into `ABAB` and
`CDCD`, therefore returned `CorruptFrame`. Both the generic writer and the
prepared path now use the alphabet's canonical lengths; singleton payloads
still consume zero bits. The old source reproducer passes 20 tests with the
expected old error, and the new oracle checks valid output and decoding.

## Preparation and ownership

The admitted slice uses standard windows 10–24, two to eight literal types,
at most 65,536 commands and 65,536 inserted literals, recent distances, a
complete final frame and no metadata/additional entropy splits or live HQ
outputs. Larger and more complex legal plans retain the generic path.
Unsupported capacity is checked before allocation. Stream position, insert
ranges, plan coverage and every command/distance projection are validated
before comparison, even when the incumbent is tiny.

The count includes the actual generic header serializer, weighted command,
distance and literal costs, all extra bits, every block switch and final byte
alignment. The key binds the borrowed immutable input, commands, split slices
and relevant options. The prepared object owns only its adaptive block code;
two real initialization allocation sites remain. A losing candidate avoids
the output allocation, rather than becoming allocation-free.

Entropy arbitration now uses a small owner module instead of 22 repeated
retention blocks. It borrows the preferred baseline, releases each losing or
replaced owned candidate once, and transfers only a strictly smaller winner.
Equal lengths preserve the baseline or earliest retained candidate. Candidate
configuration continues to depend on the immutable preferred baseline.
Stats are published by the caller only after an owned winner is transferred.

## Actual work and independent validation

Three diagnostic rounds each of MR/Mozilla/Dickens 64 KiB preserve all 168
ordered candidate configurations and exact byte lengths, complete returned
wires and native decoding. Two adaptive literal wire attempts per round
become exact evaluations: MR physical attempts fall 12 to 10, and
Mozilla/Dickens 10 to 8; evaluations rise 12 to 14. Profile clocks are used
only to identify work and do not support ordinary throughput claims.

The real encoder oracle independently checks complete wires, stats,
command/distance/literal/extras/switch costs and Counter/BitWriter headers.
It covers types 2–8, small and complex alphabets, reordered/reused types,
internal and cross-command block switches, zero inserts, more than 128
commands, implicit/direct distances, literal limits, invalid keys, position
overflow and unsupported settings. Owned initialization's two actual OOM
sites and emission's one actual OOM site preserve cleanup, borrowed data and
prior ownership. Public q8 inputs at 8/16/64 KiB actually execute preparation
1/2/2 times and match the original controller's wires, summaries and decode.
ReleaseSafe and ReleaseFast production filters each pass 29 tests.

The independent selection oracle covers 64 choice configurations, 12 fault
frontiers and an active trace case. Debug/ReleaseSafe/ReleaseFast all pass,
including empty owned wires, borrowed baselines, strict ties, repeated take,
idempotent cleanup and failure ownership. These tests compile the real owner.

The full ReleaseSafe Brotli suite passes 1,515 tests with one skipped out of
1,516. Default native/Wasm checks pass 212/212 build steps, and the prepared
command Wasm gate passes all five steps with frozen complete output plus
Zig/Node decoding. CLI help, Zig formatting and whitespace checks pass.

## Ordinary q8 comparison

The final production benchmark calls the public quality API with q8/generic/
actual window16, matching the reference quality, mode and window. Twelve
Silesia sources at 4/16/64 KiB plus random 16/64 KiB and repetitive 64 KiB
controls give 39 rows. Three alternating sweeps verify 234 processes; each
process retains five timing rounds at three encodes per round. Per-row ratios
are the median of paired candidate/baseline times. All complete input and
Vort/reference wire identities match between binaries.

Host: Intel Core i7-10700K, logical CPU2, one codec thread. Vort uses Zig
0.16.0 LLVM ReleaseFast, GNU x86-64, `skylake+pku+sgx`. Reference Brotli 1.2.0
is clean source `558fc647cdaf391228d614ca85f711e02e4e583b`, CMake Release,
`-O3 -march=skylake`. Encoder-first loader inspection of the pinned closure
confirms all three Brotli libraries come from the reference directory.
This is a separate probe; ordinary sample metadata alone hashes the requested
files without inspecting the actual loaded objects. The harness warms Vort
before its rounds, retains the reference's documented lifecycle and times
encoding allocation/free. File loading and full-content checks are outside
the interval.

| Real-input scope | Geometric paired time ratio | Faster row medians |
| --- | ---: | ---: |
| 4 KiB | 0.99723 | 8/12 |
| 16 KiB | 0.99477 | 9/12 |
| 64 KiB | 0.97382 | 10/12 |
| All 36 real inputs | 0.98855 | 27/36 |

Real-input geometric latency improves about 1.14%, including about 2.62%
at 64 KiB. Individual weaker rows remain: SAO 64 KiB 1.00722, Dickens
16 KiB 1.00684 and OSDB 16 KiB 1.00605. Random 16/64 KiB ratios are
0.99451/1.00187 and the repetitive control is 0.99589. The
[row CSV](adaptive-literal-count-20261103.csv) retains all medians and wins;
their paired statistic need not equal the quotient of independent medians.

Eleven longer alternating pairs at seven encodes per round verify another
132 processes and preserve every complete wire identity:

| Input | Median paired ratio | Geometric paired ratio | Wins |
| --- | ---: | ---: | ---: |
| Mozilla 64 KiB | 0.97217 | 0.96486 | 11/11 |
| MR 64 KiB | 0.97289 | 0.97096 | 10/11 |
| Dickens 64 KiB | 0.96045 | 0.95027 | 11/11 |
| Dickens 4 KiB | 0.99509 | 0.99527 | 9/11 |
| NCI 64 KiB | 1.00096 | 0.99945 | 5/11 |
| Repetitive 64 KiB | 0.99671 | 0.99913 | 7/11 |

The three targets improve about 2.7–4.0% in this longer median comparison.
NCI and the repetitive control remain near neutral; the matrix's weaker
real-input rows stay visible. The implementation does not claim a speed win
on every input.

The separate final-production reference epoch is 31.35 times Brotli encoding
latency geometrically at size 0.99556 times reference on the 36 real inputs.
Earlier increment gains and reference epochs are not multiplied together.

## Reproduction and bindings

`zig-out/br-adaptive-literal-count-20261103` retains the old bug reproduction,
independent tests, source archive, build identities, ordinary timing records,
profile comparison and validation logs. Baseline codec source is `ec7a9b4a`.
Production source and executable identities are recorded separately from
the earlier candidate matrices, whose executable sections differ. Those
earlier timings are not final production evidence.

```sh
python3 zig-out/br-adaptive-literal-count-20261103/matrix-production.py
python3 zig-out/br-adaptive-literal-count-20261103/long-production.py
python3 zig-out/br-adaptive-literal-count-20261103/compare-profile.py
zig build -j2 test-br -Doptimize=ReleaseSafe --summary all -- --test-timeout 900s
zig build -j4 check check-wasm --summary all
zig build test-br-prepared-command-wasm --summary all
```

| Binding | SHA-256 |
| --- | --- |
| Baseline benchmark | `5f078f9022e9706225e246e6f207f4e9644c54ffa8703a07a23dcc6a4a586a6f` |
| Production benchmark | `69a566fa84c6ea3b0a29be88a4cbfffd2c132733448939ed8809a1ff1f676bd9` |
| Production matrix | `850ea645445cfb7551b9dcc2a2e145c3b4e77c51c173a0a3d3890da47874a94a` |
| Production long comparison | `2092fde085db1e13fc98d97e6ccc2f90ca1f78ac2a0171521a49f588b78d9ff6` |

The latest three-codec [gap assessment](../industry-gap-current-20261103.md)
keeps high-quality ratio/speed, full-file, dictionary/streaming, memory and
platform work open. The industry-best goal is not completed by this increment.
