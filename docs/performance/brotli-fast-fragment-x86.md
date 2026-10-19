# Brotli q0/q1 block-local fast-fragment parsing

Date: 2026-10-19. Baseline: `3199942e`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Runtime
reference: system libbrotli 1.0.9. The local upstream source used to audit
fragment invariants is `v1.2.0-169-g558fc64`; Vort does not copy its wire or
claim byte identity.

## Implemented boundary

q0 and q1 no longer map only to shallow configurations of the general hash
chain. `src/br/encoder/fast_fragment.zig` supplies a separate reusable parser
with these bounded invariants:

- one fixed-hash candidate plus the most recent distance;
- five-byte q0 anchors, and four-byte q1 anchors through the default 32 KiB
  fragment (six bytes when an explicit wider fragment selects a 16+ bit
  table);
- Snappy-style skip-ahead after repeated misses;
- sparse tail seeding after a consumed match;
- caller-selected Brotli window-distance enforcement; and
- no LZ match into a previous fragment.

The parser writes commands directly and retains its hash table and command
capacity across reusable/incremental calls. One-shot q0/q1 now routes through
the same bounded block core as chunked and incremental encoding, so default
16 KiB q0 and 32 KiB q1 boundaries have one deterministic wire implementation.
Compressed-versus-stored arbitration remains exact.

This completes the fragment parser and streaming-state slice. q1 subsequently
gained compact fast entropy writers: q1 is documented in
[the q1 writer evidence](brotli-q1-two-pass-x86.md), and q0 in
[the q0 writer evidence](brotli-q0-one-pass-x86.md).

## Correctness evidence

The direct parser tests replay every insert/copy command, distinguish q1's
four-byte matches from q0's five-byte minimum, enforce a 1,008-byte distance
ceiling for a 10-bit window, and verify retained scratch across unrelated
fragments. Public-surface tests additionally require byte-identical output
across one-shot, single-chunk, reusable scratch, caller-buffer, and arbitrarily
fragmented incremental calls. A two-block high-entropy duplicate proves that
q0/q1 do not accidentally use earlier-fragment LZ history, while the legacy
fast policy still does. Both q0 and q1 one-shot paths pass exhaustive
allocation-failure injection.

`zig build test-br --summary all` now passes 812/812 tests after the q0/q1
writer follow-ups. The complete
`zig build run-br-planned-node-diff` matrix passes, including q0/q1 in
generic/text/font modes, so Node/libbrotli decodes every selected wire. The
benchmark itself also decodes Vort output through runtime libbrotli before
recording a row.

## Fixed-CPU A/B evidence

The baseline and candidate were built as independent ReleaseFast executables.
Each row encodes a frozen 32 KiB prefix 200 times; the benchmark takes the best
of five in-process rounds and alternates Vort/libbrotli ordering. Baseline
executable SHA-256 is
`54c529eaa5af1f8f1e43c1e869f6cc0be2e7de439325539d297366a12fc82d38`.
Final candidate executable SHA-256 is
`7bbe5d3f82eb91293f6590b5c481f9c9d9324c74ea7e466a4ff498c262563cb9`.

| Quality | Input | Input SHA-256 | Baseline MiB/s | Candidate MiB/s | Speedup | Bytes baseline -> candidate | Candidate/libbrotli speed |
| ---: | --- | --- | ---: | ---: | ---: | ---: | ---: |
| 0 | README | `eb72ac8d8090a83afc353c41c9a2aa76140f192345f720005a7a860d86456635` | 33.01 | 44.46 | 1.3470x | 13,322 -> 12,739 | 0.1211x |
| 0 | Zig source | `65fd1e2d12f02061cf486990ba81108d2796b5395045c446547acd69db0f53d5` | 46.67 | 55.28 | 1.1843x | 9,068 -> 8,885 | 0.1099x |
| 0 | structured JSON | `726db67581841c221e1beb4f11041ccbae2cb3131c37f67049cd934461ea569c` | 65.57 | 72.65 | 1.1079x | 6,744 -> 6,467 | 0.0976x |
| 0 | dictionary binary | `d2d62abaf82384d6a58b477d3ad0217c834f81168d7155bebbad8d24782f17ed` | 23.69 | 63.89 | 2.6966x | 21,506 -> 23,955 | 0.1672x |
| 1 | README | same as above | 34.29 | 43.18 | 1.2596x | 12,628 -> 12,427 | 0.1703x |
| 1 | Zig source | same as above | 50.06 | 55.92 | 1.1170x | 8,414 -> 8,491 | 0.1515x |
| 1 | structured JSON | same as above | 67.38 | 79.20 | 1.1756x | 6,417 -> 6,224 | 0.1463x |
| 1 | dictionary binary | same as above | 23.28 | 40.39 | 1.7353x | 21,277 -> 22,646 | 0.1877x |

The four-row geometric throughput gains are 1.4775x for q0 and 1.3016x for
q1; every row improves. Geometric output-size ratios are 1.0002x and 1.0062x.
The fixed-hash latency policy improves text/JSON size but trades 11.39% q0 and
6.43% q1 size on the dictionary binary, while still producing smaller output
than runtime libbrotli there. This is an explicit speed/ratio tradeoff, not a
blanket ratio improvement.

At this parser-only milestone the candidate remained only 0.0976x--0.1877x of
libbrotli throughput. The later q1 writer raises its four rows to
0.2405x--0.2863x, and the q0 writer raises its rows to 0.1485x--0.2139x.

Reproduce the matrix with the following command, substituting quality 1 for
the second run and running the baseline checkout in the same way:

```sh
taskset -c 2 zig build -Doptimize=ReleaseFast \
  run-br-planned-encode-bench -- \
  --path README.md \
  --path src/lz77.zig \
  --path docs/performance/data/brotli-short-copy-x86-20261002.json \
  --path src/br/dictionary.bin \
  --limit 32768 --iterations 200 --quality 0 --planned-quality 0
```

The benchmark's built-in `source32k` fixture now uses a true 32 KiB prefix
read rather than attempting to load all of the larger-than-2-MiB `src/br.zig`
under a 2 MiB limit. This removes the previous `StreamTooLong` failure without
weakening the frozen input bound.
