# Incremental Deflate circular staging

Incremental semantic decoding keeps the caller's 64 KiB storage and 32 KiB private generation.
Logical history and generation occupy disjoint portions of a circular window.
Draining still copies only initialized output to the caller. Between generations,
retaining the newest 32 KiB changes the logical base instead of moving history.
Leaving semantic mode normalizes the committed prefix for the compact decoder.
Already chronological compact history also skips the old bootstrap round trip.

The transaction remains private until a successful decode publishes reader
progress. Truncated/invalid attempts discard their generation, restore compact
tables and normalize only the prior committed history. Block completion returns
at the same step boundary, preventing delivered bytes from entering the compact
history recorder twice. Reset and sync recovery reset the circular base.

Geometry/copy, semantic decoding and controller history operations live in
separate modules. `DecoderWithMode` keeps a linear reference and optional
diagnostic instance; the ordinary instance has zero-sized work storage and no
per-token observer. Diagnostic byte counts report retired logical output and
requested history-copy payload, not a hardware memory-traffic measurement.

## Correctness evidence

The independent circular copy oracle tests every physical base, literal/pair
writes, distances 1/2/3/4/16/258/32768, overlap and wrap, immutable prefix,
free-region and external guards, drains and chronological normalization.
The kernel compares 105 linear/circular cases, four exact-capacity pauses,
four observed errors and ten truncated reservoirs, including different input
slices carrying preloaded bits.

The controller runs ordinary linear/circular and observed linear/circular
instances together. Each step compares status, input/output progress, reservoir,
partial token state, phase/errors, initialized logical history/generation,
pending bytes, delivered history and guards. Independent RFC fixtures cover
0/1/257/258/4096-byte output, multiple windows, fragmented fallback, every short
dynamic prefix, dictionary/rotated bootstrap, limits/reset, and dynamic/fixed/
stored transitions with distance 32768. The packed-capacity fixture requires
zero caller output to prepare 32513 bytes and eventually deliver all 32835.

The underlying [token/refill fix](../../formats/deflate-semantic-transactions.md)
is saved separately as `fdd2b4e7`. Original source independently returns
`OutputTooSmall` for its legal capacity fixture and aborts ReleaseSafe on the
maximum-token fixture. Short refill tails are now bounded.

## Diagnostic epoch

On all twelve Silesia 64 KiB/1 MiB level 9 frames, whole-input observed instances
retire/deliver 13,352,928 semantic bytes with zero discarded generation. Linear
versus circular requested history-copy counts are:

| Operation | Linear bytes | Circular bytes |
| --- | ---: | ---: |
| Bootstrap | 14,168,500 | 65,536 |
| Normalization | 17,175,842 | 7,766,016 |

All 48 diagnostic rows match generated/delivered/discarded counts. 4 KiB input
slices admit no semantic work on these frames, providing a compact control.
These counters identify removed work; the ordinary matrices below are the
adoption evidence.

## Frozen controller and empty reservoir

The independent probe imports two complete source modules: the original
`61c14dae` controller with the token/refill safety fixes, and current source.
It does not share controller history/mapping code with the candidate. All
reader fields, status/progress, partial token state, diagnostics, initialized
logical prefix/generation, compact history and caller/workspace guards are
compared at every step.

The initial strict epoch passed 207/208 runs and exposed MR 64 KiB level 6 with
`bit_count=0`, old buffer 0 and new buffer 0x2b. Wide-read shadow bits remained
when the tail rolled back a token and no complete lookahead byte could rewind.
The candidate now clears the buffer when no bit is declared. An independent
bitstream test checks all consumed offsets 0..56 and replacement of an
unconsumed byte before resume.

After that fix, 14 strict differences exposed existing nonzero empty buffers
in the old path. Every old/new raw value is preserved in the diagnostic
records. A separate reference copy adds exactly one line at its original
rewind entry: `if (reader.bit_count == 0) reader.bit_buffer = 0;`. Its controller
and eager-refill core otherwise retain their hashes. The same unmodified strict
probe then passes 208/208 runs: 101303 steps, 16359 zero-output calls and 35889
active-semantic state checks. No comparison masks or drops reader fields.

The 208 runs include 48 Silesia and 16 controls with whole/4 KiB input and 4096-byte
output, controls with 0/1/257/258/4096 output, and all 24 Silesia 1 MiB frames with
that output cycle. Provenance, independent patch, three epoch reports and
binaries remain in `zig-out/deflate-rolling-20261103/`.

## Ordinary A/B protocol and result

Both programs use the same guarded public harness. Zig 0.16.0 ReleaseFast,
`x86_64-linux-gnu -mcpu=skylake+pku+sgx`, Intel i7-10700K, logical CPU2,
one decoder thread and 8 MiB stack. All independent compile/test/profile jobs
finish before serial timing. Each process performs one warmup and timed calls
with a fresh decoder/workspace. File reads, allocation, full comparisons, SHA
and guards stay outside timing.

Inputs are twelve Silesia 64 KiB/1 MiB prefixes produced by zlib 1.2.11 levels 6/9,
window bits -15, memory 8, default strategy and `Z_FINISH`. The main matrix uses
whole/4 KiB input and 4 KiB output. Five alternating sweeps with 64 timed calls per
process cover 96 rows and 960 processes. Ratios are geometric means of each
row's median paired candidate/baseline latency ratio; lower is faster.

The structural baseline keeps the original controller and has the same
selective token refill and empty-buffer correction as the candidate. The direct
total epoch independently compares final source with pristine `61c14dae`.
These are separate epochs, not multiplied improvements.

| Scope / level | Circular / corrected linear, whole | Final / pristine, whole | Final / pristine,4 KiB input |
| --- | ---: | ---: | ---: |
|64 KiB /6 |0.64924 |0.66640 |1.00316 |
|64 KiB /9 |0.64532 |0.65972 |1.00026 |
|1 MiB /6 |0.84712 |0.85550 |1.00146 |
|1 MiB /9 |0.84834 |0.86173 |1.00111 |

Every 64 KiB whole-input row improves; the final epoch lowers whole-input group
latency 33–34% at 64 KiB and 13.8–14.4% at 1 MiB. Fragmented groups remain near
neutral. Longer 256-call structural checks retain Dickens 1 MiB level 6/9 at
1.01974/1.01479 and selected fragmented XML/Reymont/Dickens rows around
1.01–1.02. These negative rows remain visible in the per-row CSV.

The four control sources are deterministic random, periodic, overlap and mixed
inputs at 64 KiB/1 MiB and levels 6/9. Their initial 256-call epoch records random
1 MiB level 9 whole at1.07409 and random 64 KiB level 6 fragmented at1.04910.
A separate 1024-call epoch moves those rows but retains random 1 MiB level 6
whole at1.05397. Mixed 1 MiB whole improves substantially. These variable
inactive controls do not support a universal speed claim.

The public one-shot matrix isolates the shared refill correction. Selective
refill versus the first safety-fix epoch lowers 1 MiB group latency 1.2–1.3% and
is near neutral at 64 KiB. Final versus pristine one-shot groups are
1.00649/1.00918 at 64 KiB levels 6/9 and 1.00170/1.00440 at 1 MiB. Longer MR/SAO
checks preserve MR point regressions around 2.7–3.9%. No one-shot gain is
claimed from the circular incremental work.

[All per-row results](rolling-window-20261103.csv) include every main, control
and weak-row epoch. Local `final-evidence.json` binds source file hashes,
harnesses, full input/wire manifests, both binaries, commands and report hashes.
The [evidence archive](../data/deflate-rolling-20261103/evidence.tar.xz)
retains complete reports, failed epochs, independent probe/runner, reference
patch, source bindings and input/wire manifests. Its SHA-256 is
`d98d2a8d94fa549ef4c992007241d449829a0d8b48005219812403b5b1aad888`.

| Local report | SHA-256 |
| --- | --- |
|rolling-report.json |`6e8867036027b6b0b08f5e1545e4f877cdbc259f82a97bdf9fc2591b430dbb42` |
|total-report.json |`2c9bcf307e2fa38db280894b76e3e6a186bef135c98f4e892bc694388e419080` |
|oneshot-total-report.json |`b8b6eb91803b5d09e2159d19c89c44063e004697a72629dff770362496885f6e` |
|rolling-controls-long-report.json |`2bffc68a9578b09df47ee1985cc25c5dbd0725da17c232c3bdc8cbd286cb709d` |
|rolling-weak-long-report.json |`a1848382d5e080a2f2bf0f933fb7561a91aba9830aae7da60077d890ba003ad3` |

## Reproduction and gates

Archive `61c14dae` before applying the fixes. For the corrected linear source,
retain its controller and copy the current semantic decoder/token tests, then
add the independent empty-buffer line to the old rewind function. Compile
ordinary programs with the same flags and harness:

```sh
zig build-exe -OReleaseFast -target x86_64-linux-gnu -mcpu=skylake+pku+sgx \
  --dep deflate -Mroot=bench/deflate/raw_incremental_decode.zig \
  -Mdeflate=zig-out/deflate-rolling-20261103/selective-linear-source/src/deflate.zig \
  -femit-bin=zig-out/deflate-rolling-20261103/selective-linear-final
zig build-exe -OReleaseFast -target x86_64-linux-gnu -mcpu=skylake+pku+sgx \
  --dep deflate -Mroot=bench/deflate/raw_incremental_decode.zig \
  -Mdeflate=src/deflate.zig -femit-bin=zig-out/deflate-rolling-20261103/rolling-final
python3 tools/deflate/incremental_decode_compare.py \
  --manifest zig-out/deflate-lazy-20261102/corpus/manifest.json \
  --baseline zig-out/deflate-rolling-20261103/selective-linear-final \
  --candidate zig-out/deflate-rolling-20261103/rolling-final \
  --output zig-out/deflate-rolling-20261103/rolling-report.json \
  --cpu 2 --sweeps 5 --iterations 64
```

`bench/deflate/raw_decode.zig` and `--api oneshot` use the same corpus and
comparison binding for the public one-shot path. The generator and controls
record their byte hashes and reference round trips.

Current verification includes 617 ReleaseFast Deflate tests, 47 actual ELF32
ReleaseSafe tests, six actual WASI 1 MiB whole/fragmented decode cases, and
212/212 native/WASI build-check steps. The new controller contracts have
independent Debug/ReleaseSafe/ReleaseFast evidence; final pre-handoff checks
remain recorded separately in the local logs.

A temporary test harness initially wrote through a symlink to `src/root.zig`.
The production root was restored byte-for-byte from Git, the link removed and
an exclusive ordinary harness file used for all final controller checks.
The affected gate was discarded. Later source updates invalidated long
ReleaseSafe whole-library builds; their termination is not a successful gate.
The recorded completed broad gate is the ordinary Debug `check check-wasm`.

Full-file/dictionary streaming, a current zlib-ng comparison, memory/RSS and
ARM64 timing remain separate coverage. The Deflate/Zstd/Brotli industry-best
objective stays active. Next opportunities include preserving the existing
shift chain when a token needs no refill, stronger streaming/reference coverage,
and Brotli parameter-pair counted preparation and winner emission.
