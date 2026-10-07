# x86-64 dominant 32-state Zstd FSE construction

Date: 2026-10-08. Host: Intel Core i7-10700K, Linux x86-64, Zig
0.16.0, ReleaseFast, CPU 2, one codec thread. Reference: local libzstd
1.6.0-dev at `01b7154f`.

## Implementation and safety

The specialized one-shot `numbered_json` frame contains one compressed offset
FSE table with 32 states. Its normalized probabilities are `24/1/7` across
three active symbols; the remaining encoded values represent absent symbols.
The previous small builder spread all 32 symbols individually, then mapped all
32 states to final decode entries.

`buildMappedSmall32` now detects the general case where a 32-state table has no
low-probability tail and one symbol owns at least 75% of the states. Because
there is no high-end low-probability region to skip, spreading is pure modular
addition. The builder fills the 32-byte symbol scratch with the dominant
symbol, advances over the dominant run with one modular calculation, and emits
only the sparse symbols individually. The final ascending transition pass is
unchanged.

Every other 32-state distribution retains the previous spread loop. The
256/512-state `buildMapped` instantiation does not even collect dominant-symbol
statistics: the condition is removed at compile time. Disassembly confirms its
address and `0x528`-byte size are identical between the frozen binaries.

The focused oracle compares the optimized builder with the generic mapped
builder for the locked `24/1/7` distribution, existing low-probability
fixtures, and 256 deterministic randomized dominant distributions. Both
ReleaseFast and ReleaseSafe pass. The complete-frame benchmark verifies Vort
and libzstd output before every timed process.

## Performance

The primary campaign uses explicit 128-byte aligned input, Vort output, and
libzstd output (`mod128 = 0`) so allocator layout cannot explain the result.
Each process alternates five Vort/libzstd samples, retains the fastest for each
codec, and performs 100,000 decodes. Baseline/candidate process order alternates
by pair. Two independent retained batches contain 7 and 8 pairs; each starts
after a separate 60-second Zig-free window and uses a continuous 20 ms
`ps -C zig` monitor.

| Metric | Median | Geometric mean | Wins | Range |
| --- | ---: | ---: | ---: | ---: |
| candidate / baseline | 1.0130x | 1.0126x | 14/15 | 0.9913x--1.0480x |
| libzstd-normalized | 1.0112x | 1.0122x | 13/15 | 0.9905x--1.0457x |
| candidate / libzstd | 1.0058x | 1.0044x | 13/15 | 0.9859x--1.0153x |

The fifteenth baseline observation is a visible 154.9 ms high value. Removing
only that pair leaves a 1.0128x raw median / 1.0101x geometric result and a
1.0108x normalized median / 1.0099x geometric result, so the conclusion does
not depend on it. Median candidate and libzstd throughput are 831.46 and
825.50 MiB/s respectively. The fixed small JSON row therefore moves from a
0.9937x baseline/libzstd median to a 1.0058x candidate/libzstd median.

A clean seven-pair 13-row matrix uses the same explicit layout and 500 decodes
per row. The target improves by 1.0157x at the raw median. The geometric mean
across row medians is 1.0042x raw and 1.0042x after simultaneous libzstd
normalization. Long controls remain neutral-positive at the median:
`huffman80k` 1.0012x, `large_text` 1.0016x, `large_json` 1.0020x, and
`binary_mixed` 1.0003x. The weakest row median is incompressible at 0.9948x,
inside the existing one-percent control tolerance.

The optimized Small32 function grows from `0x444` to `0x4e1` bytes and its
section grows by the same 157 bytes. Generic mapped FSE code and the raw-FSE
section are unchanged. The following small-sequence and small-frame sections
move by one 256-byte alignment unit but retain their exact `0x829d` and
`0x38f` sizes.

Exact samples, hashes, layouts, control summaries, and discarded contaminated
attempts are recorded in
[zstd-small-dominant-fse32-x86-20261008.json](data/zstd-small-dominant-fse32-x86-20261008.json).

## Validation and scope

- focused FSE builder tests pass in ReleaseFast and ReleaseSafe;
- all 1,703 project ReleaseFast tests pass;
- the libzstd 1.6.0 compatibility probe passes 276/276 cases;
- all nine upstream decodecorpus campaigns pass: 9,900 frames, 2,699 bounded
  block streams, 76,578 streamed sequence blocks, and all 64 sequence-mode
  combinations;
- `zig build check -Doptimize=ReleaseFast` compiles all 104 entrypoints;
- CLI help and an AArch64 Linux ReleaseFast static-library compile pass.

This establishes a narrow lead only for the fixed small one-shot JSON shape.
It is not evidence of broad Zstd leadership: `large_json` remains the largest
synthetic decoder gap against the same libzstd build, and real-corpus aggregate
leadership remains open.
