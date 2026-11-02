# Brotli literal interval costs, 2026-11-02

The fixed-grid literal splitter reuses exact Huffman weighted costs for repeated
contiguous intervals within one immutable proposal search. Seven split points
and two outer endpoints require a bounded nine-endpoint cache. Combined,
non-contiguous histograms retain their original scoring. Candidate iteration,
strict ties, thresholds and complete-wire selection remain unchanged.

The large refinement search is separated into
`src/br/encoder/literal_block_split/refinement.zig`. The initial entropy and
exact two-region gates stay in the selector; only accepted searches call the
refinement function. Its cache seeds the two costs already computed by the
exact gate. Endpoint-index lookup also happens after that gate. The cache
contains 672 bytes on x86-64 and makes no allocator calls. It is discarded at
the end of each search, preserving deterministic and independent calls.

## Workload evidence

MR's actual q8 lazy/optimal plans contain 4,277/4,308 emitted literals. Each
admits 17 endpoint pairs and 17 triples after the minimum-region rules. Their
136 contiguous interval requests cover only 27 different intervals, so 109
loop builds repeat prior work. Two seeded gate costs provide additional reuse.
The static request analysis is retained with its input bindings.

A diagnostic baseline profile wraps this exact scorer with an existing nested
stage recorder. MR's two calls take 3.75/4.21 ms in a 56.79 ms profiled call.
Mozilla and Dickens finish their corresponding gates in about 0.23/0.26 ms
combined and largely do not reach the expensive search. Diagnostic clocks are
workload selection evidence, rather than ordinary encoding throughput.

An initial synthetic four-region screen at 3,072–32,768 literals reduced full
scorer latency by 27–33%, with identical proposals. The retained implementation
is assessed by the public encoding comparison below. A merely cached version
showed an approximately 0.8% OSDB early-path regression; outlining refinement
and delaying endpoint-index computation reduced that movement. Those earlier
variants and observations remain in the generated artifact.

In the measured x86-64 binaries, the selector's stack reservation falls from
53,704 to 17,112 bytes. Refinement reserves another 37,000 bytes only when
called. These are disassembly frame reservations, excluding callees and saved
registers; they are not total RSS or an encoder heap claim.

## Ordinary encoding comparison

Baseline source: `b7493f25`. Both executables call the public q8 quality-preset
API through `tools/br/planned_encode_bench.zig`. Settings match: quality 8,
generic mode and actual wire window bits 16. Inputs are the twelve Silesia
sources at 4/16/64 KiB, totaling 36 rows. Three sweeps alternate
baseline/candidate process order and verify all 216 processes.

Each report contains five alternating Vort/reference rounds, with three
encodes per round. The comparison uses each report's median Vort time and
then the median adjacent candidate/baseline ratio across sweeps. This retains
all reported rounds rather than comparing only minimum timings. Input and
both complete compressed-wire hashes must remain identical for every row.

The host is an Intel Core i7-10700K, logical CPU2, one codec thread. Builds use
Zig 0.16.0 ReleaseFast, `x86_64-linux-gnu -mcpu=skylake+pku+sgx`. Reference
libraries are Brotli 1.2.0, clean source
`558fc647cdaf391228d614ca85f711e02e4e583b`, CMake Release,
`-O3 -march=skylake`. Encoder-first loader inspection confirms all three actual
libraries come from the pinned build directory, including common, rather than
mixing the system 1.0.9 library.

| Input size | Twelve-source geometric time ratio |
| --- | ---: |
| 4 KiB | 1.00093 |
| 16 KiB | 1.00008 |
| 64 KiB | 0.99526 |

MR 64 KiB improves to 0.94155 paired latency, with 3/3 wins and its complete
wire unchanged at 15,482 bytes. Thus the gain is workload-dependent; small
input groups stay close to neutral. [All row results](interval-cost-20261102.csv)
retain independent medians and paired ratios, which need not equal a ratio of
the two independently aggregated medians.

Eleven longer pairs at seven encodes per timing round confirm the target and
check two early-screening controls:

| Row | Median paired ratio | Geometric ratio | Wins |
| --- | ---: | ---: | ---: |
| MR 64 KiB | 0.94472 | 0.94441 | 11/11 |
| OSDB 16 KiB | 1.00259 | 1.00095 | 3/11 |
| Reymont 4 KiB | 1.00368 | 1.00397 | 2/11 |

The target improves about 5.5%; the controls retain small sub-half-percent
movement. The current 36-row candidate is still 32.28x reference encoding
latency geometrically, with compressed size 0.99556x reference. This improves
one repeated stage and does not establish broader encoder speed leadership.

## Validation

The independent proposal oracle covers 180 cases, including fragmented insert
spans/gaps, invalid bounds, length limits and UTF8 cutoffs. It compares every
proposal field with the uncached path and independently rebuilds histograms
to verify 130 valid proposals' boundaries, type mapping and savings. All seven
proposal categories are exercised. A positive-saving tie keeps the earliest
split at 1,024, and compile-time evaluation matches runtime results without
an allocator. Selected Debug/ReleaseSafe/ReleaseFast tests pass 20/20.

The full ReleaseSafe Brotli suite passes 1,505 tests, with one skipped and zero
failed. The first combined build's test transport terminated unexpectedly;
running its identical test executable directly passes the entire suite, and
the normal build runner also passes with `--test-timeout 900s`. This retry sets
an explicit test/response limit and preserves all assertions and cases.
The default-mode `check check-wasm` compile gate also passes all 212 steps.
An additional ReleaseSafe whole-library test compilation was still running
when this increment was saved; it is not counted as a completed gate here.

Public q8 complete-wire equality and round trips are checked in every ordinary
benchmark report. The prepared-command Wasm comparison passes with identical
output, including native Node decode. The separate literal-context modes
interop probe passes eight cases against system libbrotli 1.0.9. These are
distinct from the pinned 1.2.0 performance reference.

## Reproduction and bindings

The generated `zig-out/br-interval-cost-20261102` artifact retains reference
build/loader commands, baseline source snapshot, frozen executables, all JSON
rounds, stage diagnostics, input hashes, ordinary/long comparison scripts and
validation logs. The retained matrix driver is `refined-matrix.py`, and the
long driver is `refined-long-controls.py`.

| Binding | SHA-256 |
| --- | --- |
| Baseline executable | `09522a11bd72c9ad7c9758d847533636afe090109d4a155ee2e4ccec35018260` |
| Candidate executable | `98731c55bdfb8f33a35f99ceaf7436f0ad96319bbc9d3b7e92fe90eebb5843b1` |
| Full matrix report | `e0bf4f58c7226d5cdf4c8f8a5b5ddef7b2f226fd9b74ea4c8c7c2a3bf6b9b01c` |
| Reference encoder | `916611262bd0975d4b75e6a19d957de5747eb182f2c36022a459bd21b6e40b6d` |
| Reference decoder | `916a4e22b249bb9b5024ed6d6956431fbcdea31f0cf157474de36c529a961750` |
| Reference common | `d049d028ce0ee836b2f90579b1fba73ac2c8cdde4e2014721eb93c107a399dfb` |

From the repository root, one current-source ordinary report uses the same
library API and matched parameters:

```sh
taskset -c 2 zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux-gnu -Dcpu=skylake+pku+sgx run-br-planned-encode-bench -- \
  --quality 8 --planned-quality=8 --planned-mode=generic \
  --reference-lgwin=16 --reference-mode=generic --iterations 7 --limit 65536 \
  --samples-json zig-out/br-interval-current.json --csv zig-out/br-interval-current.csv \
  --libbrotli-encoder /home/passchaos/project-z/vort/zig-out/br-interval-cost-20261102/reference/libbrotlienc.so.1.2.0 \
  --libbrotli-decoder /home/passchaos/project-z/vort/zig-out/br-interval-cost-20261102/reference/libbrotlidec.so.1.2.0 \
  --libbrotli-common /home/passchaos/project-z/vort/zig-out/br-interval-cost-20261102/reference/libbrotlicommon.so.1.2.0 \
  --path zig-out/br-interval-cost-20261102/corpus/mr-65536
```

Independent command parsing, context search and exact candidate emission remain
the next larger q8 targets. The deflate/zstd/brotli industry-best goal stays
active.
