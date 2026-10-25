# Zstd multi-duplicate work and medium Huffman alphabets

Date: 2026-10-25. Baseline: `c56c8255`, following the
[exact literal-cost increment](zstd-exact-literal-cost.md). The objective of
industry-best functionality, ratio, throughput and memory remains incomplete.

## Measured work

The unindexed XML and MR 64 KiB candidate stages each select 128 bootstrap
matches. A diagnostic built with Zig 0.16.0 ReleaseFast on the i7-10700K records:

| Work | XML | MR |
| --- | ---: | ---: |
| Exact cost queries / Huffman plans | 1,473,017 | 1,039,932 |
| Tree serializations | 1,087 | 23,960 |
| Tree cache hits | 1,471,930 | 1,015,972 |
| Histogram source bytes scanned | 49,266,861 | 35,192,481 |
| Stream frequency/bit-length products | 429,549,553 | 316,925,966 |

Tree serialization already hits in 99.926% and 97.696% of these queries. This
points to repeatedly planning Huffman code lengths rather than repeatedly
serializing the same tree. Per-stream active counts cannot be used as total
alphabet sizes: the complete XML/source input histograms contain 77/88 active
symbols, whereas MR contains 239.

## Rejected exact-frequency experiment

An experiment retained the complete previous 256-symbol frequency vector and
reused its successful tree entry only on exact equality. It passed 23 focused
tests in native Debug, native ReleaseFast and 32-bit x86 ReleaseFast, including
an independent byte oracle where equal total frequencies still produce
different rounded four-stream costs. Those functional results are evidence for
the experiment, not the final implementation.

Actual candidate-stage frequency reuse was only 65/1,473,017 XML queries and
665/1,039,932 MR queries (0.0044% and 0.0639%). The same candidate bytes were
preserved, but the negligible avoided work does not justify an additional
1040-byte resident key and a full comparison on every query. The experiment
was withdrawn before a production commit. Single instrumented durations are
retained without assigning a stable speedup or regression ranking.

## Diagnostic tool

`zig build run-zstd-multi-duplicate-profile -- FILE...` accepts exact file
lengths 65536...131072 and writes `vort.zstd.multi-duplicate-work.v1` JSON.
Each row records input and candidate-output length/SHA-256, finder/match
counts, histogram scans, actual Huffman builder calls, tree lookups and symbol
products. Its provenance includes executable SHA-256, command, build mode,
target CPU, runtime CPU and affinity.

The diagnostic evaluates the unindexed candidate directly. Normal frame
encoding retains the complete selector and its fallback rules. Outer profile
branches are disabled at compile time for product calls; existing Cache and
Histogram Work accounting remains in source. Instrumented elapsed time is
not a public-API throughput ranking or proof of zero accounting overhead.
`cache_state_bytes` describes the fixed literal-cost cache, excluding other
stack frames, caller buffers, allocator bookkeeping and process RSS.

## Medium-alphabet kernel

The kernel specializes `n=256`, `max_bits=11` and 65...127 active symbols.
It keeps the back-reference package-merge algorithm and creation-order ties,
with `workspace_n=128` and the caller's sorted active symbols. Original byte
symbols stay in the nodes and the result remains `[256]u4`; no compact
frequency copy or final symbol-remapping pass is needed. Other callers retain
their existing workspace and frequency scan, and the 128+ dense path retains
its existing dispatch.

The core node, leaf, frontier, pair and multiplicity arrays have declared
capacities of 71,168 bytes at width 256 and 35,584 bytes at width 128. The
256-byte output vector is separate. With 127 active symbols and eleven bits,
at most 1,387 nodes fit in 1,920 slots; the frontier has at most 253 entries in
256 slots and the pair list at most 126 in 128. This is a fixed local-array
capacity result, rather than a requested-heap, whole-stack or RSS comparison.

An independent ELF review follows the actual ReleaseFast encoder path from
`finalizeSmallHuffmanLiteralPlan` through `treeCodeLengthsKnownActive` and the
new medium helper. Accounting for register pushes, stack subtraction and the
inter-function return addresses gives 75,112 bytes for those old frames and
39,240 bytes for the new frames. The new shared caller uses 1,768 bytes rather
than retaining the old 73,576-byte frame; the medium helper uses 35,928 bytes.
This avoids counting the helper in isolation. These are the static allocations
of the named local call chain for the pinned executable, excluding other
callers/callees, input, total process stack, requested heap and RSS. Other build
modes, type instances and CPU targets require their own compiled evidence.

Replacing it with packed package merge would change some code-length vectors,
even when weighted costs are equal. A frozen 65-symbol fixture makes that
distinction explicit; exact old vectors and independent weighted-optimal cost
checks therefore serve different validation purposes.

The named medium-kernel test passes in native Debug, native ReleaseFast and
32-bit x86 ReleaseFast. Each execution checks 65 frequency/bit-limit groups,
including XML/source histograms, active counts 65/66/77/88/96/127, equal weights,
holes/high symbol 255, skewed bounded trees, high u32 frequencies and bit limits
7/8/11/15. Old scanned planning and per-root DAG traversal supply exact-vector
oracles. Full-width packed planning supplies a separate optimal-cost/Kraft
oracle. The helper never imports the parent module through a second route.

The complete native ReleaseFast Zstd family passes 1088/1088 and the complete
build check passes 169/169. CLI help passes its seven-step build/run check.
The diagnostic file smoke independently verifies exact JSON/input/empty-output
identities and acceptance of 65536/131072 bytes, rejecting 65535/131073 before
encoding. The diagnostic contracts are included in the complete family.
After `git pull --rebase origin main`, the medium-kernel test passes again and
the twelve-test diagnostic filter passes again. Source manifests remain
unchanged across the pull and these checks.

## Public-API measurements

Two matched level-3 public-encoder controls use the same frozen 64 KiB inputs,
default complete level policy, i7-10700K, ReleaseFast, target
`skylake+pku+sgx`, CPU8 and the explicit local libzstd 1.6.0 file from checkout
`01b7154f`. There are five alternating Vort/reference rounds in each of two
separate version processes. The old run precedes the completed compilation and
checks; the new run follows them. No compiler process is observed in either
timed run. Source, reference-file and executable identities stay unchanged.

| Input | Baseline Vort median | New Vort median | Version throughput ratio | New-run reference median |
| --- | ---: | ---: | ---: | ---: |
| XML | 12,001.652 ms | 11,838.393 ms | 1.01379x | 0.142591 ms |
| Source code | 5,187.551 ms | 5,045.272 ms | 1.02820x | 0.188274 ms |

These modest point improvements do not establish statistical significance or
competitor throughput leadership. The source input is a frozen Brotli source
file compressed with Zstd. XML remains approximately 83,023 times the reference
duration in this control; the main remaining issue is the number and cost of
exact candidate queries.

A separate one-round fourteen-row screen preserves every previous Vort and
reference frame length and SHA-256, including the two focused controls. It
retains total output 310,437/328,241 bytes and thirteen smaller Vort frames.
Raw rounds, CSV and frozen input identities pass the independent sample gate.
The one-round screen supplies wire/compatibility evidence; it is not promoted
to a stable full-corpus ranking. Explicit reference-file hashes do not prove
the complete dynamic loader dependency closure.

Broader repeated runs, all levels, 1 MiB inputs, incremental APIs, ARM64 and
symmetric competitor memory measurements remain separate work. The
[evidence package](data/zstd-medium-huffman-20261025/artifact-manifest.json)
retains commands, stable source manifests, raw samples, input/reference/executable
identities, compiler-presence observations, tests and disassembled local frames.
