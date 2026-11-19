# Zstd level-1 predefined-plan dominance skip, 2026-11-20

## Change

The fast large-sequence planner ran the predefined viability walk for literal,
offset and match tables on every block. The walk selects transition values,
not widths, so a per-code minimum-width table gives a lower bound on the
predefined bit cost without running it. The planner now compares that lower
bound with the compressed plan's exact cost; if the predefined alternative
would still be worse after charging the compressed table header plus one byte
of rounding slack, the walk is skipped. This is a strict dominance proof, so
the selected plan and the emitted wire are unchanged. If the compressed plan
is absent, or the bound is not decisive, the original walk runs. The non-fast
ratio planner keeps the eager walk.

## Measurement

- Host Intel i7-10700K, Linux 6.8, Zig 0.16.0 ReleaseFast, `skylake+pku+sgx`,
  single thread.
- `run-zstd-encode-bench`, level 1, one-shot, twelve 128 KiB Silesia prefixes,
  `--iterations 1000 --rounds 3`, interleaved with libzstd 1.6.0.

| case | before MiB/s | after MiB/s | speed ratio | bytes |
| --- | ---: | ---: | ---: | ---: |
| dickens | 83.98 | 92.88 | 1.1059 | 59,878 |
| mozilla | 171.99 | 189.41 | 1.1012 | 24,399 |
| mr | 73.49 | 83.60 | 1.1376 | 36,827 |
| nci | 223.43 | 247.49 | 1.1077 | 11,491 |
| ooffice | 93.84 | 102.25 | 1.0897 | 76,442 |
| osdb | 124.44 | 132.27 | 1.0630 | 61,098 |
| reymont | 72.32 | 81.94 | 1.1330 | 43,617 |
| samba | 103.06 | 114.56 | 1.1115 | 54,011 |
| sao | 92.86 | 96.67 | 1.0410 | 114,461 |
| webster | 93.71 | 104.73 | 1.1176 | 48,838 |
| xml | 252.25 | 276.63 | 1.0966 | 12,323 |
| x-ray | 126.60 | 127.29 | 1.0054 | 107,218 |

Geometric-mean speed **1.0919x**; every output is byte-identical. The weakest
row is x-ray at +0.5%, still above the 0.98x control floor.

Why it works: on dickens the compressed alternatives are 7,445 / 10,984 /
13,582 bits cheaper than the predefined literal/offset/match plans while their
headers cost only 15 / 12 / 19 bytes, so the lower bound proves dominance for
all three kinds. The predefined walks (`predefined.plan` + `planOffset`) were
about 6% of level-1 cycles.

## Correctness

The check only removes alternatives that cannot be selected by the exact
planner. All twelve wires are byte-identical. The full `test-zstd` suite and
the `check`/`check-wasm` gates are the adoption checks.

## Scope limits

One host, one-shot level 1, 128 KiB prefixes. The lower bound uses the
minimum predefined state width per code; a code with no predefined state
disables the skip.
