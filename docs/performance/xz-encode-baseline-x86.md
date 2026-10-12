# x86-64 XZ encode baseline and persistent LZMA2 model

Date: 2026-10-13. Baseline: `b6e6b797`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
runtime liblzma 5.2.5, easy preset 1, CRC-64.

## Benchmark surface

`run-xz-encode-bench` measures five deterministic one-shot cases in process:
text, numbered JSON, mixed binary, a 128 KiB history match, and a 1 MiB history
match. It records both encoded size and throughput, captures executable/input
provenance, and verifies Vort output through liblzma plus liblzma output through
Vort. The companion gate locks schema, reference version consistency, hashes,
positive timing, and actual wide-dictionary compression without imposing a
premature performance floor.

The initial baseline immediately separated two problems. Vort already led
liblzma preset 1 on text/JSON speed, but its outputs were 1.90x/2.40x larger.
Binary and 1 MiB-wide throughput were only 0.560x/0.693x reference, while the
128 KiB-wide row already led in both size and speed. This made LZMA2 model
continuity a higher-confidence first step than changing greedy parsing.

## Retained change

The writer now retains the LZMA probability model, state, and recent distances
across consecutive compressed chunks. The first compressed chunk still uses
`0xe0`; a following compressed chunk uses `0x80`. A stored fallback invalidates
the model, so its successor uses `0xa0` when properties are already known or
`0xc0` otherwise. Candidate encoding mutates the retained model directly:
fallback does not need rollback because LZMA2 mandates a state reset afterward.

An initial transactional model-copy variant produced the same smaller bytes
but regressed text/JSON throughput to about `0.978x`. Removing that unnecessary
copy recovered the loss and turned the retained change into a speed/ratio win.

## Paired result

Independent baseline/candidate binaries alternated order for 15 fixed-CPU-2
pairs. Each CSV observation retained the best of three internal rounds, each
containing five complete allocating encodes.

| case | size | median speedup | geometric speedup | wins |
| --- | ---: | ---: | ---: | ---: |
| text256k | 456 → 268 | 1.0550x | 1.0535x | 15/15 |
| json256k | 3,404 → 2,948 | 1.0552x | 1.0589x | 15/15 |
| binary256k | 71,048 → 70,764 | 1.0355x | 1.0366x | 15/15 |
| wide128k | 131,188 → 131,188 | 0.9966x | 0.9964x | 0/15 |

The wide control has a bounded 0.36% geometric cost while remaining 1.249x
liblzma throughput and slightly smaller than the reference. The three ordinary
rows improve both size and speed in every pair. The final reference snapshot
puts text at 1.100x liblzma speed and 1.117x its size; JSON at 1.400x speed but
2.076x size; binary at 0.559x speed and 1.026x size. The next work should focus
on binary/wide throughput and JSON parsing ratio rather than another chunk
state change.

A follow-up enlarged the streaming hash head only for dictionaries above
256 KiB. The fixed-core screen improved `wide1m` by about `1.65x`, but text,
JSON, binary, and `wide128k` moved to `0.923x`, `0.938x`, `0.985x`, and
`0.980x`. Outlining the large initializer made ordinary controls worse. The
candidate was fully removed before long pairs; a future large-window index
must isolate its code/data layout rather than changing this shared binary.

## Validation

- LZMA focused suite: 103/103.
- XZ focused suite: 114/114.
- Python/system-XZ differential and the five-row benchmark gate pass.
- Consecutive compressed, compressed→stored→compressed, and
  stored-first→compressed control transitions have exact focused coverage.
- The full repository test graph was not run.

Exact nanoseconds, executable hashes, final liblzma ratios, and the rejected
copy precursor are in
[`xz-persistent-model-x86-20261013.json`](data/xz-persistent-model-x86-20261013.json).
