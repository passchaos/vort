# Small no-low FSE tables, 2026-11-02

Zstd sequence tables with 64 or 128 states, at most 53 normalized symbols and
no low-probability tail now use a compact mapped-table builder. The normalized
count parser validates the wire first. Other shapes continue through the
generic builder; the existing 256-state specialization remains separate.

The specialized builder uses modular spreading followed by ascending state
mapping, retaining 128 symbol bytes and 53 next-state counters. Its declared
scratch is 234 bytes, versus 1,024 bytes in the generic builder. This is a
comparison of builder scratch, rather than total decoder heap or RSS. There
is no allocation and typed entry writes preserve layout and endianness.

## Workload selection

The exact libzstd 1.6.0 Mozilla first-1-MiB level-3 frame has 61 no-low
64-state tables and 15 no-low 128-state tables. A more detailed inspection
ruled out extending the existing dominant-fill optimization:

| States | Kind | Tables | Serialized symbol count | Active symbols | Largest probability |
| ---: | --- | ---: | --- | --- | ---: |
| 64 | LL | 20 | 29–31 | 15–23 | 30/64 |
| 64 | OF | 35 | 17–20 | 8–16 | 26/64 |
| 64 | ML | 6 | 25–32 | 19–25 | 15/64 |
| 128 | ML | 15 | 34–45 | 19–29 | 29/128 |

None reaches the required 3/4 dominant probability. The retained optimization
instead removes generic low-tail handling and reduces scratch capacity.

## End-to-end results

Both sides use the existing `tools/zstd/reference_bench.zig` public API
harness. Baseline codec source is `86ca5489`; Zig 0.16.0 ReleaseFast targets
`x86_64-linux-gnu -mcpu=skylake+pku+sgx`. Runs use logical CPU2 on an Intel
Core i7-10700K, one decoding thread, and input/output address offset 1 modulo
128. The reference is native libzstd 1.6.0, clean source
`01b7154f1172432f8abe9b3bb9909e14a1176b7d`, GCC 11.4.0 `-O3 -march=skylake`
with its x86 assembly enabled.

The harness alternates Vort/reference timing five times per process and retains
the minimum for each. Loading, output allocation and full-content verification
are outside the decode interval. Additional allocation/inspection rows are
retained separately. The outer comparison alternates baseline/candidate order.

Five sweeps cover twelve Silesia sources, 64 KiB/1 MiB prefixes, levels 3/9,
and one-shot/reusable APIs: 96 rows and 960 verified processes. Every process
verifies complete Vort/reference output and its input/encoded-size binding.
The per-row medians and win counts are in
[the committed CSV](small-no-low-tables-20261102.csv).

| Mozilla 1 MiB level 3 | Baseline ns | Candidate ns | Median paired time ratio | Wins |
| --- | ---: | ---: | ---: | ---: |
| One-shot | 518,701 | 510,052 | 0.98326 | 5/5 |
| Reusable | 520,929 | 509,871 | 0.98937 | 5/5 |

The target improves about 1.67%/1.06%. Group geometric ratios across the broad
matrix range from 0.99759 to 1.00380, so this is a narrow small-table gain,
rather than general corpus leadership. The remaining Mozilla gap to libzstd
is still approximately twofold.

Three 64 KiB one-shot rows initially showed noisy 1.4–2.2% paired regressions.
Fifteen longer pairs with 512 iterations per timing round resolve those
controls and independently confirm the target:

| Row | Median paired time ratio | Geometric time ratio | Wins |
| --- | ---: | ---: | ---: |
| Dickens 64 KiB level 3 | 1.00128 | 1.00328 | 6/15 |
| OSDB 64 KiB level 3 | 0.99333 | 0.99255 | 12/15 |
| XML 64 KiB level 3 | 0.99832 | 0.99770 | 11/15 |
| Mozilla 1 MiB level 3 | 0.98367 | 0.98609 | 14/15 |

Earlier candidates cached mapped entry templates. The branch version measured
1.01290 geometrically with 1/15 wins when selected by the generic builder;
parser admission reduced it to 1.00391, 6/15 wins. A branchless template
version reached 0.99428 with 15/15 wins, but used more scratch and improved less
than the retained compact builder's 0.98221, 15/15 initial screen. Both template
variants were discarded.

## Evidence and reproduction

Generated artifacts reside in `zig-out/zstd-small-fse-20261102`. The original
measured candidate and a rebuild after adding parser tests have identical
bytes in all 23 executable sections; their debug/source metadata differs.

| Binding | SHA-256 |
| --- | --- |
| Baseline binary | `9438994ef4a8a3da5663ef202d06e7ece3bea7aab5312cc6147807cc74833fd4` |
| Measured candidate | `000cb369afa543bf0ab7017c1c76ec07772db84e993d8456a8f9ebbdb8b7d6d7` |
| Native reference library | `1370151720affecc1a9a4a0f3c6257bdd6d504f460a7e78423f77c15523875c9` |
| Input/wire manifest | `580d147612aa0cd664587e88f2c61f7009e27d5b33722e61af1c6750709025ee` |
| Full matrix report | `9d17945b0f01bb08ca812d9f83647a3402bb27f46815cee31e395a82b0641947` |

The artifact contains source snapshots, wrapper aliases, native reference build
argv, `matrix.py`, raw observations, long controls, distribution/header probes
and executable-section hashes. For a focused current-source run, the normal
build entrypoint calls the same public harness:

```sh
taskset -c 2 zig build -Dtarget=x86_64-linux-gnu -Dcpu=skylake+pku+sgx run-zstd-reference-bench -- \
  --input zig-out/deflate-lazy-20261102/corpus/mozilla.1m.bin \
  --encoded-input zig-out/zstd-small-fse-20261102/corpus/mozilla.1m.zstd.3.zst \
  --name mozilla-1m-l3 --level 3 --iterations 512 \
  --libzstd zig-out/zstd-small-fse-20261102/libzstd.so.1.6.0 \
  --input-offset 1 --output-offset 1
```

`matrix.py` reproduces the complete paired comparison against the frozen
binaries. Its source and command lines are retained with the raw report.

## Validation

The full ReleaseSafe Zstd suite passes 1,257/1,257 tests. Five kernel test
groups perform 3,484 scalar-reference table comparisons in each of Debug,
ReleaseSafe and ReleaseFast, including singleton, sparse/absent symbols, unit
probabilities, random reuse, destination guards and struct layouts. The
PowerPC64 BigEndian kernel object compiles; no cross-architecture execution
claim is made.

Three small serialized headers from the reference frame cover the 64/128-state
shortcut and a 512-state low-probability fallback. Tests compare every entry
with the scalar builder, require exact byte offsets and shortcut counters, and
reject every truncated prefix with `TruncatedFrame`.

The complete `zig build -j2 check check-wasm` compile gate passes for the
retained source. The decodecorpus driver accepts explicit source provenance
for out-of-tree generators and permits legitimate zero compressed-buffer
storage while enforcing its upper bound and capacity consistency.

All nine upstream decodecorpus campaigns pass against the native libzstd 1.6.0
reference: 9,900 frames, 64/64 sequence-mode combinations and 5,376 bounded
block-stream cases. Maximum retained compressed input is 131,034 bytes;
decoded block scratch length/capacity remain zero. The freshly built generator
uses the same `01b7154f` reference source; its recorded Git description is
`v1.4.7-3067-g01b7154f`, while the source header/library version is 1.6.0.
The complete command, build records and summaries are retained in the artifact.
