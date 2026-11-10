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

## Follow-up analysis: why the FSE build has no safe local win (2026-11-10)

The decode profile tool (`run-zstd-decode-profile`) shows every weak row's
three sequence tables are no-low-probability 256-state tables built by
`large/fse_table.buildNoLowProbabilityAssumeValid` (`no_low_probability_tables=3`,
accuracy log 8 for nci/xml; x-ray L19 uses the generic mapped builder).
The hottest instructions in that builder are the per-symbol state bitset
scatter (`or` into four stack words) and the per-entry writes.

Two candidate changes were evaluated against the source and rejected
without committing:

1. The bitset construction is irreducible scatter: FSE's spread step
   (163 for 256 states) deliberately produces a permutation, so each
   symbol's `probability` writes go to distinct modulo-256 positions.
   The only existing vectorization is the `probability >= 192` dense
   path's packed 4-entry writes; lowering that threshold would change
   which symbols qualify without reducing total state visits, and the
   prior corpus already rejected wider/faster wildcopy-style changes.
2. The builder runs exactly once per frame on these single-block rows,
   so there is no reuse or batching opportunity in one-shot decode; any
   gain must come from doing less work per table (a different table
   representation the sequence executor can consume directly), which is
   the same structural executor-fusion work already identified as the
   next milestone.

The 6.15% `memcpyFast` share is similarly setup-bound (FSE table copy and
literal-section parse inside the single block), not the hot sequence
wildcopy loop, whose 16-byte width matches libzstd and was confirmed
optimal on this corpus. Conclusion: the remaining 1.32x gap is gated on
the executor/table-representation fusion; no isolated micro-change with
new evidence is available from the current profile.
