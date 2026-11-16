# Zstd compressed-literal split threshold, 2026-11-16

## Trigger

After the single-sequence literal fix, `mr` was the weakest level-1 row at
0.6210. A per-block mode dump of the libzstd 1.6.0 frame shows that almost every
`mr` block is `ll=compressed, of=compressed, ml=compressed` with about 700-1000
sequences and 17-19 KiB of literals. `preferSplit` required
`sequence_count >= 1024` **or** `literal_bytes >= 32 KiB`, so those blocks fell
through to `tryDecodeGenericSplitHuffmanSequences`, which reads every sequence
through `readModeSequence` and its per-symbol mode switches even though all
three modes are compressed. The specialized wide split executor (already
localized in `1f667638`) was never selected for this shape.

## Change

`src/zstd/sequence/decode_policy.zig`:

- lower `split_literal_min` from `32 * 1024` to `16 * 1024`, so compressed
  blocks with 16-32 KiB of literals and fewer than 1024 sequences use the
  specialized split executors;
- keep `split_sequence_min = 1024`;
- decouple `raw_all_fse_literal_min` at `32 * 1024` instead of aliasing
  `split_literal_min`, so the raw-literal routing is unchanged.

No decoder logic changed; the executors are byte-identical, only the routing
policy moved.

## Experiments

| variant | mr ratio | twelve-file geomean | lowest control |
| --- | ---: | ---: | ---: |
| committed baseline | 0.6210 | - | - |
| `split_sequence_min = 256` | 0.7576 | 1.0181 | 0.9938 |
| `split_sequence_min = 128` | 0.7568 | 1.0168 | 0.9965 |
| `split_literal_min = 16 KiB` (coupled raw threshold) | 0.7578 | 1.0159 | 0.9816 |
| **`split_literal_min = 16 KiB` + decoupled raw threshold** | **0.7560** | **1.0176** | **0.9929** |

- The sequence-threshold variants also fix `mr`, but they make
  `preferHuffmanMatchWildcopy`'s `[huffman_all_fse_sequence_min, split_sequence_min)`
  range empty and fail the policy consistency test; the literal-threshold change
  keeps every policy invariant intact.
- Coupling the raw threshold to the new 16 KiB literal threshold regressed
  `reymont`/`samba`/`xml` by up to 1.8%; decoupling it restores the controls.

## Results

Baseline: the committed single-sequence package. `speedup` is `after / before`;
`cumulative` is `after / original libzstd 1.6.0 baseline`.

| file | before | after | speedup | cumulative |
| --- | ---: | ---: | ---: | ---: |
| dickens | 0.8076 | 0.8067 | 0.9989 | 1.1003 |
| mozilla | 0.8001 | 0.8030 | 1.0036 | 1.0420 |
| mr | 0.6210 | **0.7560** | **1.2174** | **1.2545** |
| nci | 0.7871 | 0.7815 | 0.9929 | 0.9925 |
| ooffice | 0.7969 | 0.8044 | 1.0094 | 1.0405 |
| osdb | 0.8066 | 0.8081 | 1.0019 | 1.0640 |
| reymont | 0.8081 | 0.8092 | 1.0014 | 1.1349 |
| samba | 0.7930 | 0.7922 | 0.9990 | 1.0449 |
| sao | 0.8127 | 0.8148 | 1.0026 | 1.0248 |
| webster | 0.8347 | 0.8321 | 0.9969 | 1.0873 |
| xml | 0.7759 | 0.7861 | 1.0131 | 1.0334 |
| x-ray | 0.7811 | 0.7761 | 0.9936 | 2.3777 |

`mr` improves 21.7% in this increment and 25.5% cumulatively, clearing the
20% weak-row repair bar. The twelve-file geometric mean improves **1.0176**;
the lowest control row is 0.9929 (above the 0.98 floor). Cumulatively, the three
2026-11-16 zstd decode increments improve the twelve-file geometric ratio from
0.6957 to **0.7973** (**1.1460**).

## Validation

- `zig build test-zstd -Dzstd-test-filter=predefined`: 49/49.
- `zig build test-zstd -Dzstd-test-filter=literal`: 162/162, including the
  decode-policy consistency test.
- `zig build test-zstd -Dzstd-test-filter="stream counters"`: 42/42.
- Focused decode-memory/source-reverse/compressed-workspace: 228/228.
- Full `test-zstd` and `check-wasm` results are recorded in the status ledger.
- The reference bench verifies byte equality for all twelve files.

## Scope limits

Single host, one-shot decode, 20 iterations, no CPU pinning. The gain is a
routing policy change for the `mr` block shape; other corpora are within about
1% of the baseline. Absolute throughput moved between runs; the paired libzstd
ratio is the reported metric.
