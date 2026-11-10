# Zstd one-shot decode vs libzstd, 2026-11-10 (current head)

Supersedes the 2026-11-09 matrix (0.7067) with current-source measurements
that include the direct-indexed Huffman long-code fallback and the later
decode increments.

## Protocol

- Zig 0.16.0 `ReleaseFast`, `x86_64-linux-gnu`, `skylake+pku+sgx`; Intel Core
  i7-10700K; logical CPU 15 pinned with `taskset`.
- Reference frames from system libzstd 1.4.8 at levels 3 and 19. Vort uses
  one-shot `decodeFrameInto`; the reference uses `ZSTD_decompress`.
- Twelve Silesia sources at 64 KiB and 1 MiB prefixes; two invocations per
  row, per-row medians (500 iterations for 64 KiB, 100 for 1 MiB).
- Reproduce with `zig build run-zstd-reference-bench -- --input FILE
  --name NAME --level LEVEL --iterations N`.

## Result

`reference_over_vort_time` below one means Vort is slower.

| Level | Prefix | Geometric ref/Vort | Vort slower |
| --- | --- | ---: | ---: |
| 3 | 64 KiB | 0.7815 | 1.28x |
| 3 | 1 MiB | 0.7665 | 1.30x |
| 19 | 64 KiB | 0.7366 | 1.36x |
| 19 | 1 MiB | 0.7454 | 1.34x |
| all 48 rows | | **0.7573** | **1.32x** |

The full-matrix ratio moved 0.7067 -> 0.7573 (+7.2% relative throughput).
Weakest rows: `xml.64k` L19 0.6740, `nci.64k` L19 0.6960, `xml.64k` L3
0.6967. Strongest: `x-ray.64k` L3 0.9832 (near parity), `nci.1m` L19
0.8534.

## Profile of the weakest row (`xml.64k` L19, 20k iterations)

| Symbol | Share |
| --- | ---: |
| `tryDecodeAllFseSplitDenseHuffmanSequencesNative` | 42.96% |
| `fse_table.buildNoLowProbabilityAssumeValid` | 9.53% |
| `decodeFourStreamHuffmanReservoirNative` | 6.94% |
| `compiler_rt.memcpy.memcpyFast` | 6.15% |
| `decodeLinearZstdHuffmanTree` | 2.46% |

Hardware counters: IPC 3.29, branch-miss rate only 0.65% (so branch
hints have little headroom), L1-dcache miss rate 5.74%. The executor's
hottest instructions are the 16-byte wildcopy vector moves; the wider
32/64-byte tiers were already rejected on this corpus
([zstd-sixteen-byte-wildcopy](zstd-sixteen-byte-wildcopy.md)). All weak
rows are single compressed blocks, so the FSE table build is pure
per-decode setup rather than amortizable over multiple blocks.

## Next

- The 53% combined sequence-executor cost needs a structural change
  (executor fusion), not local caching or wider copies; prior
  experiments in `decode-optimization-status.md` already rejected
  cursor promotion, short-match branch-first changes and wider wildcopy.
- The 9.5% FSE table build is the second target: investigate whether the
  per-symbol 256-entry scatter can use the same dense-run machinery more
  aggressively for the common probability distributions in L19 blocks.

Raw rows: [matrix.csv](data/zstd-decode-current-20261110/matrix.csv).
