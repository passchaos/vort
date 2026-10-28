# Exact periodic Bzip2 BWT expansion

Date: 2026-10-29. Zig 0.16.0, Linux x86-64, Intel Core i7-10700K.

The forward BWT now recognizes exact repeated blocks and transforms their
primitive base once, rather than sorting all repeated rotations through every
doubling pass. Each base BWT byte expands to adjacent copies, with the exact
old stable tie rank for the original pointer. Standard encoded output stays
byte-identical, including under all three Huffman strategies.

This improves a core sorting/memory path. It does not change Huffman settings,
compression ratio, RLE1 boundaries, checksums or caller-owned progress.
The prior unique-class stop remains the generic sorting termination rule.

## Exact-order invariant and bounds

For input length n, least whole-string period p dividing n and repetition
count r=n/p, let S=2^ceil(log2(n))-1. Stable prefix doubling orders identical
complete rotations by `(index+S) mod n`. Every equivalence class corresponds
to one distinct rotation of the primitive base. Its preceding byte is the
same for all r class members; therefore each base BWT byte repeats r times.
The original class has residue zero, giving:

```text
original_pointer = base.original_pointer*r + (floor(S/p) mod r)
```

This is the full input's S. Other residues need a carry in `floor((S+a)/p)`
when reconstructing the entire index order; the emitted bytes and origin use
the stated formula. Prefix periods such as 2 for `ababa` are insufficient:
KMP supplies the least candidate and it must divide the whole n.
For n<=900000, the power is at most1048576 and the pointer at most n-1.
The primitive base cannot recurse into a shorter whole period, so the transform
has at most two active levels.

`src/bzip2/bwt_period.zig` separates conservative sampling, KMP and tie-rank
arithmetic from the existing sorter. The first eventual `u32` order array
serves as prefix scratch. Obvious primitive inputs skip the O(n) pass: proper
divisors and five cyclic equalities admit a candidate only when all samples
match. Every true period passes those equalities; false positives still need
KMP/divisibility validation. The precheck costs O(sqrt(n)+tau(n)), at most948
outer iterations for the block limit, with no general false-positive-rate
claim. Inputs shorter than16 use the generic path to avoid extra allocations.

The independent order model validates88626 inputs and its per-stage modular
tie invariant; a separate sampling model checks88572 strings, no false
negative for a proper period and1122 harmless false positives before KMP.
That model has no minimum-length performance gate; production tests separately
exercise the chosen16-byte gate. [Proof sources and identities](data/bzip2-bwt-periodic-20261029/proofs.json)
retain the mathematical argument and actual model executions.

## Requested heap and ownership

Generic sorting retains its six allocation sizes/order. The periodic path
holds a4n-byte prefix array, computes one primitive transform and allocates
the final n-byte output: eight allocations, all unwound on failure.
For a primitive base, requested temporary heap is:

```text
base_peak = 17p + sizeof(usize)*max(p,256)
period_peak = max(4n+base_peak, 5n+p)
generic_peak = 17n + sizeof(usize)*max(n,256)
```

The n-byte output and p-byte base coexist only during expansion; primitive
sort scratch has already been released. Measurements below concern this BWT
function's requested heap, excluding caller input, allocator bookkeeping,
stack, RSS and other encoder storage.

| n | p | Generic bytes on x86-64 | Periodic bytes |
| ---: | ---: | ---: | ---: |
| 65536 | 1 | 1638400 | 327681 |
| 65536 | 4 | 1638400 | 327684 |
| 900000 | 1 | 22500000 | 4500001 |
| 900000 | 4 | 22500000 | 4500004 |
| 900000 | 450000 | 22500000 | 14850000 |

Small primitive bases require the minimum256-element count array, accounted
for in the formula. The largest proper period is n/2 and exercises a larger
base transform plus many two-byte output spans. No libbz2 memory comparison
or industry-wide memory leadership is inferred.

## Native exact-output measurement

The final matrix includes31 inputs, raw BWT plus fast/balanced/ratio complete
encoding, two source variants and two reversed-order repeats. Each call
retains five samples of one iteration:496 calls /2480 raw rows /124 summaries.
The baseline is Git `1b0a0d2d2167886aa7d5f655fa765d99a6a15f3a`, using its
production unique-class BWT kernel rather than the older full-doubling kernel.
Both native programs are rebuilt from recorded sources with identical Zig
ReleaseFast/libc linkage and target features. Compiler, executable, source,
input and output hashes are retained.

Native awake-clock timing includes allocation, transform/complete encode,
sampled output consumption and free. I/O, hashes, exact BWT preflight and full
libbz2 decode happen outside timing. Preflight retains two raw BWT outputs and
an encoded output for the encode scopes; these warm the allocating APIs.
The same strategy and block size are used in both variants, and every output
hash/size/origin matches across them and repeats. All372 complete encoding-call
outputs independently decode through Python's linked libbz2 1.0.8.

The probe runs as one codec thread on CPU2. The background frozen-root test
was observed on CPU2 in the first exploratory epoch. For the entire final
matrix its existing/future threads exclude CPU2 and sibling10; the previous
CPU masks are restored after timing. [Affinity record](data/bzip2-bwt-periodic-20261029/background-affinity.json)
contains the before/temporary/restored masks and timestamps. Ordinary remaining
host load is recorded; this is not a fully idle-host claim.

Speed is baseline median divided by current median across the ten samples
per input/scope/variant. Values below1 mean lower throughput / longer time.

| Input | Bytes | Raw BWT speed | Fast encode | Balanced encode | Ratio encode |
| --- | ---: | ---: | ---: | ---: | ---: |
| unique256 | 256 | 0.937x | 0.967x | 1.012x | 0.993x |
| random16k | 16384 | 0.998x | 1.002x | 0.977x | 0.999x |
| random64k | 65536 | 0.997x | 1.004x | 1.030x | 0.998x |
| random900k | 900000 | 0.994x | 1.013x | 0.997x | 1.000x |
| source | 9473 | 1.043x | 0.990x | 0.967x | 0.997x |
| json64k | 65536 | 1.035x | 0.995x | 1.001x | 0.989x |
| periodic64k | 65536 | 66.263x | 19.492x | 19.458x | 19.339x |
| periodic900k | 900000 | 84.087x | 24.200x | 24.124x | 24.114x |
| nearly_periodic64k | 65536 | 1.015x | 0.999x | 1.005x | 1.005x |
| random899k | 899000 | 1.000x | 1.008x | 1.000x | 1.002x |
| double_large_base | 900000 | 20.753x | 8.858x | 7.917x | 5.679x |
| period257 | 899757 | 102.614x | 2.189x | 2.181x | 2.189x |
| period3_nonpower | 65535 | 67.111x | 23.138x | 22.838x | 22.689x |
| all_same2 | 2 | 0.951x | 1.047x | 1.006x | 0.985x |
| all_same3 | 3 | 0.974x | 1.005x | 1.032x | 0.965x |
| all_same5 | 5 | 1.003x | 1.025x | 1.084x | 0.992x |
| all_same16 | 16 | 1.719x | 0.959x | 0.965x | 0.962x |
| all_same64 | 64 | 4.780x | 1.031x | 0.948x | 0.957x |
| all_same256 | 256 | 14.321x | 1.008x | 1.004x | 1.013x |
| all_same1024 | 1024 | 32.283x | 1.018x | 1.004x | 1.006x |
| all_same65536 | 65536 | 72.887x | 0.987x | 0.976x | 0.975x |
| all_same900000 | 900000 | 91.369x | 0.971x | 0.983x | 0.967x |
| small_period4_16 | 16 | 1.404x | 1.082x | 1.089x | 1.115x |
| small_period4_64 | 64 | 4.200x | 1.586x | 1.541x | 1.566x |
| small_period4_256 | 256 | 13.140x | 3.565x | 3.552x | 3.477x |
| small_period4_1024 | 1024 | 28.182x | 7.772x | 8.746x | 7.738x |
| nondividing5 | 5 | 0.986x | 1.027x | 1.005x | 0.998x |
| nondividing257 | 257 | 1.025x | 0.978x | 1.006x | 1.021x |
| near_period900k | 900000 | 1.007x | 1.009x | 1.011x | 1.011x |
| common_prefix900k | 900000 | 1.052x | 0.985x | 0.991x | 0.987x |
| rle_whole_period | 898730 | 92.705x | 1.892x | 1.892x | 1.980x |

The `abac`64KiB/900000-byte inputs improve complete encoding about19.3...19.5x
and24.1...24.2x. A450000-byte primitive base repeated twice improves raw BWT
20.75x and complete encoding5.68...8.86x. Random and near-periodic controls
remain close to old complete-encoding time, with mixed small deviations;
unique256 raw BWT is about6.3% slower in this run. Microsecond/small percentage
rows are observations, not stable leadership claims.

Plain long runs are first shortened by RLE1. A900000-byte `A` input leaves a
nonperiodic tail in its transformed RLE block, so its complete encoding sees
little gain even though raw BWT is much faster. `rle_whole_period` uses an
exact multiple of259 input bytes, leaving a repeated RLE base and improving
complete encoding about1.89...1.98x. These scopes are kept distinct.

[Final raw evidence](data/bzip2-bwt-periodic-20261029/filtered.json) passes all
identity, consumption, deterministic output and independent-decode checks.
[The direct KMP prototype](data/bzip2-bwt-periodic-20261029/unfiltered.json)
contains480 calls /1440 rows, generic/tiny regressions and initial background
CPU overlap; it is exploratory. Its exact source delta/new files are preserved
with [reconstruction metadata](data/bzip2-bwt-periodic-20261029/unfiltered-source.json).
The production precheck/minimum threshold reduces its demonstrated costs.

## Validation and reproduction

```sh
python3 tools/bzip2/bwt_campaign.py \
  --current zig-out/bin/vort-bzip2-bwt-bench \
  --baseline-commit 1b0a0d2d2167886aa7d5f655fa765d99a6a15f3a \
  --compare-baseline-bwt --period-cases --strategies fast balanced ratio \
  --cpu 2 --iterations 1 --samples 5 --repeats 2 \
  --report /tmp/bzip2-period.json
zig build -j2 test-bzip2 -Doptimize=ReleaseFast
zig build -j2 test-bzip2 run-bzip2-diff
zig build -j2 test-bzip2-stream-consumers run-bzip2-stream-contract-diff \
  -Doptimize=ReleaseFast
zig test src/bzip2.zig -target x86-linux-musl -OReleaseFast \
  --test-filter 'Bzip2 periodic BWT'
zig build -j2 check check-wasm
```

The six new test groups compare9840 tiny generic inputs and9840 repeated
16...21-byte optimized inputs with frozen full doubling and independent LF
recovery. They verify non-power-of-two/divisibility controls, origin tie ranks,
all six/eight allocation failure points, exact allocation order/sizes,
preallocation rejection and the five measured large heap cases. Conservative
filter checks include a deliberate sampled false positive that KMP rejects.
Actual x86-musl execution also passes the six groups plus the module import
aggregator, respecting32-bit `usize` heap accounting.

Current Debug/ReleaseFast Bzip2 suites each pass80 tests. ReleaseFast archive
consumers pass95, the independent stream-contract campaign passes92 cases,
and Debug CLI/Python bz2 bidirectional/legacy/concatenated checks and CLI help
pass. Actual32-bit x86-musl runs pass all six periodic groups plus the import
aggregator. Current compilation/Wasm returns exit0 with211/211 steps.
[Validation logs](data/bzip2-bwt-periodic-20261029/validation.json) preserve
observed exit codes, normalized/raw hashes and code identity.

Post-rebase Bzip2 80 and independent contract92 pass again with exit0;
Wasm compilation and CLI help also pass.

The previous Huffman frozen source (commit1fe1eda4) completes the full tests
with5046 passed / two skipped and exit0. A clean detached checkout is then
advanced to periodic feature commit25fdbcc8 and starts a new full test gate.
That newer session remains running; no complete-periodic-source full-test pass
is assigned. The two epochs and their source identities stay separate.

Continue refining primitive/tiny overhead, broader real-file memory/throughput
comparisons and portable accelerators. The ten-format functionality/performance
objective remains open; this exact periodic slice proves a narrower progress
increment only.
