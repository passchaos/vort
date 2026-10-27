# Brotli command/distance preparation reuse

The preferred q8 literal-context group now prepares its ordinary command and
distance frequencies, alphabets, code lengths and Huffman encoders once. Each
literal configuration still prepares its own literal trees and emits its
complete wire. Selection retains the existing candidate order, strict ties,
80% early return and exact byte-length comparison.

The fixed descriptor lives within one immutable command group and allocates
no heap storage. Its key includes command pointer/length, window, distance
parameters, compound dictionary size, initial output position, starting recent
distance ring and both distance-policy flags. This is a borrowed group
descriptor; new groups initialize a new descriptor. Readiness is published
after successful encoder preparation. Exact HQ commands, Large Window,
split/joint plans and final wire-state/model outputs use the original path.
The original 128-command symbol cache keeps its existing bound.

Production enables reuse only for inputs of at least 8 KiB, with clustered
literal-context attempts and recent distances in the ordinary window. The
first experiment enabled it for smaller inputs too; its 4 KiB geometric time
ratio was 1.00218. Adding the input-size gate changes optimization dispatch
without changing the encoding candidates or output policy.

## Ordinary-call measurement

Baseline source is `d5e8e780f4c28f362c64b152e71988a52351667c`. Both versions
use the same frozen benchmark tools, Zig 0.16.0 ReleaseFast native target
`skylake+pku+sgx`, one thread pinned to CPU 2 on an Intel i7-10700K. The corpus
contains 4/16/64 KiB prefixes from all twelve Silesia files. Three process
sweeps reverse version order on the middle sweep. Each report has five
interleaved Vort/reference rounds of three calls, yielding fifteen samples
per version/case; each sample divides its three-call time by three. The table
uses per-case medians followed by a geometric mean across cases.

The local clean Brotli reference is 1.2.0, commit
`558fc647cdaf391228d614ca85f711e02e4e583b`, built with GCC Release
`-O3 -DNDEBUG -march=native`. Both encoders use q8, generic mode and actual
wire lgwin16. Encoding time includes allocation and free. Vort has an untimed
warmup before each primary round; the reference has no explicit warmup.

| Input prefixes | Final/baseline encoding time |
| --- | ---: |
| 4 KiB, 12 cases | 0.994887 |
| 16 KiB, 12 cases | 0.987653 |
| 64 KiB, 12 cases | 0.974206 |
| All 36 cases | **0.985545** |

The combined point is about **1.45% less encoding time**. All input hashes,
wire hashes/lengths and settings agree between versions, between sweeps and
between the initial and gated experiments. The gated candidate/reference
encoding-time ratio is **37.1917**, and its encoded-size ratio is **0.995560**.
These ratios expose the remaining competitor gap. The reference reports hash
the requested canonical library files and their versions; actual loaded
objects and transitive dependencies remain unverified in this tool epoch.

Small points, including the gated 4 KiB result where reuse is disabled, do
not establish statistical significance or isolate a causal saving. The
initial and final experiments ran at different times; their ratios should
not be compared as a controlled estimate of the gate's effect. This milestone
does not establish industry-best performance or general peak stack/memory use.

## Correctness and resource validation

The integration contracts compare independently cached and plain writers
across eight literal configurations, including more than 128 commands and
complex command trees. Complete wires and semantic statistics agree.
Allocation/resize ledgers, twelve failure indices, bounded-output OOM progress,
zero-postfix/zero-direct distance parameters and wrong-key fallback agree.
Focused Debug and ReleaseFast gates each pass 25 tests, including dependency
imports. Public quality/profile contracts additionally cover exact peak and
peak-minus-one limits, cleanup and returned-wire linkage.

Native/Wasm compile checks pass 210 steps. Node planned encoding
interoperability and the literal-context profile gate pass; the existing
public ReleaseFast Wasm gate passes seven steps. The new CI-integrated
`test-br-prepared-command-wasm` passes five steps and compares complete wires
with a compressed frozen baseline. Its actual 64 KiB fixture crosses the
recent-distance and 128-command gates; Zig and Node decode it exactly.
[Wasm correctness evidence](brotli-prepared-command-wasm.md) records the
fixture, wide initial-position key check and frozen rebuild proof.

After pulling `origin/main` with rebase, the focused Debug/ReleaseFast gates
and public q8 profile gate each pass 25/25. Combined compile, actual Wasm
baseline comparison and CLI help checks pass 215/215 steps with exit 0.
The package preserves these terminal logs and tested source hashes. Only
documentation/evidence was amended after this verification.

[The ordinary evidence package](data/brotli-prepared-command-distance-20261028/)
preserves all raw samples/commands, summaries, source epochs, frozen benchmark
tools, the initial source overlay, diagnostic profile rounds and explicit
completion records. Diagnostic profiles retain equal non-time fields and
selection events; their differing CPU affinities exclude performance
comparison. Next, reduce repeated candidate emission while retaining exact
byte arbitration and the established allocation/failure contracts.
