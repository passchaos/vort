# Full-file upstream stream correctness, 2026-11-24

These are conformance results, not throughput measurements. The source base
was `2abba4d0`; the production correction is `328302e7`. Zig 0.16.0
ReleaseFast used system libz 1.2.11, local libzstd 1.6.0 and local libbrotli
1.2.0. The readers and producers were checked for matching reference versions
within each codec family.

```sh
corpus="$HOME/Work/corpora/silesia-20261025/files"
LD_LIBRARY_PATH="$HOME/Work/brotli/build-vort:$HOME/Work/zstd/lib" \
  zig build -Doptimize=ReleaseFast run-codec-differential-fuzz -- \
  --real-limit=67108864 --real-file="$corpus/xml" --real-file="$corpus/ooffice" \
  --real-file="$corpus/mozilla"
```

Each row uses the entire public Silesia file. The runner prints full input and
wire hashes and encoder parameters for each case.

| Input | Plaintext bytes | SHA-256 |
| --- | ---: | --- |
| xml | 5,345,280 | `0e82e54e695c1938e4193448022543845b33020c8be6bf3bf3ead2224903e08c` |
| ooffice | 6,152,192 | `e7ee013880d34dd5208283d0d3d91b07f442e067454276095ded14f322a656eb` |
| mozilla | 51,220,480 | `657fc3764b0c75ac9de9623125705831ebbfbe08fed248df73bc2dc66e2a963b` |

Reference encoders flush every 64 KiB. All 15 complete wires pass the reference
and Vort's one-shot and exact-size checks. Two caller schedules validate all 30
complete incremental runs and all 30 final-byte cuts, with no mismatches. Cut
inputs must also be refused by the reference. The harness checks the emitted
prefix on every step, including a failed call, rather than assuming different
input policies publish at the same time. In particular, the prevalidated Zstd
route publishes no bytes from a truncated single frame.

## Brotli defect found by the sweep

Before the fix both incremental schedules rejected the valid `mozilla` Brotli
wire with `CorruptFrame` after 15,780,306 compressed bytes and 45,875,200
plaintext bytes (700 flush intervals). The independently decoded wire has
SHA-256 `fe12163f4e10c57ed7c8905a72ca558cb0acd5547be5ec9d72d704f3a1417ced`.
The streaming alignment check incorrectly rejected whole bytes already staged
by Huffman lookahead. The correction preserves those bytes across empty
metadata markers and drains staged stored/metadata bodies in wire order before
accepting more input. Nonzero padding remains invalid.

Focused native, x86 and executed WASI tests now cover retained-next-header,
retained stored body, retained metadata with observer and capture, output
backpressure, and bad padding. The bounded generated-wire control retains
2,584 valid, 62,432 truncation and 97,894 mutation comparisons at unchanged
wire and mutation digests. `run-codec-real-stream-smoke` covers this test mode
in `ci-smoke` with the repository README and no external corpus download.
