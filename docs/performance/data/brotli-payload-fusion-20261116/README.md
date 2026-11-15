# Brotli payload fusion A/B baseline, 2026-11-16

## Purpose

Anchor the performance phase opened by
`incremental-fuzz-closure-20261116.md`. The functional fuzz closure is
complete; the largest measured decode gap is Brotli versus libbrotli, and a
stage profile attributes ~81% of decode time to the payload stage. The
candidate work is a payload state-machine fusion in
`src/br/incremental/copy_decoder.zig`.

## Baseline

`baseline.csv` is the output of the self-contained caller-owned probe, which
measures Vort and the runtime libbrotli 1.0.9 in the same binary, at the
unmodified HEAD before any candidate change:

```sh
zig build run-br-reference-bench -- --iterations 500 --csv \
  docs/performance/data/brotli-payload-fusion-20261116/baseline.csv
```

Key reading: the `vort_over_reference` column is Vort time divided by
libbrotli time (lower is faster Vort). The 1 MiB `clustered_q8` row is the
payload-dominated case (~0.80, the only large frame); the small-frame rows
carry fixed per-call overhead and are insensitive to payload fusion, so do
not use the all-row geometric mean as the payload-candidate metric.

## Candidate protocol

1. Apply one minimal payload restructure at a time behind the existing
   native/portable split; keep wire output byte-identical.
2. Rebuild the same probe to `candidate.csv` with identical iterations.
3. Compare payload-dominated rows (`clustered_q8`, plus any added 64 KiB/1 MiB
   q6/q11 rows) across alternating sweeps; report per-row ratios and a
   geometric mean over those rows with a 95% confidence interval.
4. Adoption bar: at least 3% geometric-mean improvement, no control row below
   the 0.98x floor, and full `test-br` plus differential wire validation
   green. Reject and archive the negative result otherwise, matching the
   prior rejected micro-fusions.

## Static findings that rule out naive tweaks

- `stream_count.ringIndex` already masks power-of-two capacities and must
  keep the modulo path because caller history is not guaranteed power-of-two
  (default `max_history_len` is 2^24 - 16).
- The `previous[2]` two-byte slide in the literal loop is required RFC 7932
  context state, not removable.
- The per-command phase dispatch is flat at ~1-5% per instruction; only a
  structural goto-style fusion can move it, which is why this needs the full
  A/B cycle rather than a local edit.

## perf symbol profile (2026-11-16)

`perf record -g` over `vort-br-reference-bench --iterations 200 --vort-only`
(703 samples); top self-time symbols archived in `perf-top-symbols.txt`.
The bench drives the one-shot `decodeStreamInto` path, which is the surface
the ledger gap measures.

| symbol | self share | note |
| --- | ---: | --- |
| `compiler_rt.memset` | 23.09% | aggregated across header/prefix-code table zeroing in `readMinimalCompressedHeaderInto` and several `readPrefixCodeRuntimeInto`; many small, correctness-required clears rather than one removable fill |
| `processTailLookupCompressedPayload` | 22.02% | the payload command/literal loop; insert loop already keeps `previous`/`second_previous` in registers across the run |
| `Sha2x32.round` | 8.44% | content checksum; mandatory for checksummed frames, a shared cross-codec crypto path rather than a brotli-local lever |
| `memcpyFast` | 5.96% | match/copy spans |
| `readPrefixCodeRuntimeInto` variants | ~8.8% combined | Huffman table build |

Implication: there is no high-confidence local edit that clears the 3%
adoption bar. The memset and SHA-256 shares are structural (table build and
mandatory hashing); the payload loop itself is already register-tight. The
candidate work therefore stays a structural payload fusion (or a separate
table-build reuse / SHA acceleration project), each requiring its own paired
A/B rather than an opportunistic tweak.

