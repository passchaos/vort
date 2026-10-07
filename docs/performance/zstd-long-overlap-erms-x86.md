# x86-64 Zstd ERMS doubling chunks for long overlap

Date: 2026-10-07. Baseline: `3106e9e4`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libzstd 1.6.0-dev (`01b7154f`).

## Scope and safety

The synthetic `large_text` frame contains four compressed blocks, one
predefined sequence per block, 85 literal bytes, and 524,203 match bytes. Its
long matches have an approximately 82-byte period and nearly fill a 128 KiB
block. Vort's established replay first copies one period and then doubles the
initialized prefix with non-overlapping `memcpy` calls.

Forward `rep movsb` over the complete overlapping match was tested first. It
was byte-correct, but Intel ERMS serialized on the source-after-destination
dependency and reduced the reference-gate row to `0.5434x` system libzstd.
That version was removed.

The retained path leaves the overlapping seed and every copy below 32 KiB
unchanged. Once doubling has proved that the current source and destination
ranges do not overlap, chunks of at least 32 KiB use `rep movsb`. Selection is
limited to ERMS-capable x86-64, a match of at least 64 KiB, and distance at
least 64. Non-x86 targets compile the route away.

Only `decodeSinglePredefinedSequence` calls the new policy, and only for
dictionary-free matches. Its helper repeats the original history, output, and
offset checks before the first write. All other callers keep the original
`copyMatchFromHistory` and shared `match_copy.append` machine code. The cold
fallback uses an explicit never-inline call so it does not expand the selected
function again.

The ERMS helpers live in the dedicated
`.vort_zstd_zzz_long_match` section, whose platform spelling is isolated in
`src/zstd/sequence/code_sections.zig` and re-exported by the parent section
catalog. The section is `0x10e` bytes. `copyMatchFromHistory` remains `0x1ea`
bytes at its original address. `decodeSinglePredefinedSequence` shrinks from
`0x12f6` to `0x10c7`; the ordinary text section shrinks by 512 bytes. Existing
Zstd hot sections retain their sizes, and the small-sequence/small-frame
sections retain both addresses and sizes.

## Performance

The frozen baseline and final candidate alternate process order. Every process
runs five internal Vort/libzstd samples and keeps the best for each codec. A
20-millisecond `ps -C zig` monitor rejects a whole campaign if any external Zig
process appears.

Seven clean 5,000-iteration `large_text` pairs on CPU 2 measure:

| Comparison | Median | Geometric mean | Wins | Range |
| --- | ---: | ---: | ---: | ---: |
| candidate / baseline | 1.0657x | 1.0686x | 7/7 | 1.0615x--1.0793x |
| libzstd-normalized | 1.0644x | 1.0677x | 7/7 | 1.0607x--1.0777x |

Candidate throughput is `1.0472x` median / `1.0472x` geometric local libzstd
1.6.0, with all seven observations ahead (`1.0438x--1.0507x`). The frozen
baseline is `0.9824x` at the median.

A separate clean seven-pair 13-row matrix uses 1,000 iterations per process.
The target remains positive at `1.0686x` median / `1.0716x` geometric. The
twelve non-target row medians have a combined geometric mean of `1.0017x` raw
and `1.0044x` after libzstd normalization. Long compressed controls are:

| Case | Raw median / geometric | Normalized median / geometric | Wins |
| --- | ---: | ---: | ---: |
| `numbered_json` | 0.9947x / 0.9965x | 0.9997x / 0.9995x | 2/7 |
| `huffman80k` | 1.0019x / 1.0019x | 0.9991x / 0.9984x | 5/7 |
| `ascii64k` | 1.0116x / 1.0174x | 1.0021x / 1.0153x | 5/7 |
| `large_json` | 1.0005x / 1.0002x | 0.9978x / 0.9983x | 4/7 |
| `binary_mixed` | 1.0013x / 1.0024x | 0.9996x / 1.0005x | 6/7 |

Short raw/RLE rows show wider scheduler noise at only 1,000 iterations and are
retained as controls, not attributed changes. Exact samples, hashes, layout,
and validation totals are in
[zstd-long-overlap-erms-x86-20261007.json](data/zstd-long-overlap-erms-x86-20261007.json).

This establishes a reproducible lead over local libzstd for `large_text`, not
broad Zstd leadership. The same matrix still measures `large_json` around
`0.93x`, `numbered_json` near parity, and `huffman80k` around `1.15x` libzstd;
those rows remain open.

## Validation

- All 23 direct ReleaseFast match-copy tests pass, including a guarded
  128-KiB-class overlap oracle at distances 64, 82, 127, and 4,096.
- All 683 direct ReleaseFast Zstd tests and all 1,702 project tests pass.
- Generic AArch64 Linux ReleaseFast compilation removes the ERMS route.
- The one-shot 13-row reference gate, 12-row path smoke, five-row profile gate,
  and three-valid/seven-invalid profile path smoke pass.
- The local libzstd 1.6.0 compatibility matrix passes 276/276 cases.
- Nine upstream decodecorpus campaigns pass all 9,900 frames, 2,699 block
  streams, 76,578 streamed sequence blocks, and all 64 sequence-mode
  combinations.
- All 104 build-check steps and CLI help pass.
