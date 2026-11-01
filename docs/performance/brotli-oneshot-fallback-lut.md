# Brotli one-shot fallback lookup

A one-shot profile of Mozilla 64 KiB q6 attributed 43.9% of decoder cycles to
`br.PrefixCode(256).decode`. That is the canonical scalar scan used when the
tail-lookup preparation cannot fit the tree's active symbols. The standard and
large one-shot payload loops called `tree.decode` directly in that fallback.

## Change

The four one-shot literal fallback sites now call `tree.decodePrepared`, which
builds the owned 8-bit lookup on first use. The standard header parser clears the
prepared flags after every parse, matching the large-window parser, because the
one-shot header is parsed into an undefined stack value. Long codes keep the
canonical fallback after the same zero-padded peek.

This is the same prepared-lookup path already used by the incremental decoder.
It is not the earlier tail-lookup experiment; the tail path still handles trees
whose primary lookup fits.

## Measurement

A paired 384-process four-sweep screen against the previous current-source build
gives:

| Producer quality / scope | Fallback lookup / previous |
| --- | ---: |
| q6 / 64 KiB | 0.9090 |
| q6 / 1 MiB | 0.9965 |
| q11 / 64 KiB | 0.8902 |
| q11 / 1 MiB | 0.9989 |

All 48 rows reduce to `0.9474`; the four sweeps independently give
`0.9466/0.9493/0.9504/0.9480`. The best row is Mozilla 64 KiB q6 at `0.644`; the
worst is reymont 64 KiB q6 at `1.028`. The 1 MiB point estimates are neutral,
so the gain is specific to small frames where the fallback scan dominates.

The follow-up 1,296-process industry epoch reduces the Brotli 64 KiB reference
gap from `1.8833` to `1.7448` for q6 and from `1.7536` to `1.5542` for q11;
Brotli 1 MiB and full-file gaps stay about `1.13–1.15x` and `1.39–1.44x`.
Deflate and Zstd groups are unchanged within run-to-run variation.

## Validation

The complete ReleaseFast Brotli suite passes 1504/1505 with one 32-bit-specific
skip and zero failures. All one-shot tests that exercise the standard and
large-window fallback paths are included.

## Next work

The remaining Brotli 64 KiB gap is mostly per-call setup and the external
literal loop. Deflate's semantic dynamic block loop is still the largest
three-codec gap, followed by the Zstd sequence decode.
