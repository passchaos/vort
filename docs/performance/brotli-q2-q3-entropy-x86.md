# Brotli q2/q3 dedicated entropy writers

Date: 2026-10-19. Baseline: `f80bd315`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Runtime
reference: system libbrotli 1.0.9. The algorithm split was audited against
local Brotli `v1.2.0-169-g558fc64`; Vort does not claim byte identity.

## Implemented quality decisions

q2 ordinary LZ plans now use the upstream-shaped fast decision:

- at most 128 commands: exact literal tree capped at eight bits, the complete
  static 704-command tree, and the complete static 64-distance tree;
- above 128 commands: exact literal/command/distance histograms with 8-/10-/
  6-bit caps.

q3 ordinary LZ plans use one unsplit meta-block with exact dynamic literal,
command, and distance trees. q3 resolves the full recent-distance alphabet;
q2 retains the implicit last-distance form. Both writers use `NPOSTFIX=0` and
`NDIRECT=0`, update the RFC distance ring transactionally, and share the
one-shot/chunked/reusable/incremental block core. Static and RAW compound-
dictionary command plans fall back to the general writer.

## Correctness evidence

Private path counters prove q2's ≤128 static branch, q2's >128 dynamic branch,
and q3's trivial dynamic writer are all reached. The >128 test constructs 129
commands and decodes the resulting complete stream. Public q2/q3 round trips,
caller-buffer bounds, incremental fragmentation, dictionary fallbacks, and
allocation-failure paths remain in the 814-test Brotli suite.

The complete Node differential decodes q0...q11, pins q2/q3
generic/text/font wire sizes, and independently decodes the 129-command q2
dynamic-tree fixture. `zig build test-br --summary all` passes 814/814.

## Fixed-CPU A/B evidence

Independent ReleaseFast binaries encode four frozen 32 KiB prefixes for 200
iterations, taking the best of five rounds and alternating Vort/libbrotli
order. Baseline executable SHA-256 is
`721d94c9f16dc663dbf8c8c7681c720916c0b610890bb9a58a656fcc2d7411d0`;
candidate SHA-256 is
`ea4ee29797ddb31ee4c305713712161d27aa51d1b03bcd1b2dab268f91071e21`.

| Quality | Input | Input SHA-256 | Baseline MiB/s | Candidate MiB/s | Speedup | Bytes baseline -> candidate | Candidate/libbrotli speed | Candidate/libbrotli size |
| ---: | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 2 | README | `eb72ac8d8090a83afc353c41c9a2aa76140f192345f720005a7a860d86456635` | 30.66 | 36.79 | 1.1997x | 11,855 -> 11,879 | 0.2654x | 1.0062x |
| 2 | Zig source | `65fd1e2d12f02061cf486990ba81108d2796b5395045c446547acd69db0f53d5` | 45.05 | 54.20 | 1.2032x | 7,710 -> 7,721 | 0.3017x | 0.9777x |
| 2 | structured JSON | `726db67581841c221e1beb4f11041ccbae2cb3131c37f67049cd934461ea569c` | 57.37 | 70.28 | 1.2249x | 6,054 -> 6,074 | 0.2715x | 1.0362x |
| 2 | dictionary binary | `d2d62abaf82384d6a58b477d3ad0217c834f81168d7155bebbad8d24782f17ed` | 19.28 | 23.01 | 1.1932x | 21,222 -> 21,365 | 0.1372x | 0.9105x |
| 3 | README | same as above | 25.12 | 32.52 | 1.2946x | 11,375 -> 11,450 | 0.2770x | 0.9800x |
| 3 | Zig source | same as above | 37.40 | 48.69 | 1.3022x | 7,338 -> 7,347 | 0.3167x | 0.9635x |
| 3 | structured JSON | same as above | 46.64 | 63.07 | 1.3522x | 5,787 -> 5,836 | 0.3082x | 1.0224x |
| 3 | dictionary binary | same as above | 14.96 | 19.62 | 1.3115x | 20,450 -> 21,022 | 0.1478x | 0.9001x |

Every row improves. q2 throughput rises by 1.2052x geometric while size grows
1.0033x; q3 throughput rises 1.3149x while size grows 1.0110x. Against system
libbrotli, q2 reaches 0.1372x...0.3017x throughput and q3 reaches
0.1478x...0.3167x. This remains workload-specific evidence, not a parity
claim.

Reproduce by substituting quality 2 and 3:

```sh
taskset -c 2 zig build -Doptimize=ReleaseFast \
  run-br-planned-encode-bench -- \
  --path README.md --path src/lz77.zig \
  --path docs/performance/data/brotli-short-copy-x86-20261002.json \
  --path src/br/dictionary.bin --limit 32768 --iterations 200 \
  --quality 2 --planned-quality 2
```
