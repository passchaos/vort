# x86-64 Zstd FSE/FSE/RLE sequence pairs

Date: 2026-10-04. Baseline: `98f71ce7`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libzstd 1.6.0-dev (`01b7154f`). Validation was completed on 2026-10-06.

## Scope and safety

The first compressed block in the synthetic `binary_mixed` frame contains
2,044 raw-literal sequences with compressed LL and OF tables and an RLE ML
symbol. The three following blocks already use the separate FSE/RLE/RLE pair
executor. This change adds a bounded two-sequence executor for the remaining
FSE/FSE/RLE block's steady state: each sequence emits a 16-byte literal and a
48-byte non-overlapping rep0 match.

The pair executor starts only while more than two sequences and a complete
eight-byte reverse-bitstream suffix remain. Before committing progress, it
validates both LL symbols and transitions, both OF symbols and transitions,
both ML and LL extra values, the combined 56-bit field limit, 32 literal
bytes, 128 output bytes, and a positive in-frame rep0 of at least 48 bytes.
The standard OF table has only one zero-extra-bit symbol, code zero, so the OF
checks also prove that both offsets are rep0 without changing the repeat
queue. A successful pair commits the exact combined bit count and both FSE
states, then performs two fixed 16-byte literal copies and two existing exact
48-byte match copies. Irregular symbols, a short reservoir, the final two
sequences, a short destination, or invalid history retain the original
single-sequence decoder and its error order.

The direct oracle compares the complete output and retained modes with the
generic `readModeSequence` decoder. Short-output and invalid-history cases
also compare exact partial output, written cursor, remaining bit count,
remaining sequence count, LL/ML/OF states, and all three repcodes. The
test-only hit counter proves that the pair path, rather than only its fallback,
executes on the locked shape.

The original FSE/FSE/RLE section grows from `0xc68` (3,176) to `0xd16`
(3,350) bytes. The separately compiled pair section is `0x38b` (907) bytes.
Keeping the pair in its own section bounds parent growth and makes its code
shape independently auditable. The final validated source rebuilds both hot
sections byte-identically to the frozen timing executable, with SHA-256
`cf164ef6...d7c2f` and `769f5e6a...cd204` respectively.

## Performance

The frozen 524,288-byte `binary_mixed` input has SHA-256
`9b6baade432a5412676e8e19dbcdbd93346b08f7ed6c320af1235ca33020200d`.
Its 134,438-byte level-one frame has four compressed blocks, 8,188 total
sequences, 131,203 literal bytes, and 393,085 match bytes. Every executable
runs 3,000 complete decodes, takes the fastest of five interleaved
Vort/libzstd samples, is pinned to CPU 2, and alternates frozen
baseline/candidate launch order. A continuous `ps -C zig` monitor was empty
for all seven retained pairs; pair five was retried until its sixth attempt
was clean.

| Comparison | Median | Geometric mean | Wins | Range |
| --- | ---: | ---: | ---: | ---: |
| Candidate / baseline | 1.1508x | 1.1535x | 7/7 | 1.1338x--1.1756x |
| libzstd-normalized candidate / baseline | 1.1486x | 1.1464x | 7/7 | 1.1285x--1.1595x |
| Candidate / libzstd | 1.4416x | 1.4406x | 7/7 | 1.4254x--1.4523x |

Median Vort throughput rises from 10,180.74 to 11,722.09 MiB/s. This extends
the existing lead on this exact FSE-heavy synthetic frame; it is not a broad
Zstd decode-leadership claim. Other rows, real corpora, memory use, and more
targets still decide the project-wide objective.

Three non-target controls use 15 clean pairs and 3,000 iterations per
executable. Every pair has its own 0.2-second continuous Zig-process monitor;
one contaminated `huffman80k` attempt was discarded and repeated. None of
these frames selects the new pair executor.

| Control | Candidate / baseline median / geometric | Wins | libzstd-normalized median / geometric |
| --- | ---: | ---: | ---: |
| `large_text` | 1.0003x / 1.0024x | 8/15 | 1.0003x / 1.0025x |
| `large_json` | 1.0008x / 1.0011x | 8/15 | 1.0031x / 1.0033x |
| `huffman80k` | 1.0009x / 1.0009x | 8/15 | 1.0044x / 1.0025x |

All six direct medians/geometric means are positive, so the appended section
and shifted downstream section addresses do not create a measured control
regression.

The system-libzstd reusable reference gate remains host-sensitive: its
5,000-iteration `numbered_json` row measured 0.9131x against libzstd 1.4.8 and
failed the 0.95 absolute threshold. This row does not select the changed
executor. A separate 15-pair, 100,000-iteration frozen candidate/baseline
campaign, with two contaminated attempts discarded, measures 0.9923x median /
0.9915x geometric direct throughput. The candidate reaches 0.9913x median
local libzstd 1.6.0 reusable throughput. The red absolute gate is recorded,
but the direct attribution evidence does not show a change-induced regression.

A destructive shifting field group was also evaluated. It shortened the pair
section from 907 to 831 bytes, but reached only 1.1376x median / 1.1411x
geometric target throughput versus the same baseline, below the retained
1.1508x / 1.1535x result. The non-destructive group therefore remains the
measured winner despite its slightly larger body.

Exact executable and section hashes plus every retained timing pair are in
[zstd-fse-fse-rle-pair-x86-20261004.json](data/zstd-fse-fse-rle-pair-x86-20261004.json).

## Validation

- All 682 direct ReleaseFast Zstd tests pass, including exact failure-progress
  comparison with the generic oracle.
- The complete project ReleaseFast test suite passes in 6,391.21 seconds at
  12,944,724 KiB peak RSS; `zig build check -j1` passes in 631.98 seconds at
  1,021,320 KiB peak RSS.
- Generic x86-64 and AArch64 Linux ReleaseFast library builds pass, as do the
  CLI help smoke, five-row decode-profile gate, and 13-row one-shot reference
  gate. The reusable reference gate exception is documented above.
- The local libzstd 1.6.0-dev compatibility probe passes 276 cases with zero
  unsupported cases.
- The upstream decodecorpus gate passes nine campaigns and all 9,900 frames,
  covering all 64 sequence-mode combinations and 2,699 bounded block-stream
  cases.
