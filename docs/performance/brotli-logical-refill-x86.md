# Brotli refill bounds from the logical input range

Date: 2026-10-02. Baseline: `95c57c53`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libbrotli 1.2.0-dev (`558fc647`), CMake Release (`-O3 -DNDEBUG`).

## Motivation and change

An isolated diagnostic on the frozen 1,251,399-byte roadmap q9 input measures
200 complete decodes in 600,159,810 ns and 200 header-only parses in
35,805,627 ns, about 5.97%. The header has 143 literal trees, three command
trees, and 27 distance trees. This is an approximate attribution measurement;
the remaining time includes lookup preparation as well as payload execution.

The payload reader previously checked both the physical remaining bytes and
the valid logical bits before each word refill. A valid input reader already
guarantees `bit_len <= input.len * 8`. Therefore, 64 valid unstaged bits also
prove that an eight-byte load is inside the physical input; the corresponding
32-bit condition proves a four-byte load. Saturating subtraction gives zero
valid bits when the cursor has passed a partial final byte.

The new path uses those logical ranges directly and removes the separate
physical-end early return. It retains the existing 56/48/32-bit reservoir
increments and 7/6/4-byte cursor advances. Near a partial logical endpoint,
an eight-byte load now requires all 64 loaded bits to be valid, so the reader
may choose a four-byte load or the unchanged bounded byte-tail loop instead.
No input padding or speculative reads outside the caller buffer are required.

Reader fields, ownership, allocations, and scratch capacity are unchanged.
In the measured x86 executable, both principal 9-bit and 10-bit wide payload
instances shrink from 5,589 to 5,390 bytes, a reduction of 199 bytes each.

## Validation

The new scalar comparison exercises every logical endpoint of a 24-byte
nonzero input, all eight starting bit offsets, and read widths from zero
through 32 bits in three-field sequences. It checks decoded values, exact
truncation errors, consumed-bit positions, and synchronization back to the
scalar byte/bit cursor while retaining real bytes beyond the logical endpoint.

All 545 direct Brotli tests pass, including the focused Debug reader suite.
The local upstream differential passes 7,056 generated cases and their 7,056
progressive counterparts, 1,401 fragmentation schedules, 64 high-tree
truncations, and seven Large Window cases. The four-file real-corpus matrix
passes all 16 one-shot and 16 progressive cases. The focused AArch64 test
executable is cross-compiled and linked, not executed on this x86 host.
Changed Zig source passes `zig fmt --check`; `zig build check -j2` and
`zig build run -j2 -- --help` also pass.

## Measurement

Frozen source and roadmap inputs are reconstructed from `488c5415`. Full
reference comparisons alternate Vort and libbrotli within five warmed rounds;
baseline/candidate process order reverses on successive pairs. Decoder-only
controls use the same five-round estimator and reversed process order.
Every pair requires equal sizes, iteration counts, and decoded checksums;
full comparisons also record input and executable SHA-256 hashes.

The initial variant retained the physical-end early return and improved seven
roadmap-q9 pairs by 1.0138x median. Removing that redundant return improves
the seven-pair screen to 1.0170x median; source q9 and clustered q8 screens
reach 1.0184x and 1.0186x, respectively, each with 7/7 wins. Final reference
measurements and controls are recorded separately from these screens.

The retained version's final results against the frozen baseline are:

| Input | Sampling | Pairs won | Median | Geometric mean | Minimum pair |
| --- | --- | ---: | ---: | ---: | ---: |
| roadmap q9 | full reference comparison | 14/15 | 1.0201x | 1.0185x | 0.9983x |
| source q9 | decoder-only comparison | 15/15 | 1.0195x | 1.0204x | 1.0145x |
| roadmap q5 | decoder-only comparison | 7/7 | 1.0166x | 1.0161x | 1.0116x |
| source q5 | decoder-only comparison | 7/7 | 1.0199x | 1.0189x | 1.0149x |
| clustered q8 | decoder-only screen of the retained binary | 7/7 | 1.0186x | 1.0210x | 1.0140x |

The final roadmap-q9 candidate/libbrotli median is 0.7169x; its paired
reference-normalized geometric improvement is 1.0249x. The small negative
minimum pair remains in the record rather than being discarded. These are
repeated complete-frame observations, not extrapolations from the diagnostic
header timing.

The final 13-row local-reference gate retains all existing throughput floors,
and the input-path smoke passes three valid rows and five invalid argument
combinations. The clustered row reuses the seven-pair screen of this same
binary; it is not counted as an additional independent run.

This change narrows the measured decode gap. It does not establish broad
Brotli or Zstd leadership across inputs, APIs, cold runs, or architectures.

Exact sample times, commands, input/binary hashes, reference builds, code sizes,
and the diagnostic probe source/output are recorded in
[brotli-logical-refill-x86-20261002.json](data/brotli-logical-refill-x86-20261002.json).
