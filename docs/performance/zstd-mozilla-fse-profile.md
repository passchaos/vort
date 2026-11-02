# Mozilla Zstd FSE table shapes, 2026-11-02

A structural inspection of the 1 MiB Silesia Mozilla frame narrows the next
decoder target to small generic FSE tables. It also rules out RLE data as the
source of the `memset` samples attributed to this frame in the earlier profile.
This inspection measures format structure and does not time decoding.

The frame is generated at level 3 by libzstd 1.6.0, clean reference commit
`01b7154f1172432f8abe9b3bb9909e14a1176b7d` under `~/Work/zstd`. A GCC 11.4.0
shared build uses `-O3 -march=skylake -DZSTD_DISABLE_ASM
-DZSTD_LEGACY_SUPPORT=0`. Two compressions produce identical bytes and the
reference library decodes them back to the complete input.

| Binding | SHA-256 |
| --- | --- |
| Mozilla first 1 MiB | `d307112d2151eef3c035e308b0478e831f6039bdd9770bb753207b02e1fd579d` |
| 656,529-byte level-3 frame | `7b9c06a9a419ed0171ad4e2876d4083ea8635c0ab910b02a5e7368282440599a` |
| Reference shared library | `63755d6d27354c64f7e4a710d19062d9ed9c092b52722725f189bf7c4447d0bb` |

## Table distribution

`benchmarkNativeSequenceCopyProfile` independently reads serialized normalized
counts. The route columns below describe Vort `86ca5489`, before the small-table
optimization, and are derived from its production condition
`table_len == 256 && no_low_probability`, rather than counters inserted into
the hot decoder. Low counts tables containing at least one low-probability
symbol, rather than the number of those symbols.

| States | Tables | No low probability symbols | Low | Specialized | Generic |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 32 | 3 | 3 | 0 | 0 | 3 |
| 64 | 61 | 61 | 0 | 0 | 61 |
| 128 | 15 | 15 | 0 | 0 | 15 |
| 256 | 4 | 1 | 3 | 1 | 3 |
| 512 | 8 | 0 | 8 | 0 | 8 |
| Total | 91 | 80 | 11 | 1 | 90 |

64/128-state no-low tables account for 76/91 tables (83.5%). The generic
builder still spreads symbols into scratch and traverses states again to map
the final entries. Investigate these sizes before concentrating on the eight
512-state tables. Prior bitset-builder experiments were negative on other
workloads; these counts select a workload to study and do not establish a
profitable replacement algorithm.

The subsequent [small no-low builder](zstd/small-no-low-tables.md) implements
this selected path and validates its narrow throughput and scratch benefit.
The table above remains the baseline routing snapshot.

The 81 blocks are 27 raw and 54 compressed, with zero RLE blocks. Compressed
blocks contain 49 raw literal sections, four compressed Huffman sections and
one treeless section, with zero RLE literal sections. The earlier `memset`
attribution to RLE literal/block fills therefore lacks support. Locate its
actual callsite before proposing another fill kernel. Redundant full-table
clearing and intermediate entry conversion have already been removed.

## Reproduction

The repository probe calls existing inspection APIs and accepts a frame path:

```sh
zig build-exe -OReleaseFast --dep zstd \
  -Mroot=tools/zstd/fse_shape_probe.zig -Mzstd=src/zstd.zig \
  -femit-bin=zig-out/zstd-fse-shape
taskset -c 7 zig-out/zstd-fse-shape \
  zig-out/deflate-lazy-20261102/zstd-profile/mozilla.1m.zstd.3.zst
```

The local `zig-out/deflate-lazy-20261102/zstd-profile` artifact retains the
reference build/generation commands, probe output, all 81 block records and
source/binary hashes in `README.md`, `counts.json` and `evidence.json`. Those
files are generated evidence; the source probe and this report are committed.
