# x86-64 Brotli middle-tier positive-distance invariant

Date: 2026-10-03. Baseline: `808ec2a8`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libbrotli 1.2.0-dev (`558fc647`).

## Scope and safety

The 65--128-literal-tree executor used by the frozen source q9/q5 frames
decoded a distance through its prepared auxiliary path and then tested the
result against zero on every LZ77 copy. That path already has a stronger
invariant:

- the RFC distance ring starts at positive values `16/15/11/4` and is updated
  only with successfully decoded distances;
- direct prepared distances start at one;
- regular prepared distances retain the RFC terminal `+1`;
- short-distance negative deltas return `InvalidMatch` before reaching zero.

The selected auxiliary instances now retain this condition as a Debug and
ReleaseSafe assertion instead of a ReleaseFast runtime branch. Non-auxiliary
instances retain the original `InvalidMatch` check. The exhaustive prepared-
distance table test additionally requires every valid prepared value to be
positive. Truncation, invalid-symbol, output-bound, dictionary, and ring-update
ordering are unchanged.

The frozen q9/q5 frames execute 48,751/52,136 LZ77 copies. A debugger breakpoint
on the three concrete template instances confirms both source frames select
the command/distance-lookup instance, which shrinks from `0x154a` to `0x1482`
bytes. The unused auxiliary-without-command-lookup instance grows from `0x112e`
to `0x11c5`; the whole `.vort_br_wide_lookup9` section falls from `0x438a` to
`0x4382`. The ordinary
`.text`, Large Window, paired full-tier, and 10-bit auxiliary sections retain
their addresses, sizes, and exact bytes.

## Performance

Both binaries were emitted through the same fixed `-femit-bin` path and then
frozen. The q9/q5 frames are the unchanged 141,001/147,580-byte libbrotli
outputs for the 1,726,567-byte `src/br.zig` fixture. Decoder-only processes use
500 iterations; same-process Vort/libbrotli runs use 100 iterations. Launch
order alternates on CPU 2. Every retained batch used the corrected one-second
process monitor and observed no concurrent Zig process.

The final source adds one explanatory comment line after the measured binary
was frozen, changing only debug metadata. Its rebuilt executable is
`77425d9d...26f33`; the complete measured and final-source 9-bit text sections
are byte-identical at SHA-256 `61bb1a33...8569`.

| Input | Decoder-only median / geometric | Wins | Reference raw median / geometric | Reference-normalized median / geometric | Candidate / libbrotli median / geometric |
| --- | ---: | ---: | ---: | ---: | ---: |
| source q9 | 1.0018x / 1.0018x | 10/15 | 1.0032x / 1.0011x | 1.0050x / 1.0059x | 0.7646x / 0.7654x |
| source q5 | 1.0015x / 1.0013x | 4/7 | 1.0094x / 1.0083x | 1.0057x / 1.0069x | 0.7567x / 0.7580x |

The raw decoder-only gain is intentionally characterized as small: q9 spans
0.9943x--1.0095x and q5 spans 0.9954x--1.0063x. The independent reference
normalization is positive on both inputs, and the changed branch executes once
per LZ77 copy, so the invariant is retained as a bounded improvement. It does
not close the substantial libbrotli gap.

Several longer reference batches and one attempted q5 extension were discarded
when the continuous monitor caught unrelated `spectra` Zig builds. Only the
clean q9 7-pair and q5 7-pair campaigns are included in the result above.

## Rejected full-tier extension

The same invariant was also applied to the 129--256-tree paired executor. It
passed the focused full-tier transition/boundary oracle, but LLVM expanded the
payload from `0x1690` to `0x16d3` bytes and the paired section from `0x259b` to
`0x25db`. Seven clean 500-iteration roadmap-q5 pairs measured 0.9995x median /
0.9982x geometric throughput with only 3/7 wins. One clean roadmap-q9 pair was
1.0026x, which is not enough to offset the repeatable q5 loss. Other attempted
batches were discarded when the monitor observed external Zig work. The
full-tier runtime check therefore remains; the invariant is retained only in
the independently measured middle tier.

Exact hashes, nanosecond observations, and validation counts are recorded in
[brotli-middle-positive-distance-x86-20261003.json](data/brotli-middle-positive-distance-x86-20261003.json).

## Validation

- Four focused ReleaseFast tests cover middle-tier routing, packed/canonical
  lookup behavior, exhaustive prepared distances, and every truncated suffix.
- The full project `zig build test -j2` suite passes.
- The upstream differential passes 7,056 generated one-shot cases, 7,056
  progressive cases, 1,401 fragmentation schedules, 64 high-tree truncations,
  and seven Large Window cases.
- The real-corpus differential passes 16/16 one-shot and 16/16 progressive
  cases across four required categories.
- The 13-row libbrotli reference gate and three-row path smoke pass.
- `zig build check -j2`, the CLI help smoke, and AArch64 Linux ReleaseFast
  compilation pass.
