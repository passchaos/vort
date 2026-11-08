# Brotli q0 compact one-pass entropy writer

Date: 2026-10-19. Baseline: `85e2223b`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Runtime
reference: system libbrotli 1.0.9. Algorithm invariants were audited against
local Brotli `v1.2.0-169-g558fc64`; Vort emits deterministic compatible wire,
not byte-identical upstream output.

## Implementation

`src/br/encoder/fast_fragment_one_pass.zig` provides q0's compact 128-symbol
command/distance event mapping, the audited default first-fragment code
lengths, the seeded adaptive histogram, and the pre-LZ literal model. Short
fragments count every byte and triple the first eleven occurrences; 32 KiB+
fragments sample every 29th byte and keep all 256 literals reachable.

The writer emits the already-planned q0 commands once. While emitting it
collects the seeded command/distance histogram and derives the trees used by
the next fragment. The learned state is caller-owned inside the reusable/
incremental encoder, resets with the stream, and rolls back on any block-write
error. It advances even when exact compressed-versus-stored arbitration keeps
the stored block, matching the producer-side adaptive-state model.

Ordinary q0 LZ plans use the specialized writer. RAW compound-dictionary
commands and explicitly forced adaptive 64 KiB branch arbitration retain the
general writer; this preserves those existing semantics without applying an
unverified extension to the compact event alphabet. Vort's default q0 block
is 16 KiB, so upstream's internal 96 KiB-first/64 KiB-merge policy is outside
the selected public schedule rather than silently approximated.

## Correctness evidence

Formula oracles cover insert lengths 0...65,536, copy lengths 5...65,536, and
distances 1...65,520 against the authoritative RFC command table/distance
encoder. Further tests validate the default and learned prefix trees, the
long-fragment literal sampler, exact public API wire agreement, allocation
failure cleanup, and an actual two-fragment state transition.

The Node differential pins q0 generic/text/font wire sizes and adds a 32 KiB
two-fragment fixture whose second header uses the first fragment's learned
tree. `zig build test-br --summary all` now passes 814/814 tests after the
q2/q3 writer follow-up.

## Fixed-CPU A/B evidence

The baseline is the dedicated q0 parser using the general exact-histogram
writer. Independent ReleaseFast binaries encode frozen 32 KiB prefixes for
200 iterations, select the best of five rounds, and alternate Vort/libbrotli
order. Baseline executable SHA-256 is
`7bbe5d3f82eb91293f6590b5c481f9c9d9324c74ea7e466a4ff498c262563cb9`;
candidate SHA-256 is
`f85ba6d98e7dca9cd8076b13bb35e30791b2588176d431b27849451869c76e7a`.

| Input | Input SHA-256 | Baseline MiB/s | Candidate MiB/s | Speedup | Bytes baseline -> candidate | Candidate/libbrotli speed | Candidate/libbrotli size |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| README | `eb72ac8d8090a83afc353c41c9a2aa76140f192345f720005a7a860d86456635` | 44.46 | 69.70 | 1.5677x | 12,739 -> 13,399 | 0.1948x | 1.0170x |
| Zig source | `65fd1e2d12f02061cf486990ba81108d2796b5395045c446547acd69db0f53d5` | 55.28 | 85.38 | 1.5446x | 8,885 -> 9,349 | 0.1708x | 1.0624x |
| structured JSON | `726db67581841c221e1beb4f11041ccbae2cb3131c37f67049cd934461ea569c` | 72.65 | 108.34 | 1.4913x | 6,467 -> 7,482 | 0.1485x | 1.0517x |
| dictionary binary | `d2d62abaf82384d6a58b477d3ad0217c834f81168d7155bebbad8d24782f17ed` | 63.89 | 82.44 | 1.2904x | 23,955 -> 25,412 | 0.2139x | 1.0116x |

Every row improves. Geometric throughput rises by 1.4692x; output size grows
by 1.0796x versus the prior general writer. Against system libbrotli q0, the
candidate reaches 0.1485x...0.2139x throughput and is 1.16%...6.24% larger.
This is an explicit q0 latency/throughput tradeoff, not a ratio or parity
claim.

Reproduce with:

```sh
taskset -c 2 zig build -Doptimize=ReleaseFast \
  run-br-planned-encode-bench -- \
  --path README.md \
  --path src/lz77.zig \
  --path docs/performance/data/brotli-short-copy-x86-20261002.json \
  --path src/br/dictionary.bin \
  --limit 32768 --iterations 200 --quality 0 --planned-quality 0
```

The remaining q0 throughput gap is in pre-LZ literal tree construction,
complex-prefix header emission, output allocation, and the general bit writer;
the generic 704-symbol command analysis is no longer on ordinary q0 blocks.

## Larger q0 fragments: rejected

The q0 stream block length is 16 KiB to bound latency and keep each fragment's
entropy model homogeneous. Two candidates raised it and encoded the twelve
Silesia 64 KiB/1 MiB prefixes at q0 with the same CLI. Ratios are
candidate/16 KiB bytes.

| Candidate block | 24-row size geomean | Worst row | Selected wins | Selected regressions |
| --- | ---: | ---: | --- | --- |
| 32 KiB | 1.0180 | `dickens.64k` 1.1754 | `osdb` 0.856, `x-ray` 0.939, `xml.64k` 0.964 | `dickens` 1.166-1.175, `webster` 1.135-1.161, `samba` 1.037-1.155 |
| 64 KiB | 0.9710 | `dickens.64k` 1.1198 | `osdb` 0.753-0.755, `nci.64k` 0.877, `xml.64k` 0.913, `x-ray` 0.920-0.951 | `dickens` 1.086-1.120, `webster` 1.067-1.103, `samba.64k` 1.108 |

The 64 KiB variant improves the corpus geometric mean but fails the
non-regression control bar by more than 10% on individual text rows; the
32 KiB variant is worse overall. The effect is content-dependent: larger
fragments find more matches on database/structured data but mix text content
that the 16 KiB one-pass entropy model separates. Keep 16 KiB as the default.

