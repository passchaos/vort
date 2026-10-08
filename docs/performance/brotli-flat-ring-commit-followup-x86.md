# x86-64 Brotli flat distance-ring follow-up

Date: 2026-10-08. Baseline: `54e93ed6`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference
context: local libbrotli 1.2.0-dev (`558fc647`).

## Motivation and scope

The clean 13-row HEAD matrix leaves `clustered_q8` as its only row below the
local reference. The stream has 16,818 commands and 16,663 explicit distance
symbols. Its 52 literal trees select the flat multi-tree executor. GDB proved
that the frozen workload enters the `0x10d5` zero-insert instance, and static
disassembly showed the decoded `update_ring` flag crossing dictionary
selection before a conditional ring push.

The rejected candidate moved that decision immediately next to distance
decode. The helper returned only the distance to the payload and committed a
nonzero in-window result before dictionary/copy dispatch. Implicit distance
zero and static-dictionary distances kept their existing non-commit behavior.
Focused tests compared decoded distance, bit progress, countdown state, recent
history, and dictionary non-updates with the established path.

Linux sampling was attempted, but the host has `perf_event_paranoid=4`; no
system setting was changed. The hypothesis was therefore tested directly with
frozen binaries and generated-shape inspection. GDB confirmed the candidate
workload entered the changed instance, which grew `0x10d5 -> 0x1112` (+61 B).

## Clean paired result

The deterministic 1 MiB source and its 52,622-byte q8 frame were frozen before
measurement. Their SHA-256 values are
`d9644e1c8c6e6b29bb8f00a10cf36accb5d592afd7458e94bbd278fe0c32558f`
and `828aab9db9c321e35db5f4777c97da2d4123db113d648fc5d4c4ac1187b77718`.
Using pre-encoded input removes repeated q8 encoding from process startup:

```sh
taskset -c 2 env LD_LIBRARY_PATH=/tmp/vort-brotli-upstream-build \
  BINARY --input /tmp/vort-br-clustered-q8.raw \
  --encoded-input /tmp/vort-br-clustered-q8.br --name clustered_q8 \
  --iterations 500 --vort-only --csv OUT
```

Fifteen pairs alternated process order after a continuous 60-second clean
window with 1,996 empty `ps -C zig` observations. A 20-millisecond monitor
remained empty throughout the batch. Every run used 500 timed decodes and
produced the same checksum.

| Metric | Result |
| --- | ---: |
| baseline median | 1,689.53 MiB/s |
| candidate median | 1,670.07 MiB/s |
| paired median | 0.98848x |
| paired geometric mean | 0.98831x |
| wins | 0/15 |
| range | 0.98049x--0.99173x |

The candidate is a decisive regression and was removed. A candidate-only
campaign caused by zsh scalar word-splitting semantics and a correctly paired
campaign that overlapped an external Zig process were discarded before this
retained batch.

## Retained structural follow-up

The experiment exposed a cohesive boundary that did not need to remain in the
roughly 35,000-line `src/br.zig`. Short-distance resolution, checked delta
arithmetic, and recent-distance ring pushes now live in
`src/br/decoder/distance_history.zig`, with a focused module test. The rejected
flat commit policy is not present.

The resulting ReleaseFast binary differs in debug/symbol information, but its
ordinary `.text`, `.rodata`, Large Window, paired-literal, wide10-auxiliary,
and wide9 production sections are byte-identical to the frozen baseline. The
short-distance resolver remains at `0x10e6840` with size `0x80`, and all four
flat payload instances retain their baseline addresses and sizes. This makes
the retained change a code-organization improvement with no production
machine-code or performance claim.

## Validation

- Focused ReleaseFast distance-history, short-distance, cached-context, and
  multi-tree command-progress tests pass.
- The complete direct Brotli ReleaseFast suite and AArch64 ReleaseFast compile
  pass.
- The 13-row reference gate reports libbrotli version 1.2.0 and passes all
  rows; the path smoke passes three valid and five invalid cases.
- The upstream multi-block differential and real-corpus differential pass;
  the real-corpus driver's seven tests also pass.
- Project ReleaseFast tests, `zig build check -j1`, and CLI help pass.

Exact paired nanoseconds, CSV hashes, executable and fixture hashes, section
hashes, discarded-campaign disposition, and validation results are in
[brotli-flat-ring-commit-followup-x86-20261008.json](data/brotli-flat-ring-commit-followup-x86-20261008.json).
